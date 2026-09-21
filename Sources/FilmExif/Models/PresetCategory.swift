import Foundation

/// One of a category's fixed fields: a display label, the `FilmMetadata`
/// property it writes to, and (for fields with only a handful of common
/// real-world values, like "Camera Make" or "Film ISO") a suggestion list
/// so the preset editor can offer a combo box instead of a bare text field.
struct FixedFieldSpec: Identifiable {
    var id: String { label }
    let label: String
    let keyPath: WritableKeyPath<FilmMetadata, String>
    let suggestions: [String]
}

/// Common real-world values for fields that only ever take one of a handful
/// of options, used to populate combo boxes throughout the app.
enum FieldSuggestions {
    static let makers = [
        "Kodak", "Fujifilm", "Ilford", "Kentmere", "Canon", "Nikon", "Pentax", "Olympus",
        "Minolta", "Leica", "Contax", "Yashica", "Mamiya", "Hasselblad",
        "CineStill", "Lomography", "Agfa", "Foma", "ORWO", "Adox", "Bergger", "Flic Film", "Epson"
    ]
    /// Film camera manufacturers — researched online (Wikipedia's list of
    /// photographic equipment makers, Camera-wiki.org, Photrio) rather than
    /// guessed, so it covers real historical/defunct brands still commonly
    /// seen on used film cameras, not just today's active ones.
    static let cameraMakes = [
        "Agfa", "Alpa", "Ansco", "Argus", "Arsenal", "Balda", "Bell & Howell", "Bolsey",
        "Braun", "Bronica", "Cambo", "Canon", "Chamonix", "Chinon", "Contax", "Cosina",
        "Diana", "Exakta", "FED", "Fujica", "Fujifilm", "GAF", "Graflex", "Halina",
        "Hanimex", "Hasselblad", "Holga", "Horseman", "Ihagee", "Keystone", "Kiev", "KMZ",
        "Kodak", "Konica", "Kowa", "Leica", "Leitz", "Linhof", "LOMO", "Lomography",
        "Mamiya", "Minolta", "Minox", "Miranda", "Nagaoka", "Nikon", "Nimslo", "Olympus",
        "Pentax", "Petri", "Polaroid", "Praktica", "Realist", "Ricoh", "Rollei", "Sinar",
        "Toyo", "Voigtländer", "Wista", "Wisner", "Yashica", "Zeiss Ikon", "Zenit", "Zorki"
    ]
    /// Lens manufacturers — includes both camera makers who also built their
    /// own lenses and independent/third-party lens makers, researched the
    /// same way as `cameraMakes`.
    static let lensMakes = [
        "7Artisans", "Angénieux", "Astro-Berlin", "Canon", "Carl Zeiss", "Carl Zeiss Jena",
        "Chinon", "Cosina", "Enna", "Fujifilm", "Helios", "Industar", "Isco-Göttingen",
        "Jupiter", "Kern", "Kilfitt", "Kiron", "Kodak", "Komura", "Konica", "Leica",
        "Leitz", "Mamiya", "Meike", "Meyer-Optik Görlitz", "Minolta", "Nikon", "Novoflex",
        "Olympus", "Panagor", "Pentacon", "Pentax", "Praktica", "Promaster", "Quantaray",
        "Ricoh", "Rodenstock", "Rokinon", "Samyang", "Schneider Kreuznach", "Sigma",
        "Soligor", "Steinheil", "Tair", "Tamron", "Tokina", "TTArtisan", "Venus Optics",
        "Vivitar", "Voigtländer", "Yashica", "Zenit"
    ]
    /// Film-scanner and flatbed-scanner manufacturers commonly used for
    /// scanning film, researched the same way as `cameraMakes`.
    static let scannerMakes = [
        "Agfa", "Braun", "Canon", "Epson", "Fujifilm", "Hasselblad", "Heidelberg", "Imacon",
        "Kodak", "Konica Minolta", "Magnasonic", "Microtek", "Minolta", "Nikon", "Noritsu",
        "Pacific Image Electronics", "Pakon", "Plustek", "Polaroid", "Reflecta", "UMAX",
        "Wolverine"
    ]
    static let isoValues = ["25", "50", "64", "100", "160", "200", "320", "400", "800", "1600", "3200"]
    static let filmFormats = ["35", "120", "220", "4x5", "8x10", "110"]
    /// English/universal identifiers for `development.process` — kept as
    /// its own fixed, never-localized list (matching `FilmStockDatabase`'s
    /// process names) for the same reason as `filmTypeCanonicalNames`, plus
    /// one more: this is the exact text written into the AnalogExif mirror
    /// tag (see `ExifXMPService.write`), since AnalogExif itself expects
    /// "C-41"/"E-6"/etc, not a translated word or a bare code.
    static let processCanonicalNames = ["C-41", "E-6", "B&W", "ECN-2"]
    static func processCode(forCanonicalName name: String) -> String {
        guard let index = processCanonicalNames.firstIndex(of: name) else { return name }
        return String(index)
    }
    /// The value the AnalogExif mirror tag should actually hold for a given
    /// `development.process` value — the canonical English name if it's one
    /// of the 4 known processes, or the value itself unchanged otherwise
    /// (someone's free-typed process name, e.g. "Rodinal stand"; Process
    /// isn't a closed enum in the way File Source/Is Film Photo are, so an
    /// unrecognized value is real user data, never a mistake to discard).
    static func processCanonicalValue(_ raw: String) -> String {
        guard let index = Int(raw), processCanonicalNames.indices.contains(index) else { return raw }
        return processCanonicalNames[index]
    }
    /// `development.process` is stored as this array's bare index ("0"-"3")
    /// for one of the 4 known processes, or as free text otherwise (see
    /// `processCanonicalValue` above) — `processDisplayValue`/`...RawValue`
    /// convert a code to/from the current language's label, and pass a
    /// value through unchanged when it isn't a recognized code/label
    /// (empty, or someone's own free-typed process name).
    static var processLabels: [String] {
        [
            NSLocalizedString("Process_C41", value: "C-41", comment: "Development Process option"),
            NSLocalizedString("Process_E6", value: "E-6", comment: "Development Process option"),
            NSLocalizedString("Process_BW", value: "B&W", comment: "Development Process option"),
            NSLocalizedString("Process_ECN2", value: "ECN-2", comment: "Development Process option")
        ]
    }
    static func processDisplayValue(_ raw: String) -> String {
        guard let index = Int(raw), processLabels.indices.contains(index) else { return raw }
        return processLabels[index]
    }
    static func processRawValue(_ display: String) -> String {
        guard let index = processLabels.firstIndex(of: display) else { return display }
        return String(index)
    }
    /// English identifiers `FilmStockDatabase` and `FilmPreset`'s ~60+ built-
    /// in entries use for a stock's type — kept as its own fixed,
    /// never-localized list distinct from `filmTypeLabels` (the translated
    /// display text) so that database doesn't need editing every time a
    /// language is added. Convert one of these names to a storable code
    /// with `filmTypeCode(forCanonicalName:)`.
    static let filmTypeCanonicalNames = [
        "Color Negative", "Color Reversal", "Black & White Negative",
        "Black & White Reversal", "Instant"
    ]
    static func filmTypeCode(forCanonicalName name: String) -> String {
        guard let index = filmTypeCanonicalNames.firstIndex(of: name) else { return "" }
        return String(index)
    }
    /// `FilmInfo.type` is stored as this array's bare index ("0"..."4"), not
    /// the label text — see `filmTypeDisplayValue`/`filmTypeRawValue`, the
    /// only place code and localized label convert.
    static var filmTypeLabels: [String] {
        [
            NSLocalizedString("FilmType_ColorNegative", value: "Color Negative", comment: "Film Type option"),
            NSLocalizedString("FilmType_ColorReversal", value: "Color Reversal", comment: "Film Type option"),
            NSLocalizedString("FilmType_BWNegative", value: "Black & White Negative", comment: "Film Type option"),
            NSLocalizedString("FilmType_BWReversal", value: "Black & White Reversal", comment: "Film Type option"),
            NSLocalizedString("FilmType_Instant", value: "Instant", comment: "Film Type option")
        ]
    }
    static func filmTypeDisplayValue(_ raw: String) -> String {
        guard let index = Int(raw), filmTypeLabels.indices.contains(index) else { return "" }
        return filmTypeLabels[index]
    }
    static func filmTypeRawValue(_ display: String) -> String {
        guard let index = filmTypeLabels.firstIndex(of: display) else { return "" }
        return String(index)
    }

