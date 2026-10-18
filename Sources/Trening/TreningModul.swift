import SwiftUI
import Charts

/// Trening-modulen: én rullbar skjerm, ingen faner.
///
/// Premisset er at **vekta skal stå stille med vilje** — det bygges muskler på
/// vedlikehold. Derfor er vekt aldri hovedtallet. Øverst står det som skal bevege seg:
/// jevn trening, styrke og midje. Skjermen skal kunne leses på tre sekunder, og den skal
/// aldri få noen til å føle at de har mislyktes.
///
/// To regler går igjen overalt:
/// - **Grønn betyr bare «oppnådd», grå betyr «ikke ennå». Rødt brukes ingen steder.**
///   Et manglende tall er en opplysning, ikke en anklage.
/// - **Tekstene kommer ordrett fra kilden.** Appen formulerer aldri sin egen vurdering —
///   da ville to steder sagt noe om det samme, og de ville før eller siden sagt ulike ting.
struct TreningModul: View {
    let api: API
    @State private var lager: TreningLager
    @Environment(\.scenePhase) private var scenefase

    init(api: API) {
        self.api = api
        _lager = State(initialValue: TreningLager(api: api))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let d = lager.data {
                        if let u = d.uke { Ukekort(uke: u) }
                        if let r = d.rekorder, !r.isEmpty { Styrkekort(rekorder: r) }
                        if let m = d.midje, m.cm != nil { Midjekort(midje: m) }
                        if let v = d.vekt { Vektkort(vekt: v) }
                        if let p = d.protein, p.gram != nil || p.snitt7d != nil {
                            Proteinkort(protein: p)
                        }
                        if let k = d.kontekst { Kontekstlinje(kontekst: k) }
                        if let r = d.reisen, let p = r.punkter, p.count > 1 {
                            NavigationLink { Reiseskjerm(reisen: r, vekt: d.vekt) } label: { reiselenke }
                            .buttonStyle(Trykkflate())
                        }
                        fotnote
                    } else if let f = lager.feil {
                        Label(f, systemImage: "exclamationmark.triangle")
                            .font(.footnote).foregroundStyle(Farge.dempet)
                            .padding(.top, 40)
                    } else {
                        ProgressView().tint(Farge.dempet)
                            .frame(maxWidth: .infinity).padding(.top, 40)
                    }
                }
                .padding(16)
            }
            .background(Farge.flate)
            .scrollIndicators(.hidden)
            .navigationTitle("Trening")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Farge.flate, for: .navigationBar)
            .refreshable { await lager.last() }
            // Friskner opp så lenge skjermen er fremme; stopper av seg selv når den
            // forsvinner, fordi oppgaven kanselleres.
            .task { await lager.følg() }
            .onChange(of: scenefase) { _, ny in
                if ny == .active { Task { await lager.last() } }
            }
        }
    }

    private var reiselenke: some View {
        Flate {
            HStack {
                Text("Se hele reisen")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Farge.tekst)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Farge.dempet)
            }
            .padding(16)
        }
    }

    /// Ferskhet, diskret. Gammelt er grått — ikke rødt, og ikke en feilmelding.
    @ViewBuilder private var fotnote: some View {
        if let t = Trening.klokke(lager.generert) {
            Text(lager.erGammel ? "Data fra kl. \(t)" : "Oppdatert \(t)")
                .font(.system(size: 11))
                .foregroundStyle(Farge.svak)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)
        }
    }
}

// MARK: - uka

/// Ukekortet. Størst, øverst, og det eneste kortet som har et budskap.
private struct Ukekort: View {
    let uke: Treningsdata.Uke

