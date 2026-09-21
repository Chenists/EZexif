import SwiftUI
import MapKit

/// Editor for a single selected photo.
struct MetadataEditorView: View {
    @ObservedObject var item: PhotoItem
    @EnvironmentObject var library: PhotoLibrary
    @EnvironmentObject var fieldVisibility: FieldVisibilityStore
    @State private var showingMapPicker = false
    @State private var showingRawExif = false
    @AppStorage(AppSettingsKeys.temperatureUnit) private var temperatureUnitRaw = TemperatureUnit.celsius.rawValue
    @AppStorage(AppSettingsKeys.apertureDisplayFormat) private var apertureDisplayFormatRaw = ApertureDisplayFormat.number.rawValue

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // A zero-height marker for the very top of the
                        // content, padding included — scrolling to
                        // "section-exposure" directly (as the preset-apply/
                        // undo scrolls still do) aligns "Basics"' own top
                        // edge with the viewport's top, which crops off the
                        // padding above it. This one sits above that padding.
                        Color.clear.frame(height: 0).id("scroll-top")
                        if fieldVisibility.isAnyVisible(FieldVisibilityRegistry.groups[0].fields.map(\.label)) {
                        FieldGroup(title: "Basics", onClear: clearBasicsFields) {
                            if fieldVisibility.isVisible("ISO") {
                            LabeledComboField("ISO", $item.edited.shotISO, options: FieldSuggestions.isoValues, validatesNumber: true, isChanged: item.edited.shotISO != item.original.shotISO)
                            }
                            if fieldVisibility.isVisible("Aperture") {
                            LabeledComboField("Aperture", apertureBinding, options: apertureSuggestions, validatesNumber: apertureDisplayFormat == .number, isChanged: item.edited.aperture != item.original.aperture)
                            }
                            if fieldVisibility.isVisible("Shutter Speed") {
                            LabeledComboField("Shutter Speed", $item.edited.shutterSpeed, options: FieldSuggestions.shutterSpeedValues, unit: "s", validatesNumber: true, allowsFraction: true, isChanged: item.edited.shutterSpeed != item.original.shutterSpeed)
                            }
                            if fieldVisibility.isVisible("Exposure Bias") {
                            LabeledComboField("Exposure Bias", $item.edited.exposureBias, options: FieldSuggestions.exposureBiasValues, unit: "ev", validatesNumber: true, allowsNegative: true, centerValue: "0 ev", isChanged: item.edited.exposureBias != item.original.exposureBias)
                            }
                            if fieldVisibility.isVisible("Focal Length") {
                            LabeledComboField("Focal Length", $item.edited.focalLength, options: FieldSuggestions.focalLengthValues, unit: "mm", validatesNumber: true, isChanged: item.edited.focalLength != item.original.focalLength)
                            }
                            if fieldVisibility.isVisible("35mm Equivalent Focal Length") {
                            LabeledComboField("35mm Equivalent Focal Length", $item.edited.focalLengthIn35mmFormat, options: FieldSuggestions.focalLengthValues, unit: "mm", validatesNumber: true, isChanged: item.edited.focalLengthIn35mmFormat != item.original.focalLengthIn35mmFormat)
                            }
                            if fieldVisibility.isVisible("Exposure Program") {
                            LabeledComboField("Exposure Program", exposureProgramBinding, options: FieldSuggestions.exposureProgramLabels, isChanged: item.edited.exposureProgram != item.original.exposureProgram)
                            }
                            if fieldVisibility.isVisible("White Balance") {
                            LabeledComboField("White Balance", whiteBalanceBinding, options: FieldSuggestions.whiteBalanceLabels, isChanged: item.edited.whiteBalance != item.original.whiteBalance)
                            }
                            if fieldVisibility.isVisible("Metering Mode") {
                            LabeledComboField("Metering Mode", meteringModeBinding, options: FieldSuggestions.meteringModeLabels, isChanged: item.edited.meteringMode != item.original.meteringMode)
                            }
                            if fieldVisibility.isVisible("Capture Time") {
                            LabeledDateField("Capture Time", $item.edited.dateTimeOriginal, isChanged: item.edited.dateTimeOriginal != item.original.dateTimeOriginal)
                            }
                            if fieldVisibility.isVisible("Location") {
                            LabeledCoordinateField("Location", latitude: $item.edited.latitude, longitude: $item.edited.longitude, isChanged: item.edited.latitude != item.original.latitude || item.edited.longitude != item.original.longitude) {
                                Button {
                                    item.edited.latitude = nil
                                    item.edited.longitude = nil
                                    item.edited.altitude = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .disabled(item.edited.latitude == nil && item.edited.longitude == nil && item.edited.altitude == nil)
                                .help("Clear Location")
                                Button {
                                    showingMapPicker = true
                                } label: {
                                    Image(systemName: "map")
                                }
                                .buttonStyle(.plain)
                                .help("Map")
                            }
                            if let lat = item.edited.latitude, let lon = item.edited.longitude {
                                // `Map(initialPosition:)` only seeds the
                                // camera the first time this specific `Map`
                                // view is created — it does NOT recenter on
                                // later renders just because `lat`/`lon`
                                // changed, so switching to a different photo
                                // left it showing the previous one's
                                // location. Keying `.id()` on the coordinate
                                // alone isn't enough, though: two different
                                // photos can share the exact same coordinate
                                // (e.g. copies of the same file), which gives
                                // them the same id — SwiftUI then reuses the
                                // same `Map` instance, including wherever the
                                // user last panned it, instead of resetting.
                                // Including `item.id` guarantees a fresh `Map`
                                // for every photo, coordinates aside.
                                LocationPreviewMap(latitude: lat, longitude: lon)
                                    .id("\(item.id)-\(lat),\(lon)")
                            }
                            }
                            if fieldVisibility.isVisible("Altitude") {
                            LabeledField("Altitude", $item.edited.altitude.asOptionalText, isChanged: item.edited.altitude != item.original.altitude)
                            }
                            if fieldVisibility.isVisible("Rating") {
                            HStack {
                                FieldLabel(text: "Rating", isChanged: item.edited.rating != item.original.rating)
                                StarRatingView(rating: $item.edited.rating)
                                Spacer()
                            }
                            }
                        }
                        .id("section-exposure")
                        }

                        if fieldVisibility.isAnyVisible(FieldVisibilityRegistry.groups[1].fields.map(\.label)) {
                        FieldGroup(title: "File", onClear: clearFileFields) {
                            if fieldVisibility.isVisible("File Source") {
                            LabeledComboField("File Source", fileSourceBinding, options: FieldSuggestions.fileSourceLabels, isChanged: item.edited.fileSource != item.original.fileSource)
                            }
                            if fieldVisibility.isVisible("Is Film Photo") {
                            LabeledComboField("Is Film Photo", isFilmPhotoBinding, options: FieldSuggestions.filmPhotoLabels, isChanged: item.edited.isFilmPhoto != item.original.isFilmPhoto)
                            }
                        }
                        .id("section-file")
                        }

                        if fieldVisibility.isAnyVisible(FieldVisibilityRegistry.groups[2].fields.map(\.label)) {
                        FieldGroup(title: "Photographer & Copyright", onClear: clearPhotographerFields) {
                            if fieldVisibility.isVisible("Photographer") {
                            LabeledField("Photographer", $item.edited.artist, isChanged: item.edited.artist != item.original.artist)
                            }
                            if fieldVisibility.isVisible("Copyright") {
                            LabeledField("Copyright", $item.edited.copyright, isChanged: item.edited.copyright != item.original.copyright) {
                                Button {
                                    item.edited.copyright = Self.generatedCopyright(
                                        year: item.edited.dateTimeOriginal,
                                        photographer: item.edited.artist
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
                            SuggestibleField("Camera Make", $item.edited.cameraMake, keyPath: \.cameraMake, isChanged: item.edited.cameraMake != item.original.cameraMake)
                            }
                            if fieldVisibility.isVisible("Camera Model") {
                            LabeledField("Camera Model", $item.edited.cameraModel, isChanged: item.edited.cameraModel != item.original.cameraModel)
                            }
                            if fieldVisibility.isVisible("Camera Serial Number") {
                            LabeledField("Camera Serial Number", $item.edited.cameraSerialNumber, isChanged: item.edited.cameraSerialNumber != item.original.cameraSerialNumber)
                            }
                            if fieldVisibility.isVisible("Camera Firmware") {
                            LabeledField("Camera Firmware", $item.edited.cameraFirmware, isChanged: item.edited.cameraFirmware != item.original.cameraFirmware)
                            }
                            if fieldVisibility.isVisible("Camera Owner Name") {
                            LabeledField("Camera Owner Name", $item.edited.cameraOwnerName, isChanged: item.edited.cameraOwnerName != item.original.cameraOwnerName)
                            }
                            if fieldVisibility.isVisible("Lens Make") {
                            SuggestibleField("Lens Make", $item.edited.lensMake, keyPath: \.lensMake, isChanged: item.edited.lensMake != item.original.lensMake)
                            }
                            if fieldVisibility.isVisible("Lens Model") {
                            LabeledField("Lens Model", $item.edited.lensModel, isChanged: item.edited.lensModel != item.original.lensModel)
                            }
                            if fieldVisibility.isVisible("Lens Serial Number") {
                            LabeledField("Lens Serial Number", $item.edited.lensSerialNumber, isChanged: item.edited.lensSerialNumber != item.original.lensSerialNumber)
                            }
                            if fieldVisibility.isVisible("Lens Specification") {
                            LabeledField("Lens Specification", $item.edited.lensSpecification, isChanged: item.edited.lensSpecification != item.original.lensSpecification)
                            }
                        }
                        .id("section-camera")
                        }

                        if fieldVisibility.isAnyVisible(FieldVisibilityRegistry.groups[4].fields.map(\.label)) {
                        FieldGroup(title: "Film", onClear: clearFilmFields) {
                            if fieldVisibility.isVisible("Manufacturer") {
                            SuggestibleField("Manufacturer", filmMakerBinding, keyPath: \.film.maker, isChanged: item.edited.film.maker != item.original.film.maker)
                            }
                            if fieldVisibility.isVisible("Name") {
                            DynamicSuggestibleField("Name", filmNameBinding, suggestions: FilmStockDatabase.names(forMaker: item.edited.film.maker), isChanged: item.edited.film.name != item.original.film.name)
                            }
                            if fieldVisibility.isVisible("Film Type") {
                            SuggestibleField("Film Type", filmTypeBinding, keyPath: \.film.type, isChanged: item.edited.film.type != item.original.film.type)
                            }
                            if fieldVisibility.isVisible("Format") {
                            SuggestibleField("Format", $item.edited.film.format, keyPath: \.film.format, isChanged: item.edited.film.format != item.original.film.format)
                            }
                            if fieldVisibility.isVisible("Film ISO") {
                            SuggestibleField("Film ISO", $item.edited.film.iso, keyPath: \.film.iso, isChanged: item.edited.film.iso != item.original.film.iso)
                            }
                            if fieldVisibility.isVisible("DX Code") {
                            LabeledField("DX Code", $item.edited.film.dxCode, isChanged: item.edited.film.dxCode != item.original.film.dxCode)
                            }
                            if fieldVisibility.isVisible("Film Batch") {
                            LabeledField("Film Batch", $item.edited.film.batch, isChanged: item.edited.film.batch != item.original.film.batch)
                            }
                            if fieldVisibility.isVisible("Emulsion Number") {
                            LabeledField("Emulsion Number", $item.edited.film.emulsionNumber, isChanged: item.edited.film.emulsionNumber != item.original.film.emulsionNumber)
                            }
                            if fieldVisibility.isVisible("Base") {
                            LabeledField("Base", $item.edited.film.base, isChanged: item.edited.film.base != item.original.film.base)
                            }
                            if fieldVisibility.isVisible("Film Grain") {
                            LabeledField("Film Grain", $item.edited.film.grain, isChanged: item.edited.film.grain != item.original.film.grain)
                            }
                        }
                        .id("section-film")
                        .disabled(item.edited.isFilmPhoto == FieldSuggestions.filmPhotoNoCode)
                        }

                        if fieldVisibility.isAnyVisible(FieldVisibilityRegistry.groups[5].fields.map(\.label)) {
                        FieldGroup(title: "Roll", onClear: clearRollFields) {
                            if fieldVisibility.isVisible("Roll ID") {
                            LabeledField("Roll ID", $item.edited.roll.id, isChanged: item.edited.roll.id != item.original.roll.id)
                            }
                            if fieldVisibility.isVisible("Frame Number") {
                            LabeledField("Frame Number", $item.edited.roll.frameNumber, isChanged: item.edited.roll.frameNumber != item.original.roll.frameNumber)
                            }
                            if fieldVisibility.isVisible("Total Frame Count") {
                            LabeledField("Total Frame Count", $item.edited.roll.frameCount, isChanged: item.edited.roll.frameCount != item.original.roll.frameCount)
                            }
                            if fieldVisibility.isVisible("Exposure ISO") {
                            LabeledComboField("Exposure ISO", $item.edited.roll.exposureISO, options: FieldSuggestions.isoValues, validatesNumber: true, isChanged: item.edited.roll.exposureISO != item.original.roll.exposureISO)
                            }
                            if fieldVisibility.isVisible("Loaded Date") {
                            LabeledDateField("Loaded Date", $item.edited.roll.loadedDate, isChanged: item.edited.roll.loadedDate != item.original.roll.loadedDate)
                            }
                            if fieldVisibility.isVisible("Finished Date") {
                            LabeledDateField("Finished Date", $item.edited.roll.finishedDate, isChanged: item.edited.roll.finishedDate != item.original.roll.finishedDate)
                            }
                            if fieldVisibility.isVisible("Development Batch") {
                            LabeledField("Development Batch", $item.edited.roll.developmentBatch, isChanged: item.edited.roll.developmentBatch != item.original.roll.developmentBatch)
                            }
                        }
                        .id("section-roll")
                        .disabled(item.edited.isFilmPhoto == FieldSuggestions.filmPhotoNoCode)
                        }

                        if fieldVisibility.isAnyVisible(FieldVisibilityRegistry.groups[6].fields.map(\.label)) {
                        FieldGroup(title: "Development", onClear: clearDevelopmentFields) {
                            if fieldVisibility.isVisible("Process") {
                            SuggestibleField("Process", processBinding, keyPath: \.development.process, isChanged: item.edited.development.process != item.original.development.process)
                            }
                            if fieldVisibility.isVisible("Developer") {
                            LabeledField("Developer", $item.edited.development.developer, isChanged: item.edited.development.developer != item.original.development.developer)
                            }
                            if fieldVisibility.isVisible("Developer Manufacturer") {
                            SuggestibleField("Developer Manufacturer", $item.edited.development.developerMaker, keyPath: \.development.developerMaker, isChanged: item.edited.development.developerMaker != item.original.development.developerMaker)
                            }
                            if fieldVisibility.isVisible("Developer Dilution") {
                            LabeledField("Developer Dilution", $item.edited.development.developerDilution, isChanged: item.edited.development.developerDilution != item.original.development.developerDilution)
                            }
                            if fieldVisibility.isVisible("Development Time") {
                            LabeledDateField("Development Time", $item.edited.development.developedAt, isChanged: item.edited.development.developedAt != item.original.development.developedAt)
                            }
                            if fieldVisibility.isVisible("Development Duration") {
                            LabeledField("Development Duration", $item.edited.development.duration, isChanged: item.edited.development.duration != item.original.development.duration)
                            }
                            if fieldVisibility.isVisible("Development Temperature") {
                            LabeledField("Development Temperature", developmentTemperatureBinding, isChanged: item.edited.development.temperature != item.original.development.temperature)
                            }
                            if fieldVisibility.isVisible("Push/Pull") {
                            LabeledComboField("Push/Pull", pushPullBinding, options: pushPullSuggestions, centerValue: FieldSuggestions.pushPullStandardLabel, isChanged: item.edited.development.pushPull != item.original.development.pushPull)
                            }
                            if fieldVisibility.isVisible("Bleach") {
                            LabeledField("Bleach", $item.edited.development.bleach, isChanged: item.edited.development.bleach != item.original.development.bleach)
                            }
                            if fieldVisibility.isVisible("Fixer") {
                            LabeledField("Fixer", $item.edited.development.fixer, isChanged: item.edited.development.fixer != item.original.development.fixer)
                            }
                            if fieldVisibility.isVisible("Stabilizer") {
                            LabeledField("Stabilizer", $item.edited.development.stabilizer, isChanged: item.edited.development.stabilizer != item.original.development.stabilizer)
                            }
                            if fieldVisibility.isVisible("Replenishment") {
                            LabeledField("Replenishment", $item.edited.development.replenishment, isChanged: item.edited.development.replenishment != item.original.development.replenishment)
                            }
                            if fieldVisibility.isVisible("Chemistry Notes") {
                            LabeledField("Chemistry Notes", $item.edited.development.chemistryNotes, isChanged: item.edited.development.chemistryNotes != item.original.development.chemistryNotes)
                            }
                        }
                        .id("section-development")
                        .disabled(item.edited.isFilmPhoto == FieldSuggestions.filmPhotoNoCode)
                        }

                        if fieldVisibility.isAnyVisible(FieldVisibilityRegistry.groups[7].fields.map(\.label)) {
                        FieldGroup(title: "Lab", onClear: clearLabFields) {
                            if fieldVisibility.isVisible("Lab Name") {
                            LabeledField("Lab Name", $item.edited.lab.name, isChanged: item.edited.lab.name != item.original.lab.name)
                            }
                            if fieldVisibility.isVisible("Lab Address") {
                            LabeledField("Lab Address", $item.edited.lab.address, isChanged: item.edited.lab.address != item.original.lab.address)
                            }
                            if fieldVisibility.isVisible("Lab Contact") {
                            LabeledField("Lab Contact", $item.edited.lab.contact, isChanged: item.edited.lab.contact != item.original.lab.contact)
                            }
                            if fieldVisibility.isVisible("Lab Notes") {
                            LabeledField("Lab Notes", $item.edited.lab.labNotes, isChanged: item.edited.lab.labNotes != item.original.lab.labNotes)
                            }
                        }
                        .id("section-lab")
                        .disabled(item.edited.isFilmPhoto == FieldSuggestions.filmPhotoNoCode)
                        }

                        if fieldVisibility.isAnyVisible(FieldVisibilityRegistry.groups[8].fields.map(\.label)) {
                        FieldGroup(title: "Scanning", onClear: clearScanningFields) {
                            if fieldVisibility.isVisible("Scanner Make") {
                            SuggestibleField("Scanner Make", $item.edited.scanning.scannerMaker, keyPath: \.scanning.scannerMaker, isChanged: item.edited.scanning.scannerMaker != item.original.scanning.scannerMaker)
                            }
                            if fieldVisibility.isVisible("Scanner Model") {
                            LabeledField("Scanner Model", $item.edited.scanning.scannerModel, isChanged: item.edited.scanning.scannerModel != item.original.scanning.scannerModel)
                            }
                            if fieldVisibility.isVisible("Scanner Serial Number") {
                            LabeledField("Scanner Serial Number", $item.edited.scanning.scannerSerialNumber, isChanged: item.edited.scanning.scannerSerialNumber != item.original.scanning.scannerSerialNumber)
                            }
                            if fieldVisibility.isVisible("Scanner Software") {
                            LabeledField("Scanner Software", $item.edited.scanning.scannerSoftware, isChanged: item.edited.scanning.scannerSoftware != item.original.scanning.scannerSoftware)
                            }
                            if fieldVisibility.isVisible("Scan Resolution") {
                            SuggestibleField("Scan Resolution", $item.edited.scanning.resolution, keyPath: \.scanning.resolution, isChanged: item.edited.scanning.resolution != item.original.scanning.resolution)
                            }
                            if fieldVisibility.isVisible("Bit Depth") {
                            SuggestibleField("Bit Depth", $item.edited.scanning.bitDepth, keyPath: \.scanning.bitDepth, isChanged: item.edited.scanning.bitDepth != item.original.scanning.bitDepth)
                            }
                            if fieldVisibility.isVisible("Color Space") {
                            SuggestibleField("Color Space", $item.edited.scanning.colorSpace, keyPath: \.scanning.colorSpace, isChanged: item.edited.scanning.colorSpace != item.original.scanning.colorSpace)
                            }
                            if fieldVisibility.isVisible("Scan Type") {
                            SuggestibleField("Scan Type", $item.edited.scanning.scanType, keyPath: \.scanning.scanType, isChanged: item.edited.scanning.scanType != item.original.scanning.scanType)
                            }
                            if fieldVisibility.isVisible("Scan Date") {
                            LabeledDateField("Scan Date", $item.edited.scanning.scanDate, isChanged: item.edited.scanning.scanDate != item.original.scanning.scanDate)
                            }
                            if fieldVisibility.isVisible("Dust Removal") {
                            LabeledToggle("Dust Removal", isOn: $item.edited.scanning.dustRemoval, isChanged: item.edited.scanning.dustRemoval != item.original.scanning.dustRemoval)
                            }
                            if fieldVisibility.isVisible("Infrared Cleaning") {
                            LabeledToggle("Infrared Cleaning", isOn: $item.edited.scanning.infraredCleaning, isChanged: item.edited.scanning.infraredCleaning != item.original.scanning.infraredCleaning)
                            }
                            if fieldVisibility.isVisible("Scan Notes") {
                            LabeledField("Scan Notes", $item.edited.scanning.scanNotes, isChanged: item.edited.scanning.scanNotes != item.original.scanning.scanNotes)
                            }
                        }
                        // A "Digital Still Camera" file source means nothing
                        // ran the image through a scanner at all.
                        .disabled(item.edited.fileSource == FieldSuggestions.digitalStillCameraCode)
                        .id("section-scanning")
                        }

                        if fieldVisibility.isVisible("Notes") {
                        FieldGroup(title: "Notes", onClear: { item.edited.notes = "" }) {
                            HStack(spacing: 4) {
                                Text("Notes")
                                if item.edited.notes != item.original.notes {
                                    Circle()
                                        .fill(Color.orange)
                                        .frame(width: 6, height: 6)
                                }
                            }
                            .foregroundStyle(.secondary)
                            TextEditor(text: $item.edited.notes)
                                .frame(minHeight: 80)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
                        }
                        .id("section-notes")
                        }

                        if let error = item.lastError {
                            Text(error)
                                .foregroundStyle(.red)
                                .font(.callout)
                        }
                    }
                    .padding(24)
                }
                // Scrolls the section a just-applied preset touched into
                // view, centered — `anchor: .center` already clamps
                // naturally at the top/bottom of the content instead of
                // overshooting past either edge.
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
                // Switching to a different photo shows it from the top,
                // instead of leaving the scroll position wherever it
                // happened to be for the previously selected photo (e.g.
                // still scrolled down to "Notes"). No `withAnimation` here
                // — unlike the preset/undo scrolls, which draw attention to
                // where something just changed, this is just showing new
                // content, so it snaps into place instantly.
                .onChange(of: item.id) { _, _ in
                    proxy.scrollTo("scroll-top", anchor: .top)
                }
                // Covers the case `.onChange(of: item.id)` can't: the very
                // first photo shown after an import into an empty library.
                // That transition mounts this view fresh (going from the
                // empty-state placeholder to this editor for the first
                // time), and `.onChange` only fires on a value changing
                // *after* a view already exists — it never fires for the
                // value a freshly-appeared view starts with.
                .onAppear {
                    proxy.scrollTo("scroll-top", anchor: .top)
                }
            }
            Divider()
            footer
        }
        .sheet(isPresented: $showingMapPicker) {
            // `.id(item.id)` forces a genuinely fresh `MapLocationPickerView`
            // (and its `@State region`/`pinCoordinate`, which only ever
            // compute from the photo's coordinates in `init`) whenever the
            // picker is opened for a different photo — `.sheet(isPresented:)`
            // alone doesn't guarantee the previous presentation's view (and
            // its `@State`) gets torn down rather than reused, which is why
            // the map could open still centered on the last photo it was
            // shown for instead of the one just selected.
            MapLocationPickerView(latitude: $item.edited.latitude, longitude: $item.edited.longitude)
                .id(item.id)
        }
        .sheet(isPresented: $showingRawExif) {
            RawExifView(item: item)
        }
    }

    /// A different Manufacturer invalidates whatever Name/Film Type/Film
    /// ISO/Process were showing for the old one, so they're cleared rather
    /// than left stale — picking a new Name (below) re-fills Type/ISO/
    /// Process for the new maker.
    ///
    /// This — and `applyFilmStockAutoFill` below — used to be triggered by
    /// `.onChange(of: item.edited.film.maker)`, which reacts to the *value*
    /// changing no matter what caused it: applying a Film preset (which sets
    /// Manufacturer and Name in the same instant) fired this and immediately
    /// erased the very Name/Type/ISO/Process the preset had just set, and
    /// switching between photos fired it too, since a different photo's
    /// Manufacturer is a "different value" even though nobody edited
    /// anything. Wiring it into these two fields' own bindings instead
    /// means it only ever runs when the Manufacturer/Name combo boxes
    /// themselves are what changed the value.
    /// Setting File Source to "Digital Still Camera" disables the Scanning
    /// section (see its `.disabled(...)` below); this also snaps any
    /// pending, unsaved edits to those fields back to what's already on
    /// disk (`item.original`, not a blank slate), so a Scanner value typed
    /// before switching File Source can't later get saved from behind a
    /// greyed-out field the user can no longer see or touch.
    // MARK: - Per-section "Clear Section" buttons
    //
    // Each of these only touches fields that are currently visible (per
    // `fieldVisibility`) — a field hidden via Settings → Fields keeps
    // whatever value it already had, since the user can't even see it here
    // to know it changed. Each builds one `updated` copy and assigns
    // `item.edited` once, so clearing a whole section is one undo step
    // (matching the `fileSourceBinding`/`isFilmPhotoBinding` convention),
    // not one step per field.

    private func clearBasicsFields() {
        var updated = item.edited
        if fieldVisibility.isVisible("ISO") { updated.shotISO = "" }
        if fieldVisibility.isVisible("Aperture") { updated.aperture = "" }
        if fieldVisibility.isVisible("Shutter Speed") { updated.shutterSpeed = "" }
        if fieldVisibility.isVisible("Exposure Bias") { updated.exposureBias = "" }
        if fieldVisibility.isVisible("Focal Length") { updated.focalLength = "" }
        if fieldVisibility.isVisible("35mm Equivalent Focal Length") { updated.focalLengthIn35mmFormat = "" }
        if fieldVisibility.isVisible("Exposure Program") { updated.exposureProgram = "" }
        if fieldVisibility.isVisible("White Balance") { updated.whiteBalance = "" }
        if fieldVisibility.isVisible("Metering Mode") { updated.meteringMode = "" }
        if fieldVisibility.isVisible("Capture Time") { updated.dateTimeOriginal = nil }
        if fieldVisibility.isVisible("Location") {
            updated.latitude = nil
            updated.longitude = nil
        }
        if fieldVisibility.isVisible("Altitude") { updated.altitude = nil }
        if fieldVisibility.isVisible("Rating") { updated.rating = 0 }
        item.edited = updated
    }

    private func clearFileFields() {
        var updated = item.edited
        if fieldVisibility.isVisible("File Source") { updated.fileSource = "" }
        if fieldVisibility.isVisible("Is Film Photo") { updated.isFilmPhoto = "" }
        item.edited = updated
    }

    private func clearPhotographerFields() {
        var updated = item.edited
        if fieldVisibility.isVisible("Photographer") { updated.artist = "" }
        if fieldVisibility.isVisible("Copyright") { updated.copyright = "" }
        item.edited = updated
    }

    private func clearCameraLensFields() {
        var updated = item.edited
        if fieldVisibility.isVisible("Camera Make") { updated.cameraMake = "" }
        if fieldVisibility.isVisible("Camera Model") { updated.cameraModel = "" }
        if fieldVisibility.isVisible("Camera Serial Number") { updated.cameraSerialNumber = "" }
        if fieldVisibility.isVisible("Camera Firmware") { updated.cameraFirmware = "" }
        if fieldVisibility.isVisible("Camera Owner Name") { updated.cameraOwnerName = "" }
        if fieldVisibility.isVisible("Lens Make") { updated.lensMake = "" }
        if fieldVisibility.isVisible("Lens Model") { updated.lensModel = "" }
        if fieldVisibility.isVisible("Lens Serial Number") { updated.lensSerialNumber = "" }
        if fieldVisibility.isVisible("Lens Specification") { updated.lensSpecification = "" }
        item.edited = updated
    }

    private func clearFilmFields() {
        var updated = item.edited
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
        item.edited = updated
    }

    private func clearRollFields() {
        var updated = item.edited
        if fieldVisibility.isVisible("Roll ID") { updated.roll.id = "" }
        if fieldVisibility.isVisible("Frame Number") { updated.roll.frameNumber = "" }
        if fieldVisibility.isVisible("Total Frame Count") { updated.roll.frameCount = "" }
        if fieldVisibility.isVisible("Exposure ISO") { updated.roll.exposureISO = "" }
        if fieldVisibility.isVisible("Loaded Date") { updated.roll.loadedDate = nil }
        if fieldVisibility.isVisible("Finished Date") { updated.roll.finishedDate = nil }
        if fieldVisibility.isVisible("Development Batch") { updated.roll.developmentBatch = "" }
        item.edited = updated
    }

    private func clearDevelopmentFields() {
        var updated = item.edited
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
        item.edited = updated
    }

    private func clearLabFields() {
        var updated = item.edited
        if fieldVisibility.isVisible("Lab Name") { updated.lab.name = "" }
        if fieldVisibility.isVisible("Lab Address") { updated.lab.address = "" }
        if fieldVisibility.isVisible("Lab Contact") { updated.lab.contact = "" }
        if fieldVisibility.isVisible("Lab Notes") { updated.lab.labNotes = "" }
        item.edited = updated
    }

    private func clearScanningFields() {
        var updated = item.edited
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
        item.edited = updated
    }

    /// Stores/compares `item.edited.fileSource` as a bare numeric code
    /// (see `FieldSuggestions.fileSourceDisplayValue`/`...RawValue`) — this
    /// binding is the one place that code converts to/from the localized
    /// text the combo box actually shows and edits.
    private var fileSourceBinding: Binding<String> {
        Binding(
            get: { FieldSuggestions.fileSourceDisplayValue(item.edited.fileSource) },
            set: { newDisplayValue in
                // One assignment to `item.edited`, not two — this is one
                // coherent user action (the same way applying a preset is),
                // so it should record as a single undo step, not "change
                // File Source" and "reset Scanning" as separate ones.
                var updated = item.edited
                let newRawValue = FieldSuggestions.fileSourceRawValue(newDisplayValue)
                updated.fileSource = newRawValue
                if newRawValue == FieldSuggestions.digitalStillCameraCode {
                    updated.scanning = item.original.scanning
                }
                item.edited = updated
            }
        )
    }

    /// Same idea as `fileSourceBinding`, for the four sections "Is Film
    /// Photo" = "No" disables.
    private var isFilmPhotoBinding: Binding<String> {
        Binding(
            get: { FieldSuggestions.filmPhotoDisplayValue(item.edited.isFilmPhoto) },
            set: { newDisplayValue in
                var updated = item.edited
                let newRawValue = FieldSuggestions.filmPhotoRawValue(newDisplayValue)
                updated.isFilmPhoto = newRawValue
                if newRawValue == FieldSuggestions.filmPhotoNoCode {
                    updated.film = item.original.film
                    updated.roll = item.original.roll
                    updated.development = item.original.development
                    updated.lab = item.original.lab
                }
                item.edited = updated
            }
        )
    }

    /// Stores/compares `item.edited.film.type` as a bare numeric code (see
    /// `FieldSuggestions.filmTypeDisplayValue`/`...RawValue`) — this binding
    /// is the one place that code converts to/from the localized text the
    /// combo box actually shows and edits.
    private var filmTypeBinding: Binding<String> {
        Binding(
            get: { FieldSuggestions.filmTypeDisplayValue(item.edited.film.type) },
            set: { newDisplayValue in item.edited.film.type = FieldSuggestions.filmTypeRawValue(newDisplayValue) }
        )
    }

    /// Unlike `filmTypeBinding`, `processRawValue` passes an unrecognized
    /// typed value straight through instead of discarding it — Process
    /// isn't a closed enum the way Film Type is, and the AnalogExif mirror
    /// needs whatever the user actually typed if it isn't one of the 4
    /// known processes (see `FieldSuggestions.processCanonicalValue`, used
    /// on the write side in `ExifXMPService`).
    private var processBinding: Binding<String> {
        Binding(
            get: { FieldSuggestions.processDisplayValue(item.edited.development.process) },
            set: { newDisplayValue in item.edited.development.process = FieldSuggestions.processRawValue(newDisplayValue) }
        )
    }

    private var exposureProgramBinding: Binding<String> {
        Binding(
            get: { FieldSuggestions.exposureProgramDisplayValue(item.edited.exposureProgram) },
            set: { newDisplayValue in item.edited.exposureProgram = FieldSuggestions.exposureProgramRawValue(newDisplayValue) }
        )
    }

    private var whiteBalanceBinding: Binding<String> {
        Binding(
            get: { FieldSuggestions.whiteBalanceDisplayValue(item.edited.whiteBalance) },
            set: { newDisplayValue in item.edited.whiteBalance = FieldSuggestions.whiteBalanceRawValue(newDisplayValue) }
        )
    }

    private var meteringModeBinding: Binding<String> {
        Binding(
            get: { FieldSuggestions.meteringModeDisplayValue(item.edited.meteringMode) },
            set: { newDisplayValue in item.edited.meteringMode = FieldSuggestions.meteringModeRawValue(newDisplayValue) }
        )
    }

    private var filmMakerBinding: Binding<String> {
        Binding(
            get: { item.edited.film.maker },
            set: { newValue in
                item.edited.film.maker = newValue
                item.edited.film.name = ""
                item.edited.film.type = ""
                item.edited.film.iso = ""
                item.edited.development.process = ""
            }
        )
    }

    /// Once Manufacturer and Name both match a stock in `FilmStockDatabase`,
    /// fills in Film Type, Film ISO, and Process from it — overwriting
    /// whatever was there, so switching from one named stock to another
    /// updates them to match instead of keeping the previous stock's values.
    private var filmNameBinding: Binding<String> {
        Binding(
            get: { item.edited.film.name },
            set: { newValue in
                item.edited.film.name = newValue
                guard let stock = FilmStockDatabase.stock(maker: item.edited.film.maker, name: newValue) else { return }
                item.edited.film.type = FieldSuggestions.filmTypeCode(forCanonicalName: stock.type)
                item.edited.film.iso = stock.iso
                item.edited.development.process = FieldSuggestions.processCode(forCanonicalName: stock.process)
            }
        )
    }

    /// Appends the Settings → Fields temperature unit to a bare number as
    /// it's typed (e.g. "20" → "20 °C"), the same "auto-append missing
    /// unit" convention `LabeledComboField` uses for Aperture/Focal Length/
    /// etc. — a plain `LabeledField` binding otherwise, since Development
    /// Temperature has no fixed suggestion list to justify a combo box.
    private var developmentTemperatureBinding: Binding<String> {
        Binding(
            get: { item.edited.development.temperature },
            set: { newValue in
                item.edited.development.temperature = Self.appendingTemperatureUnitIfNeeded(newValue, unitRaw: temperatureUnitRaw)
            }
        )
    }

    static func appendingTemperatureUnitIfNeeded(_ value: String, unitRaw: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, Double(trimmed) != nil else { return trimmed }
        let symbol = (TemperatureUnit(rawValue: unitRaw) ?? .celsius).symbol
        return "\(trimmed) \(symbol)"
    }

    private var apertureDisplayFormat: ApertureDisplayFormat {
        ApertureDisplayFormat(rawValue: apertureDisplayFormatRaw) ?? .number
    }

    /// The Settings → Fields "Aperture" display choice is purely
    /// presentational — `item.edited.aperture` always stays a bare number
    /// (what EXIF's FNumber tag needs, and what `hasInvalidNumericField`
    /// already validates), so this only formats it for "f/2.8" display and
    /// strips that notation back off before it's stored. `validatesNumber`
    /// is turned off at the call site while this format is active, since
    /// `LabeledComboField`'s own numeric check has no notion of a leading
    /// "f/" — the model-level check in `hasInvalidNumericField` still
    /// blocks Save on a genuinely invalid value either way, just without
    /// the live red-border feedback in this display mode.
    private var apertureBinding: Binding<String> {
        Binding(
            get: {
                let raw = item.edited.aperture
                guard apertureDisplayFormat == .fStop, !raw.isEmpty else { return raw }
                return raw.lowercased().hasPrefix("f/") ? raw : "f/\(raw)"
            },
            set: { newValue in
                item.edited.aperture = Self.strippingApertureNotation(newValue)
            }
        )
    }

    private var apertureSuggestions: [String] {
        guard apertureDisplayFormat == .fStop else { return FieldSuggestions.apertureValues }
        return FieldSuggestions.apertureValues.map { "f/\($0)" }
    }

    static func strippingApertureNotation(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard trimmed.lowercased().hasPrefix("f/") else { return trimmed }
        return String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
    }

    /// "Push/Pull" is stored as a bare number ("0", "+1", "-2", ...) — see
    /// `FieldSuggestions.pushPullValues` — so it round-trips with other
    /// tools (RetroExif's own files use "0", not a word); "Normal" is also
    /// accepted on the way in for files saved by FilmExif before this
    /// stored a bare number, but every write from here on only ever
    /// produces "0". `FieldSuggestions.pushPullDisplayValue`/`...RawValue`
    /// convert that code to/from "Standard" (localized) for display.
    private var pushPullBinding: Binding<String> {
        Binding(
            get: { FieldSuggestions.pushPullDisplayValue(item.edited.development.pushPull) },
            set: { newValue in item.edited.development.pushPull = FieldSuggestions.pushPullRawValue(newValue) }
        )
    }

    private var pushPullSuggestions: [String] {
        FieldSuggestions.pushPullValues.map(FieldSuggestions.pushPullDisplayValue)
    }

    /// Fixed at the bottom of the editor — doesn't scroll with the fields,
    /// same "pinned action bar" pattern used in `PresetForm`'s footer.
    private var footer: some View {
        HStack {
            Button("Raw EXIF") { showingRawExif = true }
            Spacer()
            Button("Undo") {
                if let changed = item.undo(), let sectionID = changed.lazy.compactMap(FilmMetadata.scrollSectionID(forFieldNamed:)).first {
                    library.lastUndoScroll = .init(sectionID: sectionID)
                }
            }
                .disabled(!item.canUndo)
                .keyboardShortcut("z", modifiers: .command)
            Button("Revert") { item.edited = item.original }
                .disabled(!item.isDirty)
            Button {
                library.save(item)
            } label: {
                if item.isSaving {
                    ProgressView().controlSize(.small)
                } else {
                    Text("Save")
                }
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(!item.isDirty || item.isSaving || item.edited.hasInvalidNumericField)
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
    }

    /// "© {year of the photo's Capture Time, or this year if unset} {the
    /// Photographer field}" — used by the "Generate Copyright" button next
    /// to the Copyright field, in both this editor and the batch one.
    static func generatedCopyright(year date: Date?, photographer: String) -> String {
        let year = Calendar.current.component(.year, from: date ?? Date())
        let name = photographer.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "\u{00A9} \(year)" : "\u{00A9} \(year) \(name)"
    }
}

/// A field's label column, with a small orange dot appended when
/// `isChanged` is true — used throughout this file's "Labeled*" field
/// wrappers to mark a field whose value differs from what's on disk
/// (`item.edited.x != item.original.x`). Same dot style as the whole-photo
/// "unsaved changes" indicator in `PhotoListView`, just applied per field.
struct FieldLabel: View {
    let text: LocalizedStringKey
    var isChanged: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
            if isChanged {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 6, height: 6)
            }
        }
        .frame(width: 190, alignment: .leading)
        .foregroundStyle(.secondary)
    }
}

