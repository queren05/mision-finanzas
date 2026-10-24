import SwiftUI

/// nombre e icono de cada tarjeta de Hoy
enum TodayModule {
    static func label(_ m: String) -> String {
        switch m {
        case "resumen": "Resumen del día"
        case "semana": "Semana"
        case "briefing": "Briefing con IA"
        case "agenda": "Agenda de hoy"
        case "recordatorios": "Recordatorios"
        case "prioridades": "Prioridades"
        case "tareas": "Tareas"
        case "humo": "Sin humo"
        case "cine": "Viendo ahora"
        case "deseos": "Deseos"
        default: m
        }
    }
    static func icon(_ m: String) -> String {
        switch m {
        case "resumen": "square.grid.3x1.below.line.grid.1x2.fill"
        case "semana": "calendar.day.timeline.left"
        case "briefing": "sparkles"
        case "agenda": "calendar"
        case "recordatorios": "bell.fill"
        case "prioridades": "flag.fill"
        case "tareas": "checklist"
        case "humo": "wind"
        case "cine": "film.fill"
        case "deseos": "gift.fill"
        default: "square"
        }
    }
}

struct PersonalizeView: View {
    @Environment(Store.self) private var store

    var body: some View {
        @Bindable var store = store
        List {
            Section {
                Toggle(isOn: $store.s.settings.ai.animation()) { Label("Usar inteligencia artificial", systemImage: "sparkles") }
            }
            Section("Barra de abajo") {
                NavigationLink { TabsCustomizer() } label: {
                    HStack {
                        Label("Pestañas", systemImage: "dock.rectangle")
                        Spacer()
                        Text(store.s.settings.tabs.compactMap { Page(rawValue: $0)?.label }.joined(separator: ", "))
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }
            Section("Tarjetas de Hoy") {
                let order = store.s.settings.todayOrder
                ForEach(Array(order.enumerated()), id: \.element) { i, m in
                    let ai = m == "briefing" && !store.s.settings.ai
                    HStack(spacing: 10) {
                        Label(TodayModule.label(m), systemImage: TodayModule.icon(m))
                            .opacity(ai ? 0.45 : 1)
                        Spacer()
                        MoveButtons(index: i, count: order.count) { to in
                            withAnimation { store.s.settings.todayOrder.swapAt(i, to) }
                        }
                        Toggle("", isOn: Binding(get: { !store.s.settings.todayHidden.contains(m) }, set: { on in
                            Haptic.select()
                            withAnimation {
                                if on { store.s.settings.todayHidden.removeAll { $0 == m } } else if !store.s.settings.todayHidden.contains(m) { store.s.settings.todayHidden.append(m) }
                            }
                        }))
                        .labelsHidden()
                        .disabled(ai)
                    }
                }
            }
            Section {
                Button("Volver a como estaba") {
                    withAnimation {
                        let d = Settings()
                        store.s.settings.todayOrder = d.todayOrder
                        store.s.settings.todayHidden = d.todayHidden
                        store.s.settings.tabs = d.tabs
                        store.s.settings.ai = true
                    }
                    Haptic.success()
                }
            }
        }
        .navigationTitle("Personalizar")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// qué pestañas salen en la barra (entre 1 y 4, además de Hoy) y en qué orden
struct TabsCustomizer: View {
    @Environment(Store.self) private var store

    var body: some View {
        @Bindable var store = store
        let tabs = store.s.settings.tabs
        let rest = Page.allCases.filter { $0 != .hoy && !tabs.contains($0.rawValue) }
        List {
            Section {
                Label("Hoy", systemImage: Page.hoy.icon).foregroundStyle(.secondary)
                ForEach(Array(tabs.enumerated()), id: \.element) { i, id in
                    if let p = Page(rawValue: id) {
                        HStack(spacing: 10) {
                            Label(p.label, systemImage: p.icon)
                            Spacer()
                            MoveButtons(index: i, count: tabs.count) { to in
                                withAnimation { store.s.settings.tabs.swapAt(i, to) }
                            }
                            Button { Haptic.tap(); withAnimation { store.s.settings.tabs.removeAll { $0 == id } } } label: {
                                Image(systemName: "minus.circle.fill").foregroundStyle(tabs.count <= 1 ? Color.secondary : Color.negative).font(.title3)
                            }
                            .buttonStyle(.borderless)
                            .disabled(tabs.count <= 1)
                        }
                    }
                }
            } header: { Text("En la barra (\(tabs.count) de \(Settings.maxTabs))") }
            if !rest.isEmpty {
                Section("Fuera de la barra") {
                    ForEach(rest) { p in
                        HStack {
                            Label(p.label, systemImage: p.icon)
                            Spacer()
                            Button { Haptic.tap(); withAnimation { store.s.settings.tabs.append(p.rawValue) } } label: {
                                Image(systemName: "plus.circle.fill").foregroundStyle(tabs.count >= Settings.maxTabs ? Color.secondary : Color.income).font(.title3)
                            }
                            .buttonStyle(.borderless)
                            .disabled(tabs.count >= Settings.maxTabs)
                        }
                    }
                }
            }
        }
        .navigationTitle("Barra de abajo")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// flechas para subir o bajar una fila
struct MoveButtons: View {
    var index: Int
    var count: Int
    var move: (Int) -> Void
    var body: some View {
        HStack(spacing: 4) {
            arrow("chevron.up", index > 0) { move(index - 1) }
            arrow("chevron.down", index < count - 1) { move(index + 1) }
        }
    }
    private func arrow(_ icon: String, _ on: Bool, _ action: @escaping () -> Void) -> some View {
        Button { Haptic.select(); action() } label: {
            Image(systemName: icon).font(.caption.weight(.bold))
                .frame(width: 30, height: 30)
                .background(Color.white.opacity(on ? 0.08 : 0.03), in: Circle())
                .foregroundStyle(on ? Color.primary : Color.secondary.opacity(0.4))
        }
        .buttonStyle(.borderless)
        .disabled(!on)
    }
}
