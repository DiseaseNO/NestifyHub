import SwiftUI

/// Trening-modulen.
///
/// Premisset er at **vekta skal stå stille med vilje** — det bygges muskler på
/// vedlikehold. Derfor er vekt aldri hovedtallet. Øverst står det som skal bevege seg:
/// hva man kan gjøre i dag, uka, formen og konkrete råd.
///
/// Fortsatt **ingen input**: hvert trykk åpner noe å lese, aldri noe å fylle ut.
/// All registrering skjer i chat eller automatisk fra klokke og vekt.
///
/// ## Navigasjon: lukkebaserte lenker, og ingen egen NavigationStack
///
/// Modulen lager **ikke** en `NavigationStack` — den får en fra hjemskjermen, som
/// dytter modulen inn i sin. Og lenkene er **lukkebaserte**
/// (`NavigationLink { Skjerm() }`), ikke verdibaserte.
///
/// Begge deler er lært den dyre veien. v2 av modulen brukte
/// `NavigationLink(value:)` + `navigationDestination(for:)` i sin egen stack. Det er
/// mønsteret Apple anbefaler, men det oppførte seg galt inne i dette skallet: først
/// sprettet hvert trykk ut til modulvelgeren, og etter at den indre stacken ble
/// fjernet, åpnet trykkene modulen i seg selv om og om igjen.
///
/// Fantasy og Huset har alltid brukt lukkebaserte lenker, og de har aldri hatt
/// problemet. Trening var den eneste modulen med verdibasert navigasjon, og den
/// eneste som var ødelagt. Da er det riktige å gjøre som de to andre — ikke å
/// fortsette å justere på et mønster som har feilet to ganger i akkurat dette
/// hierarkiet.
///
/// Prisen er at `Treningsmål` ikke lenger er en navigasjonsverdi. Den lever videre
/// som en ren identifikator for CI.
///
/// ## Hva CI faktisk ser — og ikke ser
///
/// `-trening <navn>` rendrer én detaljskjerm **som rot**, ikke som en dytting. Det
/// gir samme innhold i skjermbildet, men betyr at **CI ikke lenger tester
/// navigasjonen i det hele tatt**. Det er en reell svakhet, og den skal stå
/// skrevet her framfor å bli oppdaget på nytt: skjermbildene beviser at skjermene
/// ser riktige ut, ikke at man kommer til dem.
struct TreningModul: View {
    let api: API
    /// Kun CI. Appen sender aldri noe her.
    var testmål: Treningsmål?
    @State private var lager: TreningLager
    @Environment(\.scenePhase) private var scenefase

    init(api: API, testmål: Treningsmål? = nil) {
        self.api = api
        self.testmål = testmål
        _lager = State(initialValue: TreningLager(api: api))
    }

    var body: some View {
        Group {
            // Detaljskjermen bygges først når dataene finnes — en skjerm som
            // rendres tom, fylles aldri, fordi innholdet fanges i det den bygges.
            if let m = testmål, lager.data != nil {
                detalj(m)
            } else {
                TreningOversikt(lager: lager)
            }
        }
        .refreshable { await lager.last() }
        // Holder dataene ferske mens skjermen er fremme; stopper av seg selv når den
        // forsvinner, fordi oppgaven kanselleres.
        .task { await lager.følg() }
        .onChange(of: scenefase) { _, ny in
            if ny == .active { Task { await lager.last() } }
        }
    }

    @ViewBuilder private func detalj(_ mål: Treningsmål) -> some View {
        let d = lager.data
        switch mål {
        case .uke:         UkeSkjerm(uke: d?.uke, okter: d?.okter ?? [])
        case .form:        FormSkjerm(form: d?.form)
        case .lop:         LopSkjerm(lop: d?.lop, okter: d?.okter ?? [])
        case .styrke:      StyrkeSkjerm(styrke: d?.styrke, rad: d?.rad ?? [],
                                        rekorder: d?.rekorder ?? [], okter: d?.okter ?? [])
        case .energi:      EnergiSkjerm(energi: d?.energi)
        case .vekt:        VektSkjerm(vekt: d?.vekt, reisen: d?.reisen)
        case .restitusjon: RestitusjonSkjerm(form: d?.form)
        case .reisen:      Reiseskjerm(reisen: d?.reisen ?? .tom, vekt: d?.vekt)
        case .okt(let id): ØktSkjerm(økt: d?.okter?.first { $0.id == id })
        }
    }
}

/// Verten CI bruker når modulen startes direkte med `-skjerm trening`.
///
/// Den finnes fordi modulen ikke eier noen stack. I appen kommer stacken fra
/// hjemskjermen; her må testveien stille med sin egen — synlig, i stedet for at
/// modulen lager en «fordi CI trenger det».
struct Treningsvert: View {
    let api: API

    var body: some View {
        NavigationStack {
            TreningModul(api: api, testmål: Testskjerm.treningsmål)
        }
    }
}
