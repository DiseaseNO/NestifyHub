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

    // MARK: v2 — det Thomas savnet

    /// Én setning om dagen i dag. Ferdig formulert av kilden.
    let iDag: IDag?
    /// Konkrete råd, viktigst først. Maks fire.
    let rad: [Rad]?
    /// Det som går riktig vei. Skjules helt hvis tom — ingen «ingen fremgang».
    let fremgang: [Fremgang]?
    let form: Form?
    let lop: Lop?
    let styrke: Styrke?
    /// De siste 40 øktene, nyeste først.
    let okter: [Okt]?
    let energi: Energi?

    // MARK: energi

    /// Mat inn og forbrenning ut.
    ///
    /// ⚠️ **`komplett: false` betyr «minst så mye», ikke «så mye».** Thomas sier selv
    /// at han er dårlig til å registrere mat, og logger ikke alt. Et tall fra en delvis
    /// dag er derfor et gulv, ikke en sum — og appen skriver «minst 1 240 kcal».
    ///
    /// Derav to regler som går igjen i hele visningen:
    /// - **Aldri inn mot ut som et underskudd på en delvis dag.** Det ville vært et
    ///   regnestykke med feil fasit, presentert som sannhet.
    /// - **En delvis dag ser nøytral ut.** Ingen advarsel, ingen «du har glemt å
    ///   logge». Logging er valgfritt, og skjermen skal ikke mase.
    ///
    /// Først når kilden selv sender `balanse` — den krever fem komplette dager —
    /// finnes det et regnestykke å vise, og da er teksten ferdig formulert der.
    struct Energi: Decodable {
        let ut: Ut?
        let inn: Inn?
        /// Kommer først ved fem eller flere komplette dager.
        let balanse: Balanse?
        /// Kommer først ved fjorten eller flere komplette dager.
        let kalibrertTdee: Tdee?

        enum CodingKeys: String, CodingKey {
            case ut, inn, balanse
            case kalibrertTdee = "kalibrert_tdee"
        }

        struct Ut: Decodable {
            let iDagSaLangt: SaLangt?
            let snitt7d: Double?
            let aktivSnitt7d: Double?
            let snitt30d: Double?
            let siste14d: [Dag]?

            enum CodingKeys: String, CodingKey {
                case snitt7d = "snitt_7d", aktivSnitt7d = "aktiv_snitt_7d"
                case snitt30d = "snitt_30d", siste14d = "siste_14d"
                case iDagSaLangt = "i_dag_sa_langt"
            }
            /// Dagen i dag, som ikke er ferdig. `hentet` er klokkeslettet tallet
            /// gjelder fram til — uten det ville «1 175 kcal» sett ut som et døgn.
            struct SaLangt: Decodable { let total: Double?; let aktiv: Double?; let hentet: String? }
            struct Dag: Decodable, Identifiable {
                let dato: String?; let total: Double?; let aktiv: Double?; let hvile: Double?
                var id: String { dato ?? "" }
            }
        }

        struct Inn: Decodable {
            let iDag: Dag?
            let maltiderIDag: [Maltid]?
            let snitt7d: Double?
            let proteinSnitt7d: Double?
            let dagerLogget7d: Int?
            let dagerKomplett7d: Int?
            let siste14d: [Dag]?

            enum CodingKeys: String, CodingKey {
                case snitt7d = "snitt_7d", siste14d = "siste_14d"
                case iDag = "i_dag", maltiderIDag = "maltider_i_dag"
                case proteinSnitt7d = "protein_snitt_7d"
                case dagerLogget7d = "dager_logget_7d"
                case dagerKomplett7d = "dager_komplett_7d"
            }

            struct Dag: Decodable, Identifiable {
                let dato: String?
                let kcal: Double?
                let protein: Double?
                let karbo: Double?
                let fett: Double?
                /// Falsk = dagen er ikke ferdig logget. Tallet er da et **gulv**.
                let komplett: Bool?
                var id: String { dato ?? "i_dag" }
                var erGulv: Bool { komplett == false }
            }

            struct Maltid: Decodable, Identifiable {
                let tid: String?
                let maltid: String?
                let beskrivelse: String?
                let kcal: Double?
                let protein: Double?
                var id: String { (tid ?? "") + (maltid ?? "") }
            }
        }

        /// Ferdig formulert av kilden. Appen regner aldri differansen selv.
        struct Balanse: Decodable {
            let innSnitt7d: Double?
            let utSnitt7d: Double?
            let differanse: Double?
            let tekst: String?
            enum CodingKeys: String, CodingKey {
                case differanse, tekst
                case innSnitt7d = "inn_snitt_7d"
                case utSnitt7d = "ut_snitt_7d"
            }
        }

        struct Tdee: Decodable {
            let tdee: Double?; let fra: String?; let til: String?; let metode: String?
        }
    }

    enum CodingKeys: String, CodingKey {
        case generert, uke, rekorder, midje, vekt, protein, reisen, kontekst
        case rad, fremgang, form, lop, styrke, okter, energi
        case iDag = "i_dag"
    }

    struct IDag: Decodable {
        let dato: String?
        /// Hovedbudskapet øverst på skjermen. Vises ordrett.
        let forslag: String?
        let readiness: Double?
    }

    struct Rad: Decodable, Identifiable {
        let tittel: String?
        let tekst: String?
        /// `sovn`, `styrke`, `kondisjon` eller `belastning` — styrer bare ikonet.
        let kategori: String?
        var id: String { (tittel ?? "") + (kategori ?? "") }
        var ikon: String {
            switch kategori {
            case "sovn":       "bed.double"
            case "styrke":     "figure.strengthtraining.traditional"
            case "kondisjon":  "heart"
            case "belastning": "gauge.with.dots.needle.50percent"
            default:           "lightbulb"
            }
        }
    }

    struct Fremgang: Decodable, Identifiable {
        let tittel: String?
        let tekst: String?
        let retning: String?
        var id: String { tittel ?? "" }
    }

    // MARK: form

    struct Form: Decodable {
        let treningsstatus: Treningsstatus?
        let vo2max: Vo2max?
        let fitnessAlder: FitnessAlder?
        let belastning: Belastning?
        let readiness: Readiness?
        let hvilepuls: Snitt?
        let hrv: Hrv?
        let sovn: Sovn?
        let terskel: Terskel?

        enum CodingKeys: String, CodingKey {
            case treningsstatus, vo2max, belastning, readiness, hvilepuls, hrv, sovn, terskel
            case fitnessAlder = "fitness_alder"
        }

        struct Treningsstatus: Decodable { let tekst: String?; let forklaring: String?; let dato: String? }

        struct Vo2max: Decodable {
            let verdi: Double?
            let dato: String?
            /// Verdien for 90 dager siden, så retningen kan vises uten å regne selv.
            let for90d: Double?
            let topp: Topp?
            let historikk: [Maaned]?
            enum CodingKeys: String, CodingKey { case verdi, dato, topp, historikk; case for90d = "for_90d" }
            struct Topp: Decodable { let verdi: Double?; let dato: String? }
            struct Maaned: Decodable, Identifiable {
                let mnd: String?; let verdi: Double?
                var id: String { mnd ?? "" }
            }
        }

        struct FitnessAlder: Decodable { let verdi: Double?; let alder: Double?; let oppnaelig: Double? }

        struct Belastning: Decodable {
            let akutt: Double?; let kronisk: Double?; let acwr: Double?
            /// Ferdig vurdering i tekst. Appen tolker aldri tallene selv.
            let vurdering: String?
        }

        struct Readiness: Decodable { let score: Double?; let niva: String?; let dato: String? }

        struct Snitt: Decodable {
            let snitt7d: Double?; let snitt90d: Double?
            enum CodingKeys: String, CodingKey { case snitt7d = "snitt_7d"; case snitt90d = "snitt_90d" }
        }

        struct Hrv: Decodable {
            let snitt7d: Double?; let snitt30d: Double?; let siste30d: [Maaling]?
            enum CodingKeys: String, CodingKey {
                case snitt7d = "snitt_7d"; case snitt30d = "snitt_30d"; case siste30d = "siste_30d"
            }
            struct Maaling: Decodable, Identifiable {
                let dato: String?; let ms: Double?
                var id: String { dato ?? "" }
            }
        }

        struct Sovn: Decodable {
            let snitt7d: Double?; let snitt30d: Double?; let siste30d: [Natt]?
            enum CodingKeys: String, CodingKey {
                case snitt7d = "snitt_7d"; case snitt30d = "snitt_30d"; case siste30d = "siste_30d"
            }
            struct Natt: Decodable, Identifiable {
                let dato: String?; let timer: Double?
                var id: String { dato ?? "" }
            }
        }

        struct Terskel: Decodable { let tempo: String?; let puls: Double? }
    }

    // MARK: løping og styrke

    struct Uketall: Decodable, Identifiable {
        let start: String?
        let okter: Int?
        let km: Double?
        let min: Double?
        var id: String { start ?? "" }
    }

    struct Lop: Decodable {
        let uker: [Uketall]?
        let kmSnitt4u: Double?
        let lengste30d: Okt?
        /// Distanse → tid. Rekkefølgen i JSON er ikke garantert, så visningen sorterer selv.
        let prediksjon: [String: String]?
        let prediksjonDato: String?
        let rekorder: [Rekordlop]?
        enum CodingKeys: String, CodingKey {
            case uker, prediksjon, rekorder
            case kmSnitt4u = "km_snitt_4u"
            case lengste30d = "lengste_30d"
            case prediksjonDato = "prediksjon_dato"
        }
        struct Rekordlop: Decodable, Identifiable {
            let distanse: String?; let tid: String?; let km: Double?; let dato: String?
            var id: String { (distanse ?? "") + (dato ?? "") }
        }
    }

    struct Styrke: Decodable {
        let uker: [Uketall]?
        let okterSnitt4u: Double?
        let malPerUke: Double?
        enum CodingKeys: String, CodingKey {
            case uker
            case okterSnitt4u = "okter_snitt_4u"
            case malPerUke = "mal_per_uke"
        }
    }

    // MARK: økter

    struct Okt: Decodable, Identifiable {
        let id: String?
        let dato: String?
        let start: String?
        let type: String?
        let typeTekst: String?
        let navn: String?
        let varighetMin: Double?
        let km: Double?
        let tempo: String?
        let snittpuls: Double?
        let makspuls: Double?
        let kcal: Double?
        let hoydemeter: Double?
        let aerobTe: Double?
        let anaerobTe: Double?
        let treningslast: Double?

        enum CodingKeys: String, CodingKey {
            case id, dato, start, type, navn, km, tempo, snittpuls, makspuls, kcal, hoydemeter, treningslast
            case typeTekst = "type_tekst"
            case varighetMin = "varighet_min"
            case aerobTe = "aerob_te"
            case anaerobTe = "anaerob_te"
        }

        var erStyrke: Bool { type?.contains("strength") == true || typeTekst?.lowercased().contains("styrke") == true }
        var erLop: Bool { type?.contains("running") == true }
        var ikon: String {
            if erStyrke { return "figure.strengthtraining.traditional" }
            if erLop { return "figure.run" }
            return "figure.mixed.cardio"
        }
    }

    // MARK: uka

    /// ⚠️ **Hvert felt her kan mangle, og det betyr «vet ikke» — ikke null.**
    ///
    /// Kilden regner bare en uke som gyldig hvis den har hentet aktivitetsdata for
    /// alle dagene i den. Mangler én dag, utelates tallene framfor å vise et tall
    /// som ser riktig ut. Et hull i importen skal aldri se ut som «trente ikke».
    ///
    /// I ytterste fall kommer bare `start`, `slutt` og `sistOkt`. Kortet må tåle det.
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
        /// De 8 fullførte ukene før inneværende, eldste først. Inneværende uke er
        /// `godkjent`, ikke en del av denne.
        ///
        /// **Utelates av kilden hvis noen av ukene mangler importdata.** Da tegnes
        /// ingen prikker — vi vet ikke, og en tom prikk ville løyet.
        let historikk: [Bool]?
        /// Hovedbudskapet, ferdig formulert av kilden. Vises **ordrett**. Appen lager
        /// aldri sin egen vurdering av hvordan uka går.
        let mangler: String?
        let sistOkt: String?

        struct Okter: Decodable { let gjort: Int?; let mal: Int? }

        enum CodingKeys: String, CodingKey {
            case start, slutt, godkjent, okter, styrke, lop, annet, mangler, historikk
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
        /// Han veier seg omtrent fire ganger i måneden. 30 dager gir tre–fire
        /// prikker, og det er for lite til å se en sone. 90 er serien vi viser
        /// når den finnes.
        let siste90d: [Punkt]?

        struct Sone: Decodable { let fra: Double?; let til: Double? }
        struct Maaling: Decodable { let kg: Double?; let dato: String? }

        enum CodingKeys: String, CodingKey {
            case sone, siste
            case snitt7d = "snitt_7d"
            case snitt14d = "snitt_14d"
            case iSonenSiden = "i_sonen_siden"
            case dagerISonen = "dager_i_sonen"
            case siste30d = "siste_30d"
            case siste90d = "siste_90d"
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

        /// Brukes bare når destinasjonen bygges før dataene finnes. Skjermen viser
        /// da overskriften sin framfor ingenting — en blank skjerm ser ødelagt ut.
        static let tom = Reisen(punkter: nil, merker: nil)

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
    /// Norsk, alltid.
    ///
    /// Appen setter `\.locale` i miljøet, men **Swift Charts' aksetiketter leser det
    /// ikke** når formatet er oppgitt eksplisitt med `.dateTime` — de faller tilbake
    /// på enhetens locale. I CI står simulatoren på engelsk, og aksene sa «Aug Sep
    /// Oct» i en app som ellers er norsk. Hver akse må derfor si det selv.
    static let norsk = Locale(identifier: "nb_NO")

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

    /// Er dette en ren kalenderdato («2026-10-12») framfor et tidspunkt?
    ///
    /// Kilden sender begge deler. `generert` og `sist_okt` har tidssone og er
    /// øyeblikk; `start`, `slutt` og alle datoene på kurvepunktene er kalenderdager
    /// uten klokkeslett. De to må behandles ulikt.
    static func erKalenderdato(_ s: String) -> Bool {
        s.count == 10 && !s.contains("T")
    }

    static func dato(_ iso: String?) -> Date? {
        guard let iso else { return nil }
        if erKalenderdato(iso) {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "yyyy-MM-dd HH:mm"
            // **Forankres kl. 12, ikke midnatt.** En kalenderdag er ikke et øyeblikk,
            // og midnatt ligger på kanten av døgnet: en tidssoneendring, en
            // sommertidsovergang eller en graf som regner i en annen sone kan da
            // skyve datoen én dag. Fra midt på dagen har ingen av delene nok å gå på.
            return f.date(from: iso + " 12:00")
        }
        let m = ISO8601DateFormatter()
        m.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = m.date(from: iso) { return d }
        m.formatOptions = [.withInternetDateTime]
        return m.date(from: iso)
    }

    /// «16. okt» — kort dato til merkelapper.
    /// «16. okt.» for i år, «3. des. 2022» ellers.
    ///
    /// Året sto ikke før, og rekordene — som er fra 2022 — leste som ferske. En
    /// dato uten år er bare utvetydig innenfor året man står i.
    static func kortDato(_ iso: String?) -> String? {
        guard let d = dato(iso) else { return nil }
        let f = DateFormatter()
        f.locale = norsk
        let k = Calendar.current
        f.dateFormat = k.component(.year, from: d) == k.component(.year, from: Date())
            ? "d. MMM" : "d. MMM yyyy"
        return f.string(from: d)
    }
}
