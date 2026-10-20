import AppIntents

/// «Apuntar gasto»: para una automatización de Atajos (Transacción de Cartera) que apunta cada pago con Apple Pay
struct AddExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Apuntar gasto en Caudal"
    static var description = IntentDescription("Apunta un gasto en Caudal sin abrir la app.")
    static var openAppWhenRun = false

    @Parameter(title: "Importe") var importe: String
    @Parameter(title: "Comercio") var comercio: String?
    @Parameter(title: "Tarjeta") var tarjeta: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Apuntar \(\.$importe) en \(\.$comercio)") { \.$tarjeta }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let amount = AutoInbox.parse(importe), amount > 0 else {
            return .result(dialog: "No entiendo el importe «\(importe)»")
        }
        AutoInbox.add(PendingTx(amount: amount, merchant: comercio ?? "", card: tarjeta ?? "", date: Date()))
        let store = Store.live ?? Store()
        store.mergeInbox()
        let shop = (comercio ?? "").isEmpty ? "" : " en \(comercio!)"
        return .result(dialog: "Apuntado: \(Money.eur(amount))\(shop)")
    }
}

struct CaudalShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: AddExpenseIntent(), phrases: ["Apunta un gasto en \(.applicationName)", "Nuevo gasto en \(.applicationName)"],
                    shortTitle: "Apuntar gasto", systemImageName: "eurosign.circle.fill")
    }
}
