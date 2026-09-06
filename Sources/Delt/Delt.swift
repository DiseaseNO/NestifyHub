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
