import SwiftUI

/// Fanene i Huset, og brukerens egne.
///
/// Huset er ikke én skjerm. Strøm, oppgaver og lys hører ikke sammen — de deler bare
/// hus. Å legge alt i én rullende liste gjør at det man bruker daglig havner under noe
/// man ser på én gang i måneden.
///
/// De tre faste fanene kan skjules, men ikke slettes: de henter data appen selv leverer.
/// Egne faner er brukerens, og kan enten følge et rom eller være en fri samling.
struct Fane: Codable, Identifiable, Equatable {
    var id: String
    var navn: String
    var ikon: String
    /// `rom` = alt som hører til ett rom, og følger huset når rommet endrer seg.
    /// `egen` = en håndplukket liste.
    var slag: Slag
    /// Rommets navn når `slag == .rom`.
    var rom: String?
    /// Entitets-id-ene når `slag == .egen`.
    var entiteter: [String]

    enum Slag: String, Codable { case hjem, strom, oppgaver, rom, egen }

    /// De faste. `id` er nøkkelen rekkefølge og av/på lagres under, og skal aldri endres.
    static let faste: [Fane] = [
        Fane(id: "hjem", navn: "Huset", ikon: "house", slag: .hjem, rom: nil, entiteter: []),
        Fane(id: "strom", navn: "Strøm", ikon: "bolt", slag: .strom, rom: nil, entiteter: []),
        Fane(id: "oppgaver", navn: "Oppgaver", ikon: "checklist", slag: .oppgaver, rom: nil, entiteter: []),
    ]
}

@Observable
final class Faner {
    private let lager = UserDefaults(suiteName: Delt.gruppe) ?? .standard
    private let nøkkel = "hus.faner"
    private let skjultNøkkel = "hus.faner.skjult"

    /// Bare brukerens egne. De faste ligger i koden — lagrer vi dem også, blir en ny fast
    /// fane usynlig for alle som har brukt appen før den kom.
    private(set) var egne: [Fane]
    private(set) var skjult: Set<String>
    private(set) var rekkefølge: [String]

    init() {
        let l = UserDefaults(suiteName: Delt.gruppe) ?? .standard
        egne = (try? JSONDecoder().decode([Fane].self, from: l.data(forKey: "hus.faner") ?? Data())) ?? []
        skjult = Set(l.stringArray(forKey: "hus.faner.skjult") ?? [])
        rekkefølge = l.stringArray(forKey: "hus.faner.rekkefolge") ?? []
    }

    private func lagre() {
        lager.set((try? JSONEncoder().encode(egne)) ?? Data(), forKey: nøkkel)
        lager.set(Array(skjult), forKey: skjultNøkkel)
        lager.set(rekkefølge, forKey: "hus.faner.rekkefolge")
    }

    /// Alle faner i brukerens rekkefølge. Ukjente id-er i lageret ignoreres, og nye
    /// faner havner sist framfor å være skjult til noen finner dem i innstillingene.
    var alle: [Fane] {
        let samlet = Fane.faste + egne
        let kjent = rekkefølge.compactMap { id in samlet.first { $0.id == id } }
        return kjent + samlet.filter { f in !rekkefølge.contains(f.id) }
    }

    var synlige: [Fane] { alle.filter { !skjult.contains($0.id) } }

    func settSynlig(_ id: String, _ på: Bool) {
        // Minst én fane må stå igjen. En app uten innhold ser ødelagt ut, og veien
        // tilbake er ikke åpenbar når det ikke er noe å trykke på.
        if !på && synlige.count <= 1 { return }
        if på { skjult.remove(id) } else { skjult.insert(id) }
        rekkefølge = alle.map(\.id)
        lagre()
    }

    func flytt(fra: IndexSet, til: Int) {
        var ids = alle.map(\.id)
        ids.move(fromOffsets: fra, toOffset: til)
        rekkefølge = ids
        lagre()
    }

    @discardableResult
    func nyRomfane(_ rom: String) -> Fane {
        let f = Fane(id: UUID().uuidString, navn: rom, ikon: "square.grid.2x2",
                     slag: .rom, rom: rom, entiteter: [])
        egne.append(f); lagre(); return f
    }

    @discardableResult
    func nyEgenfane() -> Fane {
        let f = Fane(id: UUID().uuidString, navn: "Ny fane", ikon: "star",
                     slag: .egen, rom: nil, entiteter: [])
        egne.append(f); lagre(); return f
    }

    func endre(_ f: Fane) {
        guard let i = egne.firstIndex(where: { $0.id == f.id }) else { return }
        egne[i] = f; lagre()
    }

    func slett(_ id: String) {
        egne.removeAll { $0.id == id }
        skjult.remove(id)
        rekkefølge.removeAll { $0 == id }
        lagre()
    }

    func nullstill() {
        egne = []; skjult = []; rekkefølge = []
        lager.removeObject(forKey: nøkkel)
        lager.removeObject(forKey: skjultNøkkel)
        lager.removeObject(forKey: "hus.faner.rekkefolge")
    }
}

