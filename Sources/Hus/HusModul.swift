import SwiftUI
import WidgetKit

/// «Huset» — smarthus-dashbordet i appen.
///
/// Bygget av **kort** som brukeren selv velger og ordner, på samme måte som modulene på
/// hjemskjermen. Ett rom er ett kort; scener og strøm er egne kort. Den som bare bryr
/// seg om varmen, skrur av resten.
///
/// Appen regner ikke ut noe selv — den viser hva serveren sier. To klienter som regner
/// hver for seg kommer fram til forskjellige svar.
struct HusModul: View {
    let api: API
    @State private var faner = Faner()
    @State private var valgtFane = Testskjerm.fane ?? "hjem"
    /// Hvilket ark som er åpent.
    ///
    /// ÉN tilstand, ikke tre. `.sheet` på samme visning oppfører seg uforutsigbart når
    /// den står flere ganger — det var slik trykk på et romkort ikke gjorde noe: arket
    /// ble aldri festet, og tilstanden ble satt uten at noen viste den.
    @State private var ark: Ark?

    enum Ark: Identifiable {
        case faner
        case kort
        case rom(navn: String, entiteter: [String])

        var id: String {
            switch self {
            case .faner: "faner"
            case .kort: "kort"
            case .rom(let n, _): "rom:" + n
            }
        }
    }
    @State private var status: Husstatus?
    @State private var modell: Husmodell?
    @State private var feil: String?
    @State private var jobber: Set<String> = []
    @State private var oppsett = Oppsett(område: "huskort", standard: ["strom", "scener", "garasje"])
    @State private var multi = Multikort()
    @State private var entiteter: [Husentitet] = []
    /// Når tallene sist kom inn. En skjerm som viser et gammelt tall uten å si det, er
    /// verre enn en tom skjerm — man tror den er live.
    @State private var hentet: Date?
    @State private var entiteterFeil: String?
    @State private var modellFeil: String?
    @State private var bekreftPort = false
    @Environment(\.scenePhase) private var scenefase

    /// Kort-id-ene i visningsrekkefølge. Rommene kommer fra serveren, så lista er ikke
    /// hardkodet — nye rom dukker opp av seg selv.
    private func kortIder(_ s: Husstatus) -> [String] {
        oppsett.synlige(av: alleKort(s))
    }

    private func alleKort(_ s: Husstatus) -> [String] {
        ["strom", "scener", "garasje"] + s.rom.map { "rom:" + $0.navn } + multi.ider
    }

    var body: some View {
        TabView(selection: $valgtFane) {
            ForEach(faner.synlige) { f in
                fanevisning(f)
                    .tabItem { Label(f.navn, systemImage: f.ikon) }
                    .tag(f.id)
            }
        }
        .tint(Farge.aksent)
        // Arket henger på TabView-en, ikke på hver fane. Festet per fane ville to
        // visninger bundet til samme tilstand kappes om å vise det samme.
        .sheet(item: $ark) { arkvisning($0) }
    }

    /// Innholdet i én fane. Rom- og egen-faner er samme visning med ulik kilde til
    /// entitetslista — rommet spør huset, den egne spør brukerens eget utvalg.
    @ViewBuilder
    private func fanevisning(_ f: Fane) -> some View {
        switch f.slag {
        case .hjem:     hjemfane
        case .strom:    ramme(f) { Stromfane(api: api) }
        case .oppgaver: ramme(f) { Oppgaverfane(api: api) }
        case .rom:      ramme(f) { entitetsliste(iRom(f.rom)) }
        case .egen:     ramme(f) { entitetsliste(f.entiteter) }
        }
    }

