import Foundation
import Observation

/// Datamodellene speiler kontrakten fra FPL-siden. **Vi eier ikke formatet** — de gjør.
///
/// Derfor: alt som kan mangle er valgfritt, og ukjente felter ignoreres i stillhet.
/// `versjon` bumpes bare hvis felter FJERNES; nye felter kan komme uten varsel.
struct FplStatus: Decodable {
    let versjon: Int
    let generert: String
    let sesong: String
    let lag: Lag
    let runde: Runde
    let tropp: [Spiller]
    let sjekker: [Sjekk]
    let kilder: [Kilde]
    let odds_kvote_igjen: Int?
    let modell_status: String?
    let aapne_sporsmal: [String]?
    let aapne_risikoer: [String]?
    let bytte_status: String?

    struct Lag: Decodable {
        let verdi: Double, bank: Double
        let frie_bytter: Int, bytter_brukt: Int
        let poeng_totalt: Int?          // null før runden er spilt — IKKE vis som 0
    }

    struct Runde: Decodable {
        let nummer: Int
        let frist: String               // absolutt ISO-8601 — nedtellingen regnes herfra
        let timer_til_frist: Double     // ⚠️ FRYST da fila ble skrevet. Ikke vis direkte.
        let paagaaende: Int?
        let laast: Bool                 // KUN om fristen har passert
        let snitt_liga: Int?
    }

    struct Spiller: Decodable, Identifiable {
        let id: Int
        let navn: String, posisjon: String, klubb: String
        let plass: Int
        let i_xi: Bool, kaptein: Bool, vise: Bool
        let pris: Double, salgspris: Double
        let eierskap_pst: Double?
        let spilleprosent: Int?         // null = helt frisk. IKKE tolk som 0.
        let nyhet: String?
        let poeng_sesong: Int?
        let form: Double?
        let defcon_per_90: Double?
        let dodball: Dodball?
        let kamp: Kamp?

        struct Dodball: Decodable { let straffe: Int?; let corner: Int?; let frispark: Int? }
        struct Kamp: Decodable { let mot: String; let hjemme: Bool; let vansker: Int }
    }

    /// Sluttkoden ER statusfargen: 0 = ok, 1 = varsel (en vurdering, ikke en feil),
    /// alt annet = verktøyet selv feilet.
    struct Sjekk: Decodable, Identifiable {
        let navn: String, verktoy: String?
        let sluttkode: Int, status: String
        let utdata: String?
        var id: String { navn }
    }

    /// `innholdstreff` er `null` når innholdet ikke MÅLES for denne kilden — det er noe
    /// annet enn null treff, og skal ikke vises som 0. En kilde som svarer 200 og
    /// leverer tomhet er verre enn en som svarer 500.
    struct Kilde: Decodable, Identifiable {
        let navn: String
        let http: Int?
        let innholdstreff: Int?
        let status: String
        var id: String { navn }
    }
}

/// Vår innpakning. Deres payload ligger uendret under `data`; `kilde` er vår egen
/// metadata om ferskhet.
struct FplSvar: Decodable {
    struct Kilde: Decodable {
        let hentet: String
        let hentet_alder_sek: Int
        let data_alder_sek: Int?
        let feil: String?
    }
    let kilde: Kilde
    let data: FplStatus
}

/// Henter og holder FPL-tilstanden.
///
/// Kadensen følger speccen: hvert 5. minutt når det er under tre timer til frist, ellers
/// hvert 30. Backend har sitt eget hurtiglager, så dette koster ikke FPL-siden noe.
@Observable
final class FplLager {
    private(set) var svar: FplSvar?
    private(set) var feil: String?
    private(set) var henter = false

    private let api: API
    init(api: API) { self.api = api }

    /// Sekunder til frist, regnet fra det ABSOLUTTE tidspunktet.
    ///
    /// `timer_til_frist` i kontrakten er fryst i det fila skrives og forfaller ikke —
    /// på en gammel fil sto den 13 timer feil. Nedtellingen er appens viktigste tall,
    /// og den skal aldri komme derfra.
    var sekunderTilFrist: TimeInterval? {
        guard let s = svar?.data.runde.frist,
              let d = ISO8601DateFormatter().date(from: s) else { return nil }
        return d.timeIntervalSinceNow
    }

    /// Alderen på DATAENE (ikke på hentingen). Det er dette tallet brukeren skal se.
    var dataAlder: TimeInterval? {
        svar.map { TimeInterval($0.kilde.data_alder_sek ?? 0) }
    }

