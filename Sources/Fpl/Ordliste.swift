import SwiftUI

/// Forklaringer på tallene og forkortelsene skjermene viser.
///
/// Vakta skriver for seg selv. «xP», «defcon per 90» og «EO» er selvsagt for den som
/// bygget modellen, og ugjennomtrengelig for alle andre — og et tall man ikke forstår,
/// er et tall man ikke kan bruke til noe. Derfor står forklaringen i appen, ikke i et
/// dokument ved siden av.
///
/// Kilden er bedt om å levere sin egen `forklaring`-ordbok for tallfeltene
/// (`docs/svar-fra-smarthus.md`). Til den finnes, står disse her.
enum Ordliste {
    struct Ord: Identifiable {
        let id = UUID()
        let term: String
        let hva: String
    }

    static let alle: [Ord] = [
        .init(term: "xP", hva: "Forventede poeng i runden som kommer. Et anslag, ikke et løfte — 5 i xP betyr «omtrent fem poeng hvis runden spilles mange nok ganger»."),
        .init(term: "xP over 6 runder", hva: "Samme anslag lagt sammen for de seks neste rundene. Sier mer om hvem du bør beholde enn om hvem som scorer på lørdag."),
        .init(term: "FPL-form", hva: "Forventede poeng regnet av FPL selv. Uavhengig av vår egen modell, og brukt i stedet for den når modellen er underkjent."),
        .init(term: "Defcon per 90", hva: "Forsvarsbidrag per hele kamp — taklinger, klareringer, avskjæringer. Høyt tall gir sjanse for defensive bonuspoeng."),
        .init(term: "Eierskap", hva: "Andelen av alle FPL-lag som har spilleren. Høyt eierskap gjør ham trygg å ha og dyr å stå uten; lavt gjør ham til et sjansespill som skiller deg fra mengden."),
        .init(term: "Effektivt eierskap", hva: "Eierskap justert for kapteinsvalg. Kan gå over 100 %, fordi den som er kaptein hos mange teller dobbelt."),
        .init(term: "Vanskegrad", hva: "Hvor tung motstanderen er, fra 1 (lettest) til 5 (tyngst). FPLs egen vurdering."),
        .init(term: "Form", hva: "Snittpoeng per kamp den siste tiden. Ser bakover, og sier lite alene."),
        .init(term: "Frie bytter", hva: "Bytter du kan gjøre uten poengtrekk. Ett i uka, og du kan spare opp til fem."),
        .init(term: "FT", hva: "Free transfer — et fritt bytte. «1 FT bankes» betyr at byttet spares til neste uke."),
        .init(term: "T-81t", hva: "Timer igjen til fristen da vakta skrev notatet. T-81t = 81 timer før."),
        .init(term: "Anytime scorer-odds", hva: "Bookmakernes anslag på at spilleren scorer minst ett mål i kampen."),
        .init(term: "Signal framover / bakover", hva: "Framover sier noe om runden som kommer. Bakover sier noe om det som har vært. Et argument på fire bein der tre ser bakover, er svakere enn det høres ut."),
        .init(term: "Premisset holdt", hva: "Om resonnementet bak en beslutning viste seg å være riktig. Det er ikke det samme som at det ga poeng — en riktig vurdering kan tape, og en slurvete kan vinne."),
        .init(term: "Chip", hva: "Engangskort som Wildcard, Bench Boost eller Triple Captain. Kan brukes én gang hver i sesongen."),
    ]
}

/// Arket med ordlista. Nås fra «Hva betyr tallene?» nederst på skjermene.
struct Ordlisteark: View {
    @Environment(\.dismiss) private var lukk

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Ordliste.alle) { o in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(o.term).font(.subheadline.weight(.semibold)).foregroundStyle(Farge.tekst)
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

/// Liten knapp som åpner ordlista. Står nederst der tallene er, ikke i en meny.
struct Ordlisteknapp: View {
    @State private var vis = false
    var body: some View {
        Button { vis = true } label: {
            Label("Hva betyr tallene?", systemImage: "questionmark.circle")
                .font(.caption2).foregroundStyle(Farge.svak)
        }
        .sheet(isPresented: $vis) { Ordlisteark() }
    }
}
