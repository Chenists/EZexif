import SwiftUI
import AppKit

struct PhotoListView: View {
    @EnvironmentObject var library: PhotoLibrary
    /// The most recently clicked/added item in the current selection, so
    /// the stacked preview can put it in front instead of whatever order
    /// `library.items` happens to hold. A plain `Set<PhotoItem.ID>`
    /// selection carries no ordering of its own, so this is tracked by
    /// diffing `library.selection` on change (see `list`'s `.onChange`).
    @State private var lastSelectedID: PhotoItem.ID?

    var body: some View {
        VStack(spacing: 0) {
            list
            if library.selectedItems.count == 1, let item = library.selectedItems.first {
                Divider()
                preview(item)
            } else if library.selectedItems.count > 1 {
                Divider()
                stackedPreview(library.selectedItems)
            }
        }
    }

    /// Rebuilds the real folder hierarchy for the sidebar: every photo
    /// whose `importRoot`/`sourceFolder` trace back to the same
    /// top-level imported folder is nested under that folder's node, at
    /// whatever depth its actual subfolder chain puts it — not just
    /// grouped by immediate parent. Photos opened individually (no
    /// `importRoot`) are appended as loose top-level leaves, same as
    /// before there was any folder grouping at all.
    private var treeNodes: [TreeNode] {
        final class FolderBuilder {
            let url: URL
            var subfolderOrder: [String] = []
            var subfolders: [String: FolderBuilder] = [:]
            var items: [PhotoItem] = []
            init(url: URL) { self.url = url }
        }

        var rootOrder: [String] = []
        var roots: [String: FolderBuilder] = [:]
        var looseItems: [PhotoItem] = []

        for item in library.items {
            guard let root = item.importRoot, let folder = item.sourceFolder else {
                looseItems.append(item)
                continue
            }
            if roots[root.path] == nil {
                roots[root.path] = FolderBuilder(url: root)
                rootOrder.append(root.path)
            }
            let rootNode = roots[root.path]!
            let rootComponents = root.standardizedFileURL.pathComponents
            let folderComponents = folder.standardizedFileURL.pathComponents
            let relative = folderComponents.count > rootComponents.count
                ? Array(folderComponents[rootComponents.count...])
                : []

            var current = rootNode
            var currentURL = root
            for component in relative {
                currentURL = currentURL.appendingPathComponent(component)
                if let existing = current.subfolders[component] {
                    current = existing
                } else {
                    let newFolder = FolderBuilder(url: currentURL)
                    current.subfolders[component] = newFolder
                    current.subfolderOrder.append(component)
                    current = newFolder
                }
            }
            current.items.append(item)
        }

        func convert(_ folder: FolderBuilder) -> TreeNode {
            var children = folder.subfolderOrder.compactMap { folder.subfolders[$0] }.map(convert)
            children.append(contentsOf: folder.items.map { TreeNode(id: "photo:\($0.id)", kind: .photo($0), children: nil) })
            return TreeNode(id: "folder:\(folder.url.path)", kind: .folder(folder.url), children: children)
        }

        var result = rootOrder.compactMap { roots[$0] }.map(convert)
        result.append(contentsOf: looseItems.map { TreeNode(id: "photo:\($0.id)", kind: .photo($0), children: nil) })
        return result
    }

    private var list: some View {
        List(selection: $library.selection) {
            ForEach(treeNodes) { node in
                FolderTreeRow(node: node, isRoot: true)
            }
        }
        .listStyle(.sidebar)
        .onChange(of: library.selection) { oldValue, newValue in
            // Whichever id(s) weren't in the selection before are the ones
            // just clicked; if there's exactly one (an ordinary click, or a
            // ⌘-click adding one item), that's unambiguously "last
            // clicked." A ⌘-click that only *removes* an item adds nothing
            // new, so this is left alone rather than guessing.
            let added = newValue.subtracting(oldValue)
            if let newest = added.first {
                lastSelectedID = newest
            }
        }
    }

