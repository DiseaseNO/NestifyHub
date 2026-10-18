import SwiftUI
import Charts

/// Oversikten i Trening-modulen.
///
/// **Versjon 2.** Første utgave viste lite og kunne ikke utforskes — Thomas' dom var
/// «alt for lite informasjon, kan ikke klikke på noe, ser ikke status på formen». Den
/// var bygget riktig etter en brief som var for snever. Nå er hvert kort en inngang til
/// en detaljskjerm, og det som faktisk mangler — råd, form og fremgang — står øverst.
///
/// Premisset fra v1 står: **vekt er aldri hovedtallet**, grønn betyr bare «oppnådd»,
/// grå betyr «ikke ennå», **rødt brukes ingen steder**, og tekstene fra kilden brukes
/// ordrett. Et felt som mangler skjuler sitt eget kort framfor å vise en null.
///
/// Det som er NYTT i v2 er at man kan trykke. Men fortsatt **ingen input** — hvert
/// trykk åpner noe å lese, aldri noe å fylle ut.
struct TreningOversikt: View {
    let lager: TreningLager

    var body: some View {
        // ScrollViewReader er her UTELUKKENDE for CI. Oversikten er lengre enn
        // skjermen, og simulatoren knipser bare det som er synlig — alt fra Løping
        // og nedover gikk aldri til bruker uten at noen hadde sett det rendret.
        // Det er nøyaktig den feilen skjermbilde-jobben finnes for å fange.
        ScrollViewReader { lenke in
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let d = lager.data {
                    if let i = d.iDag, let f = i.forslag, !f.isEmpty { IDagBanner(iDag: i) }

                    if let u = d.uke {
                        NavigationLink { UkeSkjerm(uke: u, okter: d.okter ?? []) }
                            label: { Ukekort(uke: u) }
                            .buttonStyle(Trykkflate())
                            .id(Treningsmål.uke.anker)
                    }
                    if let f = d.form {
                        NavigationLink { FormSkjerm(form: f) } label: { Formkort(form: f) }
                            .buttonStyle(Trykkflate())
                            .id(Treningsmål.form.anker)
                    }

                    // Det Thomas savnet mest. Derfor høyt oppe, og uten å måtte trykkes.
                    if let r = d.rad, !r.isEmpty { Raadkort(rad: r) }
                    if let f = d.fremgang, !f.isEmpty { Fremgangskort(fremgang: f) }

                    if let l = d.lop {
                        NavigationLink { LopSkjerm(lop: l, okter: d.okter ?? []) }
                            label: { Lopkort(lop: l, uke: d.uke) }
                            .buttonStyle(Trykkflate())
                            .id(Treningsmål.lop.anker)
                    }
                    if let s = d.styrke {
                        NavigationLink { StyrkeSkjerm(styrke: s, rad: d.rad ?? [],
                                                          rekorder: d.rekorder ?? [],
                                                          okter: d.okter ?? []) }
                            label: { Styrkekort(styrke: s, uke: d.uke) }
                            .buttonStyle(Trykkflate())
                            .id(Treningsmål.styrke.anker)
                    }
                    // Energi står etter Løping og Styrke, og før vekt: forbruk er
                    // noe man gjør, vekt er bare en følge av det.
                    if let e = d.energi, e.ut != nil || e.inn != nil {
                        NavigationLink { EnergiSkjerm(energi: e) } label: { Energikort(energi: e) }
                            .buttonStyle(Trykkflate())
                            .id(Treningsmål.energi.anker)
                    }
                    if let v = d.vekt {
                        NavigationLink { VektSkjerm(vekt: v, reisen: d.reisen) }
                            label: { Vektkort(vekt: v) }
                            .buttonStyle(Trykkflate())
                            .id(Treningsmål.vekt.anker)
                    }
                    if let f = d.form, f.sovn != nil || f.hrv != nil || f.hvilepuls != nil {
                        NavigationLink { RestitusjonSkjerm(form: f) } label: { Restitusjonskort(form: f) }
                            .buttonStyle(Trykkflate())
                            .id(Treningsmål.restitusjon.anker)
                    }

                    if let r = d.rekorder, !r.isEmpty { Rekordkort(rekorder: r) }
                    if let m = d.midje, m.cm != nil { Midjekort(midje: m) }
                    if let p = d.protein, p.gram != nil || p.snitt7d != nil { Proteinkort(protein: p) }

                    fotnote
                } else if let f = lager.feil {
                    Label(f, systemImage: "exclamationmark.triangle")
                        .font(.footnote).foregroundStyle(Farge.dempet).padding(.top, 40)
                } else {
                    ProgressView().tint(Farge.dempet).frame(maxWidth: .infinity).padding(.top, 40)
                }
            }
            .padding(16)
        }
        .background(Farge.flate)
        .scrollIndicators(.hidden)
        .navigationTitle("Trening")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Farge.flate, for: .navigationBar)
        // Må vente til dataene finnes: et kort som ikke er bygget ennå, har
        // ingen id å rulle til, og rullingen blir stående og gjøre ingenting.
        .onChange(of: lager.data != nil, initial: true) { _, finnes in
            guard finnes, let m = Testskjerm.treningsrull else { return }
            lenke.scrollTo(m.anker, anchor: .top)
        }
        }
    }

    /// Ferskhet, diskret. Gammelt er grått — ikke rødt, og ikke en feilmelding.
    @ViewBuilder private var fotnote: some View {
        if let t = Trening.klokke(lager.generert) {
            Text(lager.erGammel ? "Data fra kl. \(t)" : "Oppdatert \(t)")
                .font(.system(size: 11)).foregroundStyle(Farge.dempet)
                .frame(maxWidth: .infinity, alignment: .center).padding(.top, 4)
        }
    }
}

