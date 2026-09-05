import SwiftUI

/// Modulregisteret.
///
/// Hjemskjermen bygges av denne lista, ikke av en håndskrevet `NavigationLink` per
/// modul. Da holder det å legge til én rad her for at en ny modul dukker opp — og,
/// viktigere, at den kan slås av og flyttes uten at noen rører hjemskjermen.
///
/// `id` er nøkkelen som lagres i oppsettet. **Den skal aldri endres**: gjør man det,
/// mister brukeren rekkefølgen sin og modulen kommer tilbake som «ny».
struct Modul: Identifiable {
    let id: String
    let navn: String
    let ikon: String
    let undertekst: String
    /// Bygges først når modulen åpnes — ellers ville alle modulene hentet data samtidig
    /// hver gang hjemskjermen tegnes.
    let visning: (API) -> AnyView

    static func alle() -> [Modul] {
        [
            Modul(id: "fpl", navn: "Fantasy", ikon: "sportscourt",
                  undertekst: "anbefaling, tropp og helse") { AnyView(FplModul(api: $0)) },
            Modul(id: "hus", navn: "Huset", ikon: "house",
                  undertekst: "lys, varme og forbruk") { AnyView(HusModul(api: $0)) },
        ]
    }
}

/// Brukerens eget oppsett: hvilke moduler som vises, og i hvilken rekkefølge.
///
/// Lagres i **app-gruppa**, ikke i appens egen `UserDefaults`. Widgeten skal kunne
/// respektere det samme valget senere, og da må begge prosessene lese fra samme sted.
///
/// Nye moduler dukker opp automatisk nederst. Alternativet — å skjule dem til brukeren
/// finner dem i innstillingene — betyr at en modul kan bli levert og aldri sett.
@Observable
final class Oppsett {
    private static let nøkkel = "modulrekkefølge"
    private static let skjultNøkkel = "skjultemoduler"
    private let lager = UserDefaults(suiteName: Delt.gruppe) ?? .standard

    private(set) var rekkefølge: [String]
    private(set) var skjult: Set<String>

    init() {
        rekkefølge = lager.stringArray(forKey: Self.nøkkel) ?? Modul.alle().map(\.id)
        skjult = Set(lager.stringArray(forKey: Self.skjultNøkkel) ?? [])
    }

    /// Modulene i brukerens rekkefølge. Ukjente id-er i lageret ignoreres — de kan være
    /// moduler som er fjernet i en senere versjon.
    var synlige: [Modul] {
        sortert.filter { !skjult.contains($0.id) }
    }

    var sortert: [Modul] {
        let alle = Modul.alle()
        let kjent = rekkefølge.compactMap { id in alle.first { $0.id == id } }
        let nye = alle.filter { m in !rekkefølge.contains(m.id) }
        return kjent + nye
    }

    func flytt(fra: IndexSet, til: Int) {
        var ids = sortert.map(\.id)
        ids.move(fromOffsets: fra, toOffset: til)
        rekkefølge = ids
        lager.set(ids, forKey: Self.nøkkel)
    }

    func settSynlig(_ id: String, _ på: Bool) {
        if på { skjult.remove(id) } else { skjult.insert(id) }
        lager.set(Array(skjult), forKey: Self.skjultNøkkel)
        // Rekkefølgen skrives også, så en modul som skjules og vises igjen havner der
        // den lå — ikke nederst som en ny.
        rekkefølge = sortert.map(\.id)
        lager.set(rekkefølge, forKey: Self.nøkkel)
    }

    func nullstill() {
        rekkefølge = Modul.alle().map(\.id)
        skjult = []
        lager.removeObject(forKey: Self.nøkkel)
        lager.removeObject(forKey: Self.skjultNøkkel)
    }
}
