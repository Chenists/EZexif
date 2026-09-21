import Foundation

/// Whether `value` is acceptable for a numeric metadata field (ISO,
/// Aperture, Shutter Speed, Focal Length, Exposure Bias) — shared between
/// `LabeledComboField`'s live red-border check and `FilmMetadata`'s
/// `hasInvalidNumericField`, so the two never disagree about what counts as
/// valid. An empty value is always valid (an unset field, not an invalid
/// one); `unit`, if given, is stripped (case-insensitively) before parsing,
/// so "50 mm" and "50" are equivalent; `allowsFraction` accepts "1/125"-
/// style shutter speeds; `allowsNegative` is only true for Exposure Bias.
func isValidNumericFieldValue(_ value: String, unit: String?, allowsFraction: Bool, allowsNegative: Bool) -> Bool {
    let trimmed = value.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return true }
    var numeric = trimmed
    if let unit, trimmed.lowercased().hasSuffix(unit.lowercased()) {
        numeric = String(trimmed.dropLast(unit.count)).trimmingCharacters(in: .whitespaces)
    }
    guard !numeric.isEmpty else { return true }
    let parsed: Double?
    if allowsFraction, numeric.contains("/") {
        let parts = numeric.split(separator: "/")
        if parts.count == 2, let numerator = Double(parts[0]), let denominator = Double(parts[1]), denominator != 0 {
            parsed = numerator / denominator
        } else {
            parsed = nil
        }
    } else {
        parsed = Double(numeric)
    }
    guard let parsed else { return false }
    return allowsNegative || parsed >= 0
}

/// All the fields FilmExif knows how to read and write.
///
/// `camera*` / `lens*` / `dateTimeOriginal` / `copyright` / `rating` /
/// `latitude` / `longitude` map to standard EXIF/TIFF/GPS/XMP-basic tags (so
/// ordinary EXIF readers pick them up), and stay flat, top-level properties
/// here since there's nothing "custom" about organizing them.
///
/// Everything FilmExif itself invented — film stock, roll tracking,
/// development chemistry, lab, and scanning workflow — has no official EXIF
/// standard to follow, so it's written into a custom XMP namespace instead
/// (AnalogExif-compatible by default). Those fields are grouped into their
/// own sub-structs (`FilmInfo`, `RollInfo`, `DevelopmentInfo`, `LabInfo`,
/// `ScanningInfo`) below, one per section of the editor UI and one per
/// `PresetCategory` — so "what fields does the Lab category have" has a
/// single answer (LabInfo's own properties) instead of being scattered
/// across a single 40-property flat struct.
///
/// `customFields` is an open-ended bag of further user-defined tags (from
/// presets or the raw editor) written into FilmExif's own custom namespace.
struct FilmMetadata: Equatable, Codable {
    // Standard EXIF/TIFF (camera body + lens)
    var cameraMake: String = ""
    var cameraModel: String = ""
    var cameraSerialNumber: String = ""
    var cameraFirmware: String = ""
    var cameraOwnerName: String = ""
    var artist: String = ""
    var copyright: String = ""
    var lensMake: String = ""
    var lensModel: String = ""
    var lensSerialNumber: String = ""
    /// EXIF LensSpecification (tag 0xA432): the lens's min/max focal length
    /// and min/max aperture, e.g. "24-70mm f/2.8" for a zoom or "50mm f/1.4"
    /// for a prime — formatted/parsed by `ExifXMPService`, which is also
    /// where the four numbers actually get written to/read from EXIF.
    var lensSpecification: String = ""
    var dateTimeOriginal: Date? = nil