/// Kortene på oversikten, som noe å peke på — **ikke** som navigasjonsverdier.
///
/// Den brukes til to ting: `.id()` så CI kan rulle til et bestemt kort, og
/// `-trening <navn>` så CI kan åpne én detaljskjerm direkte. Navigasjonen i appen
/// går gjennom vanlige lukkebaserte `NavigationLink`-er, slik de to andre modulene
/// gjør det. Se `TreningModul` for hvorfor.
enum Treningsmål: Hashable {
    case uke, form, lop, styrke, energi, vekt, restitusjon, reisen
    case okt(String)

    /// Ankeret CI ruller til. Bevisst en **streng**, ikke `Treningsmål` selv: enum-en
    /// het en gang det samme som navigasjonsverdiene, og å blande identitetsrom med
    /// navigasjon i samme hierarki er nøyaktig den slags sammenfall som gjør en feil
    /// vanskelig å se. Her er det bare et navn på et kort.
    var anker: String {
        switch self {
        case .uke: "kort-uke"
        case .form: "kort-form"
        case .lop: "kort-lop"
        case .styrke: "kort-styrke"
        case .energi: "kort-energi"
        case .vekt: "kort-vekt"
        case .restitusjon: "kort-restitusjon"
        case .reisen: "kort-reisen"
        case .okt(let id): "kort-okt-\(id)"
        }
    }
}

// MARK: - i dag

/// Én setning om dagen i dag, øverst. Det er det første øyet treffer, så det skal være
/// det mest handlingsrettede på skjermen — ikke et tall, men hva man kan gjøre nå.
private struct IDagBanner: View {
    let iDag: Treningsdata.IDag

    var body: some View {
        Flate(aktiv: true) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Seksjonstittel(tekst: "I dag")
                    Spacer()
                    if let r = iDag.readiness, let v = Trening.tall(r, desimaler: 0) {
                        Text("Readiness \(v)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Farge.dempet)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background { Capsule().strokeBorder(Farge.strek, lineWidth: 1) }
                    }
                }
                Text(iDag.forslag ?? "")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Farge.tekst)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
        }
    }
}

// MARK: - form

private struct Formkort: View {
    let form: Treningsdata.Form

