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