struct FieldGroup<Content: View>: View {
    let title: LocalizedStringKey
    var titleFont: Font = .title3.bold()
    /// When set, shows a small clear-section button next to the title.
    /// Callers are responsible for only clearing fields that are actually
    /// visible right now — see e.g. `MetadataEditorView.clearBasicsFields`.
    var onClear: (() -> Void)? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(titleFont)
                if let onClear {
                    Spacer()
                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear Section")
                }
            }
            VStack(spacing: 8) {
                content
            }
        }
    }
}

struct LabeledField<Trailing: View>: View {
    let label: LocalizedStringKey
    @Binding var text: String
    var isChanged: Bool = false
    /// Shown (grayed out) only while `text` is empty — used in the batch
    /// editor to surface a value shared by every selected photo without
    /// actually writing it into `batchDraft` (which would make it part of
    /// the save).
    var placeholder: String = ""
    @ViewBuilder var trailing: () -> Trailing

    init(
        _ label: LocalizedStringKey,
        _ text: Binding<String>,
        isChanged: Bool = false,
        placeholder: String = "",
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.label = label
        self._text = text
        self.isChanged = isChanged
        self.placeholder = placeholder
        self.trailing = trailing
    }

    var body: some View {
        HStack {
            FieldLabel(text: label, isChanged: isChanged)
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
            trailing()
        }
    }
}

