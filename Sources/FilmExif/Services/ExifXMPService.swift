import Foundation
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers

/// Reads and writes film-scan metadata using Apple's ImageIO framework only
/// (CGImageSource / CGImageDestination / CGImageMetadata). No shelling out
/// to exiftool: this keeps the app sandbox-friendly and Gatekeeper/App-Review
/// friendly, and is the officially supported way to touch both classic EXIF
/// tags and arbitrary XMP namespaces on macOS.
///
/// Design note (why this exists): there is no official EXIF standard for
/// film-scan metadata (film stock, developer, lab, scanner). Different tools
/// invent their own XMP namespace for it (e.g. the old AnalogExif desktop
/// app used "http://analogexif.sourceforge.net/ns/"), and files written by
/// one tool's namespace are invisible to a reader that only recognizes a
/// different namespace, even if the field names look similar. FilmExif reads
/// several known namespaces so it can open files written by other tools, and
/// on save always writes to FilmExif's own namespace (`ownNamespaceURI`,
/// which `readMetadata` treats as the higher-priority source on later
/// opens), mirroring each field that AnalogExif's own schema actually
/// defines into the AnalogExif namespace too (under that schema's own tag
/// name, which isn't always the same string FilmExif uses internally — see
/// `setTag` in `write(_:to:)`) so existing AnalogExif-aware tools keep
/// reading these files. Fields AnalogExif's schema never had are never
/// written under its namespace at all — inventing a tag name there that
/// nothing else recognizes wouldn't be "compatibility," just clutter.
/// Camera/lens fields are separately mirrored into the *standard* EXIF/TIFF
/// tags so any ordinary EXIF reader (Preview, Photos, exiftool, retroexif,
/// ...) can see them too.
enum ExifXMPService {

    /// The namespace FilmExif writes to. Defaults to the original AnalogExif
    /// namespace for maximum interoperability with existing tools that
    /// understand it; change here (or wire up a Preferences UI later) if you
    /// want to use a private namespace instead.
    static let writeNamespaceURI = "http://analogexif.sourceforge.net/ns/"
    static let writeNamespacePrefix = "AnalogExif"

    /// Namespace FilmExif uses for arbitrary user-defined custom fields
    /// (from a preset's custom keys, or typed directly in the raw editor).
    static let customNamespaceURI = "https://filmexif.app/ns/custom/1.0/"
    static let customNamespacePrefix = "FilmExifCustom"

    /// FilmExif's own namespace for every curated film/roll/development/lab/
    /// scanning field — written under the exact same tag names as
    /// `writeNamespaceURI` (see `setTag` in `write(_:to:)`), just under a
    /// different namespace URI/prefix. Every save mirrors a field's value
    /// into both namespaces, and `readMetadata` treats this one as the
    /// higher-priority source: a file this app has saved carries its own
    /// authoritative copy that doesn't depend on guessing which of
    /// possibly several AnalogExif-flavored schemas last wrote a field.
    static let ownNamespaceURI = "https://filmexif.app/ns/filmscan/1.0/"
    static let ownNamespacePrefix = "FilmExif"

    /// The standard Adobe XMP Basic namespace, used for `xmp:Rating`.
    static let xmpBasicNamespaceURI = "http://ns.adobe.com/xap/1.0/"
    static let xmpBasicNamespacePrefix = "xmp"

    /// The RetroExif-style namespace (see `schemas` below) — confirmed
    /// against real files to be a genuinely separate namespace URI from
    /// AnalogExif's, with several of its own different tag names for the
    /// same fields (e.g. "ProcessType" not "DevelopProcess", "FilmName" not
    /// "Film", "ScannerModel"/"ScannerMake" not "Scanner"/"ScannerMaker").
    /// Read-only: FilmExif does NOT also write a RetroExif-readable copy on
    /// save. Real RetroExif files use the exact same "AnalogExif" prefix
    /// the real AnalogExif namespace above also uses — XML can't give two
    /// different namespace URIs the same prefix in one document, and
    /// writing under any other prefix wouldn't actually match what a real
    /// RetroExif-authored file looks like, so this is only ever consulted
    /// when reading an existing file's tags, never when minting new ones.
    static let retroexifNamespaceURI = "https://retroexif.local/ns/analogexif/1.0/"

    /// Microsoft's XMP schema — the actual location AnalogExif reads/writes
    /// lens make/model from, rather than the standard EXIF LensMake/
    /// LensModel tags this app writes by default (EXIF 2.3 tags many older
    /// cameras' own files, and older tools, never populated). Read as a
    /// fallback when the standard tags are empty, and always mirrored on
    /// save so AnalogExif (and Explorer/Windows Photo tools, its origin)
    /// keep seeing lens info in the place they actually look.
    static let microsoftPhotoNamespaceURI = "http://ns.microsoft.com/photo/1.0/"
    static let microsoftPhotoNamespacePrefix = "MicrosoftPhoto"

    /// Namespaces FilmExif will try to *read* film fields from, in priority
    /// order, so files from other tools still show their data. Each entry is
    /// (namespaceURI, prefix, tag-name-map). The tag-name-map lets us cope
    /// with tools that renamed fields (e.g. "Film" vs "FilmName").
    private struct KnownSchema {
        /// The namespace URI as actually declared in the file's XMP. This is
        /// what tags are matched against — NOT the prefix, since two tools
        /// can (and, in the wild, do) use the same prefix string for two
        /// different namespace URIs.
        let namespaceURI: String
        let filmMaker: String
        let filmName: String
        let filmFormat: String
        let filmISO: String
        let exposureNumber: String
        let processType: String
        let developer: String
        let developerMaker: String
        let developerDilution: String
        let developTime: String
        let lab: String
        let labAddress: String
        let scanner: String
        let scannerMaker: String
        let scannerSoftware: String
        let lensSerialNumber: String
        let notes: String
        /// Some schemas — confirmed against a real RetroExif-style file —
        /// keep their own copy of the lens maker in a tag under this same
        /// namespace, alongside (or instead of) the standard EXIF LensMake
        /// tag. `nil` for schemas that don't (AnalogExif's real one never
        /// defined this).
        var lensMaker: String? = nil
    }

