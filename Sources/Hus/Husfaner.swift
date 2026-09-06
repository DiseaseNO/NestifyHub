import SwiftUI

// MARK: - Modeller

/// Bilene. `online` og `sover` er med fordi resten av tallene ikke betyr noe uten dem:
/// en bil som sover rapporterer sist kjente verdi, ikke nåværende.
struct Bil: Decodable, Identifiable {
    let navn: String
    let batteri: Int?
    let rekkevidde: Double?
    let ladegrense: Int?
    let lader: Bool
    let plugget: Bool
    let ladeeffekt: Double?
    let ladet_ferdig: String?
    let laast: Bool
    let online: Bool
    let sover: Bool
    let hjemme: Bool
    let klima_paa: Bool
    let temp_inne: Double?
    let odometer: Double?
    var id: String { navn }
}

struct Handlesvar: Decodable {
    let antall: Int?
    let varer: [Vare]
    /// Satt når Oda-innloggingen har ryket. Da skal fanen si det, ikke vise en tom liste
    /// som ser ut som «ingenting å handle».
    let feil: String?
    struct Vare: Decodable, Identifiable {
        let navn: String
        let antall: Int
        let pris: Double?
        var id: String { navn }
    }
}

struct Hjemsvar: Decodable {
    let vaer: [Dag]?
    let ute: Double?
    let inne: Double?
    let kalender: [Avtale]
    let hendelser: [Hendelse]
    let soppel: [Tømming]

    struct Dag: Decodable, Identifiable {
        let dato: String
        let kond: String?
        let maks: Double?
        let min: Double?
        let nedbor: Double?
        var id: String { dato }
    }
    struct Avtale: Decodable, Identifiable {
        let start: String
        let slutt: String?
        let tittel: String
        var id: String { start + tittel }
    }
    struct Hendelse: Decodable, Identifiable {
        let tid: String
        let navn: String
        let melding: String
        let domene: String?
        let id: String
    }
    struct Tømming: Decodable, Identifiable {
        let navn: String
        /// `dd/mm/yyyy` fra integrasjonen.
        let dato: String
        var id: String { navn }
    }
}

// MARK: - Bilene