/// A switch laid out in the same label-column + control grid as
/// `LabeledField`, so it lines up with the rest of a section instead of
/// using `Toggle`'s own default (label immediately left of the switch).
struct LabeledToggle: View {
    let label: LocalizedStringKey
    @Binding var isOn: Bool
    var isChanged: Bool = false

    init(_ label: LocalizedStringKey, isOn: Binding<Bool>, isChanged: Bool = false) {
        self.label = label
        self._isOn = isOn
        self.isChanged = isChanged
    }

    var body: some View {
        HStack {
            FieldLabel(text: label, isChanged: isChanged)
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
            Spacer()
        }
    }
}

/// Like `LabeledField`, but for fields that only ever take one of a handful
/// of common real-world values (looked up from `PresetCategory`'s fixed
/// field specs, the single source of truth for these suggestion lists) —
/// shows a combo box (pick a common value, or type your own) instead of a
/// bare text field.
struct SuggestibleField: View {
    let label: LocalizedStringKey
    @Binding var text: String
    let keyPath: WritableKeyPath<FilmMetadata, String>
    var isChanged: Bool = false
    var placeholder: String = ""

    init(_ label: LocalizedStringKey, _ text: Binding<String>, keyPath: WritableKeyPath<FilmMetadata, String>, isChanged: Bool = false, placeholder: String = "") {
        self.label = label
        self._text = text
        self.keyPath = keyPath
        self.isChanged = isChanged
        self.placeholder = placeholder
    }

