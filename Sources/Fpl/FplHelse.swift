import SwiftUI

/// «Helse» — kilder, sperrer, kvote og modellstatus.
///
/// Denne skjermen finnes fordi ting har stått og feilet i stillhet før. Den skal svare på
/// «virker maskineriet?» uten at man må lete i logger.
struct FplHelse: View {
    let lager: FplLager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let s = lager.svar {
                    kilder(s.data)
                    sperrer(s.data)
                    kvote(s.data)
                    modell(s.data)
                    risikoer(s.data)
                    Ordlisteknapp()
                } else if let f = lager.feil {
                    Label(f, systemImage: "exclamationmark.triangle")
                        .font(.footnote).foregroundStyle(Farge.avvik)
                } else {
                    ProgressView().tint(Farge.dempet).frame(maxWidth: .infinity).padding(.top, 40)
                }
            }
            .padding(16)
        }
        .background(Farge.flate)
        .scrollIndicators(.hidden)
        .navigationTitle("Helse")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Farge.flate, for: .navigationBar)
        .refreshable { await lager.last() }
        // Lageret deles med «Nå», men Helse kan være det første man ser (dyplenke, eller
        // fanen man forlot appen på). Uten dette ble den stående på spinneren for alltid.
        .task { if lager.svar == nil { await lager.last() } }
    }

    // MARK: kilder

    /// Ikke et diagram. Liste med statusfarge PLUSS ikon og etikett — farge bærer aldri
    /// mening alene.
    ///
    /// Vi viser både HTTP-koden og innholdstreffene, fordi en kilde som svarer 200 og
    /// leverer tomhet er verre enn en som svarer 500. `innholdstreff = null` betyr
    /// «ikke målt», ikke «null treff» — de to må ikke se like ut.
    private func kilder(_ d: FplStatus) -> some View {
        boks("Datakilder") {
            ForEach(d.kilder) { k in
                HStack(spacing: 8) {
                    Image(systemName: Diagramfarge.statusIkon(k.status))
                        .font(.caption).foregroundStyle(Diagramfarge.status(k.status))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(k.navn).font(.caption.weight(.medium)).foregroundStyle(Farge.tekst)
                        Text(k.status).font(.system(size: 10)).foregroundStyle(Diagramfarge.status(k.status))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(k.http.map { "HTTP \($0)" } ?? "—")
                            .font(.system(size: 10).monospacedDigit()).foregroundStyle(Farge.dempet)
                        Text(k.innholdstreff.map { "\($0) treff" } ?? "innhold ikke målt")
                            .font(.system(size: 10)).foregroundStyle(Farge.svak)
                    }
                }
            }
        }
    }

    // MARK: sperrer

    /// Sluttkoden ER statusen: 0 ok, 1 varsel (en vurdering — **ikke** en feil),
    /// alt annet betyr at verktøyet selv feilet.
    private func sperrer(_ d: FplStatus) -> some View {
        boks("Forkontroll") {
            ForEach(d.sjekker) { s in
                DisclosureGroup {
                    if let u = s.utdata, !u.isEmpty {
                        Text(u)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Farge.dempet)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 4)
                    } else {
                        Text("Ingen utdata.").font(.caption2).foregroundStyle(Farge.svak)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: Diagramfarge.statusIkon(s.status))
                            .font(.caption).foregroundStyle(Diagramfarge.status(s.status))
                        Text(s.navn).font(.caption).foregroundStyle(Farge.tekst)
                        Spacer()
                        Forklar(nøkkel: s.status) {
                            Text(Ordliste.etikett(s.status).lowercased())
                                .font(.system(size: 10)).foregroundStyle(Diagramfarge.status(s.status))
                                .underline(Ordliste.finn(s.status) != nil, pattern: .dot)
                        }
                    }
                }
                .tint(Farge.dempet)
            }
        }
    }

    // MARK: kvote

    /// Én ratio mot en grense — det er en meter, ikke et kakediagram og ikke en stolpe.
    private func kvote(_ d: FplStatus) -> some View {
        boks("Odds-kvote") {
            let igjen = d.odds_kvote_igjen ?? 0
            let andel = min(1, max(0, Double(igjen) / 500))
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(igjen) av 500 igjen denne måneden")
                        .font(.caption).foregroundStyle(Farge.tekst)
                    Spacer()
                    Text("\(Int(andel * 100)) %")
                        .font(.caption.monospacedDigit()).foregroundStyle(Farge.dempet)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Farge.kort2)
                        Capsule()
                            .fill(andel < 0.2 ? Diagramfarge.kritisk : (andel < 0.4 ? Diagramfarge.varsel : Diagramfarge.god))
                            .frame(width: max(2, geo.size.width * andel))
                    }
                }
                .frame(height: 6)
            }
        }
    }

    // MARK: modell

    /// xP-modellen er per nå **underkjent** og bærer ingen konklusjon. Vises den uten det
    /// forbeholdet, lyver skjermen.
    private func modell(_ d: FplStatus) -> some View {
        boks("Modellstatus") {
            Label("Underkjent — bærer ingen konklusjon", systemImage: "exclamationmark.triangle.fill")
                .font(.caption.weight(.medium)).foregroundStyle(Diagramfarge.varsel)
            // Statusen er vaktas arbeidsnotat, ofte et par skjermlengder. Dommen over
            // står alltid; notatet ligger ett trykk unna for den som vil ha begrunnelsen.
            if let k = d.modell_status_sammendrag {
                Text(k).font(.caption).foregroundStyle(Farge.dempet)
                    .fixedSize(horizontal: false, vertical: true)
            }
            DisclosureGroup("Vaktas notat") {
                Text(d.modell_status ?? "ingen status")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Farge.dempet)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
            .font(.caption2)
            .tint(Farge.svak)
            .foregroundStyle(Farge.dempet)
        }
    }

    private func risikoer(_ d: FplStatus) -> some View {
        Group {
            if let r = d.aapne_risikoer, !r.isEmpty {
                boks("Kjente risikoer (\(r.count))") {
                    ForEach(r) { x in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(x.overskrift).font(.caption.weight(.medium))
                                .foregroundStyle(Farge.tekst)
                                .fixedSize(horizontal: false, vertical: true)
                            if let k = x.sammendrag {
                                Text(k).font(.caption2).foregroundStyle(Farge.dempet)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            if x.tittel != nil || x.sammendrag != nil, !x.tekst.isEmpty {
                                DisclosureGroup("Hele notatet") {
                                    Text(x.tekst).font(.system(size: 10)).foregroundStyle(Farge.svak)
                                        .fixedSize(horizontal: false, vertical: true).padding(.top, 3)
                                }
                                .font(.system(size: 10)).tint(Farge.svak)
                            }
                        }
                    }
                }
            }
        }
    }

    private func boks<I: View>(_ tittel: String, @ViewBuilder _ innhold: () -> I) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(tittel.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(Farge.dempet)
            VStack(alignment: .leading, spacing: 8) { innhold() }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Farge.kort)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}
