import Foundation
import AppKit
import Combine

/// Owns the list of currently-open photos, handles the Open panel, thumbnail
/// loading, and batch save.
final class PhotoLibrary: ObservableObject {
    @Published var items: [PhotoItem] = [] {
        didSet { observeItemChanges() }
    }
    // Selecting a photo (however it happens — a sidebar click, or the
    // auto-select right after import) must never leave it unloaded: both
    // editors read straight from `item.edited`/`original`, and a batch
    // edit or Save would otherwise merge onto/write out a blank
    // `FilmMetadata()` instead of the file's real content.
    @Published var selection: Set<PhotoItem.ID> = [] {
        didSet { ensureLoaded(selectedItems) }
    }
    @Published var isSavingAll: Bool = false
    @Published var lastSaveSummary: String?
    /// The batch editor's draft fields when multiple photos are selected —
    /// lives here (not as `@State` inside `BatchEditorView`) so applying a
    /// preset while several photos are selected can write into it directly
    /// and have the change actually show up in the editor, rather than
    /// only reaching each photo's `edited` metadata invisibly.
    @Published var batchDraft: FilmMetadata = FilmMetadata()
    /// Bumped whenever a preset is applied, so the editor views can scroll
    /// the affected section into view. Carries the category (so the editor
    /// knows which section) plus a fresh id each time, so applying the same
    /// category twice in a row still triggers `onChange` (a repeated
    /// `category` value alone wouldn't count as a change).
    @Published var lastPresetApply: PresetApplyEvent?
    /// Bumped whenever Undo actually changes something, so the editor views
    /// can scroll the affected section into view — same mechanism as
    /// `lastPresetApply`, just carrying a section id directly instead of a
    /// `PresetCategory`, since an undone change isn't tied to any category.
    @Published var lastUndoScroll: ScrollTarget?

    struct PresetApplyEvent: Equatable {
        let category: PresetCategory
        private let id = UUID()
    }

    struct ScrollTarget: Equatable {
        let sectionID: String
        private let id = UUID()
    }

    var selectedItems: [PhotoItem] {
        items.filter { selection.contains($0.id) }
    }

    /// Forwards each item's own `objectWillChange` up to the library's —
    /// without this, a view that only holds `@EnvironmentObject var
    /// library` (not an `@ObservedObject` on the specific `PhotoItem`) has
    /// no way to know an item changed when something *outside* the library
    /// mutates it directly (e.g. `AutoNumberExposuresView.apply()` writes
    /// straight into each `item.edited`). That left aggregate checks like
    /// the batch editor's "is anything selected still dirty?" (driving the
    /// Revert button's enabled state) stuck showing whatever was true the
    /// last time the library itself changed, rather than the current state.
    private var itemChangeCancellables: [AnyCancellable] = []

