import Foundation

/// Datamodellen for Trening-modulen.
///
/// Hele innholdet er **valgfritt**. Det er ikke slurv: kilden utelater felt den ikke har
/// data for, og regelen i modulen er at et tomt felt skjuler kortet sitt helt — ikke at
/// det vises som «0» eller «–». Et nullstilt tall ser ut som et resultat; et skjult kort
/// ser ut som ingenting, og det er riktigere.
///
/// Alt dekodes additivt. Nye felt fra kilden kan legges til når som helst uten at appen
/// må oppdateres, og et felt som forsvinner gir ikke en dekodingsfeil som tar hele
/// skjermen med seg.
struct Treningssvar: Decodable {
    let kilde: Kilde?
    let data: Treningsdata?

    struct Kilde: Decodable {
        /// Når vi tok imot dataene.
        let mottatt: Double?
        /// Når kilden laget dem. Dette er det som vises — vår mottakstid er bare
        /// interessant hvis de to spriker.
        let generert: String?
        let revisjon: String?
    }
}

struct Treningsdata: Decodable {
    let generert: String?
    let uke: Uke?
    let rekorder: [Rekord]?
    let midje: Midje?
    let vekt: Vekt?
    let protein: Protein?
    let reisen: Reisen?
    let kontekst: Kontekst?

    // MARK: uka

    struct Uke: Decodable {
        let start: String?
        let slutt: String?
        let streakUker: Int?
        let godkjent: Bool?
        let okter: Okter?
        let styrke: Int?
        let lop: Int?
        let annet: Int?
        let snitt4Uker: Double?
        /// Hovedbudskapet, ferdig formulert av kilden. Vises **ordrett**. Appen lager
        /// aldri sin egen vurdering av hvordan uka går.
        let mangler: String?
        let sistOkt: String?

        struct Okter: Decodable { let gjort: Int?; let mal: Int? }

        enum CodingKeys: String, CodingKey {
            case start, slutt, godkjent, okter, styrke, lop, annet, mangler
            case streakUker = "streak_uker"
            case snitt4Uker = "snitt_4_uker"
            case sistOkt = "sist_okt"
        }
    }

    // MARK: styrke

    struct Rekord: Decodable, Identifiable {
        let ovelse: String?
        let kg: Double?
        let reps: Int?
        let dato: String?
        let e1rm: Double?
        /// Satt av kilden når rekorden er fersk. Appen sammenligner ikke selv mot
        /// forrige henting — da ville «ny» avhengt av når man sist åpnet appen.
        let ny: Bool?

        var id: String { "\(ovelse ?? "")-\(dato ?? "")-\(kg ?? 0)" }
    }

    // MARK: midje

    struct Midje: Decodable {
        let cm: Double?
        let dato: String?
        let historikk: [Punkt]?
    }

    // MARK: vekt

    struct Vekt: Decodable {
        let sone: Sone?
        let snitt7d: Double?
        let snitt14d: Double?
        let iSonenSiden: String?
        let dagerISonen: Int?
        let siste: Maaling?
        let siste30d: [Punkt]?

        struct Sone: Decodable { let fra: Double?; let til: Double? }
        struct Maaling: Decodable { let kg: Double?; let dato: String? }

        enum CodingKeys: String, CodingKey {
            case sone, siste
            case snitt7d = "snitt_7d"
            case snitt14d = "snitt_14d"
            case iSonenSiden = "i_sonen_siden"
            case dagerISonen = "dager_i_sonen"
            case siste30d = "siste_30d"
        }
    }

    // MARK: protein

    struct Protein: Decodable {
        let gram: Double?
        let dato: String?
        let mal: Maal?
        let snitt7d: Double?

        /// Et intervall, ikke én terskel. Over `til` er også greit — det finnes ingen
        /// øvre grense som skal se ut som en advarsel.
        struct Maal: Decodable { let fra: Double?; let til: Double? }

        enum CodingKeys: String, CodingKey {
            case gram, dato, mal
            case snitt7d = "snitt_7d"
        }
    }

    // MARK: reisen

    struct Reisen: Decodable {
        let punkter: [Punkt]?
        let merker: [Merke]?

        struct Merke: Decodable, Identifiable {
            let type: String?
            let dato: String?
            let kg: Double?
            /// Falsk = selvrapportert. Vises som anslag, stiplet, aldri som en måling.
            let malt: Bool?
            let merknad: String?

            var id: String { "\(type ?? "")-\(dato ?? "")" }
            var erAnslag: Bool { malt == false }
        }
    }

    // MARK: kontekst

    /// Bakgrunnsinformasjon, ikke en vurdering. Vises uten farger og uten tolkning —
    /// tallene står for seg selv.
    struct Kontekst: Decodable {
        let dato: String?
        let sovnTimer: Double?
        let hrv: Double?
        let hrvStatus: String?
        let hvilepuls: Double?
        let readiness: Double?
        let readinessNiva: String?
        let vo2max: Double?

        enum CodingKeys: String, CodingKey {
            case dato, hrv, hvilepuls, readiness, vo2max
            case sovnTimer = "sovn_timer"
            case hrvStatus = "hrv_status"
            case readinessNiva = "readiness_niva"
        }
    }
}

/// Et punkt på en kurve. Brukes av vekt, midje og reisen — samme form alle tre steder.
struct Punkt: Decodable, Identifiable {
    let dato: String?
    let kg: Double?
    /// Midjehistorikken måler cm, ikke kg. Begge navnene godtas, så kilden kan bruke
    /// det som er naturlig for serien.
    let cm: Double?

    var verdi: Double? { kg ?? cm }
    var id: String { "\(dato ?? "")-\(verdi ?? 0)" }
}

// MARK: - formatering

enum Trening {
    /// «76,7» — komma, og ingen unødvendige desimaler.
    static func tall(_ v: Double?, desimaler: Int = 1) -> String? {
        guard let v else { return nil }
        let f = NumberFormatter()
        f.locale = Locale(identifier: "nb_NO")
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = desimaler
        return f.string(from: NSNumber(value: v))
    }

    /// Klokkeslettet fra et ISO-tidspunkt, til «Oppdatert 14:32».
    static func klokke(_ iso: String?) -> String? {
        guard let d = dato(iso) else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "nb_NO")
        f.dateFormat = "HH:mm"
        return f.string(from: d)
    }

    static func dato(_ iso: String?) -> Date? {
        guard let iso else { return nil }
        let m = ISO8601DateFormatter()
        m.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = m.date(from: iso) { return d }
        m.formatOptions = [.withInternetDateTime]
        if let d = m.date(from: iso) { return d }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: iso)
    }

    /// «16. okt» — kort dato til merkelapper.
    static func kortDato(_ iso: String?) -> String? {
        guard let d = dato(iso) else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "nb_NO")
        f.dateFormat = "d. MMM"
        return f.string(from: d)
    }
}
