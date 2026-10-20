import SwiftUI

enum MainTab: Hashable { case home, txs, debts, invest, more }

struct RootView: View {
    @Environment(Store.self) private var store
    @State private var tab: MainTab = .home
    @State private var newTx = false
    @State private var fabSpin = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $tab) {
                HomeView(tab: $tab).tag(MainTab.home)
                    .tabItem { Label("Inicio", systemImage: "house.fill") }
                TransactionsView().tag(MainTab.txs)
                    .tabItem { Label("Movimientos", systemImage: "list.bullet.rectangle.portrait.fill") }
                DebtsView().tag(MainTab.debts)
                    .tabItem { Label("Cuentas", systemImage: "person.2.fill") }
                InvestView().tag(MainTab.invest)
                    .tabItem { Label("Inversiones", systemImage: "chart.line.uptrend.xyaxis") }
                MoreView().tag(MainTab.more)
                    .tabItem { Label("Más", systemImage: "ellipsis.circle.fill") }
            }
            .onChange(of: tab) { _, _ in Haptic.select() }

            // botón de apuntar, siempre a mano
            if (tab == .home || tab == .txs) && !store.hideFAB {
                Button {
                    Haptic.heavy()
                    fabSpin.toggle()
                    newTx = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 26, weight: .bold))
                        .rotationEffect(.degrees(fabSpin ? 90 : 0))
                        .foregroundStyle(.black)
                        .frame(width: 62, height: 62)
                        .background(Color.accentColor.gradient, in: Circle())
                        .shadow(color: Color.accentColor.opacity(0.45), radius: 14, y: 6)
                }
                .buttonStyle(PressableStyle(scale: 0.86))
                .padding(.trailing, 20)
                .padding(.bottom, 96)
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: fabSpin)
            }

            // aviso para deshacer el último borrado
            if let t = store.lastDeleted {
                UndoToast(text: "«\(t.title.isEmpty ? t.type.label : t.title)» eliminado") {
                    Haptic.success(); store.undoDelete()
                } dismiss: {
                    withAnimation { store.lastDeleted = nil }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 170)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .id(t.id)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: tab)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: store.lastDeleted)
        .sheet(isPresented: $newTx) { TxEditor(original: nil) }
        .task {
            // (capturas automáticas: -tab txs|invest|stats|more, -new abre el teclado de apuntar)
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-tab"), i + 1 < args.count {
                switch args[i + 1] {
                case "txs": tab = .txs
                case "invest": tab = .invest
                case "debts": tab = .debts
                case "more": tab = .more
                default: break
                }
            }
            if args.contains("-new") { newTx = true }
            if args.contains("-demodebts"), store.state.people.isEmpty {   // (solo para las capturas del simulador)
                let a = Person(name: "Jorlo", emoji: "🥸", color: "#5fe0a0", phone: "600000000")
                let b = Person(name: "Álvaro", emoji: "🦊", color: "#ffa94d")
                let c = Person(name: "Daria", emoji: "🌸", color: "#ff9ecf")
                store.state.people = [a, b, c]
                store.state.debts = [DebtMove(personId: a.id, amount: 12.5, kind: .split, concept: "Cena del viernes", date: Day.add(Day.today, days: -2), total: 37.5),
                                     DebtMove(personId: b.id, amount: 12.5, kind: .split, concept: "Cena del viernes", date: Day.add(Day.today, days: -2), total: 37.5),
                                     DebtMove(personId: c.id, amount: -8, kind: .debt, concept: "Entradas del cine", date: Day.add(Day.today, days: -1)),
                                     DebtMove(personId: a.id, amount: -5, kind: .pay, date: Day.today)]
            }
            await Prices.refresh(store)
        }
    }
}

struct UndoToast: View {
    var text: String
    var undo: () -> Void
    var dismiss: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trash.fill").foregroundStyle(.red)
            Text(text).font(.subheadline.weight(.medium)).lineLimit(1)
            Spacer(minLength: 4)
            Button("Deshacer", action: undo).font(.subheadline.weight(.bold))
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
        .padding(.horizontal, 20)
        .task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            dismiss()
        }
    }
}