struct Bilfane: View {
    let api: API
    @State private var biler: [Bil] = []
    @State private var feil: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let feil, biler.isEmpty {
                    Label(feil, systemImage: "exclamationmark.triangle")
                        .font(.footnote).foregroundStyle(Farge.avvik)
                }
                ForEach(biler) { b in bilkort(b) }
            }
            .padding(16).padding(.bottom, 24)
        }
        .background(Farge.flate)
        .scrollIndicators(.hidden)
        .refreshable { await hent() }
        .task { await hent() }
    }

    private func bilkort(_ b: Bil) -> some View {
        Flate(aktiv: b.lader) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text(b.navn).font(.title3.weight(.semibold)).foregroundStyle(Farge.tekst)
                    Spacer()
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(b.batteri.map(String.init) ?? "–")
                            .font(.title2.monospacedDigit())
                            .foregroundStyle(batterifarge(b))
                        Text("%").font(.caption2).foregroundStyle(Farge.dempet)
                    }
                }

                // Ladegrensen tegnes inn i stolpen. Uten den ser 80 % ut som «nesten
                // fullt», når det i praksis ER fullt for denne bilen.
                ZStack(alignment: .leading) {
                    Stolpe(andel: Double(b.batteri ?? 0) / 100, farge: batterifarge(b), høyde: 8)
                    if let g = b.ladegrense {
                        GeometryReader { geo in
                            Rectangle()
                                .fill(Farge.tekst.opacity(0.5))
                                .frame(width: 1.5, height: 12)
                                .offset(x: geo.size.width * Double(g) / 100, y: -2)
                        }
                        .frame(height: 8)
                    }
                }
                .padding(.top, 12)

                HStack(spacing: 10) {
                    if let r = b.rekkevidde {
                        Text("\(Int(r)) km").font(.caption.monospacedDigit())
                            .foregroundStyle(Farge.dempet)
                    }
                    if let g = b.ladegrense {
                        Text("grense \(g) %").font(.caption2).foregroundStyle(Farge.svak)
                    }
                    Spacer()
                }
                .padding(.top, 6)

                Divider().background(Farge.strek).padding(.vertical, 11)

                // Tilstand som brikker. En bil har mange små ja/nei, og en liste med
                // «Låst: ja» tar tre ganger plassen uten å si mer.
                HStack(spacing: 7) {
                    if b.lader {
                        brikke(b.ladeeffekt.map { "Lader \(Int($0)) kW" } ?? "Lader",
                               "bolt.fill", Farge.ok)
                    } else if b.plugget {
                        brikke("Plugget i", "powerplug.fill", Farge.dempet)
                    }
                    brikke(b.laast ? "Låst" : "Ulåst", b.laast ? "lock.fill" : "lock.open.fill",
                           b.laast ? Farge.dempet : Farge.varm)
                    if b.klima_paa { brikke("Klima på", "fan.fill", Farge.kjol) }
                    Spacer()
                }

                HStack(spacing: 10) {
                    // «Sover» er ikke en feil — bilen sparer strøm. Men da er tallene
                    // over sist kjente, ikke nåværende, og det skal stå.
                    if b.sover {
                        Label("sover — tallene er sist kjente", systemImage: "moon.zzz.fill")
                    } else if !b.online {
                        Label("ikke tilkoblet", systemImage: "wifi.slash")
                    } else if b.hjemme {
                        Label("hjemme", systemImage: "house.fill")
                    } else {
                        Label("borte", systemImage: "location.fill")
                    }
                    Spacer()
                    if let t = b.temp_inne {
                        Text(String(format: "%.0f° inne", t)).monospacedDigit()
                    }
                }
                .font(.system(size: 10)).foregroundStyle(Farge.svak)
                .padding(.top, 10)
            }
            .padding(14)
        }
    }

    private func batterifarge(_ b: Bil) -> Color {
        guard let p = b.batteri else { return Farge.dempet }
        if b.lader { return Farge.ok }
        return p <= 20 ? Farge.avvik : (p <= 40 ? Farge.varm : Farge.aksent)
    }

    private func brikke(_ tekst: String, _ ikon: String, _ farge: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: ikon).font(.system(size: 9))
            Text(tekst).font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 9).padding(.vertical, 6)
        .background(farge.opacity(0.14)).foregroundStyle(farge)
        .clipShape(Capsule())
    }

    private func hent() async {
        do { biler = try await api.hent([Bil].self, "/api/hus/biler"); feil = nil }
        catch { feil = error.localizedDescription }
    }
}

// MARK: - Hjem: vær, kalender, søppel, handel, hendelser

