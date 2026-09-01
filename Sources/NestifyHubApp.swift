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
                if !api.erKlar {
                    Paring(api: api)
                } else if let start = Testskjerm.valgt {
                    // CI hopper rett inn i én skjerm; ellers ville skjermbildene krevd
                    // simulerte trykk, som er skjørt og trenger vedlikehold.
                    FplModul(api: api, start: start)
                } else {
                    Hovedvisning(api: api)
                }
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

/// Hvilken skjerm CI skal åpne rett i, gitt som `-skjerm naa|beslutning|historikk|helse`.
/// Utenfor DEBUG er `valgt` alltid `nil`, så koden finnes ikke i det som installeres.
enum Testskjerm {
    static var valgt: Int? {
        #if DEBUG
        switch UserDefaults.standard.string(forKey: "skjerm") {
        case "naa": 0
        case "beslutning": 1
        case "historikk": 2
        case "helse": 3
        default: nil
        }
        #else
        nil
        #endif
    }
}

/// Modulvelgeren.
struct Hovedvisning: View {
    let api: API

    var body: some View {
        NavigationStack {
            ZStack {
                Farge.flate.ignoresSafeArea()
                List {
                    Section {
                        NavigationLink { FplModul(api: api) } label: {
                            modul("Fantasy", "sportscourt", "anbefaling, tropp og helse")
                        }
                    } header: {
                        Text("Moduler").font(.caption).foregroundStyle(Farge.dempet)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
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

    private func modul(_ tittel: String, _ ikon: String, _ under: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: ikon).font(.footnote).foregroundStyle(Farge.aksent).frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(tittel).font(.subheadline).foregroundStyle(Farge.tekst)
                Text(under).font(.caption2).foregroundStyle(Farge.svak)
            }
        }
    }
}
