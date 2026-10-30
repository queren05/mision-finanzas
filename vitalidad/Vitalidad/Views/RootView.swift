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
    @State private var detail: Metric? = Launch.value("-detail").flatMap(Metric.init(rawValue:))

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
        // Al tocar un widget: vitalidad://tab/sleep · vitalidad://detalle/hrv
        .onOpenURL { url in
            let parts = url.pathComponents.filter { $0 != "/" }
            switch url.host {
            case "tab":
                if let t = parts.first.flatMap(AppTab.init(rawValue:)) { tab = t }
            case "detalle":
                if let m = parts.first.flatMap(Metric.init(rawValue:)) {
                    tab = .today
                    detail = m
                }
            default: break
            }
        }
    }

    @ViewBuilder
    private func screen(_ t: AppTab) -> some View {
        switch t {
        case .today: TodayView(opened: $detail)
        case .sleep: SleepView()
        case .activity: ActivityView()
        case .nutrition: NutritionView()
        case .trends: TrendsView()
        }
    }
}
