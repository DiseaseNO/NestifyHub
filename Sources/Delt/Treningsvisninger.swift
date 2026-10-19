import SwiftUI

/// Visningene i treningswidgeten.
///
/// **Ligger i `Delt/`, ikke i `Widget/`, med vilje.** Widget-målet er det eneste som
/// kompilerer `Widget/`, og da kan ingen andre se visningene rendret — heller ikke
/// skjermbilde-jobben. Det er samme felle som gjorde at navigasjonsfeilen i
/// Trening-modulen gikk ut to ganger: testveien så ikke det brukeren så.
///
/// Her ligger alt som tegner. `Widget/Treningswidget.swift` har bare tidslinja og
/// koblingen til WidgetKit, og appen kan rendre de samme visningene i CI.

// MARK: - tilstanden widgeten tegner

/// Mellomledd mellom bildet og visningen.
///
/// Finnes for å samle ÉN regel på ett sted: etter et ukeskifte er forrige ukes tall
/// ikke lenger sanne. Uten dette måtte hver av de fire visningene huske det selv.
struct Treningstilstand {
    let streak: Int?
    let gjort: Int
    let mal: Int
    let styrke: Bool
    let lop: Bool
    let status: String
    let godkjent: Bool
    let forslag: String?
    let sovn: Double?
    let readiness: String?
    let generert: Date?
    let uparet: Bool
    let ukenummer: Int?

    init(_ b: Delt.Treningsbilde?, nå: Date = Date()) {
        let nyUke = b?.gammelUke(nå) ?? false
        uparet = b?.uparet ?? (b == nil)
        streak = b?.streakUker
        generert = b?.generert
        ukenummer = b?.ukenummer
        if nyUke {
            // Ny uke, ingen nye tall ennå. Nøytralt — ikke forrige ukes fasit.
            gjort = 0
            mal = b?.mal ?? 3
            styrke = false
            lop = false
            status = "Ny uke"
            godkjent = false
            forslag = nil
            sovn = nil
            readiness = nil
        } else {
            gjort = b?.gjort ?? 0
            mal = b?.mal ?? 3
            styrke = (b?.styrke ?? 0) > 0
            lop = (b?.lop ?? 0) > 0
            godkjent = b?.godkjent == true && (b?.gjort ?? 0) >= (b?.mal ?? 3)
            status = b?.manglerKort ?? (godkjent ? "I boks" : "")
            forslag = b?.forslag
            sovn = b?.sovnTimer
            if let n = b?.readinessNiva, let s = b?.readinessScore {
                readiness = "Readiness \(s) · \(n)"
            } else if let n = b?.readinessNiva {
                readiness = "Readiness \(n)"
            } else {
                readiness = nil
            }
        }
    }

    /// Eldre enn seks timer. Da vises klokkeslettet dempet — **ikke** som en feil.
    /// Kilden oppdaterer seg sjeldnere om natta, og det er normalt.
    var gammel: Bool {
        guard let g = generert else { return false }
        return Date().timeIntervalSince(g) > 6 * 3600
    }

    var klokke: String? {
        guard let g = generert, gammel else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "nb_NO")
        f.dateFormat = "HH:mm"
        return "kl. " + f.string(from: g)
    }
}

// MARK: - byggeklosser

/// Brikke for styrke eller løp. Fylt grønn med hake når den er gjort, grå med kontur
/// når den ikke er det ennå. Haken gjør at tilstanden ikke bare er en farge.
/// Heter ikke `Brikke`: det navnet er tatt av ukekortet i Trening-modulen, og
/// Swift tillater ikke to toppnivå-typer med samme navn i samme modul — heller ikke
/// når den ene er `private`. Samme felle som `Bolk` 18.10.2026.
private struct Ukebrikke: View {
    let ikon: String
    let tekst: String
    let gjort: Bool

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: gjort ? "checkmark" : ikon)
                .font(.system(size: 8, weight: .bold))
            Text(tekst).font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(gjort ? Farge.ok : Farge.dempet)
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background {
            Capsule()
                .fill(gjort ? Farge.ok.opacity(0.16) : .clear)
                .overlay(Capsule().strokeBorder(gjort ? .clear : Farge.strek, lineWidth: 1))
        }
    }
}

