import SwiftUI

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
    @State private var status: Husstatus?
    @State private var modell: Husmodell?
    @State private var feil: String?
    @State private var jobber: Set<String> = []
    @State private var visOppsett = false
    @State private var oppsett = Oppsett(område: "huskort", standard: ["strom", "scener", "garasje"])
    @State private var multi = Multikort()
    @State private var entiteter: [Husentitet] = []
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
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let s = status {
                        ForEach(kortIder(s), id: \.self) { id in kort(id, s) }
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button { visOppsett = true } label: { Image(systemName: "slider.horizontal.3") }
                }
            }
            .sheet(isPresented: $visOppsett) {
                if let s = status {
                    Kortoppsett(oppsett: oppsett, multi: multi,
                                kort: alleKort(s), entiteter: entiteter)
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
            .task { await hent() }
            .onChange(of: scenefase) { _, ny in if ny == .active { Task { await hent() } } }
        }
    }

    // MARK: data og styring

    private func hent() async {
        do {
            // Modellen endrer seg sjelden, men den må være der før en bryter kan brukes:
            // den vet hvilke lys som hører til hvilket rom.
            if modell == nil { modell = try? await api.hent(Husmodell.self, "/api/hus/modell") }
            let s = try await api.hent(Husstatus.self, "/api/hus/status")
            status = s; feil = nil
            // Entitetene trengs både til multikortene og til velgeren. Feiler kallet,
            // beholder vi de gamle: et kort som blir tomt fordi ett kall glapp, ser ut
            // som om noe er slettet.
            if let e = try? await api.hent([Husentitet].self, "/api/hus/entiteter") { entiteter = e }
            Delt.lagre(.init(effektWatt: s.effekt_watt, lysPaa: s.lys_paa,
                             kroner: s.kr_per_kwh, oppdatert: Date()))
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

    @ViewBuilder
    private func kort(_ id: String, _ s: Husstatus) -> some View {
        if id == "strom" { stromkort(s) }
        else if id == "scener" { scenekort(s) }
        else if id == "garasje" { garasjekort(s) }
        else if id.hasPrefix("rom:"), let r = s.rom.first(where: { "rom:" + $0.navn == id }) {
            romkort(r)
        }
        else if id.hasPrefix("multi:"), let k = multi.kort(id: id) { multikort(k, s) }
    }

    private func garasjekort(_ s: Husstatus) -> some View {
        Ramme {
            HStack(spacing: 12) {
                Image(systemName: s.garasje?.aapen == true ? "door.garage.open" : "door.garage.closed")
                    .font(.title2)
                    .foregroundStyle(s.garasje?.aapen == true ? Farge.varm : Farge.dempet)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Garasjeport").font(.subheadline.weight(.medium)).foregroundStyle(Farge.tekst)
                    // Uten magnetkontakt vet vi ikke. Da sier vi det, framfor å vise «Lukket».
                    Text(s.garasje.map { $0.aapen ? "Åpen" : "Lukket" } ?? "Ukjent tilstand")
                        .font(.caption2)
                        .foregroundStyle(s.garasje == nil ? Farge.svak
                                         : (s.garasje!.aapen ? Farge.varm : Farge.svak))
                }
                Spacer()
                Button {
                    bekreftPort = true
                } label: {
                    if jobber.contains("garasje") {
                        ProgressView().controlSize(.small).tint(Farge.dempet)
                            .frame(width: 76, height: 34)
                    } else {
                        Text(s.garasje?.aapen == true ? "Lukk" : "Åpne")
                            .font(.caption.weight(.semibold))
                            .frame(width: 76, height: 34)
                            .background(Farge.kort2).foregroundStyle(Farge.tekst)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                .disabled(jobber.contains("garasje"))
            }
        }
    }

    /// Et multikort: enten rommene fra huset, eller entitetene brukeren har plukket.
    @ViewBuilder
    private func multikort(_ k: Multikort.Kort, _ s: Husstatus) -> some View {
        Ramme {
            VStack(alignment: .leading, spacing: 10) {
                Text(k.navn.uppercased())
                    .font(.system(size: 9, weight: .semibold)).foregroundStyle(Farge.dempet)
                if k.auto {
                    // Speiler nettbrettets seks fliser. To kolonner, for det er det en
                    // telefon har plass til.
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8),
                                        GridItem(.flexible(), spacing: 8)], spacing: 8) {
                        ForEach(s.rom) { r in romflis(r) }
                    }
                } else if k.entiteter.isEmpty {
                    Text("Ingen entiteter valgt ennå. Åpne oppsettet og velg hva kortet skal vise.")
                        .font(.caption2).foregroundStyle(Farge.svak)
                } else {
                    VStack(spacing: 8) {
                        ForEach(k.entiteter, id: \.self) { id in
                            if let e = entiteter.first(where: { $0.id == id }) { rad(e) }
                        }
                    }
                }
            }
        }
    }

    private func romflis(_ r: Husstatus.Romstatus) -> some View {
        Button {
            guard r.lys_totalt > 0 else { return }
            Task { await styr(r.navn, "light", r.lys_paa > 0 ? "turn_off" : "turn_on",
                              ["entity_id": lysIRom(r.navn)]) }
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(r.navn).font(.caption.weight(.medium)).lineLimit(2)
                    .foregroundStyle(Farge.tekst)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 5) {
                    if r.lys_totalt > 0 {
                        Image(systemName: r.lys_paa > 0 ? "lightbulb.fill" : "lightbulb")
                            .foregroundStyle(r.lys_paa > 0 ? Farge.aksent : Farge.svak)
                        Text("\(r.lys_paa)/\(r.lys_totalt)").foregroundStyle(Farge.dempet)
                    }
                    if let t = r.temp {
                        Text(String(format: "%.0f°", t)).foregroundStyle(Farge.dempet)
                    }
                    if r.klima == "varmer" {
                        Image(systemName: "flame.fill").foregroundStyle(Farge.varm)
                    }
                }
                .font(.caption2)
            }
            .padding(9)
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
            .background(Farge.kort2)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .disabled(jobber.contains(r.navn) || r.lys_totalt == 0)
    }

    /// Én entitet i et multikort. Lys og brytere får en bryter; varme får måltemperatur
    /// med pluss og minus — å skru av en ovn fra en liste er lettere gjort enn angret.
    @ViewBuilder
    private func rad(_ e: Husentitet) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(e.navn).font(.caption.weight(.medium)).foregroundStyle(Farge.tekst)
                    .lineLimit(1)
                if e.domene == "climate" {
                    HStack(spacing: 5) {
                        if let t = e.temp { Text(String(format: "%.1f° nå", t)) }
                        if e.handling == "heating" {
                            Label("varmer", systemImage: "flame.fill").foregroundStyle(Farge.varm)
                        }
                    }
                    .font(.caption2).foregroundStyle(Farge.svak)
                } else if let r = e.rom {
                    Text(r).font(.caption2).foregroundStyle(Farge.svak)
                }
            }
            Spacer()
            if e.domene == "climate" {
                HStack(spacing: 4) {
                    tempknapp("minus", e, -0.5)
                    Text(e.maal.map { String(format: "%.1f°", $0) } ?? "–")
                        .font(.caption.monospacedDigit()).foregroundStyle(Farge.tekst)
                        .frame(width: 46)
                    tempknapp("plus", e, 0.5)
                }
            } else {
                Toggle("", isOn: Binding(
                    get: { e.paa },
                    set: { på in Task { await styr(e.id, e.domene, på ? "turn_on" : "turn_off",
                                                   ["entity_id": e.id]) } }))
                    .labelsHidden().tint(Farge.aksent)
                    .disabled(jobber.contains(e.id))
            }
        }
    }

    private func tempknapp(_ ikon: String, _ e: Husentitet, _ delta: Double) -> some View {
        Button {
            guard let m = e.maal else { return }
            Task { await styr(e.id, "climate", "set_temperature",
                              ["entity_id": e.id, "temperature": m + delta]) }
        } label: {
            Image(systemName: ikon).font(.caption2)
                .frame(width: 28, height: 28)
                .background(Farge.kort2).foregroundStyle(Farge.tekst)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .disabled(e.maal == nil || jobber.contains(e.id))
    }

    private func stromkort(_ s: Husstatus) -> some View {
        Ramme {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(s.effekt_watt.map { String(format: "%.1f", Double($0) / 1000) } ?? "–")
                        .font(.system(size: 34, weight: .light).monospacedDigit())
                        .foregroundStyle(Farge.tekst)
                    Text("kW akkurat nå").font(.caption2).foregroundStyle(Farge.dempet)
                }
                if let w = s.effekt_watt, let p = s.kr_per_kwh {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(String(format: "%.2f", Double(w) / 1000 * p))
                            .font(.title3.monospacedDigit()).foregroundStyle(Farge.tekst)
                        Text("kr/time").font(.caption2).foregroundStyle(Farge.dempet)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(s.lys_paa)").font(.title3.monospacedDigit()).foregroundStyle(Farge.aksent)
                    Text("lys på").font(.caption2).foregroundStyle(Farge.dempet)
                }
            }
        }
    }

    private func scenekort(_ s: Husstatus) -> some View {
        Ramme {
            VStack(alignment: .leading, spacing: 8) {
                Text("SCENER").font(.system(size: 9, weight: .semibold)).foregroundStyle(Farge.dempet)
                HStack(spacing: 8) {
                    if let sc = s.scener {
                        knapp("Alt av 1. etg", "moon.zzz", "alt1etg", jobber.contains("alt1etg")) {
                            await styr("alt1etg", "light", "turn_off", ["entity_id": sc.alt1etgAv])
                        }
                        knapp("God natt", "bed.double", "godnatt", jobber.contains("godnatt")) {
                            await styr("godnatt", "light", "turn_off", ["entity_id": sc.godNattAv])
                            await styr("godnatt", "light", "turn_on",
                                       ["entity_id": sc.godNattDempes.entity_id,
                                        "brightness": sc.godNattDempes.brightness])
                        }
                    }
                }
            }
        }
    }

    private func romkort(_ r: Husstatus.Romstatus) -> some View {
        Ramme {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(r.navn).font(.subheadline.weight(.medium)).foregroundStyle(Farge.tekst)
                    HStack(spacing: 8) {
                        if r.lys_totalt > 0 {
                            Label("\(r.lys_paa) av \(r.lys_totalt)",
                                  systemImage: r.lys_paa > 0 ? "lightbulb.fill" : "lightbulb")
                                .foregroundStyle(r.lys_paa > 0 ? Farge.aksent : Farge.svak)
                        }
                        // Ikon OG tekst — fargen alene skal ikke bære betydningen.
                        if let k = r.klima, k != "av" {
                            Label(k == "varmer" ? "varmer" : "kjøler",
                                  systemImage: k == "varmer" ? "flame.fill" : "snowflake")
                                .foregroundStyle(k == "varmer" ? Farge.varm : Farge.kjol)
                        }
                    }
                    .font(.caption2)
                }
                Spacer()
                // Null grader er en verdi; «ingen måler» er noe annet.
                if let t = r.temp {
                    Text(String(format: "%.1f°", t))
                        .font(.title3.monospacedDigit()).foregroundStyle(Farge.dempet)
                }
                if r.lys_totalt > 0 {
                    Toggle("", isOn: Binding(
                        get: { r.lys_paa > 0 },
                        set: { på in Task { await styr(r.navn, "light", på ? "turn_on" : "turn_off",
                                                       ["entity_id": lysIRom(r.navn)]) } }))
                        .labelsHidden().tint(Farge.aksent)
                        .disabled(jobber.contains(r.navn))
                }
            }
        }
    }

    /// Rommets lys hentes fra husmodellen, som backend eier. Appen har ingen egen liste
    /// — to lister som skal være like, driver alltid fra hverandre.
    private func lysIRom(_ navn: String) -> [String] {
        modell?.rom.first { $0.navn == navn }?.lys ?? []
    }

    private func knapp(_ tittel: String, _ ikon: String, _ id: String, _ jobber: Bool,
                       _ handling: @escaping () async -> Void) -> some View {
        Button { Task { await handling() } } label: {
            HStack(spacing: 6) {
                if jobber { ProgressView().controlSize(.mini).tint(Farge.dempet) }
                else { Image(systemName: ikon).font(.caption) }
                Text(tittel).font(.caption.weight(.medium))
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(Farge.kort2).foregroundStyle(Farge.tekst)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .disabled(jobber)
    }
}

/// Felles ramme for kortene, så de ser like ut uansett innhold.
private struct Ramme<Innhold: View>: View {
    @ViewBuilder var innhold: () -> Innhold
    var body: some View {
        innhold()
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Farge.kort)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
