import SwiftUI
import Charts

/// Kortene oversikten er bygget av.
///
/// Ligger samlet og **ikke** private, fordi både oversikten og detaljskjermene bruker
/// dem. Da ser et kort likt ut uansett hvor det dukker opp — formen bestemmes her,
/// innholdet der det hører hjemme.
///
/// Felles regler: grønn betyr bare «oppnådd», grå betyr «ikke ennå», **rødt brukes
/// ingen steder**, og et manglende felt skjuler sin egen rad framfor å vise en null.

// MARK: - uka

/// Ukekortet. Størst, øverst, og det eneste kortet som har et budskap.
///
/// ⚠️ **Hvert felt kan mangle, og det betyr «vet ikke» — ikke null.** Kilden utelater
/// tall for uker den ikke har fullstendige data for, nettopp sånn at et hull i
/// importen ikke skal se ut som «trente ikke». Derfor står det ingen `?? 0` her: et
/// manglende felt skjuler sin egen rad i stedet for å vise en null som ser ut som
/// et resultat.
///
/// I ytterste fall kommer bare uketallet og siste økt. Da viser kortet det — og det
/// er bedre enn et tomt kort, fordi begge deler er sanne.
struct Ukekort: View {
    let uke: Treningsdata.Uke

    var body: some View {
        Flate(aktiv: uke.godkjent == true) {
            VStack(alignment: .leading, spacing: 14) {
                // Streak 0 får IKKE være hovedtallet. «0 uker på rad» stort er en
                // fiaskomelding satt med display-skrift. Da viser vi uka i stedet,
                // og lar prikkene vise historikken og `mangler` si hva som skal til.
                // Streaken kommer tilbake som helt så snart den er på minst én.
                if let s = uke.streakUker, s > 0 { streak(s) } else { uketittel }
                if let h = uke.historikk { prikker(h) }
                brikker
                if let g = uke.okter?.gjort, let m = uke.okter?.mal { fremdrift(g, m) }
                if let m = uke.mangler, !m.isEmpty {
                    Text(m)                                  // ordrett fra kilden
                        .font(.system(size: 14))
                        .foregroundStyle(Farge.tekst)
                        .fixedSize(horizontal: false, vertical: true)
                }
                bunnlinje
            }
            .padding(16)
        }
    }

    /// Uketallet. Alltid sant, og det eneste som står igjen når alt annet mangler.
    private var uketittel: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(ukenavn)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Farge.tekst)
            if let p = periode {
                Text(p).font(.system(size: 13)).foregroundStyle(Farge.dempet)
            }
            Spacer()
        }
    }

    private func streak(_ antall: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(antall)")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(uke.godkjent == true ? Farge.ok : Farge.tekst)
                .contentTransition(.numericText())
            Text(antall == 1 ? "uke på rad" : "uker på rad")
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

    /// De 8 fullførte ukene, eldste først, pluss inneværende som åpen ring til høyre.
    ///
    /// Tegnes bare når kilden faktisk sender historikken. Den utledes ikke lenger av
    /// streak-tallet — en utledet tom prikk kunne ikke skille «gikk galt» fra «ingen data».
    private func prikker(_ historikk: [Bool]) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(historikk.suffix(8).enumerated()), id: \.offset) { _, godkjent in
                Circle()
                    .strokeBorder(godkjent ? Color.clear : Farge.strek, lineWidth: 1)
                    .background(Circle().fill(godkjent ? Farge.ok : Color.clear))
                    .frame(width: 9, height: 9)
            }
            // Inneværende uke: åpen ring som fylles når den godkjennes.
            Circle()
                .strokeBorder(uke.godkjent == true ? Color.clear : Farge.dempet, lineWidth: 1.5)
                .background(Circle().fill(uke.godkjent == true ? Farge.ok : Color.clear))
                .frame(width: 9, height: 9)
        }
    }

    /// Brikkene vises bare når kilden har tall. Grå «0» ville sagt «ingen økter»,
    /// og det er noe helt annet enn «vi vet ikke ennå».
    @ViewBuilder private var brikker: some View {
        if uke.styrke != nil || uke.lop != nil {
            HStack(spacing: 8) {
                if let s = uke.styrke {
                    Brikke(ikon: "figure.strengthtraining.traditional", navn: "Styrke", antall: s)
                }
                if let l = uke.lop {
                    Brikke(ikon: "figure.run", navn: "Løp", antall: l)
                }
                if let a = uke.annet, a > 0 {
                    Brikke(ikon: "figure.mixed.cardio", navn: "Annet", antall: a)
                }
            }
        }
    }

    /// Tre segmenter — én per planlagt økt. En delt linje gjør «1 av 3» leselig uten å
    /// lese tallet.
    private func fremdrift(_ gjort: Int, _ mal: Int) -> some View {
        let m = max(1, mal)
        return VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                ForEach(0..<m, id: \.self) { i in
                    Capsule()
                        .fill(i < gjort ? Farge.ok : Farge.strek)
                        .frame(height: 5)
                }
            }
            Text("\(gjort) av \(m) økter denne uka")
                .font(.system(size: 11))
                .foregroundStyle(Farge.dempet)
        }
        .animation(.smooth(duration: 0.35), value: gjort)
    }

    /// Snitt og siste økt. `sist_okt` kommer selv når resten av uka mangler, så den
    /// gjør et ellers tomt kort meningsfullt.
    @ViewBuilder private var bunnlinje: some View {
        let deler: [String] = [
            Trening.tall(uke.snitt4Uker, desimaler: 1).map { "Snitt 4 uker: \($0) økter" },
            Trening.kortDato(uke.sistOkt).map { "Siste økt \($0)" },
        ].compactMap { $0 }
        if !deler.isEmpty {
            Text(deler.joined(separator: "  ·  "))
                .font(.system(size: 11))
                .foregroundStyle(Farge.dempet)
        }
    }

    private var ukenavn: String {
        guard let d = Trening.dato(uke.start) else { return "Denne uka" }
        var k = Calendar(identifier: .iso8601)
        k.locale = Locale(identifier: "nb_NO")
        return "Uke \(k.component(.weekOfYear, from: d))"
    }

    private var periode: String? {
        guard let f = Trening.kortDato(uke.start), let t = Trening.kortDato(uke.slutt) else { return nil }
        return "\(f) – \(t)"
    }
}