    /// The standard EXIF `FileSource` tag (0xA300) — its own closed,
    /// spec-defined vocabulary ("Others"/"Film Scanner"/"Reflection Print
    /// Scanner"/"Digital Still Camera"), read from and written to that
    /// exact tag. Stored as the bare EXIF code itself ("0"..."3"), not the
    /// display label — unlike `exposureProgram`/`whiteBalance`/
    /// `meteringMode`, which still store the (English-only) label text
    /// directly. See `FieldSuggestions.fileSourceDisplayValue`/
    /// `...RawValue`, the only place code and localized label convert.
    var fileSource: String = ""
    /// Whether the original scene was captured on film at all — independent
    /// of `fileSource`, since a "Digital Still Camera" `fileSource` can
    /// still be a film photo (e.g. a digital camera used to photograph/
    /// digitize a film negative or print, sometimes called "DSLR scanning").
    /// This has no EXIF or AnalogExif/RetroExif equivalent — it's kept in
    /// FilmExif's own namespace only, stored as a bare "1"/"0" code (see
    /// `FieldSuggestions.filmPhotoDisplayValue`/`...RawValue`), not "Yes"/"No".
    var isFilmPhoto: String = ""

    // Standard XMP basic rating (0 = unrated, 1...5 stars)
    var rating: Int = 0

    /// The bare EXIF `Orientation` code ("1"..."8"), same "store the raw
    /// code, never a label" convention as `exposureProgram`/`whiteBalance`/
    /// `meteringMode` — empty means the file has no orientation tag at all
    /// (treated as "1"/normal for display and for the rotate button's
    /// cycle). Rotating never touches pixel data, only this tag — the same
    /// lossless, tag-only rotation every photo viewer/editor relies on.
    var orientation: String = ""

    // Standard EXIF GPS
    var latitude: Double? = nil
    var longitude: Double? = nil
    var altitude: Double? = nil

    // Standard EXIF photo/exposure fields
    var aperture: String = ""          // f-number, e.g. "2.8"
    var shutterSpeed: String = ""      // e.g. "1/125 s"
    var exposureBias: String = ""      // e.g. "-0.3 ev"
    var focalLength: String = ""       // e.g. "50 mm"
    /// EXIF `FocalLengthIn35mmFilm` — the focal length re-expressed as
    /// whatever it would be on a 35mm/full-frame camera, so shots on
    /// different formats (or with a crop-sensor digital camera used to
    /// photograph film) stay comparable. Hidden by default, like Metering
    /// Mode — most photos don't need it shown alongside plain Focal Length.
    var focalLengthIn35mmFormat: String = "" // e.g. "50 mm"
    // exposureProgram/whiteBalance/meteringMode are all stored as the bare
    // EXIF integer itself (as a string), not the label text — see
    // FieldSuggestions.exposureProgramDisplayValue/whiteBalanceDisplayValue/
    // meteringModeDisplayValue, the only place code and localized label
    // convert.
    var exposureProgram: String = ""   // "1"..."9"
    var whiteBalance: String = ""      // "0"/"1"
    var meteringMode: String = ""      // "1"..."6"
    /// The ISO the shot was actually exposed at (EXIF ISOSpeedRatings) —
    /// distinct from `film.iso`, the film stock's own box speed, since a
    /// photographer can push/pull a roll to a different shooting ISO.
    var shotISO: String = ""

    /// Shared free-text notes — the standalone "Notes" section's field, also
    /// offered as an optional preset field on Film/Roll presets (their own
    /// "Notes" entries point here, not at a section-specific field).
    var notes: String = ""

    // Custom XMP namespace fields, grouped by editor section / preset
    // category — see each struct's own declaration further down this file.
    var film: FilmInfo = FilmInfo()
    var roll: RollInfo = RollInfo()
    var development: DevelopmentInfo = DevelopmentInfo()
    var lab: LabInfo = LabInfo()
    var scanning: ScanningInfo = ScanningInfo()

    /// Arbitrary user-defined tags (from a preset's custom keys, or typed
    /// directly in the raw editor) that don't fit any of the fields above.
    var customFields: [String: String] = [:]

