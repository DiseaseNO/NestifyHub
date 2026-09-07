import SwiftUI
import WidgetKit

/// «Huset» — smarthus-modulen i appen.
///
/// Speiler nettbrettets faner. Hver fane er satt sammen av **bolker** brukeren kan
/// flytte og skjule, men ikke legge til. Den frie modellen med egne faner og multikort
/// er fjernet: et multikort satt til «alle rom» tegnet rommene en gang til under dem som
/// alt lå der, og skjermen så ut som en feil.
///
/// Appen regner ikke ut noe selv — den viser hva serveren sier. To klienter som regner
/// hver for seg kommer fram til forskjellige svar.
struct HusModul: View {
    let api: API
    @State private var faner = Faner()
    @State private var valgtFane = Testskjerm.fane ?? "hjem"

    /// Hvilket ark som er åpent. ÉN tilstand, ikke flere: `.sheet` på samme visning
    /// oppfører seg uforutsigbart når den står flere ganger — det var slik trykk på et
    /// romkort en gang ikke gjorde noe.
    @State private var ark: Ark?

    enum Ark: Identifiable {
        case faner
        case bolker(fane: String)
        case rom(navn: String, entiteter: [String])

        var id: String {
            switch self {
            case .faner: "faner"
            case .bolker(let f): "bolker:" + f
            case .rom(let n, _): "rom:" + n
            }
        }
    }

    @State private var status: Husstatus?
    @State private var modell: Husmodell?
    @State private var feil: String?
    @State private var jobber: Set<String> = []
    @State private var entiteter: [Husentitet] = []
    /// Når tallene sist kom inn. En skjerm som viser et gammelt tall uten å si det, er
    /// verre enn en tom skjerm — man tror den er live.
    @State private var hentet: Date?
    @State private var entiteterFeil: String?
    @State private var modellFeil: String?
    @State private var bekreftPort = false
    @Environment(\.scenePhase) private var scenefase

    /// Ett oppsett per fane. Nøkkelen inneholder fanens id, så rekkefølgen i Strøm ikke
    /// blander seg med rekkefølgen i Huset.
    @State private var bolkoppsett: [String: Oppsett] = [:]

    private func oppsett(_ fane: String) -> Oppsett {
        if let o = bolkoppsett[fane] { return o }
        let o = Oppsett(område: "bolk." + fane, standard: Bolk.ider(fane))
        // `@State` som muteres under tegning er ikke lov; derfor lages alle på forhånd
        // i `.task`. Denne grenen er bare et sikkerhetsnett.
        return o
    }

    private func bolker(_ fane: String) -> [String] {
        oppsett(fane).synlige(av: Bolk.ider(fane))
    }