    /// `DevelopmentInfo.pushPull` is stored as this bare number string (e.g.
    /// matching how RetroExif's own files store it — "0", not a word),
    /// ordered so "0" (`pushPullStandardLabel`) falls in the middle of the
    /// list rather than at an end — see `pushPullDisplayValue`/
    /// `...RawValue`, the only place code and localized label convert.
    static let pushPullValues = ["-3", "-2", "-1", "0", "+1", "+2", "+3"]
    static func pushPullDisplayValue(_ raw: String) -> String {
        (raw == "0" || raw == "Normal") ? pushPullStandardLabel : raw
    }
    static func pushPullRawValue(_ display: String) -> String {
        display == pushPullStandardLabel ? "0" : display
    }
    static var pushPullStandardLabel: String {
        NSLocalizedString("PushPull_Standard", value: "Standard", comment: "Push/Pull option meaning no push or pull")
    }
    static let scanResolutions = ["1200 dpi", "2400 dpi", "4000 dpi", "6300 dpi", "9600 dpi"]
    static let bitDepths = ["8-bit", "16-bit"]
    static let colorSpaces = ["sRGB", "Adobe RGB", "ProPhoto RGB"]
    static let scanTypes = ["Positive", "Negative", "Print"]

    /// EXIF ExposureProgram values 1...9, in that order (index 0 == EXIF 1).
    /// `exposureProgram` is stored as this bare EXIF value ("1"..."9"), not
    /// the label text — see `exposureProgramDisplayValue`/`...RawValue`, the
    /// only place code and localized label convert.
    static var exposureProgramLabels: [String] {
        [
            NSLocalizedString("ExposureProgram_Manual", value: "Manual", comment: "Exposure Program option"),
            NSLocalizedString("ExposureProgram_ProgramAE", value: "Program AE", comment: "Exposure Program option"),
            NSLocalizedString("ExposureProgram_AperturePriority", value: "Aperture Priority", comment: "Exposure Program option"),
            NSLocalizedString("ExposureProgram_ShutterPriority", value: "Shutter Priority", comment: "Exposure Program option"),
            NSLocalizedString("ExposureProgram_Creative", value: "Creative", comment: "Exposure Program option"),
            NSLocalizedString("ExposureProgram_Action", value: "Action", comment: "Exposure Program option"),
            NSLocalizedString("ExposureProgram_Portrait", value: "Portrait", comment: "Exposure Program option"),
            NSLocalizedString("ExposureProgram_Landscape", value: "Landscape", comment: "Exposure Program option"),
            NSLocalizedString("ExposureProgram_Bulb", value: "Bulb", comment: "Exposure Program option")
        ]
    }
    static func exposureProgramDisplayValue(_ raw: String) -> String {
        guard let exifValue = Int(raw), exifValue >= 1, exifValue - 1 < exposureProgramLabels.count else { return "" }
        return exposureProgramLabels[exifValue - 1]
    }
    static func exposureProgramRawValue(_ display: String) -> String {
        guard let index = exposureProgramLabels.firstIndex(of: display) else { return "" }
        return String(index + 1)
    }