/// Fremdrift med ett segment per planlagt økt — ikke en glidende stolpe.
/// «2 av 3» skal kunne telles, ikke anslås.
private struct Fremdrift: View {
    let gjort: Int
    let mal: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<max(mal, 1), id: \.self) { i in
                Capsule()
                    .fill(i < gjort ? Farge.ok : Farge.strek)
                    .frame(height: 4)
            }
        }
    }
}

private struct Streak: View {
    let uker: Int?
    let stor: Bool

    var body: some View {
        // Streak 0 får ikke være hovedtallet. «0 uker på rad» satt i displayskrift er
        // en fiaskomelding, og widgeten skal dytte i riktig retning.
        if let u = uker, u > 0 {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(u)").font(.system(size: stor ? 34 : 26, weight: .light))
                    .foregroundStyle(Farge.tekst)
                Text(u == 1 ? "uke på rad" : "uker på rad")
                    .font(.system(size: 10)).foregroundStyle(Farge.dempet)
            }
        }
    }
}

// MARK: - visningene

struct Treningssmall: View {
    let t: Treningstilstand

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Streak(uker: t.streak, stor: true)
            HStack(spacing: 5) {
                Ukebrikke(ikon: "figure.strengthtraining.traditional", tekst: "Styrke", gjort: t.styrke)
                Ukebrikke(ikon: "figure.run", tekst: "Løp", gjort: t.lop)
            }
            Spacer(minLength: 2)
            if !t.status.isEmpty {
                Text(t.status)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(t.godkjent ? Farge.ok : Farge.tekst)
                    .lineLimit(2).minimumScaleFactor(0.8)
            }
            Fremdrift(gjort: t.gjort, mal: t.mal)
        }
    }
}

struct Treningsmedium: View {
    let t: Treningstilstand

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Streak(uker: t.streak, stor: false)
                    HStack(spacing: 5) {
                        Ukebrikke(ikon: "figure.strengthtraining.traditional", tekst: "Styrke", gjort: t.styrke)
                        Ukebrikke(ikon: "figure.run", tekst: "Løp", gjort: t.lop)
                    }
                    if !t.status.isEmpty {
                        Text(t.status)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(t.godkjent ? Farge.ok : Farge.tekst)
                            .lineLimit(2).minimumScaleFactor(0.8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    if let f = t.forslag, !f.isEmpty {
                        Text(f).font(.system(size: 12)).foregroundStyle(Farge.tekst)
                            .lineLimit(3).minimumScaleFactor(0.85)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    if let k = kontekst {
                        Text(k).font(.system(size: 10)).foregroundStyle(Farge.dempet)
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Fremdrift(gjort: t.gjort, mal: t.mal)
            if let k = t.klokke {
                Text(k).font(.system(size: 9)).foregroundStyle(Farge.dempet)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    /// Søvn og readiness på én grå linje. Bakgrunn, ikke vurdering — og hver del
    /// skjuler seg selv når den mangler, framfor å stå med en tankestrek.
    private var kontekst: String? {
        var d: [String] = []
        if let s = t.sovn {
            let f = NumberFormatter()
            f.locale = Locale(identifier: "nb_NO")
            f.maximumFractionDigits = 1
            if let v = f.string(from: NSNumber(value: s)) { d.append("Søvn \(v) t") }
        }
        if let r = t.readiness { d.append(r) }
        return d.isEmpty ? nil : d.joined(separator: "  ·  ")
    }
}

struct Treningsring: View {
    let t: Treningstilstand

    var body: some View {
        // Gauge framfor en egen ring: på låseskjermen tegner systemet den med riktig
        // vekt og kontrast for underlaget, og den arver tintingen automatisk.
        Gauge(value: Double(min(t.gjort, t.mal)), in: 0...Double(max(t.mal, 1))) {
            Image(systemName: "figure.strengthtraining.traditional")
        } currentValueLabel: {
            Text("\(t.gjort)")
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }
}

struct Treningsrektangel: View {
    let t: Treningstilstand

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(tittel).font(.system(size: 13, weight: .semibold))
            if !t.status.isEmpty {
                Text(t.status).font(.system(size: 12)).lineLimit(1).minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tittel: String {
        let tall = "\(t.gjort)/\(t.mal)"
        guard let u = t.ukenummer else { return "Trening · \(tall)" }
        return "Uke \(u) · \(tall)"
    }
}