/// En økttype med antall. Null er **grå med kontur**, aldri rød — det er noe som ikke er
/// gjort ennå, ikke noe som er galt.
struct Brikke: View {
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
        .foregroundStyle(oppnådd ? Farge.ok : Farge.dempet)
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

struct Rekordkort: View {
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
                            Text(d).font(.system(size: 11)).foregroundStyle(Farge.dempet)
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

struct Midjekort: View {
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
struct Vektkort: View {
    let vekt: Treningsdata.Vekt
    /// Kortet brukes to steder: på oversikten, der det kan trykkes, og øverst på
    /// vektskjermen, der det ikke kan. En vinkel på det siste ville lovet en
    /// skjerm som ikke finnes.
    var pil = true

    var body: some View {
        Flate {
            VStack(alignment: .leading, spacing: 12) {
                // Alle de andre kortene på oversikten har en vinkel som sier at de
                // kan trykkes. Vekt hadde den ikke, og så derfor ut som det eneste
                // kortet som var en blindvei — selv om det ikke er det.
                HStack {
                    Seksjonstittel(tekst: "Vekt")
                    if pil {
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Farge.dempet)
                    }
                }
                if let dager = vekt.dagerISonen {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(dager)")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(Farge.ok)
                        Text(dager == 1 ? "dag i sonen" : "dager i sonen")
                            .font(.system(size: 13)).foregroundStyle(Farge.dempet)
                    }
                }
                if let p = vekt.siste30d, p.count > 1 { graf(p) }
                HStack(spacing: 12) {
                    // X-aksen er skjult — da MÅ tidsrommet stå, ellers vet man ikke
                    // om prikkene dekker en uke eller et år.
                    Text("Siste 30 dager")
                    if let s = Trening.tall(vekt.snitt14d) {
                        Text("Snitt 14 d: \(s) kg")
                    }
                    if let f = Trening.tall(vekt.sone?.fra), let t = Trening.tall(vekt.sone?.til) {
                        Text("Sone \(f)–\(t)")
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(Farge.dempet)
            }
            .padding(16)
        }
    }

