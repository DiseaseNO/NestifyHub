import SwiftUI

/// Trening-modulen.
///
/// Premisset er at **vekta skal stå stille med vilje** — det bygges muskler på
/// vedlikehold. Derfor er vekt aldri hovedtallet. Øverst står det som skal bevege seg:
/// hva man kan gjøre i dag, uka, formen og konkrete råd.
///
/// **v1 var for lukket.** Den viste én skjerm uten interaksjon, og dommen var
/// treffende: «alt for lite informasjon, kan ikke klikke på noe, ser ikke status på
/// formen». v2 gjør hvert kort til en inngang.
///
/// Men fortsatt **ingen input**: hvert trykk åpner noe å lese, aldri noe å fylle ut.
/// All registrering skjer i chat eller automatisk fra klokke og vekt.
///
/// ## Modulen lager ALDRI sin egen NavigationStack
///
/// Hjemskjermen dytter modulen inn i sin stack. Lager modulen én til, havner de to
/// inni hverandre — og da tar den ytre imot et verdibasert trykk den ikke har noen
/// `navigationDestination` for, og spretter helt ut til modulvelgeren. Det var
/// nøyaktig det som skjedde i v0.10: hvert trykk sendte deg til modullista.
///
/// Trening er den eneste modulen som bruker `NavigationLink(value:)`, og derfor den
/// eneste som merket det. De andre dytter visningen rett inn med en lukke.
///
/// **Skjermbildene kunne ikke fanget det.** CI starter modulen som rot, uten
/// hjemskjermen over seg — der var det bare én stack, og alt virket. Feilen bodde i
/// forholdet mellom modulen og det som ligger utenpå den, og det er nettopp det
/// testveien hopper over. `teststi` finnes for å holde den veien ærlig: CI må
/// eksplisitt skaffe stacken modulen ikke eier.
struct TreningModul: View {
    let api: API
    /// Kun CI. Appen sender aldri noe her — stien eies av hjemskjermen.
    var teststi: Binding<NavigationPath>?
    @State private var lager: TreningLager
    @Environment(\.scenePhase) private var scenefase

    init(api: API, teststi: Binding<NavigationPath>? = nil) {
        self.api = api
        self.teststi = teststi
        _lager = State(initialValue: TreningLager(api: api))
    }

    var body: some View {
        TreningOversikt(lager: lager)
            .navigationDestination(for: Treningsmål.self) { detalj($0) }
            .refreshable { await lager.last() }
            // Holder dataene ferske mens skjermen er fremme; stopper av seg selv når
            // den forsvinner, fordi oppgaven kanselleres.
            .task {
                // CI åpner en detaljskjerm direkte. Først NÅR dataene finnes — en skjerm
                // som dyttes tom, fylles aldri, fordi innholdet fanges i det den dyttes.
                if let teststi, let m = Testskjerm.treningsmål {
                    await lager.last()
                    if lager.data != nil { teststi.wrappedValue.append(m) }
                }
                await lager.følg()
            }
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
/// Den finnes fordi modulen ikke lenger eier noen stack. I appen kommer stacken fra
/// hjemskjermen; her må testveien stille med sin egen — og det er med vilje synlig,
/// så ingen senere legger en stack inn i modulen igjen «fordi CI trenger det».
struct Treningsvert: View {
    let api: API
    @State private var sti = NavigationPath()

    var body: some View {
        NavigationStack(path: $sti) {
            TreningModul(api: api, teststi: $sti)
        }
    }
}
