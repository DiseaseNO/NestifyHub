import SwiftUI

/// «Nå» — appens hovedskjerm for FPL.
///
/// Øverst nedtellingen til frist. Det er skjermens ene viktigste tall, og det regnes fra
/// det ABSOLUTTE fristtidspunktet — aldri fra `timer_til_frist`, som er fryst i det fila
/// skrives.
///
/// Er runden låst, erstattes nedtellingen: laget kan ikke røres, og å vise noe som ligner
/// en handling ville vært villedende.
struct FplNaa: View {
    /// Lageret eies av modulen, ikke av skjermen — Nå og Helse deler samme henting.
    let lager: FplLager
    @State private var nå = Date()          // driver nedtellingen mellom hentingene
    @State private var visOpphav: Opphav?
    @State private var visSporsmal: Spørsmål?

    /// Arket trenger noe Identifiable å henge på; en `[String]` er det ikke.
    struct Spørsmål: Identifiable { let id = UUID(); let punkter: [String] }

    /// Hvert tall som bærer en beslutning skal kunne trykkes på og vise hvor det kom fra
    /// og hvor gammelt det er. Det er ikke pynt — det er produktet.
    struct Opphav: Identifiable {
        let id = UUID()
        let tittel: String, verdi: String, kilde: String, alder: String
    }

