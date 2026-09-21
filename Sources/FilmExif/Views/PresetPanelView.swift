import SwiftUI

/// Persistent right-hand panel: presets grouped into one section per
/// `PresetCategory`. Clicking a preset applies only that category's fields to
/// whatever `onApply` decides is "current" (a single photo, or every photo
/// in a multi-selection) — fields outside the category, and fields the
/// preset left blank, are never touched.
struct PresetPanelView: View {
    @ObservedObject var presetStore: PresetStore
    @EnvironmentObject var settingsRouter: AppSettingsRouter
    @Environment(\.openSettings) private var openSettings
    /// What "current" metadata looks like right now, used to capture a new
    /// preset from the fields as they're shown on screen.
    let currentMetadata: FilmMetadata
    let onApply: (FilmMetadata, PresetCategory) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Presets")
                    .font(.headline)
                Spacer()
                Button {
                    settingsRouter.currentMetadataSnapshot = currentMetadata
                    settingsRouter.prepareOpenPresets()
                    openSettings()
                } label: {
                    Image(systemName: "list.bullet.rectangle")
                }
                .buttonStyle(.plain)
                .help("Manage Presets")
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 8)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(PresetCategory.allCases) { category in
                        categorySection(category)
                    }
                }
                .padding(14)
            }
        }
        .frame(width: 260)
        .background(.thinMaterial)
    }

    @ViewBuilder
    private func categorySection(_ category: PresetCategory) -> some View {
        let presets = presetStore.presets.filter { $0.category == category }
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(LocalizedStringKey(category.title), systemImage: category.systemImage)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Spacer()
                Button {
                    settingsRouter.currentMetadataSnapshot = currentMetadata
                    settingsRouter.prepareOpenPresets(newPresetIn: category)
                    openSettings()
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
                .help("Create a new \(category.title.lowercased()) preset")
            }

            if presets.isEmpty {
                Text("No presets yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(presets) { preset in
                    presetRow(preset, category: category)
                }
            }
        }
    }

    private func presetRow(_ preset: FilmPreset, category: PresetCategory) -> some View {
        Button {
            onApply(preset.metadata, category)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(preset.name)
                    .font(.callout)
                    .foregroundStyle(.primary)
                let summary = category.summary(of: preset.metadata)
                if !summary.isEmpty {
                    Text(summary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Edit") {
                settingsRouter.currentMetadataSnapshot = currentMetadata
                settingsRouter.prepareEditPreset(preset.id)
                openSettings()
            }
            Button("Delete", role: .destructive) {
                presetStore.remove(preset)
            }
        }
    }
}
