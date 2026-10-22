import SwiftUI

enum MainTab: String, Hashable, Identifiable {
    case home, txs, debts, invest, stats, work, goals, more
    var id: String { rawValue }

    /// la pestaña de un id de Ajustes (settings.tabs)
    static func of(_ s: String) -> MainTab? {
        switch s {
        case "movimientos": .txs
        case "cuentas": .debts
        case "inversiones": .invest
        case "analisis": .stats
        case "horas": .work
        case "objetivos": .goals
        default: nil
        }
    }
    static let names: [String: (name: String, icon: String)] = [
        "movimientos": ("Movimientos", "list.bullet.rectangle.portrait.fill"),
        "cuentas": ("Cuentas", "person.2.fill"),
        "inversiones": ("Inversiones", "chart.line.uptrend.xyaxis"),
        "analisis": ("Análisis", "chart.pie.fill"),
        "horas": ("Horas", "briefcase.fill"),
        "objetivos": ("Objetivos", "target"),
    ]
}

/// la pantalla de una pestaña (también se abre en hoja si no está en la barra)
struct TabScreen: View {
    var tab: MainTab
    var body: some View {
        switch tab {
        case .txs: TransactionsView()
        case .debts: DebtsView()
        case .invest: InvestView()
        case .stats: StatsView()
        case .work: NavigationStack { WorkView() }
        case .goals: NavigationStack { GoalsList() }
        default: EmptyView()
        }
    }
}

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
                ForEach(store.state.settings.tabs, id: \.self) { id in
                    if let t = MainTab.of(id), let info = MainTab.names[id] {
                        TabScreen(tab: t).tag(t)
                            .tabItem { Label(info.name, systemImage: info.icon) }
                    }
                }
                MoreView().tag(MainTab.more)
                    .tabItem { Label("Más", systemImage: "ellipsis.circle.fill") }
            }
            .onChange(of: tab) { _, _ in Haptic.select() }
            .onChange(of: store.state.settings.tabs) { _, tabs in
                if tab != .home && tab != .more && !tabs.compactMap(MainTab.of).contains(tab) { tab = .home }
            }

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
            if args.contains("-lookdemo") {   // (solo para las capturas del simulador)
                store.state.settings.background = "agua"
                store.state.settings.cardStyle = "cristal"
                store.state.settings.mascot = true
                store.state.settings.mascotHat = "corona"
                if let i = store.state.home.firstIndex(where: { $0.id == "disponible" }) {
                    var h = store.state.home
                    var it = h.remove(at: i); it.on = true
                    h.insert(it, at: 1)
                    store.state.home = h
                }
            }
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
