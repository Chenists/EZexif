import SwiftUI
import AppKit

@main
struct FilmExifApp: App {
    @StateObject private var library = PhotoLibrary()
    @StateObject private var presetStore = PresetStore()
    @StateObject private var settingsRouter = AppSettingsRouter()
    @StateObject private var fieldVisibility = FieldVisibilityStore()
    @AppStorage(AppSettingsKeys.displayMode) private var displayModeRaw = DisplayMode.system.rawValue
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow

    private var preferredColorScheme: ColorScheme? {
        (DisplayMode(rawValue: displayModeRaw) ?? .system).colorScheme
    }

    /// Falls back to the actual system appearance when `preferredColorScheme`
    /// is `nil` (the app's Display Mode setting is "System") — used to pick
    /// the right author-logo variant for the About panel, which isn't a
    /// SwiftUI view and so can't just read `.preferredColorScheme` itself.
    private var systemColorScheme: ColorScheme {
        NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .dark : .light
    }

    /// Read from the bundle's own `CFBundleName` (currently "EZ Exif")
    /// rather than a hardcoded literal, so the About menu item's label
    /// can't drift out of sync with the app's actual display name if it's
    /// ever renamed again.
    static var appName: String {
        Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String ?? "EZ Exif"
    }

    /// A menu title built around the app's name, translated as a proper
    /// format string rather than string interpolation (`"\(appName) Help"`)
    /// — `Button`'s title is a `LocalizedStringKey`, and interpolating a
    /// value into one produces a key SwiftUI can't actually match against a
    /// plain `Localizable.strings` entry, so it silently falls back to
    /// English no matter the app's language. Looking the format string up
    /// with `NSLocalizedString` first, then substituting `appName` in
    /// ourselves, sidesteps that — and lets a translation reorder the name
    /// relative to the rest of the title (Spanish reads better as "Ayuda de
    /// EZ Exif" than a literal "EZ Exif Ayuda").
    static func localizedAppNameTitle(_ formatKey: String) -> String {
        String(format: NSLocalizedString(formatKey, value: formatKey, comment: "%@ is the app name"), appName)
    }

    init() {
        // Registered (rather than just the @AppStorage default in
        // SettingsView) so it also takes effect for anyone who saves before
        // ever opening Settings — ExifXMPService reads this key straight
        // from UserDefaults, not through an @AppStorage of its own.
        UserDefaults.standard.register(defaults: [
            AppSettingsKeys.createBackupFiles: true,
            AppSettingsKeys.jpegCompressionQuality: 1.0
        ])
    }

    /// The author's own logo (`Resources/author logo.svg` for light mode,
    /// `Resources/author logo-dark.svg` for dark mode), shown in the About
    /// panel's credits area — separate from the app icon, which represents
    /// the app itself rather than who made it. The About panel is a plain
    /// AppKit panel, not one of this app's own SwiftUI windows, so it
    /// doesn't pick up `.preferredColorScheme` — `dark` is passed in by the
    /// caller instead, using that same resolved color scheme.
    private static func authorLogoCredits(dark: Bool) -> NSAttributedString? {
        let resourceName = dark ? "author logo-dark" : "author logo"
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "svg"),
              let logo = NSImage(contentsOf: url), logo.size.height > 0 else {
            return nil
        }
        let height: CGFloat = 28 * (2.0 / 3.0)
        logo.size = NSSize(width: height * logo.size.width / logo.size.height, height: height)

        let attachment = NSTextAttachment()
        attachment.image = logo
        attachment.bounds = CGRect(x: 0, y: -6, width: logo.size.width, height: logo.size.height)

