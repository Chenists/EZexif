import SwiftUI

/// `UserDefaults` keys shared between the SwiftUI settings screens
/// (via `@AppStorage`) and the plain services that read them directly
/// (`ExifXMPService`, which isn't a view).
enum AppSettingsKeys {
    static let displayMode = "displayMode"
    static let createBackupFiles = "createBackupFiles"
    static let jpegCompressionQuality = "jpegCompressionQuality"
    static let saveToCustomFolder = "saveToCustomFolder"
    static let customSaveFolderPath = "customSaveFolderPath"
    static let hiddenFieldLabels = "hiddenFieldLabels"
    static let defaultHiddenFieldLabels = "defaultHiddenFieldLabels"
    static let defaultPhotographer = "defaultPhotographer"
    static let defaultCopyright = "defaultCopyright"
    static let applyDefaultsToImports = "applyDefaultsToImports"
    static let defaultPhotographerEnabled = "defaultPhotographerEnabled"
    static let defaultCopyrightEnabled = "defaultCopyrightEnabled"
    static let defaultExposureSettingsPresetID = "defaultExposureSettingsPresetID"
    static let defaultExposureSettingsEnabled = "defaultExposureSettingsEnabled"
    static let defaultCameraPresetID = "defaultCameraPresetID"
    static let defaultCameraEnabled = "defaultCameraEnabled"
    static let defaultLensPresetID = "defaultLensPresetID"
    static let defaultLensEnabled = "defaultLensEnabled"
    static let defaultFilmPresetID = "defaultFilmPresetID"
    static let defaultFilmEnabled = "defaultFilmEnabled"
    static let thumbnailSize = "thumbnailSize"
    static let temperatureUnit = "temperatureUnit"
    static let defaultTemperatureUnit = "defaultTemperatureUnit"
    static let warnBeforeQuitWithUnsavedChanges = "warnBeforeQuitWithUnsavedChanges"
    static let hasSeededMeteringModeDefault = "hasSeededMeteringModeDefault"
    static let hasSeededFocalLengthIn35mmFormatDefault = "hasSeededFocalLengthIn35mmFormatDefault"
    static let apertureDisplayFormat = "apertureDisplayFormat"
    static let defaultApertureDisplayFormat = "defaultApertureDisplayFormat"
}

/// The app's current display language, derived from `AppleLanguages` the
/// same way `GeneralSettingsView` picks a code for its own language picker
/// — shared here so non-view code (`FieldSuggestions`, which can't use
/// `LocalizedStringKey`/`Text` at all) can pick the right translation for
/// its fixed enum-style option lists (Exposure Program, Metering Mode,
/// File Source, etc.) without duplicating this lookup.
enum AppLanguage {
    static func currentCode() -> String {
        guard let languages = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String],
              let first = languages.first else {
            return "en"
        }
        if first.hasPrefix("zh") { return "zh-Hans" }
        if first.hasPrefix("es") { return "es" }
        return "en"
    }
}

/// How large each row's thumbnail renders in the photo list sidebar.
enum ThumbnailSize: String, CaseIterable, Identifiable {
    case small, medium, large

    var id: String { rawValue }

    var title: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }

    var pixels: CGFloat {
        switch self {
        case .small: return 20
        case .medium: return 28
        case .large: return 40
        }
    }
}

/// The unit "Development Temperature" is entered/shown in — set in
/// Settings → Fields, right next to that field's own visibility toggle,
/// since it only means anything once you know whether that field is even
/// shown.
enum TemperatureUnit: String, CaseIterable, Identifiable {
    case celsius, fahrenheit

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .celsius: return "°C"
        case .fahrenheit: return "°F"
        }
    }
}

/// How "Aperture" is displayed/typed — set in Settings → Fields, right next
/// to that field's own visibility toggle. Purely a presentation choice: the
/// stored value is always a bare number (what EXIF's FNumber tag needs), so
/// this never touches reading/writing or numeric validation, only what the
/// field shows and what its suggestion list looks like.
enum ApertureDisplayFormat: String, CaseIterable, Identifiable {
    case number, fStop

    var id: String { rawValue }

    /// A short, self-explanatory segment label rather than a full sentence,
    /// since it sits in a compact segmented control next to the toggle.
    var segmentLabel: String {
        switch self {
        case .number: return "2.8"
        case .fStop: return "f/2.8"
        }
    }
}

enum DisplayMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// The Settings window's tabs.
enum SettingsTab: String, CaseIterable, Identifiable {
    case general, saving, fields, presets

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .saving: return "Saving"
        case .fields: return "Fields"
        case .presets: return "Presets"
        }
    }

    var systemImage: String {
        switch self {
        case .general: return "gearshape"
        case .saving: return "square.and.arrow.down"
        case .fields: return "checklist"
        case .presets: return "list.bullet.rectangle"
        }
    }
}
