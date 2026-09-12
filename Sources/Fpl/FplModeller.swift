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
    /// Fri tekst om byttesituasjonen.
    ///
    /// Var en streng, ble et objekt 5. september 2026 uten at `versjon` ble bumpet.
    /// Dekoderen tar imot begge: fra objektet plukkes `plan`, som er setningen kilden
    /// selv skriver. Det er meningen bak feltet, uansett innpakning.
    let bytte_status: String?
    let anbefaling: Anbefaling?
    /// Odds-avledet per lag, alle 20, nøklet på klubbnavn. **Framoverskuende.**
    let kampforventning: [String: Kampforventning]?

    /// Kvitteringen for utførelse.
    ///
    /// Uten den vet ikke appen om noe skjedde, og da tør ingen trykke på knappen.
    /// `hva_ble_gjort` er en **verifisert** påstand: kilden leser tilbake fra laget og
    /// sammenligner før den skriver `utfort`.
    let utforelse: Utforelse?

    struct Utforelse: Decodable {
        /// `ingen` · `venter` · `utfort` · `avvist_endret_grunnlag` · `avvist_frist` ·
        /// `feilet`. Alle seks står i `ordliste`, så appen forklarer dem selv.
        let status: String
        let anbefaling_id: String?
        let godkjent: String?
        let utfort: String?
        let hva_ble_gjort: String?
        let kostnad: String?
        let feil: String?
        /// Sant når kvitteringen gjelder anbefalingen som ligger der NÅ. En kvittering
        /// fra forrige runde skal ikke se ut som svar på dagens knapp.
        let gjelder_naavaerende: Bool?
        let merknad: String?
        /// Sant når kvitteringen er lappet inn, men RESTEN av fila ennå er fra før
        /// utførelsen — troppen og laget henger noen sekunder etter mens kilden kjører
        /// den fulle eksporten. Da: vis kvitteringen, men ikke stol på lagbildet ennå.
        /// Forsvinner når hele fila er ferskt.
        let resten_oppdateres: Bool?
        /// Kildens kontrollkjøring før innsending — hva som FAKTISK ble endret. Kommer
        /// som én tekst med linjeskift, IKKE en liste: appen antok `[String]`, og da
        /// feilet hele kvitteringen med «isn't in the correct format» mens byttet i
        /// virkeligheten var utført. Vi eier ikke formatet — det gjør kilden.
        let diff: String?
        /// Hvilke beslutninger som faktisk ble utført. `hva_ble_gjort` beskriver nå
        /// **pakken Thomas valgte**, ikke anbefalingen — de er ikke det samme når han har
        /// valgt bort noe, og en kvittering som beskriver noe annet enn det som ble gjort
        /// er verre enn ingen kvittering.
        let valgte: [String]?
        let grunnlag_id: String?
    }

    /// Dekoder felt for felt, slik at ETT felt som skifter form ikke tar med seg
    /// skjermen.
    ///
    /// Vi eier ikke formatet. Med syntetisert dekoding er hele `FplStatus` enten-eller:
    /// da `bytte_status` gikk fra streng til objekt 5. september, ble Fantasy helt blank
    /// — ikke bare den ene linja. Det er feil pris for en endring i ett felt.
    ///
    /// Det som MÅ til for at skjermen betyr noe (troppen, runden, laget) kastes fortsatt.
    /// Er de borte, er det riktig å si fra i stedet for å tegne et tomt skall.
    init(from dekoder: Decoder) throws {
        let c = try dekoder.container(keyedBy: Nøkler.self)
        versjon   = try c.decode(Int.self, forKey: .versjon)
        generert  = try c.decode(String.self, forKey: .generert)
        sesong    = try c.decode(String.self, forKey: .sesong)
        lag       = try c.decode(Lag.self, forKey: .lag)
        runde     = try c.decode(Runde.self, forKey: .runde)
        tropp     = try c.decode([Spiller].self, forKey: .tropp)
        sjekker   = (try? c.decode([Sjekk].self, forKey: .sjekker)) ?? []
        kilder    = (try? c.decode([Kilde].self, forKey: .kilder)) ?? []

        odds_kvote_igjen          = try? c.decodeIfPresent(Int.self, forKey: .odds_kvote_igjen)
        modell_status             = try? c.decodeIfPresent(String.self, forKey: .modell_status)
        aapne_sporsmal            = try? c.decodeIfPresent([Punkt].self, forKey: .aapne_sporsmal)
        aapne_risikoer            = try? c.decodeIfPresent([Punkt].self, forKey: .aapne_risikoer)
        modell_status_sammendrag  = try? c.decodeIfPresent(String.self, forKey: .modell_status_sammendrag)
        sporsmal_oversikt         = try? c.decodeIfPresent(Oversikt.self, forKey: .sporsmal_oversikt)
        endret                    = try? c.decodeIfPresent([Endring].self, forKey: .endret)
        endret_historikk          = try? c.decodeIfPresent([Endring].self, forKey: .endret_historikk)
        ordliste                  = try? c.decodeIfPresent([String: Kildeord].self, forKey: .ordliste)
        anbefaling                = try? c.decodeIfPresent(Anbefaling.self, forKey: .anbefaling)
        kampforventning           = try? c.decodeIfPresent([String: Kampforventning].self, forKey: .kampforventning)
        utforelse                 = try? c.decodeIfPresent(Utforelse.self, forKey: .utforelse)

        // Streng før 5. september, objekt etter. Fra objektet er `plan` setningen som
        // faktisk sier noe; resten er tall appen viser andre steder.
        if let tekst = try? c.decodeIfPresent(String.self, forKey: .bytte_status) {
            bytte_status = tekst
        } else if let o = try? c.decodeIfPresent(Byttestatusobjekt.self, forKey: .bytte_status) {
            bytte_status = o.plan
        } else {
            bytte_status = nil
        }
    }

    private struct Byttestatusobjekt: Decodable { let plan: String? }

    private enum Nøkler: String, CodingKey {
        case versjon, generert, sesong, lag, runde, tropp, sjekker, kilder
        case odds_kvote_igjen, modell_status, aapne_sporsmal, aapne_risikoer
        case modell_status_sammendrag, sporsmal_oversikt, endret, endret_historikk
        case ordliste, bytte_status, anbefaling, kampforventning, utforelse
    }

    /// Den ventende beslutningen som struktur.
    ///
    /// ⚠️ `oppstilling == nil` betyr «ingen oppstillingsendring foreslått», ikke «tom
    /// oppstilling». `endrer_oppstilling` finnes nettopp så vi slipper å tolke null.
    struct Anbefaling: Decodable {
        let finnes: Bool?
        /// Identifiserer nøyaktig denne anbefalingen, og følger med godkjenningen.
        /// Er anbefalingen byttet ut i mellomtiden, svarer kilden
        /// `avvist_endret_grunnlag` framfor å gjøre noe.
        let id: String?
        let grunnlag_id: String?
        /// Hva det koster, i klartekst fra kilden. Vi regner det IKKE selv: om et bytte
        /// er gratis eller koster fire poeng avhenger av frie bytter og chip-tilstand,
        /// og det regnestykket er deres.
        let kostnad: String?
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
    /// Når vi sist snakket med serveren — uavhengig av hvor gamle tallene fra kilden er.
    private(set) var sistSjekket: Date?
    /// Hentingen som pågår, så et nedtrekk venter på den framfor å gjøre ingenting.
    private var pågående: Task<Void, Never>?

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

    /// Henter statusen.
    ///
    /// Er en henting allerede i gang, **venter** vi på den framfor å returnere med én
    /// gang. Før gjorde et nedtrekk ingenting hvis bakgrunnsløkka tilfeldigvis holdt på,
    /// og da så det ut som at nedtrekket ikke virket.
    func last() async {
        if let p = pågående { await p.value; return }
        let t = Task { await hentNå() }
        pågående = t
        await t.value
        pågående = nil
    }

    private func hentNå() async {
        henter = true
        defer { henter = false; sistSjekket = Date() }
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
    /// Bruker lagerets eget API — utvidelsen ligger i samme fil og ser det.
    func hentValg() async -> FplValg? {
        try? await api.hent(Innpakket<FplValg>.self, "/api/fpl/valg").data
    }

    /// Leverer en signert godkjenning av **den pakken Thomas valgte**.
    ///
    /// Begge id-ene kommer fra `valg.json`, ikke fra statusen: `grunnlag_id` er ulikt de
    /// to stedene, og statusens variant ville blitt avvist.
    ///
    /// `anbefaling_id` sier hvilken handling. `grunnlag_id` sier hvilket bilde av verden
    /// den ble valgt fra — uten den kunne en godkjenning fra to timer siden fortsatt
    /// utføres etter at en skade snudde alt.
    /// Returnerer kvitteringen med én gang hvis backend rakk å få den (path-trigger på
    /// kildens side), ellers nil — da fortsetter appen å vente og henter status på nytt.
    /// Returnerer kvitteringen hvis backend rakk den (path-trigger, ~1,5 s), ellers nil.
    /// `godkjent`-tidsstempelet følger alltid med, så en videre polling kjenner igjen
    /// NØYAKTIG denne godkjenningen framfor en annen kvittering i status.json.
    @discardableResult
    func godkjennValg(_ kombinasjonId: String, grunnlagId: String, gw: Int) async throws
        -> (kvittering: FplStatus.Utforelse?, godkjent: String?) {
        let svar = try await api.sendOgLes(Godkjennsvar.self, "/api/fpl/godkjenn",
                                           ["anbefaling_id": kombinasjonId, "grunnlag_id": grunnlagId, "gw": gw])
        await last()
        return (svar.venter == true ? nil : svar.utforelse, svar.godkjent)
    }

    /// Henter til LAGET er ferskt etter en utførelse.
    ///
    /// Kvitteringen kommer på halvannet sekund, men kilden bruker noen sekunder til på å
    /// skrive den fulle eksporten — til da er troppen fortsatt fra før byttet, og
    /// `utforelse.resten_oppdateres` er satt. Vi henter til flagget er borte, så laget i
    /// appen oppdateres av seg selv når det nye bildet lander.
    func ventPaaFerskeLag() async {
        for _ in 0..<12 {
            if svar?.data.utforelse?.resten_oppdateres != true { return }
            try? await Task.sleep(for: .seconds(2))
            await last()
        }
    }

    private struct Godkjennsvar: Decodable {
        let ok: Bool?
        let venter: Bool?
        let utforelse: FplStatus.Utforelse?
        let godkjent: String?
    }
}

/// Valgene Thomas kan ta — hele anbefalingen, eller bare deler av den.
///
/// **Appen setter ikke sammen et valg selv.** Kostnaden er ikke additiv (med ett fritt
/// bytte koster det første 0 og det andre −4; velger man bort det første, blir det andre
/// gratis), og å velge bort et bytte river i oppstillingen. Kilden regner derfor ut hver
/// lovlige kombinasjon på forhånd, med sin egen pris og sin egen kontroll. Vi viser dem.
struct FplValg: Decodable {
    let runde: Int?
    let grunnlag_id: String
    let anbefalt_id: String?
    /// Ikke-null bare hvis KILDENS egen anbefaling ikke lar seg gjennomføre. Det er en
    /// feil hos dem, ikke et valg for Thomas — vises tydelig.
    let anbefaling_ulovlig: String?
    let beslutninger: [Beslutning]
    let kombinasjoner: [Kombinasjon]

    struct Beslutning: Decodable, Identifiable {
        let id: String
        let type: String
        /// Alltid til stede og nøktern. `tittel` og `sammendrag` er skrevet av vakta og
        /// kan mangle — da viser vi ingenting framfor å finne på noe.
        let beskrivelse: String
        let tittel: String?
        let sammendrag: String?
        let inn: Int?
        let ut: Int?
        let krever: [String]?
    }

    struct Kombinasjon: Decodable, Identifiable {
        let id: String
        let beslutninger: [String]
        let anbefalt: Bool?
        let lovlig: Bool
        /// Konsekvensen når pakken ikke er lovlig — «Mangler 3,1M. Thiago må selges
        /// først.» Det er nettopp dette man vil se når man vurderer å velge bort en del.
        let hvorfor_ikke: String?
        let kostnad_poeng: Int?
        /// Kildens tekst, ordrett. Vi regner ikke prisen selv.
        let kostnad: String?
        let bank_etter: Double?
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