    func last() async {
        guard !henter else { return }
        henter = true
        defer { henter = false }
        do {
            svar = try await api.hent(FplSvar.self, "/api/fpl/status")
            feil = nil
        } catch {
            if !erAvbrutt(error) { feil = error.localizedDescription }
        }
    }

    /// Løkke som følger speccens kadens. Kanselleres når visningen forsvinner.
    func følg() async {
        while !Task.isCancelled {
            await last()
            let t = sekunderTilFrist ?? .greatestFiniteMagnitude
            let pause: Duration = (t > 0 && t < 3 * 3600) ? .seconds(300) : .seconds(1800)
            try? await Task.sleep(for: pause)
        }
    }
}

/// Menneskelig varighet: «3 d 4 t», «12 min», «nå».
func varighet(_ sek: TimeInterval, kort: Bool = false) -> String {
    let s = Int(abs(sek))
    if s >= 86400 { return kort ? "\(s / 86400) d" : "\(s / 86400) d \((s % 86400) / 3600) t" }
    if s >= 3600 { return kort ? "\(s / 3600) t" : "\(s / 3600) t \((s % 3600) / 60) min" }
    if s >= 60 { return "\(s / 60) min" }
    return "\(s) s"
}

// MARK: - Triangulering

/// Beslutningene med signalene som bærer dem.
///
/// `retning` er et FELT, ikke noe appen utleder av signalnavnet. Det er den viktigste
/// enkeltopplysningen på skjermen: et «fire bein»-argument der tre ser bakover er
/// svakere enn det høres ut.
struct FplTriangulering: Decodable {
    let versjon: Int
    let generert: String
    let runde: Int
    let beslutninger: [Beslutning]

    struct Beslutning: Decodable, Identifiable {
        let id: String
        let type: String, sporsmal: String, status: String
        let alternativer: [Alternativ]
        let signaler: [Signal]
        let konklusjon: String?
        let usikkerhet: String?
        let signalsum: Signalsum?

        struct Alternativ: Decodable {
            let nokkel: String
            let navn: String
            let anbefalt: Bool?
        }
        struct Signal: Decodable, Identifiable {
            let navn: String
            let retning: String        // "framover" | "bakover"
            let kilde: String?
            let enhet: String?
            let verdier: [String: Double]
            let peker_mot: String?     // "A" | "B" | "uavgjort"
            let vekt: String?          // "hoy" | "middels" | "lav"
            let merknad: String?
            var id: String { navn }
            var serFramover: Bool { retning == "framover" }
        }
        struct Signalsum: Decodable {
            let framover: Int?, bakover: Int?
            let peker_mot_A: Int?, peker_mot_B: Int?
        }
    }
}

// MARK: - Historikk

/// Beslutninger med utfall, kronologisk.
///
/// `premiss_holdt` (var resonnementet riktig) og `poeng_effekt` (gikk det bra) er to
/// forskjellige ting, og begge logges. En beslutning kan holde og likevel tape poeng —
/// derfor rangeres denne skjermen aldri på poeng.
struct FplHistorikk: Decodable {
    let versjon: Int
    let generert: String
    let runder: [Runde]

    struct Runde: Decodable, Identifiable {
        let runde: Int
        let poeng: Int?, snitt_liga: Int?
        let rank_total: Int?, rank_runde: Int?
        let lagverdi: Double?, bank: Double?
        let bytter: Int?, byttetrekk: Int?, benkepoeng: Int?
        let beslutninger: [Beslutning]
        var id: Int { runde }

        struct Beslutning: Decodable, Identifiable {
            let id: String
            let dato: String, type: String, hva: String
            let begrunnelse: String?
            let risiko_flagget: String?
            let utfall: Utfall?

            struct Utfall: Decodable {
                let poeng_effekt: Int?
                let premiss_holdt: Bool?
                let premiss_kommentar: String?
            }
        }
    }
}

extension FplLager {
    /// Henter trianguleringen. 404 er en gyldig tilstand — fila finnes ikke alltid.
    func hentTriangulering(_ api: API) async -> FplTriangulering? {
        try? await api.hent(Innpakket<FplTriangulering>.self, "/api/fpl/triangulering").data
    }
    func hentHistorikk(_ api: API) async -> FplHistorikk? {
        try? await api.hent(Innpakket<FplHistorikk>.self, "/api/fpl/historikk").data
    }
}

/// Backend pakker alle FPL-svar likt: deres payload under `data`, vår ferskhet i `kilde`.
struct Innpakket<T: Decodable>: Decodable {
    let kilde: FplSvar.Kilde
    let data: T
}
