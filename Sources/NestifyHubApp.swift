import SwiftUI

/// Nestify Hub — samleapp for husholdet.
///
/// Modulene kommer én for én. Skallet er bevisst tynt: det eier bare innloggingen og
/// navigasjonen, og hver modul står for seg selv.
@main
struct NestifyHubApp: App {
    @State private var api: API

    init() {
        #if DEBUG
        seedFraOppstartsargumenter()   // må skje FØR API() leser Keychain
        #endif
        _api = State(initialValue: API())
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if api.erKlar { Hovedvisning(api: api) } else { Paring(api: api) }
            }
            .preferredColorScheme(.dark)
            .tint(Farge.aksent)
            // Appen er på norsk; uten dette arver den enhetens locale og viser
            // klokkeslett som «7:36 PM».
            .environment(\.locale, Locale(identifier: "nb_NO"))
        }
    }
}

#if DEBUG
/// Testvei for simulator i CI: oppstartsargumentene `-server <vert> -token <tok>` legges
/// rett i Keychain, så skjermbilde-testene kommer forbi paringen.
///
/// Kompileres KUN inn i DEBUG. TestFlight-byggene er Release og inneholder ikke denne
/// koden — det finnes altså ingen omvei rundt paringen i det du installerer.
private func seedFraOppstartsargumenter() {
    let d = UserDefaults.standard
    let vert = d.string(forKey: "server") ?? ""
    let token = d.string(forKey: "token") ?? ""
    guard !vert.isEmpty, !token.isEmpty else { return }
    Nøkkelring.skriv(vert, for: "vert")
    Nøkkelring.skriv(token, for: "token")
}
#endif

/// Modulvelgeren. Foreløpig tom — modulene legges inn her etter hvert.
struct Hovedvisning: View {
    let api: API

    var body: some View {
        NavigationStack {
            ZStack {
                Farge.flate.ignoresSafeArea()
                VStack(spacing: 10) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(Farge.aksent)
                    Text("Tilkoblet")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(Farge.tekst)
                    Text("Ingen moduler ennå.")
                        .font(.footnote)
                        .foregroundStyle(Farge.dempet)
                }
            }
            .navigationTitle("Nestify Hub")
            .toolbarBackground(Farge.flate, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive) { api.glemEnhet() } label: {
                            Label("Glem denne enheten", systemImage: "xmark.circle")
                        }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
        }
    }
}
