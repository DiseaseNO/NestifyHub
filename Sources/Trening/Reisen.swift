import SwiftUI
import Charts

/// «Reisen» — hele kurven, fra start til i dag.
///
/// Dette er skjermen for dager med lav motivasjon. Ukekortet svarer på «hva mangler nå»,
/// og det er riktig spørsmål de fleste dager. Men når svaret på det føles tungt, er det
/// denne som setter det i perspektiv: strekningen som allerede er gått.
///
/// Derfor er den bevisst gjemt bak ett trykk. Den skal ikke konkurrere med ukekortet om
/// oppmerksomheten — den skal være der når man leter etter den.
struct Reiseskjerm: View {
    let reisen: Treningsdata.Reisen
    let vekt: Treningsdata.Vekt?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                overskrift
                if let p = reisen.punkter, p.count > 1 { kurve(p) }
                if let m = reisen.merker, !m.isEmpty { merkeliste(m) }
            }
            .padding(16)
        }
        .background(Farge.flate)
        .scrollIndicators(.hidden)
        .navigationTitle("Reisen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Farge.flate, for: .navigationBar)
    }

    /// Startpunktet er selvrapportert. Det vises med tilde og som anslag — et tall man
    /// husker er ikke det samme som et tall man har målt, og forskjellen skal være synlig.
    private var overskrift: some View {
        let start = reisen.merker?.first { $0.type == "start" }
        let fra = Trening.tall(start?.kg) ?? "–"
        let til = Trening.tall(vekt?.siste?.kg) ?? "–"
        let anslag = start?.erAnslag == true
        return VStack(alignment: .leading, spacing: 4) {
            Text("Fra \(anslag ? "~" : "")\(fra) til \(til) kg")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(Farge.tekst)
            if let d = vekt?.dagerISonen, d > 0 {
                Text("\(d) dager med stabil vekt")
                    .font(.system(size: 13))
                    .foregroundStyle(Farge.ok)
            }
        }
    }

    private func kurve(_ punkter: [Punkt]) -> some View {
        Flate {
            Chart {
                if let f = vekt?.sone?.fra, let t = vekt?.sone?.til {
                    // Samme dempede sone som på hovedskjermen. Her er den enda
                    // viktigere å holde nede: kurven er poenget, sonen er målet
                    // den endte i.
                    RectangleMark(yStart: .value("Fra", f), yEnd: .value("Til", t))
                        .foregroundStyle(Farge.ok.opacity(0.06))
                }
                ForEach(punkter) { p in
                    if let d = Trening.dato(p.dato), let v = p.verdi {
                        LineMark(x: .value("Dato", d), y: .value("kg", v))
                            .interpolationMethod(.monotone)
                            .foregroundStyle(Farge.aksent)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
                ForEach(reisen.merker ?? []) { m in
                    if let d = Trening.dato(m.dato), let v = m.kg {
                        PointMark(x: .value("Dato", d), y: .value("kg", v))
                            .symbolSize(90)
                            .foregroundStyle(m.erAnslag ? Farge.dempet : Farge.tekst)
                        // Anslaget stiples, så det ikke leses som en måling.
                        if m.erAnslag {
                            RuleMark(y: .value("kg", v))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                                .foregroundStyle(Farge.dempet.opacity(0.6))
                        }
                    }
                }
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel(format: .dateTime.year())
                        .font(.system(size: 9)).foregroundStyle(Farge.dempet)
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing) { _ in
                    AxisValueLabel().font(.system(size: 9)).foregroundStyle(Farge.dempet)
                }
            }
            .frame(height: 220)
            .padding(14)
        }
    }

    private func merkeliste(_ merker: [Treningsdata.Reisen.Merke]) -> some View {
        Flate {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(merker) { m in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 5) {
                                Text(navn(m.type))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Farge.tekst)
                                if m.erAnslag {
                                    Text("anslag")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(Farge.dempet)
                                        .padding(.horizontal, 5).padding(.vertical, 1)
                                        .background { Capsule().strokeBorder(Farge.strek, lineWidth: 1) }
                                }
                            }
                            if let n = m.merknad, !n.isEmpty {
                                Text(n).font(.system(size: 11)).foregroundStyle(Farge.dempet)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            if let kg = Trening.tall(m.kg) {
                                Text("\(m.erAnslag ? "~" : "")\(kg) kg")
                                    .font(.system(size: 14, weight: .medium).monospacedDigit())
                                    .foregroundStyle(Farge.tekst)
                            }
                            if let d = Trening.kortDato(m.dato) {
                                Text(d).font(.system(size: 10)).foregroundStyle(Farge.dempet)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private func navn(_ type: String?) -> String {
        switch type {
        case "start":        "Start"
        case "bunn":         "Laveste"
        case "vedlikehold":  "Vedlikehold"
        default:             type?.capitalized ?? "Merke"
        }
    }
}
