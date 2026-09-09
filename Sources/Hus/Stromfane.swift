import SwiftUI

/// Strøm på telefonen.
///
/// Nettbrettet har hele bildet — kapasitetsledd, historikk to år tilbake, døgnkurve mot
/// pris. Det er en skjerm man står foran. Telefonen tas opp for å svare på ett spørsmål:
/// hva koster det nå, og ligger jeg an til noe uvanlig denne måneden.
///
/// Vi dekoder derfor bare det vi viser. Serveren sender mer, og skal få lov til det.
struct Stromsvar: Decodable {
    let naa: Naa
    let pris: Pris
    let poster: [Post]
    let estimat: Estimat
    /// Kvarterssnitt gjennom døgnet, `null` der vi ikke har målt. Null er ikke det
    /// samme som «ingen måling», og kurven må vise forskjellen.
    let doegnkurve: [Double?]?
    let naa_time: Int?
    let tariff: Tariff?
    /// Månedsforbruk to år bakover — for å se om forbruket endrer seg over tid.
    let maaneder: [Maaned]?
    let maanedsammenligning: Sammenligning?

    struct Sammenligning: Decodable {
        let aar: [Int]
        let inneverende: Naavaerende
        let maaneder: [Rad]
        struct Naavaerende: Decodable { let aar: Int; let maaned: Int }
        struct Rad: Decodable, Identifiable {
            let maaned: Int
            /// Én verdi per år, `null` der vi ikke har tall. En manglende måned og en
            /// måned uten forbruk er ikke det samme.
            let verdier: [Double?]
            var id: Int { maaned }
        }
    }
    /// Like mange dager i år som i fjor, så tallet er sammenlignbart midt i en måned.
    let hittil: Hittil?

    struct Tariff: Decodable {
        let energiledd_naa: Double?
        let er_dagsats: Bool?
        let kapasitet: Kapasitet?
        struct Kapasitet: Decodable {
            /// Snittet av de tre høyeste timene på tre ulike døgn — tariffens regel.
            let snitt_kw: Double?
            let doegn: Int?
            let dager: [Dag]?
            let trinn: Trinn?
            struct Dag: Decodable, Identifiable {
                let dag: Int
                let kw: Double
                let time: Int
                var id: Int { dag }
            }
            struct Trinn: Decodable {
                let fra: Double?
                let til: Double?
                let kr: Double?
                /// Hvor mange kW det er igjen til neste trinn. Det er dette tallet som
                /// avgjør om en ekstra ovn koster 170 kroner ekstra i måneden.
                let margin_kw: Double?
                let neste_kr: Double?
                let kilde: String?
            }
        }
    }
    struct Maaned: Decodable, Identifiable {
        let start: Double
        let kwh: Double
        var id: Double { start }
    }
    struct Hittil: Decodable {
        let dag: Int?
        let i_aar_kwh: Double?
        let i_fjor_kwh: Double?
        let endring: Double?
    }

    struct Naa: Decodable {
        let total_watt: Int?
        let maalt_watt: Int?
        let annet_watt: Int?
        let har_total: Bool
        let fordeling: Fordeling?
        struct Fordeling: Decodable {
            let hoy_w: Double?
            /// Sant når forbruket nå er høyt for DETTE huset — ikke mot en fast grense.
            let er_hoyt: Bool?
        }
    }
    struct Pris: Decodable {
        let kr_per_kwh: Double?
        let kraft: Double?
        let nettleie: Double?
        let spot_alternativ: Double?
        let spart_dag: Double?
        let spart_maaned: Double?
        let spart_totalt: Double?
    }
    struct Post: Decodable, Identifiable {
        let navn: String
        let watt: Double?
        let dag_kwh: Double?
        let kategori: String?
        var id: String { navn }
    }
    struct Estimat: Decodable {
        /// Hele husets forbruk denne måneden, fra nettselskapet. `maalt_*` er
        /// delmengden vi har egen måling på — de to skal ikke blandes i samme setning.
        let maaned_kwh: Double?
        let maaned_kr: Double?
        let maalt_dag_kwh: Double?
        let maalt_dag_kr: Double?
        let maalt_maaned_kwh: Double?
        let maalt_maaned_kr: Double?
        let anslag_maaned_kr: Double?
        let dag_i_maaned: Int?
        let dager_i_maaned: Int?
        let maalt_andel: Double?
    }
}

