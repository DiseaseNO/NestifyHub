import SwiftUI

/// Forklaringer på tallene, merkelappene og forkortelsene skjermene viser.
///
/// To slags uforståelighet, med hver sin eier:
///
/// * **Fritekstet** er vaktas arbeidslogg, skrevet for den som bygget modellen. Den kan
///   bare kilden gjøre kortere — vi har bedt om et `sammendrag` (`docs/svar-fra-smarthus.md`).
/// * **Ordene** — `utfort`, `xi`, `forkastet`, `xp_fplform` — er enum-verdier og feltnavn
///   vi har vist rått. Det er vår jobb, og den gjøres her: hver verdi får en norsk
///   etikett og en setning om hva den betyr.
///
/// Alt som står i denne tabellen kan trykkes på i appen (se `Forklar`).
enum Ordliste {
    struct Ord: Identifiable {
        let id: String
        let tittel: String
        let hva: String
    }

    /// Nøkkelen er enten kildens egen verdi (`utfort`, `xi`) eller vårt eget navn på et
    /// tall (`xp`, `bank`). Ukjent nøkkel gir ingen forklaring framfor en gjetning.
    static let ord: [String: Ord] = Dictionary(uniqueKeysWithValues: [
        // --- status på en beslutning
        Ord(id: "utfort", tittel: "Utført",
            hva: "Beslutningen er gjennomført — laget ditt er allerede endret slik."),
        Ord(id: "anbefalt", tittel: "Anbefalt",
            hva: "Vakta mener dette bør gjøres, men det er ikke gjort ennå. Skjer ingenting, står laget som det står."),
        Ord(id: "forkastet", tittel: "Forkastet",
            hva: "Vurdert og valgt bort. De forkastede er ofte de mest interessante — de viser hva som faktisk ble veid."),
        // --- hva beslutningen gjelder
        Ord(id: "xi", tittel: "Startellever",
            hva: "De elleve som spiller. Bare de gir poeng — benken teller først hvis noen ikke spiller."),
        Ord(id: "bytte", tittel: "Bytte",
            hva: "Å bytte en spiller ut av troppen og en annen inn. Koster 4 poeng hvis du ikke har et fritt bytte igjen."),
        Ord(id: "kaptein", tittel: "Kaptein",
            hva: "Kapteinen gir dobbel poengsum. Det er ukas enkeltvalg som betyr mest."),
        Ord(id: "vise", tittel: "Visekaptein",
            hva: "Overtar kapteinsbindet automatisk hvis kapteinen ikke spiller."),
        Ord(id: "chip", tittel: "Chip",
            hva: "Engangskort som Wildcard, Bench Boost eller Triple Captain. Ett bruk hver per sesong."),
        // --- tallene
        Ord(id: "xp", tittel: "xP — forventede poeng",
            hva: "Anslag på hva spilleren gir i runden som kommer. Et anslag, ikke et løfte: 5 i xP betyr «omtrent fem poeng hvis runden ble spilt mange nok ganger»."),
        Ord(id: "xp_fplform", tittel: "FPL-form",
            hva: "Forventede poeng regnet av FPL selv. Uavhengig av vår egen modell, og brukt i stedet for den når modellen er underkjent."),
        Ord(id: "xp_sum6", tittel: "xP over seks runder",
            hva: "Samme anslag lagt sammen for de seks neste rundene. Sier mer om hvem du bør beholde enn om hvem som scorer på lørdag."),
        Ord(id: "defcon", tittel: "Defcon per 90",
            hva: "Forsvarsbidrag per hele kamp — taklinger, klareringer, avskjæringer. Høyt tall gir sjanse for defensive bonuspoeng."),
        Ord(id: "eierskap", tittel: "Eierskap",
            hva: "Andelen av alle FPL-lag som har spilleren. Høyt eierskap gjør ham trygg å ha og dyr å stå uten; lavt gjør ham til et sjansespill som skiller deg fra mengden."),
        Ord(id: "effektivt_eierskap", tittel: "Effektivt eierskap",
            hva: "Eierskap justert for kapteinsvalg. Kan gå over 100 %, fordi den som er kaptein hos mange teller dobbelt."),
        Ord(id: "vansker", tittel: "Vanskegrad",
            hva: "Hvor tung motstanderen er, fra 1 (lettest) til 5 (tyngst). FPLs egen vurdering."),
        Ord(id: "form", tittel: "Form",
            hva: "Snittpoeng per kamp den siste tiden. Ser bakover, og sier lite alene."),
        Ord(id: "verdi", tittel: "Lagverdi",
            hva: "Hva troppen din er verdt i millioner. Stiger og faller med spillernes priser."),
        Ord(id: "bank", tittel: "Bank",
            hva: "Penger du ikke har brukt. Kan legges på et bytte."),
        Ord(id: "frie_bytter", tittel: "Frie bytter",
            hva: "Bytter du kan gjøre uten poengtrekk. Du får ett i uka og kan spare opp til fem."),
        Ord(id: "poeng", tittel: "Poeng",
            hva: "Sesongens sum. Står som strek før runden er spilt — ikke som null."),
        // --- signalene
        Ord(id: "framover", tittel: "Signal framover",
            hva: "Sier noe om runden som kommer — odds, forventede mål, oppstilling."),
        Ord(id: "bakover", tittel: "Signal bakover",
            hva: "Sier noe om det som har vært. Et argument på fire bein der tre ser bakover, er svakere enn det høres ut."),
        Ord(id: "peker_mot", tittel: "Peker mot",
            hva: "Hvilket av de to alternativene signalet favoriserer, eller «uavgjort»."),
        Ord(id: "vekt", tittel: "Vekt",
            hva: "Hvor mye vakta faktisk la i signalet. Ikke alle teller likt."),
        Ord(id: "scorer_odds", tittel: "Anytime scorer-odds",
            hva: "Bookmakernes anslag på at spilleren scorer minst ett mål i kampen."),
        // --- historikk og helse
        Ord(id: "premiss_holdt", tittel: "Premisset holdt",
            hva: "Om resonnementet bak beslutningen viste seg å være riktig. Det er ikke det samme som at det ga poeng — en riktig vurdering kan tape, og en slurvete kan vinne."),
        Ord(id: "ok", tittel: "OK", hva: "Kontrollen gikk gjennom uten noe å bemerke."),
        Ord(id: "varsel", tittel: "Varsel",
            hva: "Noe krever en vurdering. Det er ikke en feil — vakta har sett det og går videre."),
        Ord(id: "feil", tittel: "Feil", hva: "Kontrollen selv feilet. Da vet vi ikke om det den skulle sjekke er i orden."),
        Ord(id: "ft", tittel: "FT — fritt bytte",
            hva: "Free transfer. «1 FT bankes» betyr at byttet spares til neste uke."),
    ].map { ($0.id, $0) })

