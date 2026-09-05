import SwiftUI

/// «Hus» — lys, varme og forbruk, rom for rom.
///
/// Leser husmodellen og statusen fra backend. Appen regner ikke ut noe selv; den viser
/// hva serveren sier, av samme grunn som nettbrettet gjør det: to klienter som regner
/// hver for seg, kommer fram til forskjellige svar.
///
/// Enhetsrollen `hjemme` har foreløpig bare lesetilgang, så dette er en oversikt — ikke
/// en fjernkontroll. Styring krever en skrivesti, og den skal bestilles bevisst.
struct HusModul: View {
    let api: API
    @State private var status: Husstatus?
    @State private var feil: String?
    @Environment(\.scenePhase) private var scenefase

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let s = status {
                        topp(s)
                        ForEach(s.rom) { romrad($0) }
                    } else if let feil {
                        Label(feil, systemImage: "exclamationmark.triangle")
                            .font(.footnote).foregroundStyle(Farge.avvik)
                    } else {
                        ProgressView().tint(Farge.dempet).frame(maxWidth: .infinity).padding(.top, 40)
                    }
                }
                .padding(16)
            }
            .background(Farge.flate)
            .scrollIndicators(.hidden)
            .navigationTitle("Huset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Farge.flate, for: .navigationBar)
            .refreshable { await hent() }
            .task { await hent() }
            .onChange(of: scenefase) { _, ny in if ny == .active { Task { await hent() } } }
        }
    }

    private func hent() async {
        do {
            let s = try await api.hent(Husstatus.self, "/api/hus/status")
            status = s; feil = nil
            // Legg igjen et øyeblikksbilde til widgeten. Den kjører i sin egen prosess og
            // har ingen annen vei til dette når den vekkes uten nett.
            Delt.lagre(.init(effektWatt: s.effekt_watt, lysPaa: s.lys_paa,
                             kroner: nil, oppdatert: Date()))
        } catch {
            feil = error.localizedDescription
        }
    }

    private func topp(_ s: Husstatus) -> some View {
        HStack(spacing: 14) {
            tall(s.effekt_watt.map { String(format: "%.1f", Double($0) / 1000) } ?? "–", "kW nå")
            tall("\(s.lys_paa)", "lys på")
            tall("\(s.rom.filter { $0.klima == "varmer" }.count)", "rom varmer")
            Spacer()
        }
    }

    private func tall(_ verdi: String, _ tekst: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(verdi).font(.title2.weight(.medium).monospacedDigit()).foregroundStyle(Farge.tekst)
            Text(tekst).font(.caption2).foregroundStyle(Farge.dempet)
        }
    }

    private func romrad(_ r: Husstatus.Romstatus) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(r.navn).font(.subheadline.weight(.medium)).foregroundStyle(Farge.tekst)
                HStack(spacing: 8) {
                    if r.lys_totalt > 0 {
                        Label("\(r.lys_paa) av \(r.lys_totalt)", systemImage: r.lys_paa > 0 ? "lightbulb.fill" : "lightbulb")
                            .foregroundStyle(r.lys_paa > 0 ? Farge.aksent : Farge.svak)
                    }
                    // Ikon OG tekst; fargen alene skal ikke bære betydningen.
                    if let k = r.klima, k != "av" {
                        Label(k == "varmer" ? "varmer" : "kjøler",
                              systemImage: k == "varmer" ? "flame.fill" : "snowflake")
                            .foregroundStyle(k == "varmer" ? Farge.varm : Farge.kjol)
                    }
                }
                .font(.caption2)
            }
            Spacer()
            // Null grader er en verdi; «ingen måler» er noe annet. Derfor strek, ikke 0.
            if let t = r.temp {
                Text(String(format: "%.1f°", t))
                    .font(.title3.monospacedDigit()).foregroundStyle(Farge.dempet)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Farge.kort)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
