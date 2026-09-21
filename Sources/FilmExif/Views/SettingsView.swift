import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var presetStore: PresetStore
    @ObservedObject var router: AppSettingsRouter

    var body: some View {
        TabView(selection: $router.selectedTab) {
            GeneralSettingsView(presetStore: presetStore)
                .tabItem { Label(LocalizedStringKey(SettingsTab.general.title), systemImage: SettingsTab.general.systemImage) }
                .tag(SettingsTab.general)

            SavingSettingsView()
                .tabItem { Label(LocalizedStringKey(SettingsTab.saving.title), systemImage: SettingsTab.saving.systemImage) }
                .tag(SettingsTab.saving)

            FieldVisibilitySettingsView()
                .tabItem { Label(LocalizedStringKey(SettingsTab.fields.title), systemImage: SettingsTab.fields.systemImage) }
                .tag(SettingsTab.fields)

            PresetsSettingsView(presetStore: presetStore, router: router)
                .tabItem { Label(LocalizedStringKey(SettingsTab.presets.title), systemImage: SettingsTab.presets.systemImage) }
                .tag(SettingsTab.presets)
        }
        .frame(width: 620, height: 420)
    }
}

private struct GeneralSettingsView: View {
    @ObservedObject var presetStore: PresetStore
    @AppStorage(AppSettingsKeys.displayMode) private var displayModeRaw = DisplayMode.system.rawValue
    @AppStorage(AppSettingsKeys.thumbnailSize) private var thumbnailSizeRaw = ThumbnailSize.medium.rawValue
    @AppStorage(AppSettingsKeys.applyDefaultsToImports) private var applyDefaultsToImports = true
    @AppStorage(AppSettingsKeys.defaultPhotographer) private var defaultPhotographer = ""
    @AppStorage(AppSettingsKeys.defaultCopyright) private var defaultCopyright = ""
    @AppStorage(AppSettingsKeys.defaultPhotographerEnabled) private var defaultPhotographerEnabled = true
    @AppStorage(AppSettingsKeys.defaultCopyrightEnabled) private var defaultCopyrightEnabled = true
    @AppStorage(AppSettingsKeys.defaultExposureSettingsEnabled) private var defaultExposureSettingsEnabled = false
    @AppStorage(AppSettingsKeys.defaultExposureSettingsPresetID) private var defaultExposureSettingsPresetID = ""
    @AppStorage(AppSettingsKeys.defaultCameraEnabled) private var defaultCameraEnabled = false
    @AppStorage(AppSettingsKeys.defaultCameraPresetID) private var defaultCameraPresetID = ""
    @AppStorage(AppSettingsKeys.defaultLensEnabled) private var defaultLensEnabled = false
    @AppStorage(AppSettingsKeys.defaultLensPresetID) private var defaultLensPresetID = ""
    @AppStorage(AppSettingsKeys.defaultFilmEnabled) private var defaultFilmEnabled = false
    @AppStorage(AppSettingsKeys.defaultFilmPresetID) private var defaultFilmPresetID = ""
    @State private var selectedLanguageCode = GeneralSettingsView.currentLanguageCode()
    @State private var showingRestartAlert = false

