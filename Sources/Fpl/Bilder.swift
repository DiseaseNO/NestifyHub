import SwiftUI

/// Drakt, spillerfoto og klubblogo.
///
/// URL-ene kommer alltid fra kilden (`tropp[].bilder`) — appen setter ikke sammen
/// adresser selv. Det holder repoet fritt for vertsnavn, og det betyr at en flyttet
/// bildetjeneste er en endring hos dem, ikke en ny app-versjon.
///
/// **Draktene er standarden på banen.** De finnes for alle 20 lag, er små, og leses som
/// lagtilhørighet på et halvt sekund. Spillerfoto brukes bare i detaljvisningen, og bare
/// når kilden har bekreftet at det finnes — `spiller.finnes` er HEAD-verifisert per
/// eksport, og to spillere i troppen ga 403 den 02.09.
struct Draktbilde: View {
    let bilder: FplStatus.Spiller.Bilder?
    var størrelse: CGFloat = 26

    var body: some View {
        bilde(bilder?.drakt?.liten ?? bilder?.drakt?.png)
            .frame(width: størrelse, height: størrelse)
    }

    @ViewBuilder
    private func bilde(_ adresse: String?) -> some View {
        if let a = adresse, let url = URL(string: a) {
            AsyncImage(url: url) { bilde in
                bilde.resizable().scaledToFit()
            } placeholder: {
                // Ingen spinner: kortet skal ikke blafre mens femten drakter lastes.
                Color.clear
            }
        } else {
            Color.clear
        }
    }
}

/// Portrett til detaljvisningen: foto når kilden sier det finnes, ellers drakta.
struct Spillerportrett: View {
    let bilder: FplStatus.Spiller.Bilder?
    var størrelse: CGFloat = 74

    private var fotoFinnes: Bool { bilder?.spiller?.finnes == true }

    var body: some View {
        Group {
            if fotoFinnes, let a = bilder?.spiller?.medium ?? bilder?.spiller?.stor,
               let url = URL(string: a) {
                AsyncImage(url: url) { bilde in
                    bilde.resizable().scaledToFit()
                } placeholder: {
                    Draktbilde(bilder: bilder, størrelse: størrelse * 0.7)
                }
            } else {
                // Fallback, ikke en tom ramme: drakta finnes alltid.
                Draktbilde(bilder: bilder, størrelse: størrelse * 0.7)
            }
        }
        .frame(width: størrelse, height: størrelse)
        .background(Farge.kort2)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// Klubbmerket. Hører til kampinfo, ikke til spillerkortet — to klubbmerker på samme
/// kort konkurrerer om det samme blikket.
struct Klubbmerke: View {
    let bilder: FplStatus.Spiller.Bilder?
    var størrelse: CGFloat = 16

    var body: some View {
        // PNG framfor SVG: SwiftUI laster ikke SVG over nett uten et ekstra ledd.
        if let a = bilder?.klubblogo?.png, let url = URL(string: a) {
            AsyncImage(url: url) { bilde in
                bilde.resizable().scaledToFit()
            } placeholder: {
                Color.clear
            }
            .frame(width: størrelse, height: størrelse)
        }
    }
}
