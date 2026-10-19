import Foundation

/// Ting appen og widgeten deler.
///
/// En widget er en egen prosess med egen livssyklus. Den kan ikke lese appens minne, og
/// den kjører når systemet vil — ofte når appen ikke har vært åpen på timer. Derfor to
/// ting her:
///
///  * **App-gruppa** er den eneste mappa begge kan skrive i.
///  * **Øyeblikksbildet** er det appen legger igjen, så widgeten har noe å vise selv om
///    nettet er nede eller enheten ikke er paret ennå.
///
/// Widgeten henter også selv når den kan, men den skal aldri stå tom fordi hentingen
/// feilet.
enum Delt {
    /// Må stemme med App Group-rettigheten i `project.yml` og i profilen fra match.
    static let gruppe = "group.no.gustavs1.hjemme"

    static var mappe: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: gruppe)
    }

    private static var fil: URL? { mappe?.appendingPathComponent("husbilde.json") }
    private static var tilgangsfil: URL? { mappe?.appendingPathComponent("tilgang.json") }

    /// Adresse og enhets-token, delt med widgeten.
    ///
    /// ⚠️ Dette er en bevisst avveining. Appen har alltid hatt dette i Keychain, og der
    /// ligger originalen fortsatt. Men en widget som skal kunne SLÅ AV ET LYS må nå
    /// serveren mens appen er lukket, og Keychain kan bare deles mellom app og utvidelse
    /// via «Keychain Sharing» — en kapabilitet som må slås på i Apples portal og som
    /// koster en runde med nye profiler.
    ///
    /// Fila ligger i app-gruppa, altså inne i appens sandkasse, og skrives med
    /// `.completeUntilFirstUserAuthentication` slik at den er kryptert til telefonen er
    /// låst opp første gang etter omstart. Widgeten kjører før det, men da har den
    /// uansett ingenting å vise.
    ///
    /// Vil man ha den i Keychain likevel, er veien: slå på Keychain Sharing på begge
    /// app-ID-ene, kjør bygget med «nye_profiler», og bytt ut denne fila.
    struct Tilgang: Codable {
        var vert: String
        var token: String
    }

    static func lagre(_ t: Tilgang?) {
        guard let tilgangsfil else { return }
        guard let t, let data = try? JSONEncoder().encode(t) else {
            try? FileManager.default.removeItem(at: tilgangsfil)
            return
        }
        try? data.write(to: tilgangsfil, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    static func tilgang() -> Tilgang? {
        guard let tilgangsfil, let d = try? Data(contentsOf: tilgangsfil) else { return nil }
        return try? JSONDecoder().decode(Tilgang.self, from: d)
    }

    /// Det widgeten kan vise.
    ///
    /// Fortsatt lite — en widget som må vente på mye data rekker ikke å tegne seg før
    /// systemet gir opp. Men rommene må være med: brukeren velger selv hva widgeten
    /// viser, og valget kan ikke begrenses til det appen tilfeldigvis la igjen sist.
    ///
    /// Alle nye felter har standardverdi. Widgeten kan lese et bilde skrevet av en eldre
    /// app-versjon — de to oppdateres ikke samtidig — og skal da mangle et rom, ikke
    /// feile helt.
    struct Husbilde: Codable {
        var effektWatt: Int?
        var lysPaa: Int
        var kroner: Double?
        var oppdatert: Date
        /// Satt når appen ikke er paret ennå — da skal widgeten si det, ikke vise nuller.
        var uparet: Bool = false
        var rom: [Rom] = []
        /// Null når magnetkontakten ikke svarer. Da vet vi ikke, og sier det.
        var garasjeAapen: Bool?

        /// Det widgeten kan slå av og på. Bare lys og brytere — varme styres med
        /// måltemperatur, og en av/på-knapp på en ovn er ikke det man vil ha på
        /// hjemskjermen.
        var brytere: [Bryter] = []

        struct Bryter: Codable, Identifiable {
            var id: String
            var navn: String
            var paa: Bool
            /// `light` eller `switch` — avgjør hvilken tjeneste som skal kalles.
            var domene: String
        }

        struct Rom: Codable, Identifiable {
            var navn: String
            var lysPaa: Int
            var lysTotalt: Int
            var temp: Double?
            /// `varmer`, `kjoler` eller `av`.
            var klima: String?
            var id: String { navn }
        }
    }

    static func lagre(_ b: Husbilde) {
        guard let fil, let data = try? JSONEncoder().encode(b) else { return }
        try? data.write(to: fil, options: .atomic)
    }

    static func lest() -> Husbilde? {
        guard let fil, let d = try? Data(contentsOf: fil) else { return nil }
        return try? JSONDecoder().decode(Husbilde.self, from: d)
    }

    /// Slår en ting av eller på.
    ///
    /// Ligger her, ikke i appens API-klient, fordi **widgeten er en egen prosess** og ikke
    /// kan bruke appens kode. Samme sti og samme token — det er serveren som avgjør hva
    /// som er lov, ikke hvem som spør.
    static func styr(entitet: String, domene: String, paa: Bool) async throws {
        guard let t = tilgang(), let u = URL(string: "https://\(t.vert)/api/hus/styr") else {
            throw Styrefeil.ikkeKlar
        }
        var rq = URLRequest(url: u)
        rq.httpMethod = "POST"
        rq.setValue("Bearer \(t.token)", forHTTPHeaderField: "Authorization")
        rq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        rq.httpBody = try JSONSerialization.data(withJSONObject: [
            "domain": domene,
            "service": paa ? "turn_on" : "turn_off",
            "data": ["entity_id": entitet],
        ])
        // Kort tidsavbrudd: en widget-handling som henger, ser ut som om trykket ikke
        // registrerte seg, og da trykker man igjen.
        rq.timeoutInterval = 10
        let (_, svar) = try await URLSession.shared.data(for: rq)
        guard let h = svar as? HTTPURLResponse, (200..<300).contains(h.statusCode) else {
            throw Styrefeil.avvist
        }
        // Skriv den nye tilstanden inn i øyeblikksbildet med én gang. Neste henting fra
        // appen retter det uansett, men widgeten skal ikke stå og vise «av» i et kvarter
        // etter at man slo på lyset.
        if var b = lest() {
            if let i = b.brytere.firstIndex(where: { $0.id == entitet }) { b.brytere[i].paa = paa }
            lagre(b)
        }
    }

    /// Når garasjeknappen i widgeten sist ble «armert».
    ///
    /// Widgets kan ikke vise en dialog — en intent som kjører i widget-prosessen har
    /// ingen skjerm å spørre på. Bekreftelsen gjøres derfor med **to trykk**: første
    /// trykk armerer og bytter knappeteksten, andre trykk innen vinduet utfører.
    ///
    /// Det er en ekte bekreftelse: et enkelt uhell i lomma eller på en forbipasserende
    /// finger åpner ikke porten, og man ser hva som skjer før det skjer.
    private static var armertfil: URL? { mappe?.appendingPathComponent("garasje-armert") }

    /// Hvor lenge armeringen varer. Kort nok til at den ikke blir stående glemt,
    /// langt nok til at man rekker å lese knappen.
    static let armeringsvindu: TimeInterval = 8

    static var garasjeArmert: Date? {
        guard let armertfil,
              let d = try? Data(contentsOf: armertfil),
              let t = TimeInterval(String(decoding: d, as: UTF8.self)) else { return nil }
        let dato = Date(timeIntervalSince1970: t)
        return Date().timeIntervalSince(dato) < armeringsvindu ? dato : nil
    }

    static func armerGarasje(_ på: Bool) {
        guard let armertfil else { return }
        if på {
            try? Data(String(Date().timeIntervalSince1970).utf8).write(to: armertfil, options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: armertfil)
        }
    }

    /// Pulser garasjeporten. Egen funksjon fordi ruta er en annen: den tar ingen
    /// parametre, og backend bestemmer hva «puls» betyr.
    static func garasje() async throws {
        guard let t = tilgang(), let u = URL(string: "https://\(t.vert)/api/hus/garasje") else {
            throw Styrefeil.ikkeKlar
        }
        var rq = URLRequest(url: u)
        rq.httpMethod = "POST"
        rq.setValue("Bearer \(t.token)", forHTTPHeaderField: "Authorization")
        rq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        rq.httpBody = Data("{}".utf8)
        rq.timeoutInterval = 10
        let (_, svar) = try await URLSession.shared.data(for: rq)
        guard let h = svar as? HTTPURLResponse, (200..<300).contains(h.statusCode) else {
            throw Styrefeil.avvist
        }
    }

    /// Huker av, godkjenner eller avslår oppgaver. Én eller mange i samme kall.
    static func oppgave(_ knapper: [String]) async throws {
        guard let t = tilgang(), let u = URL(string: "https://\(t.vert)/api/hus/oppgave") else {
            throw Styrefeil.ikkeKlar
        }
        var rq = URLRequest(url: u)
        rq.httpMethod = "POST"
        rq.setValue("Bearer \(t.token)", forHTTPHeaderField: "Authorization")
        rq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        rq.httpBody = try JSONSerialization.data(withJSONObject: ["knapp": knapper])
        rq.timeoutInterval = 25
        let (_, svar) = try await URLSession.shared.data(for: rq)
        guard let h = svar as? HTTPURLResponse, (200..<300).contains(h.statusCode) else {
            throw Styrefeil.avvist
        }
    }

    enum Styrefeil: LocalizedError {
        case ikkeKlar, avvist
        var errorDescription: String? {
            switch self {
            case .ikkeKlar: "Appen er ikke koblet til huset."
            case .avvist:   "Huset tok ikke imot kommandoen."
            }
        }
    }
}

// MARK: - trening

extension Delt {
    private static var treningsfil: URL? { mappe?.appendingPathComponent("treningsbilde.json") }

    /// Det treningswidgeten viser — og **ikke noe mer**.
    ///
    /// Widgeten dekoder bevisst ikke `/api/trening/visning` slik appen gjør. Det svaret
    /// er et levende skjema som utvides flere ganger om dagen, og 18.10.2026 holdt det
    /// med ett felt som skiftet type til at hele skjermen ble stående tom. En widget som
    /// er avhengig av å forstå hele svaret, arver den skjørheten — og en tom widget på
    /// hjemskjermen er verre enn en tom skjerm inne i appen, fordi ingen har bedt om å
    /// se den.
    ///
    /// Derfor dette: appen leser svaret, plukker ut de få tallene widgeten trenger, og
    /// legger dem igjen her. Alt er valgfritt og har standardverdi, så et bilde skrevet
    /// av en eldre app-versjon fortsatt kan leses.
    struct Treningsbilde: Codable {
        /// Kildens eget tidsstempel. Brukes til «kl. HH:MM» når bildet er gammelt.
        var generert: Date?
        /// Når appen skrev det. Avgjør om widgeten selv bør hente på nytt.
        var skrevet: Date = Date()

        var streakUker: Int?
        var gjort: Int?
        var mal: Int?
        var styrke: Int?
        var lop: Int?
        var godkjent: Bool?
        /// Kort status, lengste kjente verdi er 14 tegn («Mangler styrke»).
        /// Ferdig formulert av kilden; widgeten forkorter aldri selv.
        var manglerKort: String?
        /// Ukas siste dag, ren kalenderdato («2026-10-25»). Brukes til ukeskiftet.
        var ukeSlutt: String?
        var ukenummer: Int?

        /// Én setning om i dag. Vises bare på medium.
        var forslag: String?
        var sovnTimer: Double?
        var readinessScore: Int?
        /// Norsk nivå fra `form.readiness.niva`. **Ikke** `kontekst.readiness_niva` —
        /// den er Garmins rå engelske kode.
        var readinessNiva: String?

        /// Satt når appen ikke er paret. Da skal widgeten si det, ikke vise nuller.
        var uparet: Bool = false

        /// Sann når bildet er fra en uke som er over.
        ///
        /// En widget kan bli stående i timer. Uten dette ville den vist «3/3 · I boks»
        /// mandag morgen, for en uke som var ferdig — og det er en gratulasjon for noe
        /// man ikke har gjort ennå.
        func gammelUke(_ nå: Date = Date()) -> Bool {
            guard let s = ukeSlutt else { return false }
            let f = DateFormatter()
            f.locale = Locale(identifier: "nb_NO")
            f.dateFormat = "yyyy-MM-dd"
            guard let slutt = f.date(from: s) else { return false }
            return Calendar.current.startOfDay(for: nå) > Calendar.current.startOfDay(for: slutt)
        }
    }

    static func lagre(_ t: Treningsbilde) {
        guard let treningsfil, let data = try? JSONEncoder().encode(t) else { return }
        try? data.write(to: treningsfil, options: .atomic)
    }

    static func trening() -> Treningsbilde? {
        guard let treningsfil, let d = try? Data(contentsOf: treningsfil) else { return nil }
        return try? JSONDecoder().decode(Treningsbilde.self, from: d)
    }

    /// Henter et ferskt bilde direkte fra serveren.
    ///
    /// Widgeten kaller denne når appen ikke har vært åpen på en stund. Den dekoder
    /// **bare de feltene bildet trenger**, hver for seg: et nytt eller endret felt
    /// lenger inne i svaret skal ikke kunne tømme widgeten.
    static func hentTrening() async -> Treningsbilde? {
        guard let t = tilgang(),
              let u = URL(string: "https://\(t.vert)/api/trening/visning") else { return nil }
        var rq = URLRequest(url: u)
        rq.setValue("Bearer \(t.token)", forHTTPHeaderField: "Authorization")
        rq.timeoutInterval = 15
        guard let (d, svar) = try? await URLSession.shared.data(for: rq),
              (svar as? HTTPURLResponse)?.statusCode == 200,
              let rot = try? JSONSerialization.jsonObject(with: d) as? [String: Any]
        else { return nil }
        return bilde(av: (rot["data"] as? [String: Any]) ?? rot)
    }

    /// Plukker ut widget-feltene fra et ferdig parset svar.
    ///
    /// `JSONSerialization` framfor `Decodable` med vilje: her er det ingen struktur å
    /// bryte. Et felt som mangler eller har feil type gir `nil` for akkurat det feltet,
    /// og resten står.
    static func bilde(av data: [String: Any]) -> Treningsbilde {
        var b = Treningsbilde()
        let uke = data["uke"] as? [String: Any] ?? [:]
        b.generert = iso(data["generert"] as? String)
        b.streakUker = uke["streak_uker"] as? Int
        if let o = uke["okter"] as? [String: Any] {
            b.gjort = o["gjort"] as? Int
            b.mal = o["mal"] as? Int
        }
        b.styrke = uke["styrke"] as? Int
        b.lop = uke["lop"] as? Int
        b.godkjent = uke["godkjent"] as? Bool
        b.manglerKort = uke["mangler_kort"] as? String
        b.ukeSlutt = uke["slutt"] as? String
        b.ukenummer = ukenummer(uke["start"] as? String)
        b.forslag = (data["i_dag"] as? [String: Any])?["forslag"] as? String
        b.sovnTimer = (data["kontekst"] as? [String: Any])?["sovn_timer"] as? Double
        if let r = (data["form"] as? [String: Any])?["readiness"] as? [String: Any] {
            b.readinessScore = r["score"] as? Int
            b.readinessNiva = r["niva"] as? String
        }
        return b
    }

    private static func iso(_ s: String?) -> Date? {
        guard let s else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: s) ?? {
            f.formatOptions = [.withInternetDateTime]
            return f.date(from: s)
        }()
    }

    private static func ukenummer(_ start: String?) -> Int? {
        guard let start else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "nb_NO")
        f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: start) else { return nil }
        var k = Calendar(identifier: .iso8601)
        k.locale = Locale(identifier: "nb_NO")
        return k.component(.weekOfYear, from: d)
    }
}