    /// EXIF WhiteBalance values 0...1, in that order — `whiteBalance` is
    /// stored as this bare value ("0"/"1"), see `whiteBalanceDisplayValue`/
    /// `...RawValue`.
    static var whiteBalanceLabels: [String] {
        [
            NSLocalizedString("WhiteBalance_Auto", value: "Auto", comment: "White Balance option"),
            NSLocalizedString("WhiteBalance_Manual", value: "Manual", comment: "White Balance option")
        ]
    }
    static func whiteBalanceDisplayValue(_ raw: String) -> String {
        guard let index = Int(raw), whiteBalanceLabels.indices.contains(index) else { return "" }
        return whiteBalanceLabels[index]
    }
    static func whiteBalanceRawValue(_ display: String) -> String {
        guard let index = whiteBalanceLabels.firstIndex(of: display) else { return "" }
        return String(index)
    }

    /// EXIF MeteringMode values 1...6, in that order (index 0 == EXIF 1) —
    /// 0 ("Unknown") and 255 ("Other") have no corresponding label.
    /// `meteringMode` is stored as this bare EXIF value ("1"..."6"), see
    /// `meteringModeDisplayValue`/`...RawValue`.
    static var meteringModeLabels: [String] {
        [
            NSLocalizedString("MeteringMode_Average", value: "Average", comment: "Metering Mode option"),
            NSLocalizedString("MeteringMode_CenterWeighted", value: "Center-Weighted Average", comment: "Metering Mode option"),
            NSLocalizedString("MeteringMode_Spot", value: "Spot", comment: "Metering Mode option"),
            NSLocalizedString("MeteringMode_MultiSpot", value: "Multi-Spot", comment: "Metering Mode option"),
            NSLocalizedString("MeteringMode_Pattern", value: "Pattern", comment: "Metering Mode option"),
            NSLocalizedString("MeteringMode_Partial", value: "Partial", comment: "Metering Mode option")
        ]
    }
    static func meteringModeDisplayValue(_ raw: String) -> String {
        guard let exifValue = Int(raw), exifValue >= 1, exifValue - 1 < meteringModeLabels.count else { return "" }
        return meteringModeLabels[exifValue - 1]
    }
    static func meteringModeRawValue(_ display: String) -> String {
        guard let index = meteringModeLabels.firstIndex(of: display) else { return "" }
        return String(index + 1)
    }