    /// Fields that are non-empty, used when applying a preset/batch edit
    /// without clobbering fields the user left blank on purpose.
    func merging(overridingWith other: FilmMetadata) -> FilmMetadata {
        var result = self
        if !other.artist.isEmpty { result.artist = other.artist }
        if !other.copyright.isEmpty { result.copyright = other.copyright }
        if !other.fileSource.isEmpty { result.fileSource = other.fileSource }
        if !other.isFilmPhoto.isEmpty { result.isFilmPhoto = other.isFilmPhoto }
        if other.rating != 0 { result.rating = other.rating }
        if !other.orientation.isEmpty { result.orientation = other.orientation }
        if let lat = other.latitude { result.latitude = lat }
        if let lon = other.longitude { result.longitude = lon }
        if let alt = other.altitude { result.altitude = alt }
        if !other.aperture.isEmpty { result.aperture = other.aperture }
        if !other.shutterSpeed.isEmpty { result.shutterSpeed = other.shutterSpeed }
        if !other.exposureBias.isEmpty { result.exposureBias = other.exposureBias }
        if !other.focalLength.isEmpty { result.focalLength = other.focalLength }
        if !other.focalLengthIn35mmFormat.isEmpty { result.focalLengthIn35mmFormat = other.focalLengthIn35mmFormat }
        if !other.exposureProgram.isEmpty { result.exposureProgram = other.exposureProgram }
        if !other.whiteBalance.isEmpty { result.whiteBalance = other.whiteBalance }
        if !other.meteringMode.isEmpty { result.meteringMode = other.meteringMode }
        if !other.shotISO.isEmpty { result.shotISO = other.shotISO }
        if !other.lensMake.isEmpty { result.lensMake = other.lensMake }
        if !other.lensModel.isEmpty { result.lensModel = other.lensModel }
        if !other.lensSerialNumber.isEmpty { result.lensSerialNumber = other.lensSerialNumber }
        if !other.lensSpecification.isEmpty { result.lensSpecification = other.lensSpecification }
        if !other.cameraMake.isEmpty { result.cameraMake = other.cameraMake }
        if !other.cameraModel.isEmpty { result.cameraModel = other.cameraModel }
        if !other.cameraSerialNumber.isEmpty { result.cameraSerialNumber = other.cameraSerialNumber }
        if !other.cameraFirmware.isEmpty { result.cameraFirmware = other.cameraFirmware }
        if !other.cameraOwnerName.isEmpty { result.cameraOwnerName = other.cameraOwnerName }
        if !other.notes.isEmpty { result.notes = other.notes }
        result.film = result.film.merging(overridingWith: other.film)
        result.roll = result.roll.merging(overridingWith: other.roll)
        result.development = result.development.merging(overridingWith: other.development)
        result.lab = result.lab.merging(overridingWith: other.lab)
        result.scanning = result.scanning.merging(overridingWith: other.scanning)
        for (key, value) in other.customFields where !value.isEmpty {
            result.customFields[key] = value
        }
        return result
    }

    /// True if any of the numeric-value fields currently holds something
    /// that isn't a valid number for it (or a negative one, where that's
    /// not allowed) — used to keep Save disabled until it's fixed.
    var hasInvalidNumericField: Bool {
        !isValidNumericFieldValue(shotISO, unit: nil, allowsFraction: false, allowsNegative: false)
            || !isValidNumericFieldValue(aperture, unit: nil, allowsFraction: false, allowsNegative: false)
            || !isValidNumericFieldValue(shutterSpeed, unit: "s", allowsFraction: true, allowsNegative: false)
            || !isValidNumericFieldValue(focalLength, unit: "mm", allowsFraction: false, allowsNegative: false)
            || !isValidNumericFieldValue(focalLengthIn35mmFormat, unit: "mm", allowsFraction: false, allowsNegative: false)
            || !isValidNumericFieldValue(exposureBias, unit: "ev", allowsFraction: false, allowsNegative: true)
            || !isValidNumericFieldValue(roll.exposureISO, unit: nil, allowsFraction: false, allowsNegative: false)
    }

