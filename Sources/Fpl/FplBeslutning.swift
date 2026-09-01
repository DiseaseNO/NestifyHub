import SwiftUI
import Charts

/// «Beslutningen» — trianguleringen.
///
/// Jobben er: to alternativer, N signaler, hvilken vei peker hvert av dem.
///
/// **Formen er dumbbell**, ett par per signal: venstre prikk = A, høyre = B, linje mellom.
/// Ikke grupperte stolper — leseren skal se RETNINGEN per signal, ikke sammenligne høyder
/// på tvers av rader som har helt ulike enheter.
///
/// **Fargen er én hue i to nyanser.** To alternativer er ikke identitet nok til å bruke to
/// kategoriske farger; da ville de konkurrert med statusfargene om betydning.
///
/// **Framover/bakover merkes med ikon og tekst — aldri med farge**, som allerede er brukt
/// til A/B. Det er den viktigste enkeltopplysningen her: et argument på fire bein der tre
/// ser bakover er svakere enn det høres ut.
struct FplBeslutning: View {
    let api: API
    @State private var tri: FplTriangulering?
    @State private var lastet = false

    private let lys = Diagramfarge.serie1.opacity(0.55)
    private let mørk = Diagramfarge.serie1

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let t = tri {
                    ForEach(t.beslutninger) { b in kort(b) }
                } else if lastet {
                    Text("Ingen beslutninger å vise.").font(.footnote).foregroundStyle(Farge.svak)
                } else {
                    ProgressView().tint(Farge.dempet).frame(maxWidth: .infinity).padding(.top, 40)
                }
            }
            .padding(16)
        }
        .background(Farge.flate)
        .scrollIndicators(.hidden)
        .navigationTitle("Beslutningen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Farge.flate, for: .navigationBar)
        .task {
            tri = await FplLager(api: api).hentTriangulering(api)
            lastet = true
        }
    }

    // MARK: ett beslutningskort

    @ViewBuilder
    private func kort(_ b: FplTriangulering.Beslutning) -> some View {
        let a = b.alternativer.first { $0.nokkel == "A" }
        let bb = b.alternativer.first { $0.nokkel == "B" }
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(b.sporsmal).font(.subheadline.weight(.medium)).foregroundStyle(Farge.tekst)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(b.type).font(.caption2).foregroundStyle(Farge.svak)
                }
                Spacer()
                statusmerke(b.status)
            }

            legende(a?.navn ?? "A", bb?.navn ?? "B")
            dumbbell(b)
            if let s = b.signalsum { balanse(s) }

            if let k = b.konklusjon {
                avsnitt("Konklusjon", k, Farge.tekst)
            }
            if let u = b.usikkerhet {
                avsnitt("Usikkerhet", u, Diagramfarge.varsel)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Farge.kort)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func statusmerke(_ s: String) -> some View {
        let farge: Color = s == "anbefalt" ? Diagramfarge.god : (s == "forkastet" ? Farge.svak : Diagramfarge.varsel)
        return Text(s)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(farge.opacity(0.18)).foregroundStyle(farge)
            .clipShape(Capsule())
    }

    /// Legende ALLTID ved to serier, og plassert OVER diagrammet — under kolliderer den
    /// med hjemindikatoren.
    private func legende(_ navnA: String, _ navnB: String) -> some View {
        HStack(spacing: 14) {
            HStack(spacing: 5) {
                Circle().fill(lys).frame(width: 9, height: 9)
                Text(navnA).font(.caption2).foregroundStyle(Farge.dempet)
            }
            HStack(spacing: 5) {
                Circle().fill(mørk).frame(width: 9, height: 9)
                Text(navnB).font(.caption2).foregroundStyle(Farge.dempet)
            }
        }
    }

    /// Ett par per signal. X er normalisert per RAD — radene har ulike enheter (%, xP,
    /// antall), så en delt skala ville sammenlignet epler og pærer. Den største verdien i
    /// paret ligger på 1,0, og avstanden viser hvor mye som skiller. De faktiske tallene
    /// står ved siden av, med enhet.
    private func dumbbell(_ b: FplTriangulering.Beslutning) -> some View {
        VStack(spacing: 10) {
            ForEach(b.signaler) { s in
                // `?? nil` fordi oppslaget gir `Double??` — nøkkelen kan mangle, og
                // verdien kan være null. Begge betyr «ikke målt», aldri null i verdi.
                let va = (s.verdier["A"] ?? nil)
                let vb = (s.verdier["B"] ?? nil)
                let maks = max(abs(va ?? 0), abs(vb ?? 0))
                let na = maks > 0 ? abs(va ?? 0) / maks : 0
                let nb = maks > 0 ? abs(vb ?? 0) / maks : 0

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        // Retningen som IKON + TEKST. Aldri farge — den er opptatt.
                        Image(systemName: s.serFramover ? "arrow.forward.circle" : "arrow.uturn.backward.circle")
                            .font(.system(size: 10))
                        Text(s.navn).font(.caption2).foregroundStyle(Farge.tekst)
                        Text(s.serFramover ? "framover" : "bakover")
                            .font(.system(size: 9)).foregroundStyle(Farge.svak)
                        if let v = s.vekt, v != "middels" {
                            Text("vekt \(v == "hoy" ? "høy" : v)")
                                .font(.system(size: 9)).foregroundStyle(Farge.svak)
                        }
                        Spacer()
                    }
                    .foregroundStyle(Farge.dempet)

                    // Et umålt signal tegnes ikke. En prikk på null ville sett ut som
                    // et svar, og påstått noe dataene ikke sier.
                    if va == nil && vb == nil {
                        Text("ikke målt ennå")
                            .font(.system(size: 10)).foregroundStyle(Farge.svak)
                            .frame(height: 22, alignment: .leading)
                    } else {
                    Chart {
                        RuleMark(xStart: .value("A", na), xEnd: .value("B", nb), y: .value("Signal", s.navn))
                            .foregroundStyle(Farge.strek)
                            .lineStyle(.init(lineWidth: 2))
                        if va != nil {
                            PointMark(x: .value("A", na), y: .value("Signal", s.navn))
                                .foregroundStyle(lys).symbolSize(90)
                        }
                        if vb != nil {
                            PointMark(x: .value("B", nb), y: .value("Signal", s.navn))
                                .foregroundStyle(mørk).symbolSize(90)
                        }
                    }
                    .chartXScale(domain: -0.08...1.08)
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(height: 22)
                    }

                    HStack {
                        Text(tall(va, s.enhet)).font(.system(size: 10).monospacedDigit()).foregroundStyle(lys)
                        Text("·").foregroundStyle(Farge.strek)
                        Text(tall(vb, s.enhet)).font(.system(size: 10).monospacedDigit()).foregroundStyle(mørk)
                        Spacer()
                        if let p = s.peker_mot {
                            Text(p == "uavgjort" ? "uavgjort" : "peker mot \(p)")
                                .font(.system(size: 9)).foregroundStyle(Farge.svak)
                        }
                    }
                }
            }
        }
    }

    private func tall(_ v: Double?, _ enhet: String?) -> String {
        guard let v else { return "–" }
        let s = v == v.rounded() ? String(Int(v)) : String(format: "%.2f", v)
        guard let e = enhet, !e.isEmpty else { return s }
        return e == "%" ? "\(s) %" : "\(s) \(e)"
    }

    /// Signalbalansen i klartekst. Poenget er ikke hvor mange bein argumentet har, men
    /// hvor mange av dem som ser framover.
    private func balanse(_ s: FplTriangulering.Beslutning.Signalsum) -> some View {
        HStack(spacing: 10) {
            Label("\(s.framover ?? 0) framover", systemImage: "arrow.forward.circle")
            Label("\(s.bakover ?? 0) bakover", systemImage: "arrow.uturn.backward.circle")
            Spacer()
            Text("A \(s.peker_mot_A ?? 0) – \(s.peker_mot_B ?? 0) B")
                .font(.caption2.monospacedDigit())
        }
        .font(.caption2)
        .foregroundStyle(Farge.dempet)
        .padding(.top, 2)
    }

    private func avsnitt(_ tittel: String, _ tekst: String, _ farge: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(tittel.uppercased()).font(.system(size: 9, weight: .semibold)).foregroundStyle(Farge.dempet)
            Text(tekst).font(.caption2).foregroundStyle(farge)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