struct Oversiktfane: View {
    let api: API
    let rekkefølge: [String]
    @State private var svar: Hjemsvar?
    @State private var handel: Handlesvar?
    @State private var feil: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let s = svar {
                    ForEach(rekkefølge, id: \.self) { bolk($0, s) }
                } else if let feil {
                    Label(feil, systemImage: "exclamationmark.triangle")
                        .font(.footnote).foregroundStyle(Farge.avvik)
                } else {
                    ProgressView().tint(Farge.dempet).frame(maxWidth: .infinity).padding(.top, 40)
                }
            }
            .padding(16).padding(.bottom, 24)
        }
        .background(Farge.flate)
        .scrollIndicators(.hidden)
        .refreshable { await hent() }
        .task { await hent() }
    }

    @ViewBuilder
    private func bolk(_ id: String, _ s: Hjemsvar) -> some View {
        switch id {
        case "vaer":      vaerkort(s)
        case "kalender":  kalenderkort(s)
        case "soppel":    soppelkort(s)
        case "handel":    handelkort()
        case "hendelser": hendelseskort(s)
        default:          EmptyView()
        }
    }

    private func vaerkort(_ s: Hjemsvar) -> some View {
        Flate {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Nøkkeltall(verdi: s.ute.map { String(format: "%.0f°", $0) } ?? "–",
                               etikett: "ute", stor: true)
                    Nøkkeltall(verdi: s.inne.map { String(format: "%.1f°", $0) } ?? "–",
                               etikett: "inne")
                    Spacer()
                }
                if let dager = s.vaer, !dager.isEmpty {
                    HStack(spacing: 0) {
                        ForEach(dager.prefix(6)) { d in
                            VStack(spacing: 4) {
                                Text(ukedag(d.dato)).font(.system(size: 10))
                                    .foregroundStyle(Farge.svak)
                                Image(systemName: værikon(d.kond))
                                    .font(.system(size: 15))
                                    .foregroundStyle(Farge.dempet)
                                Text(d.maks.map { String(format: "%.0f°", $0) } ?? "–")
                                    .font(.caption.monospacedDigit()).foregroundStyle(Farge.tekst)
                                Text(d.min.map { String(format: "%.0f°", $0) } ?? "")
                                    .font(.system(size: 10).monospacedDigit())
                                    .foregroundStyle(Farge.svak)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.top, 14)
                }
            }
            .padding(14)
        }
    }

    private func kalenderkort(_ s: Hjemsvar) -> some View {
        Flate {
            VStack(alignment: .leading, spacing: 0) {
                Seksjonstittel(tekst: "Kalender")
                if s.kalender.isEmpty {
                    Text("Ingenting de neste dagene.").font(.caption)
                        .foregroundStyle(Farge.svak).padding(.top, 8)
                }
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(s.kalender.prefix(6)) { a in
                        HStack(alignment: .top, spacing: 10) {
                            Text(kortDato(a.start)).font(.system(size: 11).monospacedDigit())
                                .foregroundStyle(Farge.aksent).frame(width: 52, alignment: .leading)
                            Text(a.tittel).font(.footnote).foregroundStyle(Farge.tekst)
                                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                            Spacer()
                        }
                    }
                }
                .padding(.top, 10)
            }
            .padding(14)
        }
    }

    private func soppelkort(_ s: Hjemsvar) -> some View {
        Flate {
            VStack(alignment: .leading, spacing: 0) {
                Seksjonstittel(tekst: "Søppeltømming")
                VStack(spacing: 7) {
                    // Sortert på hvor nær tømmingen er. Den som kommer først er den man
                    // faktisk trenger å vite om.
                    ForEach(s.soppel.sorted { (dagerTil($0.dato) ?? 999) < (dagerTil($1.dato) ?? 999) }) { t in
                        HStack {
                            Text(t.navn.replacingOccurrences(of: "Min Renovasjon ", with: ""))
                                .font(.footnote).foregroundStyle(Farge.tekst).lineLimit(1)
                            Spacer()
                            if let d = dagerTil(t.dato) {
                                Text(d == 0 ? "i dag" : (d == 1 ? "i morgen" : "om \(d) dager"))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(d <= 1 ? Farge.aksent : Farge.dempet)
                            } else {
                                Text(t.dato).font(.caption).foregroundStyle(Farge.dempet)
                            }
                        }
                    }
                }
                .padding(.top, 10)
            }
            .padding(14)
        }
    }

    private func handelkort() -> some View {
        Flate {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Seksjonstittel(tekst: "Handleliste")
                    Spacer()
                    if let a = handel?.antall {
                        Text("\(a)").font(.system(size: 10).monospacedDigit())
                            .foregroundStyle(a > 0 ? Farge.aksent : Farge.svak)
                    }
                }
                if let f = handel?.feil {
                    // Innloggingen ryker med jevne mellomrom. En tom liste ville sett ut
                    // som «ingenting å handle».
                    Label("Fikk ikke kontakt med butikken: \(f)", systemImage: "exclamationmark.triangle")
                        .font(.caption2).foregroundStyle(Farge.varm).padding(.top, 8)
                } else if (handel?.varer ?? []).isEmpty {
                    Text("Handlelista er tom.").font(.caption)
                        .foregroundStyle(Farge.svak).padding(.top, 8)
                } else {
                    VStack(spacing: 6) {
                        ForEach((handel?.varer ?? []).prefix(8)) { v in
                            HStack {
                                Text(v.navn).font(.footnote).foregroundStyle(Farge.tekst).lineLimit(1)
                                Spacer()
                                if v.antall > 1 {
                                    Text("×\(v.antall)").font(.caption.monospacedDigit())
                                        .foregroundStyle(Farge.dempet)
                                }
                            }
                        }
                    }
                    .padding(.top, 10)
                }
            }
            .padding(14)
        }
    }

    private func hendelseskort(_ s: Hjemsvar) -> some View {
        Flate {
            VStack(alignment: .leading, spacing: 0) {
                Seksjonstittel(tekst: "Siste hendelser")
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(s.hendelser.prefix(10)) { h in
                        HStack(spacing: 9) {
                            Text(klokke(h.tid)).font(.system(size: 10).monospacedDigit())
                                .foregroundStyle(Farge.svak).frame(width: 38, alignment: .leading)
                            Text(h.navn).font(.caption).foregroundStyle(Farge.tekst).lineLimit(1)
                            Spacer(minLength: 6)
                            Text(h.melding).font(.system(size: 10))
                                .foregroundStyle(Farge.dempet).lineLimit(1)
                        }
                    }
                }
                .padding(.top, 10)
            }
            .padding(14)
        }
    }

    private func hent() async {
        do {
            svar = try await api.hent(Hjemsvar.self, "/api/hus/hjem")
            feil = nil
        } catch { feil = error.localizedDescription }
        handel = try? await api.hent(Handlesvar.self, "/api/hus/handel")
    }
}