    /// Felles skall: tittel, oppsett-knapp og oppdatering. Uten dette måtte hver fane
    /// husket å ha dem, og en fane uten vei til oppsettet er en blindvei.
    @ViewBuilder
    private func ramme<Innhold: View>(_ f: Fane,
                                      @ViewBuilder _ innhold: () -> Innhold) -> some View {
        NavigationStack {
            innhold()
                .navigationTitle(f.navn)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Farge.flate, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { ark = .faner } label: {
                            Image(systemName: "slider.horizontal.3")
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private func arkvisning(_ a: Ark) -> some View {
        switch a {
        case .faner:
            faneoppsett
        case .kort:
            if let s = status {
                Kortoppsett(oppsett: oppsett, multi: multi,
                            kort: alleKort(s), entiteter: entiteter)
            }
        case .rom(let navn, let ider):
            Romoverlay(tittel: navn,
                       entiteter: ider.compactMap { id in entiteter.first { $0.id == id } },
                       styr: styrEntitet, jobber: jobber,
                       merknad: merknad(ider))
        }
    }

    private var faneoppsett: some View {
        Faneoppsett(faner: faner,
                    rom: status?.rom.map(\.navn) ?? [],
                    entiteter: entiteter)
    }

    /// Entitetene i et rom, hentet fra husmodellen. Appen har ingen egen liste — da ville
    /// et nytt lys i rommet krevd en ny app-versjon.
    private func iRom(_ navn: String?) -> [String] {
        guard let navn, let r = modell?.rom.first(where: { $0.navn == navn }) else { return [] }
        return r.lys + r.klima
    }

    /// En rom- eller egen-fane: tingene, med dimmer og varme, uten omvei via et kort.
    @ViewBuilder
    private func entitetsliste(_ ids: [String]) -> some View {
        let valgte = ids.compactMap { id in entiteter.first { $0.id == id } }
        if status == nil {
            ProgressView().tint(Farge.dempet).frame(maxWidth: .infinity).padding(.top, 40)
                .frame(maxHeight: .infinity).background(Farge.flate)
        } else if valgte.isEmpty {
            VStack(spacing: 6) {
                Text("Ingenting valgt i denne fanen ennå.")
                    .font(.footnote).foregroundStyle(Farge.svak)
                Text("Åpne oppsettet øverst til høyre.")
                    .font(.caption2).foregroundStyle(Farge.svak)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity).background(Farge.flate)
        } else {
            Romoverlay.Innhold(entiteter: valgte, styr: styrEntitet, jobber: jobber)
                .background(Farge.flate)
                .refreshable { await hent() }
        }
    }

    /// Signaturen `Romoverlay` og fanene deler. Kortene styrer grupper, radene styrer
    /// én ting — men veien ut er den samme.
    private func styrEntitet(_ id: String, _ domain: String, _ service: String,
                             _ data: [String: Any]) async {
        await styr(id, domain, service, data)
    }

    private var hjemfane: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let s = status {
                        ForEach(strekk(s)) { strekkvisning($0, s) }
                        if kortIder(s).isEmpty {
                            Text("Ingen kort er slått på. Trykk på oppsett øverst til høyre.")
                                .font(.footnote).foregroundStyle(Farge.svak)
                        }
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
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { ark = .faner } label: { Image(systemName: "rectangle.3.group") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { ark = .kort } label: { Image(systemName: "slider.horizontal.3") }
                }
            }
            .alert("Garasjeport", isPresented: $bekreftPort) {
                Button("Avbryt", role: .cancel) {}
                Button(status?.garasje?.aapen == true ? "Lukk" : "Åpne") {
                    Task { await port() }
                }
            } message: {
                Text(status?.garasje?.aapen == true
                     ? "Lukke garasjeporten?" : "Åpne garasjeporten?")
            }
            .refreshable { await hent() }
            .task {
                await hent()
                // CI åpner et rom ved oppstart, så skjermbildet dekker dimmeren og
                // varmen — en visning som ellers krever et trykk.
                if let r = Testskjerm.apneRom, ark == nil {
                    ark = .rom(navn: r, entiteter: alleIRom(r))
                }
            }
            .onChange(of: scenefase) { _, ny in if ny == .active { Task { await hent() } } }
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

    // MARK: kortene

    /// «i huset nå» når tallet er ferskt, ellers hvor gammelt det er.
    ///
    /// Under et halvt minutt er «12 sekunder siden» støy — da ER det nå. Over det skal
    /// alderen stå, for en skjerm man tror er live, men ikke er det, er verre enn en
    /// skjerm som sier fra.
    private func alderstekst() -> String {
        guard let hentet else { return "i huset nå" }
        let sek = Date().timeIntervalSince(hentet)
        return sek < 30 ? "i huset nå" : "målt for \(varighet(sek, kort: true)) siden"
    }

    /// Kortene delt i strekk, der rom slås sammen til ett rutenett.
    ///
    /// Rommene var én kolonne høye kort. Sju rom fylte da hele skjermen og vel så det,
    /// og alt så likt ut. Som fliser i to kolonner får man oversikten uten å rulle, og
    /// hvert rom får plass til å se forskjellig ut fra de andre.
    ///
    /// Rekkefølgen er fortsatt brukerens: bare rom som ligger etter hverandre slås
    /// sammen. Legger man strømkortet mellom to rom, blir det to rutenett.
    private enum Strekk: Identifiable {
        case enkelt(String)
        case rom([String])
        var id: String {
            switch self {
            case .enkelt(let i): "e:" + i
            case .rom(let r): "r:" + (r.first ?? "")
            }
        }
    }

    private func strekk(_ s: Husstatus) -> [Strekk] {
        var ut: [Strekk] = []
        for id in kortIder(s) {
            if id.hasPrefix("rom:") {
                if case .rom(let r)? = ut.last {
                    ut[ut.count - 1] = .rom(r + [id])
                } else {
                    ut.append(.rom([id]))
                }
            } else {
                ut.append(.enkelt(id))
            }
        }
        return ut
    }

    @ViewBuilder
    private func strekkvisning(_ st: Strekk, _ s: Husstatus) -> some View {
        switch st {
        case .enkelt(let id):
            kort(id, s)
        case .rom(let ider):
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(ider, id: \.self) { id in
                    if let r = s.rom.first(where: { "rom:" + $0.navn == id }) { romflis(r) }
                }
            }
        }
    }

    @ViewBuilder
    private func kort(_ id: String, _ s: Husstatus) -> some View {
        if id == "strom" { stromkort(s) }
        else if id == "scener" { scenekort(s) }
        else if id == "garasje" { garasjekort(s) }
        else if id.hasPrefix("rom:"), let r = s.rom.first(where: { "rom:" + $0.navn == id }) {
            romflis(r)
        }
        else if id.hasPrefix("multi:"), let k = multi.kort(id: id) { multikort(k, s) }
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
    private func scenekort(_ s: Husstatus) -> some View {
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
                        if r.lys_totalt > 0 {
                            Text("\(r.lys_paa)/\(r.lys_totalt)")
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

    /// Et multikort: enten rommene fra huset, eller entitetene brukeren har plukket.
    @ViewBuilder
    private func multikort(_ k: Multikort.Kort, _ s: Husstatus) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Seksjonstittel(tekst: k.navn)
            if k.auto {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                    GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(s.rom) { r in romflis(r) }
                }
            } else if k.entiteter.isEmpty {
                Flate(radius: Hus.radiusLiten) {
                    Text("Ingenting valgt ennå. Åpne oppsettet og velg hva kortet skal vise.")
                        .font(.caption).foregroundStyle(Farge.svak)
                        .padding(13).frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                    GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(k.entiteter, id: \.self) { id in
                        if let e = entiteter.first(where: { $0.id == id }) { entitetsflis(e) }
                    }
                }
            }
        }
    }

    /// Én entitet som flis i et multikort.
    private func entitetsflis(_ e: Husentitet) -> some View {
        Flate(aktiv: e.paa, radius: Hus.radiusLiten) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Image(systemName: e.domene == "climate" ? "thermometer.medium"
                          : (e.domene == "switch" ? "poweroutlet.type-f" : "lightbulb.fill"))
                        .font(.system(size: 15))
                        .foregroundStyle(e.paa ? Farge.aksent : Farge.dempet)
                    Spacer()
                    if e.domene == "climate" {
                        Text(e.maal.map { String(format: "%.1f°", $0) } ?? "–")
                            .font(.caption.monospacedDigit()).foregroundStyle(Farge.tekst)
                    } else {
                        Strømknapp(paa: e.paa, jobber: jobber.contains(e.id), størrelse: 32) {
                            Task {
                                await styr(e.id, e.domene, e.paa ? "turn_off" : "turn_on",
                                           ["entity_id": e.id])
                            }
                        }
                    }
                }
                Spacer(minLength: 8)
                Text(e.navn).font(.caption.weight(.medium)).foregroundStyle(Farge.tekst)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                if e.domene == "climate", let t = e.temp {
                    Text(String(format: "%.1f° nå", t))
                        .font(.system(size: 10).monospacedDigit()).foregroundStyle(Farge.svak)
                } else if let l = e.lysstyrke, e.paa {
                    Text("\(l) %")
                        .font(.system(size: 10).monospacedDigit()).foregroundStyle(Farge.aksent)
                }
            }
            .padding(12)
            .frame(height: 108, alignment: .topLeading)
        }
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

/// Hvilke kort som vises i Huset, i hvilken rekkefølge — og brukerens egne multikort.
struct Kortoppsett: View {
    @Bindable var oppsett: Oppsett
    @Bindable var multi: Multikort
    let kort: [String]
    let entiteter: [Husentitet]
    @State private var redigerer: Multikort.Kort?
    @Environment(\.dismiss) private var lukk

