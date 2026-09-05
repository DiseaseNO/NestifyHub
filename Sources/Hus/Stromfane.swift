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
    }
    struct Post: Decodable, Identifiable {
        let navn: String
        let watt: Double?
        let dag_kwh: Double?
        let kategori: String?
        var id: String { navn }
    }
    struct Estimat: Decodable {
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
    @State private var svar: Stromsvar?
    @State private var feil: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let s = svar {
                    naakort(s)
                    kostnad(s)
                    poster(s)
                } else if let feil {
                    Label(feil, systemImage: "exclamationmark.triangle")
                        .font(.footnote).foregroundStyle(Farge.avvik)
                } else {
                    ProgressView().tint(Farge.dempet).frame(maxWidth: .infinity).padding(.top, 40)
                }
            }
            .padding(16)
        }
        .background(Farge.flate)
        .scrollIndicators(.hidden)
        .refreshable { await hent() }
        .task { await hent() }
    }

    private func hent() async {
        do { svar = try await api.hent(Stromsvar.self, "/api/hus/strom"); feil = nil }
        catch { feil = error.localizedDescription }
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
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(String(format: "%.0f", Double(w) / 1000 * p * 100))
                            .font(.title3.monospacedDigit()).foregroundStyle(Farge.tekst)
                        Text("øre i timen").font(.caption2).foregroundStyle(Farge.dempet)
                    }
                }
            }
            if s.naa.fordeling?.er_hoyt == true {
                Label("Høyt for dette huset akkurat nå", systemImage: "arrow.up.right")
                    .font(.caption2).foregroundStyle(Farge.varm).padding(.top, 6)
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
            VStack(spacing: 6) {
                ForEach(aktive.prefix(8)) { p in
                    HStack {
                        Text(p.navn).font(.caption).foregroundStyle(Farge.tekst).lineLimit(1)
                        Spacer()
                        Text("\(Int(p.watt ?? 0)) W")
                            .font(.caption.monospacedDigit()).foregroundStyle(Farge.dempet)
                    }
                }
            }
            .padding(.top, 8)
            if let a = s.estimat.maalt_andel {
                Text("Vi måler \(Int(a * 100)) % av husets forbruk")
                    .font(.caption2).foregroundStyle(Farge.svak).padding(.top, 8)
            }
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
        var id: String { slug }
    }
    struct Oppgave: Decodable, Identifiable {
        let navn: String?
        let status: String?
        var id: String { navn ?? UUID().uuidString }
    }
}

struct Oppgaverfane: View {
    let api: API
    @State private var svar: Oppgaversvar?
    @State private var feil: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let s = svar {
                    ForEach(s.barn) { b in
                        Kort {
                            HStack {
                                Text(b.navn).font(.subheadline.weight(.medium))
                                    .foregroundStyle(Farge.tekst)
                                Spacer()
                                Text("\(b.poeng)").font(.title3.monospacedDigit())
                                    .foregroundStyle(Farge.aksent)
                            }
                            HStack(spacing: 10) {
                                Text("\(b.fullfortDaglig) gjort i dag")
                                if let s = b.streakNa, s > 0 {
                                    // Rekka er verdt å se når den er i fare — det er da
                                    // den kan reddes.
                                    Label("\(s) dager på rad",
                                          systemImage: b.streakIFare == true ? "exclamationmark.circle" : "flame")
                                        .foregroundStyle(b.streakIFare == true ? Farge.varm : Farge.svak)
                                }
                            }
                            .font(.caption2).foregroundStyle(Farge.svak).padding(.top, 4)

                            if let o = b.oppgaver, !o.isEmpty {
                                Divider().background(Farge.kort2).padding(.vertical, 8)
                                VStack(alignment: .leading, spacing: 5) {
                                    ForEach(o.prefix(6)) { x in
                                        HStack(spacing: 6) {
                                            Image(systemName: x.status == "approved"
                                                  ? "checkmark.circle.fill" : "circle")
                                                .font(.caption2)
                                                .foregroundStyle(x.status == "approved" ? Farge.aksent : Farge.svak)
                                            Text(x.navn ?? "—").font(.caption)
                                                .foregroundStyle(Farge.tekst).lineLimit(1)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    if s.barn.isEmpty {
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
        }
        .background(Farge.flate)
        .scrollIndicators(.hidden)
        .refreshable { await hent() }
        .task { await hent() }
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
