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
}