    private var suggestions: [String] {
        for category in PresetCategory.allCases {
            if let spec = category.fixedFieldSpecs.first(where: { $0.keyPath == keyPath }) {
                return spec.suggestions
            }
        }
        return []
    }

    var body: some View {
        HStack {
            FieldLabel(text: label, isChanged: isChanged)
            if suggestions.isEmpty {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.roundedBorder)
            } else {
                ComboBoxField(text: $text, options: suggestions, placeholder: placeholder)
            }
        }
    }
}

/// Like `SuggestibleField`, but for a field whose suggestion list depends on
/// another field's current value rather than being fixed — used for "Name"
/// in the Film section, where the combo box only offers stocks made by
/// whatever's currently in "Manufacturer" (`FilmStockDatabase.names(forMaker:)`).
struct DynamicSuggestibleField: View {
    let label: LocalizedStringKey
    @Binding var text: String
    let suggestions: [String]
    var isChanged: Bool = false
    var placeholder: String = ""

    init(_ label: LocalizedStringKey, _ text: Binding<String>, suggestions: [String], isChanged: Bool = false, placeholder: String = "") {
        self.label = label
        self._text = text
        self.suggestions = suggestions
        self.isChanged = isChanged
        self.placeholder = placeholder
    }

    var body: some View {
        HStack {
            FieldLabel(text: label, isChanged: isChanged)
            if suggestions.isEmpty {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.roundedBorder)
            } else {
                ComboBoxField(text: $text, options: suggestions, placeholder: placeholder)
            }
        }
    }
}

