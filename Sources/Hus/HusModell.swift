import Foundation

/// Husmodellen, hentet fra backend.
///
/// Rommene lå hardkodet i nettbrettets komponenter til august. Nå eier
/// `backend/src/hus.ts` lista, og både nettbrettet og denne appen leser den derfra —
/// to lister som skal være like, driver alltid fra hverandre.
///
/// Modellen sier HVA huset består av. Hvordan det tegnes bestemmer hver klient selv:
/// nettbrettet har seks fliser i et rutenett, telefonen får en liste.
struct Husmodell: Decodable {
    let rom: [Rom]
    let grupper: Grupper
    let scener: Scener

    struct Rom: Decodable, Identifiable {
        let navn: String
        /// Lys og brytere. `switch.`-entiteter er av/på — de har ingen lysstyrke.
        let lys: [String]
        let klima: [String]
        /// Entiteten som gir romtemperaturen. Tom hvis rommet ikke har en.
        let temp: String
        /// Sant for samlerommet «Andre rom», som ikke er et fysisk rom.
        let samling: Bool?
        var id: String { navn }
    }
    struct Grupper: Decodable { let taklys1etg: String }
    struct Scener: Decodable {
        let godNattAv: [String]
        let godNattDempes: Dempes
        struct Dempes: Decodable { let entity_id: String; let brightness: Int }
    }
}

/// Øyeblikksbildet av huset — det appen faktisk viser.
///
/// Backend har allerede `/api/strom` for strømbildet; her handler det om lys og klima.
/// Verdiene hentes fra husmodellen pluss tilstandene, og appen regner ikke ut noe selv:
/// den viser hva serveren sier.
struct Husstatus: Decodable {
    let rom: [Romstatus]
    let effekt_watt: Int?
    let lys_paa: Int

    struct Romstatus: Decodable, Identifiable {
        let navn: String
        let lys_paa: Int
        let lys_totalt: Int
        /// Null når rommet ikke har temperaturmåler — ikke null grader.
        let temp: Double?
        /// `varmer`, `kjoler` eller `av`. Null når rommet ikke har klima.
        let klima: String?
        var id: String { navn }
    }
}
