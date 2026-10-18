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
struct TreningModul: View {
    let api: API
    @State private var lager: TreningLager
    @State private var sti = NavigationPath()
    @Environment(\.scenePhase) private var scenefase

    init(api: API) {
        self.api = api
        _lager = State(initialValue: TreningLager(api: api))
    }

    var body: some View {
        NavigationStack(path: $sti) {
            TreningOversikt(lager: lager)
                .navigationDestination(for: Treningsmål.self) { detalj($0) }
        }
        .refreshable { await lager.last() }
        // Holder dataene ferske mens skjermen er fremme; stopper av seg selv når den
        // forsvinner, fordi oppgaven kanselleres.
        .task {
            // CI åpner en detaljskjerm direkte. Først NÅR dataene finnes — en skjerm
            // som dyttes tom, fylles aldri, fordi innholdet fanges i det den dyttes.
            if let m = Testskjerm.treningsmål {
                await lager.last()
                if lager.data != nil { sti.append(m) }
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
        case .vekt:        VektSkjerm(vekt: d?.vekt, reisen: d?.reisen)
        case .restitusjon: RestitusjonSkjerm(form: d?.form)
        case .reisen:      Reiseskjerm(reisen: d?.reisen ?? .tom, vekt: d?.vekt)
        case .okt(let id): ØktSkjerm(økt: d?.okter?.first { $0.id == id })
        }
    }
}
