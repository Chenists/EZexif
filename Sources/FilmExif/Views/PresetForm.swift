import SwiftUI

struct CustomFieldRow: Identifiable {
    let id = UUID()
    var key: String
    var value: String
}

/// Create/edit form for one preset: a name, its category's fixed fields (a
/// combo box when there's a short list of common values, otherwise free
/// text) grouped into one section per category involved — the preset's own
/// primary category, plus any `extraFieldCategories` it also offers (e.g. a
/// Lab preset also showing Development and Scanning as their own same-level
/// sections) — and any number of user-defined custom key/value pairs, plus a
/// one-click copy of whatever's currently shown in the main window.
struct PresetForm: View {
    let initialPreset: FilmPreset?
    let initialCategory: PresetCategory
    let currentMetadata: FilmMetadata
    let onSave: (FilmPreset) -> Void

    @State private var name: String
    @State private var category: PresetCategory
    @State private var fixedValues: [String: String]
    /// Which fields are currently shown, per field group — keyed by
    /// `category` itself for the primary group, or by one of its
    /// `extraFieldCategories` for an extra same-level group. A preset only
    /// ever writes the fields it actually needs, so fields are opt-in via
    /// the footer's "+" menu rather than always listing everything a group
    /// could have.
    @State private var addedFieldLabelsByGroup: [PresetCategory: [String]]
    @State private var customRows: [CustomFieldRow]

    init(
        initialPreset: FilmPreset?,
        initialCategory: PresetCategory,
        currentMetadata: FilmMetadata,
        onSave: @escaping (FilmPreset) -> Void
    ) {
        self.initialPreset = initialPreset
        self.initialCategory = initialCategory
        self.currentMetadata = currentMetadata
        self.onSave = onSave

        let resolvedCategory = initialPreset?.category ?? initialCategory
        let primarySpecs = resolvedCategory.fixedFieldSpecs
            + resolvedCategory.extraIndividualFieldLabels.compactMap(PresetCategory.fixedFieldSpec(labeled:))
        let allGroups: [(PresetCategory, [FixedFieldSpec])] = [(resolvedCategory, primarySpecs)]
            + resolvedCategory.extraFieldCategories.map { ($0, $0.fixedFieldSpecs) }

        _name = State(initialValue: initialPreset?.name ?? "")
        _category = State(initialValue: resolvedCategory)
        _fixedValues = State(initialValue: Dictionary(uniqueKeysWithValues: allGroups.flatMap { _, specs in
            specs.map { spec in (spec.label, initialPreset.map { $0.metadata[keyPath: spec.keyPath] } ?? "") }
        }))
        // The primary group always shows the category's default fields
        // (even a brand-new preset with nothing set yet); an extra group
        // (e.g. Lab's Development/Scanning) has no defaults of its own here
        // — it only starts non-empty if an existing preset already set one
        // of its fields. Everything else comes from the "+" menu.
        var initialAdded: [PresetCategory: [String]] = [:]
        for (group, specs) in allGroups {
            initialAdded[group] = specs
                .filter { spec in
                    (group == resolvedCategory && resolvedCategory.defaultFieldLabels.contains(spec.label))
                        || !(initialPreset?.metadata[keyPath: spec.keyPath] ?? "").isEmpty
                }
                .map { $0.label }
        }
        _addedFieldLabelsByGroup = State(initialValue: initialAdded)
        _customRows = State(initialValue: (initialPreset?.metadata.customFields ?? [:])
            .map { CustomFieldRow(key: $0.key, value: $0.value) }
            .sorted { $0.key < $1.key })
    }

    /// The primary group's fields: `category`'s own `fixedFieldSpecs`, plus
    /// anything it borrows via `extraIndividualFieldLabels` (shown inline in
    /// this same group, not as a separate section).
    private var primaryGroupFieldSpecs: [FixedFieldSpec] {
        category.fixedFieldSpecs + category.extraIndividualFieldLabels.compactMap(PresetCategory.fixedFieldSpec(labeled:))
    }

    /// Every field group this form shows, in order: the primary group
    /// first, then one per `extraFieldCategories`.
    private var fieldGroups: [(group: PresetCategory, specs: [FixedFieldSpec])] {
        [(category, primaryGroupFieldSpecs)] + category.extraFieldCategories.map { ($0, $0.fixedFieldSpecs) }
    }