    /// The next code in the rotate button's 90°-clockwise cycle
    /// (1 → 6 → 3 → 8 → 1 → …). Any code outside that cycle — a mirrored
    /// orientation (2/4/5/7), an unrecognized value, or none at all — is
    /// treated as the cycle's start, same as "1"/normal, since the rotate
    /// button only ever offers plain 90° turns, not flips.
    static func nextOrientationCode(after code: String) -> String {
        switch code {
        case "6": return "3"
        case "3": return "8"
        case "8": return "1"
        default: return "6"
        }
    }

    /// Clockwise rotation, in degrees, that `code` represents relative to
    /// "normal" — used only to preview a pending rotation on screen (the
    /// delta between the edited and original codes), never written
    /// anywhere. Mirrored/unrecognized codes fall back to 0°, matching
    /// `nextOrientationCode`'s treatment of them as the cycle's start.
    static func rotationDegrees(_ code: String) -> Double {
        switch code {
        case "6": return 90
        case "3": return 180
        case "8": return 270
        default: return 0
        }
    }

    /// Maps a changed field's name — as `PhotoItem.changedFieldNames`
    /// reports it: a plain Swift property name for a top-level field (e.g.
    /// "cameraMake"), or "group.field" for a leaf inside one of the grouped
    /// structs above (e.g. "film.maker") — to the `.id(...)` of the
    /// `FieldGroup` it lives in, in both `MetadataEditorView` and
    /// `BatchEditorView`. Used to scroll that section into view after an
    /// Undo, the same way applying a preset already does via
    /// `PresetCategory.scrollSectionID`.
    static func scrollSectionID(forFieldNamed name: String) -> String? {
        if let dotIndex = name.firstIndex(of: ".") {
            switch name[name.startIndex..<dotIndex] {
            case "film": return "section-film"
            case "roll": return "section-roll"
            case "development": return "section-development"
            case "lab": return "section-lab"
            case "scanning": return "section-scanning"
            default: return nil
            }
        }
        switch name {
        case "shotISO", "aperture", "shutterSpeed", "exposureBias", "focalLength",
             "focalLengthIn35mmFormat", "exposureProgram", "whiteBalance", "meteringMode",
             "dateTimeOriginal", "latitude", "longitude", "altitude", "rating":
            return "section-exposure"
        case "fileSource", "isFilmPhoto":
            return "section-file"
        case "artist", "copyright":
            return "section-photographer"
        case "cameraMake", "cameraModel", "cameraSerialNumber", "cameraFirmware", "cameraOwnerName",
             "lensMake", "lensModel", "lensSerialNumber", "lensSpecification":
            return "section-camera"
        case "notes":
            return "section-notes"
        default:
            return nil
        }
    }
}

/// The film stock itself — its identity, not any particular roll of it.
/// Backs the "Film" editor section and the Film preset category.
struct FilmInfo: Equatable, Codable {
    var maker: String = ""
    var name: String = ""
    /// What kind of film stock this is, e.g. Color Negative, Color
    /// Reversal — distinct from `DevelopmentInfo.process`, which is the
    /// chemistry used to develop it (a film's type never changes; how it
    /// gets processed sometimes does, e.g. cross-processing). Stored as a
    /// bare numeric code ("0"..."4"), not the label text — see
    /// `FieldSuggestions.filmTypeDisplayValue`/`...RawValue`.
    var type: String = ""
    var format: String = ""       // e.g. "35", "120", "sheet"
    /// The film stock's rated/box ISO.
    var iso: String = ""
    /// The DX code printed on 35mm film canisters, encoding speed/exposure
    /// count/latitude (e.g. the classic barcode-like pattern cameras with a
    /// DX reader use to auto-set ISO).
    var dxCode: String = ""
    /// The manufacturer's batch/lot number for this roll — the same film
    /// stock from a different batch can have slightly different
    /// characteristics.
    var batch: String = ""
    /// The number printed alongside the frame edge markings identifying
    /// which emulsion coating run produced this roll.
    var emulsionNumber: String = ""
    /// The film base material, e.g. "Acetate", "Polyester", "Estar".
    var base: String = ""
    /// A qualitative description of the film's grain, e.g. "Fine", "Coarse".
    var grain: String = ""

