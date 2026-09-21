import Foundation

/// How a raw tag's value round-trips between the file and a text field.
enum RawValueKind: Equatable {
    /// A single string/number, edited as free text.
    case scalar
    /// An array, edited as a comma-separated list.
    case array
    /// A nested dictionary, blob, or other type we don't flatten further —
    /// shown for reference but not editable, so it's never overwritten.
    case unsupported
}

/// Where an XMP-sourced entry lives, so an edit can be written back to the
/// exact same namespace/prefix/tag it was read from.
struct XMPLocation: Equatable {
    let namespaceURI: String
    let prefix: String
    let tagName: String
}

/// Where a raw tag group's entries should be written back to.
enum RawGroupSource: Equatable {
    /// Top-level image properties not nested under a known dictionary.
    case propertiesGeneral
    /// A known nested properties dictionary, keyed by its CFString name
    /// (e.g. "{TIFF}", "{Exif}").
    case propertiesDictionary(String)
    /// XMP tags — every entry in a `.xmp` group carries its own
    /// `xmpLocation`, since different tags in the same display group can
    /// still (in principle) span namespaces sharing a prefix.
    case xmp
}

struct RawTagEntry: Identifiable, Equatable {
    let id = UUID()
    let key: String
    var value: String
    let kind: RawValueKind
    var xmpLocation: XMPLocation? = nil

    var isEditable: Bool { kind != .unsupported }
}

struct RawTagGroup: Identifiable, Equatable {
    let id = UUID()
    /// Display name of the underlying dictionary, e.g. "TIFF", "Exif",
    /// "GPS", or "XMP: AnalogExif" for a custom namespace.
    let name: String
    let source: RawGroupSource
    var entries: [RawTagEntry]
}
