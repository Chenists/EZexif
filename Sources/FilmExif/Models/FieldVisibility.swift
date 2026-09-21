import Foundation

/// One property row the main/batch editors can be configured to show or
/// hide, via Settings → Fields. Identified by its own display label — the
/// same string already used as that row's on-screen label everywhere else
/// in the app, so there's a single name to keep in sync rather than a
/// separate key scheme.
struct ToggleableField: Identifiable {
    let label: String
    var id: String { label }
}

struct ToggleableFieldGroup: Identifiable {
    let title: String
    let fields: [ToggleableField]
    var id: String { title }
}

/// Every field the main/batch editors show, grouped exactly the way those
/// editors group them (`FieldGroup` by `FieldGroup`) — the single source of
/// truth for both the Settings → Fields toggle list and the editors' own
/// visibility checks, so the two can never drift apart.
enum FieldVisibilityRegistry {
    static let groups: [ToggleableFieldGroup] = [
        ToggleableFieldGroup(title: "Basics", fields: [
            "ISO", "Aperture", "Shutter Speed", "Exposure Bias", "Focal Length",
            "35mm Equivalent Focal Length", "Exposure Program", "White Balance",
            "Metering Mode", "Capture Time", "Location", "Altitude", "Rating"
        ].map(ToggleableField.init)),
        ToggleableFieldGroup(title: "File", fields: [
            "File Source", "Is Film Photo"
        ].map(ToggleableField.init)),
        ToggleableFieldGroup(title: "Photographer & Copyright", fields: [
            "Photographer", "Copyright"
        ].map(ToggleableField.init)),
        ToggleableFieldGroup(title: "Camera & Lens", fields: [
            "Camera Make", "Camera Model", "Camera Serial Number", "Camera Firmware",
            "Camera Owner Name", "Lens Make", "Lens Model", "Lens Serial Number",
            "Lens Specification"
        ].map(ToggleableField.init)),
        ToggleableFieldGroup(title: "Film", fields: [
            "Manufacturer", "Name", "Film Type", "Format", "Film ISO", "DX Code",
            "Film Batch", "Emulsion Number", "Base", "Film Grain"
        ].map(ToggleableField.init)),
        ToggleableFieldGroup(title: "Roll", fields: [
            "Roll ID", "Frame Number", "Total Frame Count", "Exposure ISO", "Loaded Date",
            "Finished Date", "Development Batch"
        ].map(ToggleableField.init)),
        ToggleableFieldGroup(title: "Development", fields: [
            "Process", "Developer", "Developer Manufacturer", "Developer Dilution",
            "Development Time", "Development Duration", "Development Temperature",
            "Push/Pull", "Bleach", "Fixer", "Stabilizer", "Replenishment", "Chemistry Notes"
        ].map(ToggleableField.init)),
        ToggleableFieldGroup(title: "Lab", fields: [
            "Lab Name", "Lab Address", "Lab Contact", "Lab Notes"
        ].map(ToggleableField.init)),
        ToggleableFieldGroup(title: "Scanning", fields: [
            "Scanner Make", "Scanner Model", "Scanner Serial Number",
            "Scanner Software", "Scan Resolution", "Bit Depth", "Color Space",
            "Scan Type", "Scan Date", "Dust Removal", "Infrared Cleaning",
            "Scan Notes"
        ].map(ToggleableField.init)),
        ToggleableFieldGroup(title: "Notes", fields: [
            "Notes"
        ].map(ToggleableField.init))
    ]
}

/// Which fields are currently hidden from the main/batch editors — shared
/// between the Settings → Fields toggles and the editors themselves via
/// `.environmentObject`. Persisted as a plain `UserDefaults` string array
/// (everything visible, i.e. an empty hidden set, is the factory default,
/// so fields added in a future update start visible automatically instead
/// of needing to be explicitly turned on) — separately from
/// `defaultHiddenFieldLabels`, the snapshot "Reset to Default" restores,
/// which is whatever selection was in effect the first time this feature
/// shipped, not necessarily "everything visible".
final class FieldVisibilityStore: ObservableObject {
    @Published private(set) var hiddenFields: Set<String>