    var body: some View {
        Flate(aktiv: uke.godkjent == true) {
            VStack(alignment: .leading, spacing: 14) {
                streak
                prikker
                brikker
                fremdrift
                if let m = uke.mangler, !m.isEmpty {
                    Text(m)                                  // ordrett fra kilden
                        .font(.system(size: 14))
                        .foregroundStyle(Farge.tekst)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let s = Trening.tall(uke.snitt4Uker, desimaler: 1) {
                    Text("Snitt 4 uker: \(s) økter")
                        .font(.system(size: 11))
                        .foregroundStyle(Farge.svak)
                }
            }
            .padding(16)
        }
    }

    private var streak: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(uke.streakUker ?? 0)")
                .font(.system(size: 44, weight: .light).monospacedDigit())
                .foregroundStyle(uke.godkjent == true ? Farge.ok : Farge.tekst)
                .contentTransition(.numericText())
            Text((uke.streakUker ?? 0) == 1 ? "uke på rad" : "uker på rad")
                .font(.system(size: 13))
                .foregroundStyle(Farge.dempet)
            Spacer()
            if uke.godkjent == true {
                // Rolig kvittering, ikke feiring. Uka er i boks; det trenger ikke
                // markeres med noe som krever oppmerksomhet.
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Farge.ok)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.smooth(duration: 0.4), value: uke.godkjent)
    }

    /// De siste åtte ukene. Inneværende uke er en åpen ring som fylles når den godkjennes.
    ///
    /// Kilden sender bare lengden på streaken, ikke hvilke uker som var godkjent. Vi
    /// tegner derfor streaken bakover fra inneværende uke — det er det tallet faktisk
    /// betyr, og å gjette på noe mer ville vært å finne på historikk.
    private var prikker: some View {
        let streak = max(0, uke.streakUker ?? 0)
        return HStack(spacing: 6) {
            ForEach(0..<8, id: \.self) { i in
                let uketall = 7 - i                 // 0 = inneværende
                let erNå = uketall == 0
                let fylt = erNå ? (uke.godkjent == true) : uketall <= streak
                Circle()
                    .strokeBorder(fylt ? Color.clear : Farge.strek, lineWidth: 1.5)
                    .background(Circle().fill(fylt ? Farge.ok : Color.clear))
                    .frame(width: 9, height: 9)
                    .opacity(erNå && !fylt ? 1 : (fylt ? 1 : 0.6))
            }
        }
    }

    private var brikker: some View {
        HStack(spacing: 8) {
            Brikke(ikon: "figure.strengthtraining.traditional", navn: "Styrke", antall: uke.styrke ?? 0)
            Brikke(ikon: "figure.run", navn: "Løp", antall: uke.lop ?? 0)
            if let a = uke.annet, a > 0 {
                Brikke(ikon: "figure.mixed.cardio", navn: "Annet", antall: a)
            }
        }
    }

    /// Tre segmenter — én per planlagt økt. En delt linje gjør «1 av 3» leselig uten å
    /// lese tallet.
    private var fremdrift: some View {
        let gjort = uke.okter?.gjort ?? 0
        let mal = max(1, uke.okter?.mal ?? 3)
        return VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                ForEach(0..<mal, id: \.self) { i in
                    Capsule()
                        .fill(i < gjort ? Farge.ok : Farge.strek)
                        .frame(height: 5)
                }
            }
            Text("\(gjort) av \(mal) økter denne uka")
                .font(.system(size: 11))
                .foregroundStyle(Farge.dempet)
        }
        .animation(.smooth(duration: 0.35), value: gjort)
    }
}

/// En økttype med antall. Null er **grå med kontur**, aldri rød — det er noe som ikke er
/// gjort ennå, ikke noe som er galt.
private struct Brikke: View {
    let ikon: String
    let navn: String
    let antall: Int

    private var oppnådd: Bool { antall > 0 }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: ikon).font(.system(size: 11))
            Text(navn).font(.system(size: 12, weight: .medium))
            if oppnådd {
                Text("\(antall)")
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
            }
        }
        .foregroundStyle(oppnådd ? Farge.ok : Farge.svak)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(oppnådd ? Farge.ok.opacity(0.12) : Color.clear)
                .overlay { Capsule().strokeBorder(oppnådd ? Color.clear : Farge.strek, lineWidth: 1) }
        }
    }
}