    private static let schemas: [KnownSchema] = [
        // FilmExif's own namespace, checked first (see `ownNamespaceURI`).
        // Its own tag names aren't required to match AnalogExif's — where
        // they genuinely differ (see `write(_:to:)`'s `setTag` calls), the
        // mapping only needs to be listed once, here.
        KnownSchema(
            namespaceURI: ownNamespaceURI,
            filmMaker: "FilmMaker", filmName: "FilmName", filmFormat: "FilmFormat",
            filmISO: "FilmISO", exposureNumber: "FrameNumber", processType: "DevelopProcess",
            developer: "Developer", developerMaker: "DeveloperMaker",
            developerDilution: "DeveloperDilution", developTime: "DevelopTime",
            lab: "Lab", labAddress: "LabAddress",
            scanner: "ScannerModel", scannerMaker: "ScannerMake", scannerSoftware: "ScannerSoftware",
            lensSerialNumber: "LensSerialNumber", notes: "Notes"
        ),
        // The original AnalogExif desktop app's namespace.
        KnownSchema(
            namespaceURI: "http://analogexif.sourceforge.net/ns/",
            filmMaker: "FilmMaker", filmName: "Film", filmFormat: "FilmType",
            filmISO: "FilmISO", exposureNumber: "ExposureNumber", processType: "DevelopProcess",
            developer: "Developer", developerMaker: "DeveloperMaker",
            developerDilution: "DeveloperDilution", developTime: "DevelopTime",
            lab: "Lab", labAddress: "LabAddress",
            scanner: "Scanner", scannerMaker: "ScannerMaker", scannerSoftware: "ScannerSoftware",
            lensSerialNumber: "LensSerialNumber", notes: "Notes"
        ),
        // A variant seen from some scan-tagging tools (e.g. retroexif-style).
        // Same "AnalogExif" prefix as above in the raw file, but a DIFFERENT
        // namespace URI — this is exactly the mismatch that makes two
        // AnalogExif-looking files fail to interoperate with each other.
        // Field names below are verified against a real file of this kind,
        // not guessed: `scanner`/`labAddress` in particular use different
        // tag names than AnalogExif's own schema does (`ScannerModel`/
        // `LabLocation`, not `Scanner`/`LabAddress`) — reusing the
        // AnalogExif-schema names here silently lost both fields on read
        // until this was checked against a real example.
        KnownSchema(
            namespaceURI: retroexifNamespaceURI,
            filmMaker: "FilmMaker", filmName: "FilmName", filmFormat: "FilmFormat",
            filmISO: "FilmISO", exposureNumber: "ExposureNumber", processType: "ProcessType",
            developer: "Developer", developerMaker: "DeveloperMaker",
            developerDilution: "DeveloperDilution", developTime: "DevelopTime",
            lab: "Lab", labAddress: "LabLocation",
            scanner: "ScannerModel", scannerMaker: "ScannerMake", scannerSoftware: "ScannerSoftware",
            lensSerialNumber: "LensSerialNumber", notes: "Notes",
            // Also confirmed in that same file: lens maker is duplicated
            // into its own namespace under "LensMaker", not left to the
            // standard EXIF LensMake tag alone.
            lensMaker: "LensMaker"
        )
    ]

    enum ServiceError: LocalizedError {
        case cannotOpenSource
        case cannotCreateDestination
        case cannotReadImage
        case finalizeFailed

        var errorDescription: String? {
            switch self {
            case .cannotOpenSource:
                return NSLocalizedString("Could not open the image file.", comment: "ExifXMPService error")
            case .cannotCreateDestination:
                return NSLocalizedString("Could not create an output file.", comment: "ExifXMPService error")
            case .cannotReadImage:
                return NSLocalizedString("Could not decode the image data.", comment: "ExifXMPService error")
            case .finalizeFailed:
                return NSLocalizedString("Could not write metadata back to the file.", comment: "ExifXMPService error")
            }
        }
    }

    // MARK: - Reading

    static func readMetadata(from url: URL) -> (FilmMetadata, pixelWidth: Int?, pixelHeight: Int?) {
        var meta = FilmMetadata()
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return (meta, nil, nil) }