/// Latitude and longitude entered as one comma-separated field ("37.7749,
/// -122.4194") instead of two separate rows. Backed by a plain @State
/// string, synced from the model on appear/external change and committed
/// back only on submit or losing focus — the same "commit on blur" pattern
/// as `LabeledDateField`'s @State fix, so a half-typed second number never
/// gets clobbered by a live re-derived binding.
struct LabeledCoordinateField<Trailing: View>: View {
    let label: LocalizedStringKey
    @Binding var latitude: Double?
    @Binding var longitude: Double?
    var isChanged: Bool = false
    @ViewBuilder var trailing: () -> Trailing

    @State private var text: String = ""
    @FocusState private var focused: Bool

    init(
        _ label: LocalizedStringKey,
        latitude: Binding<Double?>,
        longitude: Binding<Double?>,
        isChanged: Bool = false,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.label = label
        self._latitude = latitude
        self._longitude = longitude
        self.isChanged = isChanged
        self.trailing = trailing
    }

    var body: some View {
        HStack {
            FieldLabel(text: label, isChanged: isChanged)
            TextField("Latitude, Longitude", text: $text)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit { commit() }
                .onChange(of: focused) { _, isFocused in
                    if !isFocused { commit() }
                }
            trailing()
        }
        .onAppear { syncFromModel() }
        .onChange(of: latitude) { _, _ in if !focused { syncFromModel() } }
        .onChange(of: longitude) { _, _ in if !focused { syncFromModel() } }
    }

