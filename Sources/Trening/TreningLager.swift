import Foundation
import Observation

/// Henter og holder treningsdataene.
///
/// Serveren har gjort all regning på forhånd — streak, plan, hva som mangler. Lageret
/// skal derfor ikke tolke noe, bare skaffe det og si fra når det er der.
///
/// **Oppfriskning mens skjermen er åpen:** kilden kan oppdatere seg når som helst, og da
/// skal tallene følge etter uten at man må lukke og åpne modulen. Intervallet er satt
/// etter hvor ofte kilden faktisk endrer seg, ikke etter hvor ofte vi *kan* spørre — å
/// polle tettere enn kilden produserer gir bare trafikk.
///
/// Serveren tilbyr også en hendelsesstrøm som dytter ut endringer umiddelbart. Den er
/// bevisst ikke tatt i bruk ennå: den må verifiseres gjennom hele veien utenfra før
/// modulen kan stole på den, og en strøm som stilner i stillhet er verre enn en
/// oppfriskning man vet går.
@Observable
final class TreningLager {
    private let api: API
    private(set) var svar: Treningssvar?
    private(set) var feil: String?
    private(set) var laster = false

    /// Hvor ofte vi spør mens skjermen er fremme.
    private let intervall: Duration = .seconds(60)

    init(api: API) { self.api = api }

    var data: Treningsdata? { svar?.data }

    /// Når kilden lagde dataene. Vises diskret nederst.
    var generert: String? { svar?.kilde?.generert ?? svar?.data?.generert }

    /// Eldre enn en time. Da dempes tidsstempelet — men det er **ikke** en feil, og skal
    /// ikke se ut som en. Kilden oppdaterer seg sjeldnere om natta, og det er normalt.
    var erGammel: Bool {
        guard let d = Trening.dato(generert) else { return false }
        return Date().timeIntervalSince(d) > 3600
    }

    func last() async {
        if laster { return }
        laster = true
        defer { laster = false }
        do {
            svar = try await api.hent(Treningssvar.self, "/api/trening/visning")
            feil = nil
        } catch {
            // En avbrutt forespørsel er ikke en feil — den skjer hver gang man bytter
            // skjerm mens noe er underveis.
            if erAvbrutt(error) { return }
            // Har vi data fra før, beholder vi dem. Et nettverksglimt skal ikke tømme
            // skjermen for tall som fortsatt er gyldige.
            if svar == nil { feil = error.localizedDescription }
        }
    }

    /// Løkke som friskner opp mens visningen er synlig. Avsluttes når oppgaven
    /// kanselleres, altså når skjermen forsvinner.
    func følg() async {
        await last()
        while !Task.isCancelled {
            try? await Task.sleep(for: intervall)
            if Task.isCancelled { return }
            await last()
        }
    }
}
