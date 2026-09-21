import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ContentView: View {
    @EnvironmentObject var library: PhotoLibrary
    @EnvironmentObject var presetStore: PresetStore
    @Environment(\.openSettings) private var openSettings
    @State private var isTargeted = false
    @State private var showingPresetPanel = false
    // Starts collapsed on every launch — an explicit binding is required
    // since without one `NavigationSplitView` restores whatever visibility
    // state macOS auto-saved from the last time the window closed.
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly

    var body: some View {
        HStack(spacing: 0) {
            // The preset panel is a sibling of the *whole* NavigationSplitView
            // here, not something nested inside its detail closure (that
            // was the original design, and it's why toggling the sidebar
            // used to also disturb this panel — the sidebar's internal
            // collapse/expand renegotiates space with whatever shares its
            // detail pane). As a top-level sibling, the sidebar's own
            // collapse/expand is entirely internal to the NavigationSplitView
            // and shouldn't touch this panel at all.
            NavigationSplitView(columnVisibility: $columnVisibility) {
                PhotoListView()
                    // A fixed, non-resizable width rather than a min/ideal/max
                    // range: resizing the window (e.g. dragging its left
                    // edge) was shrinking this column down toward its old
                    // 220pt floor, crowding the thumbnails and text against
                    // the divider. Fixing the width means the window's
                    // detail pane absorbs all resizing instead.
                    .navigationSplitViewColumnWidth(260)
            } detail: {
                Group {
                    if library.selectedItems.count == 1, let item = library.selectedItems.first {
                        MetadataEditorView(item: item)
                    } else if library.selectedItems.count > 1 {
                        BatchEditorView(items: library.selectedItems)
                    } else {
                        emptyState
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .toolbar {
                // `.principal` centers in the toolbar regardless of what's in
                // the leading/trailing groups — used here to show the
                // selected file's name (with a dirty dot) the way most Mac
                // document apps show the current file in their title bar.
                ToolbarItem(placement: .principal) {
                    if library.selectedItems.count == 1, let item = library.selectedItems.first {
                        ToolbarFileStatus(item: item)
                    } else if library.selectedItems.count > 1 {
                        Text("\(library.selectedItems.count) photos selected")
                            .font(.headline)
                    }
                }
                // `.primaryAction` on its own just claims the next slot after
                // leading content (the sidebar toggle) — it does not anchor to
                // the toolbar's trailing edge, which is why these were
                // clustering on the left with the rest of the (very wide)
                // toolbar sitting empty. A `Spacer()` as the first element of a
                // single `ToolbarItemGroup` is what NSToolbar actually treats
                // as flexible space, pushing everything after it to the edge.
                ToolbarItemGroup(placement: .primaryAction) {
                    Spacer()
                    // Back to plain, native toolbar Buttons — the custom
                    // manually-styled version fixed the size mismatch but
                    // gave up the real toolbar button look/feel; the
                    // dull-until-hover / stuck-hover-highlight issue is
                    // deferred rather than worked around here.
                    // "Open" and "Import Folder" used to be separate
                    // buttons/panels, but `presentOpenPanel()` already lets
                    // you pick either files or a folder in one panel
                    // (`canChooseFiles`/`canChooseDirectories` both true),
                    // making the dedicated folder-only panel redundant — one
                    // button now covers both, keeping the more recognizable
                    // "import" glyph.
                    // `.renderingMode(.original)` + an explicit `.foregroundStyle`
                    // on every toolbar icon below: SF Symbols placed directly in
                    // a toolbar default to *template* rendering, which NSToolbar
                    // itself automatically re-tints based on whether the window
                    // is key — dimming it for a background window, brightening
                    // it once key, exactly like Finder/Safari/Mail. The bug is
                    // that even this window, already frontmost at launch,
                    // doesn't get that retint until something (a hover) forces
                    // AppKit to reconsider it. Opting out of template rendering
                    // takes the icon out of that mechanism entirely — it's
                    // always drawn in this explicit color, launch or not, hover
                    // or not. `.disabled(...)` below still dims the Save button
                    // correctly, since that's a separate, SwiftUI-level opacity
                    // effect, not tied to image rendering mode at all.
                    // "folder.badge.plus" is left on plain template rendering,
                    // unlike the icons below — `.renderingMode(.original)`
                    // made it render its own built-in multicolor variant (a
                    // green "+" badge) instead of respecting `.foregroundStyle`,
                    // which looked wrong. It keeps the original dull-until-
                    // hover behavior as the trade-off.
                    Button {
                        library.presentOpenPanel()
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                    .help("Open")
                    Button {
                        library.saveAll()
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                            .renderingMode(.original)
                            .foregroundStyle(.primary)
                    }
                    .help("Save All")
                    .disabled(!library.items.contains { $0.isDirty })
                    Button {
                        openSettings()
                    } label: {
                        Image(systemName: "gearshape")
                            .renderingMode(.original)
                            .foregroundStyle(.primary)
                    }
                    .help("Settings")
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showingPresetPanel.toggle()
                        }
                    } label: {
                        Image(systemName: "sidebar.right")
                            .renderingMode(.original)
                            .foregroundStyle(.primary)
                    }
                    .help("Toggle Presets Panel")
                }
            }
            .navigationTitle("")

            // A plain conditional sibling + .transition, animated by the
            // same withAnimation block that flips `showingPresetPanel` —
            // unlike `.inspector`, this participates in ordinary SwiftUI
            // layout, so the detail column's width interpolates
            // continuously alongside the panel's reveal instead of the
            // "squeeze then resize" jump `.inspector` produced.
            //
            // The divider and panel are grouped so the same `.transition`
            // applies to both as one unit — otherwise the divider (with no
            // transition of its own) just fades in at a fixed spot while
            // the panel slides in separately, instead of the two moving
            // together.
            if showingPresetPanel {
                HStack(spacing: 0) {
                    Divider()
                    PresetPanelView(
                        presetStore: presetStore,
                        currentMetadata: library.selectedItems.count > 1
                            ? library.batchDraft
                            : (library.selectedItems.first?.edited ?? FilmMetadata()),
                        onApply: applyPreset
                    )
                }
                .transition(.move(edge: .trailing))
            }
        }
        .onChange(of: library.items.isEmpty) { _, isEmpty in
            if !isEmpty {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showingPresetPanel = true
                }
            }
        }
        .onAppear {
            // A window not yet fully "key" renders all its controls in
            // macOS's dimmed "inactive" appearance, including toolbar
            // buttons — and the very first mouse-over is exactly the kind
            // of event that can make AppKit notice and re-key/redraw it,
            // which matches the icons only "lighting up" after one hover.
            //
            // Two earlier attempts each covered only half the problem:
            // `validateVisibleItems()` alone re-checks enabled/disabled
            // state, not the window's key/active *appearance*; forcing
            // `makeKeyAndOrderFront` alone sets the window's key state but
            // doesn't itself tell an already-constructed `NSToolbar` to
            // redraw with that new state. This does both, and — since
            // `.onAppear` can fire before SwiftUI has finished attaching
            // the toolbar to the underlying `NSWindow` on first launch — is
            // delayed slightly longer than a bare `.async` (which only
            // defers to the next run-loop turn, sometimes still too early)
            // so the toolbar actually exists by the time both run.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.isVisible }) {
                    window.makeKeyAndOrderFront(nil)
                    window.toolbar?.validateVisibleItems()
                }
            }
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
            return true
        }
        // The sidebar starts collapsed on launch, but an import (via the
        // toolbar, the empty-state button, or a drag-and-drop) is exactly
        // the moment its contents become relevant, so it reopens whenever
        // one grows the library — not on every count change, since removing
        // photos shouldn't re-trigger it.
        .onChange(of: library.items.count) { oldValue, newValue in
            if newValue > oldValue {
                columnVisibility = .all
            }
        }
        .overlay(alignment: .bottom) {
            if let summary = library.lastSaveSummary {
                Text(summary)
                    .font(.callout)
                    .padding(8)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .padding(.bottom, 12)
                    .transition(.opacity)
            }
        }
    }

    /// A plain `Image`, not `Label` + `.labelStyle(.iconOnly)` — the third
    /// attempt at the toolbar icons rendering dull until the first hover.
    /// `Label`'s automatic icon-only collapsing inside a toolbar is the one
    /// remaining suspect after two window-activation fixes (forcing
    /// `validateVisibleItems()`, then forcing the window key) didn't help;
    /// this sidesteps it entirely and pins an explicit rendering mode and
    /// tint so nothing about the icon's appearance is left to be resolved
    /// later by an interaction.
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "film")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Open or drop photos or folders to edit their metadata")
                .foregroundStyle(.secondary)
            Button("Open Photos") {
                library.presentOpenPanel()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Applies a preset's category-scoped fields to the current selection.
    /// With a single photo selected, it writes straight into that photo's
    /// `edited` metadata, same as before — `MetadataEditorView` shows that
    /// live. With multiple photos selected, it writes into the shared batch
    /// draft instead of each photo directly, so the change is visible in
    /// `BatchEditorView` (which edits that same draft) rather than only
    /// reaching each photo invisibly, only to be overwritten the next time
    /// "Save" is pressed with whatever was in the batch form before.
    private func applyPreset(_ metadata: FilmMetadata, category: PresetCategory) {
        if library.selectedItems.count > 1 {
            library.batchDraft = category.apply(metadata, to: library.batchDraft)
        } else {
            for item in library.selectedItems {
                item.edited = category.apply(metadata, to: item.edited)
            }
        }
        library.lastPresetApply = .init(category: category)
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        let group = DispatchGroup()
        var urls: [URL] = []
        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                urls.append(url)
            }
        }
        group.notify(queue: .main) {
            library.load(urls: urls)
        }
    }
}

/// The selected file's name plus a small dot when it has unsaved edits —
/// a dedicated view (rather than reading `item.isDirty` inline in
/// `ContentView`) so it observes `item` directly via `@ObservedObject` and
/// updates the instant the file is edited or saved, since `ContentView`
/// itself doesn't hold the item as observed state.
private struct ToolbarFileStatus: View {
    @ObservedObject var item: PhotoItem

    var body: some View {
        HStack(spacing: 6) {
            Text(item.filename)
                .font(.headline)
            if item.isDirty {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 6, height: 6)
                    .help("Unsaved changes")
            }
        }
    }
}

