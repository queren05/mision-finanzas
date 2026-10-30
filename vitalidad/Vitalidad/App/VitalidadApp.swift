import SwiftUI

@main
struct VitalidadApp: App {
    @AppStorage("onboarded") private var onboarded = false
    @AppStorage("tema") private var theme = Theme.auto
    @State private var store = HealthStore.shared
    @Environment(\.scenePhase) private var phase

    init() {
        // Las consultas que vigilan Salud tienen que quedar puestas al arrancar, también cuando iOS abre la app en segundo plano.
        if UserDefaults.standard.bool(forKey: "onboarded") || Launch.demo { HealthStore.shared.start() }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if onboarded || Launch.demo {
                    RootView()
                } else {
                    WelcomeView {
                        withAnimation(.smooth) { onboarded = true }
                        store.start()
                    }
                }
            }
            .environment(store)
            .onChange(of: phase) { _, p in
                if p == .active && onboarded { Task { await store.refresh(full: false) } }
            }
            .fontDesign(.rounded)
            .environment(\.locale, Locale(identifier: "es_ES"))
            .preferredColorScheme(theme.scheme)
        }
    }
}

enum Theme: String, CaseIterable, Identifiable {
    case auto, dark, light
    var id: String { rawValue }
    var title: String {
        switch self {
        case .auto: "Automático"
        case .dark: "Oscuro"
        case .light: "Claro"
        }
    }
    var scheme: ColorScheme? {
        switch self {
        case .auto: nil
        case .dark: .dark
        case .light: .light
        }
    }
}

enum EnergyUnit: String, CaseIterable, Identifiable {
    case kcal, kJ
    var id: String { rawValue }
}