    /// EXIF FileSource values 0...3, in that order (index N == EXIF N) — the
    /// tag's entire spec-defined vocabulary; verified against exiftool's own
    /// tag database, which tracks every real-world value any vendor has
    /// ever used for this tag (only 1-3 are ever actually seen in practice).
    static var fileSourceLabels: [String] {
        [
            NSLocalizedString("FileSource_Others", value: "Others", comment: "File Source option"),
            NSLocalizedString("FileSource_FilmScanner", value: "Film Scanner", comment: "File Source option"),
            NSLocalizedString("FileSource_ReflectionScanner", value: "Reflection Print Scanner", comment: "File Source option"),
            NSLocalizedString("FileSource_DigitalStillCamera", value: "Digital Still Camera", comment: "File Source option")
        ]
    }
    static var filmPhotoLabels: [String] {
        [
            NSLocalizedString("FilmPhoto_Yes", value: "Yes", comment: "Is Film Photo option"),
            NSLocalizedString("FilmPhoto_No", value: "No", comment: "Is Film Photo option")
        ]
    }

    /// `fileSource`/`isFilmPhoto` are stored as bare numeric-code strings
    /// (like `pushPull`'s "0"/"+1"/"-1" convention in `MetadataEditorView`),
    /// never as the translated label text — so a value saved under one
    /// language reads back correctly under any other, and the disabled-
    /// section checks below can compare against a fixed code instead of a
    /// label that changes per language. `fileSourceDisplayValue`/
    /// `filmPhotoDisplayValue` (and their `...RawValue` inverses) are the
    /// only place code and display text convert between each other, used
    /// by the editors' File-section combo box bindings.
    static let digitalStillCameraCode = "3"
    static let filmPhotoYesCode = "1"
    static let filmPhotoNoCode = "0"

    static func fileSourceDisplayValue(_ raw: String) -> String {
        guard let index = Int(raw), fileSourceLabels.indices.contains(index) else { return "" }
        return fileSourceLabels[index]
    }
    static func fileSourceRawValue(_ display: String) -> String {
        guard let index = fileSourceLabels.firstIndex(of: display) else { return "" }
        return String(index)
    }

    static func filmPhotoDisplayValue(_ raw: String) -> String {
        switch raw {
        case filmPhotoYesCode: return filmPhotoLabels[0]
        case filmPhotoNoCode: return filmPhotoLabels[1]
        default: return ""
        }
    }
    static func filmPhotoRawValue(_ display: String) -> String {
        switch display {
        case filmPhotoLabels[0]: return filmPhotoYesCode
        case filmPhotoLabels[1]: return filmPhotoNoCode
        default: return ""
        }
    }

    static let apertureValues = ["1", "1.4", "2", "2.8", "4", "5.6", "8", "11", "16", "22", "32"]

    /// 1/3-stop shutter speeds, fastest to slowest, with the "s" unit baked
    /// into the display/stored string (stripped back off before EXIF write).
    static let shutterSpeedValues = [
        "1/8000 s", "1/6400 s", "1/5000 s", "1/4000 s", "1/3200 s", "1/2500 s",
        "1/2000 s", "1/1600 s", "1/1250 s", "1/1000 s", "1/800 s", "1/640 s",
        "1/500 s", "1/400 s", "1/320 s", "1/250 s", "1/200 s", "1/160 s",
        "1/125 s", "1/100 s", "1/80 s", "1/60 s", "1/50 s", "1/40 s",
        "1/30 s", "1/25 s", "1/20 s", "1/15 s", "1/13 s", "1/10 s",
        "1/8 s", "1/6 s", "1/5 s", "1/4 s", "0.3 s", "0.4 s", "0.5 s",
        "0.6 s", "0.8 s", "1 s", "1.3 s", "1.6 s", "2 s", "2.5 s",
        "3.2 s", "4 s", "5 s", "6 s", "8 s", "10 s", "15 s", "30 s"
    ]

    /// 1/3-stop exposure compensation, with the "ev" unit baked in.
    static let exposureBiasValues = [
        "-3 ev", "-2.7 ev", "-2.3 ev", "-2 ev", "-1.7 ev", "-1.3 ev", "-1 ev",
        "-0.7 ev", "-0.3 ev", "0 ev", "+0.3 ev", "+0.7 ev", "+1 ev",
        "+1.3 ev", "+1.7 ev", "+2 ev", "+2.3 ev", "+2.7 ev", "+3 ev"
    ]

