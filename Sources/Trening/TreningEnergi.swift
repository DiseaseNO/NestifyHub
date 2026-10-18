import SwiftUI
import Charts

/// Energi: mat inn og forbrenning ut.
///
/// ⚠️ **Hele visningen er bygget rundt én erkjennelse: matloggen er ufullstendig.**
/// Thomas sier selv at han er dårlig til å registrere mat. Et tall fra en delvis dag
/// er derfor et **gulv**, ikke en sum.
///
/// Tre regler følger av det, og de gjelder overalt her:
/// 1. `komplett: false` skrives «**minst** 1 240 kcal». Uten «minst» ville appen
///    påstått noe den ikke vet.
/// 2. **Aldri inn mot ut som et underskudd på en delvis dag.** Det ville vært et
///    regnestykke med feil fasit, servert som fakta. Tallene står ved siden av
///    hverandre til kilden selv sender `balanse`.
/// 3. **En delvis dag ser nøytral ut.** Ingen advarsel, ingen «du glemte å logge».
///    Logging er valgfritt, og en skjerm som maser blir en skjerm man slutter å åpne.

/// Kortet på oversikten.
struct Energikort: View {
    let energi: Treningsdata.Energi

    var body: some View {
        Flate {
            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    Seksjonstittel(tekst: "Energi")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(Farge.dempet)
                }
                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 9) {
                        HStack(alignment: .top, spacing: 20) {
                            if let s = energi.ut?.iDagSaLangt, let t = s.total {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(Energi.kcal(t) ?? "–")
                                        .font(.system(size: 24, weight: .light))
                                        .foregroundStyle(Farge.tekst)
                                    Text(klokkeslett(s.hentet))
                                        .font(.system(size: 10)).foregroundStyle(Farge.dempet)
                                }
                            }
                            // Mat vises BARE når den finnes, og som et tall ved siden
                            // av — aldri under, og aldri med et minustegn mellom. Et
                            // tomt «0 kcal» ville sett ut som en dag uten mat, ikke
                            // som en dag uten logg.
                            if let i = energi.inn?.iDag, let k = i.kcal {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(Energi.medGulv(k, erGulv: i.erGulv))
                                        .font(.system(size: 24, weight: .light))
                                        .foregroundStyle(Farge.tekst)
                                    Text("mat i dag")
                                        .font(.system(size: 10)).foregroundStyle(Farge.dempet)
                                }
                            }
                        }
                        if let s = energi.ut?.snitt7d, let v = Energi.kcal(s) {
                            Text("Snitt ut 7 dager: \(v)")
                                .font(.system(size: 11)).foregroundStyle(Farge.dempet)
                        }
                    }
                    Spacer(minLength: 8)
                    // Sparkline over AKTIVITET, ikke total. Totalen er dominert av
                    // hvileforbrenning og er nesten den samme hver dag — fjorten like
                    // høye søyler sier ingenting. Aktiviteten er det som varierer, og
                    // det eneste han faktisk styrer.
                    if let dager = energi.ut?.siste14d, dager.count > 1 {
                        Minigraf(verdier: dager.map { $0.aktiv ?? 0 })
                    }
                }
            }
            .padding(16)
        }
    }

    private func klokkeslett(_ iso: String?) -> String {
        guard let t = Trening.klokke(iso) else { return "så langt i dag" }
        return "så langt i dag, kl. \(t)"
    }
}

// MARK: - skjermen

