import WidgetKit
import SwiftUI

/// Treningswidget — hva som mangler denne uka, på ett blikk.
///
/// **Prioriteringen er Thomas' egen:** det viktigste er hva som mangler, fordi det er
/// det som får ham til å trene en tirsdag. Streaken kommer etter. **Vekt er ikke med**
/// — samme premiss som i modulen: vekta skal stå stille med vilje, og et tall som ikke
/// rører seg hører ikke hjemme på en flate man ser tjue ganger om dagen.
///
/// Rødt brukes ingen steder. Grønn betyr oppnådd, grå betyr ikke ennå.

// MARK: - tidslinje

struct Treningsoppføring: TimelineEntry {
    let date: Date
    let bilde: Delt.Treningsbilde?
}

struct Treningsleverandør: TimelineProvider {
    func placeholder(in context: Context) -> Treningsoppføring {
        Treningsoppføring(date: Date(), bilde: Delt.trening())
    }

    func getSnapshot(in context: Context, completion: @escaping (Treningsoppføring) -> Void) {
        completion(Treningsoppføring(date: Date(), bilde: Delt.trening()))
    }

    /// To oppføringer, ikke én.
    ///
    /// Den andre ligger ved **midnatt natt til mandag**. Uten den ville widgeten stått
    /// og vist «3/3 · I boks» gjennom hele mandagen — en gratulasjon for forrige uke,
    /// servert på en dag da regnskapet er nullstilt. `Treningsbilde.gammelUke()` fanger
    /// det samme om systemet aldri rekker å tegne oppføringen, men da først når
    /// widgeten faktisk tegnes på nytt.
    func getTimeline(in context: Context, completion: @escaping (Timeline<Treningsoppføring>) -> Void) {
        Task {
            // Det appen la igjen er alltid utgangspunktet — widgeten skal aldri stå tom
            // fordi nettet var nede. Er det gammelt, prøver vi å hente selv.
            var bilde = Delt.trening()
            let gammelt = bilde.map { Date().timeIntervalSince($0.skrevet) > 1800 } ?? true
            if gammelt, let ferskt = await Delt.hentTrening() {
                bilde = ferskt
                Delt.lagre(ferskt)
            }
            let nå = Date()
            var oppføringer = [Treningsoppføring(date: nå, bilde: bilde)]
            if let mandag = nesteMandag(etter: nå) {
                oppføringer.append(Treningsoppføring(date: mandag, bilde: bilde))
            }
            // En widget som ber om oppdatering hvert minutt får færre, ikke flere.
            completion(Timeline(entries: oppføringer,
                                policy: .after(nå.addingTimeInterval(1800))))
        }
    }

    private func nesteMandag(etter dato: Date) -> Date? {
        var k = Calendar(identifier: .iso8601)
        k.locale = Locale(identifier: "nb_NO")
        return k.nextDate(after: dato, matching: DateComponents(hour: 0, minute: 0, weekday: 2),
                          matchingPolicy: .nextTime)
    }
}

// MARK: - widgeten

struct Treningsvisning: View {
    @Environment(\.widgetFamily) private var familie
    let oppføring: Treningsoppføring

    var body: some View {
        let t = Treningstilstand(oppføring.bilde, nå: oppføring.date)
        Group {
            if t.uparet {
                // Ingen tall å vise, og ingen grunn til å vise nuller i stedet.
                Text("Koble til hjemmet i appen")
                    .font(.system(size: 12)).foregroundStyle(Farge.dempet)
                    .multilineTextAlignment(.center)
            } else {
                switch familie {
                case .accessoryCircular:    Treningsring(t: t)
                case .accessoryRectangular: Treningsrektangel(t: t)
                case .systemMedium:         Treningsmedium(t: t)
                default:                    Treningssmall(t: t)
                }
            }
        }
        .containerBackground(for: .widget) { Farge.kort }
    }
}

struct Treningswidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "no.gustavs1.hjemme.trening",
                            provider: Treningsleverandør()) {
            Treningsvisning(oppføring: $0)
        }
        .configurationDisplayName("Trening")
        .description("Hva som mangler denne uka, og streaken.")
        .supportedFamilies([.systemSmall, .systemMedium,
                            .accessoryCircular, .accessoryRectangular])
    }
}