    /// Common focal lengths, with the "mm" unit baked in.
    static let focalLengthValues = [
        "14 mm", "16 mm", "20 mm", "24 mm", "28 mm", "35 mm", "50 mm",
        "65 mm", "85 mm", "100 mm", "135 mm", "150 mm", "200 mm",
        "300 mm", "400 mm"
    ]
}

/// The groups presets (and the right-hand preset panel) are organized into,
/// in display order — `CaseIterable`'s `allCases` follows declaration order,
/// which is what both the preset panel and the preset settings list iterate.
/// Each category owns a fixed subset of `FilmMetadata`'s fields, so applying
/// a category-scoped preset never touches fields outside its group, unless
/// that category also declares `extraFieldCategories` / individual borrowed
/// fields (see below) — Lab presets, for instance, can also carry
/// Development/Scanning values.
enum PresetCategory: String, Codable, CaseIterable, Identifiable {
    case photographer, exposureSettings, cameraBody, lens, film, lab, development, scanning

    var id: String { rawValue }

    var title: String {
        switch self {
        case .exposureSettings: return "Shooting Parameters"
        case .cameraBody: return "Camera Body"
        case .lens: return "Lens"
        case .film: return "Film"
        case .development: return "Development"
        case .lab: return "Lab"
        case .scanning: return "Scanning"
        case .photographer: return "Photographer"
        }
    }

    var systemImage: String {
        switch self {
        case .exposureSettings: return "gauge"
        case .cameraBody: return "camera"
        case .lens: return "camera.aperture"
        case .film: return "film"
        case .development: return "flask"
        case .lab: return "building.2"
        case .scanning: return "scanner"
        case .photographer: return "person.fill"
        }
    }

    /// The `.id(...)` of the `FieldGroup` this category's fields live in,
    /// in both `MetadataEditorView` and `BatchEditorView` — used to scroll
    /// that section into view when a preset from this category is applied.
    /// `.cameraBody` and `.lens` share one "Camera & Lens" group; every
    /// other category has its own matching section. A category with
    /// `extraFieldCategories` (e.g. Lab, which can also carry Development/
    /// Scanning values) still only scrolls to its own primary section.
    var scrollSectionID: String {
        switch self {
        case .exposureSettings: return "section-exposure"
        case .cameraBody, .lens: return "section-camera"
        case .film: return "section-film"
        case .development: return "section-development"
        case .lab: return "section-lab"
        case .scanning: return "section-scanning"
        case .photographer: return "section-photographer"
        }
    }

    /// Other categories whose fields this one's preset editor *also* offers,
    /// each as its own same-level field group (own title, own "+" menu, own
    /// default fields) alongside this category's primary one — e.g. a Lab
    /// preset can also carry Development and Scanning fields, since a lab
    /// often handles both, without those fields becoming part of every
    /// Development/Scanning preset's own identity. Empty for every category
    /// that doesn't need this.
    var extraFieldCategories: [PresetCategory] {
        switch self {
        case .lab: return [.development, .scanning]
        default: return []
        }
    }

    /// Individual fields borrowed from another category's `fixedFieldSpecs`
    /// (or from `borrowableFieldSpecs`, for a field with no active category
    /// of its own) and folded into *this* category's own primary field
    /// group (not a separate section, unlike `extraFieldCategories`) — e.g.
    /// a Film preset can also set Development's "Process" and Roll's "Frame
    /// Count", since both are closely related but shouldn't become one of
    /// Film's own fields.
    var extraIndividualFieldLabels: [String] {
        switch self {
        case .film: return ["Process", "Total Frame Count"]
        default: return []
        }
    }

    /// Fields that don't belong to any active preset category's own
    /// `fixedFieldSpecs` — e.g. "Total Frame Count", which lives on
    /// `RollInfo` but has no Roll preset category of its own — yet can
    /// still be borrowed by another category via `extraIndividualFieldLabels`.
    private static let borrowableFieldSpecs: [FixedFieldSpec] = [
        FixedFieldSpec(label: "Total Frame Count", keyPath: \.roll.frameCount, suggestions: [])
    ]

    /// Looks up a `FixedFieldSpec` by label across every category (and
    /// `borrowableFieldSpecs`) — used to resolve `extraIndividualFieldLabels`,
    /// which name a field without saying which category actually owns it.
    static func fixedFieldSpec(labeled label: String) -> FixedFieldSpec? {
        for category in PresetCategory.allCases {
            if let spec = category.fixedFieldSpecs.first(where: { $0.label == label }) {
                return spec
            }
        }
        return borrowableFieldSpecs.first { $0.label == label }
    }

