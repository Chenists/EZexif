import SwiftUI

/// The "Presets" settings tab: a list of every preset grouped by category
/// on the left, and a create/edit form on the right. This is the single
/// place presets are added, edited, and deleted — reached either via
/// "Manage Presets" or the "+" on an individual category in the preset
/// panel (both just select a tab/category here).
struct PresetsSettingsView: View {
    @ObservedObject var presetStore: PresetStore
    @ObservedObject var router: AppSettingsRouter

    @State private var selectedPresetID: FilmPreset.ID?
    @State private var creatingCategory: PresetCategory?
    /// Which preset (if any) is being renamed inline in the list, and its
    /// in-progress draft — tracked here (not per-row) so starting a rename
    /// on one row, or selecting/creating/deleting elsewhere, can always
    /// commit whatever the previous row was mid-editing.
    @State private var renamingPresetID: FilmPreset.ID?
    @State private var renamingDraftName = ""

    var body: some View {
        HStack(spacing: 0) {
            list
            Divider()
            detail
        }
        .onAppear(perform: applyPendingRequest)
        .onChange(of: router.presetsNavigationRequestID) { _, _ in applyPendingRequest() }
    }

    private var list: some View {
        VStack(spacing: 0) {
            // A plain ScrollView/VStack rather than List+Section: macOS
            // pins List section headers to the top of the scroll area
            // while their rows scroll underneath, regardless of list
            // style — there's no way to get an ordinary, non-sticky
            // scrolling section header out of List itself.
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(PresetCategory.allCases) { category in
                        VStack(alignment: .leading, spacing: 2) {
                            Label(LocalizedStringKey(category.title), systemImage: category.systemImage)
                                .font(.headline)
                                .padding(.bottom, 2)
                            ForEach(presetStore.presets.filter { $0.category == category }) { preset in
                                presetRow(preset)
                            }
                        }
                    }
                }
                .padding(10)
                .contentShape(Rectangle())
                .onTapGesture { commitRenameIfNeeded() }
            }
            Divider()
            // Same height as `PresetForm`'s footer, so this divider and
            // that one line up at the same height across the window.
            HStack(spacing: 8) {
                Menu {
                    Button("New Photographer") { startCreating(.photographer) }
                    Button("New Shooting Parameters") { startCreating(.exposureSettings) }
                    Button("New Camera") { startCreating(.cameraBody) }
                    Button("New Lens") { startCreating(.lens) }
                    Button("New Film") { startCreating(.film) }
                    Button("New Lab") { startCreating(.lab) }
                    Button("New Development") { startCreating(.development) }
                    Button("New Scanning") { startCreating(.scanning) }
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 20, height: 20)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 20)
                Button {
                    deleteSelectedPreset()
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.borderless)
                .frame(width: 20)
                .disabled(selectedPresetID == nil)
                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(height: 44)
        }
        .frame(width: 220)
    }

    private func presetRow(_ preset: FilmPreset) -> some View {
        PresetRowView(
            preset: preset,
            isSelected: selectedPresetID == preset.id,
            renamingPresetID: $renamingPresetID,
            renamingDraftName: $renamingDraftName,
            onSelect: { selectPreset(preset) },
            onCommitRename: { newName in renamePreset(preset, to: newName) },
            onStartRename: {
                commitRenameIfNeeded()
                renamingDraftName = preset.name
                renamingPresetID = preset.id
            },
            onDelete: { deletePreset(preset) }
        )
    }

    @ViewBuilder
    private var detail: some View {
        if let category = creatingCategory {
            // `.id` forces a fresh `PresetForm` (and fresh `@State`) per
            // category — without it, SwiftUI treats every "start creating"
            // as the same view instance and never re-runs its initializer.
            PresetForm(
                initialPreset: nil,
                initialCategory: category,
                currentMetadata: router.currentMetadataSnapshot,
                onSave: { preset in
                    presetStore.upsert(preset)
                    creatingCategory = nil
                    selectedPresetID = preset.id
                }
            )
            .id("create-\(category.rawValue)")
        } else if let id = selectedPresetID, let preset = presetStore.presets.first(where: { $0.id == id }) {
            // Same reasoning: `.id(preset.id)` makes switching the selected
            // preset create a fresh form instead of reusing stale `@State`
            // from whichever preset was clicked first.
            PresetForm(
                initialPreset: preset,
                initialCategory: preset.category,
                currentMetadata: router.currentMetadataSnapshot,
                onSave: { updated in
                    presetStore.upsert(updated)
                }
            )
            .id(preset.id)
        } else {
            VStack(spacing: 8) {
                Text("Select a preset to edit")
                    .foregroundStyle(.secondary)
                Text("or create a new one with the + button")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func selectPreset(_ preset: FilmPreset) {
        commitRenameIfNeeded()
        creatingCategory = nil
        selectedPresetID = preset.id
    }

    private func startCreating(_ category: PresetCategory) {
        commitRenameIfNeeded()
        selectedPresetID = nil
        creatingCategory = category
    }

    private func deleteSelectedPreset() {
        commitRenameIfNeeded()
        guard let id = selectedPresetID, let preset = presetStore.presets.first(where: { $0.id == id }) else { return }
        deletePreset(preset)
    }

    /// Unlike `deleteSelectedPreset()` (the sidebar "−" button, which only
    /// ever acts on whatever's currently selected), this can remove any
    /// preset directly — used by each row's own context menu, since
    /// right-clicking a preset shouldn't require selecting it first.
    private func deletePreset(_ preset: FilmPreset) {
        commitRenameIfNeeded()
        presetStore.remove(preset)
        if selectedPresetID == preset.id { selectedPresetID = nil }
    }

    private func renamePreset(_ preset: FilmPreset, to newName: String) {
        var updated = preset
        updated.name = newName
        presetStore.upsert(updated)
    }

    private func commitRenameIfNeeded() {
        guard let id = renamingPresetID, let preset = presetStore.presets.first(where: { $0.id == id }) else { return }
        let trimmed = renamingDraftName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { renamePreset(preset, to: trimmed) }
        renamingPresetID = nil
    }

    /// Syncs from the router's request unconditionally — including when
    /// both `pendingEditPresetID` and `pendingNewPresetCategory` are `nil`
    /// (a generic "Manage Presets" open), so the tab always reflects the
    /// most recent request instead of getting stuck showing whatever
    /// category or preset was last requested.
    private func applyPendingRequest() {
        if let editID = router.pendingEditPresetID {
            creatingCategory = nil
            selectedPresetID = editID
        } else {
            selectedPresetID = nil
            creatingCategory = router.pendingNewPresetCategory
        }
    }
}

/// One row in the preset list: a plain title by default, switching to an
/// inline editable text field on double-click (same "double-click to
/// rename, click away to commit" pattern as the preset form's own name
/// field) — plus the ordinary single-click-to-select behavior.
private struct PresetRowView: View {
    let preset: FilmPreset
    let isSelected: Bool
    @Binding var renamingPresetID: FilmPreset.ID?
    @Binding var renamingDraftName: String
    let onSelect: () -> Void
    let onCommitRename: (String) -> Void
    let onStartRename: () -> Void
    let onDelete: () -> Void

    @FocusState private var focused: Bool

    private var isEditing: Bool { renamingPresetID == preset.id }

    var body: some View {
        Group {
            if isEditing {
                TextField("Preset name", text: $renamingDraftName)
                    .textFieldStyle(.plain)
                    .focused($focused)
                    .onSubmit { commit() }
                    .onChange(of: focused) { _, isFocused in
                        if !isFocused { commit() }
                    }
                    .onAppear { focused = true }
            } else {
                // A plain `Button` for the single-click select action, with
                // the double-click-to-rename as a *simultaneous* gesture —
                // not `.onTapGesture(count: 1)` alongside `count: 2` on the
                // same view, which forces SwiftUI to wait out the system's
                // double-click window before firing the single click at
                // all. That combination was the cause of the noticeable
                // lag when selecting a preset; `Button` recognizes its tap
                // immediately since it isn't part of that disambiguation.
                Button(action: onSelect) {
                    Text(preset.name)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        // Without this, only the text glyphs themselves are
                        // tappable — the surrounding row space stretched by
                        // `.frame(maxWidth: .infinity)` still misses clicks,
                        // since a plain `Text`'s default hit-test shape is
                        // its tight bounding path, not its layout frame.
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .simultaneousGesture(
                    TapGesture(count: 2).onEnded {
                        renamingDraftName = preset.name
                        renamingPresetID = preset.id
                    }
                )
                .contextMenu {
                    Button("Rename") { onStartRename() }
                    Button("Delete", role: .destructive) { onDelete() }
                }
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(
            isSelected ? Color.accentColor.opacity(0.2) : Color.clear,
            in: RoundedRectangle(cornerRadius: 5)
        )
    }

    private func commit() {
        guard renamingPresetID == preset.id else { return }
        onCommitRename(renamingDraftName)
        renamingPresetID = nil
    }
}