    private func addedFieldSpecs(_ specs: [FixedFieldSpec], in group: PresetCategory) -> [FixedFieldSpec] {
        let added = addedFieldLabelsByGroup[group] ?? []
        return specs.filter { added.contains($0.label) }
    }

    private func availableFieldSpecs(_ specs: [FixedFieldSpec], in group: PresetCategory) -> [FixedFieldSpec] {
        let added = addedFieldLabelsByGroup[group] ?? []
        return specs.filter { !added.contains($0.label) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // An existing preset's name is already shown, and
                    // renamable by double-click, in the list to the left —
                    // repeating it here would just be a duplicate. A
                    // brand-new preset has no list row yet, so it still
                    // needs a compact way to set its name before it can be
                    // saved.
                    if initialPreset == nil {
                        TextField("Preset name", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    ForEach(fieldGroups, id: \.group) { group, specs in
                        let shown = addedFieldSpecs(specs, in: group)
                        let isPrimary = group == category
                        // The primary group always shows — it's the
                        // preset's own identity, even with nothing added
                        // yet. An extra group (e.g. Lab's Development/
                        // Scanning) only appears once it actually has a
                        // field in it, so a Lab preset that never touches
                        // Development doesn't carry an empty "Development"
                        // section around.
                        if isPrimary || !shown.isEmpty {
                            FieldGroup(
                                title: LocalizedStringKey(isPrimary ? category.primaryFieldGroupTitle : group.title),
                                titleFont: .callout.bold()
                            ) {
                                if shown.isEmpty {
                                    Text("No fields added yet")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                ForEach(shown) { spec in
                                    fixedFieldRow(spec, group: group)
                                }
                            }
                        }
                    }

                    if !customRows.isEmpty {
                        FieldGroup(title: "Custom Fields", titleFont: .callout.bold()) {
                            ForEach($customRows) { $row in
                                HStack {
                                    TextField("Key", text: $row.key)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 160)
                                    TextField("Value", text: $row.value)
                                        .textFieldStyle(.roundedBorder)
                                    Button {
                                        customRows.removeAll { $0.id == row.id }
                                    } label: {
                                        Image(systemName: "minus.circle")
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            Divider()
            footer
        }
    }

    /// A different Manufacturer invalidates whatever Name/Film Type/Film
    /// ISO/Process were showing for the old one, so they're cleared rather
    /// than left stale — picking a new Name (below) re-fills Type/ISO/
    /// Process for the new maker.
    ///
    /// Wired into the Manufacturer field's own binding (see
    /// `fieldBinding(for:in:)`), not a passive `.onChange` on `fixedValues`
    /// — a bare `.onChange(of: fixedValues["Manufacturer"])` also fired when
    /// "Copy Current Values" or "Revert" bulk-wrote Manufacturer and Name at
    /// the same time, immediately erasing the very values that write had
    /// just set. Only the combo box itself setting a new value should
    /// trigger this.
    private func handleFilmMakerChange() {
        fixedValues["Name"] = ""
        fixedValues["Film Type"] = ""
        fixedValues["Film ISO"] = ""
        fixedValues["Process"] = ""
    }

    /// Same lookup as the per-photo/batch editors: once a Film preset's
    /// Manufacturer and Name both match a stock in `FilmStockDatabase`,
    /// fills in Film Type, Film ISO, and Process — overwriting whatever was
    /// there (so switching from one named stock to another updates them to
    /// match) and auto-adding whichever of those aren't already shown,
    /// since a fresh Film preset doesn't have "Process" added by default
    /// (it's borrowed from Development).
    private func applyFilmStockAutoFill() {
        guard let stock = FilmStockDatabase.stock(maker: fixedValues["Manufacturer"] ?? "", name: fixedValues["Name"] ?? "")
        else { return }
        setFieldValue("Film Type", FieldSuggestions.filmTypeCode(forCanonicalName: stock.type), in: category)
        setFieldValue("Film ISO", stock.iso, in: category)
        setFieldValue("Process", FieldSuggestions.processCode(forCanonicalName: stock.process), in: category)
    }

    private func setFieldValue(_ label: String, _ value: String, in group: PresetCategory) {
        fixedValues[label] = value
        if !(addedFieldLabelsByGroup[group] ?? []).contains(label) {
            addedFieldLabelsByGroup[group, default: []].append(label)
        }
    }

    /// Fixed at the bottom of the form — doesn't scroll with the fields.
    /// Same height as the preset list's "+/-" bar beside it, so the two
    /// dividers line up at the same height across the window.
    private var footer: some View {
        HStack {
            Menu {
                ForEach(availableFieldSpecs(primaryGroupFieldSpecs, in: category)) { spec in
                    Button(LocalizedStringKey(spec.label)) {
                        addedFieldLabelsByGroup[category, default: []].append(spec.label)
                    }
                }
                ForEach(category.extraFieldCategories) { extraCategory in
                    let extraAvailable = availableFieldSpecs(extraCategory.fixedFieldSpecs, in: extraCategory)
                    if !extraAvailable.isEmpty {
                        Menu(LocalizedStringKey(extraCategory.title)) {
                            ForEach(extraAvailable) { spec in
                                Button(LocalizedStringKey(spec.label)) {
                                    addedFieldLabelsByGroup[extraCategory, default: []].append(spec.label)
                                }
                            }
                        }
                    }
                }
                Divider()
                Button("Custom Field") { customRows.append(CustomFieldRow(key: "", value: "")) }
            } label: {
                Image(systemName: "plus")
                    .frame(width: 20, height: 20)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 20)
            .help("Add a field")
            Button("Copy Current Values") { copyCurrentValues() }
            Spacer()
            Button("Revert") { revertFields() }
            Button("Save") { save() }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 10)
        .frame(height: 44)
    }

    /// "Name" in the Film group's suggestions depend on the current
    /// "Manufacturer" value rather than being fixed, same as the per-photo
    /// editor's Film section — `nil` for every other field, meaning "use
    /// `spec.suggestions` as normal".
    private func dynamicSuggestions(for spec: FixedFieldSpec, group: PresetCategory) -> [String]? {
        guard group == .film, spec.label == "Name" else { return nil }
        return FilmStockDatabase.names(forMaker: fixedValues["Manufacturer"] ?? "")
    }

    @ViewBuilder
    private func fixedFieldRow(_ spec: FixedFieldSpec, group: PresetCategory) -> some View {
        HStack {
            Text(LocalizedStringKey(spec.label))
                .frame(width: 150, alignment: .leading)
                .foregroundStyle(.secondary)
            let suggestions = dynamicSuggestions(for: spec, group: group) ?? spec.suggestions
            let valueBinding = fieldBinding(for: spec, group: group)
            if suggestions.isEmpty {
                TextField("", text: valueBinding)
                    .textFieldStyle(.roundedBorder)
            } else {
                ComboBoxField(text: valueBinding, options: suggestions)
            }
            // A preset isn't tied to any one photo, so there's no capture
            // time to generate from here — always the current year.
            if spec.label == "Copyright" {
                Button {
                    fixedValues["Copyright"] = MetadataEditorView.generatedCopyright(
                        year: nil,
                        photographer: fixedValues["Photographer"] ?? ""
                    )
                } label: {
                    Image(systemName: "wand.and.stars")
                }
                .buttonStyle(.plain)
                .help("Generate Copyright")
            }
            Button {
                addedFieldLabelsByGroup[group, default: []].removeAll { $0 == spec.label }
                fixedValues[spec.label] = ""
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.plain)
        }
    }

    private func binding(for label: String) -> Binding<String> {
        Binding(
            get: { fixedValues[label] ?? "" },
            set: { fixedValues[label] = $0 }
        )
    }

    /// Like `binding(for:)`, but for Film's Manufacturer/Name specifically —
    /// setting either also runs the film-stock cascade (see
    /// `handleFilmMakerChange`/`applyFilmStockAutoFill`), scoped to the
    /// field's own binding so it only fires on a genuine edit through this
    /// exact control, not any other write to `fixedValues`.
    private func fieldBinding(for spec: FixedFieldSpec, group: PresetCategory) -> Binding<String> {
        // `fixedValues` always holds the raw stored code for these two
        // fields (same convention as the per-photo editors) — only the
        // combo box's own displayed text goes through the localized label.
        // Checked by label alone, not label + group: "Process" in
        // particular renders under `group == .film` too, since Film
        // borrows it via `extraIndividualFieldLabels` — a `group ==
        // .development` guard here would silently stop converting it the
        // moment it's shown inside a Film preset instead of a Development
        // one, which is exactly how it's shown when `applyFilmStockAutoFill`
        // fills it in.
        if spec.label == "Film Type" {
            return Binding(
                get: { FieldSuggestions.filmTypeDisplayValue(fixedValues[spec.label] ?? "") },
                set: { newDisplayValue in fixedValues[spec.label] = FieldSuggestions.filmTypeRawValue(newDisplayValue) }
            )
        }
        if spec.label == "Process" {
            return Binding(
                get: { FieldSuggestions.processDisplayValue(fixedValues[spec.label] ?? "") },
                set: { newDisplayValue in fixedValues[spec.label] = FieldSuggestions.processRawValue(newDisplayValue) }
            )
        }
        if group == .development, spec.label == "Push/Pull" {
            return Binding(
                get: { FieldSuggestions.pushPullDisplayValue(fixedValues[spec.label] ?? "") },
                set: { newDisplayValue in fixedValues[spec.label] = FieldSuggestions.pushPullRawValue(newDisplayValue) }
            )
        }
        if spec.label == "Exposure Program" {
            return Binding(
                get: { FieldSuggestions.exposureProgramDisplayValue(fixedValues[spec.label] ?? "") },
                set: { newDisplayValue in fixedValues[spec.label] = FieldSuggestions.exposureProgramRawValue(newDisplayValue) }
            )
        }
        if spec.label == "White Balance" {
            return Binding(
                get: { FieldSuggestions.whiteBalanceDisplayValue(fixedValues[spec.label] ?? "") },
                set: { newDisplayValue in fixedValues[spec.label] = FieldSuggestions.whiteBalanceRawValue(newDisplayValue) }
            )
        }
        if spec.label == "Metering Mode" {
            return Binding(
                get: { FieldSuggestions.meteringModeDisplayValue(fixedValues[spec.label] ?? "") },
                set: { newDisplayValue in fixedValues[spec.label] = FieldSuggestions.meteringModeRawValue(newDisplayValue) }
            )
        }
        guard group == .film, spec.label == "Manufacturer" || spec.label == "Name" else {
            return binding(for: spec.label)
        }
        return Binding(
            get: { fixedValues[spec.label] ?? "" },
            set: { newValue in
                fixedValues[spec.label] = newValue
                if spec.label == "Manufacturer" {
                    handleFilmMakerChange()
                } else {
                    applyFilmStockAutoFill()
                }
            }
        )
    }

    private func copyCurrentValues() {
        for (group, specs) in fieldGroups {
            for spec in specs {
                let value = currentMetadata[keyPath: spec.keyPath]
                guard !value.isEmpty else { continue }
                fixedValues[spec.label] = value
                if !(addedFieldLabelsByGroup[group] ?? []).contains(spec.label) {
                    addedFieldLabelsByGroup[group, default: []].append(spec.label)
                }
            }
        }
        for (key, value) in currentMetadata.customFields where !value.isEmpty {
            if let index = customRows.firstIndex(where: { $0.key == key }) {
                customRows[index].value = value
            } else {
                customRows.append(CustomFieldRow(key: key, value: value))
            }
        }
    }

    /// Discards unsaved edits, resetting fields back to `initialPreset`'s
    /// saved values (or blank, for a preset that hasn't been saved yet) —
    /// same "undo my changes, stay here" meaning as `Revert` elsewhere in
    /// the app, rather than dismissing the form.
    private func revertFields() {
        name = initialPreset?.name ?? ""
        fixedValues = Dictionary(uniqueKeysWithValues: fieldGroups.flatMap { _, specs in
            specs.map { spec in (spec.label, initialPreset.map { $0.metadata[keyPath: spec.keyPath] } ?? "") }
        })
        var resetAdded: [PresetCategory: [String]] = [:]
        for (group, specs) in fieldGroups {
            resetAdded[group] = specs
                .filter { spec in
                    (group == category && category.defaultFieldLabels.contains(spec.label))
                        || !(initialPreset?.metadata[keyPath: spec.keyPath] ?? "").isEmpty
                }
                .map { $0.label }
        }
        addedFieldLabelsByGroup = resetAdded
        customRows = (initialPreset?.metadata.customFields ?? [:])
            .map { CustomFieldRow(key: $0.key, value: $0.value) }
            .sorted { $0.key < $1.key }
    }

    private func save() {
        var metadata = FilmMetadata()
        for (_, specs) in fieldGroups {
            for spec in specs {
                metadata[keyPath: spec.keyPath] = fixedValues[spec.label] ?? ""
            }
        }
        for row in customRows {
            let key = row.key.trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty, !row.value.isEmpty else { continue }
            metadata.customFields[key] = row.value
        }
        let preset = FilmPreset(
            id: initialPreset?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            category: category,
            metadata: metadata
        )
        onSave(preset)
    }
}
