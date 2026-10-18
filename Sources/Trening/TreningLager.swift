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
            if svar == nil { feil = beskriv(error) }
        }
    }

    /// Skiller «kom ikke fram» fra «kom fram, men kunne ikke leses».
    ///
    /// 18.10.2026 endret kilden typen på ett felt, dekodingen kastet, og feilen kom
    /// ut som en ugjennomtrengelig systemtekst. Den leses som et nettverksproblem —
    /// og da leter man på feil sted. Svaret var framme hele tiden.
    private func beskriv(_ error: Error) -> String {
        guard let d = error as? DecodingError else { return error.localizedDescription }
        let hvor: String
        switch d {
        case .typeMismatch(_, let k), .valueNotFound(_, let k),
             .keyNotFound(_, let k), .dataCorrupted(let k):
            hvor = k.codingPath.map(\.stringValue).joined(separator: ".")
        @unknown default:
            hvor = ""
        }
        return hvor.isEmpty
            ? "Svaret fra serveren kunne ikke leses."
            : "Svaret fra serveren kunne ikke leses (\(hvor))."
    }

    /// Holder dataene ferske mens skjermen er fremme.
    ///
    /// **Strøm først, polling som fallback.** Serveren dytter ut endringer med én
    /// gang de kommer inn, så et trykk på vekta vises i appen på sekunder i stedet
    /// for ved neste runde. Målt gjennom hele veien utenfra: 37 ms til første
    /// hendelse, mot 11 ms internt — mellomleddene buffrer ikke.
    ///
    /// Men en strøm kan stilne uten å si fra, og det er verre enn en oppfriskning
    /// man vet går. Derfor: ryker strømmen, faller vi tilbake på å spørre, og
    /// prøver strømmen igjen etterpå.
    func følg() async {
        await last()
        while !Task.isCancelled {
            let varte = await strøm()
            if Task.isCancelled { return }
            // Falt strømmen med én gang, er noe galt med veien ut — da venter vi
            // et helt intervall og spør i stedet, framfor å hamre på nytt.
            if varte < 2 {
                try? await Task.sleep(for: intervall)
                await last()
            }
        }
    }

    /// Åpner hendelsesstrømmen og blir stående i den. Returnerer hvor mange
    /// sekunder den varte, så kalleren kan skille «falt med én gang» fra
    /// «gikk fint en stund og ble så brutt».
    ///
    /// **To måter en strøm dør på, og bare den ene sier fra.** Blir forbindelsen
    /// revet, kaster lesingen og vi kobler opp igjen. Men den kan også bli stående
    /// åpen og stum — da venter lesingen i det uendelige, og skjermen viser gamle
    /// tall som om de var ferske. Det er den verste utgaven, fordi ingenting ser galt ut.
    ///
    /// Serveren sender hjerteslag hvert 15. sekund (målt, også gjennom mellomleddene).
    /// Kommer det ingenting på 45, har vi mistet tre på rad, og da river vi selv og
    /// faller tilbake på å spørre.
    private func strøm() async -> TimeInterval {
        let start = Date()
        guard let rq = api.strømForespørsel("/api/trening/stream") else { return 0 }
        let liv = Livstegn()

        await withTaskGroup(of: Void.self) { gruppe in
            gruppe.addTask { await self.les(rq, liv) }
            gruppe.addTask {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(5))
                    if Task.isCancelled { return }
                    if await liv.stille > 45 { return }   // tre tapte hjerteslag
                }
            }
            // Den første som blir ferdig avgjør: enten døde lesingen, eller så
            // slo vakthunden til. Uansett skal begge avsluttes.
            await gruppe.next()
            gruppe.cancelAll()
        }
        return Date().timeIntervalSince(start)
    }

    private func les(_ rq: URLRequest, _ liv: Livstegn) async {
        do {
            let (linjer, respons) = try await URLSession.shared.bytes(for: rq)
            guard let h = respons as? HTTPURLResponse, h.statusCode == 200 else { return }
            var kropp = ""
            for try await linje in linjer.lines {
                if Task.isCancelled { return }
                await liv.rør()                          // også hjerteslag teller som liv
                if linje.isEmpty {                       // tom linje = hendelsen er slutt
                    if !kropp.isEmpty, let d = kropp.data(using: .utf8),
                       let nytt = try? JSONDecoder().decode(Treningssvar.self, from: d) {
                        await MainActor.run { self.svar = nytt; self.feil = nil }
                    }
                    kropp = ""
                    continue
                }
                if linje.hasPrefix(":") { continue }     // «: hjerteslag» er bare liv
                if linje.hasPrefix("data:") {
                    kropp += linje.dropFirst(5).trimmingCharacters(in: .whitespaces)
                }
            }
        } catch {
            // Avbrutt fordi skjermen forsvant er ikke en feil.
        }
    }
}

/// Når vi sist hørte noe som helst fra strømmen.
///
/// Egen `actor` fordi lesingen og vakthunden er to samtidige oppgaver som rører
/// det samme tidspunktet.
private actor Livstegn {
    private var sist = Date()
    func rør() { sist = Date() }
    var stille: TimeInterval { Date().timeIntervalSince(sist) }
}
