import SwiftUI

/// FPL-modulen: fire skjermer, med statusen delt mellom Nå og Helse.
///
/// Beslutningen og Historikk henter hver sin fil ved åpning — de endrer seg sjeldnere
/// enn statusen og trenger ingen løkke.
struct FplModul: View {
    let api: API
    @State private var lager: FplLager

    init(api: API) {
        self.api = api
        _lager = State(initialValue: FplLager(api: api))
    }

    var body: some View {
        TabView {
            NavigationStack { FplNaa(lager: lager) }
                .tabItem { Label("Nå", systemImage: "clock") }
            NavigationStack { FplBeslutning(api: api) }
                .tabItem { Label("Beslutningen", systemImage: "arrow.triangle.branch") }
            NavigationStack { FplHistorikk_Visning(api: api) }
                .tabItem { Label("Historikk", systemImage: "list.bullet.rectangle") }
            NavigationStack { FplHelse(lager: lager) }
                .tabItem { Label("Helse", systemImage: "waveform.path.ecg") }
        }
    }
}
