import SwiftUI

/// «Historikk» — beslutninger med utfall.
///
/// Det avgjørende skillet, som må være synlig i designet: **var resonnementet riktig**
/// kontra **gikk det bra**. Det er ikke samme sak, og begge logges. En beslutning kan
/// holde og likevel tape poeng.
///
/// Derfor: sortert KRONOLOGISK, aldri på poeng. Å rangere på utfall belønner flaks og
/// skjuler resonnement.
struct FplHistorikk_Visning: View {
    let api: API
    @State private var hist: FplHistorikk?
    @State private var lastet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let h = hist {
                    Text("Premisset er om resonnementet holdt. Poengene er hva det ga. "
                         + "De to henger ikke nødvendigvis sammen.")
                        .font(.caption2).foregroundStyle(Farge.svak)
                        .fixedSize(horizontal: false, vertical: true)
                    // Nyeste runde øverst, men beslutningene INNI hver runde står i
                    // rekkefølgen de ble tatt.
                    ForEach(h.runder.sorted { $0.runde > $1.runde }) { r in runde(r) }
                    Ordlisteknapp()
                } else if lastet {
                    Text("Ingen historikk å vise.").font(.footnote).foregroundStyle(Farge.svak)
                } else {
                    ProgressView().tint(Farge.dempet).frame(maxWidth: .infinity).padding(.top, 40)
                }
            }
            .padding(16)
        }
        .background(Farge.flate)
        .scrollIndicators(.hidden)
        .navigationTitle("Historikk")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Farge.flate, for: .navigationBar)
        .task {
            hist = await FplLager(api: api).hentHistorikk(api)
            lastet = true
        }
    }

    private func runde(_ r: FplHistorikk.Runde) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Runde \(r.runde)").font(.subheadline.weight(.semibold)).foregroundStyle(Farge.tekst)
                Spacer()
                if let p = r.poeng {
                    // Ditt lag i slot 1, ligasnittet i slot 2 — samme rollefordeling
                    // som resten av modulen.
                    Text("\(p)").font(.subheadline.monospacedDigit()).foregroundStyle(Diagramfarge.serie1)
                    if let s = r.snitt_liga {
                        Text("mot \(s)").font(.caption2.monospacedDigit()).foregroundStyle(Diagramfarge.serie2)
                    }
                }
            }
            nøkkeltall(r)
            ForEach(r.beslutninger) { b in beslutning(b) }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Farge.kort)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func nøkkeltall(_ r: FplHistorikk.Runde) -> some View {
        HStack(spacing: 12) {
            if let x = r.rank_total { merke("rank", forkort(x)) }
            if let x = r.benkepoeng { merke("på benken", "\(x)") }
            if let x = r.byttetrekk, x != 0 { merke("byttetrekk", "−\(abs(x))") }
            Spacer()
        }
        .font(.system(size: 10))
    }

    private func merke(_ tittel: String, _ verdi: String) -> some View {
        HStack(spacing: 3) {
            Text(verdi).monospacedDigit().foregroundStyle(Farge.dempet)
            Text(tittel).foregroundStyle(Farge.svak)
        }
    }

    private func forkort(_ n: Int) -> String {
        n >= 1_000_000 ? String(format: "%.1fM", Double(n) / 1_000_000)
            : n >= 1000 ? "\(n / 1000)k" : "\(n)"
    }

    /// Ett beslutningskort.
    ///
    /// Referanseraden er `gw2-szoboszlai-for-gibbswhite`: **poeng_effekt −9** og
    /// **premiss_holdt true**. Byttet tapte ni poeng fordi lavsannsynlighetsgrenen landet
    /// — resonnementet var likevel riktig. Skjermen er bygget rundt akkurat den raden:
    ///
    /// 1. **Premisset er overskriften**, poengene er en fotnote. Motsatt rekkefølge ville
    ///    stemplet ukas grundigst begrunnede beslutning som en tabbe.
    /// 2. **Poengeffekten har ingen dom-farge.** Rødt på −9 ER en dom. Tallet er en måling;
    ///    vurderingen står i premisset. Samme prinsipp som retningsikonene i «Beslutningen».
    /// 3. **Når de to spriker, sies det høyt.** At premisset holdt og det likevel kostet
    ///    poeng er ikke en selvmotsigelse å skjule — det er nøyaktig det appen finnes for.
    private func beslutning(_ b: FplHistorikk.Runde.Beslutning) -> some View {
        let holdt = b.utfall?.premiss_holdt
        let poeng = b.utfall?.poeng_effekt
        // Sprik = resonnementet og utfallet peker hver sin vei.
        let spriker = holdt.map { h in
            (h && (poeng ?? 0) < 0) || (!h && (poeng ?? 0) > 0)
        } ?? false

        return VStack(alignment: .leading, spacing: 6) {
            Text(b.hva).font(.caption.weight(.medium)).foregroundStyle(Farge.tekst)
                .fixedSize(horizontal: false, vertical: true)
            if let g = b.begrunnelse {
                Text(g).font(.caption2).foregroundStyle(Farge.dempet)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let r = b.risiko_flagget {
                Label(r, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 10)).foregroundStyle(Diagramfarge.varsel)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if holdt != nil || poeng != nil {
                Divider().overlay(Farge.strek).padding(.vertical, 1)
                utfall(holdt: holdt, poeng: poeng, spriker: spriker,
                       kommentar: b.utfall?.premiss_kommentar)
            }

            Text(b.dato).font(.system(size: 9).monospacedDigit()).foregroundStyle(Farge.svak)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Farge.kort2)
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    @ViewBuilder
    private func utfall(holdt: Bool?, poeng: Int?, spriker: Bool, kommentar: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let h = holdt {
                // Ikon OG tekst — fargen alene skal aldri bære betydningen. Og selve
                // begrepet forklarer seg ved trykk: skillet mellom «riktig vurdert» og
                // «gikk bra» er hele poenget med skjermen, og det er ikke selvsagt.
                Forklar(nøkkel: "premiss_holdt") {
                    HStack(spacing: 4) {
                        Label(h ? "Premisset holdt" : "Premisset holdt ikke",
                              systemImage: h ? "checkmark.seal.fill" : "xmark.seal.fill")
                        Image(systemName: "questionmark.circle").font(.system(size: 10))
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(h ? Diagramfarge.god : Diagramfarge.alvorlig)
                }
            }
            if let k = kommentar {
                Text(k).font(.system(size: 10)).foregroundStyle(Farge.dempet)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 4) {
                // Nøytral farge med vilje: måling, ikke dom.
                Text(poeng.map { $0 > 0 ? "+\($0)" : "\($0)" } ?? "–")
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                Text("poeng av byttet")
                    .font(.system(size: 10))
            }
            .foregroundStyle(Farge.svak)
            if spriker, let h = holdt {
                Text(h ? "Resonnementet var riktig selv om utfallet kostet poeng."
                       : "Utfallet ble bra, men ikke av grunnen beslutningen hvilte på.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Diagramfarge.varsel)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
