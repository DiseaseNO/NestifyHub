import SwiftUI

/// «Sett opp appen» — hva som vises, og i hvilken rekkefølge.
///
/// Skjulte moduler står i sin egen seksjon framfor å forsvinne. En bryter man ikke
/// finner igjen, er en funksjon man har mistet.
struct Oppsettvisning: View {
    @Bindable var oppsett: Oppsett
    @Environment(\.dismiss) private var lukk

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(oppsett.sortert) { m in
                        rad(m)
                    }
                    .onMove { oppsett.flytt(fra: $0, til: $1) }
                } header: {
                    Text("Moduler").font(.caption).foregroundStyle(Farge.dempet)
                } footer: {
                    Text("Dra i håndtaket for å endre rekkefølgen. Den øverste er den du "
                         + "ser først. Nye moduler legger seg nederst.")
                        .font(.caption2).foregroundStyle(Farge.svak)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Farge.flate)
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Sett opp")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Farge.flate, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Nullstill") { oppsett.nullstill() }
                        .foregroundStyle(Farge.svak)
                }
                ToolbarItem(placement: .topBarTrailing) { Button("Ferdig") { lukk() } }
            }
        }
    }

    private func rad(_ m: Modul) -> some View {
        let synlig = !oppsett.skjult.contains(m.id)
        return HStack(spacing: 10) {
            Image(systemName: m.ikon).font(.footnote)
                .foregroundStyle(synlig ? Farge.aksent : Farge.svak).frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(m.navn).font(.subheadline)
                    .foregroundStyle(synlig ? Farge.tekst : Farge.svak)
                Text(m.undertekst).font(.caption2).foregroundStyle(Farge.svak)
            }
            Spacer()
            Toggle("", isOn: Binding(get: { synlig },
                                     set: { oppsett.settSynlig(m.id, $0) }))
                .labelsHidden()
                .tint(Farge.aksent)
        }
        .listRowBackground(Farge.kort)
    }
}
