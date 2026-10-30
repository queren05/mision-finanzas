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
    @AppStorage("energia") private var energy = EnergyUnit.kcal

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
        // Al cambiar de kcal a kJ se vuelven a pintar todas las pantallas.
        .id(energy)
    }

    @ViewBuilder
    private func screen(_ t: AppTab) -> some View {
        switch t {
        case .today: TodayView()
        case .sleep: SleepView()
        case .activity: ActivityView()
        case .nutrition: NutritionView()
        case .trends: TrendsView()
        }
    }
}