    /// The title `PresetForm` shows above this category's own primary field
    /// group — "General" for most categories, but a category can override
    /// it (e.g. Lab, where "Lab Information" reads more clearly once
    /// Development/Scanning show up as their own same-level groups below).
    var primaryFieldGroupTitle: String {
        switch self {
        case .lab: return "Lab Information"
        default: return "General"
        }
    }

    /// This category's fixed fields, in display order.
    var fixedFieldSpecs: [FixedFieldSpec] {
        switch self {
        case .exposureSettings:
            return [
                FixedFieldSpec(label: "ISO", keyPath: \.shotISO, suggestions: FieldSuggestions.isoValues),
                FixedFieldSpec(label: "Aperture", keyPath: \.aperture, suggestions: FieldSuggestions.apertureValues),
                FixedFieldSpec(label: "Shutter Speed", keyPath: \.shutterSpeed, suggestions: FieldSuggestions.shutterSpeedValues),
                FixedFieldSpec(label: "Exposure Bias", keyPath: \.exposureBias, suggestions: FieldSuggestions.exposureBiasValues),
                FixedFieldSpec(label: "Exposure Program", keyPath: \.exposureProgram, suggestions: FieldSuggestions.exposureProgramLabels),
                FixedFieldSpec(label: "White Balance", keyPath: \.whiteBalance, suggestions: FieldSuggestions.whiteBalanceLabels),
                FixedFieldSpec(label: "Metering Mode", keyPath: \.meteringMode, suggestions: FieldSuggestions.meteringModeLabels),
                FixedFieldSpec(label: "35mm Equivalent Focal Length", keyPath: \.focalLengthIn35mmFormat, suggestions: FieldSuggestions.focalLengthValues)
            ]
        case .cameraBody:
            return [
                FixedFieldSpec(label: "Camera Make", keyPath: \.cameraMake, suggestions: FieldSuggestions.cameraMakes),
                FixedFieldSpec(label: "Camera Model", keyPath: \.cameraModel, suggestions: []),
                FixedFieldSpec(label: "Camera Serial Number", keyPath: \.cameraSerialNumber, suggestions: []),
                FixedFieldSpec(label: "Camera Firmware", keyPath: \.cameraFirmware, suggestions: []),
                FixedFieldSpec(label: "Camera Owner Name", keyPath: \.cameraOwnerName, suggestions: [])
            ]
        case .lens:
            return [
                FixedFieldSpec(label: "Lens Make", keyPath: \.lensMake, suggestions: FieldSuggestions.lensMakes),
                FixedFieldSpec(label: "Lens Model", keyPath: \.lensModel, suggestions: []),
                FixedFieldSpec(label: "Lens Serial Number", keyPath: \.lensSerialNumber, suggestions: []),
                FixedFieldSpec(label: "Lens Specification", keyPath: \.lensSpecification, suggestions: [])
            ]
        case .film:
            return [
                FixedFieldSpec(label: "Manufacturer", keyPath: \.film.maker, suggestions: FieldSuggestions.makers),
                FixedFieldSpec(label: "Name", keyPath: \.film.name, suggestions: []),
                FixedFieldSpec(label: "Film Type", keyPath: \.film.type, suggestions: FieldSuggestions.filmTypeLabels),
                FixedFieldSpec(label: "Format", keyPath: \.film.format, suggestions: FieldSuggestions.filmFormats),
                FixedFieldSpec(label: "Film ISO", keyPath: \.film.iso, suggestions: FieldSuggestions.isoValues),
                FixedFieldSpec(label: "DX Code", keyPath: \.film.dxCode, suggestions: []),
                FixedFieldSpec(label: "Film Batch", keyPath: \.film.batch, suggestions: []),
                FixedFieldSpec(label: "Emulsion Number", keyPath: \.film.emulsionNumber, suggestions: []),
                FixedFieldSpec(label: "Base", keyPath: \.film.base, suggestions: []),
                FixedFieldSpec(label: "Film Grain", keyPath: \.film.grain, suggestions: []),
                FixedFieldSpec(label: "Notes", keyPath: \.notes, suggestions: [])
            ]
        case .development:
            return [
                FixedFieldSpec(label: "Process", keyPath: \.development.process, suggestions: FieldSuggestions.processLabels),
                FixedFieldSpec(label: "Developer", keyPath: \.development.developer, suggestions: []),
                FixedFieldSpec(label: "Developer Manufacturer", keyPath: \.development.developerMaker, suggestions: FieldSuggestions.makers),
                FixedFieldSpec(label: "Developer Dilution", keyPath: \.development.developerDilution, suggestions: []),
                FixedFieldSpec(label: "Development Duration", keyPath: \.development.duration, suggestions: []),
                FixedFieldSpec(label: "Development Temperature", keyPath: \.development.temperature, suggestions: []),
                FixedFieldSpec(label: "Push/Pull", keyPath: \.development.pushPull, suggestions: FieldSuggestions.pushPullValues.map(FieldSuggestions.pushPullDisplayValue)),
                FixedFieldSpec(label: "Bleach", keyPath: \.development.bleach, suggestions: []),
                FixedFieldSpec(label: "Fixer", keyPath: \.development.fixer, suggestions: []),
                FixedFieldSpec(label: "Stabilizer", keyPath: \.development.stabilizer, suggestions: []),
                FixedFieldSpec(label: "Replenishment", keyPath: \.development.replenishment, suggestions: []),
                FixedFieldSpec(label: "Chemistry Notes", keyPath: \.development.chemistryNotes, suggestions: [])
            ]
        case .lab:
            return [
                FixedFieldSpec(label: "Lab Name", keyPath: \.lab.name, suggestions: []),
                FixedFieldSpec(label: "Lab Address", keyPath: \.lab.address, suggestions: []),
                FixedFieldSpec(label: "Lab Contact", keyPath: \.lab.contact, suggestions: []),
                FixedFieldSpec(label: "Lab Notes", keyPath: \.lab.labNotes, suggestions: [])
            ]
        case .scanning:
            return [
                FixedFieldSpec(label: "Scanner Make", keyPath: \.scanning.scannerMaker, suggestions: FieldSuggestions.scannerMakes),
                FixedFieldSpec(label: "Scanner Model", keyPath: \.scanning.scannerModel, suggestions: []),
                FixedFieldSpec(label: "Scanner Serial Number", keyPath: \.scanning.scannerSerialNumber, suggestions: []),
                FixedFieldSpec(label: "Scanner Software", keyPath: \.scanning.scannerSoftware, suggestions: []),
                FixedFieldSpec(label: "Scan Resolution", keyPath: \.scanning.resolution, suggestions: FieldSuggestions.scanResolutions),
                FixedFieldSpec(label: "Bit Depth", keyPath: \.scanning.bitDepth, suggestions: FieldSuggestions.bitDepths),
                FixedFieldSpec(label: "Color Space", keyPath: \.scanning.colorSpace, suggestions: FieldSuggestions.colorSpaces),
                FixedFieldSpec(label: "Scan Type", keyPath: \.scanning.scanType, suggestions: FieldSuggestions.scanTypes),
                FixedFieldSpec(label: "Scan Notes", keyPath: \.scanning.scanNotes, suggestions: [])
            ]
        case .photographer:
            return [
                FixedFieldSpec(label: "Photographer", keyPath: \.artist, suggestions: []),
                FixedFieldSpec(label: "Copyright", keyPath: \.copyright, suggestions: [])
            ]
        }
    }

