import SwiftUI

/// Nestify Hub — samleapp for husholdet. (Internt heter prosjektet Navet.)
///
/// Bevisst TOM. Dette er skallet: prosjektfil, signering og TestFlight-løype, uten
/// moduler og uten datalag. Modulene legges inn når strukturen er bestemt.
///
/// Kameraene bor i sin egen app (CameraRelay) og skal ikke inn her.
@main
struct NavetApp: App {
    var body: some Scene {
        WindowGroup {
            Hovedvisning()
                .preferredColorScheme(.dark)
                .tint(Farge.aksent)
                // Appen er på norsk; uten dette arver den enhetens locale og viser
                // klokkeslett som «7:36 PM».
                .environment(\.locale, Locale(identifier: "nb_NO"))
        }
    }
}

struct Hovedvisning: View {
    var body: some View {
        ZStack {
            Farge.flate.ignoresSafeArea()
            VStack(spacing: 10) {
                Image(systemName: "house")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(Farge.aksent)
                Text(navn)
                    .font(.title2.weight(.medium))
                    .foregroundStyle(Farge.tekst)
                Text("Skallet står klart — ingen moduler ennå.")
                    .font(.footnote)
                    .foregroundStyle(Farge.dempet)
                Text(versjon)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Farge.svak)
                    .padding(.top, 6)
            }
        }
    }

    /// Navnet leses fra bundelen, ikke hardkodet. `CFBundleDisplayName` settes av
    /// XcodeGen fra `$DISPLAY_NAME`, som er en GitHub-secret nettopp så navnet kan
    /// byttes uten kodeendring — da må teksten i appen følge med av seg selv.
    private var navn: String {
        let i = Bundle.main.infoDictionary
        return (i?["CFBundleDisplayName"] as? String)
            ?? (i?["CFBundleName"] as? String) ?? "Nestify Hub"
    }

    /// Vises i skallet så man ser HVILKET bygg som ligger på telefonen. Uten det er
    /// «er den nye versjonen installert?» et gjettespørsmål.
    private var versjon: String {
        let i = Bundle.main.infoDictionary
        return "versjon \(i?["CFBundleShortVersionString"] as? String ?? "?") "
            + "(bygg \(i?["CFBundleVersion"] as? String ?? "?"))"
    }
}
