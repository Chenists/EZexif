import Foundation
import AppKit

/// One loaded photo: its file URL, a thumbnail, the metadata as currently
/// read from disk, and the metadata as edited in the UI (dirty state).
final class PhotoItem: ObservableObject, Identifiable, Hashable {
    let id = UUID()
    let url: URL
    /// The immediate folder this file was found in — set for a file picked
    /// up by choosing a folder in the Open panel (or dragging one onto the
    /// window), so the sidebar can group photos by their containing folder.
    /// For a file nested inside a subfolder of the chosen folder, this is
    /// that subfolder, not the top-level folder that was chosen — see
    /// `importRoot` for that. `nil` for an individually-chosen file.
    let sourceFolder: URL?
    /// The top-level folder actually chosen/dropped to import this file —
    /// the same for every file found anywhere underneath it, however
    /// deeply nested, unlike `sourceFolder`. The sidebar uses this (plus
    /// each file's `sourceFolder`) to rebuild the real subfolder hierarchy
    /// as a tree instead of a flat list of same-level folder sections.
    /// `nil` for an individually-chosen file, same as `sourceFolder`.
    let importRoot: URL?

    @Published var thumbnail: NSImage?
    @Published var original: FilmMetadata = FilmMetadata()
    @Published var edited: FilmMetadata = FilmMetadata() {
        didSet {
            guard !isRestoringState else { return }
            recordUndoSnapshot(previous: oldValue)
        }
    }
    @Published var lastError: String?
    @Published var isSaving: Bool = false
    /// Whether `PhotoLibrary.ensureLoaded` has actually read this file's
    /// metadata/thumbnail yet — a photo inside a collapsed sidebar
    /// subfolder starts `false` and stays that way (its `edited`/`original`
    /// are still both a blank `FilmMetadata()`) until that folder is
    /// expanded, so importing a large album doesn't decode every photo in
    /// it up front. `isDirty` naturally stays `false` for an unloaded item
    /// (blank == blank), so it's automatically excluded from `saveAll()`.
    @Published var isContentLoaded: Bool = false

    /// The full image's own pixel dimensions (not the sidebar thumbnail's) —
    /// `nil` until the file's been read at least once. Refreshed on import,
    /// reload, and save, since saving can itself change the file (and in
    /// principle a reload always should, though metadata-only writes never
    /// touch pixel dimensions in practice).
    @Published var pixelWidth: Int?
    @Published var pixelHeight: Int?
    /// The file's size on disk in bytes — refreshed at the same points as
    /// `pixelWidth`/`pixelHeight`, since writing metadata changes it.
    @Published var fileSizeBytes: Int64?

    var isDirty: Bool { edited != original }
    var filename: String { url.lastPathComponent }

    /// "3089 × 2048 · 3.2 MB" for the sidebar preview — `nil` if either
    /// piece isn't known yet rather than showing a partial/misleading value.
    var dimensionsAndSizeText: String? {
        guard let pixelWidth, let pixelHeight, let fileSizeBytes else { return nil }
        let megabytes = Double(fileSizeBytes) / 1_000_000
        return "\(pixelWidth) × \(pixelHeight) · \(String(format: "%.1f", megabytes)) MB"
    }

    // MARK: - Undo

    /// One entry per discrete action — "click a preset" or "change one
    /// field's value" — not one per keystroke. There's no reliable
    /// end-of-edit signal to hook (an earlier attempt using
    /// `NSComboBoxDelegate.controlTextDidEndEditing` broke combo box
    /// selection entirely), so instead of timing, this watches *which*
    /// field(s) actually differ from the start of the current pending
    /// action: as long as only one field keeps changing (typing "K", "Ko",
    /// "Kodak" one keystroke at a time), it's the same action; the moment a
    /// second field changes too (a different control was touched, or a
    /// preset just landed and touched several fields in one assignment),
    /// the pending action is flushed as its own undo step and a new one
    /// starts.
    private var undoStack: [FilmMetadata] = []
    private var pendingUndoSnapshot: FilmMetadata?
    /// Suppresses undo recording while `edited`/`original` are being set
    /// programmatically (initial load, reload from disk, or undo itself) —
    /// none of those should themselves become undoable steps.
    private var isRestoringState = false

