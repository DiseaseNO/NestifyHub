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
    @State private var visSpiller: FplStatus.Spiller?

    /// Arket trenger noe Identifiable å henge på; en `[String]` er det ikke.
    struct Spørsmål: Identifiable {
        let id = UUID()
        let punkter: [FplStatus.Punkt]
        let oversikt: FplStatus.Oversikt?
    }

    /// Hvert tall som bærer en beslutning skal kunne trykkes på og vise hvor det kom fra
    /// og hvor gammelt det er. Det er ikke pynt — det er produktet.
    struct Opphav: Identifiable {
        let id = UUID()
        let tittel: String, verdi: String, kilde: String, alder: String
        /// Hva tallet betyr, fra ordlista. Uten forklaring er tallet bare et tall.
        let betyr: String?
    }

    private let takt = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let s = lager.svar {
                    if s.data.versjon > FplStatus.støttetVersjon { nyereKontrakt(s.data.versjon) }
                    topp(s)
                    dataAlder(s)
                    endringer(s.data)
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
        .onChange(of: lager.svar == nil) { _, tomt in
            // Bare i CI: åpne detaljene automatisk så skjermbildet dekker dem.
            if !tomt, Testskjerm.spillerdetalj, visSpiller == nil {
                visSpiller = lager.svar?.data.tropp.first
            }
        }
        .refreshable { await lager.last() }
        .sheet(item: $visOpphav) { o in opphavsark(o) }
        .sheet(item: $visSporsmal) { sp in sporsmaalsark(sp) }
        .sheet(item: $visSpiller) { FplSpillerark(spiller: $0) }
    }

    /// Nødløsning til kilden sender `sammendrag`: anbefalingen som én setning, satt
    /// sammen av `bytter`, `endrer_oppstilling`, `kaptein` og `chip`.
    ///
    /// Den er mekanisk og sier bare det feltene sier — men den er vår, og teksten skal
    /// være kildens. Se `docs/bestilling-fra-appen.md` §2 i FPL-repoet.
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

    /// Hva som er nytt siden forrige eksport. Tom liste vises ikke — «ingenting er
    /// endret» er ikke verdt en rad, men en endring er det man åpner appen for.
    @ViewBuilder
    private func endringer(_ d: FplStatus) -> some View {
        if let e = d.endret, !e.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                Label("Nytt siden sist", systemImage: "sparkles")
                    .font(.caption.weight(.semibold)).foregroundStyle(Diagramfarge.god)
                ForEach(e) { x in
                    Text(x.beskrivelse ?? [x.felt, x.fra, x.til].compactMap { $0 }.joined(separator: " → "))
                        .font(.caption2).foregroundStyle(Farge.dempet)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Diagramfarge.god.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
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
                    Text(a.sammendrag ?? handling(a))
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


    /// Topplinja over spørsmål. Kilden teller selv, og skiller det som **må gjøres nå**
    /// fra driftsgjeld som bare står. Uten det skillet så alle punktene like presserende
    /// ut, og det ene som faktisk ventet på en beslutning druknet.
    ///
    /// Er tallet null, sies det: «ingenting venter på deg» er en nyttig beskjed, og den
    /// er ikke det samme som at lista er tom.
    private func resten(_ s: FplSvar) -> some View {
        let punkter = (s.data.aapne_sporsmal ?? []) + (s.data.aapne_risikoer ?? [])
        let o = s.data.sporsmal_oversikt
        let maa = o?.maa_besvares_foer_frist ?? punkter.filter { $0.kategori == "runde" }.count
        return Group {
            if !punkter.isEmpty {
                Divider().overlay(Farge.strek)
                Button { visSporsmal = .init(punkter: punkter, oversikt: o) } label: {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: maa > 0 ? "exclamationmark.circle.fill" : "checkmark.circle")
                            .font(.caption2)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(maa > 0 ? "\(maa) må besvares før fristen" : "Ingenting venter på deg")
                                .font(.caption.weight(.medium))
                            Text(undertekst(o, punkter))
                                .font(.system(size: 10)).foregroundStyle(Farge.svak)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 10))
                    }
                    .foregroundStyle(maa > 0 ? Diagramfarge.varsel : Farge.dempet)
                }
            }
        }
    }

    private func undertekst(_ o: FplStatus.Oversikt?, _ p: [FplStatus.Punkt]) -> String {
        let venter = o?.venter_paa_signal ?? p.filter { $0.kategori == "venter_paa_signal" }.count
        let står = o?.staaende ?? p.filter { $0.kategori == "staaende" }.count
        var d: [String] = []
        if venter > 0 { d.append("\(venter) venter på signal") }
        if står > 0 { d.append("\(står) står åpne") }
        return d.isEmpty ? "\(p.count) punkter" : d.joined(separator: " · ")
    }


    // MARK: lag

    private func lagoversikt(_ d: FplStatus) -> some View {
        HStack(spacing: 10) {
            rute("Verdi", String(format: "%.1f", d.lag.verdi), "lagverdi i millioner", "verdi")
            rute("Bank", String(format: "%.1f", d.lag.bank), "ubrukt beløp", "bank")
            rute("Frie bytter", "\(d.lag.frie_bytter)", "bytter uten poengtrekk", "frie_bytter")
            // poeng_totalt er null før runden er spilt — vis strek, ikke 0.
            rute("Poeng", d.lag.poeng_totalt.map(String.init) ?? "—", "totalt i sesongen", "poeng")
        }
    }

    private func rute(_ tittel: String, _ verdi: String, _ hva: String, _ nøkkel: String) -> some View {
        Button {
            visOpphav = .init(tittel: tittel, verdi: verdi, kilde: hva,
                              alder: lager.dataAlder.map { varighet($0) + " gammel" } ?? "ukjent alder",
                              betyr: Ordliste.finn(nøkkel)?.hva)
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
            // Ingen Forklar-knapp her: hele kortet er en knapp, og en knapp inni en
            // knapp gir uforutsigbar treffflate. Forklaringen står i detaljvisningen.
            if let f = s.forventet, let x = f.xp_fplform {
                Text(String(format: "%.1f xP", x))
                    .font(.system(size: 9).monospacedDigit()).foregroundStyle(Diagramfarge.serie1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Farge.kort)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture { visSpiller = s }
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
            if let b = o.betyr {
                Text(b).font(.footnote).foregroundStyle(Farge.dempet)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Divider().overlay(Farge.strek)
            Label(o.kilde, systemImage: "arrow.triangle.branch").font(.footnote)
            Label(o.alder, systemImage: "clock").font(.footnote)
            Spacer()
        }
        .foregroundStyle(Farge.dempet)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Farge.flate)
        .presentationDetents([.medium])
    }

    /// Punktene gruppert på kategori. Rekkefølgen er hele poenget: det som kan gjøres
    /// nå står øverst, driftsgjelda ligger kollapset nederst.
    private func sporsmaalsark(_ sp: Spørsmål) -> some View {
        let rekkefølge = ["runde", "venter_paa_signal", "avgjort_for_runden", "staaende"]
        let overskrift = ["runde": "Må besvares før fristen",
                          "venter_paa_signal": "Venter på signal",
                          "avgjort_for_runden": "Avgjort for runden",
                          "staaende": "Står åpent"]
        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(rekkefølge, id: \.self) { kat in
                        let i = sp.punkter.filter { ($0.kategori ?? "staaende") == kat }
                        if !i.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(overskrift[kat] ?? kat) (\(i.count))")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(kat == "runde" ? Diagramfarge.varsel : Farge.dempet)
                                    if let f = sp.oversikt?.forklaring?[kat] {
                                        Text(f).font(.system(size: 10)).foregroundStyle(Farge.svak)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                if kat == "staaende" {
                                    // Driftsgjeld ligger kollapset — den rører ikke runden.
                                    DisclosureGroup("Vis alle \(i.count)") {
                                        VStack(alignment: .leading, spacing: 12) {
                                            ForEach(i) { punkt($0, dempet: true) }
                                        }
                                        .padding(.top, 6)
                                    }
                                    .font(.caption2).tint(Farge.svak).foregroundStyle(Farge.dempet)
                                } else {
                                    ForEach(i) { punkt($0, dempet: kat == "avgjort_for_runden") }
                                }
                            }
                        }
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

    private func punkt(_ p: FplStatus.Punkt, dempet: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(p.overskrift)
                .font(.footnote.weight(.medium))
                .foregroundStyle(dempet ? Farge.dempet : Farge.tekst)
                .fixedSize(horizontal: false, vertical: true)
            if let k = p.sammendrag {
                Text(k).font(.caption).foregroundStyle(Farge.dempet)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // Hva vi venter på er viktigere enn når punktet ble åpnet.
            if let v = p.venter_paa {
                Label(v, systemImage: "hourglass").font(.system(size: 10))
                    .foregroundStyle(Farge.svak).fixedSize(horizontal: false, vertical: true)
            }
            if let m = p.kategori_merknad {
                Text(m).font(.system(size: 10)).foregroundStyle(Farge.svak)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !p.tekst.isEmpty, p.tittel != nil || p.sammendrag != nil {
                DisclosureGroup("Vaktas notat") {
                    Text(p.tekst).font(.caption2).foregroundStyle(Farge.svak)
                        .fixedSize(horizontal: false, vertical: true).padding(.top, 3)
                }
                .font(.caption2).tint(Farge.svak)
            }
        }
    }
}
