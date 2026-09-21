# EZ Exif

A native macOS app for editing metadata on scanned film photos — film stock,
development, lab, scanner, and camera/lens info, all in one place, without a
terminal or a separate metadata tool.

## Why this exists

EXIF has no fields for film brand, developer chemistry, or processing lab —
it was designed for digital cameras. Every film-scanning tool invents its own
XMP namespace for this, and those namespaces don't agree with each other, so
a file tagged by one tool often looks blank in another.

EZ Exif's approach:

- Keeps its own authoritative XMP namespace for every curated field, so
  re-opening a file it already saved is always exact.
- On save, mirrors each field into the original [AnalogExif](http://analogexif.sourceforge.net/)
  namespace too (under AnalogExif's own tag names, where they differ), so
  AnalogExif-aware tools can read what it saves.
- On open, also checks a RetroExif-style namespace and Microsoft's lens-info
  XMP schema, so files tagged by those tools show their data too.
- Mirrors camera/lens/capture info into standard EXIF/TIFF tags, so ordinary
  tools (Preview, Photos, exiftool) can read that part with no special support.

## Features

- **Library sidebar** — open files/folders or drag them onto the window; an
  imported folder becomes a real, disclosure-triangle tree of its subfolders
  (any depth), and a collapsed subfolder's photos aren't even read from disk
  until you expand it. Thumbnails show a dirty-state dot; right-click a photo
  or a whole folder to remove it from the list or reload it from disk.
- **Supports JPEG, TIFF, PNG, and HEIC** — reads and writes EXIF/XMP the same
  way across all four via ImageIO; a lossless format (TIFF, PNG) is
  unaffected by the JPEG/HEIC quality slider below.
- **Single-photo and batch editing** — edit one photo, or select several to
  edit shared fields across all of them at once. A field left blank across a
  batch shows the value they all already share as a placeholder.
- **73 fields across 10 groups**, each independently toggleable in
  Settings → Fields — see the [Field Reference](#field-reference) below.
- **Rotate** a photo losslessly (EXIF orientation only, no re-encoded pixels)
  from a button above the sidebar preview — undo/revert-aware like any other
  edit.
- **Presets** — reusable Photographer, Shooting Parameters, Camera, Lens,
  Film, Development, Lab, and Scanning presets, applied with one click,
  renamed/deleted by right-clicking them in Settings → Presets; ships with a
  few starter examples. Shooting Parameters covers ISO, Aperture, Shutter
  Speed, Exposure Bias, Exposure Program, White Balance, and Metering Mode
  by default, with 35mm Equivalent Focal Length addable. Shooting
  Parameters/Camera/Lens/Film presets can also be applied automatically to
  every new import (Settings → General → Defaults), each with its own
  on/off switch, only ever filling fields a file doesn't already have real
  values for.
- **Film stock database** — ~60 real film stocks auto-fill type, ISO, and
  process from Manufacturer + Name.
- **Curated manufacturer suggestions** for Camera/Lens/Scanner Make,
  researched rather than guessed.
- **Location** — click-to-drop-pin map picker with zoom buttons, a place
  search box, and a live inline preview.
- **Auto Frame Numbers** — sequential numbering across a batch, by filename
  or capture time.
- **Image save quality control** (Settings → Saving) — every save re-encodes
  the image, so this trades quality against file size for lossy formats
  (JPEG, HEIC), defaulting to the highest step, closest to the original a
  re-encode can get; TIFF/PNG ignore it since they're lossless.
- **Per-field undo**, a **raw EXIF/XMP editor** for anything the curated
  fields don't cover, optional `.bak` backups, quit protection for unsaved
  changes, and an in-app **Help menu** (guide + keyboard shortcuts).
- **Localized** in English, Spanish, and Simplified Chinese.

## Requirements

- macOS 14 (Sonoma) or later
- To build from source: the free **Xcode Command Line Tools** (no Xcode.app,
  no Apple Developer account) — `xcode-select --install`

## Building

```
git clone <this repo>
cd filmexif
Scripts/build_app.sh    # builds dist/EZ Exif.app
Scripts/make_dmg.sh     # packages dist/EZ Exif <version>.dmg
```

`build_app.sh` runs `swift build -c release` and assembles a `.app` bundle by
hand (no `.xcodeproj`), ad-hoc code-signed so it launches. `make_dmg.sh`
wraps it in a disk image with a symlink to `/Applications`.

## ⚠️ First-launch warning

This isn't signed with a paid Apple Developer ID or notarized, so Gatekeeper
will warn **"Apple could not verify 'EZ Exif' is free of malware"** the first
time it's opened after downloading. This is normal for non-App-Store Mac
software. To open it anyway:

- **Right-click the app → Open → Open** (once per machine), or
- `xattr -cr "/Applications/EZ Exif.app"` from Terminal.

Avoiding this warning entirely requires joining the Apple Developer Program
and notarizing the build — not required to use or distribute it as-is.

## ⚠️ Folder access permission

The first time you import a folder under Desktop, Documents, Downloads, or a
removable/network volume, macOS will show its own permission prompt ("EZ Exif
would like to access files in your ... folder") — this is a standard macOS
protection for those locations, independent of code signing. Click Allow, or
photos in that folder's subfolders won't be found.

The in-app **Help menu** covers the full workflow and keyboard shortcuts.

## How metadata is stored

- Camera/lens/capture/GPS info → standard EXIF/TIFF tags. Lens make/model are
  also mirrored into Microsoft's XMP schema, since some tools read lens info
  from there instead.
- Film/roll/development/lab/scanner fields → EZ Exif's own namespace
  (`https://filmexif.app/ns/filmscan/1.0/`), mirrored into AnalogExif's
  namespace (`http://analogexif.sourceforge.net/ns/`) for every field that
  schema actually defines. Fields with no AnalogExif equivalent are never
  invented there — see the [Field Reference](#field-reference) for exactly
  which fields those are.
- Arbitrary custom fields (typed directly, or via a preset) live in their own
  namespace (`https://filmexif.app/ns/custom/1.0/`).
- Full namespace URIs, tag-name mappings, and third-party schemas read on
  open: `Sources/FilmExif/Services/ExifXMPService.swift`.

Saving replaces the file's curated metadata with EZ Exif's own; it doesn't
preserve arbitrary metadata from other tools beyond what's listed here. Turn
on "Keep a .bak backup" in Settings → Saving if that matters to you.

## Field Reference

Every editable field, grouped the way the editor groups them. **Storage**
shorthand: `EXIF <Tag>` is a standard tag; `own` is EZ Exif's own namespace
only (own tag name in backticks if it differs from the model property);
`own + AnalogExif` is mirrored into AnalogExif's namespace too (its own tag
name in backticks where different). Fields marked **(code)** store a plain
number instead of their label text — see [Numeric codes](#numeric-codes)
below for what each one means.

### Basics (`FilmMetadata`, top-level)

| Field | Meaning | Property | Storage |
|---|---|---|---|
| ISO | ISO the shot was exposed at | `shotISO` | `EXIF ISOSpeedRatings` |
| Aperture | Lens f-stop | `aperture` | `EXIF FNumber` |
| Shutter Speed | Exposure time | `shutterSpeed` | `EXIF ExposureTime` |
| Exposure Bias | Exposure compensation (EV) | `exposureBias` | `EXIF ExposureBiasValue` |
| Focal Length | Lens focal length | `focalLength` | `EXIF FocalLength` |
| 35mm Equivalent Focal Length | Focal length re-expressed as its 35mm/full-frame equivalent (hidden by default) | `focalLengthIn35mmFormat` | `EXIF FocalLenIn35mmFilm` |
| Exposure Program | Camera exposure mode | `exposureProgram` | `EXIF ExposureProgram` (1–9) **(code)** |
| White Balance | Auto/Manual | `whiteBalance` | `EXIF WhiteBalance` (0/1) **(code)** |
| Metering Mode | Metering pattern | `meteringMode` | `EXIF MeteringMode` (1–6) **(code)** |
| Capture Time | Date/time taken | `dateTimeOriginal` | `EXIF DateTimeOriginal` |
| Location | GPS lat/long | `latitude`, `longitude` | `GPS GPSLatitude/GPSLongitude` |
| Altitude | GPS altitude | `altitude` | `GPS GPSAltitude` |
| Rating | 0–5 stars | `rating` | standard `xmp:Rating` |
| Orientation *(not in Settings → Fields — see below)* | Rotation, set via the sidebar preview's rotate button, not a form field | `orientation` | `EXIF/TIFF Orientation` (1/3/6/8 from the app; any 1–8 read from a file is preserved) **(code)** |

### File (`FilmMetadata`, top-level)

| Field | Meaning | Property | Storage |
|---|---|---|---|
| File Source | Film Scanner / Reflection Print Scanner / Digital Still Camera / Others | `fileSource` | `EXIF FileSource` (0–3) **(code)** |
| Is Film Photo | Was the scene shot on film at all, independent of File Source | `isFilmPhoto` | own only, `IsFilmPhoto` (0/1) **(code)** |

### Photographer & Copyright (`FilmMetadata`, top-level)

| Field | Meaning | Property | Storage |
|---|---|---|---|
| Photographer | Photographer's name | `artist` | `TIFF Artist` |
| Copyright | Copyright notice | `copyright` | `TIFF Copyright` |

### Camera & Lens (`FilmMetadata`, top-level)

| Field | Meaning | Property | Storage |
|---|---|---|---|
| Camera Make | Camera manufacturer | `cameraMake` | `TIFF Make` |
| Camera Model | Camera model | `cameraModel` | `TIFF Model` |
| Camera Serial Number | Body serial number | `cameraSerialNumber` | `EXIF BodySerialNumber` |
| Camera Firmware | Firmware version | `cameraFirmware` | `Exif Aux Firmware` |
| Camera Owner Name | Registered owner | `cameraOwnerName` | `EXIF CameraOwnerName` |
| Lens Make | Lens manufacturer | `lensMake` | `EXIF LensMake` + Microsoft XMP `LensManufacturer` |
| Lens Model | Lens model | `lensModel` | `EXIF LensModel` + Microsoft XMP `LensModel` |
| Lens Serial Number | Lens serial number | `lensSerialNumber` | `EXIF LensSerialNumber`, own + AnalogExif `LensSerialNumber` |
| Lens Specification | Focal length/aperture range | `lensSpecification` | `EXIF LensSpecification` |

### Film (`FilmInfo`, via `film`)

| Field | Meaning | Property | Storage |
|---|---|---|---|
| Manufacturer | Film stock's manufacturer | `film.maker` | own + AnalogExif `FilmMaker` |
| Name | Film stock's name | `film.name` | own `FilmName` + AnalogExif `Film` |
| Film Type | Color/process type (Color Negative, B&W, etc.) | `film.type` | own only, `FilmStockType` (0–4) **(code)** |
| Format | Physical size (35, 120, etc.) | `film.format` | own `FilmFormat` + AnalogExif `FilmType` |
| Film ISO | Box speed | `film.iso` | own + AnalogExif `FilmISO` |
| DX Code | DX barcode identifier | `film.dxCode` | own only, `DXCode` |
| Film Batch | Manufacturing batch/lot | `film.batch` | own only, `FilmBatch` |
| Emulsion Number | Emulsion run number | `film.emulsionNumber` | own only, `EmulsionNumber` |
| Base | Film base material | `film.base` | own only, `FilmBase` |
| Film Grain | Grain notes | `film.grain` | own only, `FilmGrain` |

### Roll (`RollInfo`, via `roll`)

| Field | Meaning | Property | Storage |
|---|---|---|---|
| Roll ID | Identifier for this roll | `roll.id` | own only, `RollID` |
| Frame Number | Position within the roll | `roll.frameNumber` | own `FrameNumber` + AnalogExif `ExposureNumber` |
| Total Frame Count | Frames the roll holds | `roll.frameCount` | own only, `FrameCount` |
| Exposure ISO | ISO actually shot at, if pushed/pulled from Film ISO | `roll.exposureISO` | own only, `ExposureISO` |
| Loaded Date | When loaded into the camera | `roll.loadedDate` | own only, `RollLoadedDate` |
| Finished Date | When the roll finished | `roll.finishedDate` | own only, `RollFinishedDate` |
| Development Batch | Ties the roll to a development session | `roll.developmentBatch` | own only, `DevelopmentBatch` |

### Development (`DevelopmentInfo`, via `development`)

| Field | Meaning | Property | Storage |
|---|---|---|---|
| Process | Chemical process (C-41, E-6, B&W) | `development.process` | own `DevelopProcess` (0–3, or free text) + AnalogExif `DevelopProcess` **(code)** |
| Developer | Developer chemical | `development.developer` | own + AnalogExif `Developer` |
| Developer Manufacturer | Developer's manufacturer | `development.developerMaker` | own + AnalogExif `DeveloperMaker` |
| Developer Dilution | Dilution ratio | `development.developerDilution` | own + AnalogExif `DeveloperDilution` |
| Development Time | When developed | `development.developedAt` | own + AnalogExif `DevelopTime` |
| Development Duration | How long | `development.duration` | own only, `DevelopmentDuration` |
| Development Temperature | Temperature | `development.temperature` | own only, `DevelopmentTemperature` |
| Push/Pull | Stops pushed/pulled from box speed | `development.pushPull` | own only, `PushPull` **(code)** |
| Bleach | Bleach step notes | `development.bleach` | own only, `Bleach` |
| Fixer | Fixer chemical | `development.fixer` | own only, `Fixer` |
| Stabilizer | Final-rinse chemical | `development.stabilizer` | own only, `Stabilizer` |
| Replenishment | Chemistry replenishment notes | `development.replenishment` | own only, `Replenishment` |
| Chemistry Notes | Anything else | `development.chemistryNotes` | own only, `ChemistryNotes` |

### Lab (`LabInfo`, via `lab`)

| Field | Meaning | Property | Storage |
|---|---|---|---|
| Lab Name | Lab that processed/scanned the film | `lab.name` | own + AnalogExif `Lab` |
| Lab Address | Lab's address | `lab.address` | own + AnalogExif `LabAddress` |
| Lab Contact | Lab contact info | `lab.contact` | own only, `LabContact` |
| Lab Notes | Anything else | `lab.labNotes` | own only, `LabNotes` |

### Scanning (`ScanningInfo`, via `scanning`)

| Field | Meaning | Property | Storage |
|---|---|---|---|
| Scanner Make | Scanner manufacturer | `scanning.scannerMaker` | own `ScannerMake` + AnalogExif `ScannerMaker` |
| Scanner Model | Scanner model | `scanning.scannerModel` | own `ScannerModel` + AnalogExif `Scanner` |
| Scanner Serial Number | Scanner serial number | `scanning.scannerSerialNumber` | own only, `ScannerSerialNumber` |
| Scanner Software | Software used to scan | `scanning.scannerSoftware` | own + AnalogExif `ScannerSoftware` |
| Scan Resolution | Scan resolution (dpi) | `scanning.resolution` | own only, `ScanResolution` |
| Bit Depth | Scan color bit depth | `scanning.bitDepth` | own only, `ScanBitDepth` |
| Color Space | Scan's color space | `scanning.colorSpace` | own only, `ScanColorSpace` |
| Scan Type | Positive / negative / print | `scanning.scanType` | own only, `ScanType` |
| Scan Date | When scanned | `scanning.scanDate` | `EXIF DateTimeDigitized` |
| Dust Removal | Automated dust removal applied | `scanning.dustRemoval` | own only, `DustRemoval` |
| Infrared Cleaning | Infrared defect cleaning applied | `scanning.infraredCleaning` | own only, `InfraredCleaning` |
| Scan Notes | Anything else | `scanning.scanNotes` | own only, `ScanNotes` |

### Notes (`FilmMetadata`, top-level)

| Field | Meaning | Property | Storage |
|---|---|---|---|
| Notes | Freeform notes, not tied to any other field | `notes` | own + AnalogExif `Notes` |

### Custom fields

Arbitrary key/value pairs typed directly or added via a preset —
`customFields: [String: String]` on `FilmMetadata`, stored in their own
namespace (`https://filmexif.app/ns/custom/1.0/`), separate from everything
above.

### Numeric codes

A few fields marked **(code)** above don't store their label text — they
store a plain number (as a string), language-independent, translated to
whatever the UI's current language is only for display. Here's what each
code actually means:

**File Source** (`fileSource`) — same numbering as the EXIF spec itself:

| Code | Meaning |
|---|---|
| 0 | Others |
| 1 | Film Scanner |
| 2 | Reflection Print Scanner |
| 3 | Digital Still Camera |

**Is Film Photo** (`isFilmPhoto`):

| Code | Meaning |
|---|---|
| 0 | No |
| 1 | Yes |

**Film Type** (`film.type`) — own numbering, no EXIF/AnalogExif equivalent:

| Code | Meaning |
|---|---|
| 0 | Color Negative |
| 1 | Color Reversal |
| 2 | Black & White Negative |
| 3 | Black & White Reversal |
| 4 | Instant |

**Exposure Program** (`exposureProgram`) — same numbering as the EXIF spec:

| Code | Meaning |
|---|---|
| 1 | Manual |
| 2 | Program AE |
| 3 | Aperture Priority |
| 4 | Shutter Priority |
| 5 | Creative |
| 6 | Action |
| 7 | Portrait |
| 8 | Landscape |
| 9 | Bulb |

**White Balance** (`whiteBalance`) — same numbering as the EXIF spec:

| Code | Meaning |
|---|---|
| 0 | Auto |
| 1 | Manual |

**Metering Mode** (`meteringMode`) — same numbering as the EXIF spec (0
"Unknown" and 255 "Other" exist in the spec but aren't offered as options):

| Code | Meaning |
|---|---|
| 1 | Average |
| 2 | Center-Weighted Average |
| 3 | Spot |
| 4 | Multi-Spot |
| 5 | Pattern |
| 6 | Partial |

**Push/Pull** (`development.pushPull`) isn't index-based like the others —
it's the literal stop count as a signed string, so "+2" always means "+2"
regardless of language. Only "0" gets a special display label ("Standard"),
shown centered in the menu between the negative and positive stops:
`-3, -2, -1, 0 (Standard), +1, +2, +3`.

**Process** (`development.process`) is the one exception with a twist: it
has its own numbering below, but typing anything else (e.g. a home-brew
process name) is preserved as free text rather than forced into a code —
see [How metadata is stored](#how-metadata-is-stored) for why (it's also
mirrored into AnalogExif, which needs the real name, not a number).

| Code | Meaning |
|---|---|
| 0 | C-41 |
| 1 | E-6 |
| 2 | B&W |
| 3 | ECN-2 |

**Orientation** (`orientation`) uses the real EXIF Orientation values (so a
file tagged by another tool is read correctly), but the rotate button only
ever cycles through the four that are plain 90° turns, no mirroring:

| Code | Meaning |
|---|---|
| 1 | Normal (0°) |
| 6 | Rotated 90° clockwise |
| 3 | Rotated 180° |
| 8 | Rotated 270° clockwise (90° counter-clockwise) |

## Project layout

```
Package.swift
Sources/FilmExif/
  FilmExifApp.swift          entry point, menu commands, quit confirmation
  Models/
    FilmMetadata.swift       the curated field model (FilmMetadata + sub-structs)
    PhotoItem.swift          one open photo: original/edited state, undo history
    FilmPreset.swift         built-in starter presets
    PresetCategory.swift     preset categories, fixed fields, suggestion lists
    FieldVisibility.swift    the field visibility registry + store
    FilmStockDatabase.swift  film stock -> type/ISO/process lookup
    AppSettingsKeys.swift    UserDefaults keys shared by views and services
    RawExifEntry.swift       raw-editor tag model
  Services/
    ExifXMPService.swift     ImageIO read/write, all namespace/compatibility logic
    PhotoLibrary.swift       open-photo list, import, save-all
    PresetStore.swift        saved presets persistence
    AppSettingsRouter.swift  routes Settings window to a specific tab
    AppRelauncher.swift      restart-after-language-change helper
  Views/                     SwiftUI views (editor, batch editor, presets,
                              raw editor, settings, help, map picker, etc.)
Resources/
  Info.plist                 app bundle metadata
  AppIcon.icns
  {en,es,zh-Hans}.lproj/     localized strings
Scripts/
  build_app.sh                swift build -> .app bundle
  make_dmg.sh                  .app -> .dmg
```

No third-party dependencies — everything runs on Apple's `ImageIO` framework.

## License

[PolyForm Noncommercial License 1.0.0](LICENSE) — free to use, modify, and
share for any noncommercial purpose; commercial use requires the
copyright holder's permission.