    var canUndo: Bool { pendingUndoSnapshot != nil || !undoStack.isEmpty }

    private func recordUndoSnapshot(previous: FilmMetadata) {
        guard let pending = pendingUndoSnapshot else {
            pendingUndoSnapshot = previous
            return
        }
        if Self.changedFieldNames(pending, edited).count > 1 {
            undoStack.append(pending)
            pendingUndoSnapshot = previous
        }
        // Otherwise this step only extended the same single field the
        // pending action already covers — keep `pending` as the action's
        // start and don't push anything yet.
    }

    /// Steps `edited` back by one action, returning the names of the
    /// fields that changed as a result — so the UI can scroll the affected
    /// section into view, the same way it does for a preset. `nil` if there
    /// was nothing to undo.
    @discardableResult
    func undo() -> Set<String>? {
        if let pending = pendingUndoSnapshot {
            undoStack.append(pending)
            pendingUndoSnapshot = nil
        }
        guard let previous = undoStack.popLast() else { return nil }
        let before = edited
        isRestoringState = true
        edited = previous
        isRestoringState = false
        return Self.changedFieldNames(before, previous)
    }

    /// Sets both `original` and `edited` without recording undo history or
    /// keeping whatever history existed before — used for the initial load
    /// and for reloading from disk, neither of which is something a photo's
    /// *editing* undo history should reach back through.
    func setLoadedMetadata(_ metadata: FilmMetadata) {
        isRestoringState = true
        original = metadata
        edited = metadata
        isRestoringState = false
        undoStack.removeAll()
        pendingUndoSnapshot = nil
    }

    /// `FilmMetadata`'s own grouped sub-structs (film/roll/development/lab/
    /// scanning) — a change inside one of these needs to be compared leaf by
    /// leaf, not as "the whole group differs", or editing two different
    /// fields in the same group (e.g. Developer then Developer Dilution)
    /// would wrongly look like the same field changing twice and get
    /// coalesced into one undo step instead of two.
    private static let groupedFieldNames: Set<String> = ["film", "roll", "development", "lab", "scanning"]

    /// The names of the properties that differ between `a` and `b`,
    /// compared by their printed description — generic across `String`,
    /// `Double?`, `Date?`, `Int`, `Bool`, and `[String: String]` alike,
    /// without needing per-field `Equatable` plumbing. One of the grouped
    /// sub-structs above reports its differing fields as "group.field" (e.g.
    /// "film.maker") by descending one level further; everything else
    /// compares at the top level, same as before. Only used to decide
    /// undo-step boundaries, so an imperfect comparison (e.g. two `Date`s
    /// that print the same but aren't `==`) only affects grouping, never
    /// correctness of the data itself.
    private static func changedFieldNames(_ a: FilmMetadata, _ b: FilmMetadata) -> Set<String> {
        var changed: Set<String> = []
        for (childA, childB) in zip(Mirror(reflecting: a).children, Mirror(reflecting: b).children) {
            guard let label = childA.label else { continue }
            if groupedFieldNames.contains(label) {
                for (leafA, leafB) in zip(Mirror(reflecting: childA.value).children, Mirror(reflecting: childB.value).children) {
                    guard let leafLabel = leafA.label else { continue }
                    if String(describing: leafA.value) != String(describing: leafB.value) {
                        changed.insert("\(label).\(leafLabel)")
                    }
                }
            } else if String(describing: childA.value) != String(describing: childB.value) {
                changed.insert(label)
            }
        }
        return changed
    }

    init(url: URL, sourceFolder: URL? = nil, importRoot: URL? = nil) {
        self.url = url
        self.sourceFolder = sourceFolder
        self.importRoot = importRoot
    }

    static func == (lhs: PhotoItem, rhs: PhotoItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
