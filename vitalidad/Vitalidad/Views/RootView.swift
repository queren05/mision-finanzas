import SwiftUI

enum AppTab: String, CaseIterable {
    case today, sleep, activity, nutrition, trends

    var title: String {
        switch self {
        case .today: "Hoy"
        case .sleep: "Sueño"
        case .activity: "Actividad"
        case .nutrition: "Nutrición"
        case .trends: "Tendencias"
        }
    }

    var symbol: String {
        switch self {
        case .today: "sun.max.fill"
        case .sleep: "moon.zzz.fill"
        case .activity: "flame.fill"
        case .nutrition: "fork.knife"
        case .trends: "chart.xyaxis.line"
        }
    }
}

struct RootView: View {
    @State private var tab: AppTab = AppTab(rawValue: Launch.value("-tab") ?? "") ?? .today

    var body: some View {
        TabView(selection: $tab) {
            ForEach(AppTab.allCases, id: \.self) { t in
                NavigationStack {
                    screen(t)
                }
                .tabItem { Label(t.title, systemImage: t.symbol) }
                .tag(t)
            }
        }
        .minimizingTabBar()
    }

    @ViewBuilder
    private func screen(_ t: AppTab) -> some View {
        PlaceholderScreen(tab: t)
    }
}

/// Pantalla provisional de la fase 1.
struct PlaceholderScreen: View {
    var tab: AppTab
    @State private var settings = Launch.args.contains("-settings")

    var body: some View {
        ZStack {
            MoodBackground(mood: .neutral)
            VStack(spacing: Space.l) {
                MetricGlyph(symbol: tab.symbol, color: Palette.recovery, size: 72)
                Text(tab.title).font(.largeTitle.bold())
            }
        }
        .navigationTitle(tab.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { settings = true } label: { Image(systemName: "gearshape") }
            }
        }
        .sheet(isPresented: $settings) { SettingsView() }
    }
}