    /// Slår opp en verdi fra kilden. Tåler store bokstaver og norske former.
    static func finn(_ nøkkel: String) -> Ord? {
        ord[nøkkel.lowercased()]
    }

    /// Norsk etikett for en verdi fra kilden. Uten treff vises verdien som den er —
    /// bedre å se `noe_ukjent` enn å finne på hva det betyr.
    static func etikett(_ nøkkel: String) -> String {
        finn(nøkkel)?.tittel ?? nøkkel
    }

    static var alle: [Ord] { ord.values.sorted { $0.tittel < $1.tittel } }
}

/// Gjør hva som helst trykkbart med en forklaring bak.
///
/// Uten treff i ordlista er det ingen knapp — da skal ingenting se trykkbart ut heller.
struct Forklar<Innhold: View>: View {
    let nøkkel: String
    @ViewBuilder var innhold: () -> Innhold
    @State private var vis = false

    var body: some View {
        if let o = Ordliste.finn(nøkkel) {
            Button { vis = true } label: { innhold() }
                .buttonStyle(.plain)
                .sheet(isPresented: $vis) { forklaringsark(o) }
        } else {
            innhold()
        }
    }

    private func forklaringsark(_ o: Ordliste.Ord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(o.tittel).font(.title3.weight(.semibold)).foregroundStyle(Farge.tekst)
            Text(o.hva).font(.callout).foregroundStyle(Farge.dempet)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Farge.flate)
        .presentationDetents([.height(220)])
    }
}

/// Hele ordlista, for den som vil lese alt.
struct Ordlisteark: View {
    @Environment(\.dismiss) private var lukk

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Ordliste.alle) { o in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(o.tittel).font(.subheadline.weight(.semibold)).foregroundStyle(Farge.tekst)
                            Text(o.hva).font(.caption).foregroundStyle(Farge.dempet)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(16)
            }
            .background(Farge.flate)
            .scrollIndicators(.hidden)
            .navigationTitle("Hva betyr tallene?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Farge.flate, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Lukk") { lukk() } } }
        }
    }
}

struct Ordlisteknapp: View {
    @State private var vis = false
    var body: some View {
        Button { vis = true } label: {
            Label("Trykk på tall og merkelapper for forklaring — eller se hele ordlista",
                  systemImage: "questionmark.circle")
                .font(.caption2).foregroundStyle(Farge.svak)
                .multilineTextAlignment(.leading)
        }
        .sheet(isPresented: $vis) { Ordlisteark() }
    }
}
