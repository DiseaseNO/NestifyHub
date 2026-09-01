import SwiftUI

/// FPL-modulen: fire skjermer, med statusen delt mellom Nå og Helse.
///
/// Beslutningen og Historikk henter hver sin fil ved åpning — de endrer seg sjeldnere
/// enn statusen og trenger ingen løkke.
struct FplModul: View {
    let api: API
    @State private var lager: FplLager
    /// Hvilken fane som er åpen. Settes bare av CI (se `Testskjerm`); i appen er det
    /// alltid «Nå» som møter deg.
    @State private var valgt: Int

    init(api: API, start: Int = 0) {
        self.api = api
        _lager = State(initialValue: FplLager(api: api))
        _valgt = State(initialValue: start)
    }

    var body: some View {
        TabView(selection: $valgt) {
            NavigationStack { FplNaa(lager: lager) }
                .tag(0)
                .tabItem { Label("Nå", systemImage: "clock") }
            NavigationStack { FplBeslutning(api: api) }
                .tag(1)
                .tabItem { Label("Beslutningen", systemImage: "arrow.triangle.branch") }
            NavigationStack { FplHistorikk_Visning(api: api) }
                .tag(2)
                .tabItem { Label("Historikk", systemImage: "list.bullet.rectangle") }
            NavigationStack { FplHelse(lager: lager) }
                .tag(3)
                .tabItem { Label("Helse", systemImage: "waveform.path.ecg") }
        }
    }
}
