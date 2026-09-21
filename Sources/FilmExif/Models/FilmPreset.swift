import Foundation

/// A saved preset — a named group of fields, scoped to one `PresetCategory`
/// (camera body, lens, film stock, roll, development, lab, scanning, or
/// photographer), that can be applied to one photo or a whole batch in one
/// click instead of retyping them.
struct FilmPreset: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var category: PresetCategory = .film
    var metadata: FilmMetadata

    init(id: UUID = UUID(), name: String, category: PresetCategory = .film, metadata: FilmMetadata) {
        self.id = id
        self.name = name
        self.category = category
        self.metadata = metadata
    }

    private enum CodingKeys: String, CodingKey { case id, name, category, metadata }

    // Custom decoding so presets saved before `category` existed (plain
    // JSON on disk from an earlier version of the app) still load, instead
    // of failing to decode for a missing key — and so presets saved when
    // "camera" was one combined category (before it split into Camera Body
    // and Lens) migrate to Camera Body rather than failing to decode.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        if let rawCategory = try container.decodeIfPresent(String.self, forKey: .category) {
            category = PresetCategory(rawValue: rawCategory) ?? (rawCategory == "camera" ? .cameraBody : .film)
        } else {
            category = .film
        }
        metadata = try container.decode(FilmMetadata.self, forKey: .metadata)
    }

    static let builtIns: [FilmPreset] = [
        FilmPreset(name: "Nikon FM2", category: .cameraBody, metadata: {
            var m = FilmMetadata()
            m.cameraMake = "Nikon"
            m.cameraModel = "FM2"
            return m
        }()),
        FilmPreset(name: "Nikkor 50mm f/1.4", category: .lens, metadata: {
            var m = FilmMetadata()
            m.lensMake = "Nikon"
            m.lensModel = "Nikkor 50mm f/1.4"
            return m
        }()),
        FilmPreset(name: "Kodak Ektachrome E100", category: .film, metadata: {
            var m = FilmMetadata()
            m.film.maker = "Kodak"
            m.film.name = "Ektachrome E100"
            m.film.type = "1" // Color Reversal
            m.film.format = "35"
            m.film.iso = "100"
            return m
        }()),
        FilmPreset(name: "Kodak Portra 400", category: .film, metadata: {
            var m = FilmMetadata()
            m.film.maker = "Kodak"
            m.film.name = "Portra 400"
            m.film.type = "0" // Color Negative
            m.film.format = "35"
            m.film.iso = "400"
            return m
        }()),
        FilmPreset(name: "Kodak Tri-X 400", category: .film, metadata: {
            var m = FilmMetadata()
            m.film.maker = "Kodak"
            m.film.name = "Tri-X 400"
            m.film.type = "2" // Black & White Negative
            m.film.format = "35"
            m.film.iso = "400"
            return m
        }()),
        FilmPreset(name: "Fujifilm Provia 100F", category: .film, metadata: {
            var m = FilmMetadata()
            m.film.maker = "Fujifilm"
            m.film.name = "Provia 100F"
            m.film.type = "1" // Color Reversal
            m.film.format = "35"
            m.film.iso = "100"
            return m
        }()),
        FilmPreset(name: "D-76", category: .development, metadata: {
            var m = FilmMetadata()
            m.development.process = "2" // B&W
            m.development.developer = "Kodak D-76"
            m.development.developerDilution = "1+1"
            return m
        }()),
        FilmPreset(name: "Home", category: .lab, metadata: {
            var m = FilmMetadata()
            m.lab.name = "Home"
            return m
        }()),
        FilmPreset(name: "Epson V600", category: .scanning, metadata: {
            var m = FilmMetadata()
            m.scanning.scannerMaker = "Epson"
            m.scanning.scannerModel = "V600"
            return m
        }())
    ]
}
