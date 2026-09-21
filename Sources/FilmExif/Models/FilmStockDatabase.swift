import Foundation

/// One real-world film stock's known attributes — used to auto-fill "Film
/// Type", "Film ISO", and "Process" once a photo's Manufacturer and Name are
/// both set to a recognized stock, so re-typing the same three values for
/// every roll of a stock you shoot often isn't necessary.
struct FilmStockInfo {
    let maker: String
    let name: String
    let type: String     // one of FieldSuggestions.filmTypeCanonicalNames
    let iso: String       // the stock's box speed
    let process: String   // one of FieldSuggestions.processCanonicalNames
}

/// A curated (not exhaustive) reference of film stocks from major
/// manufacturers, researched against current (2026) manufacturer/retailer
/// listings — current production plus a few enduring, still-often-scanned
/// discontinued classics (e.g. Fujifilm Pro 400H), so cataloging an old roll
/// still auto-fills correctly. Not a complete catalog of every variant.
enum FilmStockDatabase {
    static let all: [FilmStockInfo] = [
        // Kodak
        FilmStockInfo(maker: "Kodak", name: "Gold 200", type: "Color Negative", iso: "200", process: "C-41"),
        FilmStockInfo(maker: "Kodak", name: "ColorPlus 200", type: "Color Negative", iso: "200", process: "C-41"),
        FilmStockInfo(maker: "Kodak", name: "UltraMax 400", type: "Color Negative", iso: "400", process: "C-41"),
        FilmStockInfo(maker: "Kodak", name: "Ektar 100", type: "Color Negative", iso: "100", process: "C-41"),
        FilmStockInfo(maker: "Kodak", name: "Portra 160", type: "Color Negative", iso: "160", process: "C-41"),
        FilmStockInfo(maker: "Kodak", name: "Portra 400", type: "Color Negative", iso: "400", process: "C-41"),
        FilmStockInfo(maker: "Kodak", name: "Portra 800", type: "Color Negative", iso: "800", process: "C-41"),
        FilmStockInfo(maker: "Kodak", name: "Ektachrome E100", type: "Color Reversal", iso: "100", process: "E-6"),
        FilmStockInfo(maker: "Kodak", name: "Tri-X 400", type: "Black & White Negative", iso: "400", process: "B&W"),
        FilmStockInfo(maker: "Kodak", name: "T-Max 100", type: "Black & White Negative", iso: "100", process: "B&W"),
        FilmStockInfo(maker: "Kodak", name: "T-Max 400", type: "Black & White Negative", iso: "400", process: "B&W"),
        FilmStockInfo(maker: "Kodak", name: "T-Max P3200", type: "Black & White Negative", iso: "3200", process: "B&W"),
        FilmStockInfo(maker: "Kodak", name: "Double-X", type: "Black & White Negative", iso: "250", process: "B&W"),

        // Fujifilm
        FilmStockInfo(maker: "Fujifilm", name: "Fujicolor C200", type: "Color Negative", iso: "200", process: "C-41"),
        FilmStockInfo(maker: "Fujifilm", name: "Superia X-TRA 400", type: "Color Negative", iso: "400", process: "C-41"),
        FilmStockInfo(maker: "Fujifilm", name: "Pro 400H", type: "Color Negative", iso: "400", process: "C-41"),
        FilmStockInfo(maker: "Fujifilm", name: "Velvia 50", type: "Color Reversal", iso: "50", process: "E-6"),
        FilmStockInfo(maker: "Fujifilm", name: "Velvia 100", type: "Color Reversal", iso: "100", process: "E-6"),
        FilmStockInfo(maker: "Fujifilm", name: "Provia 100F", type: "Color Reversal", iso: "100", process: "E-6"),
        FilmStockInfo(maker: "Fujifilm", name: "Acros 100 II", type: "Black & White Negative", iso: "100", process: "B&W"),

        // Ilford
        FilmStockInfo(maker: "Ilford", name: "Pan F Plus", type: "Black & White Negative", iso: "50", process: "B&W"),
        FilmStockInfo(maker: "Ilford", name: "FP4 Plus", type: "Black & White Negative", iso: "125", process: "B&W"),
        FilmStockInfo(maker: "Ilford", name: "HP5 Plus", type: "Black & White Negative", iso: "400", process: "B&W"),
        FilmStockInfo(maker: "Ilford", name: "Delta 100", type: "Black & White Negative", iso: "100", process: "B&W"),
        FilmStockInfo(maker: "Ilford", name: "Delta 400", type: "Black & White Negative", iso: "400", process: "B&W"),
        FilmStockInfo(maker: "Ilford", name: "Delta 3200", type: "Black & White Negative", iso: "3200", process: "B&W"),
        // Chromogenic black & white — actually develops in C-41, not B&W
        // chemistry, despite being a black & white stock.
        FilmStockInfo(maker: "Ilford", name: "XP2 Super", type: "Black & White Negative", iso: "400", process: "C-41"),
        FilmStockInfo(maker: "Ilford", name: "SFX 200", type: "Black & White Negative", iso: "200", process: "B&W"),
        FilmStockInfo(maker: "Ilford", name: "Ortho Plus", type: "Black & White Negative", iso: "80", process: "B&W"),

        // Kentmere (Harman/Ilford's budget line)
        FilmStockInfo(maker: "Kentmere", name: "Kentmere 100", type: "Black & White Negative", iso: "100", process: "B&W"),
        FilmStockInfo(maker: "Kentmere", name: "Kentmere 400", type: "Black & White Negative", iso: "400", process: "B&W"),

        // CineStill
        FilmStockInfo(maker: "CineStill", name: "50D", type: "Color Negative", iso: "50", process: "C-41"),
        FilmStockInfo(maker: "CineStill", name: "400D", type: "Color Negative", iso: "400", process: "C-41"),
        FilmStockInfo(maker: "CineStill", name: "800T", type: "Color Negative", iso: "800", process: "C-41"),
        // Unlike CineStill's color stocks, BwXX is genuine black & white
        // chemistry, not C-41.
        FilmStockInfo(maker: "CineStill", name: "BwXX", type: "Black & White Negative", iso: "250", process: "B&W"),

        // Lomography
        FilmStockInfo(maker: "Lomography", name: "Color Negative 100", type: "Color Negative", iso: "100", process: "C-41"),
        FilmStockInfo(maker: "Lomography", name: "Color Negative 400", type: "Color Negative", iso: "400", process: "C-41"),
        FilmStockInfo(maker: "Lomography", name: "Color Negative 800", type: "Color Negative", iso: "800", process: "C-41"),
        FilmStockInfo(maker: "Lomography", name: "LomoChrome Purple", type: "Color Negative", iso: "400", process: "C-41"),
        FilmStockInfo(maker: "Lomography", name: "LomoChrome Turquoise", type: "Color Negative", iso: "400", process: "C-41"),
        FilmStockInfo(maker: "Lomography", name: "LomoChrome Metropolis", type: "Color Negative", iso: "400", process: "C-41"),
        FilmStockInfo(maker: "Lomography", name: "Earl Grey", type: "Black & White Negative", iso: "100", process: "B&W"),
        FilmStockInfo(maker: "Lomography", name: "Lady Grey", type: "Black & White Negative", iso: "400", process: "B&W"),
        FilmStockInfo(maker: "Lomography", name: "Potsdam Kino", type: "Black & White Negative", iso: "100", process: "B&W"),

        // Agfa / AgfaPhoto
        FilmStockInfo(maker: "Agfa", name: "APX 100", type: "Black & White Negative", iso: "100", process: "B&W"),
        FilmStockInfo(maker: "Agfa", name: "APX 400", type: "Black & White Negative", iso: "400", process: "B&W"),
        FilmStockInfo(maker: "Agfa", name: "Vista Plus 200", type: "Color Negative", iso: "200", process: "C-41"),

        // Foma
        FilmStockInfo(maker: "Foma", name: "Fomapan 100 Classic", type: "Black & White Negative", iso: "100", process: "B&W"),
        FilmStockInfo(maker: "Foma", name: "Fomapan 200 Creative", type: "Black & White Negative", iso: "200", process: "B&W"),
        FilmStockInfo(maker: "Foma", name: "Fomapan 400 Action", type: "Black & White Negative", iso: "400", process: "B&W"),
        FilmStockInfo(maker: "Foma", name: "Fomapan R100", type: "Black & White Reversal", iso: "100", process: "B&W"),
        FilmStockInfo(maker: "Foma", name: "Retropan 320 Soft", type: "Black & White Negative", iso: "320", process: "B&W"),

        // ORWO
        FilmStockInfo(maker: "ORWO", name: "UN54", type: "Black & White Negative", iso: "100", process: "B&W"),
        FilmStockInfo(maker: "ORWO", name: "N74", type: "Black & White Negative", iso: "400", process: "B&W"),
        FilmStockInfo(maker: "ORWO", name: "DN21", type: "Black & White Negative", iso: "13", process: "B&W"),
        FilmStockInfo(maker: "ORWO", name: "NC500", type: "Color Negative", iso: "500", process: "C-41"),

        // Adox
        FilmStockInfo(maker: "Adox", name: "CHS 100 II", type: "Black & White Negative", iso: "100", process: "B&W"),
        FilmStockInfo(maker: "Adox", name: "HR-50", type: "Black & White Negative", iso: "50", process: "B&W"),
        FilmStockInfo(maker: "Adox", name: "Silvermax", type: "Black & White Negative", iso: "100", process: "B&W"),
        // Scala's reversal chemistry is its own specialized process, not
        // ordinary B&W negative development or E-6.
        FilmStockInfo(maker: "Adox", name: "Scala 160", type: "Black & White Reversal", iso: "160", process: "B&W"),

        // Bergger
        FilmStockInfo(maker: "Bergger", name: "Pancro 400", type: "Black & White Negative", iso: "400", process: "B&W"),

        // Flic Film
        FilmStockInfo(maker: "Flic Film", name: "Elektra 100", type: "Color Negative", iso: "100", process: "C-41")
    ]

    /// The stock matching `maker`/`name`, compared case-insensitively so a
    /// free-typed match (not picked from the combo box) still resolves.
    static func stock(maker: String, name: String) -> FilmStockInfo? {
        all.first {
            $0.maker.caseInsensitiveCompare(maker) == .orderedSame
                && $0.name.caseInsensitiveCompare(name) == .orderedSame
        }
    }

    /// Every known stock name for `maker` — the "Name" field's combo box
    /// suggestions once a recognized Manufacturer is chosen. Empty (falling
    /// back to a plain text field) for a manufacturer not in the database.
    static func names(forMaker maker: String) -> [String] {
        all.filter { $0.maker.caseInsensitiveCompare(maker) == .orderedSame }.map { $0.name }
    }
}