    private func navn(_ id: String) -> String {
        switch id {
        case "strom": return "Strøm"
        case "scener": return "Scener"
        case "garasje": return "Garasjeport"
        default:
            if id.hasPrefix("multi:") { return multi.kort(id: id)?.navn ?? "Multikort" }
            return String(id.dropFirst(4))
        }
    }

    /// Multikortene kan redigeres; de faste kortene kan bare slås av og flyttes.
    private func erMulti(_ id: String) -> Bool { id.hasPrefix("multi:") }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(oppsett.ordne(kort), id: \.self) { id in
                        HStack {
                            if erMulti(id) {
                                Button {
                                    redigerer = multi.kort(id: id)
                                } label: {
                                    HStack(spacing: 6) {
                                        Text(navn(id)).font(.subheadline)
                                            .foregroundStyle(oppsett.skjult.contains(id) ? Farge.svak : Farge.tekst)
                                        Image(systemName: "chevron.right")
                                            .font(.caption2).foregroundStyle(Farge.svak)
                                    }
                                }
                                .buttonStyle(.plain)
                            } else {
                                Text(navn(id)).font(.subheadline)
                                    .foregroundStyle(oppsett.skjult.contains(id) ? Farge.svak : Farge.tekst)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(get: { !oppsett.skjult.contains(id) },
                                                     set: { oppsett.settSynlig(id, $0) }))
                                .labelsHidden().tint(Farge.aksent)
                        }
                        .listRowBackground(Farge.kort)
                    }
                    .onMove { oppsett.flyttIds(kort, fra: $0, til: $1) }
                } footer: {
                    Text("Dra for å endre rekkefølgen. Rommene kommer fra huset, så nye "
                         + "rom dukker opp nederst av seg selv.")
                        .font(.caption2).foregroundStyle(Farge.svak)
                }

                Section {
                    Button {
                        redigerer = multi.nytt(auto: false)
                    } label: {
                        Label("Kort med egne entiteter", systemImage: "plus.circle")
                    }
                    .listRowBackground(Farge.kort)
                    Button {
                        redigerer = multi.nytt(auto: true)
                    } label: {
                        Label("Kort med alle rommene", systemImage: "square.grid.2x2")
                    }
                    .listRowBackground(Farge.kort)
                } header: {
                    Text("Nytt multikort")
                } footer: {
                    Text("Et multikort samler det du vil ha sammen — enten du plukker "
                         + "entitetene selv, eller lar det følge de samme rommene som "
                         + "nettbrettet viser.")
                        .font(.caption2).foregroundStyle(Farge.svak)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Farge.flate)
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Kort i Huset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Farge.flate, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Nullstill") { oppsett.nullstill() }.foregroundStyle(Farge.svak)
                }
                ToolbarItem(placement: .topBarTrailing) { Button("Ferdig") { lukk() } }
            }
            .sheet(item: $redigerer) { k in
                Multikortredigering(multi: multi, kort: k, entiteter: entiteter)
            }
        }
    }
}