    private func observeItemChanges() {
        itemChangeCancellables = items.map { item in
            item.objectWillChange
                // Deferred to the next run loop turn, not sent inline —
                // `objectWillChange.send()` here happens synchronously
                // inside whatever caused the item to change, which could be
                // AppKit still in the middle of handling its own event (e.g.
                // an NSComboBox mid-way through committing a selection).
                // Forwarding immediately let that reentrantly trigger a
                // SwiftUI re-render before AppKit finished, which is what
                // caused a freshly-selected combo box value to flash and
                // then revert to the old one.
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.objectWillChange.send()
                }
        }
    }

    /// The single "Open" panel, used both from the toolbar and the empty
    /// start page — lets you pick photo files, folders, or a mix of both in
    /// one window, rather than needing a separate folder-import dialog.
    /// No `allowedContentTypes` here — combining it with
    /// `canChooseDirectories` makes the panel evaluate every visible item
    /// against the type filter just to decide whether to gray it out,
    /// which is the "Open Photos was slow" lag on any folder with a lot of
    /// files (Desktop, Downloads, Pictures...). `load(urls:)` already
    /// silently skips anything that isn't a supported image via
    /// `ExifXMPService.isSupportedImage`, so nothing is lost — you can just
    /// select a non-image file in the panel and it'll be ignored.
    func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.title = "Open Film Scans"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.begin { [weak self] response in
            guard response == .OK else { return }
            self?.load(urls: panel.urls)
        }
    }

    func presentImportFolderPanel() {
        let panel = NSOpenPanel()
        panel.title = "Import Folder of Film Scans"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.begin { [weak self] response in
            guard response == .OK else { return }
            self?.load(urls: panel.urls)
        }
    }

    /// Loads `urls`, transparently recursing into any directories among
    /// them (so both an explicit folder import and a plain folder drag
    /// onto the window pick up every supported image inside, at any depth).
    ///
    /// Only a file that's actually visible right away — one opened
    /// directly, or one sitting straight inside a chosen folder (not one of
    /// its subfolders) — gets its metadata/thumbnail read eagerly here. A
    /// file inside a subfolder stays unloaded (see `PhotoItem.isContentLoaded`)
    /// until the sidebar actually expands that subfolder and calls
    /// `ensureLoaded`, since the top-level folder starts expanded in the
    /// sidebar but every subfolder underneath it starts collapsed — reading
    /// and decoding every photo in a large imported album up front would be
    /// wasted work for whatever stays collapsed.
    func load(urls: [URL]) {
        // Each file remembers its own immediate containing folder (if any)
        // plus the top-level folder actually chosen to import it, so the
        // sidebar can rebuild the real subfolder hierarchy as a tree — a
        // file passed in directly (not via a folder) gets neither and
        // stays ungrouped.
        var fileURLs: [(url: URL, folder: URL?, root: URL?)] = []
        let fm = FileManager.default
        for url in urls {
            var isDirectory: ObjCBool = false
            if fm.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
                fileURLs.append(contentsOf: Self.supportedImages(inFolder: url).map { ($0.url, $0.folder, url) })
            } else {
                fileURLs.append((url, nil, nil))
            }
        }

        var newItems: [PhotoItem] = []
        for (url, folder, root) in fileURLs where ExifXMPService.isSupportedImage(url) {
            if items.contains(where: { $0.url == url }) { continue }
            let item = PhotoItem(url: url, sourceFolder: folder, importRoot: root)
            items.append(item)
            newItems.append(item)
        }
        // A loose file (no `root`) and anything sitting directly inside the
        // chosen folder itself (`folder == root`) is visible the instant
        // import finishes, so it's loaded now rather than waiting on a
        // sidebar expansion that already happened by default.
        let visibleByDefault = newItems.filter { $0.importRoot == nil || $0.sourceFolder == $0.importRoot }
        ensureLoaded(visibleByDefault)
        // Auto-selecting `items.first` unconditionally could land on a
        // photo inside a subfolder that starts collapsed — its row
        // wouldn't even be in the sidebar yet, making the list look like
        // nothing is selected while the editor shows that hidden photo's
        // metadata. Preferring whatever's already visible avoids that;
        // only an import with no visible photos at all (every file nested
        // in a subfolder, nothing loose at the top level) falls back to
        // picking something hidden, since there's no visible photo to pick.
        if selection.isEmpty, let first = visibleByDefault.first ?? items.first {
            selection = [first.id]
        }
    }

    /// Reads `item`'s metadata/thumbnail/pixel size/file size from disk if
    /// it hasn't been already — the one place actual file I/O happens for a
    /// photo, called both eagerly (for whatever's visible right after
    /// import) and lazily (when the sidebar expands the folder it's in, or
    /// it becomes selected). A no-op if already loaded, so calling it
    /// repeatedly (e.g. every time a folder is expanded) is harmless.
    func ensureLoaded(_ item: PhotoItem) {
        guard !item.isContentLoaded else { return }
        item.isContentLoaded = true
        let (meta, pixelWidth, pixelHeight) = ExifXMPService.readMetadata(from: item.url)
        item.setLoadedMetadata(meta)
        Self.applyImportDefaults(to: item)
        item.thumbnail = Self.loadThumbnail(url: item.url)
        item.pixelWidth = pixelWidth
        item.pixelHeight = pixelHeight
        item.fileSizeBytes = Self.fileSizeBytes(at: item.url)
    }

    func ensureLoaded(_ items: [PhotoItem]) {
        for item in items { ensureLoaded(item) }
    }

    /// Stages Settings → General → Defaults into a freshly imported photo —
    /// Photographer/Copyright only into whichever of the two the file
    /// didn't already have its own value for, and the Camera/Lens/Film
    /// presets (each only when individually enabled and a preset is
    /// actually chosen), applied as a whole only when every field that
    /// preset would set is still empty in the file (see
    /// `applyPresetToEmptyFields`) — so an import never overwrites, or
    /// partially overlays, fields the file already had real values for.
    /// Everything lands in `edited` (never `original`), so the photo shows
    /// as unsaved until confirmed by saving, and can still be edited or
    /// cleared first if it's wrong for this particular roll.
    private static func applyImportDefaults(to item: PhotoItem) {
        let defaults = UserDefaults.standard
        // `bool(forKey:)` alone would read a not-yet-set key as `false` —
        // this key's `@AppStorage` default in Settings is `true`, so a
        // missing key (nobody has opened that toggle yet) needs to be
        // treated as "on" too, to match what the toggle would show.
        let applyDefaults = defaults.object(forKey: AppSettingsKeys.applyDefaultsToImports) as? Bool ?? true
        guard applyDefaults else { return }

        let photographerEnabled = defaults.object(forKey: AppSettingsKeys.defaultPhotographerEnabled) as? Bool ?? true
        if photographerEnabled, item.edited.artist.isEmpty,
           let name = defaults.string(forKey: AppSettingsKeys.defaultPhotographer), !name.isEmpty {
            item.edited.artist = name
        }
        let copyrightEnabled = defaults.object(forKey: AppSettingsKeys.defaultCopyrightEnabled) as? Bool ?? true
        if copyrightEnabled, item.edited.copyright.isEmpty,
           let copyright = defaults.string(forKey: AppSettingsKeys.defaultCopyright), !copyright.isEmpty {
            item.edited.copyright = copyright
        }

        let presetDefaults: [(enabledKey: String, presetIDKey: String, category: PresetCategory)] = [
            (AppSettingsKeys.defaultExposureSettingsEnabled, AppSettingsKeys.defaultExposureSettingsPresetID, .exposureSettings),
            (AppSettingsKeys.defaultCameraEnabled, AppSettingsKeys.defaultCameraPresetID, .cameraBody),
            (AppSettingsKeys.defaultLensEnabled, AppSettingsKeys.defaultLensPresetID, .lens),
            (AppSettingsKeys.defaultFilmEnabled, AppSettingsKeys.defaultFilmPresetID, .film)
        ]
        let enabledPresetIDs: [(PresetCategory, UUID)] = presetDefaults.compactMap { entry in
            guard defaults.object(forKey: entry.enabledKey) as? Bool ?? false,
                  let idString = defaults.string(forKey: entry.presetIDKey), !idString.isEmpty,
                  let id = UUID(uuidString: idString) else { return nil }
            return (entry.category, id)
        }
        guard !enabledPresetIDs.isEmpty else { return }
        let presets = PresetStore.loadPersisted()
        for (category, id) in enabledPresetIDs {
            guard let preset = presets.first(where: { $0.id == id && $0.category == category }) else { continue }
            applyPresetToEmptyFields(preset.metadata, category: category, into: &item.edited)
        }
    }

    /// Like `PresetCategory.apply(_:to:)`, but all-or-nothing: applies the
    /// preset only when every field it would actually set (i.e. every field
    /// non-empty in `preset`) is still empty in `metadata`. Unlike clicking
    /// a preset by hand (which deliberately overwrites), an import default
    /// shouldn't clobber real camera/lens/film info the file's own EXIF
    /// already carried — and a partial overlay (some of the preset's fields
    /// landing, others silently skipped because the file already had
    /// something there) would leave the photo in a mixed state that's
    /// harder to notice than either "fully applied" or "left alone".
    private static func applyPresetToEmptyFields(_ preset: FilmMetadata, category: PresetCategory, into metadata: inout FilmMetadata) {
        let coveredSpecs = category.allApplicableFixedFieldSpecs.filter { !preset[keyPath: $0.keyPath].isEmpty }
        guard !coveredSpecs.isEmpty else { return }
        guard coveredSpecs.allSatisfy({ metadata[keyPath: $0.keyPath].isEmpty }) else { return }
        for spec in coveredSpecs {
            metadata[keyPath: spec.keyPath] = preset[keyPath: spec.keyPath]
        }
    }

    /// Every image inside `url`, at any depth — recurses into subfolders
    /// (e.g. one folder per roll under an album folder) rather than only
    /// picking up images directly inside `url` itself. Returns each file
    /// alongside its own immediate containing folder, both reconstructed by
    /// appending path components onto `url` by hand (via
    /// `FileManager.contentsOfDirectory`, which only needs to name what's
    /// *inside* a folder, not resolve the folder's own path) rather than
    /// trusting a recursive enumerator's own absolute URLs — `FileManager`'s
    /// `.enumerator(at:)` can hand back paths through a resolved symlink
    /// (famously `/tmp` → `/private/tmp`) that no longer share a common
    /// prefix with the original `url`, which broke every "is this file
    /// directly inside `url`?" comparison downstream.
    private static func supportedImages(inFolder url: URL) -> [(url: URL, folder: URL)] {
        var results: [(url: URL, folder: URL)] = []
        func recurse(_ folder: URL) {
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { return }
            for entry in contents {
                let isDirectory = (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                let name = entry.lastPathComponent
                if isDirectory {
                    recurse(folder.appendingPathComponent(name, isDirectory: true))
                } else {
                    let fileURL = folder.appendingPathComponent(name)
                    if ExifXMPService.isSupportedImage(fileURL) {
                        results.append((fileURL, folder))
                    }
                }
            }
        }
        recurse(url)
        return results
    }

    func reload(_ item: PhotoItem) {
        let (meta, pixelWidth, pixelHeight) = ExifXMPService.readMetadata(from: item.url)
        item.setLoadedMetadata(meta)
        item.pixelWidth = pixelWidth
        item.pixelHeight = pixelHeight
        item.fileSizeBytes = Self.fileSizeBytes(at: item.url)
    }

    private static func fileSizeBytes(at url: URL) -> Int64? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else { return nil }
        return (attributes[.size] as? NSNumber)?.int64Value
    }

    func save(_ item: PhotoItem) {
        // A last line of defense — the Save buttons in both editors are
        // already disabled while a numeric field is invalid, but this
        // guards every path to a write (including `saveAll()`'s loop)
        // against ever putting bad EXIF data on disk.
        guard !item.edited.hasInvalidNumericField else {
            item.lastError = NSLocalizedString(
                "Fix the highlighted fields before saving.",
                comment: "PhotoLibrary save error: a numeric field (ISO, Aperture, etc.) has an invalid value"
            )
            return
        }
        item.isSaving = true
        item.lastError = nil
        do {
            try ExifXMPService.write(item.edited, to: item.url)
            item.original = item.edited
            item.thumbnail = Self.loadThumbnail(url: item.url)
            // Pixel dimensions never change from a metadata-only write, but
            // the file's size on disk does (more/less XMP data).
            item.fileSizeBytes = Self.fileSizeBytes(at: item.url)
        } catch {
            item.lastError = error.localizedDescription
        }
        item.isSaving = false
    }

    func saveAll() {
        isSavingAll = true
        var succeeded = 0
        var failed = 0
        for item in items where item.isDirty {
            save(item)
            if item.lastError == nil { succeeded += 1 } else { failed += 1 }
        }
        isSavingAll = false
        if succeeded == 0 && failed == 0 {
            lastSaveSummary = "Nothing to save."
        } else if failed == 0 {
            lastSaveSummary = "Saved \(succeeded) file\(succeeded == 1 ? "" : "s")."
        } else {
            lastSaveSummary = "Saved \(succeeded), failed \(failed)."
        }
    }

    /// Applies `metadata` (non-empty fields only) to every currently
    /// selected item — the "apply this roll's info to the whole batch"
    /// action.
    func applyToSelection(_ metadata: FilmMetadata) {
        for item in selectedItems {
            item.edited = item.edited.merging(overridingWith: metadata)
        }
    }

    func remove(_ item: PhotoItem) {
        items.removeAll { $0.id == item.id }
        selection.remove(item.id)
    }

    /// Batch form of `remove(_:)` — used by "Remove from list" when it's
    /// invoked (via right-click) on a row that's part of a multi-photo
    /// selection, so it removes the whole selection rather than just the
    /// one row the context menu happened to be opened on.
    func remove(_ itemsToRemove: [PhotoItem]) {
        let ids = Set(itemsToRemove.map(\.id))
        items.removeAll { ids.contains($0.id) }
        selection.subtract(ids)
    }

    private static func loadThumbnail(url: URL, maxPixelSize: Int = 220) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let cgThumb = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return NSImage(cgImage: cgThumb, size: .zero)
    }
}
