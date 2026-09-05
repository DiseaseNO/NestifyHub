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
/// Verdiene kommer ferdig regnet fra serveren — appen regner ikke ut noe selv, den
/// viser hva den får.
struct Husstatus: Decodable {
    let rom: [Romstatus]
    let effekt_watt: Int?
    let lys_paa: Int
    let kr_per_kwh: Double?
    let scener: Scener?
    /// Null hvis magnetkontakten ikke svarer. Da vet vi ikke om porten er åpen, og
    /// kortet sier det i stedet for å gjette «lukket».
    let garasje: Garasje?

    struct Garasje: Decodable {
        let aapen: Bool
        let endret: String?
    }

    struct Scener: Decodable {
        let godNattAv: [String]
        let godNattDempes: Dempes
        let alt1etgAv: String
        struct Dempes: Decodable { let entity_id: String; let brightness: Int }
    }

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


/// En entitet et multikort kan vise — lys, bryter eller varme.
///
/// Lista er allerede renset for innstillinger som ikke hører hjemme i et kort, så alt
/// her er noe i huset man faktisk kan røre.
struct Husentitet: Decodable, Identifiable {
    let id: String
    let navn: String
    let domene: String
    /// Rommet entiteten hører til i husmodellen, eller null hvis den ikke er plassert.
    let rom: String?
    let paa: Bool
    /// Klima: hva den gjør nå (`heating`, `idle`, …). Null for lys og brytere.
    let handling: String?
    /// Målt temperatur der termostaten står.
    let temp: Double?
    /// Temperaturen den styrer mot.
    let maal: Double?
}