    /// The subset of `fixedFieldSpecs` a preset editor shows out of the box
    /// (for a brand-new preset, or for one that's never set the field) —
    /// everything else in `fixedFieldSpecs` is opt-in via the preset form's
    /// "+" menu instead. Defaults to every field for a category that hasn't
    /// been curated yet, matching the form's original behavior of always
    /// showing everything.
    var defaultFieldLabels: Set<String> {
        switch self {
        case .exposureSettings:
            return ["ISO", "Aperture", "Shutter Speed", "Exposure Bias", "Exposure Program", "White Balance", "Metering Mode"]
        case .cameraBody:
            return ["Camera Make", "Camera Model", "Camera Serial Number"]
        case .lens:
            return ["Lens Make", "Lens Model", "Lens Serial Number"]
        case .film:
            return ["Manufacturer", "Name", "Film Type", "Format", "Film ISO", "Process", "Total Frame Count"]
        case .development:
            return ["Process", "Push/Pull"]
        case .lab:
            return ["Lab Name", "Lab Address"]
        case .scanning:
            return ["Scanner Make", "Scanner Model", "Scanner Software"]
        default:
            return Set(fixedFieldSpecs.map { $0.label })
        }
    }

    /// Every fixed field this category's presets can actually set: its own
    /// `fixedFieldSpecs`, plus any individual fields borrowed from another
    /// category via `extraIndividualFieldLabels`, plus every field of any
    /// whole `extraFieldCategories`.
    var allApplicableFixedFieldSpecs: [FixedFieldSpec] {
        fixedFieldSpecs
            + extraIndividualFieldLabels.compactMap(Self.fixedFieldSpec(labeled:))
            + extraFieldCategories.flatMap { $0.fixedFieldSpecs }
    }

