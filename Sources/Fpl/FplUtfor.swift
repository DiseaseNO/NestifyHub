import SwiftUI

/// Knappen som lar Thomas si ja — og kvitteringen etterpå.
///
/// **Appen utfører ingenting.** Den leverer en signert godkjenning; kilden kontrollerer
/// sine egne sperrer og gjør jobben. Derfor heter knappen «Utfør anbefalingen» og ikke
/// «Bytt spiller»: vi lover et signal, ikke et resultat.
///
/// **Appen setter heller ikke sammen et valg selv.** Kostnaden er ikke additiv — med ett
/// fritt bytte koster det første 0 og det andre −4, og velger man bort det første blir
/// det andre gratis — og å velge bort et bytte river i oppstillingen. Kilden regner ut
/// hver lovlige kombinasjon på forhånd; vi viser dem og sender den ene Thomas peker på.
struct FplUtfor: View {
    let lager: FplLager
    let svar: FplSvar

    @State private var visValg = false
    @State private var valg: FplValg?
    @State private var henter = false
    @State private var valgtId: String?
    @State private var sender = false
    @State private var feil: String?
    /// Sant mens vi venter på kvitteringen fra kilden.
    @State private var venter = false
    @State private var ventetSek = 0
    /// Hvor stort valgarket åpnes. Er det flere enn ett valg, må det åpnes stort — ellers
    /// ligger alternativene under folden og det ser ut som det ikke er noe å velge.
    @State private var arkhøyde: PresentationDetent = .medium

    private var d: FplStatus { svar.data }
    private var a: FplStatus.Anbefaling? { d.anbefaling }

    /// Kvitteringen teller bare når den gjelder anbefalingen som ligger der nå. En
    /// kvittering fra forrige runde skal ikke se ut som svar på dagens knapp.
    private var kvittering: FplStatus.Utforelse? {
        guard let u = d.utforelse, u.status != "ingen" else { return nil }
        if u.gjelder_naavaerende == false { return nil }
        return u
    }

