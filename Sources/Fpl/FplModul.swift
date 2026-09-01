import SwiftUI

/// FPL-modulen: to skjermer over én felles henting.
///
/// «Beslutningen» og «Historikk» mangler bevisst. Kontrakten har ingen strukturert
/// triangulering, og beslutningshistorikken er ikke maskinlesbar ennå — begge er meldt
/// til FPL-siden. Å bygge dem på fritekst ville gitt et grensesnitt som later som det
/// vet mer enn det gjør.
struct FplModul: View {
    @State private var lager: FplLager

    init(api: API) { _lager = State(initialValue: FplLager(api: api)) }

    var body: some View {
        TabView {
            NavigationStack { FplNaa(lager: lager) }
                .tabItem { Label("Nå", systemImage: "clock") }
            NavigationStack { FplHelse(lager: lager) }
                .tabItem { Label("Helse", systemImage: "waveform.path.ecg") }
        }
    }
}
