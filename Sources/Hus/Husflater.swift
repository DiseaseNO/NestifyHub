import SwiftUI

/// Byggeklossene Huset tegnes av.
///
/// Ligger samlet fordi de skal se like ut. Da den første utgaven vokste fram kort for
/// kort, endte alt som like grå bokser i én kolonne — hvert kort var greit for seg, og
/// helheten var en vegg. Formen bestemmes her, innholdet der det hører hjemme.
enum Hus {
    /// Hjørneradius. Store flater tåler mer avrunding enn små; ellers ser de små ut som
    /// piller og de store som bokser.
    static let radiusStor: CGFloat = 18
    static let radiusLiten: CGFloat = 14
}

/// Kortflate med lys når noe er på.
///
/// Det er dette som gjør at skjermen kan leses på en armlengdes avstand: et rom med lys
/// på gløder svakt varmt, et mørkt rom er kaldt og flatt. Toggle-bryteren sier det samme,
/// men den må man se etter.
struct Flate<Innhold: View>: View {
    var aktiv = false
    var radius: CGFloat = Hus.radiusStor
    @ViewBuilder var innhold: () -> Innhold

    var body: some View {
        innhold()
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Farge.kort)
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Farge.aksent.opacity(aktiv ? 0.16 : 0),
                                             Farge.aksent.opacity(aktiv ? 0.03 : 0)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(aktiv ? Farge.aksent.opacity(0.28) : Farge.strek,
                                          lineWidth: 1)
                    }
            }
            .animation(.smooth(duration: 0.35), value: aktiv)
    }
}

/// Trykkflate som synker litt inn.
///
/// Uten dette er det ingenting som bekrefter at trykket traff, og på et kort som bruker
/// et halvt sekund på å svare, rekker man å tvile.
struct Trykkflate: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}

/// Kort haptikk. Den bekrefter at kommandoen ER sendt — ikke at lyset har svart.
enum Kjenn {
    static func trykk() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
    static func vellykket() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
}

/// Av/på som en rund knapp framfor en systembryter.
///
/// En `Toggle` inne i et kort som selv kan trykkes, blir tvetydig: to trykkflater
/// oppå hverandre, og ingenting sier hva som skjer hvor. Knappen her er tydelig
/// avgrenset, og resten av kortet gjør noe annet.
struct Strømknapp: View {
    let paa: Bool
    var jobber = false
    var størrelse: CGFloat = 38
    let handling: () -> Void

    var body: some View {
        Button {
            Kjenn.trykk()
            handling()
        } label: {
            ZStack {
                Circle()
                    .fill(paa ? Farge.aksent.opacity(0.22) : Farge.kort2)
                Circle()
                    .strokeBorder(paa ? Farge.aksent.opacity(0.5) : Farge.strek, lineWidth: 1)
                if jobber {
                    ProgressView().controlSize(.mini).tint(Farge.dempet)
                } else {
                    Image(systemName: "power")
                        .font(.system(size: størrelse * 0.42, weight: .semibold))
                        .foregroundStyle(paa ? Farge.aksent : Farge.svak)
                }
            }
            .frame(width: størrelse, height: størrelse)
        }
        .buttonStyle(Trykkflate())
        .disabled(jobber)
        .animation(.smooth(duration: 0.3), value: paa)
    }
}

/// Overskrift over en gruppe.
struct Seksjonstittel: View {
    let tekst: String
    var body: some View {
        Text(tekst.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.8)
            .foregroundStyle(Farge.dempet)
    }
}

/// Et tall med enhet og etikett, satt slik at tallet leses først.
struct Nøkkeltall: View {
    let verdi: String
    var enhet: String?
    let etikett: String
    var farge: Color = Farge.tekst
    var stor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(verdi)
                    .font(.system(size: stor ? 40 : 22,
                                  weight: stor ? .light : .medium)
                        .monospacedDigit())
                    .foregroundStyle(farge)
                    .contentTransition(.numericText())
                if let enhet {
                    Text(enhet).font(.caption).foregroundStyle(Farge.dempet)
                }
            }
            Text(etikett)
                .font(.system(size: 10))
                .foregroundStyle(Farge.svak)
        }
    }
}

/// Vannrett stolpe som viser hvor noe ligger mellom to ytterpunkter.
struct Stolpe: View {
    /// 0–1. Utenfor klippes den; en stolpe som renner ut av kortet er ikke informasjon.
    let andel: Double
    var farge: Color = Farge.aksent
    var høyde: CGFloat = 6

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Farge.kort2)
                Capsule()
                    .fill(LinearGradient(colors: [farge.opacity(0.65), farge],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(0, min(1, andel)) * g.size.width)
            }
        }
        .frame(height: høyde)
        .animation(.smooth(duration: 0.5), value: andel)
    }
}

/// Ikon som passer til rommet.
///
/// Gjetter fra navnet. Bommer den, er den fortsatt bedre enn samme symbol overalt —
/// og ingenting går i stykker av et ikon som ikke stemmer.
func romikon(_ navn: String) -> String {
    let n = navn.lowercased()
    if n.contains("kjøkken") { return "cooktop" }
    if n.contains("spisestue") { return "fork.knife" }
    if n.contains("tv") { return "tv" }
    if n.contains("stue") { return "sofa" }
    if n.contains("bad") { return "shower" }
    if n.contains("soverom") { return "bed.double" }
    if n.contains("gang") || n.contains("trapp") { return "figure.walk" }
    if n.contains("bod") || n.contains("vaskerom") { return "washer" }
    if n.contains("loft") { return "stairs" }
    if n.contains("ute") { return "tree" }
    return "square.grid.2x2"
}
