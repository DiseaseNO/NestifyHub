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
        // EGET ark, ikke `confirmationDialog`.
        //
        // Dialogen fikk hele sammendraget som melding — en halv side tekst som dyttet
        // «Avbryt» ut av skjermen. En bekreftelse man ikke kan avbryte er ikke en
        // bekreftelse. Arket har fast bunn med begge knappene, og teksten ruller.
        .sheet(isPresented: $bekreft) { bekreftelsesark }
    }

    /// Hva som faktisk skjer, punkt for punkt.
    ///
    /// Bygget av de STRUKTURERTE feltene, ikke av sammendraget. Sammendraget er kildens
    /// begrunnelse — den hører hjemme på skjermen bak, der man leser den i ro. Her skal
    /// det stå hva knappen gjør, og det er en kort liste.
    private var handlinger: [String] {
        guard let a else { return [] }
        var ut: [String] = []
        for b in a.bytter ?? [] {
            let inn = b.inn?.navn ?? "?"
            let utNavn = b.ut?.navn ?? "?"
            ut.append("Bytte: \(utNavn) ut, \(inn) inn")
        }
        if (a.bytter ?? []).isEmpty { ut.append("Ingen bytter") }
        if let k = a.kaptein?.navn { ut.append("Kaptein: \(k)") }
        if let v = a.vise?.navn { ut.append("Visekaptein: \(v)") }
        if a.endrer_oppstilling == true { ut.append("Endrer startelleveren") }
        if let c = a.chip { ut.append("Chip: \(c)") }
        return ut
    }

    private var bekreftelsesark: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 9) {
                            Text("Dette skjer").font(.caption.weight(.semibold))
                                .foregroundStyle(Farge.dempet)
                            ForEach(handlinger, id: \.self) { h in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "arrow.right").font(.caption2)
                                        .foregroundStyle(Farge.aksent).padding(.top, 2)
                                    Text(h).font(.subheadline).foregroundStyle(Farge.tekst)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }

                        if let k = a?.kostnad, !k.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Kostnad").font(.caption.weight(.semibold))
                                    .foregroundStyle(Farge.dempet)
                                // Kildens tekst, ordrett. Vi regner ikke selv om et bytte
                                // er gratis — det avhenger av frie bytter og chip.
                                Text(k).font(.subheadline.weight(.medium))
                                    .foregroundStyle(Farge.tekst)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        Label("Godkjenningen sendes til FPL-systemet, som utfører den. "
                              + "Den kan ikke trekkes tilbake herfra.",
                              systemImage: "exclamationmark.circle")
                            .font(.caption).foregroundStyle(Farge.svak)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(18)
                }
                .scrollIndicators(.hidden)

                // Fast bunn: knappene skal ALLTID være synlige, uansett hvor lang
                // teksten over blir.
                VStack(spacing: 9) {
                    Button {
                        bekreft = false
                        Task { await send() }
                    } label: {
                        Text("Utfør").font(.callout.weight(.semibold))
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Farge.aksent).foregroundStyle(Farge.flate)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(Trykkflate())
                    Button("Avbryt") { bekreft = false }
                        .font(.callout).foregroundStyle(Farge.dempet)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                }
                .padding(.horizontal, 18).padding(.bottom, 10)
            }
            .background(Farge.flate)
            .navigationTitle("Utfør anbefalingen?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Farge.flate, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
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