        let credits = NSMutableAttributedString(attachment: attachment)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        credits.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: credits.length))
        return credits
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(library)
                .environmentObject(presetStore)
                .environmentObject(settingsRouter)
                .environmentObject(fieldVisibility)
                .frame(minWidth: 900, minHeight: 600)
                .preferredColorScheme(preferredColorScheme)
                .onAppear { appDelegate.library = library }
        }
        // Makes the sidebar/content divider continue up through the
        // toolbar row itself (splitting it into a sidebar zone and a
        // content zone), instead of the toolbar rendering as one
        // undivided bar with the divider only starting where the content
        // area begins.
        .windowToolbarStyle(.unified(showsTitle: false))
        // `.frame(minWidth:minHeight:)` above only describes the content's
        // layout; without this, the window itself can still be dragged
        // smaller than that (e.g. from its left edge), squeezing the fixed-
        // width sidebar's neighbors. `.contentMinSize` makes that frame's
        // minimum an actual floor on the window's resize handles.
        .windowResizability(.contentMinSize)
        .commands {
            // The system's default "About EZ Exif" panel already pulls its
            // icon from `CFBundleIconFile`/`CFBundleIconName` in Info.plist
            // automatically — this replaces it with an explicit call anyway,
            // passing `NSApp.applicationIconImage` (the same value AppKit
            // resolves from those same Info.plist keys) directly as the
            // `.applicationIcon` option, so the logo showing up there isn't
            // left to implicit default-panel resolution.
            CommandGroup(replacing: .appInfo) {
                Button(Self.localizedAppNameTitle("About %@")) {
                    var options: [NSApplication.AboutPanelOptionKey: Any] = [
                        .applicationIcon: NSApp.applicationIconImage as Any
                    ]
                    let isDark = (preferredColorScheme ?? systemColorScheme) == .dark
                    if let credits = Self.authorLogoCredits(dark: isDark) {
                        options[.credits] = credits
                    }
                    NSApplication.shared.orderFrontStandardAboutPanel(options: options)
                }
            }
            CommandGroup(replacing: .newItem) {
                Button("Open Photos") {
                    library.presentOpenPanel()
                }
                .keyboardShortcut("o", modifiers: .command)
                Button("Import Folder") {
                    library.presentImportFolderPanel()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }
            CommandGroup(after: .saveItem) {
                Button("Save Metadata") {
                    library.saveAll()
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(library.items.isEmpty)
            }
            // Replaces the default Help menu (which otherwise only has the
            // built-in search field and no actual content) with two real
            // items — the general guide and, isolated as its own entry/
            // window rather than a section within it, Keyboard Shortcuts.
            // `⌘?` is the same shortcut macOS's own Help menu item uses.
            CommandGroup(replacing: .help) {
                Button(Self.localizedAppNameTitle("%@ Help")) {
                    openWindow(id: "help")
                }
                .keyboardShortcut("?", modifiers: .command)
                Button("Keyboard Shortcuts") {
                    openWindow(id: "shortcuts")
                }
            }
        }

        Settings {
            SettingsView(presetStore: presetStore, router: settingsRouter)
                .environmentObject(fieldVisibility)
                .preferredColorScheme(preferredColorScheme)
        }

        Window("Help", id: "help") {
            HelpView()
        }
        .windowResizability(.contentSize)

        Window("Keyboard Shortcuts", id: "shortcuts") {
            KeyboardShortcutsView()
        }
        .windowResizability(.contentSize)
    }
}

/// Intercepts Cmd+Q / the Quit menu item so "Warn Before Quitting with
/// Unsaved Changes" (Settings → General) can actually block termination —
/// there's no pure-SwiftUI hook for this, so it needs an `NSApplication`-
/// level delegate. `library` is injected once `ContentView` appears, since
/// `AppDelegate` itself is constructed by `@NSApplicationDelegateAdaptor`
/// before any `@StateObject` in `FilmExifApp` is available.
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var library: PhotoLibrary?

    /// Without this, clicking the window's red close button just closes the
    /// window — the app itself keeps running (still in the Dock, no window)
    /// until something else quits it, which is normal behavior for most Mac
    /// apps but not what a single-window utility like this one wants.
    /// Returning `true` makes AppKit call `terminate(_:)` once the last
    /// window closes, which in turn still runs `applicationShouldTerminate`
    /// below — so the unsaved-changes warning applies to the red button
    /// exactly the same way it already does to Cmd+Q.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let defaults = UserDefaults.standard
        let warnBeforeQuit = defaults.object(forKey: AppSettingsKeys.warnBeforeQuitWithUnsavedChanges) as? Bool ?? true
        guard warnBeforeQuit, let library, library.items.contains(where: { $0.isDirty }) else {
            return .terminateNow
        }
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Unsaved Changes", comment: "Quit confirmation alert title")
        alert.informativeText = NSLocalizedString(
            "Some photos have unsaved metadata changes. Quit anyway?",
            comment: "Quit confirmation alert message"
        )
        alert.addButton(withTitle: NSLocalizedString("Quit Anyway", comment: "Quit confirmation button"))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "Quit confirmation button"))
        return alert.runModal() == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
    }
}