    /// The `FieldVisibilityRegistry` group a field belongs to, by its own
    /// display label — used by `apply(_:to:)` below to tell whether a given
    /// fixed field currently lives in a disabled editor section, regardless
    /// of which preset category's button was actually clicked (a Lab preset
    /// can carry Scanning fields via `extraFieldCategories`, a Film preset
    /// carries "Total Frame Count" via `extraIndividualFieldLabels`, etc. —
    /// checking by the field's own group, not the category, is what makes
    /// those borrowed fields respect the same gating too).
    private static func groupTitle(forFieldLabeled label: String) -> String? {
        FieldVisibilityRegistry.groups.first { group in
            group.fields.contains { $0.label == label }
        }?.title
    }

    /// Section names currently disabled by the "File" section's two
    /// selection boxes — see the matching `.disabled(...)` modifiers on
    /// `MetadataEditorView`/`BatchEditorView`'s Scanning/Film/Roll/
    /// Development/Lab `FieldGroup`s, which this must stay in sync with.
    private static func disabledGroupTitles(for base: FilmMetadata) -> Set<String> {
        var disabled: Set<String> = []
        if base.fileSource == FieldSuggestions.digitalStillCameraCode { disabled.insert("Scanning") }
        if base.isFilmPhoto == FieldSuggestions.filmPhotoNoCode { disabled.formUnion(["Film", "Roll", "Development", "Lab"]) }
        return disabled
    }

    /// Returns `base` with this category's non-empty fields from `preset`
    /// (fixed fields and custom fields alike) overlaid on top. Fields left
    /// blank in `preset` are left untouched, fields outside this category
    /// (and whatever it borrows via `extraFieldCategories` /
    /// `extraIndividualFieldLabels`) are never touched, and fields whose own
    /// editor section is currently disabled are skipped even if this
    /// category would otherwise set them — clicking a Scanner preset on a
    /// photo marked "Digital Still Camera" shouldn't change anything, since
    /// you couldn't type into those fields by hand either.
    func apply(_ preset: FilmMetadata, to base: FilmMetadata) -> FilmMetadata {
        var result = base
        let disabledGroups = Self.disabledGroupTitles(for: base)
        for spec in allApplicableFixedFieldSpecs {
            if let group = Self.groupTitle(forFieldLabeled: spec.label), disabledGroups.contains(group) { continue }
            let value = preset[keyPath: spec.keyPath]
            if !value.isEmpty { result[keyPath: spec.keyPath] = value }
        }
        for (key, value) in preset.customFields where !value.isEmpty {
            result.customFields[key] = value
        }
        return result
    }

    /// How many non-empty fixed-field values `summary(of:)` shows — Lab
    /// defaults to 2 (its address is often long enough on its own; a 3rd
    /// field tends to just make the row wrap or overflow), every other
    /// category shows 3.
    private var summaryFieldCount: Int {
        switch self {
        case .lab: return 2
        default: return 3
        }
    }

    /// A short "Maker · Model · ..." caption for a preset row — its first
    /// `summaryFieldCount` fields that actually have a value (in the same
    /// order the editor shows them), not just the first `summaryFieldCount`
    /// fields *positionally* — a preset whose 2nd field happens to be blank
    /// but whose 4th has a value should still show 3, not 2.
    func summary(of metadata: FilmMetadata) -> String {
        let values = fixedFieldSpecs.map { spec -> String in
            let raw = metadata[keyPath: spec.keyPath]
            // A couple of fields store a bare numeric code rather than the
            // label text (see `FieldSuggestions.filmTypeDisplayValue`) — the
            // summary should still show the reader the word, not "1".
            if spec.keyPath == \FilmMetadata.film.type {
                return FieldSuggestions.filmTypeDisplayValue(raw)
            }
            if spec.keyPath == \FilmMetadata.development.pushPull {
                return FieldSuggestions.pushPullDisplayValue(raw)
            }
            if spec.keyPath == \FilmMetadata.exposureProgram {
                return FieldSuggestions.exposureProgramDisplayValue(raw)
            }
            if spec.keyPath == \FilmMetadata.whiteBalance {
                return FieldSuggestions.whiteBalanceDisplayValue(raw)
            }
            if spec.keyPath == \FilmMetadata.meteringMode {
                return FieldSuggestions.meteringModeDisplayValue(raw)
            }
            return raw
        }
        return values.filter { !$0.isEmpty }.prefix(summaryFieldCount).joined(separator: " · ")
    }
}