struct Stromfane: View {
    let api: API
    /// Bolkene i den rekkefølgen brukeren har valgt.
    let rekkefølge: [String]
    @State private var svar: Stromsvar?
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
            .padding(16)
            // Siste rad skal ikke ligge under fanelinja.
            .padding(.bottom, 24)
        }
        .background(Farge.flate)
        .scrollIndicators(.hidden)
        .refreshable { await hent() }
        .task { await hent() }
    }

    @ViewBuilder
    private func bolk(_ id: String, _ s: Stromsvar) -> some View {
        switch id {
        case "naa":     naakort(s)
        case "doegn":
            if let k = s.doegnkurve, k.contains(where: { $0 != nil }) { doegnkort(k, s.naa_time) }
        case "kostnad": kostnad(s)
        case "poster":  poster(s)
        case "maaned":  maanedkort(s)
        case "trend":   trendkort(s)
        case "kapasitet": kapasitetkort(s)
        case "avtale":  avtalekort(s)
        default: EmptyView()
        }
    }

    /// Hittil i måneden — kWt og kroner, med anslag for hele måneden.
    private func maanedkort(_ s: Stromsvar) -> some View {
        Kort {
            Seksjonstittel(tekst: "Hittil i måneden")
            // HELE husets forbruk og HELE husets kostnad — samme grunnlag.
            //
            // Sto før med kWt fra nettselskapet (hele huset) rett ved siden av kroner
            // for bare de målte kursene. 714 kWt og 217 kr ved siden av hverandre er
            // ikke to tall om samme ting, og regnestykket så tullete ut fordi det var det.
            HStack(spacing: 0) {
                tall(s.estimat.maaned_kwh.map { String(format: "%.0f", $0) } ?? "–", "kWt")
                tall(s.estimat.maaned_kr.map { "\(Int($0)) kr" } ?? "–", "så langt")
                tall(s.estimat.anslag_maaned_kr.map { "\(Int($0)) kr" } ?? "–", "hele måneden")
            }
            .padding(.top, 10)
            if let a = s.estimat.maalt_andel, let m = s.estimat.maalt_maaned_kwh {
                Text(String(format: "Vi har egen måling på %.0f kWt av dette (%d %%)",
                            m, Int(a * 100)))
                    .font(.system(size: 10)).foregroundStyle(Farge.svak).padding(.top, 6)
            }
            if let d = s.estimat.dag_i_maaned, let n = s.estimat.dager_i_maaned {
                Stolpe(andel: Double(d) / Double(max(1, n)), høyde: 4).padding(.top, 10)
                Text("dag \(d) av \(n)")
                    .font(.system(size: 10)).foregroundStyle(Farge.svak).padding(.top, 5)
            }
        }
    }

    /// Endrer forbruket seg — i år mot i fjor, på like mange dager.
    @ViewBuilder
    private func trendkort(_ s: Stromsvar) -> some View {
        if let h = s.hittil, let iaar = h.i_aar_kwh, let ifjor = h.i_fjor_kwh {
            let opp = (h.endring ?? 0) > 0
            Kort {
                Seksjonstittel(tekst: "Endrer forbruket seg")
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: opp ? "arrow.up.right" : "arrow.down.right")
                        .font(.footnote).foregroundStyle(opp ? Farge.varm : Farge.ok)
                    Text(String(format: "%.0f %%", abs((h.endring ?? 0) * 100)))
                        .font(.title2.monospacedDigit())
                        .foregroundStyle(opp ? Farge.varm : Farge.ok)
                    Text(opp ? "mer enn i fjor" : "mindre enn i fjor")
                        .font(.caption).foregroundStyle(Farge.dempet)
                }
                .padding(.top, 8)
                HStack(spacing: 0) {
                    tall(String(format: "%.0f", iaar), "kWt i år")
                    tall(String(format: "%.0f", ifjor), "kWt i fjor")
                }
                .padding(.top, 10)
                // Sammenligningen gjelder like mange dager. Uten det ville en halv måned
                // sett ut som et kraftig fall.
                if let d = h.dag {
                    Text("samme antall dager i begge år (\(d))")
                        .font(.system(size: 10)).foregroundStyle(Farge.svak).padding(.top, 6)
                }
                if let sml = s.maanedsammenligning, sml.aar.count > 1 {
                    sammenligningsgraf(sml)
                }
            }
        }
    }

    /// Samme måned, år ved siden av år.
    ///
    /// En flat rekke av 24 måneder viser at forbruket svinger, men ikke om september i år
    /// er høyere enn september i fjor — og det er hele spørsmålet. Her står årene ved
    /// siden av hverandre i hver måned, med hver sin farge.
    private func sammenligningsgraf(_ sml: Stromsvar.Sammenligning) -> some View {
        let maks = sml.maaneder.flatMap { $0.verdier }.compactMap { $0 }.max() ?? 1
        let navn = ["", "jan", "feb", "mar", "apr", "mai", "jun",
                    "jul", "aug", "sep", "okt", "nov", "des"]
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                ForEach(Array(sml.aar.enumerated()), id: \.offset) { i, år in
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(aarsfarge(i, sml.aar.count)).frame(width: 8, height: 8)
                        Text(String(år)).font(.system(size: 10).monospacedDigit())
                            .foregroundStyle(Farge.dempet)
                    }
                }
                Spacer()
            }
            GeometryReader { g in
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(sml.maaneder) { rad in
                        HStack(alignment: .bottom, spacing: 1) {
                            ForEach(Array(rad.verdier.enumerated()), id: \.offset) { i, v in
                                // Tynne stolper: tre år × tolv måneder er 36 stolper på
                                // en telefonbredde, og de må få stå fra hverandre.
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(aarsfarge(i, sml.aar.count)
                                        .opacity(ufullstendig(rad, i, sml) ? 0.45 : 1))
                                    .frame(height: max(1, ((v ?? 0) / maks) * g.size.height))
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .frame(height: 64)
            HStack(spacing: 3) {
                ForEach(sml.maaneder) { rad in
                    Text(navn[rad.maaned]).font(.system(size: 8))
                        .foregroundStyle(Farge.svak).frame(maxWidth: .infinity)
                }
            }
            // Inneværende måned er ikke omme. Uten dette ser en halv september ut som
            // et krakk ved siden av to hele.
            Text("Inneværende måned er ikke ferdig, og står dempet.")
                .font(.system(size: 9)).foregroundStyle(Farge.svak)
        }
        .padding(.top, 14)
    }

    /// Sant for stolpen som representerer måneden vi står i.
    private func ufullstendig(_ rad: Stromsvar.Sammenligning.Rad, _ i: Int,
                              _ sml: Stromsvar.Sammenligning) -> Bool {
        rad.maaned == sml.inneverende.maaned && sml.aar[i] == sml.inneverende.aar
    }

    /// Eldst er svakest, nyest er sterkest — så rekkefølgen kan leses uten forklaring.
    private func aarsfarge(_ i: Int, _ antall: Int) -> Color {
        switch antall - 1 - i {
        case 0: Farge.aksent
        case 1: Farge.kjol
        default: Farge.dempet
        }
    }

    private func maanedsgraf(_ m: [Stromsvar.Maaned]) -> some View {
        let siste = Array(m.suffix(24))
        let maks = siste.map(\.kwh).max() ?? 1
        return VStack(alignment: .leading, spacing: 4) {
            GeometryReader { g in
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(siste) { x in
                        Capsule().fill(Farge.aksent.opacity(0.5))
                            .frame(height: max(2, (x.kwh / maks) * g.size.height))
                    }
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .frame(height: 44)
            Text("måned for måned, to år tilbake")
                .font(.system(size: 10)).foregroundStyle(Farge.svak)
        }
        .padding(.top, 12)
    }

    /// Kapasitetsleddet — nettleiens fastledd.
    ///
    /// Regelen er snittet av de **tre høyeste timene på tre ulike døgn** i kalender-
    /// måneden. Ikke øyeblikkstoppen: det var slik vi regnet feil en gang, og snittet
    /// falt fra 9,2 til 6,4 kW da det ble rettet.
    @ViewBuilder
    private func kapasitetkort(_ s: Stromsvar) -> some View {
        if let k = s.tariff?.kapasitet {
            Kort {
                HStack {
                    Seksjonstittel(tekst: "Kapasitetsledd")
                    Spacer()
                    if let t = k.trinn, let kr = t.kr {
                        Text("\(Int(kr)) kr/mnd").font(.system(size: 10).monospacedDigit())
                            .foregroundStyle(Farge.aksent)
                    }
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(k.snitt_kw.map { String(format: "%.1f", $0) } ?? "–")
                        .font(.system(size: 34, weight: .light).monospacedDigit())
                        .foregroundStyle(Farge.tekst)
                    Text("kW snitt").font(.caption).foregroundStyle(Farge.dempet)
                }
                .padding(.top, 8)
                if let t = k.trinn, let fra = t.fra, let til = t.til, let snitt = k.snitt_kw {
                    Stolpe(andel: (snitt - fra) / max(0.1, til - fra),
                           farge: (t.margin_kw ?? 9) < 1 ? Farge.varm : Farge.aksent, høyde: 6)
                        .padding(.top, 12)
                    HStack {
                        Text(String(format: "%.0f kW", fra)).font(.system(size: 9))
                        Spacer()
                        Text(String(format: "%.0f kW", til)).font(.system(size: 9))
                    }
                    .foregroundStyle(Farge.svak).padding(.top, 4)
                    if let m = t.margin_kw, let neste = t.neste_kr, let kr = t.kr {
                        // Marginen er det som betyr noe: den sier hva en ekstra ovn
                        // faktisk koster.
                        Text(String(format: "%.1f kW igjen til neste trinn (+%d kr/mnd)",
                                    m, Int(neste - kr)))
                            .font(.caption2)
                            .foregroundStyle(m < 1 ? Farge.varm : Farge.dempet)
                            .padding(.top, 8)
                    }
                }
                if let dager = k.dager, !dager.isEmpty {
                    Divider().background(Farge.strek).padding(.vertical, 10)
                    VStack(spacing: 5) {
                        ForEach(dager) { d in
                            HStack {
                                Text("\(d.dag). kl. \(d.time)")
                                    .font(.caption.monospacedDigit()).foregroundStyle(Farge.dempet)
                                Spacer()
                                Text(String(format: "%.2f kW", d.kw))
                                    .font(.caption.monospacedDigit()).foregroundStyle(Farge.tekst)
                            }
                        }
                    }
                    // Tre døgn kreves. Har vi færre, er snittet foreløpig.
                    if (k.doegn ?? 0) < 3 {
                        Text("\(k.doegn ?? 0) av 3 døgn målt — snittet er foreløpig")
                            .font(.system(size: 10)).foregroundStyle(Farge.svak).padding(.top, 8)
                    }
                }
            }
        }
    }

    /// Strømavtalen — hva Norgespris sparer mot spot.
    @ViewBuilder
    private func avtalekort(_ s: Stromsvar) -> some View {
        if s.pris.spart_totalt != nil || s.pris.spot_alternativ != nil {
            Kort {
                Seksjonstittel(tekst: "Strømavtalen din")
                if let n = s.pris.kraft, let spot = s.pris.spot_alternativ {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Norgespris").font(.caption2).foregroundStyle(Farge.dempet)
                            Stolpe(andel: n / max(n, spot), farge: Farge.ok, høyde: 6)
                            Text(String(format: "%.2f kr/kWt", n))
                                .font(.caption.monospacedDigit()).foregroundStyle(Farge.ok)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Spot i dag").font(.caption2).foregroundStyle(Farge.dempet)
                            Stolpe(andel: spot / max(n, spot), farge: Farge.varm, høyde: 6)
                            Text(String(format: "%.2f kr/kWt", spot))
                                .font(.caption.monospacedDigit()).foregroundStyle(Farge.varm)
                        }
                    }
                    .padding(.top, 10)
                }
                HStack(spacing: 0) {
                    tall(s.pris.spart_dag.map { String(format: "%.0f kr", $0) } ?? "–", "spart i dag")
                    tall(s.pris.spart_maaned.map { String(format: "%.0f kr", $0) } ?? "–", "denne mnd")
                    tall(s.pris.spart_totalt.map { String(format: "%.0f kr", $0) } ?? "–", "siden start")
                }
                .padding(.top, 12)
            }
        }
    }

    private func hent() async {
        do { svar = try await api.hent(Stromsvar.self, "/api/hus/strom"); feil = nil }
        catch { feil = error.localizedDescription }
    }

    /// Døgnet som en kurve.
    ///
    /// Et tall for «nå» sier ikke om det er høyt. Formen på døgnet gjør det: man ser
    /// morgentoppen, dagen borte, og hvor man ligger akkurat nå i forhold til resten.
    private func doegnkort(_ kurve: [Double?], _ naaTime: Int?) -> some View {
        let maks = kurve.compactMap { $0 }.max() ?? 1
        return Kort {
            HStack {
                Text("DØGNET").font(.system(size: 10, weight: .semibold)).tracking(0.8)
                    .foregroundStyle(Farge.dempet)
                Spacer()
                Text(String(format: "topp %.1f kW", maks / 1000))
                    .font(.system(size: 10).monospacedDigit()).foregroundStyle(Farge.svak)
            }
            GeometryReader { g in
                let bredde = g.size.width / CGFloat(max(1, kurve.count))
                HStack(alignment: .bottom, spacing: 1) {
                    ForEach(Array(kurve.enumerated()), id: \.offset) { i, v in
                        // Kvarteret vi er i nå, markeres. Uten den er kurven en historie
                        // uten et «du er her».
                        let naa = naaTime.map { i / 4 == $0 } ?? false
                        Capsule()
                            .fill(v == nil ? Farge.kort2
                                  : (naa ? Farge.aksent : Farge.aksent.opacity(0.45)))
                            .frame(width: max(1, bredde - 1),
                                   height: v == nil ? 2 : max(2, (v! / maks) * g.size.height))
                    }
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .frame(height: 56)
            .padding(.top, 10)
            HStack {
                ForEach([0, 6, 12, 18], id: \.self) { t in
                    Text("\(t)").font(.system(size: 9)).foregroundStyle(Farge.svak)
                    if t != 18 { Spacer() }
                }
                Spacer()
                Text("24").font(.system(size: 9)).foregroundStyle(Farge.svak)
            }
            .padding(.top, 4)
        }
    }

    private func naakort(_ s: Stromsvar) -> some View {
        Kort {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                VStack(alignment: .leading, spacing: 1) {
                    // Uten HAN-måler vet vi ikke husets totale forbruk, og da skal
                    // skjermen si det framfor å vise summen av kursene som om den var alt.
                    Text(s.naa.har_total
                         ? (s.naa.total_watt.map { String(format: "%.1f", Double($0) / 1000) } ?? "–")
                         : "–")
                        .font(.system(size: 40, weight: .light).monospacedDigit())
                        .foregroundStyle(Farge.tekst)
                    Text(s.naa.har_total ? "kW akkurat nå" : "ingen måler på hovedinntaket")
                        .font(.caption2).foregroundStyle(Farge.dempet)
                }
                Spacer()
                if let w = s.naa.total_watt, let p = s.pris.kr_per_kwh {
                    // Under en krone leses ører lettere, over leses kroner lettere.
                    let kr = Double(w) / 1000 * p
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(kr < 1 ? String(format: "%.0f", kr * 100)
                                    : String(format: "%.2f", kr))
                            .font(.title3.monospacedDigit()).foregroundStyle(Farge.tekst)
                        Text(kr < 1 ? "øre i timen" : "kroner i timen")
                            .font(.caption2).foregroundStyle(Farge.dempet)
                    }
                }
            }
            // Hvor mye vi FAKTISK måler. Resten er «Annet», og den delen er ikke en
            // feil — den er alt som ikke har egen måler. Men den skal være synlig, ellers
            // ser tallene mer presise ut enn de er.
            if let m = s.naa.maalt_watt, let t = s.naa.total_watt, t > 0 {
                VStack(spacing: 5) {
                    Stolpe(andel: Double(m) / Double(t), høyde: 8)
                    HStack {
                        Label("\(m) W målt", systemImage: "circle.fill")
                            .font(.system(size: 10)).foregroundStyle(Farge.aksent)
                        Spacer()
                        Text("\(s.naa.annet_watt ?? max(0, t - m)) W annet")
                            .font(.system(size: 10)).foregroundStyle(Farge.svak)
                    }
                }
                .padding(.top, 12)
            }
            if s.naa.fordeling?.er_hoyt == true {
                Label("Høyt for dette huset akkurat nå", systemImage: "arrow.up.right")
                    .font(.caption2).foregroundStyle(Farge.varm).padding(.top, 8)
            }
        }
    }

    private func kostnad(_ s: Stromsvar) -> some View {
        Kort {
            Text("KOSTNAD").font(.system(size: 9, weight: .semibold)).foregroundStyle(Farge.dempet)
            HStack(spacing: 0) {
                tall(s.estimat.maalt_dag_kr.map { "\(Int($0)) kr" } ?? "–", "i dag")
                tall(s.estimat.maalt_maaned_kr.map { "\(Int($0)) kr" } ?? "–", "hittil i mnd")
                tall(s.estimat.anslag_maaned_kr.map { "\(Int($0)) kr" } ?? "–", "anslag mnd")
            }
            .padding(.top, 8)
            if let d = s.estimat.dag_i_maaned, let n = s.estimat.dager_i_maaned,
               s.estimat.anslag_maaned_kr != nil {
                // Anslaget er forbruket hittil framskrevet. Det bommer i en kuldeperiode,
                // og da skal det si fra om hvor tynt grunnlaget er.
                Text("Anslaget bygger på \(d) av \(n) døgn")
                    .font(.caption2).foregroundStyle(Farge.svak).padding(.top, 6)
            }
            if let p = s.pris.kr_per_kwh {
                Divider().background(Farge.kort2).padding(.vertical, 8)
                HStack {
                    Text(String(format: "%.2f kr/kWt", p))
                        .font(.caption.monospacedDigit()).foregroundStyle(Farge.tekst)
                    Spacer()
                    if let k = s.pris.kraft, let n = s.pris.nettleie {
                        Text(String(format: "strøm %.2f · nettleie %.2f", k, n))
                            .font(.caption2).foregroundStyle(Farge.svak)
                    }
                }
            }
        }
    }

    private func poster(_ s: Stromsvar) -> some View {
        // Bare det som trekker noe nå. En liste med femten nuller skjuler de tre som betyr
        // noe. Alt uten måler ligger uansett i «Annet» fra serveren.
        let aktive = s.poster.filter { ($0.watt ?? 0) > 20 }
            .sorted { ($0.watt ?? 0) > ($1.watt ?? 0) }
        return Kort {
            Text("HVA BRUKER STRØM NÅ").font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Farge.dempet)
            if aktive.isEmpty {
                Text("Ingenting av det vi måler trekker noe nevneverdig nå.")
                    .font(.caption2).foregroundStyle(Farge.svak).padding(.top, 6)
            }
            // Stolpene gjør rekkefølgen leselig uten å lese tallene: den lengste er
            // den som koster mest akkurat nå.
            let storste = aktive.first?.watt ?? 1
            VStack(spacing: 9) {
                ForEach(aktive.prefix(8)) { p in
                    VStack(spacing: 3) {
                        HStack {
                            Text(p.navn).font(.caption).foregroundStyle(Farge.tekst).lineLimit(1)
                            Spacer()
                            Text("\(Int(p.watt ?? 0)) W")
                                .font(.caption.monospacedDigit()).foregroundStyle(Farge.dempet)
                        }
                        Stolpe(andel: (p.watt ?? 0) / max(1, storste),
                               farge: kategorifarge(p.kategori), høyde: 3)
                    }
                }
            }
            .padding(.top, 10)
            if let a = s.estimat.maalt_andel {
                Text("Vi måler \(Int(a * 100)) % av husets forbruk")
                    .font(.caption2).foregroundStyle(Farge.svak).padding(.top, 8)
            }
        }
    }

    /// Farge per kategori, så en varmekabel og en bil ikke ser like ut i lista.
    private func kategorifarge(_ k: String?) -> Color {
        switch k {
        case "Varme": Farge.varm
        case "Bil": Farge.kjol
        case "Hvitevarer": Farge.ok
        case "Lys": Farge.aksent
        default: Farge.dempet
        }
    }

    private func tall(_ verdi: String, _ merkelapp: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(verdi).font(.title3.monospacedDigit()).foregroundStyle(Farge.tekst)
            Text(merkelapp).font(.caption2).foregroundStyle(Farge.dempet)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Oppgavene, slik nettbrettet viser dem — men kortet er barnet, ikke lista.
struct Oppgaversvar: Decodable {
    let barn: [Barn]
    struct Barn: Decodable, Identifiable {
        let navn: String
        let slug: String
        let poeng: Int
        let fullfortDaglig: Int
        let streakNa: Int?
        let streakIFare: Bool?
        let oppgaver: [Oppgave]?
        let belonninger: [Belonning]?
        var id: String { slug }
    }
    struct Oppgave: Decodable, Identifiable {
        let tittel: String
        /// `pending`, `claimed` eller `approved`.
        let status: String?
        let poeng: Int?
        /// Knappen som huker av oppgaven. Backend slipper bare KidsChores-knapper
        /// gjennom, så appen kan ikke be om noe annet enn dette.
        let claim: String?
        let approve: String?
        /// Å avslå er en egen handling, ikke fravær av godkjenning.
        let avslaa: String?
        var id: String { claim ?? tittel }
    }

    struct Belonning: Decodable, Identifiable {
        let tittel: String
        let cost: Int?
        let harRad: Bool?
        let status: String?
        let claim: String?
        let approve: String?
        let avslaa: String?
        var id: String { claim ?? tittel }
    }
}

struct Oppgaverfane: View {
    let api: API
    var rekkefølge: [String] = ["godkjenning", "barn"]
    /// Admin viser bare godkjenningsdelen; Oppgaver viser begge.
    @State private var svar: Oppgaversvar?
    @State private var feil: String?
    @State private var jobber: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let s = svar {
                    ForEach(rekkefølge, id: \.self) { id in
                        if id == "godkjenning", !ventende(s).isEmpty {
                            godkjenningskort(s)
                        } else if id == "barn" {
                            ForEach(s.barn) { b in barnekort(b) }
                        }
                    }
                    if s.barn.isEmpty, rekkefølge.contains("barn") {
                        Text("Ingen oppgaver å vise.").font(.footnote).foregroundStyle(Farge.svak)
                    }
                } else if let feil {
                    Label(feil, systemImage: "exclamationmark.triangle")
                        .font(.footnote).foregroundStyle(Farge.avvik)
                } else {
                    ProgressView().tint(Farge.dempet).frame(maxWidth: .infinity).padding(.top, 40)
                }
            }
            .padding(16)
            // Siste rad skal ikke ligge under fanelinja.
            .padding(.bottom, 24)
        }
        .background(Farge.flate)
        .scrollIndicators(.hidden)
        .refreshable { await hent() }
        .task { await hent() }
    }

    /// Alt som er meldt gjort og venter på en voksen.
    private struct Venter: Identifiable {
        let id: String
        let barn: String
        let hva: String
        let verdi: String
        let godkjenn: String
        let avslaa: String?
    }

    private func ventende(_ s: Oppgaversvar) -> [Venter] {
        s.barn.flatMap { b -> [Venter] in
            let o = (b.oppgaver ?? []).filter { $0.status == "claimed" }.compactMap { x -> Venter? in
                guard let g = x.approve else { return nil }
                return Venter(id: g, barn: b.navn, hva: x.tittel,
                              verdi: "+\(x.poeng ?? 0)", godkjenn: g, avslaa: x.avslaa)
            }
            let r = (b.belonninger ?? []).filter { $0.status == "claimed" }.compactMap { x -> Venter? in
                guard let g = x.approve else { return nil }
                return Venter(id: g, barn: b.navn, hva: x.tittel,
                              verdi: "−\(x.cost ?? 0)", godkjenn: g, avslaa: x.avslaa)
            }
            return o + r
        }
    }

    private func godkjenningskort(_ s: Oppgaversvar) -> some View {
        let v = ventende(s)
        return Flate(aktiv: true) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Seksjonstittel(tekst: "Venter på godkjenning")
                    Spacer()
                    Text("\(v.count)").font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(Farge.aksent)
                }
                VStack(spacing: 8) {
                    ForEach(v) { x in venterad(x) }
                }
                .padding(.top, 10)

                Button {
                    Kjenn.trykk()
                    Task { await kjor(v.map(\.godkjenn), "alle") }
                } label: {
                    HStack(spacing: 7) {
                        if jobber.contains("alle") {
                            ProgressView().controlSize(.mini).tint(Farge.dempet)
                        } else {
                            Image(systemName: "checkmark.circle.fill").font(.caption)
                        }
                        Text("Godkjenn alle (\(v.count))").font(.footnote.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 11)
                    .background(Farge.ok.opacity(0.18)).foregroundStyle(Farge.ok)
                    .clipShape(RoundedRectangle(cornerRadius: Hus.radiusLiten, style: .continuous))
                }
                .buttonStyle(Trykkflate())
                .disabled(!jobber.isEmpty)
                .padding(.top, 11)
            }
            .padding(14)
        }
    }

    private func venterad(_ x: Venter) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(x.hva).font(.footnote).foregroundStyle(Farge.tekst).lineLimit(1)
                Text("\(x.barn) · \(x.verdi)").font(.system(size: 10)).foregroundStyle(Farge.svak)
            }
            Spacer()
            if jobber.contains(x.id) {
                ProgressView().controlSize(.mini).tint(Farge.dempet)
            } else {
                svarknapp("checkmark", Farge.ok) { Task { await kjor([x.godkjenn], x.id) } }
                // Avslag finnes bare hvis KidsChores har en knapp for det. Vi later ikke
                // som om vi kan noe vi ikke kan.
                if let a = x.avslaa {
                    svarknapp("xmark", Farge.avvik) { Task { await kjor([a], x.id) } }
                }
            }
        }
    }

    private func svarknapp(_ ikon: String, _ farge: Color,
                           _ handling: @escaping () -> Void) -> some View {
        Button {
            Kjenn.trykk()
            handling()
        } label: {
            Image(systemName: ikon).font(.system(size: 13, weight: .bold))
                .frame(width: 34, height: 30)
                .background(farge.opacity(0.16)).foregroundStyle(farge)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(Trykkflate())
        .disabled(!jobber.isEmpty)
    }

    private func kjor(_ knapper: [String], _ merke: String) async {
        jobber.insert(merke)
        defer { jobber.remove(merke) }
        do {
            try await api.send("/api/hus/oppgave", ["knapp": knapper])
            Kjenn.vellykket()
            try? await Task.sleep(for: .milliseconds(900))
            await hent()
        } catch { feil = error.localizedDescription }
    }

    private func barnekort(_ b: Oppgaversvar.Barn) -> some View {
        let alt = !(b.oppgaver ?? []).isEmpty && b.fullfortDaglig >= (b.oppgaver ?? []).count
        return Flate(aktiv: alt) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text(b.navn).font(.title3.weight(.semibold)).foregroundStyle(Farge.tekst)
                    Spacer()
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(b.poeng)").font(.title2.monospacedDigit())
                            .foregroundStyle(Farge.aksent).contentTransition(.numericText())
                        Text("poeng").font(.caption2).foregroundStyle(Farge.dempet)
                    }
                }
                HStack(spacing: 10) {
                    if let st = b.streakNa, st > 0 {
                        // Rekka er verdt å se når den er i fare — det er da den kan reddes.
                        Label("\(st) dager på rad",
                              systemImage: b.streakIFare == true ? "exclamationmark.triangle.fill" : "flame.fill")
                            .foregroundStyle(b.streakIFare == true ? Farge.varm : Farge.svak)
                    }
                }
                .font(.caption).foregroundStyle(Farge.svak)
                .padding(.top, 3)

                if let o = b.oppgaver, !o.isEmpty {
                    // Dagens teller, ikke statusfeltet: KidsChores nullstiller status ved
                    // midnatt, så en oppgave gjort i morges står som «pending» igjen.
                    // Stolpen sa derfor «0 av 8» rett over teksten «2 gjort i dag».
                    let gjort = min(b.fullfortDaglig, o.count)
                    VStack(spacing: 5) {
                        Stolpe(andel: Double(gjort) / Double(max(1, o.count)),
                               farge: gjort >= o.count ? Farge.ok : Farge.aksent, høyde: 5)
                        HStack {
                            Text(gjort >= o.count ? "Alt gjort i dag"
                                                  : "\(gjort) av \(o.count) gjort i dag")
                                .font(.system(size: 10))
                                .foregroundStyle(gjort >= o.count ? Farge.ok : Farge.svak)
                            Spacer()
                        }
                    }
                    .padding(.top, 12)

                    VStack(spacing: 7) {
                        ForEach(o) { x in oppgaverad(x) }
                    }
                    .padding(.top, 10)
                }

                let bel = Array((b.belonninger ?? []).filter { $0.harRad == true }.prefix(3))
                if !bel.isEmpty {
                    Divider().background(Farge.strek).padding(.vertical, 11)
                    Seksjonstittel(tekst: "Har råd til")
                    // Bare det barnet faktisk har poeng til. En liste over alt man ikke
                    // har råd til, er ikke motiverende — den er en prisliste.
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(bel) { r in
                            HStack {
                                Text(r.tittel).font(.caption).foregroundStyle(Farge.tekst)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(r.cost ?? 0)").font(.caption.monospacedDigit())
                                    .foregroundStyle(Farge.aksent)
                            }
                        }
                    }
                    .padding(.top, 6)
                }
            }
            .padding(14)
        }
    }

    /// Én oppgave. Trykk huker den av — det er det barnet gjør, og det er hele poenget
    /// med å ha den på telefonen framfor på nettbrettet på kjøkkenet.
    private func oppgaverad(_ x: Oppgaversvar.Oppgave) -> some View {
        let gjort = x.status == "approved"
        let venter = x.status == "claimed"
        return Button {
            guard let knapp = gjort ? nil : (venter ? x.approve : x.claim) else { return }
            Kjenn.trykk()
            Task { await hukAv(knapp, x.id) }
        } label: {
            HStack(spacing: 9) {
                if jobber.contains(x.id) {
                    ProgressView().controlSize(.mini).tint(Farge.dempet).frame(width: 18)
                } else {
                    Image(systemName: gjort ? "checkmark.circle.fill"
                          : (venter ? "clock.badge.checkmark" : "circle"))
                        .font(.system(size: 16))
                        .foregroundStyle(gjort ? Farge.ok : (venter ? Farge.aksent : Farge.svak))
                        .frame(width: 18)
                }
                Text(x.tittel)
                    .font(.footnote)
                    .foregroundStyle(gjort ? Farge.svak : Farge.tekst)
                    .strikethrough(gjort, color: Farge.svak)
                    .lineLimit(1)
                Spacer()
                if let p = x.poeng {
                    Text("+\(p)").font(.caption2.monospacedDigit())
                        .foregroundStyle(gjort ? Farge.svak : Farge.dempet)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(Trykkflate())
        .disabled(gjort || jobber.contains(x.id))
        .animation(.smooth(duration: 0.3), value: x.status)
    }

    private func hukAv(_ knapp: String, _ id: String) async {
        jobber.insert(id)
        defer { jobber.remove(id) }
        do {
            try await api.send("/api/hus/oppgave", ["knapp": knapp])
            Kjenn.vellykket()
            // KidsChores bruker et øyeblikk på å oppdatere sensorene sine.
            try? await Task.sleep(for: .milliseconds(700))
            await hent()
        } catch { feil = error.localizedDescription }
    }

    private func hent() async {
        do { svar = try await api.hent(Oppgaversvar.self, "/api/hus/oppgaver"); feil = nil }
        catch { feil = error.localizedDescription }
    }
}

/// Felles kortramme for fanene, så de ser like ut uansett innhold.
struct Kort<Innhold: View>: View {
    @ViewBuilder var innhold: () -> Innhold
    var body: some View {
        VStack(alignment: .leading, spacing: 0) { innhold() }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Farge.kort)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