    private func graf(_ punkter: [Punkt]) -> some View {
        let fra = vekt.sone?.fra
        let til = vekt.sone?.til
        return Chart {
            if let fra, let til {
                // Dempet felt, ikke en blokk. Sonen er BAKGRUNN — målepunktene er
                // dataene. Første utgave hadde 0,14 og ble en stor mettet flate som
                // tok over kortet; prikkene forsvant i den.
                RectangleMark(yStart: .value("Fra", fra), yEnd: .value("Til", til))
                    .foregroundStyle(Farge.ok.opacity(0.06))
                // Tynne grenselinjer gjør sonen lesbar som et INTERVALL uten at
                // flaten må bære det alene.
                ForEach([fra, til], id: \.self) { kant in
                    RuleMark(y: .value("Sonekant", kant))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                        .foregroundStyle(Farge.ok.opacity(0.35))
                }
            }
            ForEach(punkter) { p in
                if let d = Trening.dato(p.dato), let v = p.verdi {
                    PointMark(x: .value("Dato", d), y: .value("kg", v))
                        .symbolSize(55)
                        // Utenfor sonen = nøytral grå. Ikke en advarsel.
                        .foregroundStyle(iSonen(v) ? Farge.ok : Farge.dempet)
                        // Ring i kortets egen farge, så punktene løsner fra båndet
                        // og fra hverandre der de ligger tett.
                        .symbol { Circle().stroke(Farge.kort, lineWidth: 2)
                            .background(Circle().fill(iSonen(v) ? Farge.ok : Farge.dempet))
                            .frame(width: 9, height: 9) }
                }
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .trailing) { _ in
                AxisValueLabel().font(.system(size: 9)).foregroundStyle(Farge.dempet)
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

struct Proteinkort: View {
    let protein: Treningsdata.Protein

    var body: some View {
        Flate {
            VStack(alignment: .leading, spacing: 10) {
                Seksjonstittel(tekst: "Protein i dag")
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if let g = Trening.tall(protein.gram, desimaler: 0) {
                        Text(g).font(.system(size: 28, weight: .light))
                            .foregroundStyle(Farge.tekst)
                        Text("g").font(.system(size: 13)).foregroundStyle(Farge.dempet)
                    }
                    if nådd { Image(systemName: "checkmark").font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Farge.ok) }
                    Spacer()
                    if let s = Trening.tall(protein.snitt7d, desimaler: 0) {
                        Text("Snitt 7 d: \(s) g").font(.system(size: 11)).foregroundStyle(Farge.dempet)
                    }
                }
                if protein.gram != nil, protein.mal?.fra != nil { meter }
            }
            .padding(16)
        }
    }

    private var nådd: Bool {
        guard let g = protein.gram, let fra = protein.mal?.fra else { return false }
        return g >= fra
    }

    /// Måler, ikke ring.
    ///
    /// Målet er et **intervall** (f.eks. 140–155 g), ikke én terskel — og det kan en
    /// ring ikke vise. På en lineær bane kan intervallet tegnes som et felt, så det
    /// er synlig både hvor man er og hvor stort rommet for «bra nok» er.
    ///
    /// Banen er en lysere tone av samme farge som fyllet, ikke nøytral grå: da leses
    /// tilstanden langs hele bredden, i stedet for at bare den fylte delen betyr noe.
    private var meter: some View {
        let fra = protein.mal?.fra ?? 0
        let til = protein.mal?.til ?? fra
        // Skalaen går litt forbi øvre mål, så «over målet» har et sted å vises.
        let maks = max(til * 1.2, (protein.gram ?? 0) * 1.05, 1)
        return VStack(alignment: .leading, spacing: 5) {
            GeometryReader { g in
                let b = g.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Farge.ok.opacity(0.10))
                    if til > fra {
                        // Målintervallet. Et felt, ikke en strek — «bra nok» er et rom.
                        Capsule().fill(Farge.ok.opacity(0.22))
                            .frame(width: b * CGFloat((til - fra) / maks))
                            .offset(x: b * CGFloat(fra / maks))
                    }
                    Capsule()
                        .fill(nådd ? Farge.ok : Farge.ok.opacity(0.55))
                        .frame(width: b * CGFloat(min(1, (protein.gram ?? 0) / maks)))
                }
            }
            .frame(height: 8)
            if let f = Trening.tall(fra, desimaler: 0), let t = Trening.tall(til, desimaler: 0) {
                Text("Mål \(f)–\(t) g")
                    .font(.system(size: 11)).foregroundStyle(Farge.dempet)
            }
        }
        .animation(.smooth(duration: 0.4), value: protein.gram)
    }
}

// MARK: - kontekst

/// Én linje, uten farger og uten tolkning. Dette er bakgrunn, ikke en vurdering.
struct Kontekstlinje: View {
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
                    .foregroundStyle(Farge.dempet)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 2)
            }
        }
    }
}
