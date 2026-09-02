import SwiftUI
import Charts

/// Detaljene om én spiller: hva han har levert, og om han leverte **til forventning**.
///
/// Poeng alene svarer ikke på «leverte han». To poeng i en kamp der vi ventet to er ikke
/// det samme som to der vi ventet åtte. Det er samme skille som `premiss_holdt` mot
/// `poeng_effekt` på beslutningsnivå — og den samme grunnen appen finnes.
struct FplSpillerark: View {
    let spiller: FplStatus.Spiller
    @Environment(\.dismiss) private var lukk

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    topp
                    if let l = spiller.levert, let r = l.runder, !r.isEmpty {
                        hosOss(l)
                        poengforløp(r)
                        avviksdel(l, r)
                        rundetabell(r)
                    } else {
                        Text("Ingen leveransehistorikk for denne spilleren ennå.")
                            .font(.footnote).foregroundStyle(Farge.svak)
                    }
                }
                .padding(16)
            }
            .background(Farge.flate)
            .scrollIndicators(.hidden)
            .navigationTitle(spiller.navn)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Farge.flate, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Lukk") { lukk() } } }
        }
    }

    // MARK: topp

    private var topp: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(spiller.posisjon).font(.caption2).foregroundStyle(Farge.svak)
                Text(spiller.klubb).font(.caption2).foregroundStyle(Farge.svak)
                if spiller.kaptein { merke("kaptein") } else if spiller.vise { merke("vise") }
                if !spiller.i_xi { merke("benk") }
                Spacer()
                Text(String(format: "%.1f", spiller.pris)).font(.caption.monospacedDigit())
                    .foregroundStyle(Farge.dempet)
            }
            if let k = spiller.kamp {
                Text("\(k.hjemme ? "Hjemme mot" : "Borte mot") \(k.mot) · vanskegrad \(k.vansker)")
                    .font(.caption).foregroundStyle(Farge.dempet)
            }
            // xP: egen modell er underkjent, så vi viser den uavhengige kilden.
            if let f = spiller.forventet, let x = f.xp_fplform {
                Forklar(nøkkel: "xp_fplform") {
                    Text(String(format: "Forventet nå: %.1f xP", x))
                        .font(.caption.monospacedDigit()).foregroundStyle(Diagramfarge.serie1)
                }
            }
            if let n = spiller.nyhet, !n.isEmpty {
                Label(n, systemImage: "exclamationmark.bubble").font(.caption2)
                    .foregroundStyle(Diagramfarge.varsel)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func merke(_ t: String) -> some View {
        Text(t).font(.system(size: 9)).padding(.horizontal, 6).padding(.vertical, 2)
            .background(Farge.kort2).foregroundStyle(Farge.dempet).clipShape(Capsule())
    }

    // MARK: hos oss

    /// `poeng_hos_oss` teller kapteinsdobling — det er poengene laget faktisk fikk,
    /// ikke spillerens egne.
    private func hosOss(_ l: FplStatus.Spiller.Levert) -> some View {
        HStack(spacing: 12) {
            tall("\(l.poeng_hos_oss ?? 0)", "poeng hos oss")
            tall(l.snitt_hos_oss.map { String(format: "%.1f", $0) } ?? "—", "i snitt")
            tall("\(l.runder_eid ?? 0)", "runder eid")
            Spacer()
        }
    }

    private func tall(_ verdi: String, _ tittel: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(verdi).font(.title3.weight(.medium).monospacedDigit()).foregroundStyle(Farge.tekst)
            Text(tittel).font(.system(size: 10)).foregroundStyle(Farge.dempet)
        }
    }

    // MARK: poeng

    /// Sparkline: sekvensen, uten akser. Formen er poenget, ikke avlesningen — tallene
    /// står i tabellen under.
    private func poengforløp(_ r: [FplStatus.Spiller.Levert.Runde]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("POENG PER RUNDE").font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Farge.dempet)
            Chart {
                ForEach(r) { x in
                    LineMark(x: .value("Runde", x.runde), y: .value("Poeng", x.poeng ?? 0))
                        .foregroundStyle(Diagramfarge.serie1)
                        .interpolationMethod(.monotone)
                    PointMark(x: .value("Runde", x.runde), y: .value("Poeng", x.poeng ?? 0))
                        // Hul prikk for runder vi ikke eide ham: han leverte, men ikke for oss.
                        .foregroundStyle(x.i_troppen == true ? Diagramfarge.serie1 : Farge.strek)
                        .symbolSize(70)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: max(40, CGFloat(min(r.count, 10)) * 12))
            // Legenden bare når den forklarer noe: eide vi ham hele veien, finnes det
            // ingen hule prikker å forklare.
            if r.contains(where: { $0.i_troppen != true }) {
                HStack(spacing: 5) {
                    Circle().fill(Farge.strek).frame(width: 7, height: 7)
                    Text("runder vi ikke eide ham").font(.system(size: 9)).foregroundStyle(Farge.svak)
                }
            }
        }
    }

    // MARK: avvik

    /// Avvik mot forventning: stolper om nullinjen. Over/under er polaritet, ikke
    /// magnitude, så nullinjen må være synlig og felles.
    ///
    /// Snittet vises IKKE før dekningen tillater det — et snitt over én runde ser like
    /// autoritativt ut som et over ti.
    @ViewBuilder
    private func avviksdel(_ l: FplStatus.Spiller.Levert, _ r: [FplStatus.Spiller.Levert.Runde]) -> some View {
        let målte = r.filter { $0.avvik != nil }
        VStack(alignment: .leading, spacing: 6) {
            Text("MOT FORVENTNING").font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Farge.dempet)
            if målte.isEmpty {
                Text("Ingen bevart forventning ennå. Arkivet startet 2. september, så "
                     + "runder før det kan ikke bedømmes.")
                    .font(.caption2).foregroundStyle(Farge.svak)
                    .fixedSize(horizontal: false, vertical: true)
                if let d = l.avvik_dekning {
                    Text("Dekning: \(d) runder").font(.system(size: 10)).foregroundStyle(Farge.svak)
                }
            } else {
                Chart {
                    RuleMark(y: .value("Null", 0)).foregroundStyle(Farge.strek)
                    ForEach(målte) { x in
                        BarMark(x: .value("Runde", "\(x.runde)"), y: .value("Avvik", x.avvik ?? 0))
                            .foregroundStyle((x.avvik ?? 0) >= 0 ? Diagramfarge.god : Diagramfarge.alvorlig)
                    }
                }
                .chartYAxis(.hidden)
                .frame(height: 80)
                HStack(spacing: 6) {
                    // Snittet bare når det hviler på mer enn én runde.
                    if let s = l.avvik_snitt, let d = l.dekning, d.av > 1 {
                        Text(String(format: "snitt %+.1f", s)).font(.caption.monospacedDigit())
                            .foregroundStyle(Farge.dempet)
                    }
                    if let d = l.avvik_dekning {
                        Text("dekning \(d)").font(.system(size: 10)).foregroundStyle(Farge.svak)
                    }
                }
            }
        }
    }

    // MARK: tabell

    /// xG og poeng i samme rad, men ikke samme akse — en spiller med høy xG og få poeng
    /// er hele historien, og den forsvinner hvis de deler y-akse.
    private func rundetabell(_ r: [FplStatus.Spiller.Levert.Runde]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("RUNDE FOR RUNDE").font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Farge.dempet)
            ForEach(r.sorted { $0.runde > $1.runde }) { x in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("R\(x.runde)").font(.caption.monospacedDigit()).foregroundStyle(Farge.dempet)
                        .frame(width: 30, alignment: .leading)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text("\(x.poeng ?? 0) p").font(.caption.weight(.medium).monospacedDigit())
                                .foregroundStyle(x.i_troppen == true ? Farge.tekst : Farge.svak)
                            if let b = x.bonus, b > 0 {
                                Text("+\(b) bonus").font(.system(size: 9)).foregroundStyle(Farge.svak)
                            }
                            Text(x.rolle).font(.system(size: 9)).foregroundStyle(Farge.svak)
                        }
                        HStack(spacing: 8) {
                            if let g = x.xg { Text(String(format: "xG %.2f", g)) }
                            if let a = x.xa, a > 0 { Text(String(format: "xA %.2f", a)) }
                            if let m = x.minutter { Text("\(m) min") }
                        }
                        .font(.system(size: 10).monospacedDigit()).foregroundStyle(Farge.svak)
                    }
                    Spacer()
                    if let a = x.avvik {
                        Text(String(format: "%+.1f", a)).font(.caption.monospacedDigit())
                            .foregroundStyle(a >= 0 ? Diagramfarge.god : Diagramfarge.alvorlig)
                    }
                }
                .padding(.vertical, 3)
            }
        }
    }
}