// MARK: - styrke

private struct Styrkekort: View {
    let rekorder: [Treningsdata.Rekord]

    var body: some View {
        Flate {
            VStack(alignment: .leading, spacing: 12) {
                Seksjonstittel(tekst: "Styrke")
                ForEach(rekorder.prefix(3)) { r in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(tung(r)).font(.system(size: 20, weight: .medium).monospacedDigit())
                                    .foregroundStyle(Farge.tekst)
                                if r.ny == true { nymerke }
                            }
                            if let ø = r.ovelse {
                                Text(ø).font(.system(size: 12)).foregroundStyle(Farge.dempet)
                            }
                        }
                        Spacer()
                        if let d = Trening.kortDato(r.dato) {
                            Text(d).font(.system(size: 11)).foregroundStyle(Farge.svak)
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private func tung(_ r: Treningsdata.Rekord) -> String {
        let kg = Trening.tall(r.kg, desimaler: 1) ?? "–"
        guard let reps = r.reps else { return "\(kg) kg" }
        return "\(kg) kg × \(reps)"
    }

    private var nymerke: some View {
        Text("NY")
            .font(.system(size: 9, weight: .bold)).tracking(0.5)
            .foregroundStyle(Farge.ok)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background { Capsule().fill(Farge.ok.opacity(0.15)) }
    }
}

// MARK: - midje

private struct Midjekort: View {
    let midje: Treningsdata.Midje

    var body: some View {
        Flate {
            HStack(alignment: .center, spacing: 14) {
                Nøkkeltall(verdi: Trening.tall(midje.cm, desimaler: 1) ?? "–",
                           enhet: "cm", etikett: "Midje")
                Spacer()
                if let h = midje.historikk, h.count > 1 {
                    // Ingen fargekoding. Nedover er bra, men en graf som er grønn når
                    // den peker ned, er rød når den peker opp — og det skal den ikke være.
                    Chart {
                        ForEach(h) { p in
                            if let d = Trening.dato(p.dato), let v = p.verdi {
                                LineMark(x: .value("Dato", d), y: .value("cm", v))
                                    .interpolationMethod(.monotone)
                                    .foregroundStyle(Farge.dempet)
                            }
                        }
                    }
                    .chartXAxis(.hidden).chartYAxis(.hidden)
                    .chartYScale(domain: .automatic(includesZero: false))
                    .frame(width: 110, height: 38)
                }
            }
            .padding(16)
        }
    }
}

// MARK: - vekt

/// Vekt som **sone**, ikke som kurve mot et mål.
///
/// Det er her hele premisset bor: et tall som står stille er suksess. Derfor ingen linje
/// gjennom punktene (en linje ber om å bli lest som en retning), ingen piler, ingen
/// endring fra i går, og ingen rød farge når en måling faller utenfor båndet — da er den
/// bare en nøytral grå prikk.
private struct Vektkort: View {
    let vekt: Treningsdata.Vekt

    var body: some View {
        Flate {
            VStack(alignment: .leading, spacing: 12) {
                Seksjonstittel(tekst: "Vekt")
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(vekt.dagerISonen ?? 0)")
                        .font(.system(size: 34, weight: .light).monospacedDigit())
                        .foregroundStyle(Farge.ok)
                    Text("dager i sonen")
                        .font(.system(size: 13)).foregroundStyle(Farge.dempet)
                }
                if let p = vekt.siste30d, p.count > 1 { graf(p) }
                HStack(spacing: 12) {
                    if let s = Trening.tall(vekt.snitt14d) {
                        Text("Snitt 14 d: \(s) kg")
                    }
                    if let f = Trening.tall(vekt.sone?.fra), let t = Trening.tall(vekt.sone?.til) {
                        Text("Sone \(f)–\(t)")
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(Farge.svak)
            }
            .padding(16)
        }
    }

    private func graf(_ punkter: [Punkt]) -> some View {
        let fra = vekt.sone?.fra
        let til = vekt.sone?.til
        return Chart {
            if let fra, let til {
                RectangleMark(
                    yStart: .value("Fra", fra),
                    yEnd: .value("Til", til)
                )
                .foregroundStyle(Farge.ok.opacity(0.14))
            }
            ForEach(punkter) { p in
                if let d = Trening.dato(p.dato), let v = p.verdi {
                    PointMark(x: .value("Dato", d), y: .value("kg", v))
                        .symbolSize(28)
                        // Utenfor sonen = nøytral grå. Ikke en advarsel.
                        .foregroundStyle(iSonen(v) ? Farge.ok : Farge.dempet)
                }
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .trailing) { _ in
                AxisValueLabel().font(.system(size: 9)).foregroundStyle(Farge.svak)
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .frame(height: 92)
    }

    private func iSonen(_ v: Double) -> Bool {
        guard let f = vekt.sone?.fra, let t = vekt.sone?.til else { return false }
        return v >= f && v <= t
    }
}

// MARK: - protein

private struct Proteinkort: View {
    let protein: Treningsdata.Protein

    var body: some View {
        Flate {
            HStack(spacing: 16) {
                if let g = protein.gram { ring(g) }
                VStack(alignment: .leading, spacing: 3) {
                    Seksjonstittel(tekst: "Protein i dag")
                    if let g = Trening.tall(protein.gram, desimaler: 0) {
                        Text("\(g) g").font(.system(size: 20, weight: .medium).monospacedDigit())
                            .foregroundStyle(Farge.tekst)
                    }
                    if let f = Trening.tall(protein.mal?.fra, desimaler: 0),
                       let t = Trening.tall(protein.mal?.til, desimaler: 0) {
                        Text("Mål \(f)–\(t) g").font(.system(size: 11)).foregroundStyle(Farge.dempet)
                    }
                    if let s = Trening.tall(protein.snitt7d, desimaler: 0) {
                        Text("Snitt 7 d: \(s) g").font(.system(size: 11)).foregroundStyle(Farge.svak)
                    }
                }
                Spacer()
            }
            .padding(16)
        }
    }

    /// Ringen fylles mot nedre kant av målintervallet. Over øvre kant er også bra — det
    /// finnes ingen tilstand her som skal se ut som en advarsel.
    private func ring(_ gram: Double) -> some View {
        let mål = protein.mal?.fra ?? 0
        let andel = mål > 0 ? min(1, gram / mål) : 0
        let nådd = mål > 0 && gram >= mål
        return ZStack {
            Circle().stroke(Farge.strek, lineWidth: 6)
            Circle()
                .trim(from: 0, to: andel)
                .stroke(nådd ? Farge.ok : Farge.dempet,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if nådd {
                Image(systemName: "checkmark").font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Farge.ok)
            }
        }
        .frame(width: 52, height: 52)
        .animation(.smooth(duration: 0.4), value: andel)
    }
}

// MARK: - kontekst

/// Én linje, uten farger og uten tolkning. Dette er bakgrunn, ikke en vurdering.
private struct Kontekstlinje: View {
    let kontekst: Treningsdata.Kontekst

    var body: some View {
        let deler: [String] = [
            Trening.tall(kontekst.sovnTimer).map { "Søvn \($0) t" },
            Trening.tall(kontekst.hrv, desimaler: 0).map { "HRV \($0)" },
            Trening.tall(kontekst.readiness, desimaler: 0).map { "Readiness \($0)" },
        ].compactMap { $0 }

        return Group {
            if !deler.isEmpty {
                Text(deler.joined(separator: "  ·  "))
                    .font(.system(size: 11))
                    .foregroundStyle(Farge.svak)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 2)
            }
        }
    }
}
