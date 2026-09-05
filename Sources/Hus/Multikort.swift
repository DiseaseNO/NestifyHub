import SwiftUI

/// Brukerens egne multikort.
///
/// Et multikort er en håndplukket samling entiteter — «det jeg vil ha på forsiden»
/// framfor rommene huset tilfeldigvis er delt inn i. Vaskerom, varmekabler og utelys
/// hører ikke til samme rom, men de hører gjerne til samme kort.
///
/// Alternativet — «velg entiteter» rett i romkortene — ble forkastet fordi rommene
/// eies av backend. Skal appen kunne overstyre dem, må appen ha sin egen liste, og da
/// har vi to lister som skal være like. Multikortet er en egen ting ved siden av, ikke
/// en overstyring.
///
/// Lagres i app-gruppa, som resten av oppsettet, så widgeten kan lese det senere.
@Observable
final class Multikort {
    private let lager = UserDefaults(suiteName: Delt.gruppe) ?? .standard
    private let nøkkel = "huskort.multi"

    private(set) var kort: [Kort]

    /// Ett multikort. `id` er en UUID-streng og skal aldri endres — den er nøkkelen
    /// rekkefølgen og av/på lagres under i `Oppsett`.
    struct Kort: Codable, Identifiable, Equatable {
        var id: String
        var navn: String
        /// Sant = speil rommene fra huset, akkurat som nettbrettet. Da følger kortet
        /// huset når det endrer seg, i stedet for å bli stående med en gammel liste.
        var auto: Bool
        var entiteter: [String]
    }

    init() {
        let d = lager.data(forKey: "huskort.multi") ?? Data()
        kort = (try? JSONDecoder().decode([Kort].self, from: d)) ?? []
    }

    private func lagre() {
        lager.set((try? JSONEncoder().encode(kort)) ?? Data(), forKey: nøkkel)
    }

    /// Kort-id-ene slik dashbordet kjenner dem.
    var ider: [String] { kort.map { "multi:" + $0.id } }

    func kort(id: String) -> Kort? {
        kort.first { "multi:" + $0.id == id || $0.id == id }
    }

    @discardableResult
    func nytt(auto: Bool) -> Kort {
        let k = Kort(id: UUID().uuidString, navn: auto ? "Alle rom" : "Nytt kort",
                     auto: auto, entiteter: [])
        kort.append(k)
        lagre()
        return k
    }

    func endre(_ k: Kort) {
        guard let i = kort.firstIndex(where: { $0.id == k.id }) else { return }
        kort[i] = k
        lagre()
    }

    func slett(_ id: String) {
        kort.removeAll { $0.id == id }
        lagre()
    }
}

/// Redigering av ett multikort: navn, om det følger rommene, og hvilke entiteter det viser.
struct Multikortredigering: View {
    @Bindable var multi: Multikort
    @State var kort: Multikort.Kort
    let entiteter: [Husentitet]
    @State private var søk = ""
    @Environment(\.dismiss) private var lukk

    /// Treff på både navnet og entitets-id-en. Man husker ofte det ene og ikke det andre.
    private var treff: [Husentitet] {
        let s = søk.trimmingCharacters(in: .whitespaces).lowercased()
        guard !s.isEmpty else { return entiteter }
        return entiteter.filter {
            $0.navn.lowercased().contains(s) || $0.id.lowercased().contains(s)
                || ($0.rom?.lowercased().contains(s) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Navn på kortet", text: $kort.navn)
                        .listRowBackground(Farge.kort)
                    Toggle("Følg rommene i huset", isOn: $kort.auto)
                        .tint(Farge.aksent).listRowBackground(Farge.kort)
                } footer: {
                    Text(kort.auto
                         ? "Kortet viser de samme rommene som nettbrettet, og følger huset når det endrer seg."
                         : "Velg selv hva kortet skal vise. Ting som ikke hører til samme rom kan godt høre til samme kort.")
                        .font(.caption2).foregroundStyle(Farge.svak)
                }

                if !kort.auto {
                    Section {
                        // Valgte først, så man ser hva kortet består av uten å lete.
                        ForEach(treff.sorted(by: sortering), id: \.id) { e in
                            Button {
                                if let i = kort.entiteter.firstIndex(of: e.id) {
                                    kort.entiteter.remove(at: i)
                                } else {
                                    kort.entiteter.append(e.id)
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
                                    Image(systemName: kort.entiteter.contains(e.id)
                                          ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(kort.entiteter.contains(e.id)
                                                         ? Farge.aksent : Farge.svak)
                                }
                            }
                            .listRowBackground(Farge.kort)
                        }
                    } header: {
                        Text("\(kort.entiteter.count) valgt")
                    } footer: {
                        if entiteter.isEmpty {
                            Text("Fant ingen entiteter. Er telefonen koblet til huset?")
                                .font(.caption2).foregroundStyle(Farge.svak)
                        }
                    }
                }

                Section {
                    Button("Slett kortet", role: .destructive) {
                        multi.slett(kort.id); lukk()
                    }
                    .listRowBackground(Farge.kort)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Farge.flate)
            .searchable(text: $søk, prompt: "Søk i huset")
            .navigationTitle("Multikort")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Farge.flate, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Ferdig") { multi.endre(kort); lukk() }
                }
            }
            // Lagrer underveis også: lukker man med et sveip, skal ikke valgene være borte.
            .onDisappear { multi.endre(kort) }
        }
    }

    private func sortering(_ a: Husentitet, _ b: Husentitet) -> Bool {
        let va = kort.entiteter.contains(a.id), vb = kort.entiteter.contains(b.id)
        if va != vb { return va }
        return a.navn.localizedStandardCompare(b.navn) == .orderedAscending
    }
}
