import SwiftUI
import WidgetKit

/// cómo se ven los widgets con tus datos y cómo ponerlos
struct WidgetsGallery: View {
    @Environment(Store.self) private var store
    var body: some View {
        let d = store.widgetData()
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                steps
                title("Cuentas")
                HStack(spacing: 14) { box(small: true) { WBalanceSmall(d: d) }; box(small: true) { WSpentSmall(d: d) } }
                box { WAccounts(d: d) }
                title("Gastos del mes")
                box { WSpentMedium(d: d) }
                title("Inversiones")
                HStack(spacing: 14) { box(small: true) { WInvest(d: d, showList: false) }; Spacer() }
                box { WInvest(d: d) }
                title("Grande")
                box(height: 340) { WLarge(d: d) }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Widgets")
        .onAppear { store.updateWidgets() }
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Mantén pulsada la pantalla de inicio del iPhone", systemImage: "1.circle.fill")
            Label("Toca «Editar» → «Añadir widget»", systemImage: "2.circle.fill")
            Label("Busca Caudal y elige el que quieras", systemImage: "3.circle.fill")
            Label("«Gastos del mes» también va en la pantalla de bloqueo", systemImage: "lock.circle.fill")
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
    private func title(_ t: String) -> some View { Text(t).font(.headline).padding(.top, 4) }
    private func box<C: View>(small: Bool = false, height: CGFloat = 158, @ViewBuilder _ c: () -> C) -> some View {
        c().padding(16)
            .frame(width: small ? 158 : nil, height: small ? 158 : height)
            .frame(maxWidth: small ? nil : .infinity)
            .background(LinearGradient(colors: [Color(hex: "#1c1b22"), Color(hex: "#111014")], startPoint: .top, endPoint: .bottom),
                        in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.08)))
    }
}

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
