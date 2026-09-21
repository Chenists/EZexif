import SwiftUI

/// Editor shown when multiple photos are selected — fields entered here get
/// applied to every selected item's corresponding section as soon as they
/// change, leaving fields left blank alone. The draft fields themselves
/// live in `library.batchDraft`, not local `@State`, so applying a preset
/// while several photos are selected can update what's shown here directly.
struct BatchEditorView: View {
    let items: [PhotoItem]
    @EnvironmentObject var library: PhotoLibrary
    @EnvironmentObject var fieldVisibility: FieldVisibilityStore
    @State private var showingMapPicker = false
    @State private var showingAutoNumber = false
    @AppStorage(AppSettingsKeys.temperatureUnit) private var temperatureUnitRaw = TemperatureUnit.celsius.rawValue
    @AppStorage(AppSettingsKeys.apertureDisplayFormat) private var apertureDisplayFormatRaw = ApertureDisplayFormat.number.rawValue

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        fields
                    }
                    .padding(24)
                }
                .onChange(of: library.lastPresetApply) { _, event in
                    guard let event else { return }
                    withAnimation {
                        proxy.scrollTo(event.category.scrollSectionID, anchor: .center)
                    }
                }
                .onChange(of: library.lastUndoScroll) { _, event in
                    guard let event else { return }
                    withAnimation {
                        proxy.scrollTo(event.sectionID, anchor: .center)
                    }
                }
            }
            Divider()
            footer
        }
        // Every batch-field edit (typing, or a preset landing in the draft)
        // was only ever staged in `batchDraft` until "Save" merged it into
        // each selected item — so the orange dirty dot on those rows never
        // reacted to batch edits, only to Save. Applying on every change
        // makes each selected item's `edited` track the draft live, the
        // same way the single-photo editor's fields write straight into
        // `item.edited` on every keystroke; "Save" then only needs to
        // write the (already-applied) result to disk.
        .onChange(of: library.batchDraft) { _, newValue in
            library.applyToSelection(newValue)
        }
        .sheet(isPresented: $showingMapPicker) {
            // See the same `.id(...)` fix in `MetadataEditorView` — without
            // it, a later selection's map picker could open still centered
            // on an earlier selection's location.
            MapLocationPickerView(latitude: $library.batchDraft.latitude, longitude: $library.batchDraft.longitude)
                .id(library.selection)
        }
        .sheet(isPresented: $showingAutoNumber) {
            AutoNumberExposuresView(items: items)
        }
    }

    /// Same "wired into the field's own binding, not a passive `.onChange`"
    /// approach as `MetadataEditorView`'s — see its `filmMakerBinding` for
    /// why: a bare `.onChange(of: library.batchDraft.film.maker)` also fired
    /// when a Film preset set Manufacturer and Name in the same instant,
    /// immediately erasing the very values the preset had just applied.
    /// Same cascading reset as `MetadataEditorView.fileSourceBinding`, but
    /// for the batch draft: an empty sub-struct here means "leave every
    /// selected item's own existing value alone" (see
    /// `FilmMetadata.merging(overridingWith:)`/`PhotoLibrary.applyToSelection`),
    /// which is the batch-mode equivalent of "restore to what's on disk" —
    /// there's no single shared "original" across a multi-photo selection.
    // MARK: - Per-section "Clear Section" buttons
    //
    // Only touch fields currently visible per `fieldVisibility` — same
    // convention as `MetadataEditorView`'s. Unlike a normal batch edit
    // (which only ever *overlays* `batchDraft`'s non-empty fields onto each
    // selected item — see `FilmMetadata.merging(overridingWith:)` — so a
    // blank field there means "leave it alone"), clearing has to reach past
    // that: it writes the cleared value straight into every selected
    // item's `edited` directly, the same way "Revert" already does,
    // since writing blanks into `batchDraft` alone would be a no-op. Each
    // section's field list lives once, in a pure "cleared" transform, reused
    // for both that direct per-item write and resetting `batchDraft` itself
    // so the form visibly reflects the clear.

    private func clearedBasics(_ meta: FilmMetadata) -> FilmMetadata {
        var updated = meta
        if fieldVisibility.isVisible("ISO") { updated.shotISO = "" }
        if fieldVisibility.isVisible("Aperture") { updated.aperture = "" }
        if fieldVisibility.isVisible("Shutter Speed") { updated.shutterSpeed = "" }
        if fieldVisibility.isVisible("Exposure Bias") { updated.exposureBias = "" }
        if fieldVisibility.isVisible("Focal Length") { updated.focalLength = "" }
        if fieldVisibility.isVisible("35mm Equivalent Focal Length") { updated.focalLengthIn35mmFormat = "" }
        if fieldVisibility.isVisible("Exposure Program") { updated.exposureProgram = "" }
        if fieldVisibility.isVisible("White Balance") { updated.whiteBalance = "" }
        if fieldVisibility.isVisible("Metering Mode") { updated.meteringMode = "" }
        if fieldVisibility.isVisible("Location") {
            updated.latitude = nil
            updated.longitude = nil
        }
        if fieldVisibility.isVisible("Altitude") { updated.altitude = nil }
        if fieldVisibility.isVisible("Rating") { updated.rating = 0 }
        return updated
    }
    private func clearBasicsFields() {
        for item in library.selectedItems { item.edited = clearedBasics(item.edited) }
        library.batchDraft = clearedBasics(library.batchDraft)
    }

    private func clearedFile(_ meta: FilmMetadata) -> FilmMetadata {
        var updated = meta
        if fieldVisibility.isVisible("File Source") { updated.fileSource = "" }
        if fieldVisibility.isVisible("Is Film Photo") { updated.isFilmPhoto = "" }
        return updated
    }
    private func clearFileFields() {
        for item in library.selectedItems { item.edited = clearedFile(item.edited) }
        library.batchDraft = clearedFile(library.batchDraft)
    }

    private func clearedPhotographer(_ meta: FilmMetadata) -> FilmMetadata {
        var updated = meta
        if fieldVisibility.isVisible("Photographer") { updated.artist = "" }
        if fieldVisibility.isVisible("Copyright") { updated.copyright = "" }
        return updated
    }
    private func clearPhotographerFields() {
        for item in library.selectedItems { item.edited = clearedPhotographer(item.edited) }
        library.batchDraft = clearedPhotographer(library.batchDraft)
    }

    private func clearedCameraLens(_ meta: FilmMetadata) -> FilmMetadata {
        var updated = meta
        if fieldVisibility.isVisible("Camera Make") { updated.cameraMake = "" }
        if fieldVisibility.isVisible("Camera Model") { updated.cameraModel = "" }
        if fieldVisibility.isVisible("Camera Serial Number") { updated.cameraSerialNumber = "" }
        if fieldVisibility.isVisible("Camera Firmware") { updated.cameraFirmware = "" }
        if fieldVisibility.isVisible("Camera Owner Name") { updated.cameraOwnerName = "" }
        if fieldVisibility.isVisible("Lens Make") { updated.lensMake = "" }
        if fieldVisibility.isVisible("Lens Model") { updated.lensModel = "" }
        if fieldVisibility.isVisible("Lens Serial Number") { updated.lensSerialNumber = "" }
        if fieldVisibility.isVisible("Lens Specification") { updated.lensSpecification = "" }
        return updated
    }
    private func clearCameraLensFields() {
        for item in library.selectedItems { item.edited = clearedCameraLens(item.edited) }
        library.batchDraft = clearedCameraLens(library.batchDraft)
    }

    private func clearedFilm(_ meta: FilmMetadata) -> FilmMetadata {
        var updated = meta
        if fieldVisibility.isVisible("Manufacturer") { updated.film.maker = "" }
        if fieldVisibility.isVisible("Name") { updated.film.name = "" }
        if fieldVisibility.isVisible("Film Type") { updated.film.type = "" }
        if fieldVisibility.isVisible("Format") { updated.film.format = "" }
        if fieldVisibility.isVisible("Film ISO") { updated.film.iso = "" }
        if fieldVisibility.isVisible("DX Code") { updated.film.dxCode = "" }
        if fieldVisibility.isVisible("Film Batch") { updated.film.batch = "" }
        if fieldVisibility.isVisible("Emulsion Number") { updated.film.emulsionNumber = "" }
        if fieldVisibility.isVisible("Base") { updated.film.base = "" }
        if fieldVisibility.isVisible("Film Grain") { updated.film.grain = "" }
        return updated
    }
    private func clearFilmFields() {
        for item in library.selectedItems { item.edited = clearedFilm(item.edited) }
        library.batchDraft = clearedFilm(library.batchDraft)
    }

    private func clearedRoll(_ meta: FilmMetadata) -> FilmMetadata {
        var updated = meta
        if fieldVisibility.isVisible("Roll ID") { updated.roll.id = "" }
        if fieldVisibility.isVisible("Frame Number") { updated.roll.frameNumber = "" }
        if fieldVisibility.isVisible("Total Frame Count") { updated.roll.frameCount = "" }
        if fieldVisibility.isVisible("Exposure ISO") { updated.roll.exposureISO = "" }
        if fieldVisibility.isVisible("Loaded Date") { updated.roll.loadedDate = nil }
        if fieldVisibility.isVisible("Finished Date") { updated.roll.finishedDate = nil }
        if fieldVisibility.isVisible("Development Batch") { updated.roll.developmentBatch = "" }
        return updated
    }
    private func clearRollFields() {
        for item in library.selectedItems { item.edited = clearedRoll(item.edited) }
        library.batchDraft = clearedRoll(library.batchDraft)
    }

    private func clearedDevelopment(_ meta: FilmMetadata) -> FilmMetadata {
        var updated = meta
        if fieldVisibility.isVisible("Process") { updated.development.process = "" }
        if fieldVisibility.isVisible("Developer") { updated.development.developer = "" }
        if fieldVisibility.isVisible("Developer Manufacturer") { updated.development.developerMaker = "" }
        if fieldVisibility.isVisible("Developer Dilution") { updated.development.developerDilution = "" }
        if fieldVisibility.isVisible("Development Time") { updated.development.developedAt = nil }
        if fieldVisibility.isVisible("Development Duration") { updated.development.duration = "" }
        if fieldVisibility.isVisible("Development Temperature") { updated.development.temperature = "" }
        if fieldVisibility.isVisible("Push/Pull") { updated.development.pushPull = "" }
        if fieldVisibility.isVisible("Bleach") { updated.development.bleach = "" }
        if fieldVisibility.isVisible("Fixer") { updated.development.fixer = "" }
        if fieldVisibility.isVisible("Stabilizer") { updated.development.stabilizer = "" }
        if fieldVisibility.isVisible("Replenishment") { updated.development.replenishment = "" }
        if fieldVisibility.isVisible("Chemistry Notes") { updated.development.chemistryNotes = "" }
        return updated
    }
    private func clearDevelopmentFields() {
        for item in library.selectedItems { item.edited = clearedDevelopment(item.edited) }
        library.batchDraft = clearedDevelopment(library.batchDraft)
    }

    private func clearedLab(_ meta: FilmMetadata) -> FilmMetadata {
        var updated = meta
        if fieldVisibility.isVisible("Lab Name") { updated.lab.name = "" }
        if fieldVisibility.isVisible("Lab Address") { updated.lab.address = "" }
        if fieldVisibility.isVisible("Lab Contact") { updated.lab.contact = "" }
        if fieldVisibility.isVisible("Lab Notes") { updated.lab.labNotes = "" }
        return updated
    }
    private func clearLabFields() {
        for item in library.selectedItems { item.edited = clearedLab(item.edited) }
        library.batchDraft = clearedLab(library.batchDraft)
    }

    private func clearedScanning(_ meta: FilmMetadata) -> FilmMetadata {
        var updated = meta
        if fieldVisibility.isVisible("Scanner Make") { updated.scanning.scannerMaker = "" }
        if fieldVisibility.isVisible("Scanner Model") { updated.scanning.scannerModel = "" }
        if fieldVisibility.isVisible("Scanner Serial Number") { updated.scanning.scannerSerialNumber = "" }
        if fieldVisibility.isVisible("Scanner Software") { updated.scanning.scannerSoftware = "" }
        if fieldVisibility.isVisible("Scan Resolution") { updated.scanning.resolution = "" }
        if fieldVisibility.isVisible("Bit Depth") { updated.scanning.bitDepth = "" }
        if fieldVisibility.isVisible("Color Space") { updated.scanning.colorSpace = "" }
        if fieldVisibility.isVisible("Scan Type") { updated.scanning.scanType = "" }
        if fieldVisibility.isVisible("Scan Date") { updated.scanning.scanDate = nil }
        if fieldVisibility.isVisible("Dust Removal") { updated.scanning.dustRemoval = false }
        if fieldVisibility.isVisible("Infrared Cleaning") { updated.scanning.infraredCleaning = false }
        if fieldVisibility.isVisible("Scan Notes") { updated.scanning.scanNotes = "" }
        return updated
    }
    private func clearScanningFields() {
        for item in library.selectedItems { item.edited = clearedScanning(item.edited) }
        library.batchDraft = clearedScanning(library.batchDraft)
    }

    private func clearNotesField() {
        for item in library.selectedItems { item.edited.notes = "" }
        library.batchDraft.notes = ""
    }

    /// Returns the value at `keyPath` shared by every selected item, but
    /// only when it's non-empty and every item actually agrees on it —
    /// shown as a placeholder hint in an otherwise-empty batch field so a
    /// value common to the whole selection is visible without writing it
    /// into `batchDraft`, which would make it part of what gets saved (see
    /// the "empty means don't touch" convention used throughout this file).
    private func commonValue(_ keyPath: KeyPath<FilmMetadata, String>) -> String {
        guard let first = items.first?.edited[keyPath: keyPath], !first.isEmpty else { return "" }
        guard items.dropFirst().allSatisfy({ $0.edited[keyPath: keyPath] == first }) else { return "" }
        return first
    }

    /// Stores/compares `fileSource` as a bare numeric code (see
    /// `FieldSuggestions.fileSourceDisplayValue`/`...RawValue`) — this
    /// binding is the one place that code converts to/from the localized
    /// text the combo box actually shows and edits.
    private var fileSourceBinding: Binding<String> {
        Binding(
            get: { FieldSuggestions.fileSourceDisplayValue(library.batchDraft.fileSource) },
            set: { newDisplayValue in
                // One assignment to `batchDraft`, not two — its own
                // `.onChange` applies it to every selected item, so this
                // also keeps that as a single apply instead of two.
                var updated = library.batchDraft
                let newRawValue = FieldSuggestions.fileSourceRawValue(newDisplayValue)
                updated.fileSource = newRawValue
                if newRawValue == FieldSuggestions.digitalStillCameraCode {
                    updated.scanning = ScanningInfo()
                }
                library.batchDraft = updated
            }
        )
    }

    /// Same idea as `fileSourceBinding`, for the four sections "Is Film
    /// Photo" = "No" disables.
    private var isFilmPhotoBinding: Binding<String> {
        Binding(
            get: { FieldSuggestions.filmPhotoDisplayValue(library.batchDraft.isFilmPhoto) },
            set: { newDisplayValue in
                var updated = library.batchDraft
                let newRawValue = FieldSuggestions.filmPhotoRawValue(newDisplayValue)
                updated.isFilmPhoto = newRawValue
                if newRawValue == FieldSuggestions.filmPhotoNoCode {
                    updated.film = FilmInfo()
                    updated.roll = RollInfo()
                    updated.development = DevelopmentInfo()
                    updated.lab = LabInfo()
                }
                library.batchDraft = updated
            }
        )
    }

    private var filmMakerBinding: Binding<String> {
        Binding(
            get: { library.batchDraft.film.maker },
            set: { newValue in
                library.batchDraft.film.maker = newValue
                library.batchDraft.film.name = ""
                library.batchDraft.film.type = ""
                library.batchDraft.film.iso = ""
                library.batchDraft.development.process = ""
            }
        )
    }

    /// Same auto-fill as `MetadataEditorView`'s, applied to the batch draft
    /// instead of one photo — overwrites Film Type, Film ISO, and Process
    /// so switching from one named stock to another updates them to match.
    private var filmNameBinding: Binding<String> {
        Binding(
            get: { library.batchDraft.film.name },
            set: { newValue in
                library.batchDraft.film.name = newValue
                guard let stock = FilmStockDatabase.stock(maker: library.batchDraft.film.maker, name: newValue) else { return }
                library.batchDraft.film.type = FieldSuggestions.filmTypeCode(forCanonicalName: stock.type)
                library.batchDraft.film.iso = stock.iso
                library.batchDraft.development.process = FieldSuggestions.processCode(forCanonicalName: stock.process)
            }
        )
    }

    /// Same "auto-append missing unit" convention as `MetadataEditorView`'s.
    private var developmentTemperatureBinding: Binding<String> {
        Binding(
            get: { library.batchDraft.development.temperature },
            set: { newValue in
                library.batchDraft.development.temperature = MetadataEditorView.appendingTemperatureUnitIfNeeded(newValue, unitRaw: temperatureUnitRaw)
            }
        )
    }

    private var apertureDisplayFormat: ApertureDisplayFormat {
        ApertureDisplayFormat(rawValue: apertureDisplayFormatRaw) ?? .number
    }

    /// Same "display-only formatting, model always stays a bare number"
    /// approach as `MetadataEditorView`'s.
    private var apertureBinding: Binding<String> {
        Binding(
            get: {
                let raw = library.batchDraft.aperture
                guard apertureDisplayFormat == .fStop, !raw.isEmpty else { return raw }
                return raw.lowercased().hasPrefix("f/") ? raw : "f/\(raw)"
            },
            set: { newValue in
                library.batchDraft.aperture = MetadataEditorView.strippingApertureNotation(newValue)
            }
        )
    }

    private var apertureSuggestions: [String] {
        guard apertureDisplayFormat == .fStop else { return FieldSuggestions.apertureValues }
        return FieldSuggestions.apertureValues.map { "f/\($0)" }
    }

    /// Same display formatting as `apertureBinding`'s getter, applied to
    /// the selection's shared raw value (if any) for use as a placeholder.
    private var commonApertureDisplay: String {
        let raw = commonValue(\.aperture)
        guard apertureDisplayFormat == .fStop, !raw.isEmpty else { return raw }
        return raw.lowercased().hasPrefix("f/") ? raw : "f/\(raw)"
    }

    /// Same idea as `commonValue`, for the one field (`altitude`) that's a
    /// `Double?` rather than a bare `String`.
    private var commonAltitudeDisplay: String {
        guard let first = items.first?.edited.altitude else { return "" }
        guard items.dropFirst().allSatisfy({ $0.edited.altitude == first }) else { return "" }
        return String(first)
    }

    /// Same "display-only formatting, model always stays a bare number"
    /// approach as `MetadataEditorView`'s `pushPullBinding`.
    private var pushPullBinding: Binding<String> {
        Binding(
            get: { FieldSuggestions.pushPullDisplayValue(library.batchDraft.development.pushPull) },
            set: { newValue in library.batchDraft.development.pushPull = FieldSuggestions.pushPullRawValue(newValue) }
        )
    }

    private var pushPullSuggestions: [String] {
        FieldSuggestions.pushPullValues.map(FieldSuggestions.pushPullDisplayValue)
    }

    /// Same idea as `filmTypeBinding` elsewhere — stores/compares
    /// `library.batchDraft.film.type` as a bare numeric code.
    private var filmTypeBinding: Binding<String> {
        Binding(
            get: { FieldSuggestions.filmTypeDisplayValue(library.batchDraft.film.type) },
            set: { newDisplayValue in library.batchDraft.film.type = FieldSuggestions.filmTypeRawValue(newDisplayValue) }
        )
    }

    /// Same idea as `filmTypeBinding`, but passes an unrecognized typed
    /// value straight through — see `MetadataEditorView.processBinding`.
    private var processBinding: Binding<String> {
        Binding(
            get: { FieldSuggestions.processDisplayValue(library.batchDraft.development.process) },
            set: { newDisplayValue in library.batchDraft.development.process = FieldSuggestions.processRawValue(newDisplayValue) }
        )
    }

    private var exposureProgramBinding: Binding<String> {
        Binding(
            get: { FieldSuggestions.exposureProgramDisplayValue(library.batchDraft.exposureProgram) },
            set: { newDisplayValue in library.batchDraft.exposureProgram = FieldSuggestions.exposureProgramRawValue(newDisplayValue) }
        )
    }

    private var whiteBalanceBinding: Binding<String> {
        Binding(
            get: { FieldSuggestions.whiteBalanceDisplayValue(library.batchDraft.whiteBalance) },
            set: { newDisplayValue in library.batchDraft.whiteBalance = FieldSuggestions.whiteBalanceRawValue(newDisplayValue) }
        )
    }

    private var meteringModeBinding: Binding<String> {
        Binding(
            get: { FieldSuggestions.meteringModeDisplayValue(library.batchDraft.meteringMode) },
            set: { newDisplayValue in library.batchDraft.meteringMode = FieldSuggestions.meteringModeRawValue(newDisplayValue) }
        )
    }

    /// Fixed at the bottom of the editor, like `MetadataEditorView`'s own
    /// footer — mirrors that editor's Revert/Save pair rather than the
    /// previous separate "Apply to Selection" / "Apply & Save All" buttons,
    /// since "Save" already applies the batch fields to every selected
    /// photo before writing them, in one step.
    private var footer: some View {
        HStack {
            Button("Auto Frame Numbers") { showingAutoNumber = true }
            Spacer()
            Button("Undo") {
                // The draft is just a scratch buffer for what's shown in
                // this form — the real state lives on each selected item,
                // which is what actually recorded the undo history, so
                // undoing means stepping every selected item back by one
                // change and clearing the draft to match (rather than
                // leaving the form showing a value that no longer matches
                // what the items just reverted to).
                library.batchDraft = FilmMetadata()
                var scrollSectionID: String?
                for item in library.selectedItems {
                    if let changed = item.undo(), scrollSectionID == nil {
                        scrollSectionID = changed.lazy.compactMap(FilmMetadata.scrollSectionID(forFieldNamed:)).first
                    }
                }
                if let scrollSectionID {
                    library.lastUndoScroll = .init(sectionID: scrollSectionID)
                }
            }
            .disabled(!library.selectedItems.contains { $0.canUndo })
            .keyboardShortcut("z", modifiers: .command)
            Button("Revert") {
                library.batchDraft = FilmMetadata()
                // The draft is a separate scratch buffer — clearing it
                // alone left any selected item that was *already* dirty
                // (from an earlier individual edit) untouched, so its
                // orange dot never went away. Revert here means "discard
                // unsaved changes on what's selected," same as it does for
                // a single photo, so it needs to reset each item too.
                for item in library.selectedItems {
                    item.edited = item.original
                }
            }
            .disabled(library.batchDraft == FilmMetadata() && !library.selectedItems.contains { $0.isDirty })
            Button("Save") {
                library.applyToSelection(library.batchDraft)
                library.saveAll()
            }
            // `"s"`, not `.return` — `.return` marks this as the window's
            // default action button, which macOS renders with a prominent
            // blue style automatically. The single-photo editor's Save
            // button uses `"s"` for the same reason, staying plain/white.
            .keyboardShortcut("s", modifiers: .command)
            .disabled(library.batchDraft.hasInvalidNumericField)
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
    }

    private var fields: some View {
        Group {
            if fieldVisibility.isAnyVisible(FieldVisibilityRegistry.groups[0].fields.map(\.label)) {
            FieldGroup(title: "Basics", onClear: clearBasicsFields) {
                if fieldVisibility.isVisible("ISO") {
                LabeledComboField("ISO", $library.batchDraft.shotISO, options: FieldSuggestions.isoValues, validatesNumber: true, placeholder: commonValue(\.shotISO))
                }
                if fieldVisibility.isVisible("Aperture") {
                LabeledComboField("Aperture", apertureBinding, options: apertureSuggestions, validatesNumber: apertureDisplayFormat == .number, placeholder: commonApertureDisplay)
                }
                if fieldVisibility.isVisible("Shutter Speed") {
                LabeledComboField("Shutter Speed", $library.batchDraft.shutterSpeed, options: FieldSuggestions.shutterSpeedValues, unit: "s", validatesNumber: true, allowsFraction: true, placeholder: commonValue(\.shutterSpeed))
                }
                if fieldVisibility.isVisible("Exposure Bias") {
                LabeledComboField("Exposure Bias", $library.batchDraft.exposureBias, options: FieldSuggestions.exposureBiasValues, unit: "ev", validatesNumber: true, allowsNegative: true, centerValue: "0 ev", placeholder: commonValue(\.exposureBias))
                }
                if fieldVisibility.isVisible("Focal Length") {
                LabeledComboField("Focal Length", $library.batchDraft.focalLength, options: FieldSuggestions.focalLengthValues, unit: "mm", validatesNumber: true, placeholder: commonValue(\.focalLength))
                }
                if fieldVisibility.isVisible("35mm Equivalent Focal Length") {
                LabeledComboField("35mm Equivalent Focal Length", $library.batchDraft.focalLengthIn35mmFormat, options: FieldSuggestions.focalLengthValues, unit: "mm", validatesNumber: true, placeholder: commonValue(\.focalLengthIn35mmFormat))
                }
                if fieldVisibility.isVisible("Exposure Program") {
                LabeledComboField("Exposure Program", exposureProgramBinding, options: FieldSuggestions.exposureProgramLabels, placeholder: FieldSuggestions.exposureProgramDisplayValue(commonValue(\.exposureProgram)))
                }
                if fieldVisibility.isVisible("White Balance") {
                LabeledComboField("White Balance", whiteBalanceBinding, options: FieldSuggestions.whiteBalanceLabels, placeholder: FieldSuggestions.whiteBalanceDisplayValue(commonValue(\.whiteBalance)))
                }
                if fieldVisibility.isVisible("Metering Mode") {
                LabeledComboField("Metering Mode", meteringModeBinding, options: FieldSuggestions.meteringModeLabels, placeholder: FieldSuggestions.meteringModeDisplayValue(commonValue(\.meteringMode)))
                }
                if fieldVisibility.isVisible("Location") {
                LabeledCoordinateField("Location", latitude: $library.batchDraft.latitude, longitude: $library.batchDraft.longitude) {
                    Button {
                        library.batchDraft.latitude = nil
                        library.batchDraft.longitude = nil
                        library.batchDraft.altitude = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(library.batchDraft.latitude == nil && library.batchDraft.longitude == nil && library.batchDraft.altitude == nil)
                    .help("Clear Location")
                    Button {
                        showingMapPicker = true
                    } label: {
                        Image(systemName: "map")
                    }
                    .buttonStyle(.plain)
                    .help("Map")
                }
                if let lat = library.batchDraft.latitude, let lon = library.batchDraft.longitude {
                    // Same fix as `MetadataEditorView`'s `LocationPreviewMap`
                    // — keying `.id()` on the coordinate alone isn't enough,
                    // since switching to a different selection that happens
                    // to share the same batch-draft coordinate would reuse
                    // the same `Map` (and whatever the user last panned it
                    // to) instead of resetting. Including the selected
                    // items' own ids guarantees a fresh `Map` whenever the
                    // selection changes, coordinates aside.
                    LocationPreviewMap(latitude: lat, longitude: lon)
                        .id("\(items.map { "\($0.id)" }.joined(separator: ","))-\(lat),\(lon)")
                }
                }
                if fieldVisibility.isVisible("Altitude") {
                LabeledField("Altitude", $library.batchDraft.altitude.asOptionalText, placeholder: commonAltitudeDisplay)
                }
                if fieldVisibility.isVisible("Rating") {
                HStack {
                    Text("Rating")
                        .frame(width: 190, alignment: .leading)
                        .foregroundStyle(.secondary)
                    StarRatingView(rating: $library.batchDraft.rating)
                    Spacer()
                }
                }
            }
            .id("section-exposure")
            }

            if fieldVisibility.isAnyVisible(FieldVisibilityRegistry.groups[1].fields.map(\.label)) {
            FieldGroup(title: "File", onClear: clearFileFields) {
                if fieldVisibility.isVisible("File Source") {
                LabeledComboField("File Source", fileSourceBinding, options: FieldSuggestions.fileSourceLabels, placeholder: FieldSuggestions.fileSourceDisplayValue(commonValue(\.fileSource)))
                }
                if fieldVisibility.isVisible("Is Film Photo") {
                LabeledComboField("Is Film Photo", isFilmPhotoBinding, options: FieldSuggestions.filmPhotoLabels, placeholder: FieldSuggestions.filmPhotoDisplayValue(commonValue(\.isFilmPhoto)))
                }
            }
            .id("section-file")
            }

            if fieldVisibility.isAnyVisible(FieldVisibilityRegistry.groups[2].fields.map(\.label)) {
            FieldGroup(title: "Photographer & Copyright", onClear: clearPhotographerFields) {
                if fieldVisibility.isVisible("Photographer") {
                LabeledField("Photographer", $library.batchDraft.artist, placeholder: commonValue(\.artist))
                }
                if fieldVisibility.isVisible("Copyright") {
                LabeledField("Copyright", $library.batchDraft.copyright, placeholder: commonValue(\.copyright)) {
                    Button {
                        library.batchDraft.copyright = MetadataEditorView.generatedCopyright(
                            year: library.batchDraft.dateTimeOriginal,
                            photographer: library.batchDraft.artist
                        )
                    } label: {
                        Image(systemName: "wand.and.stars")
                    }
                    .buttonStyle(.plain)
                    .help("Generate Copyright")
                }
                }
            }
            .id("section-photographer")
            }

            if fieldVisibility.isAnyVisible(FieldVisibilityRegistry.groups[3].fields.map(\.label)) {
            FieldGroup(title: "Camera & Lens", onClear: clearCameraLensFields) {
                if fieldVisibility.isVisible("Camera Make") {
                SuggestibleField("Camera Make", $library.batchDraft.cameraMake, keyPath: \.cameraMake, placeholder: commonValue(\.cameraMake))
                }
                if fieldVisibility.isVisible("Camera Model") {
                LabeledField("Camera Model", $library.batchDraft.cameraModel, placeholder: commonValue(\.cameraModel))
                }
                if fieldVisibility.isVisible("Camera Serial Number") {
                LabeledField("Camera Serial Number", $library.batchDraft.cameraSerialNumber, placeholder: commonValue(\.cameraSerialNumber))
                }
                if fieldVisibility.isVisible("Camera Firmware") {
                LabeledField("Camera Firmware", $library.batchDraft.cameraFirmware, placeholder: commonValue(\.cameraFirmware))
                }
                if fieldVisibility.isVisible("Camera Owner Name") {
                LabeledField("Camera Owner Name", $library.batchDraft.cameraOwnerName, placeholder: commonValue(\.cameraOwnerName))
                }
                if fieldVisibility.isVisible("Lens Make") {
                SuggestibleField("Lens Make", $library.batchDraft.lensMake, keyPath: \.lensMake, placeholder: commonValue(\.lensMake))
                }
                if fieldVisibility.isVisible("Lens Model") {
                LabeledField("Lens Model", $library.batchDraft.lensModel, placeholder: commonValue(\.lensModel))
                }
                if fieldVisibility.isVisible("Lens Serial Number") {
                LabeledField("Lens Serial Number", $library.batchDraft.lensSerialNumber, placeholder: commonValue(\.lensSerialNumber))
                }
                if fieldVisibility.isVisible("Lens Specification") {
                LabeledField("Lens Specification", $library.batchDraft.lensSpecification, placeholder: commonValue(\.lensSpecification))
                }
            }
            .id("section-camera")
            }

            if fieldVisibility.isAnyVisible(FieldVisibilityRegistry.groups[4].fields.map(\.label)) {
            FieldGroup(title: "Film", onClear: clearFilmFields) {
                if fieldVisibility.isVisible("Manufacturer") {
                SuggestibleField("Manufacturer", filmMakerBinding, keyPath: \.film.maker, placeholder: commonValue(\.film.maker))
                }
                if fieldVisibility.isVisible("Name") {
                DynamicSuggestibleField("Name", filmNameBinding, suggestions: FilmStockDatabase.names(forMaker: library.batchDraft.film.maker), placeholder: commonValue(\.film.name))
                }
                if fieldVisibility.isVisible("Film Type") {
                SuggestibleField("Film Type", filmTypeBinding, keyPath: \.film.type, placeholder: FieldSuggestions.filmTypeDisplayValue(commonValue(\.film.type)))
                }
                if fieldVisibility.isVisible("Format") {
                SuggestibleField("Format", $library.batchDraft.film.format, keyPath: \.film.format, placeholder: commonValue(\.film.format))
                }
                if fieldVisibility.isVisible("Film ISO") {
                SuggestibleField("Film ISO", $library.batchDraft.film.iso, keyPath: \.film.iso, placeholder: commonValue(\.film.iso))
                }
                if fieldVisibility.isVisible("DX Code") {
                LabeledField("DX Code", $library.batchDraft.film.dxCode, placeholder: commonValue(\.film.dxCode))
                }
                if fieldVisibility.isVisible("Film Batch") {
                LabeledField("Film Batch", $library.batchDraft.film.batch, placeholder: commonValue(\.film.batch))
                }
                if fieldVisibility.isVisible("Emulsion Number") {
                LabeledField("Emulsion Number", $library.batchDraft.film.emulsionNumber, placeholder: commonValue(\.film.emulsionNumber))
                }
                if fieldVisibility.isVisible("Base") {
                LabeledField("Base", $library.batchDraft.film.base, placeholder: commonValue(\.film.base))
                }
                if fieldVisibility.isVisible("Film Grain") {
                LabeledField("Film Grain", $library.batchDraft.film.grain, placeholder: commonValue(\.film.grain))
                }
            }
            .id("section-film")
            .disabled(library.batchDraft.isFilmPhoto == FieldSuggestions.filmPhotoNoCode)
            }

            if fieldVisibility.isAnyVisible(FieldVisibilityRegistry.groups[5].fields.map(\.label)) {
            FieldGroup(title: "Roll", onClear: clearRollFields) {
                if fieldVisibility.isVisible("Roll ID") {
                LabeledField("Roll ID", $library.batchDraft.roll.id, placeholder: commonValue(\.roll.id))
                }
                if fieldVisibility.isVisible("Frame Number") {
                LabeledField("Frame Number", $library.batchDraft.roll.frameNumber, placeholder: commonValue(\.roll.frameNumber))
                }
                if fieldVisibility.isVisible("Total Frame Count") {
                LabeledField("Total Frame Count", $library.batchDraft.roll.frameCount, placeholder: commonValue(\.roll.frameCount))
                }
                if fieldVisibility.isVisible("Exposure ISO") {
                LabeledComboField("Exposure ISO", $library.batchDraft.roll.exposureISO, options: FieldSuggestions.isoValues, validatesNumber: true, placeholder: commonValue(\.roll.exposureISO))
                }
                if fieldVisibility.isVisible("Loaded Date") {
                LabeledDateField("Loaded Date", $library.batchDraft.roll.loadedDate)
                }
                if fieldVisibility.isVisible("Finished Date") {
                LabeledDateField("Finished Date", $library.batchDraft.roll.finishedDate)
                }
                if fieldVisibility.isVisible("Development Batch") {
                LabeledField("Development Batch", $library.batchDraft.roll.developmentBatch, placeholder: commonValue(\.roll.developmentBatch))
                }
            }
            .id("section-roll")
            .disabled(library.batchDraft.isFilmPhoto == FieldSuggestions.filmPhotoNoCode)
            }

            if fieldVisibility.isAnyVisible(FieldVisibilityRegistry.groups[6].fields.map(\.label)) {
            FieldGroup(title: "Development", onClear: clearDevelopmentFields) {
                if fieldVisibility.isVisible("Process") {
                SuggestibleField("Process", processBinding, keyPath: \.development.process, placeholder: FieldSuggestions.processDisplayValue(commonValue(\.development.process)))
                }
                if fieldVisibility.isVisible("Developer") {
                LabeledField("Developer", $library.batchDraft.development.developer, placeholder: commonValue(\.development.developer))
                }
                if fieldVisibility.isVisible("Developer Manufacturer") {
                SuggestibleField("Developer Manufacturer", $library.batchDraft.development.developerMaker, keyPath: \.development.developerMaker, placeholder: commonValue(\.development.developerMaker))
                }
                if fieldVisibility.isVisible("Developer Dilution") {
                LabeledField("Developer Dilution", $library.batchDraft.development.developerDilution, placeholder: commonValue(\.development.developerDilution))
                }
                if fieldVisibility.isVisible("Development Time") {
                LabeledDateField("Development Time", $library.batchDraft.development.developedAt)
                }
                if fieldVisibility.isVisible("Development Duration") {
                LabeledField("Development Duration", $library.batchDraft.development.duration, placeholder: commonValue(\.development.duration))
                }
                if fieldVisibility.isVisible("Development Temperature") {
                LabeledField("Development Temperature", developmentTemperatureBinding, placeholder: commonValue(\.development.temperature))
                }
                if fieldVisibility.isVisible("Push/Pull") {
                LabeledComboField("Push/Pull", pushPullBinding, options: pushPullSuggestions, centerValue: FieldSuggestions.pushPullStandardLabel, placeholder: FieldSuggestions.pushPullDisplayValue(commonValue(\.development.pushPull)))
                }
                if fieldVisibility.isVisible("Bleach") {
                LabeledField("Bleach", $library.batchDraft.development.bleach, placeholder: commonValue(\.development.bleach))
                }
                if fieldVisibility.isVisible("Fixer") {
                LabeledField("Fixer", $library.batchDraft.development.fixer, placeholder: commonValue(\.development.fixer))
                }
                if fieldVisibility.isVisible("Stabilizer") {
                LabeledField("Stabilizer", $library.batchDraft.development.stabilizer, placeholder: commonValue(\.development.stabilizer))
                }
                if fieldVisibility.isVisible("Replenishment") {
                LabeledField("Replenishment", $library.batchDraft.development.replenishment, placeholder: commonValue(\.development.replenishment))
                }
                if fieldVisibility.isVisible("Chemistry Notes") {
                LabeledField("Chemistry Notes", $library.batchDraft.development.chemistryNotes, placeholder: commonValue(\.development.chemistryNotes))
                }
            }
            .id("section-development")
            .disabled(library.batchDraft.isFilmPhoto == FieldSuggestions.filmPhotoNoCode)
            }

            if fieldVisibility.isAnyVisible(FieldVisibilityRegistry.groups[7].fields.map(\.label)) {
            FieldGroup(title: "Lab", onClear: clearLabFields) {
                if fieldVisibility.isVisible("Lab Name") {
                LabeledField("Lab Name", $library.batchDraft.lab.name, placeholder: commonValue(\.lab.name))
                }
                if fieldVisibility.isVisible("Lab Address") {
                LabeledField("Lab Address", $library.batchDraft.lab.address, placeholder: commonValue(\.lab.address))
                }
                if fieldVisibility.isVisible("Lab Contact") {
                LabeledField("Lab Contact", $library.batchDraft.lab.contact, placeholder: commonValue(\.lab.contact))
                }
                if fieldVisibility.isVisible("Lab Notes") {
                LabeledField("Lab Notes", $library.batchDraft.lab.labNotes, placeholder: commonValue(\.lab.labNotes))
                }
            }
            .id("section-lab")
            .disabled(library.batchDraft.isFilmPhoto == FieldSuggestions.filmPhotoNoCode)
            }

            if fieldVisibility.isAnyVisible(FieldVisibilityRegistry.groups[8].fields.map(\.label)) {
            FieldGroup(title: "Scanning", onClear: clearScanningFields) {
                if fieldVisibility.isVisible("Scanner Make") {
                SuggestibleField("Scanner Make", $library.batchDraft.scanning.scannerMaker, keyPath: \.scanning.scannerMaker, placeholder: commonValue(\.scanning.scannerMaker))
                }
                if fieldVisibility.isVisible("Scanner Model") {
                LabeledField("Scanner Model", $library.batchDraft.scanning.scannerModel, placeholder: commonValue(\.scanning.scannerModel))
                }
                if fieldVisibility.isVisible("Scanner Serial Number") {
                LabeledField("Scanner Serial Number", $library.batchDraft.scanning.scannerSerialNumber, placeholder: commonValue(\.scanning.scannerSerialNumber))
                }
                if fieldVisibility.isVisible("Scanner Software") {
                LabeledField("Scanner Software", $library.batchDraft.scanning.scannerSoftware, placeholder: commonValue(\.scanning.scannerSoftware))
                }
                if fieldVisibility.isVisible("Scan Resolution") {
                SuggestibleField("Scan Resolution", $library.batchDraft.scanning.resolution, keyPath: \.scanning.resolution, placeholder: commonValue(\.scanning.resolution))
                }
                if fieldVisibility.isVisible("Bit Depth") {
                SuggestibleField("Bit Depth", $library.batchDraft.scanning.bitDepth, keyPath: \.scanning.bitDepth, placeholder: commonValue(\.scanning.bitDepth))
                }
                if fieldVisibility.isVisible("Color Space") {
                SuggestibleField("Color Space", $library.batchDraft.scanning.colorSpace, keyPath: \.scanning.colorSpace, placeholder: commonValue(\.scanning.colorSpace))
                }
                if fieldVisibility.isVisible("Scan Type") {
                SuggestibleField("Scan Type", $library.batchDraft.scanning.scanType, keyPath: \.scanning.scanType, placeholder: commonValue(\.scanning.scanType))
                }
                if fieldVisibility.isVisible("Scan Date") {
                LabeledDateField("Scan Date", $library.batchDraft.scanning.scanDate)
                }
                if fieldVisibility.isVisible("Dust Removal") {
                LabeledToggle("Dust Removal", isOn: $library.batchDraft.scanning.dustRemoval)
                }
                if fieldVisibility.isVisible("Infrared Cleaning") {
                LabeledToggle("Infrared Cleaning", isOn: $library.batchDraft.scanning.infraredCleaning)
                }
                if fieldVisibility.isVisible("Scan Notes") {
                LabeledField("Scan Notes", $library.batchDraft.scanning.scanNotes, placeholder: commonValue(\.scanning.scanNotes))
                }
            }
            .id("section-scanning")
            .disabled(library.batchDraft.fileSource == FieldSuggestions.digitalStillCameraCode)
            }

            if fieldVisibility.isVisible("Notes") {
            FieldGroup(title: "Notes", onClear: clearNotesField) {
                TextEditor(text: $library.batchDraft.notes)
                    .frame(minHeight: 80)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
            }
            .id("section-notes")
            }
        }
    }
}
