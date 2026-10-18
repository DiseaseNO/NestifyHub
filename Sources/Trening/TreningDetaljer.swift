import SwiftUI
import Charts

/// Detaljskjermene bak hvert kort på oversikten.
///
/// Alle leser, ingen skriver. Felles form: tittel, så det viktigste tallet, så
/// underlaget. Et manglende felt skjuler sin egen del — aldri «–» eller «0».

/// Rammen alle detaljskjermene deler.
private struct Detalj<Innhold: View>: View {
    let tittel: String
    @ViewBuilder var innhold: () -> Innhold

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) { innhold() }
                .padding(16)
        }
        .background(Farge.flate)
        .scrollIndicators(.hidden)
        .navigationTitle(tittel)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Farge.flate, for: .navigationBar)
    }
}

/// Et avsnitt inne i en detaljskjerm.
private struct Treningsbolk<Innhold: View>: View {
    let tittel: String
    @ViewBuilder var innhold: () -> Innhold

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Seksjonstittel(tekst: tittel).padding(.leading, 4)
            Flate {
                VStack(alignment: .leading, spacing: 11) { innhold() }
                    // Uten dette krymper kortet til innholdets bredde, og en bolk med
                    // bare tekst blir smalere enn en med rader. Da ser skjermen ut som
                    // den er satt sammen av biter fra ulike steder.
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(15)
            }
        }
    }
}

/// Etikett og verdi på hver sin side. Tallene står i kolonne, så de får like brede
/// sifre — der hører `monospacedDigit` hjemme.
private struct Rad: View {
    let venstre: String
    let høyre: String
    var under: String?
    var farge: Color = Farge.tekst

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(venstre).font(.system(size: 14)).foregroundStyle(Farge.tekst)
                if let under {
                    Text(under).font(.system(size: 11)).foregroundStyle(Farge.dempet)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            Text(høyre)
                .font(.system(size: 15, weight: .medium).monospacedDigit())
                .foregroundStyle(farge)
        }
    }
}

/// Én økt i en liste. Trykk åpner detaljene.
private struct Øktrad: View {
    let økt: Treningsdata.Okt

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: økt.ikon).font(.system(size: 13))
                .foregroundStyle(Farge.dempet).frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(økt.typeTekst ?? økt.navn ?? "Økt")
                    .font(.system(size: 14)).foregroundStyle(Farge.tekst)
                Text(underlinje).font(.system(size: 11)).foregroundStyle(Farge.dempet)
            }
            Spacer(minLength: 8)
            if let d = Trening.kortDato(økt.dato) {
                Text(d).font(.system(size: 11)).foregroundStyle(Farge.dempet)
            }
            Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Farge.strek)
        }
    }

    private var underlinje: String {
        var d: [String] = []
        if let km = økt.km, km > 0, let v = Trening.tall(km) { d.append("\(v) km") }
        if let m = økt.varighetMin, let v = Trening.tall(m, desimaler: 0) { d.append("\(v) min") }
        if let t = økt.tempo, økt.km ?? 0 > 0 { d.append(t) }
        return d.joined(separator: "  ·  ")
    }
}

// MARK: - uke

struct UkeSkjerm: View {
    let uke: Treningsdata.Uke?
    let okter: [Treningsdata.Okt]

    var body: some View {
        Detalj(tittel: "Uka") {
            if let u = uke { Ukekort(uke: u) }
            let ukas = okter.filter { innenfor($0.dato) }
            if !ukas.isEmpty {
                Treningsbolk(tittel: "Øktene denne uka") {
                    ForEach(ukas) { ø in
                        NavigationLink(value: Treningsmål.okt(ø.id ?? "")) { Øktrad(økt: ø) }
                            .buttonStyle(Trykkflate())
                    }
                }
            }
            if let h = uke?.historikk, !h.isEmpty {
                Treningsbolk(tittel: "8 uker tilbake") {
                    // Eldste først, som kilden sender dem.
                    ForEach(Array(h.enumerated()), id: \.offset) { i, godkjent in
                        Rad(venstre: "For \(h.count - i) uker siden",
                            høyre: godkjent ? "godkjent" : "ikke godkjent",
                            farge: godkjent ? Farge.ok : Farge.dempet)
                    }
                }
            }
        }
    }

    /// Øktene i uka kildens `start`–`slutt` dekker. Sammenligner som tekst, siden
    /// begge er rene kalenderdatoer i samme format.
    private func innenfor(_ dato: String?) -> Bool {
        guard let dato, let f = uke?.start, let t = uke?.slutt else { return false }
        return dato >= f && dato <= t
    }
}

