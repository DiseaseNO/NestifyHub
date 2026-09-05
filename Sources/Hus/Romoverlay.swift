import SwiftUI

/// Detaljene bak et kort: hvert lys for seg, med dimmer, og hver ovn med måltemperatur.
///
/// Kortet i oversikten sier «3 av 5 på». Det holder til å se, men ikke til å styre — og
/// en bryter som slår av alle fem er ikke det samme som å dimme det ene man sitter under.
/// Derfor denne: kortet er sammendraget, overlayet er tingene.
struct Romoverlay: View {
    let tittel: String
    let entiteter: [Husentitet]
    /// Sender kommandoen. Overlayet eier ikke data — det ber om en endring og viser det
    /// som kommer tilbake neste gang statusen hentes.
    let styr: (String, String, String, [String: Any]) async -> Void
    let jobber: Set<String>
    @Environment(\.dismiss) private var lukk

    var body: some View {
        NavigationStack {
            Innhold(entiteter: entiteter, styr: styr, jobber: jobber)
                .background(Farge.flate)
                .navigationTitle(tittel)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Farge.flate, for: .navigationBar)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Ferdig") { lukk() } } }
        }
    }
}

extension Romoverlay {

/// Selve lista. Ligger for seg fordi den brukes to steder: som overlay over et kort, og
/// som hele innholdet i en rom- eller egen-fane. Samme rader begge steder — ellers får
/// man to måter å dimme det samme lyset på, som før eller siden oppfører seg ulikt.
struct Innhold: View {
    let entiteter: [Husentitet]
    let styr: (String, String, String, [String: Any]) async -> Void
    let jobber: Set<String>

    private var lys: [Husentitet] { entiteter.filter { $0.domene == "light" } }
    private var brytere: [Husentitet] { entiteter.filter { $0.domene == "switch" } }
    private var klima: [Husentitet] { entiteter.filter { $0.domene == "climate" } }

    var body: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !lys.isEmpty {
                        seksjon("LYS") { ForEach(lys) { lysrad($0) } }
                    }
                    if !klima.isEmpty {
                        seksjon("VARME") { ForEach(klima) { klimarad($0) } }
                    }
                    if !brytere.isEmpty {
                        seksjon("BRYTERE") { ForEach(brytere) { bryterrad($0) } }
                    }
                    if entiteter.isEmpty {
                        Text("Ingenting å styre her.")
                            .font(.footnote).foregroundStyle(Farge.svak)
                    }
                }
                .padding(16)
            }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private func seksjon<Innhold: View>(_ navn: String,
                                        @ViewBuilder _ innhold: () -> Innhold) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(navn).font(.system(size: 9, weight: .semibold)).foregroundStyle(Farge.dempet)
            VStack(spacing: 10) { innhold() }
        }
    }

    private func lysrad(_ e: Husentitet) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(e.navn).font(.subheadline).foregroundStyle(Farge.tekst).lineLimit(1)
                    Stillemerke(dager: e.stille_dager)
                }
                Spacer()
                if jobber.contains(e.id) {
                    ProgressView().controlSize(.mini).tint(Farge.dempet)
                }
                Toggle("", isOn: Binding(
                    get: { e.paa },
                    set: { på in Task { await styr(e.id, "light", på ? "turn_on" : "turn_off",
                                                   ["entity_id": e.id]) } }))
                    .labelsHidden().tint(Farge.aksent).disabled(jobber.contains(e.id))
            }
            // Bare dimbare lys får slider. En av/på-pære med en dimmer som ikke gjør noe
            // er verre enn ingen dimmer.
            if e.dimbar {
                Dimmer(e: e, jobber: jobber.contains(e.id), styr: styr)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Farge.kort)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func bryterrad(_ e: Husentitet) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(e.navn).font(.subheadline).foregroundStyle(Farge.tekst).lineLimit(1)
                Stillemerke(dager: e.stille_dager)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { e.paa },
                set: { på in Task { await styr(e.id, "switch", på ? "turn_on" : "turn_off",
                                               ["entity_id": e.id]) } }))
                .labelsHidden().tint(Farge.aksent).disabled(jobber.contains(e.id))
        }
        .padding(12)
        .background(Farge.kort)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func klimarad(_ e: Husentitet) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(e.navn).font(.subheadline).foregroundStyle(Farge.tekst).lineLimit(1)
                HStack(spacing: 6) {
                    // Null grader er en verdi; «ingen måler» er noe annet.
                    if let t = e.temp { Text(String(format: "%.1f° nå", t)) }
                    if e.handling == "heating" {
                        Label("varmer", systemImage: "flame.fill").foregroundStyle(Farge.varm)
                    } else if e.handling == "idle" {
                        Text("hviler").foregroundStyle(Farge.svak)
                    }
                }
                .font(.caption2).foregroundStyle(Farge.svak)
                Stillemerke(dager: e.stille_dager)
            }
            Spacer()
            HStack(spacing: 6) {
                gradknapp("minus", e, -0.5)
                Text(e.maal.map { String(format: "%.1f°", $0) } ?? "–")
                    .font(.body.monospacedDigit()).foregroundStyle(Farge.tekst)
                    .frame(width: 56)
                gradknapp("plus", e, 0.5)
            }
        }
        .padding(12)
        .background(Farge.kort)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func gradknapp(_ ikon: String, _ e: Husentitet, _ delta: Double) -> some View {
        Button {
            guard let m = e.maal else { return }
            Task { await styr(e.id, "climate", "set_temperature",
                              ["entity_id": e.id, "temperature": m + delta]) }
        } label: {
            Image(systemName: ikon).font(.footnote)
                .frame(width: 34, height: 34)
                .background(Farge.kort2).foregroundStyle(Farge.tekst)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .disabled(e.maal == nil || jobber.contains(e.id))
    }
}

}   // extension Romoverlay

