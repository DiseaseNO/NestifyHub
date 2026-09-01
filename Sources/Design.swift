import SwiftUI

/// Fargene fra smarthus-dashbordet (`smarthus/app/src/index.css`). Appen skal føles som
/// samme system som nettbrettet på kjøkkenet — ikke et fremmed produkt.
///
/// Slots har fast betydning og skal ikke syklet: gult = lys og interaktivt, rødt = varme,
/// blått = kjøling. Statusfargene er reservert og brukes aldri som en dataserie.
enum Farge {
    static let flate  = Color(hex: 0x0B0D10)  // nesten svart, ikke ren svart
    static let kort   = Color(hex: 0x14171C)
    static let kort2  = Color(hex: 0x1B1F26)
    static let strek  = Color(hex: 0x232830)  // linjer og skiller — aldri tekst
    static let svak   = Color(hex: 0x5B6270)  // svakeste LESBARE tekst
    static let dempet = Color(hex: 0x8A919C)  // etiketter
    static let tekst  = Color(hex: 0xE8EAED)
    static let aksent = Color(hex: 0xF5A524)  // varm gul: interaktivt og aktivt
    static let ok     = Color(hex: 0x4ADE80)
    static let avvik  = Color(hex: 0xF87171)
    static let varm   = Color(hex: 0xEF6F5F)  // varmer
    static let kjol   = Color(hex: 0x58A6D8)  // kjøler
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red:   Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue:  Double(hex & 0xFF) / 255)
    }
}

/// Datavisualiseringspaletten fra FPL-speccen. **Egen fra husets farger med vilje** —
/// slots har fast rekkefølge og skal aldri syklet, og statusfargene er reservert.
///
/// Verdiene er mørk modus, som er VALGT og ikke en automatisk invertering.
///
/// ⚠️ Ikke validert med skillets validator — den var ikke tilgjengelig. Verdiene kommer
/// fra den dokumenterte, forhåndsvaliderte paletten. Byttes de til egne merkevarefarger,
/// må de valideres på nytt.
enum Data {
    /// Slot 1 — ditt lag / alternativ A.
    static let serie1 = Color(hex: 0x3987E5)
    /// Slot 2 — ligasnitt / alternativ B.
    static let serie2 = Color(hex: 0xD95926)
    /// Slot 3 — tredje serie, hvis nødvendig. Hold deg til tre.
    static let serie3 = Color(hex: 0x199E70)

    static let god      = Color(hex: 0x0CA30C)
    static let varsel   = Color(hex: 0xFAB219)
    static let alvorlig = Color(hex: 0xEC835A)
    static let kritisk  = Color(hex: 0xD03B3B)

    /// Statusfarge fra kontraktens `status`-streng. Farge bærer aldri mening alene —
    /// den skal alltid følges av ikon eller etikett.
    static func status(_ s: String) -> Color {
        switch s {
        case "ok":     god
        case "varsel": varsel
        case "feil":   kritisk
        default:       Farge.svak
        }
    }
    static func statusIkon(_ s: String) -> String {
        switch s {
        case "ok":     "checkmark.circle.fill"
        case "varsel": "exclamationmark.triangle.fill"
        case "feil":   "xmark.octagon.fill"
        default:       "questionmark.circle"
        }
    }
}
