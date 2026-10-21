import SwiftUI

/// gastos que se apuntan solos al pagar con Apple Pay (automatización de Atajos)
struct AutoExpensesView: View {
    @Environment(Store.self) private var store
    var body: some View {
        let auto = store.state.txs.filter { $0.note == "Apuntado solo (Apple Pay)" }.sorted { $0.sortKey > $1.sortKey }
        List {
            Section {
                step(1, "Abre la app Atajos → pestaña «Automatización» → «+»")
                step(2, "Elige «Transacción» y marca tus tarjetas (Revolut…)")
                step(3, "Marca «Ejecutar inmediatamente» y toca «Siguiente»")
                step(4, "«Nuevo atajo en blanco» → «Añadir acción» → busca «Apuntar gasto en Caudal»")
                step(5, "En Importe pon «Importe», en Comercio «Comercio» y en Tarjeta «Tarjeta» (toca cada campo y elige la variable de la transacción)")
            } header: { Text("Cómo activarlo") }
            Section("Apuntados solos") {
                if auto.isEmpty { Text("Ninguno todavía").foregroundStyle(.secondary) }
                ForEach(auto.prefix(30)) { t in TxRow(tx: t, showDate: true) }
            }
        }
        .navigationTitle("Gastos automáticos")
    }
    private func step(_ n: Int, _ t: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)").font(.headline).foregroundStyle(.black).frame(width: 28, height: 28).background(Color.accentColor, in: Circle())
            Text(t).font(.subheadline)
        }
        .padding(.vertical, 2)
    }
}