        // Standard EXIF/TIFF tags.
        if let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
            // `Orientation` lives at the top level of the properties dict,
            // not nested under TIFF/Exif. A file with no tag at all is
            // "normal" per the EXIF spec's own default, i.e. code 1 — read
            // as that explicit code (not left empty) so a full 4-tap
            // rotate cycle lands back on the exact same string this file
            // started with, rather than "1" no longer matching an
            // originally-untagged file's "" and staying marked dirty.
            let orientationCode = props[kCGImagePropertyOrientation] as? Int ?? 1
            meta.orientation = String(orientationCode)
            if let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
                meta.cameraMake = (tiff[kCGImagePropertyTIFFMake] as? String) ?? ""
                meta.cameraModel = (tiff[kCGImagePropertyTIFFModel] as? String) ?? ""
                meta.artist = (tiff[kCGImagePropertyTIFFArtist] as? String) ?? ""
                meta.copyright = (tiff[kCGImagePropertyTIFFCopyright] as? String) ?? ""
            }
            if let gps = props[kCGImagePropertyGPSDictionary] as? [CFString: Any] {
                if let lat = gps[kCGImagePropertyGPSLatitude] as? Double {
                    let ref = gps[kCGImagePropertyGPSLatitudeRef] as? String
                    meta.latitude = (ref == "S") ? -lat : lat
                }
                if let lon = gps[kCGImagePropertyGPSLongitude] as? Double {
                    let ref = gps[kCGImagePropertyGPSLongitudeRef] as? String
                    meta.longitude = (ref == "W") ? -lon : lon
                }
                if let alt = gps[kCGImagePropertyGPSAltitude] as? Double {
                    let ref = gps[kCGImagePropertyGPSAltitudeRef] as? Int
                    meta.altitude = (ref == 1) ? -alt : alt
                }
            }
            if let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any] {
                if let original = exif[kCGImagePropertyExifDateTimeOriginal] as? String {
                    meta.dateTimeOriginal = Self.exifDateFormatter.date(from: original)
                }
                if let digitized = exif[kCGImagePropertyExifDateTimeDigitized] as? String {
                    meta.scanning.scanDate = Self.exifDateFormatter.date(from: digitized)
                }
                if let iso = exif[kCGImagePropertyExifISOSpeedRatings] as? [Int], let first = iso.first {
                    meta.shotISO = String(first)
                }
                // LensMake / LensModel / LensSerialNumber live directly under
                // Exif in the raw IFD; ImageIO exposes them via these keys.
                if let v = exif[kCGImagePropertyExifLensMake] as? String { meta.lensMake = v }
                if let v = exif[kCGImagePropertyExifLensModel] as? String { meta.lensModel = v }
                if let v = exif[kCGImagePropertyExifLensSerialNumber] as? String { meta.lensSerialNumber = v }
                if let v = exif[kCGImagePropertyExifLensSpecification] as? [Any] {
                    let numbers = v.compactMap { ($0 as? NSNumber)?.doubleValue }
                    if numbers.count == 4 {
                        meta.lensSpecification = formatLensSpecification(
                            minFocal: numbers[0], maxFocal: numbers[1],
                            minAperture: numbers[2], maxAperture: numbers[3]
                        )
                    }
                }
                // BodySerialNumber (EXIF tag 0xA431) is the standard camera
                // body counterpart to LensSerialNumber — same IFD, same
                // "string" type, added in the EXIF 2.3 spec.
                if let v = exif[kCGImagePropertyExifBodySerialNumber] as? String { meta.cameraSerialNumber = v }
                // CameraOwnerName (EXIF tag 0xA430) — same IFD and EXIF 2.3
                // vintage as BodySerialNumber, just the owner rather than
                // the body itself.
                if let v = exif[kCGImagePropertyExifCameraOwnerName] as? String { meta.cameraOwnerName = v }

                if let v = exif[kCGImagePropertyExifFNumber] as? Double { meta.aperture = formatNumber(v) }
                if let v = exif[kCGImagePropertyExifExposureTime] as? Double { meta.shutterSpeed = "\(formatExposureTime(v)) s" }
                if let v = exif[kCGImagePropertyExifExposureBiasValue] as? Double { meta.exposureBias = "\(formatSignedNumber(v)) ev" }
                if let v = exif[kCGImagePropertyExifFocalLength] as? Double { meta.focalLength = "\(formatNumber(v)) mm" }
                // Unlike FocalLength, EXIF defines this tag as a whole
                // number (SHORT), not a rational — no fractional mm.
                if let v = exif[kCGImagePropertyExifFocalLenIn35mmFilm] as? Int { meta.focalLengthIn35mmFormat = "\(v) mm" }
                // exposureProgram/meteringMode/whiteBalance are stored as
                // the bare EXIF value itself, not the label — see
                // `FieldSuggestions.exposureProgramDisplayValue`/etc.
                if let v = exif[kCGImagePropertyExifExposureProgram] as? Int,
                   v >= 1, v - 1 < FieldSuggestions.exposureProgramLabels.count {
                    meta.exposureProgram = String(v)
                }
                if let v = exif[kCGImagePropertyExifWhiteBalance] as? Int,
                   v >= 0, v < FieldSuggestions.whiteBalanceLabels.count {
                    meta.whiteBalance = String(v)
                }
                if let v = exif[kCGImagePropertyExifMeteringMode] as? Int,
                   v >= 1, v - 1 < FieldSuggestions.meteringModeLabels.count {
                    meta.meteringMode = String(v)
                }
                if let v = exif[kCGImagePropertyExifFileSource] as? Int,
                   v >= 0, v < FieldSuggestions.fileSourceLabels.count {
                    // Stored as the bare EXIF code itself, not the label —
                    // see `FieldSuggestions.fileSourceDisplayValue`.
                    meta.fileSource = String(v)
                }
            }
            // Firmware version has no slot in the main EXIF IFD — it's the
            // "Exif Aux" dictionary's tag instead (same one exiftool and
            // most camera makers use for this).
            if let aux = props[kCGImagePropertyExifAuxDictionary] as? [CFString: Any],
               let v = aux[kCGImagePropertyExifAuxFirmware] as? String {
                meta.cameraFirmware = v
            }
        }

        // XMP, trying each known schema until one has data. Looked up by
        // namespace URI directly off one enumeration pass, NOT via
        // `CGImageMetadataRegisterNamespaceForPrefix` + path queries — that
        // approach silently found nothing for every one of these fields on
        // any file this app had already saved once: registering a namespace
        // under our own made-up query prefix ("ns0") FAILS outright once
        // that namespace is already bound to a different prefix elsewhere in
        // the file's own metadata (which our own writes guarantee, since
        // they always use the "AnalogExif" prefix) — the call returns an
        // error, the prefix never actually binds, and every subsequent
        // "ns0:FieldName" path lookup quietly finds nothing. Enumerating
        // once and indexing by namespace URI (exactly how the custom-fields
        // loop below already worked, which is why custom fields never had
        // this bug) sidesteps prefix registration entirely.
        if let cgMetadata = CGImageSourceCopyMetadataAtIndex(source, 0, nil) {
            var valuesByNamespace: [String: [String: String]] = [:]
            let enumerateOptions = [kCGImageMetadataEnumerateRecursively as String: false] as CFDictionary
            CGImageMetadataEnumerateTagsUsingBlock(cgMetadata, nil, enumerateOptions) { _, tag in
                guard let namespace = CGImageMetadataTagCopyNamespace(tag) as String?,
                      let name = CGImageMetadataTagCopyName(tag) as String?,
                      let tagValue = CGImageMetadataTagCopyValue(tag) else { return true }
                valuesByNamespace[namespace, default: [:]][name] = rawStringify(tagValue)
                return true
            }

            func value(_ namespaceURI: String, _ tag: String) -> String? {
                valuesByNamespace[namespaceURI]?[tag]
            }

            // `schemas` is in priority order (FilmExif's own namespace
            // first, then the original AnalogExif namespace, then the
            // RetroExif-style variant) — each field is only taken from a
            // later schema if an earlier one didn't have it, rather than
            // letting whichever schema happens to be checked last win.
            for schema in schemas {
                let ns = schema.namespaceURI
                if meta.film.maker.isEmpty, let v = value(ns, schema.filmMaker), !v.isEmpty { meta.film.maker = v }
                if meta.film.name.isEmpty, let v = value(ns, schema.filmName), !v.isEmpty { meta.film.name = v }
                if meta.film.format.isEmpty, let v = value(ns, schema.filmFormat), !v.isEmpty { meta.film.format = v }
                if meta.film.iso.isEmpty, let v = value(ns, schema.filmISO), !v.isEmpty { meta.film.iso = v }
                if meta.roll.frameNumber.isEmpty, let v = value(ns, schema.exposureNumber), !v.isEmpty { meta.roll.frameNumber = v }
                if meta.development.process.isEmpty, let v = value(ns, schema.processType), !v.isEmpty {
                    // Our own namespace already holds the bare code (or a
                    // free-typed value); any other schema — a real
                    // AnalogExif/RetroExif file we've never touched — holds
                    // the process name as text, so convert it to a code if
                    // it's one of the 4 we know, or keep it as-is otherwise.
                    meta.development.process = (ns == ownNamespaceURI) ? v : FieldSuggestions.processCode(forCanonicalName: v)
                }
                if meta.development.developer.isEmpty, let v = value(ns, schema.developer), !v.isEmpty { meta.development.developer = v }
                if meta.development.developerMaker.isEmpty, let v = value(ns, schema.developerMaker), !v.isEmpty { meta.development.developerMaker = v }
                if meta.development.developerDilution.isEmpty, let v = value(ns, schema.developerDilution), !v.isEmpty { meta.development.developerDilution = v }
                if meta.development.developedAt == nil, let v = value(ns, schema.developTime), let date = Self.exifDateFormatter.date(from: v) {
                    meta.development.developedAt = date
                }
                if meta.lab.name.isEmpty, let v = value(ns, schema.lab), !v.isEmpty { meta.lab.name = v }
                if meta.lab.address.isEmpty, let v = value(ns, schema.labAddress), !v.isEmpty { meta.lab.address = v }
                if meta.scanning.scannerModel.isEmpty, let v = value(ns, schema.scanner), !v.isEmpty { meta.scanning.scannerModel = v }
                if meta.scanning.scannerMaker.isEmpty, let v = value(ns, schema.scannerMaker), !v.isEmpty { meta.scanning.scannerMaker = v }
                if meta.scanning.scannerSoftware.isEmpty, let v = value(ns, schema.scannerSoftware), !v.isEmpty { meta.scanning.scannerSoftware = v }
                if meta.lensSerialNumber.isEmpty, let v = value(ns, schema.lensSerialNumber), !v.isEmpty { meta.lensSerialNumber = v }
                if meta.notes.isEmpty, let v = value(ns, schema.notes), !v.isEmpty { meta.notes = v }
                if meta.lensMake.isEmpty, let tag = schema.lensMaker, let v = value(ns, tag), !v.isEmpty { meta.lensMake = v }
            }

            // FilmExif's own namespace used to call these "Scanner"/
            // "ScannerMaker" (AnalogExif's own names) before they were
            // renamed to "ScannerModel"/"ScannerMake" — a file this app
            // already saved under the old names has to keep reading
            // correctly, so this checks own-namespace-under-the-old-name as
            // one more fallback, below every schema above (which only check
            // the *current* own-namespace name, or other namespaces
            // entirely).
            if meta.scanning.scannerModel.isEmpty, let v = value(ownNamespaceURI, "Scanner"), !v.isEmpty {
                meta.scanning.scannerModel = v
            }
            if meta.scanning.scannerMaker.isEmpty, let v = value(ownNamespaceURI, "ScannerMaker"), !v.isEmpty {
                meta.scanning.scannerMaker = v
            }

            // Also check XMP-aux:Lens, some scan-tagging tools' stand-in for
            // the standard EXIF LensModel tag.
            if meta.lensModel.isEmpty, let v = value("http://ns.adobe.com/exif/1.0/aux/", "Lens"), !v.isEmpty {
                meta.lensModel = v
            }

            // AnalogExif itself reads/writes lens make/model here, not the
            // standard EXIF tags — this is the fallback that makes AnalogExif
            // files' lens info actually show up.
            if meta.lensMake.isEmpty, let v = value(microsoftPhotoNamespaceURI, "LensManufacturer"), !v.isEmpty {
                meta.lensMake = v
            }
            if meta.lensModel.isEmpty, let v = value(microsoftPhotoNamespaceURI, "LensModel"), !v.isEmpty {
                meta.lensModel = v
            }

            // These have no equivalent in AnalogExif's real schema — they're
            // FilmExif's own invention, so only FilmExif's own writes are
            // expected to have most of them. Still checked own-namespace-
            // first, then the real AnalogExif namespace (a file saved before
            // this dual-write scheme existed only has them there), then the
            // RetroExif-style namespace — confirmed against a real file to
            // define at least "PushPull" under this same tag name itself,
            // so it's worth checking for the rest too.
            func ownOrLegacy(_ tag: String) -> String? {
                value(ownNamespaceURI, tag) ?? value(writeNamespaceURI, tag) ?? value(retroexifNamespaceURI, tag)
            }
            if let v = ownOrLegacy("IsFilmPhoto"), !v.isEmpty { meta.isFilmPhoto = v }
            if let v = ownOrLegacy("FilmStockType"), !v.isEmpty { meta.film.type = v }
            if let v = ownOrLegacy("DXCode"), !v.isEmpty { meta.film.dxCode = v }
            if let v = ownOrLegacy("FilmBatch"), !v.isEmpty { meta.film.batch = v }
            if let v = ownOrLegacy("EmulsionNumber"), !v.isEmpty { meta.film.emulsionNumber = v }
            if let v = ownOrLegacy("FilmBase"), !v.isEmpty { meta.film.base = v }
            if let v = ownOrLegacy("FilmGrain"), !v.isEmpty { meta.film.grain = v }

            if let v = ownOrLegacy("RollID"), !v.isEmpty { meta.roll.id = v }
            if let v = ownOrLegacy("FrameCount"), !v.isEmpty { meta.roll.frameCount = v }
            if let v = ownOrLegacy("ExposureISO"), !v.isEmpty { meta.roll.exposureISO = v }
            if let v = ownOrLegacy("RollLoadedDate"), let date = Self.exifDateFormatter.date(from: v) {
                meta.roll.loadedDate = date
            }
            if let v = ownOrLegacy("RollFinishedDate"), let date = Self.exifDateFormatter.date(from: v) {
                meta.roll.finishedDate = date
            }
            if let v = ownOrLegacy("DevelopmentBatch"), !v.isEmpty { meta.roll.developmentBatch = v }

            if let v = ownOrLegacy("DevelopmentDuration"), !v.isEmpty { meta.development.duration = v }
            if let v = ownOrLegacy("DevelopmentTemperature"), !v.isEmpty { meta.development.temperature = v }
            if let v = ownOrLegacy("PushPull"), !v.isEmpty { meta.development.pushPull = v }
            if let v = ownOrLegacy("Bleach"), !v.isEmpty { meta.development.bleach = v }
            if let v = ownOrLegacy("Fixer"), !v.isEmpty { meta.development.fixer = v }
            if let v = ownOrLegacy("Stabilizer"), !v.isEmpty { meta.development.stabilizer = v }
            if let v = ownOrLegacy("Replenishment"), !v.isEmpty { meta.development.replenishment = v }
            if let v = ownOrLegacy("ChemistryNotes"), !v.isEmpty { meta.development.chemistryNotes = v }

            if let v = ownOrLegacy("LabContact"), !v.isEmpty { meta.lab.contact = v }
            if let v = ownOrLegacy("LabNotes"), !v.isEmpty { meta.lab.labNotes = v }

            if let v = ownOrLegacy("ScannerSerialNumber"), !v.isEmpty { meta.scanning.scannerSerialNumber = v }
            if let v = ownOrLegacy("ScanResolution"), !v.isEmpty { meta.scanning.resolution = v }
            if let v = ownOrLegacy("ScanBitDepth"), !v.isEmpty { meta.scanning.bitDepth = v }
            if let v = ownOrLegacy("ScanColorSpace"), !v.isEmpty { meta.scanning.colorSpace = v }
            if let v = ownOrLegacy("ScanType"), !v.isEmpty { meta.scanning.scanType = v }
            if let v = ownOrLegacy("DustRemoval") { meta.scanning.dustRemoval = (v == "true") }
            if let v = ownOrLegacy("InfraredCleaning") { meta.scanning.infraredCleaning = (v == "true") }
            if let v = ownOrLegacy("ScanNotes"), !v.isEmpty { meta.scanning.scanNotes = v }

            if let v = value(xmpBasicNamespaceURI, "Rating"), let rating = Int(v) {
                meta.rating = rating
            }

            // Arbitrary custom fields (from a preset's custom keys, or typed
            // directly in the raw editor).
            if let fields = valuesByNamespace[customNamespaceURI] {
                for (name, tagValue) in fields {
                    meta.customFields[name] = tagValue
                }
            }
        }

        var width: Int?
        var height: Int?
        if let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
            width = props[kCGImagePropertyPixelWidth] as? Int
            height = props[kCGImagePropertyPixelHeight] as? Int
        }
        return (meta, width, height)
    }

    // MARK: - Writing

    /// Writes `meta` into `url`, replacing the file in place (via a temp file
    /// + atomic replace so a crash mid-write never corrupts the original).
    static func write(_ meta: FilmMetadata, to url: URL) throws {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw ServiceError.cannotOpenSource
        }
        guard let type = CGImageSourceGetType(source) else {
            throw ServiceError.cannotOpenSource
        }
        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ServiceError.cannotReadImage
        }

        let tempURL = url.deletingLastPathComponent()
            .appendingPathComponent(".filmexif-tmp-\(UUID().uuidString)")
            .appendingPathExtension(url.pathExtension)

        guard let destination = CGImageDestinationCreateWithURL(tempURL as CFURL, type, 1, nil) else {
            throw ServiceError.cannotCreateDestination
        }

        // Standard EXIF/TIFF properties (camera + lens + date).
        var tiffDict: [CFString: Any] = [:]
        if !meta.cameraMake.isEmpty { tiffDict[kCGImagePropertyTIFFMake] = meta.cameraMake }
        if !meta.cameraModel.isEmpty { tiffDict[kCGImagePropertyTIFFModel] = meta.cameraModel }
        if !meta.artist.isEmpty { tiffDict[kCGImagePropertyTIFFArtist] = meta.artist }
        if !meta.copyright.isEmpty { tiffDict[kCGImagePropertyTIFFCopyright] = meta.copyright }

        var exifDict: [CFString: Any] = [:]
        if !meta.lensModel.isEmpty { exifDict[kCGImagePropertyExifLensModel] = meta.lensModel }
        if !meta.lensMake.isEmpty { exifDict[kCGImagePropertyExifLensMake] = meta.lensMake }
        if !meta.lensSerialNumber.isEmpty { exifDict[kCGImagePropertyExifLensSerialNumber] = meta.lensSerialNumber }
        if let spec = parseLensSpecification(meta.lensSpecification) {
            exifDict[kCGImagePropertyExifLensSpecification] = [spec.minFocal, spec.maxFocal, spec.minAperture, spec.maxAperture]
        }
        if !meta.cameraSerialNumber.isEmpty { exifDict[kCGImagePropertyExifBodySerialNumber] = meta.cameraSerialNumber }
        if !meta.cameraOwnerName.isEmpty { exifDict[kCGImagePropertyExifCameraOwnerName] = meta.cameraOwnerName }
        if let iso = Int(meta.shotISO) { exifDict[kCGImagePropertyExifISOSpeedRatings] = [iso] }
        if let date = meta.dateTimeOriginal {
            exifDict[kCGImagePropertyExifDateTimeOriginal] = Self.exifDateFormatter.string(from: date)
        }
        if let digitized = meta.scanning.scanDate {
            exifDict[kCGImagePropertyExifDateTimeDigitized] = Self.exifDateFormatter.string(from: digitized)
        }
        if let index = Int(meta.fileSource), FieldSuggestions.fileSourceLabels.indices.contains(index) {
            exifDict[kCGImagePropertyExifFileSource] = index
        }
        if let fNumber = Double(meta.aperture) { exifDict[kCGImagePropertyExifFNumber] = fNumber }
        if let seconds = parseExposureTime(stripUnit(meta.shutterSpeed, "s")) {
            exifDict[kCGImagePropertyExifExposureTime] = seconds
        }
        if let bias = Double(stripUnit(meta.exposureBias, "ev")) { exifDict[kCGImagePropertyExifExposureBiasValue] = bias }
        if let focal = Double(stripUnit(meta.focalLength, "mm")) { exifDict[kCGImagePropertyExifFocalLength] = focal }
        if let focal35 = Int(stripUnit(meta.focalLengthIn35mmFormat, "mm")) { exifDict[kCGImagePropertyExifFocalLenIn35mmFilm] = focal35 }
        if let value = Int(meta.exposureProgram), value >= 1, value - 1 < FieldSuggestions.exposureProgramLabels.count {
            exifDict[kCGImagePropertyExifExposureProgram] = value
        }
        if let value = Int(meta.whiteBalance), FieldSuggestions.whiteBalanceLabels.indices.contains(value) {
            exifDict[kCGImagePropertyExifWhiteBalance] = value
        }
        if let value = Int(meta.meteringMode), value >= 1, value - 1 < FieldSuggestions.meteringModeLabels.count {
            exifDict[kCGImagePropertyExifMeteringMode] = value
        }

        var gpsDict: [CFString: Any] = [:]
        if let lat = meta.latitude {
            gpsDict[kCGImagePropertyGPSLatitude] = abs(lat)
            gpsDict[kCGImagePropertyGPSLatitudeRef] = lat >= 0 ? "N" : "S"
        }
        if let lon = meta.longitude {
            gpsDict[kCGImagePropertyGPSLongitude] = abs(lon)
            gpsDict[kCGImagePropertyGPSLongitudeRef] = lon >= 0 ? "E" : "W"
        }
        if let alt = meta.altitude {
            gpsDict[kCGImagePropertyGPSAltitude] = abs(alt)
            gpsDict[kCGImagePropertyGPSAltitudeRef] = alt >= 0 ? 0 : 1
        }

        var exifAuxDict: [CFString: Any] = [:]
        if !meta.cameraFirmware.isEmpty { exifAuxDict[kCGImagePropertyExifAuxFirmware] = meta.cameraFirmware }

        // Every save decodes the image to a bitmap and re-encodes it (below),
        // since ImageIO has no way to patch EXIF/XMP into a JPEG/HEIC in
        // place — without this, that re-encode uses ImageIO's own
        // unspecified default quality, which can be substantially lower
        // than the original's (confirmed against a real 12MB JPEG scan:
        // silently dropped to 4.9MB, with a real, measurable increase in
        // per-pixel error). User-configurable in Settings → Saving (defaults
        // to 1.0, the closest a lossy re-encode can get to the original —
        // some generational loss from decoding and re-quantizing is
        // inherent to any JPEG/HEIC round-trip, even at maximum quality).
        // Harmless for lossless formats (TIFF/PNG), which ignore this key
        // entirely.
        let compressionQuality = UserDefaults.standard.object(forKey: AppSettingsKeys.jpegCompressionQuality) as? Double ?? 1.0
        var properties: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: compressionQuality]
        // Top-level, like on the read side — never nested under TIFF/Exif.
        // The pixel data above was decoded with no transform options, so
        // it's still exactly as stored; only this tag changes, which is
        // the same lossless, tag-only rotation every photo viewer relies on.
        if let orientation = Int(meta.orientation) { properties[kCGImagePropertyOrientation] = orientation }
        if !tiffDict.isEmpty { properties[kCGImagePropertyTIFFDictionary] = tiffDict }
        if !exifDict.isEmpty { properties[kCGImagePropertyExifDictionary] = exifDict }
        if !exifAuxDict.isEmpty { properties[kCGImagePropertyExifAuxDictionary] = exifAuxDict }
        if !gpsDict.isEmpty { properties[kCGImagePropertyGPSDictionary] = gpsDict }

        // Custom XMP namespace for film/development/scan fields — registers
        // BOTH the AnalogExif-compatible namespace and FilmExif's own, so
        // `setTag` below can mirror every value into both. FilmExif does NOT
        // also write a RetroExif-readable copy: doing so would need a third
        // namespace registered on this same object, and real RetroExif files
        // use the exact same "AnalogExif" prefix the real AnalogExif
        // namespace above already claims — XML can't give two different
        // namespace URIs the same prefix in one document, and forcing it
        // (tested directly) either silently merges the two namespaces'
        // tags together or gets auto-renamed by the XMP serializer to
        // something like "AnalogExif_1_", never the real "AnalogExif" a
        // RetroExif-authored file actually uses. Reading RetroExif-authored
        // files (see `schemas` and the RetroExif namespace fallbacks below)
        // has none of this problem, since it only ever inspects an existing
        // file's tags rather than needing to mint a colliding prefix itself.
        let mutableMetadata = CGImageMetadataCreateMutable()
        var nsError: Unmanaged<CFError>?
        CGImageMetadataRegisterNamespaceForPrefix(
            mutableMetadata, writeNamespaceURI as CFString, writeNamespacePrefix as CFString, &nsError
        )
        var ownNsError: Unmanaged<CFError>?
        CGImageMetadataRegisterNamespaceForPrefix(
            mutableMetadata, ownNamespaceURI as CFString, ownNamespacePrefix as CFString, &ownNsError
        )

        /// Writes `value` into FilmExif's own namespace under `own`, and —
        /// only when `analog` is non-nil — mirrors it into the AnalogExif
        /// namespace too, under `analog`'s own tag name for that field
        /// (which isn't always the same string as `own`; see the call sites
        /// below). Passing `analog: nil` is how a field AnalogExif's schema
        /// never had avoids inventing a meaningless new tag under its
        /// namespace — it's only ever written to FilmExif's own.
        func setTag(own: String, analog: String?, _ value: String) {
            guard !value.isEmpty else { return }
            CGImageMetadataSetValueWithPath(mutableMetadata, nil, "\(ownNamespacePrefix):\(own)" as CFString, value as CFTypeRef)
            if let analog {
                CGImageMetadataSetValueWithPath(mutableMetadata, nil, "\(writeNamespacePrefix):\(analog)" as CFString, value as CFTypeRef)
            }
        }
        func setDateTag(own: String, analog: String?, _ value: Date?) {
            guard let value else { return }
            setTag(own: own, analog: analog, Self.exifDateFormatter.string(from: value))
        }
        func setBoolTag(own: String, analog: String?, _ value: Bool) {
            guard value else { return }
            setTag(own: own, analog: analog, "true")
        }

        // Whether this is a film photo at all has no EXIF or AnalogExif/
        // RetroExif equivalent — own namespace only.
        setTag(own: "IsFilmPhoto", analog: nil, meta.isFilmPhoto)

        // Film
        setTag(own: "FilmMaker", analog: "FilmMaker", meta.film.maker)
        // AnalogExif's real tag for this is bare "Film" — FilmExif's own
        // namespace isn't bound by that legacy naming, so it gets a clearer
        // name of its own.
        setTag(own: "FilmName", analog: "Film", meta.film.name)
        // The film's color/B&W type has no AnalogExif equivalent at all —
        // own namespace only.
        setTag(own: "FilmStockType", analog: nil, meta.film.type)
        // AnalogExif's real tag for the format/size field is "FilmType" —
        // reusing that name literally would collide with the (unrelated)
        // color/B&W field above once both share one namespace, which is
        // exactly why FilmExif's own copy gets the clearer "FilmFormat".
        setTag(own: "FilmFormat", analog: "FilmType", meta.film.format)
        setTag(own: "FilmISO", analog: "FilmISO", meta.film.iso)
        setTag(own: "DXCode", analog: nil, meta.film.dxCode)
        setTag(own: "FilmBatch", analog: nil, meta.film.batch)
        setTag(own: "EmulsionNumber", analog: nil, meta.film.emulsionNumber)
        setTag(own: "FilmBase", analog: nil, meta.film.base)
        setTag(own: "FilmGrain", analog: nil, meta.film.grain)

        // Roll
        setTag(own: "RollID", analog: nil, meta.roll.id)
        // AnalogExif calls this "ExposureNumber"; FilmExif's own UI and
        // storage both call it "Frame Number" instead.
        setTag(own: "FrameNumber", analog: "ExposureNumber", meta.roll.frameNumber)
        setTag(own: "FrameCount", analog: nil, meta.roll.frameCount)
        setTag(own: "ExposureISO", analog: nil, meta.roll.exposureISO)
        setDateTag(own: "RollLoadedDate", analog: nil, meta.roll.loadedDate)
        setDateTag(own: "RollFinishedDate", analog: nil, meta.roll.finishedDate)
        setTag(own: "DevelopmentBatch", analog: nil, meta.roll.developmentBatch)

        // Development
        // `meta.development.process` holds a bare code (or free-typed
        // text) — only the own-namespace tag gets that raw value; the
        // AnalogExif mirror needs the actual process name (e.g. "C-41"),
        // since that's what AnalogExif itself expects there, regardless of
        // the app's current display language.
        setTag(own: "DevelopProcess", analog: nil, meta.development.process)
        let processAnalogValue = FieldSuggestions.processCanonicalValue(meta.development.process)
        if !processAnalogValue.isEmpty {
            CGImageMetadataSetValueWithPath(
                mutableMetadata, nil, "\(writeNamespacePrefix):DevelopProcess" as CFString, processAnalogValue as CFTypeRef
            )
        }
        setTag(own: "Developer", analog: "Developer", meta.development.developer)
        setTag(own: "DeveloperMaker", analog: "DeveloperMaker", meta.development.developerMaker)
        setTag(own: "DeveloperDilution", analog: "DeveloperDilution", meta.development.developerDilution)
        setDateTag(own: "DevelopTime", analog: "DevelopTime", meta.development.developedAt)
        setTag(own: "DevelopmentDuration", analog: nil, meta.development.duration)
        setTag(own: "DevelopmentTemperature", analog: nil, meta.development.temperature)
        setTag(own: "PushPull", analog: nil, meta.development.pushPull)
        setTag(own: "Bleach", analog: nil, meta.development.bleach)
        setTag(own: "Fixer", analog: nil, meta.development.fixer)
        setTag(own: "Stabilizer", analog: nil, meta.development.stabilizer)
        setTag(own: "Replenishment", analog: nil, meta.development.replenishment)
        setTag(own: "ChemistryNotes", analog: nil, meta.development.chemistryNotes)

        // Lab
        setTag(own: "Lab", analog: "Lab", meta.lab.name)
        setTag(own: "LabAddress", analog: "LabAddress", meta.lab.address)
        setTag(own: "LabContact", analog: nil, meta.lab.contact)
        setTag(own: "LabNotes", analog: nil, meta.lab.labNotes)

        // Scanning — FilmExif's own tags ("ScannerModel"/"ScannerMake")
        // differ from AnalogExif's real schema ("Scanner"/"ScannerMaker",
        // still mirrored below for that compatibility).
        setTag(own: "ScannerModel", analog: "Scanner", meta.scanning.scannerModel)
        setTag(own: "ScannerMake", analog: "ScannerMaker", meta.scanning.scannerMaker)
        setTag(own: "ScannerSerialNumber", analog: nil, meta.scanning.scannerSerialNumber)
        setTag(own: "ScannerSoftware", analog: "ScannerSoftware", meta.scanning.scannerSoftware)
        setTag(own: "ScanResolution", analog: nil, meta.scanning.resolution)
        setTag(own: "ScanBitDepth", analog: nil, meta.scanning.bitDepth)
        setTag(own: "ScanColorSpace", analog: nil, meta.scanning.colorSpace)
        setTag(own: "ScanType", analog: nil, meta.scanning.scanType)
        setBoolTag(own: "DustRemoval", analog: nil, meta.scanning.dustRemoval)
        setBoolTag(own: "InfraredCleaning", analog: nil, meta.scanning.infraredCleaning)
        setTag(own: "ScanNotes", analog: nil, meta.scanning.scanNotes)

        setTag(own: "LensSerialNumber", analog: "LensSerialNumber", meta.lensSerialNumber)
        setTag(own: "Notes", analog: "Notes", meta.notes)

        // Mirrored into the Microsoft Photo namespace too — AnalogExif (and
        // Windows Explorer/Photo tools, its origin) read lens info from
        // there, not from the standard EXIF LensMake/LensModel tags this
        // app writes above.
        if !meta.lensMake.isEmpty || !meta.lensModel.isEmpty {
            var msPhotoErr: Unmanaged<CFError>?
            CGImageMetadataRegisterNamespaceForPrefix(
                mutableMetadata, microsoftPhotoNamespaceURI as CFString, microsoftPhotoNamespacePrefix as CFString, &msPhotoErr
            )
            if !meta.lensMake.isEmpty {
                let path = "\(microsoftPhotoNamespacePrefix):LensManufacturer" as CFString
                CGImageMetadataSetValueWithPath(mutableMetadata, nil, path, meta.lensMake as CFTypeRef)
            }
            if !meta.lensModel.isEmpty {
                let path = "\(microsoftPhotoNamespacePrefix):LensModel" as CFString
                CGImageMetadataSetValueWithPath(mutableMetadata, nil, path, meta.lensModel as CFTypeRef)
            }
        }

        if meta.rating > 0 {
            var ratingErr: Unmanaged<CFError>?
            CGImageMetadataRegisterNamespaceForPrefix(
                mutableMetadata, xmpBasicNamespaceURI as CFString, xmpBasicNamespacePrefix as CFString, &ratingErr
            )
            let path = "\(xmpBasicNamespacePrefix):Rating" as CFString
            CGImageMetadataSetValueWithPath(mutableMetadata, nil, path, NSNumber(value: meta.rating))
        }

        if !meta.customFields.isEmpty {
            var customErr: Unmanaged<CFError>?
            CGImageMetadataRegisterNamespaceForPrefix(
                mutableMetadata, customNamespaceURI as CFString, customNamespacePrefix as CFString, &customErr
            )
            for (key, fieldValue) in meta.customFields where !fieldValue.isEmpty {
                let path = "\(customNamespacePrefix):\(sanitizeXMPName(key))" as CFString
                CGImageMetadataSetValueWithPath(mutableMetadata, nil, path, fieldValue as CFTypeRef)
            }
        }

        CGImageDestinationAddImageAndMetadata(
            destination, cgImage, mutableMetadata, properties as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else { throw ServiceError.finalizeFailed }

        let defaults = UserDefaults.standard
        var destinationURL = url
        if defaults.bool(forKey: AppSettingsKeys.saveToCustomFolder),
           let folderPath = defaults.string(forKey: AppSettingsKeys.customSaveFolderPath), !folderPath.isEmpty {
            destinationURL = URL(fileURLWithPath: folderPath, isDirectory: true)
                .appendingPathComponent(url.lastPathComponent)
        }

        // Only back up when actually overwriting the original in place —
        // saving a copy to a different folder leaves the original untouched.
        if destinationURL.path == url.path, defaults.bool(forKey: AppSettingsKeys.createBackupFiles) {
            let backupURL = url.appendingPathExtension("bak")
            try? FileManager.default.removeItem(at: backupURL)
            try? FileManager.default.copyItem(at: url, to: backupURL)
        }

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            _ = try FileManager.default.replaceItemAt(destinationURL, withItemAt: tempURL)
        } else {
            try FileManager.default.moveItem(at: tempURL, to: destinationURL)
        }
    }

    // MARK: - Raw metadata (read/write every tag, not just the curated fields)

    /// The dictionaries ImageIO nests properties under, and the display name
    /// each gets in the raw editor. Anything not in this list but still a
    /// nested dictionary (e.g. a proprietary maker-notes block) is shown
    /// read-only under "General" instead of being silently dropped.
    private static let rawGroupKeys: [(cfKey: CFString, displayName: String)] = [
        (kCGImagePropertyTIFFDictionary, "TIFF"),
        (kCGImagePropertyExifDictionary, "Exif"),
        (kCGImagePropertyExifAuxDictionary, "Exif Aux"),
        (kCGImagePropertyGPSDictionary, "GPS"),
        (kCGImagePropertyIPTCDictionary, "IPTC"),
        (kCGImagePropertyJFIFDictionary, "JFIF"),
        (kCGImagePropertyPNGDictionary, "PNG")
    ]

    /// Reads every tag ImageIO exposes for the image at `url` — both the
    /// standard properties (TIFF/Exif/GPS/...) and every XMP tag present,
    /// grouped by namespace so custom/non-standard fields (FilmExif's own
    /// custom fields, or another tool's) show up too — for display/editing
    /// in the raw editor.
    static func readRawMetadata(from url: URL) -> [RawTagGroup] {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return []
        }

        var groups: [RawTagGroup] = []
        var handledKeys = Set<String>()

        for (cfKey, displayName) in rawGroupKeys {
            let key = cfKey as String
            handledKeys.insert(key)
            guard let nested = props[key] as? [String: Any], !nested.isEmpty else { continue }
            let entries = nested.keys.sorted().map { rawEntry(key: $0, value: nested[$0]!) }
            groups.append(RawTagGroup(name: displayName, source: .propertiesDictionary(key), entries: entries))
        }

        let topLevelEntries = props.keys.sorted().compactMap { key -> RawTagEntry? in
            guard !handledKeys.contains(key), let value = props[key] else { return nil }
            return rawEntry(key: key, value: value)
        }
        if !topLevelEntries.isEmpty {
            groups.insert(RawTagGroup(name: "General", source: .propertiesGeneral, entries: topLevelEntries), at: 0)
        }

        // Every XMP tag, grouped by namespace — this is where custom/
        // non-standard key-value pairs (ours and other tools') show up,
        // since we enumerate rather than looking up known names.
        if let cgMetadata = CGImageSourceCopyMetadataAtIndex(source, 0, nil) {
            var prefixByNamespace: [String: String] = [:]
            var entriesByNamespace: [String: [RawTagEntry]] = [:]
            let options = [kCGImageMetadataEnumerateRecursively as String: false] as CFDictionary
            CGImageMetadataEnumerateTagsUsingBlock(cgMetadata, nil, options) { _, tag in
                guard let namespace = CGImageMetadataTagCopyNamespace(tag) as String?,
                      let prefix = CGImageMetadataTagCopyPrefix(tag) as String?,
                      let name = CGImageMetadataTagCopyName(tag) as String? else { return true }
                let value = CGImageMetadataTagCopyValue(tag).map(rawStringify) ?? ""
                prefixByNamespace[namespace] = prefix
                let entry = RawTagEntry(
                    key: name, value: value, kind: .scalar,
                    xmpLocation: XMPLocation(namespaceURI: namespace, prefix: prefix, tagName: name)
                )
                entriesByNamespace[namespace, default: []].append(entry)
                return true
            }
            let namespaces = entriesByNamespace.keys.sorted {
                (prefixByNamespace[$0] ?? $0) < (prefixByNamespace[$1] ?? $1)
            }
            for namespace in namespaces {
                let prefix = prefixByNamespace[namespace] ?? namespace
                let entries = (entriesByNamespace[namespace] ?? []).sorted { $0.key < $1.key }
                groups.append(RawTagGroup(name: "XMP: \(prefix)", source: .xmp, entries: entries))
            }
        }

        return groups
    }

    /// Writes edited raw tag groups back into `url`'s properties and XMP,
    /// leaving any tag not represented in `groups` (or marked unsupported)
    /// exactly as it was.
    static func writeRaw(_ groups: [RawTagGroup], to url: URL) throws {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw ServiceError.cannotOpenSource
        }
        guard let type = CGImageSourceGetType(source) else {
            throw ServiceError.cannotOpenSource
        }
        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ServiceError.cannotReadImage
        }
        guard var properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            throw ServiceError.cannotReadImage
        }
        let mutableMetadata: CGMutableImageMetadata =
            CGImageSourceCopyMetadataAtIndex(source, 0, nil).flatMap { CGImageMetadataCreateMutableCopy($0) }
            ?? CGImageMetadataCreateMutable()

        for group in groups {
            let editable = group.entries.filter { $0.isEditable }
            guard !editable.isEmpty else { continue }
            switch group.source {
            case .propertiesGeneral:
                for entry in editable { properties[entry.key] = parsedRawValue(entry) }
            case .propertiesDictionary(let key):
                var nested = (properties[key] as? [String: Any]) ?? [:]
                for entry in editable { nested[entry.key] = parsedRawValue(entry) }
                properties[key] = nested
            case .xmp:
                for entry in editable {
                    guard let location = entry.xmpLocation else { continue }
                    var errorRef: Unmanaged<CFError>?
                    CGImageMetadataRegisterNamespaceForPrefix(
                        mutableMetadata, location.namespaceURI as CFString, location.prefix as CFString, &errorRef
                    )
                    let path = "\(location.prefix):\(location.tagName)" as CFString
                    CGImageMetadataSetValueWithPath(mutableMetadata, nil, path, entry.value as CFTypeRef)
                }
            }
        }

        let tempURL = url.deletingLastPathComponent()
            .appendingPathComponent(".filmexif-tmp-\(UUID().uuidString)")
            .appendingPathExtension(url.pathExtension)
        guard let destination = CGImageDestinationCreateWithURL(tempURL as CFURL, type, 1, nil) else {
            throw ServiceError.cannotCreateDestination
        }

        CGImageDestinationAddImageAndMetadata(destination, cgImage, mutableMetadata, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ServiceError.finalizeFailed }

        _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL)
    }

    private static func rawEntry(key: String, value: Any) -> RawTagEntry {
        if let array = value as? [Any] {
            return RawTagEntry(key: key, value: array.map(rawStringify).joined(separator: ", "), kind: .array)
        }
        if let dict = value as? [String: Any] {
            let summary = dict.keys.sorted().joined(separator: ", ")
            return RawTagEntry(key: key, value: summary.isEmpty ? "{}" : "{ \(summary) }", kind: .unsupported)
        }
        if value is Data {
            return RawTagEntry(key: key, value: "<\((value as? Data)?.count ?? 0) bytes>", kind: .unsupported)
        }
        return RawTagEntry(key: key, value: rawStringify(value), kind: .scalar)
    }

    private static func rawStringify(_ value: Any) -> String {
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        return "\(value)"
    }

    /// Best-effort parse back to a native type ImageIO will accept: numbers
    /// stay numbers, everything else stays a string.
    private static func rawParseScalar(_ text: String) -> Any {
        if let intValue = Int(text) { return intValue }
        if let doubleValue = Double(text) { return doubleValue }
        return text
    }

    /// XMP tag paths are XML-QName-like, so a user-typed custom field name
    /// needs sanitizing (no spaces/colons/etc.) before it can be used as one.
    /// Deterministic, so round-tripping through FilmExif itself is stable.
    private static func sanitizeXMPName(_ raw: String) -> String {
        var result = String(raw.unicodeScalars.map { scalar -> Character in
            (CharacterSet.alphanumerics.contains(scalar) || scalar == "_" || scalar == "-")
                ? Character(scalar) : "_"
        })
        if result.isEmpty { result = "_" }
        if let first = result.unicodeScalars.first, CharacterSet.decimalDigits.contains(first) {
            result = "_" + result
        }
        return result
    }

    private static func parsedRawValue(_ entry: RawTagEntry) -> Any {
        switch entry.kind {
        case .array:
            return entry.value
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .map(rawParseScalar)
        case .scalar, .unsupported:
            return rawParseScalar(entry.value)
        }
    }

    // MARK: - Helpers

    /// "2.8" instead of "2.8000000000000003" / "2.0" -> "2".
    private static func formatNumber(_ value: Double) -> String {
        if value == value.rounded() && abs(value) < 1e15 {
            return String(Int(value))
        }
        return String(format: "%g", value)
    }

    private static func formatSignedNumber(_ value: Double) -> String {
        let formatted = formatNumber(value)
        return value > 0 && !formatted.hasPrefix("+") ? "+\(formatted)" : formatted
    }

    /// 0.008 -> "1/125"; 2 -> "2".
    private static func formatExposureTime(_ seconds: Double) -> String {
        guard seconds > 0 else { return formatNumber(seconds) }
        if seconds < 1 {
            let denominator = (1 / seconds).rounded()
            return "1/\(Int(denominator))"
        }
        return formatNumber(seconds)
    }

    /// "24mm-70mm f/2.8-4" style values shown in the field, e.g. a zoom's
    /// "24-70mm f/2.8-4" or a prime's "50mm f/1.4" (min == max on both
    /// sides) — the human-readable form of EXIF LensSpecification's four
    /// numbers (min/max focal length, min/max aperture).
    private static func formatLensSpecification(minFocal: Double, maxFocal: Double, minAperture: Double, maxAperture: Double) -> String {
        let focal = minFocal == maxFocal ? formatNumber(minFocal) : "\(formatNumber(minFocal))-\(formatNumber(maxFocal))"
        let aperture = minAperture == maxAperture ? formatNumber(minAperture) : "\(formatNumber(minAperture))-\(formatNumber(maxAperture))"
        return "\(focal)mm f/\(aperture)"
    }

    /// Parses a "Lens Specification" field value back into the four numbers
    /// EXIF's LensSpecification tag wants — accepts both the zoom form
    /// ("24-70mm f/2.8-4") and the prime form ("50mm f/1.4", applied to both
    /// ends of each range). `nil` for anything that doesn't parse (an empty
    /// field, or free text that was never meant to round-trip to EXIF).
    private static func parseLensSpecification(_ text: String) -> (minFocal: Double, maxFocal: Double, minAperture: Double, maxAperture: Double)? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed.components(separatedBy: "mm f/")
        guard parts.count == 2 else { return nil }

        func range(_ s: String) -> (Double, Double)? {
            let bits = s.trimmingCharacters(in: .whitespaces).components(separatedBy: "-")
            if bits.count == 1, let v = Double(bits[0].trimmingCharacters(in: .whitespaces)) { return (v, v) }
            if bits.count == 2,
               let lo = Double(bits[0].trimmingCharacters(in: .whitespaces)),
               let hi = Double(bits[1].trimmingCharacters(in: .whitespaces)) {
                return (lo, hi)
            }
            return nil
        }

        guard let focal = range(parts[0]), let aperture = range(parts[1]) else { return nil }
        return (focal.0, focal.1, aperture.0, aperture.1)
    }

    /// Strips a trailing unit suffix (e.g. "1/125 s" -> "1/125", "50 mm" ->
    /// "50") so a display value with a baked-in unit can still be parsed
    /// back to a number for EXIF. Case-insensitive; a value with no
    /// matching suffix passes through unchanged.
    private static func stripUnit(_ text: String, _ unit: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.lowercased().hasSuffix(unit.lowercased()) else { return trimmed }
        return String(trimmed.dropLast(unit.count)).trimmingCharacters(in: .whitespaces)
    }

    /// "1/125" -> 0.008; "2" -> 2.0.
    private static func parseExposureTime(_ text: String) -> Double? {
        if let slashIndex = text.firstIndex(of: "/") {
            let numeratorText = text[text.startIndex..<slashIndex]
            let denominatorText = text[text.index(after: slashIndex)...]
            guard let numerator = Double(numeratorText), let denominator = Double(denominatorText), denominator != 0 else {
                return nil
            }
            return numerator / denominator
        }
        return Double(text)
    }

    // EXIF's DateTimeOriginal/DateTimeDigitized (and our own DevelopTime
    // string) carry no timezone at all — they're a bare wall-clock
    // reading, e.g. "the camera's clock said 10:34:52". Forcing this
    // formatter to UTC made `date(from:)` treat that raw reading as UTC,
    // which then rendered shifted by the system's UTC offset wherever it
    // was displayed (e.g. 10:34:52 read from the file showing as 3:34:52
    // AM on a UTC-7 system) — pinning to `.current` instead means the
    // same wall-clock digits go in and come back out, in both directions.
    static let exifDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy:MM:dd HH:mm:ss"
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = .current
        return df
    }()

    static func isSupportedImage(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension.lowercased()) else { return false }
        return type.conforms(to: .jpeg) || type.conforms(to: .tiff) || type.conforms(to: .png)
            || type.conforms(to: .heic) || type.conforms(to: .heif)
    }
}