    var body: some View {
        Flate {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Seksjonstittel(tekst: "Form")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(Farge.dempet)
                }
                if let t = form.treningsstatus {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t.tekst ?? "")
                            .font(.system(size: 24, weight: .light)).foregroundStyle(Farge.tekst)
                        if let f = t.forklaring {
                            Text(f).font(.system(size: 12)).foregroundStyle(Farge.dempet)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                HStack(spacing: 0) {
                    if let v = form.vo2max?.verdi {
                        Tallrute(verdi: Trening.tall(v) ?? "–", etikett: "VO₂max",
                                 pil: retning(v, form.vo2max?.for90d))
                    }
                    if let f = form.fitnessAlder?.verdi {
                        Tallrute(verdi: (Trening.tall(f, desimaler: 0) ?? "–") + " år",
                                 etikett: "Formalder")
                    }
                    if let r = form.readiness?.score {
                        // Nivået sto ALENE som etikett, så «68 / God» ikke sa hva
                        // tallet var. Nivået hører til verdien, ikke til navnet på
                        // målingen — og det brukes ordrett fra kilden.
                        Tallrute(verdi: (Trening.tall(r, desimaler: 0) ?? "–")
                                     + (form.readiness?.niva.map { " · \($0)" } ?? ""),
                                 etikett: "Readiness")
                    }
                }
            }
            .padding(16)
        }
    }

    /// Retningen vises som pil, ikke som farge. Nedover i VO₂max er ikke en katastrofe,
    /// og skal ikke se ut som en.
    private func retning(_ nå: Double, _ før: Double?) -> String? {
        guard let før, abs(nå - før) > 0.05 else { return nil }
        return nå > før ? "arrow.up" : "arrow.down"
    }
}

/// Ett tall med etikett, i en rad med andre. Egen fordi `Nøkkeltall` er venstrestilt
/// og ikke deler bredden likt.
struct Tallrute: View {
    let verdi: String
    let etikett: String
    var pil: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(verdi).font(.system(size: 19, weight: .medium)).foregroundStyle(Farge.tekst)
                if let pil {
                    Image(systemName: pil).font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Farge.dempet)
                }
            }
            Text(etikett).font(.system(size: 10)).foregroundStyle(Farge.dempet)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - råd og fremgang

/// «Hva du kan gjøre bedre». Dette er grunnen til at v2 finnes.
///
/// Ingen farge som dømmer — nøytral flate med aksentfarget ikon. Et råd er en mulighet,
/// ikke en anmerkning.
private struct Raadkort: View {
    let rad: [Treningsdata.Rad]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Seksjonstittel(tekst: "Hva du kan gjøre bedre").padding(.leading, 4)
            ForEach(rad.prefix(4)) { r in
                Flate(radius: Hus.radiusLiten) {
                    HStack(alignment: .top, spacing: 11) {
                        Image(systemName: r.ikon)
                            .font(.system(size: 14))
                            .foregroundStyle(Farge.aksent)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(r.tittel ?? "")
                                .font(.system(size: 14, weight: .semibold)).foregroundStyle(Farge.tekst)
                            if let t = r.tekst {
                                Text(t).font(.system(size: 12)).foregroundStyle(Farge.dempet)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(13)
                }
            }
        }
    }
}

/// Det som går riktig vei. Skjules helt når det ikke finnes noe — «ingen fremgang»
/// skulle vært en dom, og modulen dømmer ikke.
private struct Fremgangskort: View {
    let fremgang: [Treningsdata.Fremgang]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Seksjonstittel(tekst: "Fremgang").padding(.leading, 4)
            ForEach(fremgang) { f in
                HStack(alignment: .top, spacing: 11) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .bold)).foregroundStyle(Farge.ok)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(f.tittel ?? "")
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(Farge.tekst)
                        if let t = f.tekst {
                            Text(t).font(.system(size: 12)).foregroundStyle(Farge.dempet)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 13).padding(.vertical, 9)
                .background {
                    RoundedRectangle(cornerRadius: Hus.radiusLiten, style: .continuous)
                        .fill(Farge.ok.opacity(0.07))
                }
            }
        }
    }
}

