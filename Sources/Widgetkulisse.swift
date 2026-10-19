#if DEBUG
import SwiftUI

/// Rendrer treningswidgeten inne i appen, i CI.
///
/// **Hvorfor dette finnes.** En widget kjører i en egen prosess som systemet vekker,
/// og den kan ikke knipses med `simctl` slik en app-skjerm kan. Uten en kulisse ville
/// widgeten gått til Thomas uten at noen hadde sett den tegnet — og det er nøyaktig
/// feilen som gjorde at Trening-modulen ble sendt ut ødelagt to ganger: testveien så
/// ikke det brukeren så.
///
/// **Hva den beviser, og hva den ikke beviser.** Den viser de ekte visningene fra
/// `Delt/Treningsvisninger.swift` med ekte `Treningsbilde`-data, i målene WidgetKit
/// bruker. Den beviser at layouten holder, at tomme felt skjuler seg, og at
/// ukeskiftet slår inn. Den beviser **ikke** at tidslinja virker, at systemet tegner
/// den på hjemskjermen, eller at app-gruppa er riktig satt opp. Det må prøves på
/// telefonen.
struct Widgetkulisse: View {
    /// Målene WidgetKit bruker på iPhone 16 Pro, i punkter.
    private let small = CGSize(width: 170, height: 170)
    private let medium = CGSize(width: 364, height: 170)
    private let rektangel = CGSize(width: 172, height: 76)
    private let sirkel = CGSize(width: 76, height: 76)

    /// Én tilstand per skjermbilde.
    ///
    /// Første utgave la small og medium ved siden av hverandre: 170 + 364 = 534 punkter
    /// på en skjerm som er 393 bred. Begge ble beskåret, og bildet var ubrukelig til
    /// det det finnes for. Medium alene er 364 og krever at margen holdes under 15.
    let tilfelle: Kulissedata.Tilfelle

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tilfelle.navn).font(.system(size: 11, weight: .semibold))
                .tracking(0.6).foregroundStyle(Farge.dempet)

            HStack(alignment: .top, spacing: 10) {
                merket("small") { ramme(small) { Treningssmall(t: tilfelle.tilstand) } }
                merket("circular") {
                    ramme(sirkel) { Treningsring(t: tilfelle.tilstand) }
                }
            }
            merket("medium") { ramme(medium) { Treningsmedium(t: tilfelle.tilstand) } }
            merket("rectangular") {
                ramme(rektangel) { Treningsrektangel(t: tilfelle.tilstand) }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Farge.flate)
    }

    private func merket<I: View>(_ navn: String, @ViewBuilder _ innhold: () -> I) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(navn).font(.system(size: 9)).foregroundStyle(Farge.svak)
            innhold()
        }
    }

    private func ramme<I: View>(_ str: CGSize, @ViewBuilder _ innhold: () -> I) -> some View {
        innhold()
            .padding(12)
            .frame(width: str.width, height: str.height, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 18).fill(Farge.kort))
    }
}

/// De tre tilstandene som faktisk skal sjekkes: ny uke, delvis, i boks.
///
/// Skrevet ut som `Treningsbilde` og ikke som ferdige `Treningstilstand`-er, slik at
/// omregningen — særlig ukeskiftet — går gjennom den samme koden widgeten bruker.
enum Kulissedata {
    struct Tilfelle { let navn: String; let tilstand: Treningstilstand }

    /// `-tilstand <navn>`. Ukjent eller manglende navn gir «delvis», som er den
    /// tilstanden med flest felt i bruk.
    static func valgt(_ navn: String?) -> Tilfelle {
        switch navn {
        case "nyuke": Tilfelle(navn: "NY UKE", tilstand: Treningstilstand(nyUke, nå: nå))
        case "iboks": Tilfelle(navn: "I BOKS", tilstand: Treningstilstand(iBoks, nå: nå))
        default: Tilfelle(navn: "DELVIS — 1 STYRKE, 0 LØP",
                          tilstand: Treningstilstand(delvis, nå: nå))
        }
    }

    private static let nå = Date()

    private static var grunn: Delt.Treningsbilde {
        var b = Delt.Treningsbilde()
        b.generert = nå.addingTimeInterval(-900)
        b.mal = 3
        b.ukenummer = 43
        b.sovnTimer = 7.1
        b.readinessScore = 68
        b.readinessNiva = "Middels"
        b.ukeSlutt = iDag(leggTil: 4)
        return b
    }

    /// Uka som er over. `ukeSlutt` i går, så `gammelUke()` slår inn og widgeten skal
    /// vise «Ny uke» i stedet for forrige ukes fasit.
    private static var nyUke: Delt.Treningsbilde {
        var b = grunn
        b.ukeSlutt = iDag(leggTil: -1)
        b.streakUker = 4
        b.gjort = 3
        b.styrke = 2
        b.lop = 1
        b.godkjent = true
        b.manglerKort = "I boks"
        b.forslag = "Uka er i boks. Hvile eller en rolig tur."
        return b
    }

    private static var delvis: Delt.Treningsbilde {
        var b = grunn
        b.streakUker = 1
        b.gjort = 1
        b.styrke = 1
        b.lop = 0
        b.godkjent = false
        b.manglerKort = "Mangler løp"
        b.forslag = "En løpetur i dag holder streaken i live."
        return b
    }

    private static var iBoks: Delt.Treningsbilde {
        var b = grunn
        b.streakUker = 5
        b.gjort = 3
        b.styrke = 2
        b.lop = 1
        b.godkjent = true
        b.manglerKort = "I boks"
        b.forslag = "Uka er i boks. Hvile eller en rolig tur."
        return b
    }

    private static func iDag(leggTil dager: Int) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "nb_NO")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Calendar.current.date(byAdding: .day, value: dager, to: nå) ?? nå)
    }
}
#endif
