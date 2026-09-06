import SwiftUI

/// Fanene i Huset — de samme som nettbrettet har.
///
/// **Var** en fri modell der brukeren kunne lage egne faner og «multikort». Den ble
/// fjernet: et multikort satt til «alle rom» tegnet rommene en gang til under dem som
/// alt lå der, og skjermen så ut som en feil. Thomas ba om å speile nettbrettet og bare
/// kunne endre rekkefølgen på bolkene — det er en enklere modell som ikke kan bli rar.
///
/// Kamera er bevisst ikke med: rollen appen bruker har ikke kameratilgang, og
/// CameraRelay er en egen app for nettopp det.
struct Fane: Identifiable, Equatable {
    let id: String
    let navn: String
    let ikon: String

    static let alle: [Fane] = [
        Fane(id: "hjem", navn: "Huset", ikon: "house"),
        Fane(id: "oversikt", navn: "Oversikt", ikon: "square.text.square"),
        Fane(id: "strom", navn: "Strøm", ikon: "bolt"),
        Fane(id: "oppgaver", navn: "Oppgaver", ikon: "checklist"),
        Fane(id: "biler", navn: "Bilene", ikon: "car"),
        Fane(id: "admin", navn: "Admin", ikon: "gearshape"),
    ]
}

/// Bolkene i hver fane.
///
/// Rekkefølgen her er utgangspunktet; brukeren kan flytte og skjule, men ikke legge til.
/// Det var det som ble bedt om — og en fane man kan bygge fritt, er en fane som kan bli
/// tom uten at man skjønner hvorfor.
enum Bolk {
    static func ider(_ fane: String) -> [String] {
        switch fane {
        case "hjem":     ["puls", "scener", "garasje", "rom"]
        case "oversikt": ["varsler", "vaer", "kalender", "soppel", "handel", "hendelser"]
        case "strom":    ["naa", "doegn", "kostnad", "poster", "maaned", "trend",
                          "kapasitet", "avtale"]
        case "oppgaver": ["godkjenning", "barn"]
        case "biler":    ["biler"]
        case "admin":    ["godkjenning", "enheter"]
        default:         []
        }
    }

    static func navn(_ id: String) -> String {
        switch id {
        case "puls": "Forbruk nå"
        case "scener": "Scener"
        case "garasje": "Garasjeport"
        case "rom": "Rommene"
        case "varsler": "Varsler"
        case "vaer": "Været"
        case "kalender": "Kalender"
        case "soppel": "Søppeltømming"
        case "handel": "Handleliste"
        case "hendelser": "Siste hendelser"
        case "naa": "Forbruk nå"
        case "doegn": "Effekt gjennom dagen"
        case "kostnad": "Kostnad"
        case "poster": "Hva bruker strømmen nå"
        case "maaned": "Hittil i måneden"
        case "trend": "Endrer forbruket seg"
        case "kapasitet": "Kapasitetsledd"
        case "avtale": "Strømavtalen din"
        case "godkjenning": "Venter på godkjenning"
        case "barn": "Barna"
        case "biler": "Bilene"
        case "enheter": "Parede enheter"
        default: id
        }
    }
}

/// Brukerens valg: hvilke faner som vises og i hvilken rekkefølge.
@Observable
final class Faner {
    private let lager = UserDefaults(suiteName: Delt.gruppe) ?? .standard
    private let rekkeNøkkel = "hus.faner.rekkefolge"
    private let skjultNøkkel = "hus.faner.skjult"

    private(set) var skjult: Set<String>
    private(set) var rekkefølge: [String]

    /// iOS viser **fem** faner i linja. Er det flere, blir den femte til «More», og
    /// resten havner i en liste bak den. Seks faner ga derfor fire ekte og en «…».
    ///
    /// Admin er skjult i utgangspunktet, så de fem daglige står framme. Den kan slås på
    /// — da havner noe annet under «More», og det er brukerens valg å ta.
    static let skjultSomStandard: Set<String> = ["admin"]

    init() {
        let l = UserDefaults(suiteName: Delt.gruppe) ?? .standard
        // Har brukeren aldri vært innom oppsettet, gjelder standarden. Etterpå er det
        // brukerens liste som gjelder, også når den er tom.
        if l.object(forKey: "hus.faner.skjult") == nil {
            skjult = Faner.skjultSomStandard
        } else {
            skjult = Set(l.stringArray(forKey: "hus.faner.skjult") ?? [])
        }
        rekkefølge = l.stringArray(forKey: "hus.faner.rekkefolge") ?? []
    }

    private func lagre() {
        lager.set(Array(skjult), forKey: skjultNøkkel)
        lager.set(rekkefølge, forKey: rekkeNøkkel)
    }

    /// Nye faner havner sist framfor å være skjult til noen finner dem i innstillingene.
    /// En fane som leveres og aldri sees, er ikke levert.
    var alle: [Fane] {
        let kjent = rekkefølge.compactMap { id in Fane.alle.first { $0.id == id } }
        return kjent + Fane.alle.filter { f in !rekkefølge.contains(f.id) }
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

    func nullstill() {
        skjult = Faner.skjultSomStandard; rekkefølge = []
        lager.removeObject(forKey: skjultNøkkel)
        lager.removeObject(forKey: rekkeNøkkel)
    }
}

/// Rekkefølge og synlighet — både for fanene og for bolkene inne i én fane.
///
/// Samme skjerm til begge deler, fordi det er samme handling: dra for å flytte, bryter
/// for å skjule. To ulike skjermer for det ville bare vært to steder å lære.
struct Rekkefølgeoppsett: View {
    let tittel: String
    let ider: [String]
    let navn: (String) -> String
    let erSkjult: (String) -> Bool
    let settSynlig: (String, Bool) -> Void
    let flytt: (IndexSet, Int) -> Void
    let nullstill: () -> Void
    let ordne: ([String]) -> [String]
    @Environment(\.dismiss) private var lukk

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(ordne(ider), id: \.self) { id in
                        HStack {
                            Text(navn(id)).font(.subheadline)
                                .foregroundStyle(erSkjult(id) ? Farge.svak : Farge.tekst)
                            Spacer()
                            Toggle("", isOn: Binding(get: { !erSkjult(id) },
                                                     set: { settSynlig(id, $0) }))
                                .labelsHidden().tint(Farge.aksent)
                        }
                        .listRowBackground(Farge.kort)
                    }
                    .onMove { flytt($0, $1) }
                } footer: {
                    Text("Dra i håndtaket til høyre for å endre rekkefølgen. "
                         + "Bryteren skjuler uten å slette.")
                        .font(.caption2).foregroundStyle(Farge.svak)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Farge.flate)
            .environment(\.editMode, .constant(.active))
            .navigationTitle(tittel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Farge.flate, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Nullstill") { nullstill() }.foregroundStyle(Farge.svak)
                }
                ToolbarItem(placement: .topBarTrailing) { Button("Ferdig") { lukk() } }
            }
        }
    }
}