// MARK: - Småting

/// `dd/mm/yyyy` → dager til. Regnes her, ikke på serveren: det endrer seg ved midnatt,
/// og skal ikke fryses i et svar som caches.
func dagerTil(_ dmy: String) -> Int? {
    let d = dmy.split(separator: "/")
    guard d.count == 3, let dag = Int(d[0]), let mnd = Int(d[1]), let aar = Int(d[2]) else { return nil }
    var k = DateComponents(); k.year = aar; k.month = mnd; k.day = dag
    guard let dato = Calendar.current.date(from: k) else { return nil }
    return Calendar.current.dateComponents([.day],
        from: Calendar.current.startOfDay(for: Date()),
        to: Calendar.current.startOfDay(for: dato)).day
}

private let iso = ISO8601DateFormatter()

func klokke(_ tid: String) -> String {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    guard let d = f.date(from: tid) ?? iso.date(from: tid) else { return "" }
    let ut = DateFormatter()
    ut.locale = Locale(identifier: "nb_NO")   // ikke systemets — appen er norsk
    ut.dateFormat = "HH:mm"
    return ut.string(from: d)
}

func kortDato(_ tid: String) -> String {
    guard let d = iso.date(from: tid) ?? ISO8601DateFormatter().date(from: tid) else { return "" }
    let ut = DateFormatter()
    ut.locale = Locale(identifier: "nb_NO")
    ut.dateFormat = Calendar.current.isDateInToday(d) ? "'i dag'" : "EEE d."
    return ut.string(from: d)
}

func ukedag(_ tid: String) -> String {
    guard let d = iso.date(from: tid) ?? ISO8601DateFormatter().date(from: tid) else { return "" }
    let ut = DateFormatter()
    ut.locale = Locale(identifier: "nb_NO")
    ut.dateFormat = "EEE"
    return ut.string(from: d)
}

/// HA-værsymbol → SF Symbol. Bommer den, er «sky» bedre enn ingenting.
func værikon(_ kond: String?) -> String {
    switch kond ?? "" {
    case "sunny", "clear-night": "sun.max.fill"
    case "partlycloudy": "cloud.sun.fill"
    case "cloudy": "cloud.fill"
    case "rainy", "pouring": "cloud.rain.fill"
    case "snowy", "snowy-rainy": "cloud.snow.fill"
    case "lightning", "lightning-rainy": "cloud.bolt.fill"
    case "fog": "cloud.fog.fill"
    case "windy": "wind"
    default: "cloud"
    }
}