    private func syncFromModel() {
        if let lat = latitude, let lon = longitude {
            // 5 decimal places is already ~1.1m of precision at the
            // equator — plenty for where a photo was taken, and far
            // shorter than a raw Double's full (often noisy) precision.
            text = String(format: "%.5f, %.5f", lat, lon)
        } else {
            text = ""
        }
    }

    private func commit() {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            // Only write through if there's actually something to clear —
            // clicking into an already-empty field and away again shouldn't
            // record a no-op "edit".
            guard latitude != nil || longitude != nil else { return }
            latitude = nil
            longitude = nil
            return
        }
        let parts = trimmed.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2, let lat = Double(parts[0]), let lon = Double(parts[1]) else {
            // Invalid input — revert the field to the last known-good values.
            syncFromModel()
            return
        }
        // Same guard as `LabeledComboField`'s normalization — clicking into
        // an unchanged, already-valid field and away again shouldn't record
        // a no-op "edit" either.
        guard lat != latitude || lon != longitude else { return }
        latitude = lat
        longitude = lon
    }
}

/// A small, read-only map centered on a coordinate — shown right below the
/// Location field whenever it has a value, just for context (still
/// pannable/zoomable, but with no tap-to-set-pin behavior like
/// `MapLocationPickerView`'s own map, since this isn't an editing control).
struct LocationPreviewMap: View {
    let latitude: Double
    let longitude: Double

