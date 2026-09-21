#!/bin/bash
# Builds FilmExif.app from the Swift package, with no Xcode project and no
# Apple Developer account required — just the free Xcode Command Line Tools
# (install with: xcode-select --install).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# APP_NAME is the SwiftPM executable target's actual name — it must match
# the compiled binary's filename and CFBundleExecutable in Info.plist, so it
# stays "FilmExif" even though the app is now presented to users as
# "EZ Exif" (DISPLAY_NAME): the .app bundle itself, and everything a user
# actually sees (menu bar, Dock, Finder), uses DISPLAY_NAME.
APP_NAME="FilmExif"
DISPLAY_NAME="EZ Exif"
BUILD_DIR="$ROOT_DIR/.build/release"
APP_BUNDLE="$ROOT_DIR/dist/$DISPLAY_NAME.app"

echo "==> Building release binary with Swift Package Manager…"
swift build -c release

echo "==> Assembling $DISPLAY_NAME.app…"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
cp "$ROOT_DIR/Resources/author logo.svg" "$APP_BUNDLE/Contents/Resources/author logo.svg"
cp "$ROOT_DIR/Resources/author logo-dark.svg" "$APP_BUNDLE/Contents/Resources/author logo-dark.svg"

# Localization: NSLocalizedString / SwiftUI's Text(_:) read Bundle.main's
# .lproj folders directly, so these just need to land in Contents/Resources
# — no asset-catalog compile step required.
for lproj in "$ROOT_DIR"/Resources/*.lproj; do
    [ -d "$lproj" ] || continue
    cp -R "$lproj" "$APP_BUNDLE/Contents/Resources/"
done

# Ad-hoc code sign so Gatekeeper doesn't flat-out refuse to launch it at all.
# This does NOT replace notarization — without a paid Apple Developer
# account, people downloading the DMG will still see an "unidentified
# developer" warning the first time they open it. See README.md for the
# one-time workaround they need (right-click → Open, or `xattr -cr`).
echo "==> Ad-hoc code signing…"
codesign --force --deep --sign - "$APP_BUNDLE"

echo "==> Done: $APP_BUNDLE"
