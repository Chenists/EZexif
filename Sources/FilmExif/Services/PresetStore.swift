import Foundation

/// Persists user-created film presets as JSON in Application Support.
final class PresetStore: ObservableObject {
    @Published var presets: [FilmPreset] = []

    private static let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FilmExif", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("presets.json")
    }()

    init() {
        load()
    }

    func load() {
        let fileExisted = FileManager.default.fileExists(atPath: Self.fileURL.path)
        presets = Self.loadPersisted()
        // First launch (no presets.json yet) — write the built-ins out so
        // the file exists from here on, same as before this was split into
        // a static `loadPersisted()`.
        if !fileExisted { save() }
    }

    func save() {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }

    /// Reads presets straight from disk without needing a `PresetStore`
    /// instance — used by `PhotoLibrary` to look up a chosen Camera/Lens/
    /// Film default preset when importing, since import can happen before
    /// (or entirely independent of) the app's own `@StateObject` preset
    /// store being consulted.
    static func loadPersisted() -> [FilmPreset] {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([FilmPreset].self, from: data) else {
            return FilmPreset.builtIns
        }
        return decoded
    }

    func add(_ preset: FilmPreset) {
        presets.append(preset)
        save()
    }

    /// Replaces the preset with a matching `id` if one exists, else appends.
    func upsert(_ preset: FilmPreset) {
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[index] = preset
        } else {
            presets.append(preset)
        }
        save()
    }

    func remove(_ preset: FilmPreset) {
        presets.removeAll { $0.id == preset.id }
        save()
    }
}