    init() {
        let defaults = UserDefaults.standard
        var hidden = Set(defaults.stringArray(forKey: AppSettingsKeys.hiddenFieldLabels) ?? [])

        // "Metering Mode" is new and, unlike every other Basics field,
        // starts hidden rather than shown — seeded once, into both the
        // active selection and whatever "Reset to Default" restores, so it
        // doesn't silently appear for someone who never asked for it. Its
        // own one-shot flag (rather than just checking whether the label is
        // already absent from `hidden`) is what lets this apply exactly
        // once: "absent from `hidden`" is otherwise ambiguous between "this
        // field is brand new" and "the user already turned it back on."
        if !defaults.bool(forKey: AppSettingsKeys.hasSeededMeteringModeDefault) {
            hidden.insert("Metering Mode")
            defaults.set(Array(hidden), forKey: AppSettingsKeys.hiddenFieldLabels)
            var defaultHidden = Set(defaults.stringArray(forKey: AppSettingsKeys.defaultHiddenFieldLabels) ?? [])
            defaultHidden.insert("Metering Mode")
            defaults.set(Array(defaultHidden), forKey: AppSettingsKeys.defaultHiddenFieldLabels)
            defaults.set(true, forKey: AppSettingsKeys.hasSeededMeteringModeDefault)
        }

        // Same one-shot seeding as "Metering Mode" above, for the same
        // reason: new, and starting hidden rather than shown, so it doesn't
        // silently appear for someone who never asked for it.
        if !defaults.bool(forKey: AppSettingsKeys.hasSeededFocalLengthIn35mmFormatDefault) {
            hidden.insert("35mm Equivalent Focal Length")
            defaults.set(Array(hidden), forKey: AppSettingsKeys.hiddenFieldLabels)
            var defaultHidden = Set(defaults.stringArray(forKey: AppSettingsKeys.defaultHiddenFieldLabels) ?? [])
            defaultHidden.insert("35mm Equivalent Focal Length")
            defaults.set(Array(defaultHidden), forKey: AppSettingsKeys.defaultHiddenFieldLabels)
            defaults.set(true, forKey: AppSettingsKeys.hasSeededFocalLengthIn35mmFormatDefault)
        }

        hiddenFields = hidden
        // Captured once, the first time this ships: whatever the user
        // already had selected becomes "the default" to reset back to,
        // rather than silently discarding their existing choices in favor
        // of a fixed "everything visible" factory default. The same applies
        // to the temperature unit and aperture display format, which live
        // in this same settings screen and are restored by the same
        // "Reset to Default" button.
        if defaults.object(forKey: AppSettingsKeys.defaultHiddenFieldLabels) == nil {
            defaults.set(Array(hiddenFields), forKey: AppSettingsKeys.defaultHiddenFieldLabels)
        }
        if defaults.object(forKey: AppSettingsKeys.defaultTemperatureUnit) == nil {
            let current = defaults.string(forKey: AppSettingsKeys.temperatureUnit) ?? TemperatureUnit.celsius.rawValue
            defaults.set(current, forKey: AppSettingsKeys.defaultTemperatureUnit)
        }
        if defaults.object(forKey: AppSettingsKeys.defaultApertureDisplayFormat) == nil {
            let current = defaults.string(forKey: AppSettingsKeys.apertureDisplayFormat) ?? ApertureDisplayFormat.number.rawValue
            defaults.set(current, forKey: AppSettingsKeys.defaultApertureDisplayFormat)
        }
    }

    func isVisible(_ label: String) -> Bool { !hiddenFields.contains(label) }

    /// True if at least one field in `labels` is visible — used to hide an
    /// entire `FieldGroup` section once every field inside it has been
    /// turned off, instead of leaving an empty titled box behind.
    func isAnyVisible(_ labels: [String]) -> Bool {
        labels.contains { isVisible($0) }
    }

    func setVisible(_ visible: Bool, for label: String) {
        if visible {
            hiddenFields.remove(label)
        } else {
            hiddenFields.insert(label)
        }
        UserDefaults.standard.set(Array(hiddenFields), forKey: AppSettingsKeys.hiddenFieldLabels)
    }

    /// Restores the selection saved as the default (see `init`) — the
    /// "Reset to Default" button in Settings → Fields. Also restores the
    /// temperature unit and aperture display format shown alongside their
    /// fields on that same screen, since visually they're part of the same
    /// "reset this screen" gesture even though they're plain `@AppStorage`
    /// values the view itself owns, not part of `hiddenFields`.
    func resetToDefault() {
        let defaults = UserDefaults.standard
        hiddenFields = Set(defaults.stringArray(forKey: AppSettingsKeys.defaultHiddenFieldLabels) ?? [])
        defaults.set(Array(hiddenFields), forKey: AppSettingsKeys.hiddenFieldLabels)
        defaults.set(
            defaults.string(forKey: AppSettingsKeys.defaultTemperatureUnit) ?? TemperatureUnit.celsius.rawValue,
            forKey: AppSettingsKeys.temperatureUnit
        )
        defaults.set(
            defaults.string(forKey: AppSettingsKeys.defaultApertureDisplayFormat) ?? ApertureDisplayFormat.number.rawValue,
            forKey: AppSettingsKeys.apertureDisplayFormat
        )
    }
}
