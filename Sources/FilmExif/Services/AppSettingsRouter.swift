import Foundation

/// Shared between the main window and the Settings window so a button in
/// the main window (e.g. "Manage Presets") can make the Settings window
/// land on a specific tab, optionally already creating a new preset in a
/// given category.
final class AppSettingsRouter: ObservableObject {
    @Published var selectedTab: SettingsTab = .general
    @Published var pendingNewPresetCategory: PresetCategory?
    /// Set by "Edit" on a preset's context menu in the preset panel, so the
    /// Presets tab lands with that specific preset already selected for
    /// editing instead of the plain list or a "create new" form.
    @Published var pendingEditPresetID: FilmPreset.ID?
    /// Bumped on every `prepareOpenPresets`/`prepareEditPreset` call, even
    /// ones that leave `pendingNewPresetCategory` at `nil` — a plain
    /// `nil -> nil` transition (e.g. two "Manage Presets" clicks in a row)
    /// wouldn't otherwise trigger `onChange`, leaving the Presets tab stuck
    /// showing whatever category was last requested instead of resetting to
    /// the plain list.
    @Published var presetsNavigationRequestID = UUID()
    /// A snapshot of "what's currently shown in the main window", so the
    /// Presets tab's "Copy Current Values" still works even though it opens
    /// in a separate window.
    @Published var currentMetadataSnapshot: FilmMetadata = FilmMetadata()

    /// Sets up state for the Presets tab; the caller still needs to actually
    /// open the Settings window (via `@Environment(\.openSettings)`, which
    /// only works from inside a View — this router is a plain object).
    func prepareOpenPresets(newPresetIn category: PresetCategory? = nil) {
        pendingNewPresetCategory = category
        pendingEditPresetID = nil
        presetsNavigationRequestID = UUID()
        selectedTab = .presets
    }

    /// Sets up the Presets tab to land directly on `id`'s edit form —
    /// used by "Edit" on a preset's context menu.
    func prepareEditPreset(_ id: FilmPreset.ID) {
        pendingNewPresetCategory = nil
        pendingEditPresetID = id
        presetsNavigationRequestID = UUID()
        selectedTab = .presets
    }
}
