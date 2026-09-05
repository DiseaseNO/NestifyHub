import WidgetKit
import SwiftUI

/// Hjemskjerm-widget: husets effekt og hvor mange lys som står på.
///
/// Widgeten er en **egen prosess** som systemet vekker når det passer det — ofte når
/// appen ikke har vært åpen på timer. Derfor leser den øyeblikksbildet appen la igjen i
/// app-gruppa framfor å hente selv. Den skal aldri stå tom fordi nettet var nede.
///
/// `.after`-policyen ber om nytt om et kvarter. Systemet bestemmer selv om det gir oss
/// det; en widget som ber om oppdatering hvert minutt får færre, ikke flere.
struct Husoppføring: TimelineEntry {
    let date: Date
    let bilde: Delt.Husbilde?
}

struct Husleverandør: TimelineProvider {
    func placeholder(in context: Context) -> Husoppføring {
        Husoppføring(date: Date(), bilde: .init(effektWatt: 2400, lysPaa: 5, kroner: nil,
                                               oppdatert: Date()))
    }

    func getSnapshot(in context: Context, completion: @escaping (Husoppføring) -> Void) {
        completion(Husoppføring(date: Date(), bilde: Delt.lest() ?? placeholder(in: context).bilde))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Husoppføring>) -> Void) {
        let nå = Date()
        completion(Timeline(entries: [Husoppføring(date: nå, bilde: Delt.lest())],
                            policy: .after(nå.addingTimeInterval(15 * 60))))
    }
}

struct Husvisning: View {
    var oppføring: Husoppføring

    var body: some View {
        let b = oppføring.bilde
        VStack(alignment: .leading, spacing: 6) {
            if b?.uparet == true || b == nil {
                // Ingen data er ikke det samme som null forbruk. Widgeten sier hvorfor.
                Text("Ikke koblet til")
                    .font(.headline).foregroundStyle(.secondary)
                Text("Åpne appen og par enheten")
                    .font(.caption2).foregroundStyle(.tertiary)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(b?.effektWatt.map { String(format: "%.1f", Double($0) / 1000) } ?? "–")
                        .font(.system(size: 34, weight: .light).monospacedDigit())
                    Text("kW").font(.caption).foregroundStyle(.secondary)
                }
                Label("\(b?.lysPaa ?? 0) lys på", systemImage: "lightbulb.fill")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if let o = b?.oppdatert {
                    // Alderen på tallet står alltid. En widget som viser et gammelt tall
                    // uten å si det, er verre enn en tom widget.
                    Text(o, style: .relative).font(.system(size: 9)).foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { Color.black }
    }
}

struct Huswidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "no.gustavs1.hjemme.hus", provider: Husleverandør()) {
            Husvisning(oppføring: $0)
        }
        .configurationDisplayName("Huset")
        .description("Effekt og lys akkurat nå.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

@main
struct Widgetpakke: WidgetBundle {
    var body: some Widget { Huswidget() }
}