// MARK: - Admin

struct Enhet: Decodable, Identifiable {
    let id: String
    let navn: String
    let rolle: String
    let opprettet: Double?
    let sistBrukt: Double?
}

/// Admin — godkjenning og hva som er koblet til huset.
///
/// **Ikke** en kopi av nettbrettets Admin. Der ligger paring, tilbakekalling og
/// tjeneste-restart bak en PIN, fordi nettbrettet henger på veggen og alle går forbi det.
/// Telefonen er personlig, men den ligger også på bord: å kunne kaste ut andres enheter
/// eller restarte tjenester herfra er en annen risiko enn å se at de finnes. Derfor er
/// enhetslista **skrivebeskyttet** her.
struct Adminfane: View {
    let api: API
    let rekkefølge: [String]
    @State private var enheter: [Enhet] = []
    @State private var feil: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(rekkefølge, id: \.self) { id in
                    switch id {
                    case "godkjenning":
                        // Samme visning som i Oppgaver, med bare godkjenningsbolken.
                        Oppgaverfane(api: api, rekkefølge: ["godkjenning"])
                            .frame(height: godkjenningshøyde)
                    case "enheter":
                        enhetskort
                    default:
                        EmptyView()
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .background(Farge.flate)
        .scrollIndicators(.hidden)
        .refreshable { await hent() }
        .task { await hent() }
    }

    /// Godkjenningsdelen er en egen rullende visning inni denne. Uten en høyde ville den
    /// krympet til ingenting i en `ScrollView`.
    private var godkjenningshøyde: CGFloat { 340 }

    private var enhetskort: some View {
        Flate {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Seksjonstittel(tekst: "Parede enheter")
                    Spacer()
                    Text("\(enheter.count)").font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(Farge.svak)
                }
                if let feil {
                    Label(feil, systemImage: "exclamationmark.triangle")
                        .font(.caption2).foregroundStyle(Farge.avvik).padding(.top, 8)
                }
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(enheter) { e in
                        HStack(spacing: 9) {
                            Image(systemName: ikon(e.rolle)).font(.caption)
                                .foregroundStyle(Farge.dempet).frame(width: 18)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(e.navn).font(.footnote).foregroundStyle(Farge.tekst)
                                Text(beskriv(e)).font(.system(size: 10))
                                    .foregroundStyle(e.rolle == "full" ? Farge.varm : Farge.svak)
                            }
                            Spacer()
                        }
                    }
                }
                .padding(.top, 10)
                Text("Paring og frakobling gjøres fra nettbrettet, bak PIN.")
                    .font(.system(size: 10)).foregroundStyle(Farge.svak).padding(.top, 12)
            }
            .padding(14)
        }
        .padding(.horizontal, 16)
    }

    private func ikon(_ rolle: String) -> String {
        switch rolle {
        case "kamera": "video"
        case "hjemme": "iphone"
        case "ci": "hammer"
        default: "exclamationmark.triangle"
        }
    }

    /// «uten begrensning» skal stå på de som har det. En enhet paret før rollene fantes
    /// kan alt, og det er verdt å se.
    private func beskriv(_ e: Enhet) -> String {
        let rolle = e.rolle == "full" ? "uten begrensning" : e.rolle
        guard let sist = e.sistBrukt else { return "\(rolle) · aldri brukt" }
        let d = Date(timeIntervalSince1970: sist / 1000)
        return "\(rolle) · sist brukt \(varighet(Date().timeIntervalSince(d), kort: true)) siden"
    }

    private func hent() async {
        do { enheter = try await api.hent([Enhet].self, "/api/hus/enheter"); feil = nil }
        catch { feil = error.localizedDescription }
    }
}