/// Hvilke faner som vises, i hvilken rekkefølge, og redigering av egne.
struct Faneoppsett: View {
    @Bindable var faner: Faner
    let rom: [String]
    let entiteter: [Husentitet]
    @State private var redigerer: Fane?
    @State private var velgerRom = false
    @Environment(\.dismiss) private var lukk

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(faner.alle) { f in
                        HStack(spacing: 10) {
                            Image(systemName: f.ikon).font(.caption)
                                .foregroundStyle(Farge.dempet).frame(width: 20)
                            if f.slag == .rom || f.slag == .egen {
                                Button { redigerer = f } label: {
                                    HStack(spacing: 6) {
                                        Text(f.navn).font(.subheadline)
                                            .foregroundStyle(faner.skjult.contains(f.id) ? Farge.svak : Farge.tekst)
                                        Image(systemName: "chevron.right")
                                            .font(.caption2).foregroundStyle(Farge.svak)
                                    }
                                }
                                .buttonStyle(.plain)
                            } else {
                                Text(f.navn).font(.subheadline)
                                    .foregroundStyle(faner.skjult.contains(f.id) ? Farge.svak : Farge.tekst)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(get: { !faner.skjult.contains(f.id) },
                                                     set: { faner.settSynlig(f.id, $0) }))
                                .labelsHidden().tint(Farge.aksent)
                        }
                        .listRowBackground(Farge.kort)
                    }
                    .onMove { faner.flytt(fra: $0, til: $1) }
                } footer: {
                    Text("Dra for å endre rekkefølgen. Minst én fane må være på.")
                        .font(.caption2).foregroundStyle(Farge.svak)
                }

                Section {
                    Button { velgerRom = true } label: {
                        Label("Fane for et rom", systemImage: "square.grid.2x2")
                    }
                    .listRowBackground(Farge.kort)
                    Button { redigerer = faner.nyEgenfane() } label: {
                        Label("Egen fane", systemImage: "star")
                    }
                    .listRowBackground(Farge.kort)
                } header: {
                    Text("Ny fane")
                } footer: {
                    Text("En romfane følger huset — kommer det et lys i rommet, dukker "
                         + "det opp her av seg selv. En egen fane er din liste, og "
                         + "endrer seg bare når du endrer den.")
                        .font(.caption2).foregroundStyle(Farge.svak)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Farge.flate)
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Faner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Farge.flate, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Nullstill") { faner.nullstill() }.foregroundStyle(Farge.svak)
                }
                ToolbarItem(placement: .topBarTrailing) { Button("Ferdig") { lukk() } }
            }
            .sheet(item: $redigerer) { f in
                Faneredigering(faner: faner, fane: f, entiteter: entiteter)
            }
            .confirmationDialog("Hvilket rom?", isPresented: $velgerRom, titleVisibility: .visible) {
                ForEach(rom, id: \.self) { r in
                    Button(r) { faner.nyRomfane(r) }
                }
                Button("Avbryt", role: .cancel) {}
            }
        }
    }
}

/// Navn, ikon og innhold i en egen fane.
struct Faneredigering: View {
    @Bindable var faner: Faner
    @State var fane: Fane
    let entiteter: [Husentitet]
    @State private var søk = ""
    @Environment(\.dismiss) private var lukk

    private static let ikoner = ["star", "square.grid.2x2", "lightbulb", "flame",
                                 "bolt", "bed.double", "sofa", "shower", "car",
                                 "leaf", "moon", "sun.max"]

    private var treff: [Husentitet] {
        let s = søk.trimmingCharacters(in: .whitespaces).lowercased()
        let liste = s.isEmpty ? entiteter : entiteter.filter {
            $0.navn.lowercased().contains(s) || $0.id.lowercased().contains(s)
                || ($0.rom?.lowercased().contains(s) ?? false)
        }
        return liste.sorted { a, b in
            let va = fane.entiteter.contains(a.id), vb = fane.entiteter.contains(b.id)
            if va != vb { return va }
            return a.navn.localizedStandardCompare(b.navn) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Navn", text: $fane.navn).listRowBackground(Farge.kort)
                    // Ikonet er det eneste som skiller fanene når navnene er korte.
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Self.ikoner, id: \.self) { i in
                                Button { fane.ikon = i } label: {
                                    Image(systemName: i).font(.body)
                                        .frame(width: 40, height: 40)
                                        .background(fane.ikon == i ? Farge.aksent.opacity(0.25) : Farge.kort2)
                                        .foregroundStyle(fane.ikon == i ? Farge.aksent : Farge.dempet)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Farge.kort)
                }

                if fane.slag == .egen {
                    Section {
                        ForEach(treff) { e in
                            Button {
                                if let i = fane.entiteter.firstIndex(of: e.id) {
                                    fane.entiteter.remove(at: i)
                                } else {
                                    fane.entiteter.append(e.id)
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(e.navn).font(.subheadline).foregroundStyle(Farge.tekst)
                                        if let r = e.rom {
                                            Text(r).font(.caption2).foregroundStyle(Farge.svak)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: fane.entiteter.contains(e.id)
                                          ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(fane.entiteter.contains(e.id) ? Farge.aksent : Farge.svak)
                                }
                            }
                            .listRowBackground(Farge.kort)
                        }
                    } header: {
                        Text("\(fane.entiteter.count) valgt")
                    }
                } else if let r = fane.rom {
                    Section {
                        Text("Viser alt i \(r), og følger rommet når huset endrer seg.")
                            .font(.caption).foregroundStyle(Farge.svak)
                            .listRowBackground(Farge.kort)
                    }
                }

                Section {
                    Button("Slett fanen", role: .destructive) { faner.slett(fane.id); lukk() }
                        .listRowBackground(Farge.kort)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Farge.flate)
            .searchable(text: $søk, prompt: "Søk i huset")
            .navigationTitle(fane.slag == .rom ? "Romfane" : "Egen fane")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Farge.flate, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Ferdig") { faner.endre(fane); lukk() }
                }
            }
            .onDisappear { faner.endre(fane) }
        }
    }
}