/// «Sist sett» for en enhet som har vært stille lenge.
///
/// Terskelen er en uke. Kortere ville merket alt som sjelden endrer seg — en utelampe
/// som står på hele høsten sier ingenting på ukevis, og den er ikke borte.
struct Stillemerke: View {
    let dager: Int?
    private var vis: Bool { (dager ?? 0) >= 7 }

    var body: some View {
        if vis, let d = dager {
            Label(d >= 60 ? "ikke hørt fra på \(d / 30) måneder" : "ikke hørt fra på \(d) døgn",
                  systemImage: "wifi.slash")
                .font(.system(size: 9)).foregroundStyle(Farge.svak)
        }
    }
}

/// Lysstyrke.
///
/// Verdien holdes lokalt mens man drar. Å sende ved hver bevegelse ville gitt titalls
/// kall i sekundet og et lys som blinker seg fram til målet — vi sender når fingeren
/// slippes. Mens man drar viser tallet der man er, ikke der lyset var.
private struct Dimmer: View {
    let e: Husentitet
    let jobber: Bool
    let styr: (String, String, String, [String: Any]) async -> Void
    @State private var verdi: Double?
    @State private var drar = false

    private var vises: Double { verdi ?? Double(e.lysstyrke ?? 0) }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sun.min").font(.caption2).foregroundStyle(Farge.svak)
            Slider(value: Binding(get: { vises }, set: { verdi = $0 }),
                   in: 1...100,
                   onEditingChanged: { igang in
                       drar = igang
                       guard !igang, let v = verdi else { return }
                       Task {
                           await styr(e.id, "light", "turn_on",
                                      ["entity_id": e.id, "brightness_pct": Int(v.rounded())])
                           // Slipp den lokale verdien først når serveren har svart, ellers
                           // hopper slideren tilbake til den gamle i et halvt sekund.
                           verdi = nil
                       }
                   })
                .tint(Farge.aksent)
                .disabled(!e.paa || jobber)
            Text("\(Int(vises.rounded()))%")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(drar ? Farge.tekst : Farge.svak)
                .frame(width: 38, alignment: .trailing)
        }
        .opacity(e.paa ? 1 : 0.4)
    }
}
