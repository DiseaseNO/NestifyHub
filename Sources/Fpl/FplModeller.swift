import Foundation
import Observation

/// Datamodellene speiler kontrakten fra FPL-siden. **Vi eier ikke formatet** — de gjør.
///
/// Derfor: alt som kan mangle er valgfritt, og ukjente felter ignoreres i stillhet.
/// `versjon` bumpes bare hvis felter FJERNES; nye felter kan komme uten varsel.
struct FplStatus: Decodable {
    /// Kontraktsversjonen appen er bygget for. Er `versjon` høyere, mangler vi felter
    /// vi ikke vet om — da sier vi det heller enn å vise noe halvt.
    /// Kontraktversjonen appen er bygget for. Er dataene nyere, viser Nå-skjermen et
    /// varsel — den slutter ikke å virke, men noe kan mangle.
    ///
    /// v4 (02.09.2026) bumpet fordi to formendringer var gjort under v3: de to
    /// punktlistene ble objekter, og `kampforventning` ble nøklet om til klubbkode.
    /// Begge var alt håndtert her da bumpen kom — `Punkt` tåler streng og objekt, og
    /// `kampforventning` brukes ikke av appen ennå.
    static let støttetVersjon = 4

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
    let aapne_sporsmal: [Punkt]?
    let aapne_risikoer: [Punkt]?
    /// Kildens korte versjon av `modell_status`. Den lange er et arbeidsnotat.
    let modell_status_sammendrag: String?
    /// Opptelling over BEGGE listene, så appen slipper å summere selv. Bare
    /// `maa_besvares_foer_frist` er en oppfordring — resten er tilstand.
    let sporsmal_oversikt: Oversikt?

    struct Oversikt: Decodable {
        let maa_besvares_foer_frist: Int?
        let venter_paa_signal: Int?
        let staaende: Int?
        let avgjort_for_runden: Int?
        let frist: String?
        let forklaring: [String: String]?
    }

    /// Et åpent spørsmål eller en kjent risiko, i tre lengder: `tittel`, `sammendrag`,
    /// og hele notatet. Var rene strenger fram til 1. september 2026 — dekoderen tåler
    /// begge, så en app som møter gamle data ikke går tom.
    struct Punkt: Decodable, Identifiable {
        let tittel: String?
        let sammendrag: String?
        let tekst: String
        let alvor: String?
        let siden: String?
        let blokkerer: Bool?
        /// Hvorfor punktet står åpent — `runde`, `venter_paa_signal`, `staaende`,
        /// `avgjort_for_runden`. `blokkerer` er avledet av denne; kategorien sier mer.
        let kategori: String?
        /// Hva vi venter på, i klartekst. Bare for `venter_paa_signal`.
        let venter_paa: String?
        let frist: String?
        let kategori_merknad: String?

        var id: String { (tittel ?? "") + tekst }
        /// Overskriften vi viser. Kildens tittel hvis den finnes — ellers ingenting
        /// oppdiktet, bare teksten selv.
        var overskrift: String { tittel ?? tekst }

        init(from dekoder: Decoder) throws {
            if let bare = try? dekoder.singleValueContainer().decode(String.self) {
                tittel = nil; sammendrag = nil; tekst = bare
                alvor = nil; siden = nil; blokkerer = nil
                kategori = nil; venter_paa = nil; frist = nil; kategori_merknad = nil
                return
            }
            let c = try dekoder.container(keyedBy: Nøkler.self)
            tittel = try c.decodeIfPresent(String.self, forKey: .tittel)
            sammendrag = try c.decodeIfPresent(String.self, forKey: .sammendrag)
            tekst = try c.decodeIfPresent(String.self, forKey: .tekst) ?? ""
            alvor = try c.decodeIfPresent(String.self, forKey: .alvor)
            siden = try c.decodeIfPresent(String.self, forKey: .siden)
            blokkerer = try c.decodeIfPresent(Bool.self, forKey: .blokkerer)
            kategori = try c.decodeIfPresent(String.self, forKey: .kategori)
            venter_paa = try c.decodeIfPresent(String.self, forKey: .venter_paa)
            frist = try c.decodeIfPresent(String.self, forKey: .frist)
            kategori_merknad = try c.decodeIfPresent(String.self, forKey: .kategori_merknad)
        }
        private enum Nøkler: String, CodingKey {
            case tittel, sammendrag, tekst, alvor, siden, blokkerer
            case kategori, venter_paa, frist, kategori_merknad
        }
    }
    /// Hva som er endret siden forrige eksport. Tom liste betyr «ingenting nytt» —
    /// det er forskjellen på en app og et dokument.
    let endret: [Endring]?
    /// De siste 40 endringene, for en tidslinje. Ikke tatt i bruk ennå.
    let endret_historikk: [Endring]?

