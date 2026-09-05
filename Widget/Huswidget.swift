import WidgetKit
import SwiftUI
import AppIntents

/// Hjemskjerm-widget for huset — brukeren velger selv hva den viser.
///
/// Widgeten er en **egen prosess** som systemet vekker når det passer det, ofte når appen
/// ikke har vært åpen på timer. Derfor leser den øyeblikksbildet appen la igjen i
/// app-gruppa framfor å hente selv. Den skal aldri stå tom fordi nettet var nede.
///
/// `.after`-policyen ber om nytt om et kvarter. Systemet bestemmer selv om vi får det;
/// en widget som ber om oppdatering hvert minutt får færre oppdateringer, ikke flere.

// MARK: - Hva widgeten kan vise

enum Visning: String, AppEnum {
    case effekt, kostnad, lys, rom, garasje

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Innhold"
    static var caseDisplayRepresentations: [Visning: DisplayRepresentation] = [
        .effekt:  "Forbruk akkurat nå",
        .kostnad: "Hva det koster nå",
        .lys:     "Lys som står på",
        .rom:     "Ett rom",
        .garasje: "Garasjeport",
    ]
}

/// Rommene, hentet fra øyeblikksbildet.
///
/// Lista kan ikke stå i koden: huset endrer seg uten at appen bygges på nytt, og et rom
/// som mangler i widgetoppsettet ville sett ut som en feil i appen.
struct Romvalg: AppEntity {
    let id: String
    let navn: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Rom"
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(navn)") }
    static var defaultQuery = Romspørring()
}

struct Romspørring: EntityQuery {
    private func alle() -> [Romvalg] {
        (Delt.lest()?.rom ?? []).map { Romvalg(id: $0.navn, navn: $0.navn) }
    }
    func entities(for ider: [Romvalg.ID]) async throws -> [Romvalg] {
        alle().filter { ider.contains($0.id) }
    }
    func suggestedEntities() async throws -> [Romvalg] { alle() }
    func defaultResult() async -> Romvalg? { alle().first }
}

struct Husvalg: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Huset"
    static var description = IntentDescription("Velg hva widgeten skal vise.")

    @Parameter(title: "Vis", default: .effekt)
    var visning: Visning

    /// Brukes bare når `visning == .rom`. iOS viser den uansett; å skjule den betinget
    /// krever en parameter-oppsummering som ikke er verdt kompleksiteten her.
    @Parameter(title: "Hvilket rom")
    var rom: Romvalg?
}

// MARK: - Tidslinje

struct Husoppføring: TimelineEntry {
    let date: Date
    let bilde: Delt.Husbilde?
    let valg: Husvalg
}

struct Husleverandør: AppIntentTimelineProvider {
    private var eksempel: Delt.Husbilde {
        .init(effektWatt: 2400, lysPaa: 5, kroner: 1.24, oppdatert: Date(),
              rom: [.init(navn: "Stue", lysPaa: 1, lysTotalt: 1, temp: 21.5, klima: "varmer")],
              garasjeAapen: false)
    }

    func placeholder(in context: Context) -> Husoppføring {
        Husoppføring(date: Date(), bilde: eksempel, valg: Husvalg())
    }

    func snapshot(for valg: Husvalg, in context: Context) async -> Husoppføring {
        Husoppføring(date: Date(), bilde: Delt.lest() ?? eksempel, valg: valg)
    }

    func timeline(for valg: Husvalg, in context: Context) async -> Timeline<Husoppføring> {
        let nå = Date()
        return Timeline(entries: [Husoppføring(date: nå, bilde: Delt.lest(), valg: valg)],
                        policy: .after(nå.addingTimeInterval(15 * 60)))
    }
}

// MARK: - Visning

struct Husvisning: View {
    var oppføring: Husoppføring

    private var b: Delt.Husbilde? { oppføring.bilde }

    /// Rommet brukeren valgte, med FERSKE tall. Valget lagrer bare navnet — hadde vi
    /// lagret verdiene, ville widgeten vist tallene fra den gangen den ble satt opp.
    private var valgtRom: Delt.Husbilde.Rom? {
        guard let navn = oppføring.valg.rom?.id else { return b?.rom.first }
        return b?.rom.first { $0.navn == navn } ?? b?.rom.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if b?.uparet == true || b == nil {
                // Ingen data er ikke det samme som null forbruk. Widgeten sier hvorfor.
                Text("Ikke koblet til").font(.headline).foregroundStyle(.secondary)
                Text("Åpne appen og par enheten").font(.caption2).foregroundStyle(.tertiary)
            } else {
                innhold
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

    @ViewBuilder
    private var innhold: some View {
        switch oppføring.valg.visning {
        case .effekt:
            stort(b?.effektWatt.map { String(format: "%.1f", Double($0) / 1000) } ?? "–", "kW")
            Text("i huset nå").font(.caption).foregroundStyle(.secondary)

        case .kostnad:
            // Øre i timen framfor kr/kWt: det er det tallet som endrer seg mens du ser
            // på det, og det som svarer på «koster det mye akkurat nå».
            if let w = b?.effektWatt, let p = b?.kroner {
                stort(String(format: "%.0f", Double(w) / 1000 * p * 100), "øre/t")
                Text(String(format: "%.2f kr/kWt", p)).font(.caption).foregroundStyle(.secondary)
            } else {
                stort("–", "")
                Text("mangler pris eller måling").font(.caption2).foregroundStyle(.tertiary)
            }

        case .lys:
            stort("\(b?.lysPaa ?? 0)", "")
            Label("lys står på", systemImage: "lightbulb.fill")
                .font(.caption).foregroundStyle(.secondary)

        case .rom:
            if let r = valgtRom {
                Text(r.navn).font(.caption.weight(.medium))
                stort("\(r.lysPaa)/\(r.lysTotalt)", "lys")
                HStack(spacing: 6) {
                    if let t = r.temp { Text(String(format: "%.1f°", t)) }
                    if r.klima == "varmer" {
                        Label("varmer", systemImage: "flame.fill").foregroundStyle(.orange)
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Ingen rom valgt").font(.headline).foregroundStyle(.secondary)
                Text("Hold på widgeten og velg rom").font(.caption2).foregroundStyle(.tertiary)
            }

        case .garasje:
            if let åpen = b?.garasjeAapen {
                Image(systemName: åpen ? "door.garage.open" : "door.garage.closed")
                    .font(.system(size: 30))
                    .foregroundStyle(åpen ? .orange : .secondary)
                Text(åpen ? "Åpen" : "Lukket")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(åpen ? .orange : .primary)
            } else {
                Text("Ukjent").font(.headline).foregroundStyle(.secondary)
                Text("ingen kontakt med porten").font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }

    private func stort(_ verdi: String, _ enhet: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(verdi).font(.system(size: 34, weight: .light).monospacedDigit())
            if !enhet.isEmpty {
                Text(enhet).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct Huswidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "no.gustavs1.hjemme.hus",
                               intent: Husvalg.self,
                               provider: Husleverandør()) {
            Husvisning(oppføring: $0)
        }
        .configurationDisplayName("Huset")
        .description("Velg selv: forbruk, kostnad, lys, et rom eller garasjeporten.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

@main
struct Widgetpakke: WidgetBundle {
    var body: some Widget { Huswidget() }
}
