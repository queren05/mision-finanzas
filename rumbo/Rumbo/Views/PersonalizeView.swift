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
                ForEach(store.s.settings.todayOrder, id: \.self) { m in
                    let ai = m == "briefing" && !store.s.settings.ai
                    Toggle(isOn: Binding(get: { !store.s.settings.todayHidden.contains(m) }, set: { on in
                        Haptic.select()
                        withAnimation {
                            if on { store.s.settings.todayHidden.removeAll { $0 == m } } else { store.s.settings.todayHidden.append(m) }
                        }
                    })) {
                        Label(TodayModule.label(m), systemImage: TodayModule.icon(m))
                    }
                    .disabled(ai)
                    .opacity(ai ? 0.45 : 1)
                }
                .onMove { from, to in store.s.settings.todayOrder.move(fromOffsets: from, toOffset: to); Haptic.select() }
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
        .environment(\.editMode, .constant(.active))
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
                ForEach(tabs, id: \.self) { id in
                    if let p = Page(rawValue: id) {
                        HStack {
                            Label(p.label, systemImage: p.icon)
                            Spacer()
                            Button { Haptic.tap(); withAnimation { store.s.settings.tabs.removeAll { $0 == id } } } label: {
                                Image(systemName: "minus.circle.fill").foregroundStyle(Color.negative).font(.title3)
                            }
                            .buttonStyle(.plain)
                            .disabled(tabs.count <= 1)
                        }
                    }
                }
                .onMove { from, to in store.s.settings.tabs.move(fromOffsets: from, toOffset: to); Haptic.select() }
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
                            .buttonStyle(.plain)
                            .disabled(tabs.count >= Settings.maxTabs)
                        }
                    }
                }
            }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle("Barra de abajo")
        .navigationBarTitleDisplayMode(.inline)
    }
}