// MARK: - løping og styrke

private struct Lopkort: View {
    let lop: Treningsdata.Lop
    let uke: Treningsdata.Uke?

    var body: some View {
        Flate {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Seksjonstittel(tekst: "Løping")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(Farge.dempet)
                }
                HStack(alignment: .bottom, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        if let km = lop.uker?.last?.km, let v = Trening.tall(km) {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(v).font(.system(size: 26, weight: .light)).foregroundStyle(Farge.tekst)
                                Text("km denne uka").font(.system(size: 12)).foregroundStyle(Farge.dempet)
                            }
                        }
                        if let s = Trening.tall(lop.kmSnitt4u) {
                            Text("Snitt 4 uker: \(s) km")
                                .font(.system(size: 11)).foregroundStyle(Farge.dempet)
                        }
                        if let t = lop.prediksjon?["5 km"] {
                            Text("5 km anslått \(t)")
                                .font(.system(size: 11)).foregroundStyle(Farge.dempet)
                        }
                    }
                    Spacer()
                    if let u = lop.uker, u.count > 1 { Minigraf(verdier: u.map { $0.km ?? 0 }) }
                }
            }
            .padding(16)
        }
    }
}

private struct Styrkekort: View {
    let styrke: Treningsdata.Styrke
    let uke: Treningsdata.Uke?

    var body: some View {
        Flate {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Seksjonstittel(tekst: "Styrke")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(Farge.dempet)
                }
                HStack(alignment: .bottom, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        if let n = styrke.uker?.last?.okter {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(n)").font(.system(size: 26, weight: .light))
                                    .foregroundStyle(n > 0 ? Farge.ok : Farge.tekst)
                                if let m = Trening.tall(styrke.malPerUke, desimaler: 0) {
                                    Text("av \(m) denne uka").font(.system(size: 12)).foregroundStyle(Farge.dempet)
                                }
                            }
                        }
                        if let s = Trening.tall(styrke.okterSnitt4u) {
                            Text("Snitt 4 uker: \(s) økter")
                                .font(.system(size: 11)).foregroundStyle(Farge.dempet)
                        }
                    }
                    Spacer()
                    if let u = styrke.uker, u.count > 1 {
                        Minigraf(verdier: u.map { Double($0.okter ?? 0) })
                    }
                }
            }
            .padding(16)
        }
    }
}

/// Liten stolpegraf uten akser. Viser form, ikke verdier — tallene står ved siden av.
struct Minigraf: View {
    let verdier: [Double]
    var farge: Color = Farge.ok

    var body: some View {
        let maks = max(verdier.max() ?? 1, 0.001)
        return HStack(alignment: .bottom, spacing: 2) {
            ForEach(Array(verdier.enumerated()), id: \.offset) { i, v in
                Capsule()
                    .fill(i == verdier.count - 1 ? farge : farge.opacity(0.35))
                    .frame(width: 5, height: max(2, 34 * v / maks))
            }
        }
        .frame(height: 34)
    }
}

// MARK: - restitusjon

private struct Restitusjonskort: View {
    let form: Treningsdata.Form

    var body: some View {
        Flate {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Seksjonstittel(tekst: "Søvn og restitusjon")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(Farge.dempet)
                }
                HStack(spacing: 0) {
                    if let s = form.sovn?.snitt7d {
                        Tallrute(verdi: (Trening.tall(s) ?? "–") + " t", etikett: "Søvn 7 d")
                    }
                    if let h = form.hrv?.snitt7d {
                        Tallrute(verdi: Trening.tall(h, desimaler: 0) ?? "–", etikett: "HRV 7 d")
                    }
                    if let p = form.hvilepuls?.snitt7d {
                        Tallrute(verdi: Trening.tall(p, desimaler: 0) ?? "–", etikett: "Hvilepuls 7 d")
                    }
                }
            }
            .padding(16)
        }
    }
}