struct EnergiSkjerm: View {
    let energi: Treningsdata.Energi?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let b = energi?.balanse { balanse(b) }
                if let u = energi?.ut { forbrenning(u) }
                if let i = energi?.inn { mat(i) }
                if let t = energi?.kalibrertTdee, let v = t.tdee { tdee(t, v) }
            }
            .padding(16)
        }
        .background(Farge.flate)
        .scrollIndicators(.hidden)
        .navigationTitle("Energi")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Farge.flate, for: .navigationBar)
    }

    /// Balansen finnes bare når kilden har nok komplette dager. Teksten er ferdig
    /// formulert der, og brukes ordrett — appen regner aldri differansen selv.
    @ViewBuilder private func balanse(_ b: Treningsdata.Energi.Balanse) -> some View {
        Energibolk(tittel: "Balanse") {
            if let t = b.tekst {
                Text(t).font(.system(size: 15)).foregroundStyle(Farge.tekst)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 0) {
                if let i = b.innSnitt7d { Tallrute(verdi: Energi.kcal(i) ?? "–", etikett: "Inn, snitt 7 d") }
                if let u = b.utSnitt7d { Tallrute(verdi: Energi.kcal(u) ?? "–", etikett: "Ut, snitt 7 d") }
            }
        }
    }

    @ViewBuilder private func forbrenning(_ u: Treningsdata.Energi.Ut) -> some View {
        Energibolk(tittel: "Forbrenning") {
            HStack(spacing: 0) {
                if let s = u.iDagSaLangt?.total {
                    // Klokkeslettet MÅ stå her. Uten det leses «1 240» mot «snitt 7 d
                    // 2 320» som et stort etterslep — men dagen er ikke over. Tallet
                    // er et gulv, og etiketten må si hvor langt det rekker.
                    Tallrute(verdi: Energi.kcal(s) ?? "–",
                             etikett: Trening.klokke(u.iDagSaLangt?.hentet)
                                 .map { "Så langt, kl. \($0)" } ?? "Så langt i dag")
                }
                if let s = u.snitt7d { Tallrute(verdi: Energi.kcal(s) ?? "–", etikett: "Snitt 7 d") }
                if let s = u.snitt30d { Tallrute(verdi: Energi.kcal(s) ?? "–", etikett: "Snitt 30 d") }
            }
            if let dager = u.siste14d, dager.count > 1 { stolper(dager) }
        }
        // Egen bolk for aktiviteten. I stolpene over ligger den som en tynn topp på
        // en vegg av hvileforbrenning — og det er nettopp aktiviteten som varierer,
        // og det eneste han faktisk styrer. Skal den leses, må den få sin egen skala.
        if let dager = u.siste14d, dager.count > 1,
           dager.contains(where: { ($0.aktiv ?? 0) > 0 }) {
            Energibolk(tittel: "Aktivitet") {
                Chart {
                    ForEach(dager) { dag in
                        if let d = Trening.dato(dag.dato) {
                            BarMark(x: .value("Dato", d, unit: .day),
                                    y: .value("kcal", dag.aktiv ?? 0))
                                .foregroundStyle(Farge.ok.opacity(0.85))
                                .cornerRadius(3)
                        }
                    }
                    if let a = u.aktivSnitt7d {
                        RuleMark(y: .value("Snitt", a))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                            .foregroundStyle(Farge.dempet.opacity(0.7))
                    }
                }
                .chartXAxis { AxisMarks(values: .stride(by: .day, count: 3)) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated)
                        .locale(Trening.norsk))
                        .font(.system(size: 9)).foregroundStyle(Farge.dempet) } }
                .chartYAxis { AxisMarks(position: .trailing) { _ in
                    AxisGridLine().foregroundStyle(Farge.kort2)
                    AxisValueLabel().font(.system(size: 9)).foregroundStyle(Farge.dempet) } }
                .frame(height: 130)
                if let a = u.aktivSnitt7d, let v = Energi.kcal(a) {
                    Text("Stiplet linje er snittet siste 7 dager: \(v)")
                        .font(.system(size: 11)).foregroundStyle(Farge.dempet)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// Hvile og aktivitet stablet, så man ser hvor mye som kommer av trening.
    /// Inn legges oppå som prikker der det finnes — **hule prikker for delvise dager**,
    /// så en halvlogget dag ikke ser ut som en dag med lite mat.
    private func stolper(_ dager: [Treningsdata.Energi.Ut.Dag]) -> some View {
        let inn = Dictionary(uniqueKeysWithValues:
            (energi?.inn?.siste14d ?? []).compactMap { d -> (String, Treningsdata.Energi.Inn.Dag)? in
                guard let dt = d.dato, d.kcal != nil else { return nil }
                return (dt, d)
            })
        return VStack(alignment: .leading, spacing: 8) {
            Chart {
                ForEach(dager) { dag in
                    if let d = Trening.dato(dag.dato) {
                        BarMark(x: .value("Dato", d, unit: .day), y: .value("kcal", dag.hvile ?? 0))
                            .foregroundStyle(Farge.dempet.opacity(0.4))
                        BarMark(x: .value("Dato", d, unit: .day), y: .value("kcal", dag.aktiv ?? 0))
                            .foregroundStyle(Farge.ok.opacity(0.85))
                            .cornerRadius(3)
                    }
                }
                // Mat oppå. Full prikk = ferdig logget dag, hul = gulv.
                ForEach(Array(inn.values)) { dag in
                    if let d = Trening.dato(dag.dato), let k = dag.kcal {
                        PointMark(x: .value("Dato", d, unit: .day), y: .value("Mat", k))
                            .symbol {
                                if dag.erGulv {
                                    Circle().strokeBorder(Farge.aksent, lineWidth: 1.8)
                                        .frame(width: 9, height: 9)
                                } else {
                                    Circle().fill(Farge.aksent)
                                        .frame(width: 9, height: 9)
                                        // Ring i flatefargen så prikken løsner fra stolpen
                                        // den ligger oppå.
                                        .overlay(Circle().strokeBorder(Farge.kort, lineWidth: 2)
                                            .frame(width: 13, height: 13))
                                }
                            }
                    }
                }
            }
            .chartXAxis { AxisMarks(values: .stride(by: .day, count: 3)) { _ in
                AxisValueLabel(format: .dateTime.day().month(.abbreviated).locale(Trening.norsk))
                    .font(.system(size: 9)).foregroundStyle(Farge.dempet) } }
            .chartYAxis { AxisMarks(position: .trailing) { _ in
                AxisGridLine().foregroundStyle(Farge.kort2)
                AxisValueLabel().font(.system(size: 9)).foregroundStyle(Farge.dempet) } }
            .frame(height: 150)

            // Tegnforklaring framfor en setning som beskriver fargene: fargen og
            // navnet står da ved siden av hverandre, og identiteten er aldri
            // bare en farge.
            HStack(spacing: 12) {
                Tegn(farge: Farge.ok.opacity(0.85), tekst: "Aktivitet")
                Tegn(farge: Farge.dempet.opacity(0.4), tekst: "Hvile")
                if !inn.isEmpty { Tegn(farge: Farge.aksent, tekst: "Mat", hul: harGulv(inn)) }
                Spacer()
            }
            Text("Siste 14 dager")
                .font(.system(size: 10)).foregroundStyle(Farge.dempet)
        }
    }

    /// Forklarer den hule prikken bare når det faktisk finnes en delvis dag i
    /// grafen — ellers er det en forklaring på noe man ikke ser.
    private func harGulv(_ inn: [String: Treningsdata.Energi.Inn.Dag]) -> Bool {
        inn.values.contains { $0.erGulv }
    }

    @ViewBuilder private func mat(_ i: Treningsdata.Energi.Inn) -> some View {
        Energibolk(tittel: "Mat") {
            if let d = i.iDag, let k = d.kcal {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(Energi.medGulv(k, erGulv: d.erGulv))
                        .font(.system(size: 26, weight: .light)).foregroundStyle(Farge.tekst)
                    Text("i dag").font(.system(size: 12)).foregroundStyle(Farge.dempet)
                }
                HStack(spacing: 0) {
                    if let p = d.protein { Tallrute(verdi: Energi.gram(p), etikett: "Protein") }
                    if let k = d.karbo { Tallrute(verdi: Energi.gram(k), etikett: "Karbo") }
                    if let f = d.fett { Tallrute(verdi: Energi.gram(f), etikett: "Fett") }
                }
            }
            if let m = i.maltiderIDag, !m.isEmpty {
                ForEach(m) { måltid in
                    HStack(alignment: .top, spacing: 10) {
                        Text(måltid.tid ?? "")
                            .font(.system(size: 11).monospacedDigit()).foregroundStyle(Farge.dempet)
                            .frame(width: 38, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(måltid.maltid ?? "").font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Farge.tekst)
                            if let b = måltid.beskrivelse {
                                Text(b).font(.system(size: 11)).foregroundStyle(Farge.dempet)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer(minLength: 8)
                        if let k = måltid.kcal, let v = Energi.kcal(k) {
                            Text(v).font(.system(size: 12).monospacedDigit())
                                .foregroundStyle(Farge.dempet)
                        }
                    }
                }
            }
            if let s = i.snitt7d, let v = Energi.kcal(s) {
                // Snittet regnes bare på komplette dager — ellers ville det dratt
                // nedover hver gang en dag ikke ble ferdiglogget.
                Text("Snitt 7 dager: \(v) · teller bare ferdig loggede dager")
                    .font(.system(size: 11)).foregroundStyle(Farge.dempet)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder private func tdee(_ t: Treningsdata.Energi.Tdee, _ v: Double) -> some View {
        Energibolk(tittel: "Kalibrert forbruk") {
            Text(Energi.kcal(v) ?? "–")
                .font(.system(size: 26, weight: .light)).foregroundStyle(Farge.tekst)
            if let m = t.metode {
                Text(m).font(.system(size: 12)).foregroundStyle(Farge.dempet)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let f = Trening.kortDato(t.fra), let til = Trening.kortDato(t.til) {
                Text("Basert på \(f) – \(til)")
                    .font(.system(size: 11)).foregroundStyle(Farge.dempet)
            }
        }
    }
}

/// Egen bolk her framfor å dele med detaljskjermene — energi har sitt eget filomfang,
/// og en type kan ikke hete det samme to steder i modulen.
private struct Energibolk<Innhold: View>: View {
    let tittel: String
    @ViewBuilder var innhold: () -> Innhold

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Seksjonstittel(tekst: tittel).padding(.leading, 4)
            Flate {
                VStack(alignment: .leading, spacing: 11) { innhold() }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(15)
            }
        }
    }
}

/// Én rute i tegnforklaringen. Hul variant brukes når grafen inneholder delvise
/// dager, så «hul = ikke ferdig logget» står skrevet et sted.
private struct Tegn: View {
    let farge: Color
    let tekst: String
    var hul = false

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(farge).frame(width: 8, height: 8)
            if hul {
                Circle().strokeBorder(farge, lineWidth: 1.5).frame(width: 8, height: 8)
            }
            Text(hul ? "\(tekst) (hul = delvis)" : tekst)
                .font(.system(size: 10)).foregroundStyle(Farge.dempet)
        }
    }
}

enum Energi {
    /// «2 482 kcal» — med tusenskille, fordi firesifrede kaloritall ellers er tunge
    /// å lese på et blikk.
    static func kcal(_ v: Double?) -> String? {
        guard let v else { return nil }
        let f = NumberFormatter()
        f.locale = Locale(identifier: "nb_NO")
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return (f.string(from: NSNumber(value: v)) ?? "–") + " kcal"
    }

    /// **Den viktigste funksjonen i denne fila.** En delvis logget dag er et gulv,
    /// ikke en sum, og det skal stå i teksten — ikke antydes med en farge eller et ikon.
    static func medGulv(_ v: Double, erGulv: Bool) -> String {
        let t = kcal(v) ?? "–"
        return erGulv ? "minst \(t)" : t
    }

    static func gram(_ v: Double?) -> String {
        (Trening.tall(v, desimaler: 0) ?? "–") + " g"
    }
}