    private var kanUtfore: Bool {
        guard let a, a.finnes == true else { return false }
        // Låst runde: fristen har gått, og kilden ville uansett avvist med `avvist_frist`.
        if d.runde.laast { return false }
        return kvittering == nil && !venter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let k = kvittering {
                kvitteringsrad(k)
            } else if venter {
                venterad
            } else if kanUtfore {
                knapp
            } else if d.runde.laast, a?.finnes == true {
                rad("lock", Farge.svak, "Runden er låst",
                    "Fristen har passert — anbefalingen kan ikke utføres nå.")
            }

            if let feil {
                Label(feil, systemImage: "exclamationmark.triangle")
                    .font(.caption2).foregroundStyle(Farge.avvik)
            }
        }
        .sheet(isPresented: $visValg) { valgark }
        .task {
            // Bare i CI: åpne valgarket automatisk så skjermbildet dekker det.
            if Testskjerm.fplvalg, kanUtfore {
                visValg = true
                await hentValg()
            }
        }
    }

    // MARK: knappen og ventingen

    private var knapp: some View {
        VStack(alignment: .leading, spacing: 7) {
            Button {
                Kjenn.trykk()
                visValg = true
                Task { await hentValg() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill").font(.footnote)
                    Text("Utfør anbefalingen").font(.callout.weight(.semibold))
                }
                .frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(Farge.aksent).foregroundStyle(Farge.flate)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(Trykkflate())

            if let k = a?.kostnad, !k.isEmpty {
                Text(k).font(.caption2).foregroundStyle(Farge.dempet)
            }
        }
    }

    /// Ventetilstanden.
    ///
    /// Kilden henter godkjenningen fra postkassen sin med jevne mellomrom, så kvitteringen
    /// kommer ikke med én gang. **Før måtte man ut av appen og inn igjen for å se den** —
    /// skjermen hentet bare ved oppstart. Nå henter den selv, og sier hvor lenge den har
    /// ventet.
    private var venterad: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 9) {
                ProgressView().controlSize(.small).tint(Farge.aksent).frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Venter på at endringen utføres")
                        .font(.footnote.weight(.medium)).foregroundStyle(Farge.tekst)
                    Text(ventetSek < 20
                         ? "Godkjenningen er levert. Kilden henter den innen et minutt."
                         : "Fortsatt ingen kvittering — det har gått \(ventetSek) sekunder.")
                        .font(.caption2).foregroundStyle(Farge.dempet)
                        .contentTransition(.numericText())
                }
                Spacer(minLength: 0)
            }
            // En strek som beveger seg er forskjellen på å vente og på å lure på om noe
            // i det hele tatt skjedde.
            Stolpe(andel: Double(ventetSek) / 30, høyde: 3)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Farge.aksent.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: valgarket

    private var valgark: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if henter {
                            ProgressView().tint(Farge.dempet)
                                .frame(maxWidth: .infinity).padding(.top, 30)
                        } else if let v = valg {
                            if let u = v.anbefaling_ulovlig {
                                // Kildens EGEN anbefaling går ikke. Det er deres feil,
                                // ikke et valg for Thomas — så den skal stå tydelig.
                                Label(u, systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption).foregroundStyle(Farge.avvik)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Farge.avvik.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            if v.kombinasjoner.count > 1 {
                                Text("Velg hva som skal gjøres. Prisen er ikke summen av "
                                     + "delene — kilden har regnet ut hver kombinasjon for seg.")
                                    .font(.caption2).foregroundStyle(Farge.svak)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            ForEach(v.kombinasjoner) { k in kombinasjonskort(k, v) }
                        } else {
                            Text("Fikk ikke tak i valgene. Prøv igjen om litt.")
                                .font(.footnote).foregroundStyle(Farge.svak)
                        }
                    }
                    .padding(18)
                }
                .scrollIndicators(.hidden)
                bunn
            }
            .background(Farge.flate)
            .navigationTitle((valg?.kombinasjoner.count ?? 0) > 1 ? "Velg" : "Utfør anbefalingen?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Farge.flate, for: .navigationBar)
        }
        .presentationDetents([.medium, .large], selection: $arkhøyde)
        .presentationDragIndicator(.visible)
    }

    /// Fast bunn: knappene skal ALLTID være synlige. En bekreftelse man ikke kan avbryte
    /// fordi teksten dyttet knappen ut av skjermen, er ikke en bekreftelse.
    @ViewBuilder
    private var bunn: some View {
        if let v = valg, let id = valgtId,
           let k = v.kombinasjoner.first(where: { $0.id == id }), k.lovlig {
            VStack(spacing: 9) {
                Text("Godkjenningen sendes til FPL-systemet, som utfører den. "
                     + "Den kan ikke trekkes tilbake herfra.")
                    .font(.caption2).foregroundStyle(Farge.svak)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    Task { await send(k, v) }
                } label: {
                    HStack(spacing: 8) {
                        if sender { ProgressView().controlSize(.small).tint(Farge.flate) }
                        Text(sender ? "Sender …" : "Utfør").font(.callout.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Farge.aksent).foregroundStyle(Farge.flate)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(Trykkflate())
                .disabled(sender)
                Button("Avbryt") { visValg = false }
                    .font(.callout).foregroundStyle(Farge.dempet).padding(.vertical, 6)
            }
            .padding(.horizontal, 18).padding(.bottom, 10)
        }
    }

    private func kombinasjonskort(_ k: FplValg.Kombinasjon, _ v: FplValg) -> some View {
        let valgt = valgtId == k.id
        return Button {
            guard k.lovlig else { return }
            Kjenn.trykk()
            valgtId = k.id
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: valgt ? "largecircle.fill.circle" : "circle")
                        .foregroundStyle(valgt ? Farge.aksent : (k.lovlig ? Farge.svak : Farge.strek))
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(linjer(k, v), id: \.self) { linje in
                            Text(linje).font(.subheadline)
                                .foregroundStyle(k.lovlig ? Farge.tekst : Farge.svak)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    if k.anbefalt == true {
                        Text("ANBEFALT").font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(Farge.aksent.opacity(0.18)).foregroundStyle(Farge.aksent)
                            .clipShape(Capsule())
                    }
                }
                if let kost = k.kostnad, !kost.isEmpty {
                    Text(kost).font(.caption).foregroundStyle(Farge.dempet)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let b = k.bank_etter {
                    Text(String(format: "Bank etter: %.1f", b))
                        .font(.caption2.monospacedDigit()).foregroundStyle(Farge.svak)
                }
                if !k.lovlig, let hvorfor = k.hvorfor_ikke {
                    // Konsekvensen, ikke bare «går ikke». Det er dette man vil vite når
                    // man vurderer å velge bort en del av pakken.
                    Label(hvorfor, systemImage: "hand.raised.fill")
                        .font(.caption2).foregroundStyle(Farge.varm)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(valgt ? Farge.aksent.opacity(0.10) : Farge.kort)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(valgt ? Farge.aksent.opacity(0.4) : Farge.strek, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(Trykkflate())
        .disabled(!k.lovlig)
    }

    /// Hva pakken gjør. Tom liste betyr «gjør ingenting», og det skal stå — ikke være et
    /// tomt kort man ikke skjønner.
    private func linjer(_ k: FplValg.Kombinasjon, _ v: FplValg) -> [String] {
        let valgte = k.beslutninger.compactMap { id in v.beslutninger.first { $0.id == id } }
        if valgte.isEmpty { return ["Gjør ingenting"] }
        // `beskrivelse` er alltid der; `tittel` er vaktas ord og kan mangle.
        return valgte.map { $0.tittel ?? $0.beskrivelse }
    }

    // MARK: sending og venting

    private func hentValg() async {
        henter = true
        defer { henter = false }
        let v = await lager.hentValg()
        valg = v
        // Flere valg → åpne stort, så alle alternativene er synlige med en gang.
        arkhøyde = (v?.kombinasjoner.count ?? 0) > 1 ? .large : .medium
        // Forhåndsvelg kildens anbefaling: det trygge valget, og det begrunnelsen på
        // skjermen bak faktisk handler om.
        valgtId = v?.kombinasjoner.first(where: { $0.anbefalt == true && $0.lovlig })?.id
            ?? v?.kombinasjoner.first(where: { $0.lovlig })?.id
    }

    private func send(_ k: FplValg.Kombinasjon, _ v: FplValg) async {
        sender = true
        defer { sender = false }
        do {
            // Backend holder forbindelsen og venter på kvitteringen. Kom den, viser vi
            // resultatet MED EN GANG — ingen ventestolpe, ingen ut/inn. Rakk ikke backend
            // det (kildens cron er fortsatt treg), faller vi tilbake på polling.
            let (kvittering, godkjent) = try await lager.godkjennValg(
                k.id, grunnlagId: v.grunnlag_id, gw: v.runde ?? d.runde.nummer)
            Kjenn.vellykket()
            feil = nil
            visValg = false
            if kvittering == nil {
                await vent(godkjent: godkjent)
            } else {
                // Kvitteringen er her, men laget kan henge noen sekunder etter mens kilden
                // skriver den fulle eksporten. Hent til troppen er ferskt, så lagbildet
                // oppdateres live uten at Thomas må gjøre noe.
                await lager.ventPaaFerskeLag()
            }
        } catch {
            feil = error.localizedDescription
            visValg = false
        }
    }

    /// Henter til kvitteringen dukker opp.
    ///
    /// Gir vi opp, står ventetilstanden igjen framfor å påstå at noe gikk galt — den kan
    /// godt ha blitt utført ett sekund etter at vi sluttet å se etter.
    private static let terminal: Set<String> =
        ["utfort", "avvist_endret_grunnlag", "avvist_frist", "feilet"]

    private func vent(godkjent: String?) async {
        venter = true
        ventetSek = 0
        // 30 sek. Path-triggeren gir kvittering på ~1,5 s, og backend har alt ventet 25 s
        // synkront — dette er bare et fallback. Vi breaker straks DENNE godkjenningens
        // kvittering er terminal, kjent igjen på `godkjent`. En annen kvittering i
        // status.json (også en forurenset fra en avvist test) matcher ikke og holder oss
        // ikke fanget lenger enn nødvendig.
        for _ in 0..<15 {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { ventetSek += 2 }
            await lager.last()
            if let u = lager.svar?.data.utforelse,
               Self.terminal.contains(u.status),
               godkjent == nil || u.godkjent == godkjent {
                Kjenn.vellykket()
                break
            }
        }
        venter = false
    }

    // MARK: kvitteringen

    @ViewBuilder
    private func kvitteringsrad(_ k: FplStatus.Utforelse) -> some View {
        let (ikon, farge) = utseende(k.status)
        VStack(alignment: .leading, spacing: 6) {
            rad(ikon, farge, Ordliste.etikett(k.status), k.hva_ble_gjort ?? k.merknad)
            if let kost = k.kostnad, !kost.isEmpty {
                Text(kost).font(.caption2).foregroundStyle(Farge.dempet)
            }
            if let f = k.feil, !f.isEmpty {
                Text(f).font(.caption2).foregroundStyle(Farge.avvik)
            }
            // Laget henger noen sekunder etter kvitteringen mens kilden skriver den fulle
            // eksporten. Si fra, så «utført» ikke ser rart ut ved siden av en gammel tropp.
            if k.resten_oppdateres == true {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini).tint(Farge.dempet)
                    Text("Oppdaterer laget …").font(.caption2).foregroundStyle(Farge.svak)
                }
            }
            // Kontrollkjøringen, bak en fold: teknisk, og skal være tilgjengelig uten å
            // være det første man møter.
            if let diff = k.diff?.trimmingCharacters(in: .whitespacesAndNewlines), !diff.isEmpty {
                DisclosureGroup("Hva som ble endret") {
                    Text(diff).font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Farge.dempet)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 4)
                }
                .font(.caption2).tint(Farge.svak).foregroundStyle(Farge.dempet)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(farge.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func rad(_ ikon: String, _ farge: Color, _ tittel: String, _ under: String?) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: ikon).font(.footnote).foregroundStyle(farge).frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(tittel).font(.footnote.weight(.medium)).foregroundStyle(Farge.tekst)
                if let under, !under.isEmpty {
                    Text(under).font(.caption2).foregroundStyle(Farge.dempet)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
    }

    /// Avvist er ikke det samme som feilet: det første er en sperre som gjorde jobben
    /// sin, det andre er noe som gikk galt.
    private func utseende(_ status: String) -> (String, Color) {
        switch status {
        case "utfort": ("checkmark.seal.fill", Farge.ok)
        case "venter": ("clock.arrow.circlepath", Farge.aksent)
        case "avvist_endret_grunnlag", "avvist_frist": ("hand.raised.fill", Farge.dempet)
        case "feilet": ("exclamationmark.triangle.fill", Farge.avvik)
        default: ("info.circle", Farge.dempet)
        }
    }
}
