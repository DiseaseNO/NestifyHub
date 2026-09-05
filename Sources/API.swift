import Foundation
import Observation

enum APIFeil: LocalizedError {
    case ingenServer, ikkeAutorisert, kode(Int), nettverk(String)
    var errorDescription: String? {
        switch self {
        case .ingenServer:     "Ingen server satt opp."
        case .ikkeAutorisert:  "Enheten er ikke lenger godkjent. Koble til på nytt."
        case .kode(let n):     "Serveren svarte \(n)."
        case .nettverk(let m): m
        }
    }
}

private struct ParSvar: Decodable {
    let token: String
    struct Enhet: Decodable { let id: String; let navn: String }
    let enhet: Enhet
}

/// Klienten mot hjemmeserveren.
///
/// Appen kjenner ingen adresser på forhånd. Verten skrives inn ved paring og lagres i
/// Keychain sammen med enhets-tokenet — derfor finnes det ingenting å lese ut av dette
/// repoet om hvor noe står.
@Observable
final class API {
    /// Delt referanse, så små visninger slipper å få API sendt gjennom flere ledd.
    static private(set) var delt: API?

    private(set) var vert: String? = Nøkkelring.les("vert")
    private(set) var token: String? = Nøkkelring.les("token")
    var erKlar: Bool { vert != nil && token != nil }

    init() { API.delt = self }

    // MARK: paring

    /// Løser inn en engangskode fra dashbordet. Passordet kommer aldri inn i appen —
    /// koden er engangs og lever i fem minutter.
    func par(vert: String, kode: String, enhetsnavn: String) async throws {
        let renVert = vert.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "https://\(renVert)/api/enheter/par") else { throw APIFeil.ingenServer }
        var rq = URLRequest(url: url)
        rq.httpMethod = "POST"
        rq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        rq.httpBody = try JSONEncoder().encode(["kode": kode, "navn": enhetsnavn])
        let (data, svar) = try await URLSession.shared.data(for: rq)
        guard let h = svar as? HTTPURLResponse else { throw APIFeil.nettverk("Uventet svar") }
        guard h.statusCode == 200 else {
            throw h.statusCode == 401 ? APIFeil.nettverk("Ugyldig eller utløpt kode.") : APIFeil.kode(h.statusCode)
        }
        let p = try JSONDecoder().decode(ParSvar.self, from: data)
        Nøkkelring.skriv(renVert, for: "vert")
        Nøkkelring.skriv(p.token, for: "token")
        self.vert = renVert
        self.token = p.token
    }

    func glemEnhet() {
        Nøkkelring.slett("vert"); Nøkkelring.slett("token")
        vert = nil; token = nil
    }

    // MARK: kall

    private func adresse(_ sti: String, _ q: [String: String] = [:]) -> URL? {
        guard let vert else { return nil }
        var c = URLComponents(string: "https://" + vert) ?? URLComponents()
        c.percentEncodedPath = sti
        if !q.isEmpty { c.queryItems = q.map { URLQueryItem(name: $0.key, value: $0.value) } }
        return c.url
    }

    func hent<T: Decodable>(_ type: T.Type, _ sti: String, _ q: [String: String] = [:]) async throws -> T {
        try await kall(type, sti, q, metode: "GET")
    }
    @discardableResult
    func send<T: Decodable>(_ type: T.Type, _ sti: String, _ q: [String: String] = [:]) async throws -> T {
        try await kall(type, sti, q, metode: "POST")
    }

    /// POST med JSON-kropp, for kall der serveren trenger å vite HVA som skal gjøres —
    /// ikke bare at noe skal skje.
    ///
    /// Svaret leses ikke: statuskoden er det vi bryr oss om, og en tom kropp skal ikke
    /// bli en dekodingsfeil.
    func send(_ sti: String, _ kropp: [String: Any]) async throws {
        guard let token, let u = adresse(sti) else { throw APIFeil.ingenServer }
        var rq = URLRequest(url: u)
        rq.httpMethod = "POST"
        rq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        rq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        rq.httpBody = try JSONSerialization.data(withJSONObject: kropp)
        rq.timeoutInterval = 20
        let (_, svar) = try await URLSession.shared.data(for: rq)
        guard let h = svar as? HTTPURLResponse else { throw APIFeil.nettverk("Uventet svar") }
        if h.statusCode == 401 { throw APIFeil.ikkeAutorisert }
        guard (200..<300).contains(h.statusCode) else { throw APIFeil.kode(h.statusCode) }
    }

    private func kall<T: Decodable>(_ type: T.Type, _ sti: String, _ q: [String: String], metode: String) async throws -> T {
        guard let token, let u = adresse(sti, q) else { throw APIFeil.ingenServer }
        var rq = URLRequest(url: u)
        rq.httpMethod = metode
        rq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        rq.timeoutInterval = 30
        let (data, svar) = try await URLSession.shared.data(for: rq)
        guard let h = svar as? HTTPURLResponse else { throw APIFeil.nettverk("Uventet svar") }
        if h.statusCode == 401 { throw APIFeil.ikkeAutorisert }
        guard h.statusCode == 200 else { throw APIFeil.kode(h.statusCode) }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

/// En avbrutt forespørsel er ikke en feil.
///
/// SwiftUIs `.task` kansellerer det som er underveis når visningen forsvinner. Bytter du
/// skjerm mens noe lastes, får vi `NSURLErrorCancelled` — å vise «cancelled» i rødt får
/// en helt normal hendelse til å se ut som at noe er ødelagt.
func erAvbrutt(_ feil: Error) -> Bool {
    if feil is CancellationError { return true }
    let n = feil as NSError
    return n.domain == NSURLErrorDomain && n.code == NSURLErrorCancelled
}