    func merging(overridingWith other: FilmInfo) -> FilmInfo {
        var result = self
        if !other.maker.isEmpty { result.maker = other.maker }
        if !other.name.isEmpty { result.name = other.name }
        if !other.type.isEmpty { result.type = other.type }
        if !other.format.isEmpty { result.format = other.format }
        if !other.iso.isEmpty { result.iso = other.iso }
        if !other.dxCode.isEmpty { result.dxCode = other.dxCode }
        if !other.batch.isEmpty { result.batch = other.batch }
        if !other.emulsionNumber.isEmpty { result.emulsionNumber = other.emulsionNumber }
        if !other.base.isEmpty { result.base = other.base }
        if !other.grain.isEmpty { result.grain = other.grain }
        return result
    }
}

/// One physical roll of film — its identity as a roll (not the stock it's
/// made of, which is `FilmInfo`), and where it is in its own lifecycle.
/// Backs the "Roll" editor section and the Roll preset category.
struct RollInfo: Equatable, Codable {
    var id: String = ""
    /// This photo's frame number within the roll — was called "Exposure
    /// Number" before rolls got their own section.
    var frameNumber: String = ""
    /// How many frames the roll holds in total, e.g. "36", "24", "12".
    var frameCount: String = ""
    /// The ISO the roll was actually metered/shot at — distinct from
    /// `FilmInfo.iso` (the stock's box speed) whenever the roll was pushed
    /// or pulled, e.g. a box-speed-400 film exposed at 800.
    var exposureISO: String = ""
    /// When the roll was loaded into the camera.
    var loadedDate: Date? = nil
    /// When the last frame was shot / the roll was rewound.
    var finishedDate: Date? = nil
    /// An identifier tying this roll to a particular development session,
    /// for cross-referencing against a souping log kept elsewhere.
    var developmentBatch: String = ""

    func merging(overridingWith other: RollInfo) -> RollInfo {
        var result = self
        if !other.id.isEmpty { result.id = other.id }
        if !other.frameNumber.isEmpty { result.frameNumber = other.frameNumber }
        if !other.frameCount.isEmpty { result.frameCount = other.frameCount }
        if !other.exposureISO.isEmpty { result.exposureISO = other.exposureISO }
        if let d = other.loadedDate { result.loadedDate = d }
        if let d = other.finishedDate { result.finishedDate = d }
        if !other.developmentBatch.isEmpty { result.developmentBatch = other.developmentBatch }
        return result
    }
}

/// The chemistry used to develop the roll. Backs the "Development" editor
/// section and the Development preset category.
struct DevelopmentInfo: Equatable, Codable {
    /// A bare code ("0"..."3") for one of the 4 known processes, or free
    /// text for anything else — see `FieldSuggestions.processDisplayValue`/
    /// `...RawValue`/`processCanonicalValue`. Unlike the other numeric-code
    /// fields, an unrecognized value here is real data (someone's own
    /// process name), never discarded — this field also gets mirrored into
    /// AnalogExif's namespace, which needs the actual name, not a code.
    var process: String = ""            // "0"..."3", or free text
    var developer: String = ""
    var developerMaker: String = ""
    var developerDilution: String = ""
    /// When the roll was actually developed (a calendar date/time) —
    /// distinct from `duration`, how long the development itself took.
    var developedAt: Date? = nil
    /// How long development took, e.g. "7:30" — free text rather than a
    /// `Date`, since it's an elapsed duration, not a point in time.
    var duration: String = ""
    var temperature: String = ""        // e.g. "20°C", "68°F"
    /// How many stops the roll was push/pull processed, e.g. "+1", "-1",
    /// "Normal" / "0".
    var pushPull: String = ""
    var bleach: String = ""
    var fixer: String = ""
    var stabilizer: String = ""
    /// Chemistry replenishment info, for anyone reusing a working solution
    /// across multiple development runs.
    var replenishment: String = ""
    var chemistryNotes: String = ""