    var body: some View {
        // EGEN fanelinje, ikke `TabView`.
        //
        // iOS sin tar bare fem: er det flere, blir den femte til «More» og resten havner
        // i en liste bak den. Verre er det at innholdet under «More» pakkes inn i iOS'
        // egen navigasjon, som spiser verktøylinja — så både Admin OG sorteringsknappene
        // forsvant. Med vår egen linje er alle fanene likeverdige, og hver av dem
        // beholder sin egen `NavigationStack`.
        VStack(spacing: 0) {
            ZStack {
                ForEach(faner.synlige) { f in
                    // Alle fanene finnes, men bare den valgte tegnes. Da beholder hver
                    // fane rulleposisjonen sin når man bytter fram og tilbake.
                    if f.id == valgtFane { fane(f) }
                }
                if faner.synlige.first(where: { $0.id == valgtFane }) == nil {
                    // Fanen er skjult eller ukjent — vis den første som finnes.
                    Color.clear.onAppear { valgtFane = faner.synlige.first?.id ?? "hjem" }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            fanelinje
        }
        .background(Farge.flate)
        .tint(Farge.aksent)
        // Arket henger på TabView-en, ikke på hver fane. Festet per fane ville to
        // visninger bundet til samme tilstand kappes om å vise det samme.
        .sheet(item: $ark) { arkvisning($0) }
        .task {
            // Alle oppsettene lages her, ikke under tegning: å endre `@State` mens
            // SwiftUI tegner gir udefinert oppførsel.
            for f in Fane.alle where bolkoppsett[f.id] == nil {
                bolkoppsett[f.id] = Oppsett(område: "bolk." + f.id, standard: Bolk.ider(f.id))
            }
            await hent()
            if let r = Testskjerm.apneRom, ark == nil {
                ark = .rom(navn: r, entiteter: alleIRom(r))
            }
        }
        .onChange(of: scenefase) { _, ny in if ny == .active { Task { await hent() } } }
    }

    private var fanelinje: some View {
        HStack(spacing: 0) {
            ForEach(faner.synlige) { f in
                Button {
                    Kjenn.trykk()
                    valgtFane = f.id
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: f.ikon)
                            .font(.system(size: 17))
                            .frame(height: 20)
                        Text(f.navn)
                            .font(.system(size: 9, weight: valgtFane == f.id ? .semibold : .regular))
                            // Seks navn på en telefonbredde er trangt. Heller litt
                            // mindre skrift enn «Oppg…».
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(valgtFane == f.id ? Farge.aksent : Farge.svak)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8).padding(.bottom, 2)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
        .background(alignment: .top) {
            VStack(spacing: 0) {
                Rectangle().fill(Farge.strek).frame(height: 0.5)
                Farge.kort
            }
        }
    }

    /// Én fane: felles skall med tittel og de to sorteringsknappene, ulikt innhold.
    private func fane(_ f: Fane) -> some View {
        NavigationStack {
            innhold(f)
                .background(Farge.flate)
                .navigationTitle(f.navn)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Farge.flate, for: .navigationBar)
                .toolbar {
                    // Venstre: hvilke FANER som vises. Høyre: rekkefølgen på BOLKENE i
                    // denne fanen. To ulike ting, og de sto lenge bare på én fane.
                    ToolbarItem(placement: .topBarLeading) {
                        Button { ark = .faner } label: {
                            Image(systemName: "rectangle.3.group")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { ark = .bolker(fane: f.id) } label: {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                    }
                }
                .refreshable { await hent() }
        }
    }

    @ViewBuilder
    private func innhold(_ f: Fane) -> some View {
        switch f.id {
        case "hjem":     husfane
        case "oversikt": Oversiktfane(api: api, rekkefølge: bolker("oversikt"))
        case "strom":    Stromfane(api: api, rekkefølge: bolker("strom"))
        case "oppgaver": Oppgaverfane(api: api, rekkefølge: bolker("oppgaver"))
        case "biler":    Bilfane(api: api)
        case "admin":    Adminfane(api: api, rekkefølge: bolker("admin"))
        default:         EmptyView()
        }
    }

    @ViewBuilder
    private func arkvisning(_ a: Ark) -> some View {
        switch a {
        case .faner:
            Rekkefølgeoppsett(
                tittel: "Faner", ider: Fane.alle.map(\.id),
                navn: { id in Fane.alle.first { $0.id == id }?.navn ?? id },
                erSkjult: { faner.skjult.contains($0) },
                settSynlig: { faner.settSynlig($0, $1) },
                flytt: { faner.flytt(fra: $0, til: $1) },
                nullstill: { faner.nullstill() },
                ordne: { _ in faner.alle.map(\.id) })
        case .bolker(let f):
            let o = oppsett(f)
            Rekkefølgeoppsett(
                tittel: "Rekkefølge", ider: Bolk.ider(f), navn: Bolk.navn,
                erSkjult: { o.skjult.contains($0) },
                settSynlig: { o.settSynlig($0, $1) },
                flytt: { o.flyttIds(Bolk.ider(f), fra: $0, til: $1) },
                nullstill: { o.nullstill() },
                ordne: { o.ordne($0) })
        case .rom(let navn, let ider):
            Romoverlay(tittel: navn,
                       entiteter: ider.compactMap { id in entiteter.first { $0.id == id } },
                       styr: styrEntitet, jobber: jobber,
                       merknad: merknad(ider))
        }
    }

    // MARK: Huset-fanen

    private var husfane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let s = status {
                    ForEach(bolker("hjem"), id: \.self) { id in husbolk(id, s) }
                    if bolker("hjem").isEmpty {
                        Text("Alle bolker er skjult. Trykk på sorteringsknappen øverst.")
                            .font(.footnote).foregroundStyle(Farge.svak)
                    }
                } else if let feil {
                    Label(feil, systemImage: "exclamationmark.triangle")
                        .font(.footnote).foregroundStyle(Farge.avvik)
                } else {
                    ProgressView().tint(Farge.dempet).frame(maxWidth: .infinity).padding(.top, 40)
                }
            }
            .padding(16).padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .alert("Garasjeport", isPresented: $bekreftPort) {
            Button("Avbryt", role: .cancel) {}
            Button(status?.garasje?.aapen == true ? "Lukk" : "Åpne") {
                Task { await port() }
            }
        } message: {
            Text(status?.garasje?.aapen == true
                 ? "Lukke garasjeporten?" : "Åpne garasjeporten?")
        }
    }

    @ViewBuilder
    private func husbolk(_ id: String, _ s: Husstatus) -> some View {
        switch id {
        case "puls":    stromkort(s)
        case "scener":  scenekort(s)
        case "garasje": garasjekort(s)
        case "rom":
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(s.rom) { r in romflis(r) }
            }
        default: EmptyView()
        }
    }

    // MARK: data og styring

    private func hent() async {
        do {
            // Modellen endrer seg sjelden, men den må være der før en bryter kan brukes:
            // den vet hvilke lys som hører til hvilket rom.
            if modell == nil {
                do { modell = try await api.hent(Husmodell.self, "/api/hus/modell") }
                catch { modellFeil = error.localizedDescription }
            }
            let s = try await api.hent(Husstatus.self, "/api/hus/status")
            status = s; feil = nil; hentet = Date()
            // Entitetene trengs både til multikortene og til velgeren. Feiler kallet,
            // beholder vi de gamle: et kort som blir tomt fordi ett kall glapp, ser ut
            // som om noe er slettet.
            //
            // Men feilen SVELGES IKKE. Et tomt romark uten forklaring kostet oss en hel
            // runde med gjetting — «ingenting å styre her» kan bety at rommet er tomt,
            // at modellen mangler, eller at dette kallet feilet. Nå står det hvilken.
            do {
                entiteter = try await api.hent([Husentitet].self, "/api/hus/entiteter")
                entiteterFeil = nil
            } catch {
                entiteterFeil = error.localizedDescription
            }
            Delt.lagre(.init(effektWatt: s.effekt_watt, lysPaa: s.lys_paa,
                             kroner: s.kr_per_kwh, oppdatert: Date(),
                             rom: s.rom.map { .init(navn: $0.navn, lysPaa: $0.lys_paa,
                                                    lysTotalt: $0.lys_totalt,
                                                    temp: $0.temp, klima: $0.klima) },
                             garasjeAapen: s.garasje?.aapen,
                             brytere: entiteter.filter { $0.domene != "climate" }
                                 .map { .init(id: $0.id, navn: $0.navn, paa: $0.paa,
                                              domene: $0.domene) }))
            // Widgeten er en egen prosess og oppdager ikke av seg selv at fila er ny.
            WidgetCenter.shared.reloadAllTimelines()
        } catch { feil = error.localizedDescription }
    }

    /// Sender en kommando og henter status på nytt.
    ///
    /// Vi venter på serveren framfor å endre skjermen med én gang. En bryter som slår om
    /// og så spretter tilbake er verre enn en som bruker et halvt sekund — særlig når det
    /// den styrer er et lys man ser på.
    private func styr(_ id: String, _ domain: String, _ service: String, _ data: [String: Any]) async {
        jobber.insert(id)
        defer { jobber.remove(id) }
        do {
            try await api.send("/api/hus/styr",
                               ["domain": domain, "service": service, "data": data])
            try? await Task.sleep(for: .milliseconds(400))
            await hent()
        } catch { feil = error.localizedDescription }
    }

    /// Garasjeporten. Vi bekrefter først: porten veksler, så et feiltrykk på vei ut av
    /// huset lukker den bak bilen.
    private func port() async {
        jobber.insert("garasje")
        defer { jobber.remove("garasje") }
        do {
            try await api.send("/api/hus/garasje", [:])
            // Porten bruker ~15 sekunder på å gå. Vi henter et par ganger så kortet
            // ikke står og påstår «lukket» mens den er på vei opp.
            for _ in 0..<3 {
                try? await Task.sleep(for: .seconds(3))
                await hent()
            }
        } catch { feil = error.localizedDescription }
    }

    /// Signaturen `Romoverlay` og bolkene deler. Flisene styrer grupper, radene styrer
    /// én ting — men veien ut er den samme.
    private func styrEntitet(_ id: String, _ domain: String, _ service: String,
                             _ data: [String: Any]) async {
        await styr(id, domain, service, data)
    }

    /// «i huset nå» når tallet er ferskt, ellers hvor gammelt det er.
    ///
    /// Under et halvt minutt er «12 sekunder siden» støy — da ER det nå. Over det skal
    /// alderen stå: en skjerm man tror er live, men ikke er det, er verre enn en som
    /// sier fra.
    private func alderstekst() -> String {
        guard let hentet else { return "i huset nå" }
        let sek = Date().timeIntervalSince(hentet)
        return sek < 30 ? "i huset nå" : "målt for \(varighet(sek, kort: true)) siden"
    }

    // MARK: forsidens toppkort

    /// Effekt, pris og lys — husets puls.
    ///
    /// Tre tall som betyr noe hver for seg, men som hører sammen: hvor mye som går, hva
    /// det koster, og hvor mye som står på. Tidligere sto de på rad i samme størrelse og
    /// slåss om oppmerksomheten. Nå leses effekten først, kostnaden er avledet, og lysene
    /// er en egen ting til høyre.
    private func stromkort(_ s: Husstatus) -> some View {
        let kw = s.effekt_watt.map { Double($0) / 1000 }
        return Flate(aktiv: false) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Nøkkeltall(verdi: kw.map { String(format: "%.1f", $0) } ?? "–",
                               enhet: "kW",
                               // IKKE `.formatted(.relative(...))`: den bruker systemets
                               // locale, ikke appens, og ga «oppdatert in 0 seconds».
                               // Samme felle som klokkeslettene 3. september.
                               etikett: alderstekst(),
                               stor: true)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        if let w = s.effekt_watt, let p = s.kr_per_kwh {
                            // Under en krone i timen leses ører lettere; over leses
                            // kroner lettere. «319 øre/t» er et tall man må regne om.
                            let kr = Double(w) / 1000 * p
                            HStack(alignment: .firstTextBaseline, spacing: 3) {
                                Text(kr < 1 ? String(format: "%.0f", kr * 100)
                                            : String(format: "%.2f", kr))
                                    .font(.system(size: 20, weight: .medium).monospacedDigit())
                                    .foregroundStyle(Farge.tekst)
                                    .contentTransition(.numericText())
                                Text(kr < 1 ? "øre/t" : "kr/t")
                                    .font(.caption2).foregroundStyle(Farge.dempet)
                            }
                        }
                        HStack(spacing: 5) {
                            Image(systemName: s.lys_paa > 0 ? "lightbulb.fill" : "lightbulb")
                                .font(.caption2)
                            Text("\(s.lys_paa) lys på").font(.caption)
                        }
                        .foregroundStyle(s.lys_paa > 0 ? Farge.aksent : Farge.svak)
                    }
                }
                // Stolpen gir effekten en størrelse å måles mot. Uten en skala er den
                // bare en strek: 3,4 kW sier lite hvis man ikke vet hva som er mye.
                VStack(spacing: 4) {
                    Stolpe(andel: (kw ?? 0) / 10)
                    HStack {
                        Text("0").font(.system(size: 9)).foregroundStyle(Farge.svak)
                        Spacer()
                        Text("10 kW").font(.system(size: 9)).foregroundStyle(Farge.svak)
                    }
                }
            }
            .padding(14)
        }
    }

    /// Scenene som brikker.
    ///
    /// De var to grå knapper i en boks med overskrift. Overskriften sa «SCENER», som er
    /// et ord fra systemet, ikke fra huset. Nå er de bare to brikker man trykker på.
    @ViewBuilder
    private func scenekort(_ s: Husstatus) -> some View {
        VStack(spacing: 10) {
            // «Lys 1. etg» — nettbrettets hurtigknapp. Gruppa er dimbar, så én glider
            // styrer hele etasjen, og medlemslista bor i HA og ikke to steder.
            if let sc = s.scener, let gruppe = entiteter.first(where: { $0.id == sc.alt1etgAv }) {
                Flate(aktiv: gruppe.paa, radius: Hus.radiusLiten) {
                    VStack(alignment: .leading, spacing: 9) {
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Lys 1. etasje").font(.subheadline.weight(.medium))
                                    .foregroundStyle(Farge.tekst)
                                Text(gruppe.paa
                                     ? (gruppe.lysstyrke.map { "på · \($0) %" } ?? "på")
                                     : "av")
                                    .font(.caption2).foregroundStyle(Farge.svak)
                            }
                            Spacer()
                            Strømknapp(paa: gruppe.paa, jobber: jobber.contains("1etg"),
                                       størrelse: 40) {
                                Task {
                                    await styr("1etg", "light",
                                               gruppe.paa ? "turn_off" : "turn_on",
                                               ["entity_id": gruppe.id])
                                }
                            }
                        }
                        if gruppe.dimbar {
                            Etasjedimmer(gruppe: gruppe, jobber: jobber.contains("1etg"),
                                         styr: styrEntitet)
                        }
                    }
                    .padding(13)
                }
            }
            scenebrikker(s)
        }
    }

    private func scenebrikker(_ s: Husstatus) -> some View {
        HStack(spacing: 10) {
            if let sc = s.scener {
                scenebrikke("Alt av 1. etg", "moon.zzz.fill", "alt1etg") {
                    await styr("alt1etg", "light", "turn_off", ["entity_id": sc.alt1etgAv])
                }
                scenebrikke("God natt", "bed.double.fill", "godnatt") {
                    await styr("godnatt", "light", "turn_off", ["entity_id": sc.godNattAv])
                    await styr("godnatt", "light", "turn_on",
                               ["entity_id": sc.godNattDempes.entity_id,
                                "brightness": sc.godNattDempes.brightness])
                }
            }
        }
    }

    private func scenebrikke(_ tittel: String, _ ikon: String, _ id: String,
                             _ handling: @escaping () async -> Void) -> some View {
        Button {
            Kjenn.trykk()
            Task { await handling(); Kjenn.vellykket() }
        } label: {
            Flate(radius: Hus.radiusLiten) {
                HStack(spacing: 8) {
                    if jobber.contains(id) {
                        ProgressView().controlSize(.mini).tint(Farge.dempet)
                    } else {
                        Image(systemName: ikon).font(.footnote).foregroundStyle(Farge.aksent)
                    }
                    Text(tittel).font(.footnote.weight(.medium)).foregroundStyle(Farge.tekst)
                        .lineLimit(1).minimumScaleFactor(0.85)
                }
                .padding(.horizontal, 12).padding(.vertical, 12)
                .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(Trykkflate())
        .disabled(jobber.contains(id))
    }

    private func garasjekort(_ s: Husstatus) -> some View {
        let åpen = s.garasje?.aapen == true
        return Flate(aktiv: åpen) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(åpen ? Farge.aksent.opacity(0.16) : Farge.kort2)
                    Image(systemName: åpen ? "door.garage.open" : "door.garage.closed")
                        .font(.system(size: 17))
                        .foregroundStyle(åpen ? Farge.aksent : Farge.dempet)
                }
                .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Garasjeport").font(.subheadline.weight(.medium))
                        .foregroundStyle(Farge.tekst)
                    // Uten magnetkontakt vet vi ikke. Da sier vi det, framfor «Lukket».
                    Text(s.garasje.map { $0.aapen ? "Åpen" : "Lukket" } ?? "Ukjent tilstand")
                        .font(.caption)
                        .foregroundStyle(s.garasje == nil ? Farge.svak
                                         : (åpen ? Farge.aksent : Farge.svak))
                }
                Spacer()
                Button {
                    Kjenn.trykk()
                    bekreftPort = true
                } label: {
                    if jobber.contains("garasje") {
                        ProgressView().controlSize(.small).tint(Farge.dempet)
                            .frame(width: 78, height: 36)
                    } else {
                        Text(åpen ? "Lukk" : "Åpne")
                            .font(.footnote.weight(.semibold))
                            .frame(width: 78, height: 36)
                            .background(Farge.kort2)
                            .foregroundStyle(Farge.tekst)
                            .clipShape(Capsule())
                    }
                }
                .buttonStyle(Trykkflate())
                .disabled(jobber.contains("garasje"))
            }
            .padding(14)
        }
    }

    // MARK: rommene

    /// Ett rom som flis.
    ///
    /// Flisa gjør to ting, og de er tydelig skilt: **strømknappen** slår rommets lys av
    /// eller på, resten av flisa **åpner** rommet. Før satt en systembryter midt i et
    /// kort som også kunne trykkes, og ingenting sa hva som skjedde hvor.
    private func romflis(_ r: Husstatus.Romstatus) -> some View {
        let på = r.lys_paa > 0
        return Button {
            Kjenn.trykk()
            ark = .rom(navn: r.navn, entiteter: alleIRom(r.navn))
        } label: {
            Flate(aktiv: på, radius: Hus.radiusStor) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        Image(systemName: romikon(r.navn))
                            .font(.system(size: 17))
                            .foregroundStyle(på ? Farge.aksent : Farge.dempet)
                        Spacer()
                        if r.lys_totalt > 0 {
                            Strømknapp(paa: på, jobber: jobber.contains(r.navn), størrelse: 34) {
                                Task {
                                    await styr(r.navn, "light", på ? "turn_off" : "turn_on",
                                               ["entity_id": lysIRom(r.navn)])
                                }
                            }
                        }
                    }
                    Spacer(minLength: 6)
                    // Navn og tall får FAST høyde. Uten det bestemmer innholdet hvor
                    // teksten havner, og to fliser ved siden av hverandre fikk navnet i
                    // ulik høyde — det ene som er umulig å overse når man først ser det.
                    VStack(alignment: .leading, spacing: 3) {
                    Text(r.navn)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Farge.tekst)
                        .lineLimit(2).multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        // Prosent, som på nettbrettet. «2/3» sier hvor mange pærer som
                        // står på; prosenten sier hvor lyst det ER i rommet, og det er
                        // det man ser etter.
                        if r.lys_totalt > 0 {
                            Text(på ? (lysnivaa(r.navn).map { "\(Int($0 * 100)) %" } ?? "på")
                                    : "av")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(på ? Farge.aksent : Farge.svak)
                        }
                        if let t = r.temp {
                            Text(String(format: "%.1f°", t))
                                .font(.caption2.monospacedDigit()).foregroundStyle(Farge.dempet)
                        }
                        // Ikon OG farge — fargen alene skal ikke bære betydningen.
                        if let k = r.klima, k != "av" {
                            Image(systemName: k == "varmer" ? "flame.fill" : "snowflake")
                                .font(.system(size: 9))
                                .foregroundStyle(k == "varmer" ? Farge.varm : Farge.kjol)
                        }
                    }
                    }
                    .frame(height: 42, alignment: .bottomLeading)
                    // Hvor sterkt rommet lyser, ikke bare AT det lyser. Plassen er satt
                    // av alltid, så en flis som kan dimmes ikke blir høyere enn naboen.
                    // `Color.clear`, ikke en tom `Group`: en tom Group blir EmptyView,
                    // som ikke tar plass uansett hvilken høyde man ber om. Derfor sto
                    // navnene fortsatt i ulik høyde etter forrige forsøk.
                    Group {
                        if på, let niva = lysnivaa(r.navn) {
                            Stolpe(andel: niva, høyde: 3)
                        } else {
                            Color.clear
                        }
                    }
                    .frame(height: 3)
                    .padding(.top, 8)
                }
                .padding(13)
                .frame(height: 116, alignment: .topLeading)
            }
        }
        .buttonStyle(Trykkflate())
    }

    /// Hvorfor et rom er tomt. «Ingenting å styre her» er sant på tre helt ulike måter,
    /// og forskjellen er hele forskjellen når noe skal rettes.
    private func merknad(_ ider: [String]) -> String? {
        if let f = modellFeil, modell == nil { return "Fikk ikke husmodellen: \(f)" }
        if ider.isEmpty { return "Rommet har ingenting registrert i husmodellen." }
        let funnet = ider.filter { id in entiteter.contains { $0.id == id } }.count
        if funnet == ider.count { return nil }
        if let f = entiteterFeil { return "Fikk ikke enhetslista: \(f)" }
        // Resten er ekte: en enhet som er utilgjengelig, filtreres bort av serveren.
        return funnet == 0
            ? "Ingen av rommets \(ider.count) enheter svarer akkurat nå."
            : "\(ider.count - funnet) av \(ider.count) enheter svarer ikke akkurat nå."
    }

    /// Alt i rommet — lys, brytere og varme. Flisa viser lysene; arket viser tingene.
    private func alleIRom(_ navn: String) -> [String] {
        guard let r = modell?.rom.first(where: { $0.navn == navn }) else { return [] }
        return r.lys + r.klima
    }

    /// Snittet av lysstyrken på de tente lysene i rommet, 0–1.
    ///
    /// Null når ingen av dem kan dimmes — en flis som alltid viser full stolpe forteller
    /// ingenting, og da er det bedre å la være å tegne den.
    private func lysnivaa(_ navn: String) -> Double? {
        let nivaaer = lysIRom(navn)
            .compactMap { id in entiteter.first { $0.id == id } }
            .filter { $0.paa }
            .compactMap { $0.lysstyrke }
        guard !nivaaer.isEmpty else { return nil }
        return Double(nivaaer.reduce(0, +)) / Double(nivaaer.count) / 100
    }

    /// Rommets lys hentes fra husmodellen, som backend eier. Appen har ingen egen liste
    /// — to lister som skal være like, driver alltid fra hverandre.
    private func lysIRom(_ navn: String) -> [String] {
        modell?.rom.first { $0.navn == navn }?.lys ?? []
    }
}
