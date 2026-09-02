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
/// Oppslag av hva kildens verdier og tall betyr.
///
/// **Forklaringene eies av kilden, ikke av appen.** Det er FPL-vakta som tar
/// beslutningene og som vet hva `utfort`, `xp_fplform` eller `vekt: hoy` innebærer;
/// skriver vi forklaringene selv, gjetter vi på en modell vi ikke har bygget — og
/// gjetningen ser like autoritativ ut som en riktig forklaring.
///
/// Appen eier mekanismen: oppslaget, arket, og at alt kan trykkes på. Teksten kommer
/// i `status.json` under `ordliste` (bestilt i `docs/svar-fra-smarthus.md`). Mangler
/// oppslaget, er det ingen knapp og ingen forklaring.
enum Ordliste {
    struct Ord: Identifiable {
        let id: String
        let tittel: String
        let hva: String
    }

    /// Settes av `FplLager` hver gang statusen hentes. Tom til kilden leverer.
    static var fraKilde: [String: FplStatus.Kildeord] = [:]

    /// Appens egne etiketter for verdier vi selv viser fram. Dette er IKKE forklaringer
    /// av kildens modell — bare norsk for maskinverdier, så «utfort» ikke står på skjermen.
    /// Hva de betyr, er kildens ord.
    private static let etiketter: [String: String] = [
        "utfort": "Utført", "anbefalt": "Anbefalt", "forkastet": "Forkastet",
        "xi": "Startellever", "bytte": "Bytte", "kaptein": "Kaptein", "vise": "Visekaptein",
        "chip": "Chip", "framover": "Framover", "bakover": "Bakover",
        "ok": "OK", "varsel": "Varsel", "feil": "Feil",
        "hoy": "Høy", "middels": "Middels", "lav": "Lav",
    ]

    static func finn(_ nøkkel: String) -> Ord? {
        let n = nøkkel.lowercased()
        guard let k = fraKilde[n] else { return nil }
        return Ord(id: n, tittel: k.tittel ?? etiketter[n] ?? nøkkel, hva: k.hva)
    }

    /// Norsk etikett for en maskinverdi. Uten treff vises verdien som den er — bedre å
    /// se `noe_ukjent` enn å finne på hva det heter.
    static func etikett(_ nøkkel: String) -> String {
        let n = nøkkel.lowercased()
        return fraKilde[n]?.tittel ?? etiketter[n] ?? nøkkel
    }

    static var alle: [Ord] {
        fraKilde.keys.compactMap { finn($0) }.sorted { $0.tittel < $1.tittel }
    }
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
                    if Ordliste.alle.isEmpty {
                        Text("Kilden har ikke levert forklaringer ennå. Appen finner ikke "
                             + "på hva tallene betyr — det er FPL-vakta som vet det, og "
                             + "teksten kommer med dataene når den er skrevet.")
                            .font(.caption).foregroundStyle(Farge.dempet)
                            .fixedSize(horizontal: false, vertical: true)
                    }
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
            Label(Ordliste.alle.isEmpty ? "Ordlista er tom — se hvorfor"
                                        : "Trykk på tall og merkelapper for forklaring",
                  systemImage: "questionmark.circle")
                .font(.caption2).foregroundStyle(Farge.svak)
                .multilineTextAlignment(.leading)
        }
        .sheet(isPresented: $vis) { Ordlisteark() }
    }
}

/// Kategoriene et åpent spørsmål kan ha, med navn, farge og ikon på ett sted.
///
/// Fargene er en rampe etter hvor mye som venter på DEG: gult krever handling nå, blått
/// venter på noe utenfra, grønt er avgjort, grått står bare. Uten farge på de to midterste
/// så «venter på signal» og «avgjort for runden» like døde ut som driftsgjelda, selv om
/// de sier helt forskjellige ting.
///
/// **Fargen står aldri alene** — hver overskrift har både ikon og tekst.
enum Kategori {
    static func navn(_ k: String) -> String {
        switch k {
        case "runde":             "Må besvares før fristen"
        case "venter_paa_signal": "Venter på signal"
        case "avgjort_for_runden": "Avgjort for runden"
        case "staaende":          "Står åpent"
        default:                  k
        }
    }

    static func farge(_ k: String) -> Color {
        switch k {
        case "runde":             Diagramfarge.varsel   // krever handling nå
        case "venter_paa_signal": Farge.kjol            // venter på noe utenfra
        case "avgjort_for_runden": Diagramfarge.god     // ferdig for denne runden
        default:                  Farge.dempet          // står, rører ikke runden
        }
    }

    static func ikon(_ k: String) -> String {
        switch k {
        case "runde":             "exclamationmark.circle.fill"
        case "venter_paa_signal": "hourglass"
        case "avgjort_for_runden": "checkmark.seal.fill"
        default:                  "tray.full"
        }
    }
}