    struct Endring: Decodable, Identifiable {
        let felt: String?
        let fra: String?
        let til: String?
        let beskrivelse: String?
        var id: String { (felt ?? "") + (fra ?? "") + (til ?? "") + (beskrivelse ?? "") }
    }

    /// Kildens egen ordbok: hva verdiene og tallene deres betyr, med deres ord.
    ///
    /// Vi oversetter ikke lenger domenet selv — kilden tar beslutningene og er den eneste
    /// som vet hva `utfort` eller `xp_fplform` faktisk innebærer. Mangler oppslaget, viser
    /// appen ingen forklaring framfor en vi har funnet på.
    let ordliste: [String: Kildeord]?

    /// Tåler både `{"tittel": …, "hva": …}` og bare en streng — da blir nøkkelen tittel.
    struct Kildeord: Decodable {
        let tittel: String?
        let hva: String

        init(from dekoder: Decoder) throws {
            if let tekst = try? dekoder.singleValueContainer().decode(String.self) {
                tittel = nil; hva = tekst; return
            }
            let c = try dekoder.container(keyedBy: Nøkler.self)
            tittel = try c.decodeIfPresent(String.self, forKey: .tittel)
            hva = try c.decode(String.self, forKey: .hva)
        }
        private enum Nøkler: String, CodingKey { case tittel, hva }
    }
    let bytte_status: String?
    let anbefaling: Anbefaling?
    /// Odds-avledet per lag, alle 20, nøklet på klubbnavn. **Framoverskuende.**
    let kampforventning: [String: Kampforventning]?

    /// Den ventende beslutningen som struktur.
    ///
    /// ⚠️ `oppstilling == nil` betyr «ingen oppstillingsendring foreslått», ikke «tom
    /// oppstilling». `endrer_oppstilling` finnes nettopp så vi slipper å tolke null.
    struct Anbefaling: Decodable {
        let finnes: Bool?
        let skrevet: String?
        let bytter: [Bytte]?
        let chip: String?
        let kaptein: Navngitt?
        let vise: Navngitt?
        let endrer_oppstilling: Bool?
        let notat: String?
        /// Kildens egen korte formulering av hva som skal gjøres. Vinner over setningen
        /// appen setter sammen selv — den som skrev anbefalingen vet hvorfor.
        let sammendrag: String?

        struct Navngitt: Decodable { let id: Int?; let navn: String; let klubb: String? }
        struct Bytte: Decodable { let inn: Navngitt?; let ut: Navngitt? }
    }

    struct Kampforventning: Decodable {
        let seier_pst: Double?
        let over_2_5_pst: Double?
        let motstander: String?
        let hjemme: Bool?
    }

    struct Lag: Decodable {
        let verdi: Double, bank: Double
        let frie_bytter: Int, bytter_brukt: Int
        let poeng_totalt: Int?          // null før runden er spilt — IKKE vis som 0
    }

    struct Runde: Decodable {
        let nummer: Int
        let frist: String               // absolutt ISO-8601 — nedtellingen regnes herfra
        let paagaaende: Int?
        let laast: Bool                 // KUN om fristen har passert
        /// 0 før runden er spilt — FPLs eget felt fylles først underveis.
        /// **Ikke vis 0 som «snittet er null».**
        let snitt_liga: Int?
    }
    // `timer_til_frist` fantes i v1–v2 og er FJERNET i v3. Den ble regnet ut ved skriving
    // og forfalt aldri — målt 9,5 timer feil. Nedtellingen regnes fra `frist`.

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
        let forventet: Forventet?
        /// Drakt, spillerfoto og klubblogo. URL-ene kommer fra kilden — appen bygger
        /// ingen adresser selv.
        let bilder: Bilder?

        struct Bilder: Decodable {
            let spiller: Spillerbilde?
            let drakt: Drakt?
            let klubblogo: Logo?

            /// ⚠️ `finnes` er HEAD-verifisert per eksport. Ikke alle spillere har foto —
            /// er den `false`, skal appen falle tilbake på drakta, som alltid finnes.
            struct Spillerbilde: Decodable {
                let liten: String?, medium: String?, stor: String?
                let finnes: Bool?
            }
            /// Keepere får keeperdrakta automatisk fra kilden; appen sjekker ikke posisjon.
            struct Drakt: Decodable { let liten: String?, stor: String?, png: String? }
            struct Logo: Decodable { let svg: String?, png: String? }
        }

        /// Hva han faktisk har levert, runde for runde. Se `FplSpiller.swift`.
        let levert: Levert?