    var body: some View {
        Map(initialPosition: .region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        )) {
            Marker("", coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
        }
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// A date+time picker in the same label-column grid as `LabeledField`, for
/// optional `Date` fields (Capture Time, Loaded Date, Development Time,
/// ...) — with the same "x" clear button used everywhere else a value can
/// be unset (e.g. `StarRatingView`), rather than a plain "Clear" text
/// button.
///
/// This used to briefly be a plain text field instead, so its display could
/// follow a chosen Date/Time Format (including showing seconds). That was
/// reverted: `DatePicker` has no API to show seconds at all (no
/// `DatePickerComponents` option covers it) and its date segment always
/// follows the system locale, not a chosen pattern — so there was no way to
/// deliver the requested formatting through the *picker widget itself*
/// without dropping the picker for a text field, which wasn't wanted
/// either. The Date/Time Format settings this fed have been removed.
struct LabeledDateField: View {
    let label: LocalizedStringKey
    @Binding var date: Date?
    var isChanged: Bool = false

    // A real, stable @State backs the picker itself, synced to/from `date`
    // only on actual changes (via the onChange hooks below). Binding the
    // picker directly to a computed `date ?? Date()` getter is a trap: that
    // getter re-evaluates (and returns a *new* "now") on every read, and
    // DatePicker can write its currently-displayed value back through the
    // binding during its own internal updates — including right after the
    // clear button sets `date = nil`, silently resurrecting it to "now" a
    // moment later. A plain @State has no such read-produces-new-value
    // feedback risk.
    @State private var internalDate: Date = Date()

    init(_ label: LocalizedStringKey, _ date: Binding<Date?>, isChanged: Bool = false) {
        self.label = label
        self._date = date
        self.isChanged = isChanged
    }

    var body: some View {
        HStack {
            FieldLabel(text: label, isChanged: isChanged)
            if date != nil {
                DatePicker("", selection: $internalDate, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .onChange(of: internalDate) { _, newValue in
                        // `onAppear` below sets `internalDate` from `date`
                        // on this view's very first appearance — for a
                        // photo that already had a time set, that's a real
                        // change to `internalDate` (from its `Date()`
                        // default), which fires this same `.onChange` and
                        // would otherwise write `date` right back to what
                        // it already was. That happens exactly once per
                        // launch (whichever photo is shown first, e.g. the
                        // one a folder import auto-selects), and looked
                        // like an unedited photo having something to undo.
                        guard date != newValue else { return }
                        date = newValue
                    }
                Button {
                    // Clears the time to a genuinely blank/undefined state —
                    // `date` becomes nil (so it's left out of the file
                    // entirely) and the picker itself disappears, rather
                    // than staying on screen still showing the old time.
                    date = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear")
            } else {
                Button("Set Time") {
                    internalDate = Date()
                    date = internalDate
                }
            }
            Spacer()
        }
        .onAppear {
            if let date { internalDate = date }
        }
    }
}

/// Like `LabeledField`, but always a combo box against an explicit option
/// list (for fields with no `PresetCategory` fixed-field entry to look
/// suggestions up from, e.g. aperture/shutter speed/exposure program).
struct LabeledComboField: View {
    let label: LocalizedStringKey
    @Binding var text: String
    let options: [String]
    /// When set, a value typed without this unit gets it appended once
    /// editing ends (e.g. "50" → "50 mm") — and it's stripped off before
    /// checking whether what's left is a valid number. `nil` for fields
    /// with no unit convention (ISO, Aperture), which still get the
    /// numeric check when `validatesNumber` is on.
    var unit: String? = nil
    /// Turns on the "must be a number" check at all. Off by default since
    /// some `LabeledComboField`s (Exposure Program, White Balance) hold a
    /// fixed label, not a number.
    var validatesNumber: Bool = false
    /// Shutter speeds are conventionally also written as a fraction
    /// ("1/125"), which `Double(_:)` doesn't parse.
    var allowsFraction: Bool = false
    /// Only Exposure Bias is signed (e.g. "-0.3 ev") — ISO, Aperture,
    /// Shutter Speed, and Focal Length can't be negative in real life.
    var allowsNegative: Bool = false
    /// When set, the dropdown opens scrolled so this option sits in the
    /// middle of the visible list rather than wherever it happens to fall
    /// — used for Exposure Bias, where "0 ev" is the natural place to start
    /// browsing from in either direction, instead of the top of a list that
    /// runs from -3 to +3.
    var centerValue: String? = nil
    var isChanged: Bool = false
    var placeholder: String = ""

    init(
        _ label: LocalizedStringKey,
        _ text: Binding<String>,
        options: [String],
        unit: String? = nil,
        validatesNumber: Bool = false,
        allowsFraction: Bool = false,
        allowsNegative: Bool = false,
        centerValue: String? = nil,
        isChanged: Bool = false,
        placeholder: String = ""
    ) {
        self.label = label
        self._text = text
        self.options = options
        self.unit = unit
        self.validatesNumber = validatesNumber
        self.allowsFraction = allowsFraction
        self.allowsNegative = allowsNegative
        self.centerValue = centerValue
        self.isChanged = isChanged
        self.placeholder = placeholder
    }

    /// Live, not just on blur — the red border needs to track every
    /// keystroke, since it (via `FilmMetadata.hasInvalidNumericField`) is
    /// also what keeps Save disabled while it's showing.
    private var isInvalid: Bool {
        validatesNumber && !isValidNumericFieldValue(text, unit: unit, allowsFraction: allowsFraction, allowsNegative: allowsNegative)
    }

    var body: some View {
        HStack {
            FieldLabel(text: label, isChanged: isChanged)
            ComboBoxField(text: $text, options: options, placeholder: placeholder, isInvalid: isInvalid, centerValue: centerValue)
        }
        // A plain SwiftUI `.onChange`, not an `NSComboBoxDelegate` method —
        // an earlier version implemented `controlTextDidEndEditing` on the
        // combo box's delegate for this, which (combined with an unrelated
        // reentrancy bug since fixed) broke selecting values entirely.
        // `.onChange` only touches the binding, never the combo box's own
        // editing/selection machinery.
        .onChange(of: text) { _, _ in
            guard validatesNumber else { return }
            commitValidation()
        }
    }

    /// Normalizes a valid value by appending its missing unit, if any (e.g.
    /// "50" → "50 mm"). Runs on every change, so typing a bare number that's
    /// already complete on its own (like ISO's "400") gets it immediately —
    /// the trade-off is that a unit can appear before you're done typing a
    /// longer number, which is a minor inconvenience next to relying on
    /// AppKit delegate hooks that turned out to be fragile. An invalid
    /// value is left exactly as typed (still flagged by the red border)
    /// rather than reverted or wiped.
    private func commitValidation() {
        guard !isInvalid else { return }
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        var numeric = trimmed
        if let unit, trimmed.lowercased().hasSuffix(unit.lowercased()) {
            numeric = String(trimmed.dropLast(unit.count)).trimmingCharacters(in: .whitespaces)
        }
        let normalized: String
        if numeric.isEmpty {
            normalized = ""
        } else if let unit {
            normalized = "\(numeric) \(unit)"
        } else {
            normalized = numeric
        }
        // `.onChange(of: text)` fires whenever the bound value differs from
        // last render for *any* reason — including simply selecting a
        // different photo, since its field naturally holds a different
        // value than the previous one. Without this guard, an
        // already-correctly-formatted value (which is the common case,
        // e.g. anything read from a file or picked from the dropdown) would
        // still get written right back on every such switch — a no-op in
        // content, but a real assignment that made `PhotoItem` think an
        // edit had just happened on a photo nobody touched.
        guard normalized != text else { return }
        text = normalized
    }
}
