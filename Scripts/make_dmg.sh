#!/bin/bash
# Packages dist/EZ Exif.app into a distributable dist/EZ Exif.dmg, with a
# custom background, hidden toolbar, and pre-arranged icons (app on the
# left, an arrow, an Applications shortcut on the right) — the standard
# "drag to install" look, instead of Finder's raw default window.
# Run Scripts/build_app.sh first.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# See build_app.sh for why this is "EZ Exif", not "FilmExif" — that's the
# internal SwiftPM target name, this is the user-visible app/bundle name.
APP_NAME="EZ Exif"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_BUNDLE/Contents/Info.plist")
FINAL_DMG="$DIST_DIR/$APP_NAME $VERSION.dmg"
STAGING_DIR="$DIST_DIR/dmg-staging"
RW_DMG="$DIST_DIR/dmg-rw-temp.dmg"
BACKGROUND_SRC="$ROOT_DIR/Resources/dmg-background.png"

# Window/icon layout — kept in sync with the coordinates baked into
# Resources/dmg-background.png (its arrow points from the app icon slot to
# the Applications slot at these same positions).
WINDOW_BOUNDS="{400, 120, 1060, 540}"
ICON_SIZE=128
APP_ICON_POS="{180, 200}"
APPLICATIONS_ICON_POS="{480, 200}"

if [ ! -d "$APP_BUNDLE" ]; then
    echo "error: $APP_BUNDLE not found — run Scripts/build_app.sh first" >&2
    exit 1
fi

echo "==> Staging DMG contents…"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR/.background"
cp -R "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"
cp "$BACKGROUND_SRC" "$STAGING_DIR/.background/background.png"

echo "==> Creating a writable staging image…"
rm -f "$RW_DMG" "$FINAL_DMG"
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -fs HFS+ -format UDRW \
    -size 200m \
    "$RW_DMG" >/dev/null

echo "==> Mounting it to arrange the window…"
MOUNT_OUTPUT=$(hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG")
DEVICE=$(echo "$MOUNT_OUTPUT" | egrep '^/dev/' | sed 1q | awk '{print $1}')
VOLUME_PATH="/Volumes/$APP_NAME"

# Give Finder a moment to notice the newly mounted volume before scripting it.
sleep 1

osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "$APP_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to $WINDOW_BOUNDS
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to $ICON_SIZE
        set background picture of theViewOptions to file ".background:background.png"
        set position of item "$APP_NAME.app" of container window to $APP_ICON_POS
        set position of item "Applications" of container window to $APPLICATIONS_ICON_POS
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
APPLESCRIPT

sync
echo "==> Ejecting…"
hdiutil detach "$DEVICE" >/dev/null

echo "==> Compressing final $FINAL_DMG…"
hdiutil convert "$RW_DMG" -format UDZO -ov -o "$FINAL_DMG" >/dev/null

rm -rf "$STAGING_DIR" "$RW_DMG"
echo "==> Done: $FINAL_DMG"