    private let takt = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let s = lager.svar {
                    if s.data.versjon > FplStatus.støttetVersjon { nyereKontrakt(s.data.versjon) }
                    topp(s)
                    dataAlder(s)
                    anbefalingskort(s)
                    lagoversikt(s.data)
                    tropp(s.data)
                    Ordlisteknapp().padding(.top, 2)
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
        .navigationTitle("Nå")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Farge.flate, for: .navigationBar)
        .onReceive(takt) { nå = $0 }
        .task { await lager.følg() }
        .refreshable { await lager.last() }
        .sheet(item: $visOpphav) { o in opphavsark(o) }
        .sheet(item: $visSporsmal) { sp in sporsmaalsark(sp.punkter) }
    }

    /// Anbefalingen som én setning, satt sammen av `bytter`, `endrer_oppstilling`,
    /// `kaptein` og `chip`. Ingen tolkning av fritekst — bare feltene, sagt på norsk.
    private func handling(_ a: FplStatus.Anbefaling) -> String {
        var deler: [String] = []
        let bytter = a.bytter ?? []
        if let b = bytter.first, bytter.count == 1, let inn = b.inn?.navn, let ut = b.ut?.navn {
            deler.append("Bytt inn \(inn) for \(ut).")
        } else if !bytter.isEmpty {
            deler.append("Gjør \(bytter.count) bytter.")
        } else if a.endrer_oppstilling == true {
            deler.append("Endre oppstillingen.")
        } else {
            deler.append("Gjør ingenting — laget står som det er.")
        }
        if let k = a.kaptein?.navn {
            // Ikke `a.vise?.navn.map {…}`: der binder `.map` seg til String som samling
            // og gir `[String]?`, ikke den valgfrie strengen man tror man har.
            if let v = a.vise?.navn {
                deler.append("\(k) er kaptein, \(v) er vise.")
            } else {
                deler.append("\(k) er kaptein.")
            }
        }
        if let c = a.chip { deler.append("Bruk chip: \(c).") }
        return deler.joined(separator: " ")
    }

    // MARK: nedtelling

    @ViewBuilder
    private func topp(_ s: FplSvar) -> some View {
        let laast = s.data.runde.laast
        let paagaar = (s.data.runde.paagaaende ?? 0) > 0
        VStack(alignment: .leading, spacing: 4) {
            Text("Runde \(s.data.runde.nummer)")
                .font(.footnote).foregroundStyle(Farge.dempet)

            if laast && paagaar {
                // Laget kan ikke endres nå. Ingen nedtelling, ingen handlinger.
                Label("Runden pågår — laget er låst", systemImage: "lock.fill")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Diagramfarge.varsel)
                if let sn = s.data.runde.snitt_liga, sn > 0 {
                    Text("Ligasnitt \(sn)").font(.subheadline).foregroundStyle(Farge.dempet)
                }
            } else if let t = lager.sekunderTilFrist {
                let haster = t > 0 && t < 3 * 3600
                Text(nedtellingstekst(t))
                    // ≥48 pt: dette er tallet man åpner appen for.
                    .font(.system(size: 52, weight: .light).monospacedDigit())
                    .foregroundStyle(t < 0 ? Farge.svak : (haster ? Diagramfarge.kritisk : Farge.tekst))
                    .contentTransition(.numericText())
                Text(t < 0 ? "siden frist" : "til frist")
                    .font(.subheadline).foregroundStyle(Farge.dempet)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Under tre timer bytter vi til minutter — da er timer for grov oppløsning til å
    /// ta en beslutning på.
    private func nedtellingstekst(_ t: TimeInterval) -> String {
        let s = Int(abs(t))
        if s < 3 * 3600 { return "\(s / 60) min" }
        if s < 86400 { return "\(s / 3600) t" }
        return "\(s / 86400) d \((s % 86400) / 3600) t"
    }

    // MARK: alder

    private func dataAlder(_ s: FplSvar) -> some View {
        let alder = TimeInterval(s.kilde.data_alder_sek ?? 0)
        let gammelt = alder > 3 * 3600
        return HStack(spacing: 6) {
            Image(systemName: gammelt ? "exclamationmark.circle.fill" : "clock")
                .font(.caption2)
            Text("Tallene er \(varighet(alder)) gamle")
                .font(.caption)
            if let f = s.kilde.feil {
                Text("· henting feilet").font(.caption).foregroundStyle(Diagramfarge.kritisk)
                    .help(f)
            }
        }
        .foregroundStyle(gammelt ? Diagramfarge.varsel : Farge.svak)
    }

    /// Kontrakten er nyere enn appen. Da mangler vi felter vi ikke vet om — si det,
    /// framfor å vise noe halvt som ser komplett ut.
    private func nyereKontrakt(_ v: Int) -> some View {
        Label("Dataene følger kontrakt v\(v); appen er bygget for v\(FplStatus.støttetVersjon). "
              + "Noe kan mangle.", systemImage: "exclamationmark.triangle.fill")
            .font(.caption).foregroundStyle(Diagramfarge.varsel)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: anbefaling

    /// Den strukturerte anbefalingen, ikke fritekst.
    ///
    /// `endrer_oppstilling` finnes nettopp så vi slipper å tolke `oppstilling: null` —
    /// null betyr «ingen endring foreslått», ikke «tom oppstilling».
    @ViewBuilder
    private func anbefalingskort(_ s: FplSvar) -> some View {
        let a = s.data.anbefaling
        if a?.finnes == true || (s.data.bytte_status?.isEmpty == false) {
            VStack(alignment: .leading, spacing: 8) {
                Text("ANBEFALING").font(.caption2.weight(.semibold)).foregroundStyle(Farge.dempet)

                if let a {
                    // Setningen først. De strukturerte feltene ER forståelige; det er
                    // fritekstet som ikke er det, og da skal fritekstet ikke stå øverst.
                    Text(handling(a))
                        .font(.callout.weight(.medium)).foregroundStyle(Farge.tekst)
                        .fixedSize(horizontal: false, vertical: true)
                    let antallBytter = a.bytter?.count ?? 0
                    HStack(spacing: 6) {
                        Image(systemName: antallBytter > 0 ? "arrow.left.arrow.right" : "pause.circle")
                            .font(.caption2)
                        Text(antallBytter > 0 ? "\(antallBytter) bytte\(antallBytter == 1 ? "" : "r")"
                                              : "Ingen bytter foreslått")
                            .font(.caption)
                        if a.endrer_oppstilling == false {
                            Text("· oppstillingen står").font(.caption2).foregroundStyle(Farge.svak)
                        }
                        if let c = a.chip { Text("· chip: \(c)").font(.caption2).foregroundStyle(Diagramfarge.varsel) }
                    }
                    .foregroundStyle(Farge.dempet)
                    // Vaktas eget notat er en arbeidslogg med forkortelser og filnavn.
                    // Den skal være tilgjengelig, men ikke være det første man møter.
                    if let n = a.notat {
                        DisclosureGroup("Vaktas notat") {
                            Text(n).font(.caption2).foregroundStyle(Farge.dempet)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 4)
                        }
                        .font(.caption2).tint(Farge.svak).foregroundStyle(Farge.dempet)
                    }
                } else if let b = s.data.bytte_status {
                    Text(b).font(.footnote).foregroundStyle(Farge.tekst)
                        .fixedSize(horizontal: false, vertical: true)
                }
                resten(s)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Farge.kort)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }


    /// Åpne spørsmål er vaktas arbeidsnotater — seks punkter på opptil 4 400 tegn. De
    /// hører til anbefalingen, men de kan ikke stå på hovedskjermen: da er det de man
    /// leser i stedet for hva man skal gjøre.
    private func resten(_ s: FplSvar) -> some View {
        Group {
            if let sp = s.data.aapne_sporsmal, !sp.isEmpty {
                Divider().overlay(Farge.strek)
                Button { visSporsmal = .init(punkter: sp) } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "questionmark.circle").font(.caption2)
                        Text("\(sp.count) åpne spørsmål bak anbefalingen").font(.caption2)
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 10))
                    }
                    .foregroundStyle(Diagramfarge.varsel)
                }
            }
        }
    }

    /// Førstesetningen i et notat, brukt som overskrift.
    ///
    /// Flere notater åpner med en datostempel-stump («NY 28/8:»). Kutter vi på første
    /// skilletegn blir overskriften den stumpen, som ikke sier noe — så vi går videre til
    /// det første bruddet som faktisk gir en setning.
    private func overskrift(_ tekst: String) -> String {
        let ren = tekst.trimmingCharacters(in: .whitespacesAndNewlines)
        var fra = ren.startIndex
        while let brudd = ren[fra...].firstIndex(where: { $0 == "." || $0 == ":" }) {
            let stykke = ren[ren.startIndex..<brudd].trimmingCharacters(in: .whitespaces)
            if stykke.count >= 25 { return stykke }
            fra = ren.index(after: brudd)
            if ren.distance(from: ren.startIndex, to: fra) > 90 { break }
        }
        return ren.count > 90 ? String(ren.prefix(90)) + "…" : ren
    }

    // MARK: lag

    private func lagoversikt(_ d: FplStatus) -> some View {
        HStack(spacing: 10) {
            rute("Verdi", String(format: "%.1f", d.lag.verdi), "lagverdi i millioner")
            rute("Bank", String(format: "%.1f", d.lag.bank), "ubrukt beløp")
            rute("Frie bytter", "\(d.lag.frie_bytter)", "bytter uten poengtrekk")
            // poeng_totalt er null før runden er spilt — vis strek, ikke 0.
            rute("Poeng", d.lag.poeng_totalt.map(String.init) ?? "—", "totalt i sesongen")
        }
    }

    private func rute(_ tittel: String, _ verdi: String, _ hva: String) -> some View {
        Button {
            visOpphav = .init(tittel: tittel, verdi: verdi, kilde: hva,
                              alder: lager.dataAlder.map { varighet($0) + " gammel" } ?? "ukjent alder")
        } label: {
            VStack(spacing: 2) {
                Text(verdi).font(.title3.weight(.medium).monospacedDigit()).foregroundStyle(Farge.tekst)
                Text(tittel).font(.caption2).foregroundStyle(Farge.dempet)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(Farge.kort).clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    // MARK: tropp

    /// Troppen som banehalvdel. Folk leser lag som lag — en tabell her ville tvunget
    /// leseren til å bygge oppstillingen i hodet.
    private func tropp(_ d: FplStatus) -> some View {
        let xi = d.tropp.filter(\.i_xi).sorted { $0.plass < $1.plass }
        let benk = d.tropp.filter { !$0.i_xi }.sorted { $0.plass < $1.plass }
        return VStack(alignment: .leading, spacing: 12) {
            Text("STARTELLEVER").font(.caption2.weight(.semibold)).foregroundStyle(Farge.dempet)
            ForEach(["GK", "DEF", "MID", "FWD"], id: \.self) { pos in
                let rad = xi.filter { $0.posisjon == pos }
                if !rad.isEmpty {
                    HStack(spacing: 6) { ForEach(rad) { spillerkort($0) } }
                }
            }
            Text("BENK — i autosub-rekkefølge").font(.caption2.weight(.semibold))
                .foregroundStyle(Farge.dempet).padding(.top, 4)
            Text("Plass 12 er alltid reservekeeper. Hoppes en spiller over fordi han spilte "
                 + "0 minutter, faller køen gjennom gratis.")
                .font(.caption2).foregroundStyle(Farge.svak)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) { ForEach(benk) { spillerkort($0) } }
        }
    }

    private func spillerkort(_ s: FplStatus.Spiller) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                if s.kaptein { Image(systemName: "c.circle.fill").font(.system(size: 9)).foregroundStyle(Diagramfarge.serie1) }
                if s.vise { Image(systemName: "v.circle").font(.system(size: 9)).foregroundStyle(Farge.dempet) }
                Text(s.navn).font(.system(size: 11, weight: .medium)).lineLimit(1)
            }
            .foregroundStyle(Farge.tekst)
            Text(s.klubb).font(.system(size: 9)).foregroundStyle(Farge.svak)
            if let k = s.kamp {
                Text("\(k.hjemme ? "H" : "B") \(k.mot)")
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(vanskefarge(k.vansker))
            }
            // spilleprosent er null når spilleren er helt frisk — ikke tolk som 0.
            if let p = s.spilleprosent {
                Text("\(p) %").font(.system(size: 9)).foregroundStyle(Diagramfarge.varsel)
            }
            // xP: egen modell er underkjent (`xp_modell_gyldig == false`), så vi viser
            // den UAVHENGIGE kilden. Å vise et underkjent tall alene ville vært å påstå
            // mer enn systemet står inne for.
            if let f = s.forventet, let x = f.xp_fplform {
                Text(String(format: "%.1f xP", x))
                    .font(.system(size: 9).monospacedDigit()).foregroundStyle(Diagramfarge.serie1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Farge.kort)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func vanskefarge(_ v: Int) -> Color {
        switch v {
        case ...2: Diagramfarge.god
        case 3:    Farge.dempet
        default:   Diagramfarge.alvorlig
        }
    }

    // MARK: opphav

    private func opphavsark(_ o: Opphav) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(o.tittel).font(.headline).foregroundStyle(Farge.tekst)
            Text(o.verdi).font(.system(size: 40, weight: .light).monospacedDigit())
                .foregroundStyle(Farge.tekst)
            Divider().overlay(Farge.strek)
            Label(o.kilde, systemImage: "arrow.triangle.branch").font(.footnote)
            Label(o.alder, systemImage: "clock").font(.footnote)
            Spacer()
        }
        .foregroundStyle(Farge.dempet)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Farge.flate)
        .presentationDetents([.height(240)])
    }

    /// Arket med de åpne spørsmålene. Overskrift per punkt, hele teksten bak et trykk.
    private func sporsmaalsark(_ sp: [String]) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Spørsmål vakta ikke har svart på ennå. De endrer ikke "
                         + "anbefalingen, men de er grunnen til at den kan endre seg.")
                        .font(.caption2).foregroundStyle(Farge.svak)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(sp, id: \.self) { q in
                        DisclosureGroup {
                            Text(q).font(.caption2).foregroundStyle(Farge.dempet)
                                .fixedSize(horizontal: false, vertical: true).padding(.top, 3)
                        } label: {
                            Text(overskrift(q)).font(.footnote).foregroundStyle(Farge.tekst)
                                .multilineTextAlignment(.leading)
                        }
                        .tint(Farge.svak)
                    }
                }
                .padding(16)
            }
            .background(Farge.flate)
            .scrollIndicators(.hidden)
            .navigationTitle("Åpne spørsmål")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Farge.flate, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Lukk") { visSporsmal = nil } } }
        }
    }
}