// MARK: - form

struct FormSkjerm: View {
    let form: Treningsdata.Form?

    var body: some View {
        Detalj(tittel: "Form") {
            if let t = form?.treningsstatus {
                Treningsbolk(tittel: "Treningsstatus") {
                    Text(t.tekst ?? "").font(.system(size: 22, weight: .light))
                        .foregroundStyle(Farge.tekst)
                    if let f = t.forklaring {
                        Text(f).font(.system(size: 13)).foregroundStyle(Farge.dempet)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if let v = form?.vo2max { vo2(v) }
            if let f = form?.fitnessAlder, let verdi = f.verdi {
                Treningsbolk(tittel: "Formalder") {
                    Rad(venstre: "Nå", høyre: (Trening.tall(verdi) ?? "–") + " år", farge: Farge.ok)
                    if let a = f.alder {
                        Rad(venstre: "Faktisk alder", høyre: (Trening.tall(a, desimaler: 0) ?? "–") + " år")
                    }
                    if let o = f.oppnaelig {
                        Rad(venstre: "Oppnåelig", høyre: (Trening.tall(o) ?? "–") + " år",
                            under: "Det laveste klokka anslår som mulig for deg")
                    }
                }
            }
            if let b = form?.belastning {
                Treningsbolk(tittel: "Belastning") {
                    if let v = b.vurdering {
                        Text(v).font(.system(size: 13)).foregroundStyle(Farge.tekst)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let a = b.akutt { Rad(venstre: "Akutt (7 dager)", høyre: Trening.tall(a, desimaler: 0) ?? "–") }
                    if let k = b.kronisk { Rad(venstre: "Kronisk (28 dager)", høyre: Trening.tall(k, desimaler: 0) ?? "–") }
                    if let c = b.acwr {
                        Rad(venstre: "Forholdstall", høyre: Trening.tall(c, desimaler: 2) ?? "–",
                            under: "Akutt delt på kronisk")
                    }
                }
            }
            if let t = form?.terskel, t.tempo != nil || t.puls != nil {
                Treningsbolk(tittel: "Terskel") {
                    if let p = t.tempo { Rad(venstre: "Tempo", høyre: p + " /km") }
                    if let p = t.puls { Rad(venstre: "Puls", høyre: (Trening.tall(p, desimaler: 0) ?? "–") + " slag") }
                }
            }
        }
    }

    @ViewBuilder private func vo2(_ v: Treningsdata.Form.Vo2max) -> some View {
        Treningsbolk(tittel: "VO₂max") {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(Trening.tall(v.verdi) ?? "–")
                    .font(.system(size: 30, weight: .light)).foregroundStyle(Farge.tekst)
                if let f = v.for90d, let n = v.verdi, abs(n - f) > 0.05 {
                    // Retning som pil, ikke farge. Nedover er ikke en katastrofe.
                    Label(Trening.tall(abs(n - f)) ?? "", systemImage: n > f ? "arrow.up" : "arrow.down")
                        .font(.system(size: 11)).foregroundStyle(n > f ? Farge.ok : Farge.dempet)
                    Text("siste 90 dager").font(.system(size: 11)).foregroundStyle(Farge.dempet)
                }
            }
            if let h = v.historikk, h.count > 1 {
                Chart {
                    ForEach(h) { m in
                        if let d = Trening.dato((m.mnd ?? "") + "-01"), let y = m.verdi {
                            LineMark(x: .value("Måned", d), y: .value("VO₂max", y))
                                .interpolationMethod(.monotone)
                                .foregroundStyle(Farge.aksent)
                                .lineStyle(StrokeStyle(lineWidth: 2))
                        }
                    }
                    if let t = v.topp, let d = Trening.dato(t.dato), let y = t.verdi {
                        PointMark(x: .value("Topp", d), y: .value("VO₂max", y))
                            .symbolSize(70).foregroundStyle(Farge.ok)
                        RuleMark(y: .value("Topp", y))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                            .foregroundStyle(Farge.ok.opacity(0.35))
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .chartXAxis { AxisMarks(values: .stride(by: .year)) { _ in
                    AxisValueLabel(format: .dateTime.year())
                        .font(.system(size: 9)).foregroundStyle(Farge.dempet) } }
                .chartYAxis { AxisMarks(position: .trailing) { _ in
                    AxisValueLabel().font(.system(size: 9)).foregroundStyle(Farge.dempet) } }
                .frame(height: 130)
            }
            if let t = v.topp, let d = Trening.kortDato(t.dato), let y = Trening.tall(t.verdi) {
                Text("Høyeste målt: \(y) — \(d)")
                    .font(.system(size: 11)).foregroundStyle(Farge.dempet)
            }
        }
    }
}

// MARK: - løping

struct LopSkjerm: View {
    let lop: Treningsdata.Lop?
    let okter: [Treningsdata.Okt]

    var body: some View {
        Detalj(tittel: "Løping") {
            if let u = lop?.uker, !u.isEmpty {
                Treningsbolk(tittel: "12 uker") {
                    Chart(u) { uke in
                        if let d = Trening.dato(uke.start) {
                            BarMark(x: .value("Uke", d, unit: .weekOfYear),
                                    y: .value("km", uke.km ?? 0))
                                .foregroundStyle(Farge.ok.opacity(0.8))
                                .cornerRadius(3)
                        }
                    }
                    .chartXAxis { AxisMarks(values: .stride(by: .month)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                            .font(.system(size: 9)).foregroundStyle(Farge.dempet) } }
                    .chartYAxis { AxisMarks(position: .trailing) { _ in
                        AxisValueLabel().font(.system(size: 9)).foregroundStyle(Farge.dempet) } }
                    .frame(height: 120)
                    if let s = Trening.tall(lop?.kmSnitt4u) {
                        Text("Snitt siste 4 uker: \(s) km").font(.system(size: 11))
                            .foregroundStyle(Farge.dempet)
                    }
                }
            }
            if let p = lop?.prediksjon, !p.isEmpty {
                Treningsbolk(tittel: "Anslåtte tider") {
                    // Fast rekkefølge: JSON-objekter har ingen garantert orden, og en
                    // liste som bytter rekkefølge mellom hentinger er uleselig.
                    ForEach(["5 km", "10 km", "Halvmaraton", "Maraton"], id: \.self) { d in
                        if let t = p[d] { Rad(venstre: d, høyre: t) }
                    }
                    if let d = Trening.kortDato(lop?.prediksjonDato) {
                        Text("Anslag fra klokka, \(d)").font(.system(size: 11))
                            .foregroundStyle(Farge.dempet)
                    }
                }
            }
            if let r = lop?.rekorder, !r.isEmpty {
                Treningsbolk(tittel: "Personlige rekorder") {
                    ForEach(r) { rek in
                        Rad(venstre: rek.distanse ?? (Trening.tall(rek.km).map { "\($0) km" } ?? "—"),
                            høyre: rek.tid ?? "—",
                            under: Trening.kortDato(rek.dato).map { "satt \($0)" })
                    }
                }
            }
            if let l = lop?.lengste30d {
                Treningsbolk(tittel: "Lengste siste 30 dager") {
                    NavigationLink(value: Treningsmål.okt(l.id ?? "")) { Øktrad(økt: l) }
                        .buttonStyle(Trykkflate())
                }
            }
            let turer = okter.filter { $0.erLop }
            if !turer.isEmpty {
                Treningsbolk(tittel: "Løpeturer") {
                    ForEach(turer.prefix(20)) { ø in
                        NavigationLink(value: Treningsmål.okt(ø.id ?? "")) { Øktrad(økt: ø) }
                            .buttonStyle(Trykkflate())
                    }
                }
            }
        }
    }
}

// MARK: - styrke

struct StyrkeSkjerm: View {
    let styrke: Treningsdata.Styrke?
    let rad: [Treningsdata.Rad]
    let rekorder: [Treningsdata.Rekord]
    let okter: [Treningsdata.Okt]

    var body: some View {
        Detalj(tittel: "Styrke") {
            if let u = styrke?.uker, !u.isEmpty {
                Treningsbolk(tittel: "12 uker") {
                    Chart {
                        ForEach(u) { uke in
                            if let d = Trening.dato(uke.start) {
                                BarMark(x: .value("Uke", d, unit: .weekOfYear),
                                        y: .value("Økter", uke.okter ?? 0))
                                    .foregroundStyle(Farge.ok.opacity(0.8))
                                    .cornerRadius(3)
                            }
                        }
                        if let m = styrke?.malPerUke {
                            // Mållinje, ikke en terskel som dømmer — stiplet og dempet.
                            RuleMark(y: .value("Mål", m))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                .foregroundStyle(Farge.dempet.opacity(0.7))
                        }
                    }
                    .chartXAxis { AxisMarks(values: .stride(by: .month)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                            .font(.system(size: 9)).foregroundStyle(Farge.dempet) } }
                    .chartYAxis { AxisMarks(position: .trailing) { _ in
                        AxisValueLabel().font(.system(size: 9)).foregroundStyle(Farge.dempet) } }
                    .frame(height: 120)
                    if let m = Trening.tall(styrke?.malPerUke, desimaler: 0),
                       let s = Trening.tall(styrke?.okterSnitt4u) {
                        Text("Mål \(m) i uka · snitt siste 4 uker: \(s)")
                            .font(.system(size: 11)).foregroundStyle(Farge.dempet)
                    }
                }
            }
            if !rekorder.isEmpty {
                Treningsbolk(tittel: "Rekorder") { Rekordkort(rekorder: rekorder) }
            } else if let r = rad.first(where: { $0.kategori == "styrke" }) {
                // Ingen rekorder er ikke en feil — klokka registrerer ikke øvelsene.
                // Forklaringen finnes allerede ferdig formulert i rådene; vi gjenbruker
                // den framfor å skrive vår egen versjon av samme beskjed.
                Treningsbolk(tittel: "Hvorfor ingen rekorder?") {
                    Text(r.tekst ?? "").font(.system(size: 13)).foregroundStyle(Farge.tekst)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            let økter = okter.filter { $0.erStyrke }
            if !økter.isEmpty {
                Treningsbolk(tittel: "Styrkeøkter") {
                    ForEach(økter.prefix(20)) { ø in
                        NavigationLink(value: Treningsmål.okt(ø.id ?? "")) { Øktrad(økt: ø) }
                            .buttonStyle(Trykkflate())
                    }
                }
            }
        }
    }
}

// MARK: - restitusjon

struct RestitusjonSkjerm: View {
    let form: Treningsdata.Form?

    var body: some View {
        Detalj(tittel: "Søvn og restitusjon") {
            if let s = form?.sovn { sovn(s) }
            if let h = form?.hrv { hrv(h) }
            if let p = form?.hvilepuls, p.snitt7d != nil || p.snitt90d != nil {
                Treningsbolk(tittel: "Hvilepuls") {
                    if let v = p.snitt7d { Rad(venstre: "Siste 7 dager", høyre: (Trening.tall(v, desimaler: 0) ?? "–") + " slag") }
                    if let v = p.snitt90d { Rad(venstre: "Siste 90 dager", høyre: (Trening.tall(v, desimaler: 0) ?? "–") + " slag") }
                }
            }
        }
    }

    @ViewBuilder private func sovn(_ s: Treningsdata.Form.Sovn) -> some View {
        Treningsbolk(tittel: "Søvn") {
            HStack(spacing: 0) {
                if let v = s.snitt7d { Tallrute(verdi: (Trening.tall(v) ?? "–") + " t", etikett: "Snitt 7 d") }
                if let v = s.snitt30d { Tallrute(verdi: (Trening.tall(v) ?? "–") + " t", etikett: "Snitt 30 d") }
            }
            if let n = s.siste30d, n.count > 1 {
                Chart {
                    ForEach(n) { natt in
                        if let d = Trening.dato(natt.dato), let t = natt.timer {
                            BarMark(x: .value("Dato", d, unit: .day), y: .value("Timer", t))
                                // Grønn når målet er nådd, grå ellers. Aldri rødt.
                                .foregroundStyle(t >= 7 ? Farge.ok.opacity(0.85) : Farge.dempet.opacity(0.55))
                                .cornerRadius(2)
                        }
                    }
                    RuleMark(y: .value("Mål", 7))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(Farge.dempet.opacity(0.7))
                }
                .chartXAxis(.hidden)
                .chartYAxis { AxisMarks(position: .trailing) { _ in
                    AxisValueLabel().font(.system(size: 9)).foregroundStyle(Farge.dempet) } }
                .frame(height: 110)
                Text("Siste 30 dager · stiplet linje er 7 timer")
                    .font(.system(size: 11)).foregroundStyle(Farge.dempet)
            }
        }
    }

    @ViewBuilder private func hrv(_ h: Treningsdata.Form.Hrv) -> some View {
        Treningsbolk(tittel: "HRV") {
            HStack(spacing: 0) {
                if let v = h.snitt7d { Tallrute(verdi: Trening.tall(v, desimaler: 0) ?? "–", etikett: "Snitt 7 d") }
                if let v = h.snitt30d { Tallrute(verdi: Trening.tall(v, desimaler: 0) ?? "–", etikett: "Snitt 30 d") }
            }
            if let m = h.siste30d, m.count > 1 {
                Chart(m) { måling in
                    if let d = Trening.dato(måling.dato), let v = måling.ms {
                        LineMark(x: .value("Dato", d), y: .value("ms", v))
                            .interpolationMethod(.monotone)
                            .foregroundStyle(Farge.aksent)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
                .chartXAxis(.hidden)
                .chartYScale(domain: .automatic(includesZero: false))
                .chartYAxis { AxisMarks(position: .trailing) { _ in
                    AxisValueLabel().font(.system(size: 9)).foregroundStyle(Farge.dempet) } }
                .frame(height: 100)
                Text("Siste 30 dager").font(.system(size: 11)).foregroundStyle(Farge.dempet)
            }
        }
    }
}

// MARK: - vekt

struct VektSkjerm: View {
    let vekt: Treningsdata.Vekt?
    let reisen: Treningsdata.Reisen?

    var body: some View {
        Detalj(tittel: "Vekt") {
            if let v = vekt { Vektkort(vekt: v) }
            if let r = reisen, let p = r.punkter, p.count > 1 {
                NavigationLink(value: Treningsmål.reisen) {
                    Flate {
                        HStack {
                            Text("Se hele reisen").font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Farge.tekst)
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Farge.dempet)
                        }
                        .padding(16)
                    }
                }
                .buttonStyle(Trykkflate())
            }
        }
    }
}

// MARK: - én økt

struct ØktSkjerm: View {
    let økt: Treningsdata.Okt?

    var body: some View {
        Detalj(tittel: økt?.typeTekst ?? "Økt") {
            if let ø = økt {
                Treningsbolk(tittel: "Økten") {
                    if let n = ø.navn {
                        Text(n).font(.system(size: 18, weight: .light)).foregroundStyle(Farge.tekst)
                    }
                    if let d = Trening.kortDato(ø.dato) {
                        Rad(venstre: "Dato", høyre: d + (ø.start.map { " kl. \($0)" } ?? ""))
                    }
                    if let m = ø.varighetMin, let v = Trening.tall(m, desimaler: 0) {
                        Rad(venstre: "Varighet", høyre: "\(v) min")
                    }
                    if let km = ø.km, km > 0, let v = Trening.tall(km) {
                        Rad(venstre: "Distanse", høyre: "\(v) km")
                    }
                    if let t = ø.tempo, ø.km ?? 0 > 0 { Rad(venstre: "Tempo", høyre: "\(t) /km") }
                }
                if ø.snittpuls != nil || ø.makspuls != nil || ø.kcal != nil || ø.hoydemeter != nil {
                    Treningsbolk(tittel: "Underveis") {
                        if let p = ø.snittpuls { Rad(venstre: "Snittpuls", høyre: (Trening.tall(p, desimaler: 0) ?? "–") + " slag") }
                        if let p = ø.makspuls { Rad(venstre: "Makspuls", høyre: (Trening.tall(p, desimaler: 0) ?? "–") + " slag") }
                        if let k = ø.kcal { Rad(venstre: "Forbrenning", høyre: (Trening.tall(k, desimaler: 0) ?? "–") + " kcal") }
                        if let h = ø.hoydemeter, h > 0 { Rad(venstre: "Høydemeter", høyre: (Trening.tall(h, desimaler: 0) ?? "–") + " m") }
                    }
                }
                if ø.aerobTe != nil || ø.anaerobTe != nil || ø.treningslast != nil {
                    Treningsbolk(tittel: "Effekt") {
                        if let a = ø.aerobTe, a > 0 {
                            Rad(venstre: "Aerob", høyre: Trening.tall(a) ?? "–",
                                under: "Hvor mye økten bygget utholdenhet")
                        }
                        if let a = ø.anaerobTe, a > 0 {
                            Rad(venstre: "Anaerob", høyre: Trening.tall(a) ?? "–",
                                under: "Hvor mye den bygget fart")
                        }
                        if let l = ø.treningslast {
                            Rad(venstre: "Treningslast", høyre: Trening.tall(l, desimaler: 0) ?? "–")
                        }
                    }
                }
            }
        }
    }
}