        /// Leveransen mot forventningen.
        ///
        /// ⚠️ Arkivet starter 02.09.2026 — `xp_predictions.csv` overskrives hver kjøring,
        /// så for GW1 og GW2 finnes ingen bevart forventning. `forventet_xp` og `avvik`
        /// er `null` der, og `avvik_dekning` («0/2») sier hvor mange runder som faktisk
        /// kan bedømmes. Snittet skjules til dekningen betyr noe.
        struct Levert: Decodable {
            let runder: [Runde]?
            let runder_eid: Int?
            let poeng_hos_oss: Int?
            let snitt_hos_oss: Double?
            let forste_runde_eid: Int?
            let avvik_snitt: Double?
            let avvik_dekning: String?

            struct Runde: Decodable, Identifiable {
                let runde: Int
                let poeng: Int?
                let minutter: Int?
                let xg: Double?
                let xa: Double?
                let bonus: Int?
                /// Falsk = han spilte, men ikke for oss. Halve poenget med å se på en spiller.
                let i_troppen: Bool?
                let i_xi: Bool?
                let kaptein: Bool?
                let forventet_xp: Double?
                let avvik: Double?
                var id: Int { runde }

                /// Rollen som etikett — farge er allerede brukt til noe annet.
                var rolle: String {
                    if i_troppen != true { return "ikke eid" }
                    if kaptein == true { return "kaptein" }
                    return i_xi == true ? "i XI" : "benk"
                }
            }

            /// Hvor mange runder som faktisk har en bevart forventning, av totalt.
            var dekning: (av: Int, total: Int)? {
                guard let d = avvik_dekning else { return nil }
                let d2 = d.split(separator: "/").compactMap { Int($0) }
                return d2.count == 2 ? (d2[0], d2[1]) : nil
            }
        }

        /// xP fra to uavhengige kilder.
        ///
        /// ⚠️ `xp_modell_gyldig == false` betyr at egen modell er underkjent. Da skal
        /// `xp_modell` **ikke vises som et tall alene** — `xp_fplform` er den uavhengige.
        struct Forventet: Decodable {
            let xp_modell: Double?
            let xp_modell_gyldig: Bool?
            let xp_fplform: Double?
            let xp_sum6: Double?
        }

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
        /// Hva svaret brukes til. Uten den ser man at kilden svarte 200, men ikke hva
        /// det betyr at den er nede.
        let brukes_til: String?
        let sist_lest: String?
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
            let nytt = try await api.hent(FplSvar.self, "/api/fpl/status")
            // Ordboka følger dataene. Kommer den ikke, står appen uten forklaringer —
            // det er riktigere enn at vi finner på hva kildens begreper betyr.
            Ordliste.fraKilde = nytt.data.ordliste ?? [:]
            svar = nytt
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
    /// Null i praksis — rundenummeret står på hver beslutning, ikke på toppen. Var
    /// erklært som `Int` og gjorde at HELE filen ikke lot seg lese: skjermen sto med
    /// «ingen beslutninger å vise» selv om det lå seks der.
    let runde: Int?
    let beslutninger: [Beslutning]

    struct Beslutning: Decodable, Identifiable {
        let id: String
        let type: String, sporsmal: String, status: String
        let alternativer: [Alternativ]
        let signaler: [Signal]
        /// Kildens egen ettsetnings utfall. Vinner over appens sammensatte dom.
        let kortsvar: String?
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
            /// Verdiene kan være `null` — et signal kan finnes uten å være målt ennå
            /// (scorer-odds før bookmakerne har åpnet runden). Det er IKKE det samme som
            /// null i verdi, og var erklært `Double`: hele filen lot seg ikke lese.
            let verdier: [String: Double?]
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

/// «Statistikk» — regnskapet over egne beslutninger.
///
/// Kilden advarer selv: med få spilte runder er ratene støy. `n` står ved hver rate, og
/// signalseksjonen skjules helt til `n` er stor nok — en rangering ser autoritativ ut
/// uansett hvor tynt grunnlaget er.
struct FplStatistikk: Decodable {
    let versjon: Int
    let generert: String
    let advarsel: String?
    let premiss: Premiss?
    let kaptein: Kaptein?
    let bytter: Bytter?
    let signaler: [String: Signal]?

    /// Under denne grensen viser vi ikke treffrater. Kildens egen anbefaling.
    static let nokGrunnlag = 10

    struct Premiss: Decodable {
        let holdt: Int?, brast: Int?
        let holdt_men_tapte: Int?, brast_men_vant: Int?
    }
    struct Kaptein: Decodable { let traff: Int?; let n: Int?; let tapt_totalt: Int? }
    struct Bytter: Decodable { let antall: Int?; let sum_effekt: Int?; let sum_trekk: Int?; let netto: Int? }
    struct Signal: Decodable {
        let n: Int?
        let traff: Int?
        let retning: String?
        let vekt_brukt: String?
        let treffrate: Double?
    }
}

extension FplLager {
    func hentStatistikk(_ api: API) async -> FplStatistikk? {
        try? await api.hent(Innpakket<FplStatistikk>.self, "/api/fpl/statistikk").data
    }
}
