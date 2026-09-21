import SwiftUI

/// The app's own in-window Help — opened from the Help menu via
/// `openWindow(id: "help")` (see `FilmExifApp`'s `Window("Help", id: "help")`
/// scene). A plain SwiftUI window rather than a real Apple Help Book: a
/// Help Book needs its own indexed `.help` bundle built with `hiutil`, which
/// isn't worth the overhead for a small, single-window utility — this gives
/// the same "there's somewhere to look this up" value without it.
///
/// Keyboard shortcuts live in their own `KeyboardShortcutsView`/window
/// (further down this file), not a section here — the Help menu has a
/// separate item for each, rather than one long combined document.
struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("EZ Exif Help")
                    .font(.largeTitle.bold())
                Text("A guide to editing metadata on scanned film photos.")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                section("Getting Started") {
                    bullet("**Open** (⌘O) a photo, or drag files or a whole folder onto the window. A dragged/imported folder's photos are grouped into a folder in the sidebar, subfolders and all — expand a subfolder to see (and load) what's inside it.")
                    bullet("Supported formats: JPEG, TIFF, PNG, and HEIC.")
                    bullet("Select one photo to edit its fields individually, or select several to edit shared fields across all of them at once.")
                    bullet("Right-click a photo (or a whole folder) in the sidebar to remove it from the list or reload it from disk — a folder's menu acts on every photo inside it, including its subfolders.")
                }

                section("Editing Fields") {
                    bullet("Fields are grouped into sections — Basics, File, Photographer & Copyright, Camera & Lens, Film, Roll, Development, Lab, Scanning, and Notes. See the Field Reference below for what each one means.")
                    bullet("Each section header has a “×” button that clears every field **currently shown** in that section — a field you've hidden is never touched.")
                    bullet("Setting **File Source** to “Digital Still Camera” disables Scanning; setting **Is Film Photo** to “No” disables Film, Roll, Development, and Lab — since those stop being relevant.")
                    bullet("An orange dot next to a field (or a photo's thumbnail) means it has unsaved changes.")
                    bullet("With several photos selected, a field left blank shows the value they all already share as a placeholder — type over it to set that value for the whole selection, or leave it as-is to keep each photo's own.")
                    bullet("The rotate button (⟳) above the sidebar preview turns the selected photo 90° at a time without touching its pixel data, the same lossless rotation any photo viewer uses — an orange dot appears next to it until saved, and it's covered by Undo/Revert like any other edit.")
                    bullet("The Location map picker has zoom buttons and a place search box, alongside the usual click-to-drop-pin and “Use Current Location.”")
                }

                section("Customizing What You See") {
                    bullet("Settings → Fields lets you show or hide any field — hiding one never changes its stored value, it just declutters the editor.")
                    bullet("Development Temperature and Aperture each have their own display-format toggle (°C/°F; plain number vs. “f/2.8”) right next to their visibility switch.")
                }

                section("Presets") {
                    bullet("Save reusable Photographer, Shooting Parameters, Camera, Lens, Film, Development, Lab, or Scanning presets from the panel on the right (toggle it with the sidebar icon in the toolbar), and apply one with a single click.")
                    bullet("Right-click a preset in Settings → Presets to rename or delete it.")
                    bullet("A Shooting Parameters preset covers ISO, Aperture, Shutter Speed, Exposure Bias, Exposure Program, White Balance, and Metering Mode by default; 35mm Equivalent Focal Length can be added to it as well.")
                    bullet("Choosing a Film preset's Manufacturer and Name from the built-in film stock database automatically fills in Film Type, Film ISO, and Process.")
                    bullet("Applying a preset skips any field whose section is currently disabled (see File Source/Is Film Photo above), the same as if you'd typed into it by hand.")
                    bullet("Settings → General → Defaults can apply a Shooting Parameters, Camera, Lens, or Film preset to every new import automatically — each one (and Photographer/Copyright) has its own on/off switch, and a preset only lands if every field it covers is still empty, so real EXIF data already in a file is never overwritten.")
                }

                section("Saving") {
                    bullet("**Save** (⌘S) writes one photo's metadata back into the file itself. **Save All** (toolbar) does the same for every photo with unsaved changes.")
                    bullet("Settings → Saving keeps a `.bak` backup of the original before overwriting it by default (toggle it off there), or can save edited copies to a separate folder instead of touching the originals.")
                    bullet("Settings → Saving also has an Image Save Quality slider (Low to High, 7 steps) — every save re-encodes the image, so a lower step trades some quality for a smaller file, while the default (High) stays as close to the original as a re-encode can get. Only matters for lossy formats (JPEG, HEIC); TIFF and PNG ignore it since they're lossless.")
                    bullet("**Undo** (⌘Z) steps back one field-edit at a time; applying a preset or using Revert counts as a single undo step.")
                }

                section("Compatibility") {
                    bullet("Camera, lens, and capture info are mirrored into standard EXIF tags any photo app can read.")
                    bullet("Film-specific fields (stock, development, lab, scanner) are also mirrored into the original AnalogExif namespace, so AnalogExif-aware tools can read them too.")
                    bullet("Opening a file already tagged by AnalogExif, a RetroExif-style tool, or Microsoft's lens-info schema is supported — their data shows up instead of appearing blank.")
                }

                fieldReferenceSection
            }
            .padding(24)
            .frame(maxWidth: 620, alignment: .leading)
        }
        .frame(width: 660, height: 560)
    }

    // MARK: - Field Reference

    /// One row per editable field, grouped exactly like the editors
    /// themselves (`FieldVisibilityRegistry`) — kept as data here (rather
    /// than pulling live from the registry) since the registry only knows
    /// field *labels*, not a human-readable explanation of what each means.
    private static let fieldReference: [(group: String, fields: [(String, String)])] = [
        ("Basics", [
            ("ISO", "The ISO the shot was actually exposed at (standard EXIF) — can differ from the film's own box speed if pushed or pulled."),
            ("Aperture", "The f-stop the lens was set to."),
            ("Shutter Speed", "The exposure time, e.g. “1/125 s”."),
            ("Exposure Bias", "Exposure compensation applied, in EV."),
            ("Focal Length", "The lens's focal length for this shot."),
            ("35mm Equivalent Focal Length", "The focal length re-expressed as its 35mm/full-frame equivalent — hidden by default."),
            ("Exposure Program", "The camera's exposure mode (Manual, Aperture Priority, etc.)."),
            ("White Balance", "Auto or Manual white balance."),
            ("Metering Mode", "How the camera measured exposure (Spot, Pattern, etc.)."),
            ("Capture Time", "The date and time the photo was taken."),
            ("Location", "GPS latitude/longitude of where the photo was taken."),
            ("Altitude", "GPS altitude, in meters."),
            ("Rating", "A 0–5 star rating for the photo.")
        ]),
        ("File", [
            ("File Source", "The standard EXIF “FileSource” tag — Film Scanner, Reflection Print Scanner, Digital Still Camera, or Others."),
            ("Is Film Photo", "Whether the original scene was captured on film at all — independent of File Source, since a digital camera can still be photographing a film print or negative.")
        ]),
        ("Photographer & Copyright", [
            ("Photographer", "The photographer's name."),
            ("Copyright", "A copyright notice for the photo.")
        ]),
        ("Camera & Lens", [
            ("Camera Make", "The camera's manufacturer."),
            ("Camera Model", "The camera's model."),
            ("Camera Serial Number", "The camera body's serial number."),
            ("Camera Firmware", "The camera's firmware version."),
            ("Camera Owner Name", "The camera's registered owner."),
            ("Lens Make", "The lens's manufacturer."),
            ("Lens Model", "The lens's model."),
            ("Lens Serial Number", "The lens's serial number."),
            ("Lens Specification", "The lens's focal length and aperture range, e.g. “24-70mm f/2.8”.")
        ]),
        ("Film", [
            ("Manufacturer", "The film stock's manufacturer, e.g. Kodak."),
            ("Name", "The film stock's name, e.g. Portra 400."),
            ("Film Type", "The film's color/process type (Color Negative, Black & White, etc.) — distinct from Format."),
            ("Format", "The film's physical size, e.g. 35, 120, 4x5."),
            ("Film ISO", "The film stock's own box speed — distinct from “ISO” in Basics, which is what it was actually shot at."),
            ("DX Code", "The film's DX barcode identifier."),
            ("Film Batch", "The manufacturing batch/lot the film came from."),
            ("Emulsion Number", "The specific emulsion run number."),
            ("Base", "The film base material, e.g. polyester, acetate."),
            ("Film Grain", "Notes on the film's grain characteristics.")
        ]),
        ("Roll", [
            ("Roll ID", "An identifier for this specific roll of film."),
            ("Frame Number", "This photo's position within the roll."),
            ("Total Frame Count", "How many frames the whole roll holds, e.g. 36."),
            ("Exposure ISO", "The ISO the roll was actually metered/shot at, if different from the film's box speed — e.g. a box-400 film shot at 800."),
            ("Loaded Date", "When the roll was loaded into the camera."),
            ("Finished Date", "When the last frame was shot or the roll was rewound."),
            ("Development Batch", "An identifier tying this roll to a specific development session.")
        ]),
        ("Development", [
            ("Process", "The chemical process used, e.g. C-41, E-6, B&W."),
            ("Developer", "The developer chemical used."),
            ("Developer Manufacturer", "The developer's manufacturer."),
            ("Developer Dilution", "The dilution ratio used, e.g. 1+1."),
            ("Development Time", "When the roll was developed."),
            ("Development Duration", "How long development took."),
            ("Development Temperature", "The temperature development was carried out at."),
            ("Push/Pull", "Stops pushed (+) or pulled (−) from box speed; “Standard” means none."),
            ("Bleach", "Notes on the bleach step, for processes that use one (e.g. C-41)."),
            ("Fixer", "The fixer chemical used."),
            ("Stabilizer", "The stabilizer/final-rinse chemical used."),
            ("Replenishment", "Notes on chemistry replenishment."),
            ("Chemistry Notes", "Any other notes about the chemistry used.")
        ]),
        ("Lab", [
            ("Lab Name", "The name of the lab that processed or scanned the film."),
            ("Lab Address", "The lab's address."),
            ("Lab Contact", "Contact info for the lab."),
            ("Lab Notes", "Any other notes about the lab.")
        ]),
        ("Scanning", [
            ("Scanner Make", "The scanner's manufacturer."),
            ("Scanner Model", "The scanner's model."),
            ("Scanner Serial Number", "The scanner's serial number."),
            ("Scanner Software", "The software used to drive the scan."),
            ("Scan Resolution", "The resolution the film was scanned at, e.g. 4000 dpi."),
            ("Bit Depth", "The color bit depth of the scan."),
            ("Color Space", "The color space the scan was saved in."),
            ("Scan Type", "Whether the scan is of a positive, negative, or print."),
            ("Scan Date", "When the scan was made."),
            ("Dust Removal", "Whether automated dust removal was applied."),
            ("Infrared Cleaning", "Whether infrared-based defect cleaning was applied."),
            ("Scan Notes", "Any other notes about the scan.")
        ]),
        ("Notes", [
            ("Notes", "Freeform notes about the photo, not tied to any other specific field.")
        ])
    ]

    private var fieldReferenceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Field Reference")
                .font(.title2.bold())
            Text("What every editable field means, grouped the same way the editor groups them.")
                .foregroundStyle(.secondary)
            ForEach(Self.fieldReference, id: \.group) { entry in
                VStack(alignment: .leading, spacing: 6) {
                    Text(LocalizedStringKey(entry.group))
                        .font(.headline)
                    ForEach(entry.fields, id: \.0) { field in
                        fieldRow(field.0, field.1)
                    }
                }
            }
        }
    }

    private func fieldRow(_ name: String, _ meaning: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(LocalizedStringKey(name))
                .fontWeight(.medium)
                .frame(width: 170, alignment: .leading)
            Text(LocalizedStringKey(meaning))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func section(_ title: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title2.bold())
            content()
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
            Text(.init(text))
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// The Help menu's second, separate entry — isolated from `HelpView` into
/// its own window/menu item rather than a section of the main guide, so
/// "what are the shortcuts" doesn't require scrolling past the rest of the
/// help content to find.
struct KeyboardShortcutsView: View {
    private static let shortcuts: [(String, String)] = [
        ("⌘O", "Open photos or a folder"),
        ("⇧⌘O", "Import a folder specifically"),
        ("⌘S", "Save the selected photo(s)"),
        ("⌘Z", "Undo the last field edit"),
        ("⌘,", "Open Settings")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Keyboard Shortcuts")
                .font(.largeTitle.bold())
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Self.shortcuts, id: \.0) { shortcut in
                    HStack {
                        Text(shortcut.0)
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 70, alignment: .leading)
                        Text(LocalizedStringKey(shortcut.1))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(24)
        .frame(width: 360)
    }
}