    func merging(overridingWith other: DevelopmentInfo) -> DevelopmentInfo {
        var result = self
        if !other.process.isEmpty { result.process = other.process }
        if !other.developer.isEmpty { result.developer = other.developer }
        if !other.developerMaker.isEmpty { result.developerMaker = other.developerMaker }
        if !other.developerDilution.isEmpty { result.developerDilution = other.developerDilution }
        if let d = other.developedAt { result.developedAt = d }
        if !other.duration.isEmpty { result.duration = other.duration }
        if !other.temperature.isEmpty { result.temperature = other.temperature }
        if !other.pushPull.isEmpty { result.pushPull = other.pushPull }
        if !other.bleach.isEmpty { result.bleach = other.bleach }
        if !other.fixer.isEmpty { result.fixer = other.fixer }
        if !other.stabilizer.isEmpty { result.stabilizer = other.stabilizer }
        if !other.replenishment.isEmpty { result.replenishment = other.replenishment }
        if !other.chemistryNotes.isEmpty { result.chemistryNotes = other.chemistryNotes }
        return result
    }
}

/// The lab or facility a roll was developed/handled at (as opposed to
/// `DevelopmentInfo`, which is the chemistry itself — useful when someone
/// else does the developing). Backs the "Lab" editor section and the Lab
/// preset category.
struct LabInfo: Equatable, Codable {
    var name: String = ""
    var address: String = ""
    var contact: String = ""
    var labNotes: String = ""

    func merging(overridingWith other: LabInfo) -> LabInfo {
        var result = self
        if !other.name.isEmpty { result.name = other.name }
        if !other.address.isEmpty { result.address = other.address }
        if !other.contact.isEmpty { result.contact = other.contact }
        if !other.labNotes.isEmpty { result.labNotes = other.labNotes }
        return result
    }
}

/// The digitizing workflow that turned the developed roll into these image
/// files. Backs the "Scanning" editor section and the Scanning preset
/// category.
struct ScanningInfo: Equatable, Codable {
    var scannerMaker: String = ""
    var scannerModel: String = ""
    var scannerSerialNumber: String = ""
    var scannerSoftware: String = ""
    var resolution: String = ""     // e.g. "4000 dpi"
    var bitDepth: String = ""       // e.g. "16-bit"
    var colorSpace: String = ""     // e.g. "sRGB", "Adobe RGB"
    var scanType: String = ""       // e.g. "Positive", "Negative"
    /// When the scan was digitized (standard EXIF DateTimeDigitized) — was
    /// called "Digitized Time" before scanning got its own section.
    var scanDate: Date? = nil
    var dustRemoval: Bool = false
    var infraredCleaning: Bool = false  // e.g. Digital ICE
    var scanNotes: String = ""

    func merging(overridingWith other: ScanningInfo) -> ScanningInfo {
        var result = self
        if !other.scannerMaker.isEmpty { result.scannerMaker = other.scannerMaker }
        if !other.scannerModel.isEmpty { result.scannerModel = other.scannerModel }
        if !other.scannerSerialNumber.isEmpty { result.scannerSerialNumber = other.scannerSerialNumber }
        if !other.scannerSoftware.isEmpty { result.scannerSoftware = other.scannerSoftware }
        if !other.resolution.isEmpty { result.resolution = other.resolution }
        if !other.bitDepth.isEmpty { result.bitDepth = other.bitDepth }
        if !other.colorSpace.isEmpty { result.colorSpace = other.colorSpace }
        if !other.scanType.isEmpty { result.scanType = other.scanType }
        if let d = other.scanDate { result.scanDate = d }
        if other.dustRemoval { result.dustRemoval = true }
        if other.infraredCleaning { result.infraredCleaning = true }
        if !other.scanNotes.isEmpty { result.scanNotes = other.scanNotes }
        return result
    }
}