    /// Opens the original file in Preview.app, rather than whatever the
    /// system's default handler for the file type happens to be — the app
    /// only edits metadata, so this is just a quick way to look at the
    /// full-size image outside FilmExif. `static` (not an instance method)
    /// so `PhotoLeafRow`, a separate view type, can call it directly.
    fileprivate static func openInPreview(_ item: PhotoItem) {
        guard let previewURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Preview") else {
            NSWorkspace.shared.open(item.url)
            return
        }
        NSWorkspace.shared.open([item.url], withApplicationAt: previewURL, configuration: NSWorkspace.OpenConfiguration())
    }

    /// The plain thumbnail frame shared by both the single-photo preview and
    /// each card in the stacked multi-photo preview — same size, same
    /// corner radius, same empty-state fill, no border or shadow on either,
    /// so the two only ever differ in how many are shown and how they're
    /// arranged, never in their own styling.
    private func photoFrame(_ item: PhotoItem) -> some View {
        Group {
            if let thumb = item.thumbnail {
                // The thumbnail is generated with the file's own
                // (== `item.original`) orientation already baked into its
                // pixels — this only previews the *pending* extra turn from
                // the rotate button below, as the delta between the edited
                // and original codes, rather than re-deriving the whole
                // rotation from scratch.
                let rotation = FilmMetadata.rotationDegrees(item.edited.orientation)
                    - FilmMetadata.rotationDegrees(item.original.orientation)
                // A plain `.aspectRatio(contentMode: .fit)` sizes the image
                // for its own (unrotated) width/height — at a 90°/270°
                // preview, `.rotationEffect` then spins that already-sized
                // box onto its side, so it overflows the frame it was fit
                // to instead of shrinking to match. Fitting against the
                // *swapped* width/height first, then rotating, keeps the
                // rotated box within the same frame at every angle.
                GeometryReader { geo in
                    let isQuarterTurn = Int(rotation.rounded()) % 180 != 0
                    let imageRatio = thumb.size.height > 0 ? thumb.size.width / thumb.size.height : 1
                    // At a 90°/270° preview, pre-fit the image's true
                    // aspect ratio into the *swapped* container box, so
                    // that once `.rotationEffect` turns it onto its side,
                    // its footprint (width/height swapped back) lands
                    // within the real container instead of overflowing it.
                    let fitWidth = isQuarterTurn ? geo.size.height : geo.size.width
                    let fitHeight = isQuarterTurn ? geo.size.width : geo.size.height
                    let renderSize: CGSize = imageRatio >= fitWidth / fitHeight
                        ? CGSize(width: fitWidth, height: fitWidth / imageRatio)
                        : CGSize(width: fitHeight * imageRatio, height: fitHeight)
                    Image(nsImage: thumb)
                        .resizable()
                        .frame(width: renderSize.width, height: renderSize.height)
                        .rotationEffect(.degrees(rotation))
                        .frame(width: geo.size.width, height: geo.size.height)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
            }
        }
    }

    private func preview(_ item: PhotoItem) -> some View {
        VStack(spacing: 4) {
            photoFrame(item)
                .overlay(alignment: .topTrailing) {
                    Button {
                        item.edited.orientation = FilmMetadata.nextOrientationCode(after: item.edited.orientation)
                    } label: {
                        Image(systemName: "rotate.right")
                            .frame(width: 16, height: 16)
                            .padding(8)
                            .background(.regularMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Rotate")
                    .padding(6)
                }
            HStack(spacing: 4) {
                if let text = item.dimensionsAndSizeText {
                    Text(text)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                // Same small orange dot `PhotoRow` uses for its own overall
                // dirty state — scoped to just this one field here, since
                // rotating is the only edit this preview area can make.
                if item.edited.orientation != item.original.orientation {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                        .help("Unsaved changes")
                }
            }
        }
        .padding(10)
    }

    /// A fanned stack of up to 3 thumbnails, in the same spot the single
    /// preview occupies, for when more than one photo is selected — with a
    /// badge for the total count. Each card is the exact same `photoFrame`
    /// the single preview uses, just scaled down slightly and offset per
    /// layer to suggest a stack, rather than a differently-sized, bordered
    /// card of its own.
    private func stackedPreview(_ items: [PhotoItem]) -> some View {
        // Put the most recently selected item first, so it lands on top of
        // the stack instead of wherever it happens to sit in `items`.
        var ordered = items
        if let lastSelectedID, let idx = ordered.firstIndex(where: { $0.id == lastSelectedID }) {
            let mostRecent = ordered.remove(at: idx)
            ordered.insert(mostRecent, at: 0)
        }
        let stacked = Array(ordered.prefix(3).enumerated())
        return ZStack {
            ForEach(Array(stacked.reversed()), id: \.element.id) { index, item in
                photoFrame(item)
                    .scaleEffect(1 - CGFloat(index) * 0.06)
                    .offset(x: CGFloat(index) * 10, y: CGFloat(index) * -8)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
        .overlay(alignment: .bottomTrailing) {
            Text("\(items.count)")
                .font(.caption2.bold())
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.thinMaterial, in: Capsule())
                .padding(6)
        }
        .padding(10)
    }

}

/// One node of the sidebar's folder tree — either a folder (with
/// `children`, possibly containing more folders and/or photos) or a single
/// photo leaf (`children == nil`). Built fresh from `library.items` each
/// time by `PhotoListView.treeNodes`, using each item's
/// `importRoot`/`sourceFolder` to reconstruct the real on-disk hierarchy.
/// A plain top-level type (not nested in `PhotoListView`) so `FolderTreeRow`
/// and `PhotoLeafRow` below — separate view types, needed so each folder
/// level can own its own `@State` expansion flag — can use it too.
private struct TreeNode: Identifiable {
    enum Kind {
        case folder(URL)
        case photo(PhotoItem)
    }
    let id: String
    let kind: Kind
    var children: [TreeNode]?

    /// Every photo nested anywhere under this node (itself included if
    /// it's already a leaf) — used by a folder's own "Remove from
    /// list"/"Reload" so acting on a folder covers its subfolders too, not
    /// just whatever photos sit directly inside it.
    func allPhotos() -> [PhotoItem] {
        guard let children else {
            if case .photo(let item) = kind { return [item] }
            return []
        }
        return children.flatMap { $0.allPhotos() }
    }

    /// Just the photos directly inside this node, not nested any deeper —
    /// what gets lazily loaded the moment this folder is expanded, leaving
    /// any collapsed subfolder's own photos untouched until it's expanded
    /// in turn.
    func directPhotos() -> [PhotoItem] {
        (children ?? []).compactMap { child in
            if case .photo(let item) = child.kind { return item }
            return nil
        }
    }
}

/// One row of the sidebar's folder tree: a folder renders as a
/// `DisclosureGroup` (expanded by default only at the top level — every
/// subfolder starts collapsed) recursing into its own children, or a photo
/// renders as a leaf row. `DisclosureGroup`'s `content` closure isn't even
/// evaluated while collapsed, so a collapsed subfolder's photos build no
/// view hierarchy at all — and expanding one lazily loads
/// (`PhotoLibrary.ensureLoaded`) just its own direct photos, so importing a
/// large album only ever decodes thumbnails/EXIF for what's actually been
/// shown, not everything nested underneath it.
private struct FolderTreeRow: View {
    let node: TreeNode
    @EnvironmentObject var library: PhotoLibrary
    @State private var isExpanded: Bool

    init(node: TreeNode, isRoot: Bool) {
        self.node = node
        _isExpanded = State(initialValue: isRoot)
    }

    var body: some View {
        switch node.kind {
        case .folder(let url):
            DisclosureGroup(isExpanded: $isExpanded) {
                ForEach(node.children ?? []) { child in
                    FolderTreeRow(node: child, isRoot: false)
                }
            } label: {
                Label(url.lastPathComponent, systemImage: "folder")
                    .font(.headline)
                    .contextMenu {
                        Button("Remove from list") {
                            library.remove(node.allPhotos())
                        }
                        Button("Reload") {
                            for item in node.allPhotos() { library.reload(item) }
                        }
                    }
            }
            // Both cover the same need: `isExpanded`'s initial value (for
            // a root node) never fires `.onChange`, since nothing actually
            // changed from this view's own perspective — only a value that
            // starts `false` and flips to `true` does. `.onAppear` catches
            // that "already expanded from the start" case once instead.
            .onAppear {
                if isExpanded { library.ensureLoaded(node.directPhotos()) }
            }
            .onChange(of: isExpanded) { _, expanded in
                if expanded { library.ensureLoaded(node.directPhotos()) }
            }
        case .photo(let item):
            PhotoLeafRow(item: item)
        }
    }
}

/// A single photo's sidebar row plus its own context menu — pulled out of
/// `PhotoListView` (rather than staying a private method returning
/// `some View`) so `FolderTreeRow` above, a separate view type, can use it
/// directly without needing an instance of `PhotoListView` itself.
private struct PhotoLeafRow: View {
    @ObservedObject var item: PhotoItem
    @EnvironmentObject var library: PhotoLibrary

    var body: some View {
        PhotoRow(item: item)
            .tag(item.id)
            .contextMenu {
                // Opening in Preview only lives here (right-click), not on
                // a double-click gesture on the row — several attempts at a
                // double-click gesture (a custom `NSClickGestureRecognizer`
                // overlay, then `.simultaneousGesture`) either never fired
                // at all or made ordinary row selection worse, apparently
                // due to `List`'s underlying `NSTableView` already owning
                // click handling for its rows. A context menu action never
                // touches the row's click handling at all, so it's the only
                // way to open a photo in Preview from the sidebar.
                Button("Open in Preview") {
                    PhotoListView.openInPreview(item)
                }
                // Right-clicking a row that's part of the current
                // multi-selection acts on the whole selection (matching
                // Finder) — right-clicking a row outside the current
                // selection (or with nothing/only it selected) acts on just
                // that one row, not whatever was selected before.
                Button("Remove from list") {
                    if library.selection.contains(item.id), library.selectedItems.count > 1 {
                        library.remove(library.selectedItems)
                    } else {
                        library.remove(item)
                    }
                }
                Button("Reload") {
                    if library.selection.contains(item.id), library.selectedItems.count > 1 {
                        for selected in library.selectedItems { library.reload(selected) }
                    } else {
                        library.reload(item)
                    }
                }
            }
    }
}

/// One row's content — a dedicated view (rather than a plain function
/// returning content inline) so it observes `item` directly via
/// `@ObservedObject`. `PhotoListView` itself only holds `@EnvironmentObject
/// var library`, which never changes just because one photo's own `edited`/
/// `original` metadata does (e.g. from typing in a field, or "Revert") — a
/// row built as a plain function using `item.isDirty` would only ever have
/// been recomputed by *some other* trigger (like `library.selection`
/// changing), so it could go stale and keep showing "dirty" after a Revert
/// until something unrelated forced the row to re-render. Observing `item`
/// here makes SwiftUI re-render just this row the instant its own
/// properties change.
private struct PhotoRow: View {
    @ObservedObject var item: PhotoItem
    @AppStorage(AppSettingsKeys.thumbnailSize) private var thumbnailSizeRaw = ThumbnailSize.medium.rawValue

    private var thumbnailPixels: CGFloat {
        (ThumbnailSize(rawValue: thumbnailSizeRaw) ?? .medium).pixels
    }

    var body: some View {
        HStack(spacing: 10) {
            if let thumb = item.thumbnail {
                Image(nsImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: thumbnailPixels, height: thumbnailPixels)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            } else {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: thumbnailPixels, height: thumbnailPixels)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.filename)
                    .lineLimit(1)
                    .font(.callout)
                if let err = item.lastError {
                    Text(err)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                }
            }
            Spacer()
            // The same small orange dot the toolbar uses for the selected
            // file's unsaved-changes indicator, at the row's trailing edge
            // — not a separate "Unsaved changes" text tag.
            if item.isDirty {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 6, height: 6)
                    .help("Unsaved changes")
            }
        }
    }
}
