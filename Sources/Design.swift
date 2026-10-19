import SwiftUI

/// Datavisualiseringspaletten fra FPL-speccen.
///
/// Het `Data` først. Det skygget for `Foundation.Data` og knekte Keychain-koden — et
/// navn som er så vanlig i standardbiblioteket, skal man ikke ta. **Egen fra husets farger med vilje** —
/// slots har fast rekkefølge og skal aldri syklet, og statusfargene er reservert.
///
/// Verdiene er mørk modus, som er VALGT og ikke en automatisk invertering.
///
/// ⚠️ Ikke validert med skillets validator — den var ikke tilgjengelig. Verdiene kommer
/// fra den dokumenterte, forhåndsvaliderte paletten. Byttes de til egne merkevarefarger,
/// må de valideres på nytt.
enum Diagramfarge {
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
