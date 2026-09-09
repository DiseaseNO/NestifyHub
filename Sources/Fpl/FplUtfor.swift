import SwiftUI

/// Knappen som lar Thomas si ja til anbefalingen — og kvitteringen etterpå.
///
/// **Appen utfører ingenting.** Den leverer en signert godkjenning; kilden kontrollerer
/// sine egne sperrer og gjør jobben. Det er derfor knappen heter «Utfør anbefalingen» og
/// ikke «Bytt spiller»: vi lover et signal, ikke et resultat.
///
/// Bekreftelsen viser **konsekvensen i klartekst** før trykket — hva som skjer og hva det
/// koster. Kostnaden er kildens tekst, ordrett. Om et bytte er gratis eller koster fire
/// poeng avhenger av frie bytter og chip-tilstand, og det regnestykket er deres.
struct FplUtfor: View {
    let lager: FplLager
    let svar: FplSvar

    @State private var bekreft = false
    @State private var sender = false
    @State private var feil: String?
    @State private var sendtNå = false

    private var d: FplStatus { svar.data }
    private var a: FplStatus.Anbefaling? { d.anbefaling }
    private var u: FplStatus.Utforelse? { d.utforelse }

    /// Kvitteringen teller bare når den gjelder anbefalingen som ligger der nå.
    /// En kvittering fra forrige runde skal ikke se ut som svar på dagens knapp.
    private var kvittering: FplStatus.Utforelse? {
        guard let u, u.status != "ingen" else { return nil }
        if u.gjelder_naavaerende == false { return nil }
        return u
    }

    /// Kan vi i det hele tatt tilby knappen?
    private var kanUtfore: Bool {
        guard let a, a.finnes == true, a.id != nil, a.grunnlag_id != nil else { return false }
        // Låst runde: fristen har gått, og kilden ville uansett avvist med `avvist_frist`.
        // Bedre å ikke tilby knappen enn å la den feile.
        if d.runde.laast { return false }
        return kvittering == nil && !sendtNå
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let k = kvittering {
                kvitteringsrad(k)
            } else if sendtNå {
                // Mellomtilstand: vi har levert, kilden har ikke rukket å svare. Uten
                // denne ser skjermen ut som om trykket forsvant.
                rad("clock.arrow.circlepath", Farge.aksent,
                    "Godkjenningen er levert",
                    "Kilden henter den innen et minutt. Kvitteringen dukker opp her.")
            } else if kanUtfore {
                knapp
            } else if d.runde.laast, a?.finnes == true {
                rad("lock", Farge.svak, "Runden er låst",
                    "Fristen har passert — anbefalingen kan ikke utføres nå.")
            }

            if let feil {
                Label(feil, systemImage: "exclamationmark.triangle")
                    .font(.caption2).foregroundStyle(Farge.avvik)
            }
        }
        .confirmationDialog("Utfør anbefalingen?", isPresented: $bekreft, titleVisibility: .visible) {
            Button("Utfør") { Task { await send() } }
            Button("Avbryt", role: .cancel) {}
        } message: {
            // Konsekvensen i klartekst. Det er forskjellen på en knapp man tør bruke og
            // en man lar være.
            Text(bekreftelsestekst)
        }
    }

    private var bekreftelsestekst: String {
        var deler: [String] = []
        if let s = a?.sammendrag, !s.isEmpty { deler.append(s) }
        if let k = a?.kostnad, !k.isEmpty { deler.append("Kostnad: \(k)") }
        deler.append("Godkjenningen sendes til FPL-systemet, som utfører den. "
                     + "Den kan ikke trekkes tilbake herfra.")
        return deler.joined(separator: "\n\n")
    }

    private var knapp: some View {
        VStack(alignment: .leading, spacing: 7) {
            Button {
                Kjenn.trykk()
                bekreft = true
            } label: {
                HStack(spacing: 8) {
                    if sender {
                        ProgressView().controlSize(.small).tint(Farge.flate)
                    } else {
                        Image(systemName: "checkmark.seal.fill").font(.footnote)
                    }
                    Text(sender ? "Sender …" : "Utfør anbefalingen")
                        .font(.callout.weight(.semibold))
                }
                .frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(Farge.aksent).foregroundStyle(Farge.flate)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(Trykkflate())
            .disabled(sender)

            if let k = a?.kostnad, !k.isEmpty {
                Text(k).font(.caption2).foregroundStyle(Farge.dempet)
            }
        }
    }

    @ViewBuilder
    private func kvitteringsrad(_ k: FplStatus.Utforelse) -> some View {
        let (ikon, farge) = utseende(k.status)
        VStack(alignment: .leading, spacing: 6) {
            rad(ikon, farge, Ordliste.etikett(k.status), k.hva_ble_gjort ?? k.merknad)
            if let kost = k.kostnad, !kost.isEmpty {
                Text(kost).font(.caption2).foregroundStyle(Farge.dempet)
            }
            if let f = k.feil, !f.isEmpty {
                Text(f).font(.caption2).foregroundStyle(Farge.avvik)
            }
            // Kontrollkjøringen, bak en fold: den er teknisk, og skal være tilgjengelig
            // uten å være det første man møter.
            if let d = k.diff, !d.isEmpty {
                DisclosureGroup("Hva som ble endret") {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(d, id: \.self) { linje in
                            Text(linje).font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(Farge.dempet)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                }
                .font(.caption2).tint(Farge.svak).foregroundStyle(Farge.dempet)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(farge.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func rad(_ ikon: String, _ farge: Color, _ tittel: String, _ under: String?) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: ikon).font(.footnote).foregroundStyle(farge).frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(tittel).font(.footnote.weight(.medium)).foregroundStyle(Farge.tekst)
                if let under, !under.isEmpty {
                    Text(under).font(.caption2).foregroundStyle(Farge.dempet)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
    }

    /// Ikon og farge per status. Avvist er ikke det samme som feilet: det første er en
    /// sperre som gjorde jobben sin, det andre er noe som gikk galt.
    private func utseende(_ status: String) -> (String, Color) {
        switch status {
        case "utfort": ("checkmark.seal.fill", Farge.ok)
        case "venter": ("clock.arrow.circlepath", Farge.aksent)
        case "avvist_endret_grunnlag", "avvist_frist": ("hand.raised.fill", Farge.dempet)
        case "feilet": ("exclamationmark.triangle.fill", Farge.avvik)
        default: ("info.circle", Farge.dempet)
        }
    }

    private func send() async {
        sender = true
        defer { sender = false }
        do {
            try await lager.godkjenn()
            Kjenn.vellykket()
            sendtNå = true
            feil = nil
        } catch {
            feil = error.localizedDescription
        }
    }
}