    private static let languages: [(code: String, name: String)] = [
        ("en", "English"), ("zh-Hans", "中文（简体）"), ("es", "Español")
    ]

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Display Mode", selection: $displayModeRaw) {
                    ForEach(DisplayMode.allCases) { mode in
                        Text(LocalizedStringKey(mode.title)).tag(mode.rawValue)
                    }
                }
                .tint(.primary)
                Picker("Thumbnail Size", selection: $thumbnailSizeRaw) {
                    ForEach(ThumbnailSize.allCases) { size in
                        Text(LocalizedStringKey(size.title)).tag(size.rawValue)
                    }
                }
                .tint(.primary)
            }
            Section("Language") {
                Picker("Language", selection: $selectedLanguageCode) {
                    ForEach(Self.languages, id: \.code) { language in
                        Text(language.name).tag(language.code)
                    }
                }
                .tint(.primary)
                .onChange(of: selectedLanguageCode) { _, newValue in
                    UserDefaults.standard.set([newValue], forKey: "AppleLanguages")
                    showingRestartAlert = true
                }
                Text("Changing language requires restarting EZ Exif.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Defaults") {
                Toggle("Apply the following fields to new imports", isOn: $applyDefaultsToImports)
                HStack {
                    TextField("Photographer", text: $defaultPhotographer)
                        .disabled(!applyDefaultsToImports || !defaultPhotographerEnabled)
                    Toggle("", isOn: $defaultPhotographerEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .disabled(!applyDefaultsToImports)
                }
                HStack {
                    TextField("Copyright", text: $defaultCopyright)
                        .disabled(!applyDefaultsToImports || !defaultCopyrightEnabled)
                    Button {
                        defaultCopyright = MetadataEditorView.generatedCopyright(year: nil, photographer: defaultPhotographer)
                    } label: {
                        Image(systemName: "wand.and.stars")
                    }
                    .buttonStyle(.plain)
                    .help("Generate Copyright")
                    .disabled(!applyDefaultsToImports || !defaultCopyrightEnabled)
                    Toggle("", isOn: $defaultCopyrightEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .disabled(!applyDefaultsToImports)
                }
                presetDefaultRow(title: "Shooting Parameters", category: .exposureSettings, presetID: $defaultExposureSettingsPresetID, enabled: $defaultExposureSettingsEnabled)
                presetDefaultRow(title: "Camera", category: .cameraBody, presetID: $defaultCameraPresetID, enabled: $defaultCameraEnabled)
                presetDefaultRow(title: "Lens", category: .lens, presetID: $defaultLensPresetID, enabled: $defaultLensEnabled)
                presetDefaultRow(title: "Film", category: .film, presetID: $defaultFilmPresetID, enabled: $defaultFilmEnabled)
            }
        }
        .formStyle(.grouped)
        .padding()
        .alert("Restart Required", isPresented: $showingRestartAlert) {
            Button("Restart Now") { AppRelauncher.restart() }
            Button("Later", role: .cancel) {}
        } message: {
            Text("EZ Exif needs to restart for the new language to take effect.")
        }
    }

    /// One "apply this preset to new imports" row for Camera/Lens/Film — a
    /// picker over that category's saved presets, applied whole only when
    /// every field it covers is still empty on the imported file (see
    /// `PhotoLibrary.applyPresetToEmptyFields`), plus its own enable
    /// switch, same as every other default here.
    @ViewBuilder
    private func presetDefaultRow(title: LocalizedStringKey, category: PresetCategory, presetID: Binding<String>, enabled: Binding<Bool>) -> some View {
        let options = presetStore.presets.filter { $0.category == category }
        HStack {
            Picker(selection: presetID) {
                Text("None").tag("")
                ForEach(options) { preset in
                    Text(preset.name).tag(preset.id.uuidString)
                }
            } label: {
                Text(title)
            }
            .disabled(!applyDefaultsToImports || !enabled.wrappedValue)
            Toggle("", isOn: enabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .disabled(!applyDefaultsToImports)
        }
    }

    private static func currentLanguageCode() -> String {
        AppLanguage.currentCode()
    }
}

/// One toggle per field the main/batch editors know how to show, grouped
/// exactly the way those editors group them — turning a field off here
/// hides that row (and, once every field in a section is off, the section
/// itself) without touching whatever value is already stored for it.
private struct FieldVisibilitySettingsView: View {
    @EnvironmentObject var fieldVisibility: FieldVisibilityStore
    @AppStorage(AppSettingsKeys.temperatureUnit) private var temperatureUnitRaw = TemperatureUnit.celsius.rawValue
    @AppStorage(AppSettingsKeys.apertureDisplayFormat) private var apertureDisplayFormatRaw = ApertureDisplayFormat.number.rawValue

    var body: some View {
        // The header row lives directly in the `Form` (not wrapped in a
        // `Section`, and not a sibling view outside the `Form`) specifically
        // so its left/right edges land at the exact same x-position as the
        // grouped `Section` boxes below — `.formStyle(.grouped)` gives every
        // direct child of the `Form` the same leading/trailing inset, which
        // a separately-padded sibling view can only match by accident.
        Form {
            HStack(alignment: .top) {
                Text("Choose which properties appear in the editor. Hiding a field never changes its stored value.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button("Reset to Default") { fieldVisibility.resetToDefault() }
            }
            ForEach(FieldVisibilityRegistry.groups) { group in
                Section(LocalizedStringKey(group.title)) {
                    ForEach(group.fields) { field in
                        let visibilityBinding = Binding(
                            get: { fieldVisibility.isVisible(field.label) },
                            set: { fieldVisibility.setVisible($0, for: field.label) }
                        )
                        // Development Temperature/Aperture carry an extra
                        // unit picker — it only means anything alongside the
                        // field it applies to, so it lives right here
                        // instead of as an unrelated-looking control over in
                        // General. A bare `Toggle(label)` alone in an HStack
                        // stretches its own switch to the row's trailing
                        // edge on its own (its default style has an implicit
                        // internal spacer), but adding a sibling `Picker`
                        // after it competes with that same stretch, landing
                        // the switch somewhere in the middle instead of the
                        // trailing edge every other row's switch sits at —
                        // so these two rows spell out the label/spacer/
                        // picker/switch order explicitly, ending with the
                        // switch, to match everything else.
                        if field.label == "Development Temperature" {
                            HStack {
                                Text(LocalizedStringKey(field.label))
                                Spacer()
                                Picker("", selection: $temperatureUnitRaw) {
                                    ForEach(TemperatureUnit.allCases) { unit in
                                        Text(unit.symbol).tag(unit.rawValue)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .labelsHidden()
                                .frame(width: 90)
                                Toggle("", isOn: visibilityBinding)
                                    .labelsHidden()
                            }
                        } else if field.label == "Aperture" {
                            HStack {
                                Text(LocalizedStringKey(field.label))
                                Spacer()
                                Picker("", selection: $apertureDisplayFormatRaw) {
                                    ForEach(ApertureDisplayFormat.allCases) { format in
                                        Text(format.segmentLabel).tag(format.rawValue)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .labelsHidden()
                                .frame(width: 110)
                                Toggle("", isOn: visibilityBinding)
                                    .labelsHidden()
                            }
                        } else {
                            Toggle(LocalizedStringKey(field.label), isOn: visibilityBinding)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct SavingSettingsView: View {
    @AppStorage(AppSettingsKeys.createBackupFiles) private var createBackupFiles = true
    @AppStorage(AppSettingsKeys.saveToCustomFolder) private var saveToCustomFolder = false
    @AppStorage(AppSettingsKeys.customSaveFolderPath) private var customSaveFolderPath = ""
    @AppStorage(AppSettingsKeys.warnBeforeQuitWithUnsavedChanges) private var warnBeforeQuit = true
    @AppStorage(AppSettingsKeys.jpegCompressionQuality) private var jpegCompressionQuality = 1.0

    /// The only 7 values the slider can land on — chosen (not API-imposed;
    /// `kCGImageDestinationLossyCompressionQuality` itself takes any Double
    /// in 0...1) to skip the ranges that turned out to be dead weight when
    /// tested against a real file: 0.5 is already visibly compressed, and
    /// everything from 0.95 to 0.99 produced byte-identical output, so this
    /// keeps 0.95 as its own step and treats 1.0 as a distinct 7th one
    /// rather than wasting slider travel on indistinguishable values.
    private static let qualitySteps: [Double] = [0.5, 0.6, 0.7, 0.8, 0.9, 0.95, 1.0]

    /// The slider itself operates on a 1...7 step index, converting to/from
    /// whichever `qualitySteps` value is actually stored — matched to the
    /// *closest* step rather than requiring an exact hit, so a value from
    /// anywhere else (or a hypothetical future default) still lands
    /// somewhere sensible instead of the binding silently failing.
    private var qualityStepIndex: Binding<Double> {
        Binding(
            get: {
                let closest = Self.qualitySteps.indices.min { lhs, rhs in
                    abs(Self.qualitySteps[lhs] - jpegCompressionQuality) < abs(Self.qualitySteps[rhs] - jpegCompressionQuality)
                } ?? Self.qualitySteps.count - 1
                return Double(closest + 1)
            },
            set: { newValue in
                let index = Int(newValue.rounded()) - 1
                jpegCompressionQuality = Self.qualitySteps[max(0, min(index, Self.qualitySteps.count - 1))]
            }
        )
    }

    var body: some View {
        Form {
            Section("Image Quality") {
                // `Slider`'s own `label:` already renders visibly here
                // (macOS doesn't treat it as accessibility-only the way
                // some other controls' labels are) — a separate `Text`
                // with the same title above it just duplicated it.
                Slider(value: qualityStepIndex, in: 1...7, step: 1) {
                    Text("Image Save Quality")
                } minimumValueLabel: {
                    Text("Low")
                } maximumValueLabel: {
                    Text("High")
                }
                Text("Applies to JPEG and HEIC. TIFF and PNG are lossless and always saved at full quality.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Backups") {
                Toggle("Generate backup files .bak when saving", isOn: $createBackupFiles)
                    .toggleStyle(.switch)
                    .controlSize(.regular)
            }
            Section("Save Location") {
                Picker("", selection: $saveToCustomFolder) {
                    Text("Overwrite the original file").tag(false)
                    Text("Save a copy to a folder").tag(true)
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()

                HStack {
                    if customSaveFolderPath.isEmpty {
                        Text("No folder chosen")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(customSaveFolderPath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    Button("Choose") { chooseFolder() }
                }
                .disabled(!saveToCustomFolder)
            }
            Section("Safety") {
                Toggle("Warn before quitting with unsaved changes", isOn: $warnBeforeQuit)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Save Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            customSaveFolderPath = url.path
        }
    }
}
