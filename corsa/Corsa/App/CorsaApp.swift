import SwiftUI
import UserNotifications

@main
struct CorsaApp: App {
    @State private var store = Store()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(\.locale, Locale(identifier: "es_ES"))
                .tint(Color(hex: "#7ac8ff"))
                .preferredColorScheme(.dark)
                .onAppear {
                    if !ProcessInfo.processInfo.arguments.contains("-demo") {
                        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
                    }
                    store.scheduleNotifications()
                }
        }
    }
}

enum CTab: Hashable { case home, parts, log, faults, more }

struct RootView: View {
    @Environment(Store.self) private var store
    @State private var tab: CTab = .home
    @State private var wizard = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $tab) {
                HomeView(tab: $tab).tag(CTab.home).tabItem { Label("Inicio", systemImage: "car.fill") }
                PartsView().tag(CTab.parts).tabItem { Label("Piezas", systemImage: "wrench.and.screwdriver.fill") }
                LogView().tag(CTab.log).tabItem { Label("Historial", systemImage: "clock.arrow.circlepath") }
                FaultsView().tag(CTab.faults).tabItem { Label("Averías", systemImage: "exclamationmark.triangle.fill") }
                MoreView(wizard: $wizard).tag(CTab.more).tabItem { Label("Más", systemImage: "ellipsis.circle.fill") }
            }
            .onChange(of: tab) { _, _ in Haptic.select() }
            if let l = store.lastDeleted {
                HStack(spacing: 12) {
                    Image(systemName: "trash.fill").foregroundStyle(.red)
                    Text("Registro borrado").font(.subheadline.weight(.medium))
                    Spacer()
                    Button("Deshacer") { Haptic.success(); store.undoDelete() }.font(.subheadline.weight(.bold))
                }
                .padding(.horizontal, 18).padding(.vertical, 14)
                .background(.regularMaterial, in: Capsule())
                .padding(.horizontal, 20).padding(.bottom, 100)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .id(l.id)
                .task { try? await Task.sleep(nanoseconds: 5_000_000_000); withAnimation { store.lastDeleted = nil } }
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: store.lastDeleted)
        .fullScreenCover(isPresented: $wizard) { WizardView() }
        .task {
            // (capturas automáticas: -demo rellena datos de ejemplo, -tab parts|log|faults|more, -wizard)
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-demo") { Demo.fill(store) }
            if let i = args.firstIndex(of: "-tab"), i + 1 < args.count {
                switch args[i + 1] {
                case "parts": tab = .parts
                case "log": tab = .log
                case "faults": tab = .faults
                case "more": tab = .more
                default: break
                }
            }
            if args.contains("-wizard") || (!store.s.done && !args.contains("-demo")) { wizard = true }
        }
    }
}

enum Demo {
    static func fill(_ store: Store) {
        var st = CState()
        st.km = 182_400; st.matric = "2019-06-01"; st.itv = "2025-06-10"; st.done = true
        st.kmLog = [KmPoint(d: Day.add(Day.today, days: -90), km: 179_100), KmPoint(d: Day.today, km: 182_400)]
        st.parts = ["aceite": PartState(km: 170_000, date: "2025-10-01"), "aire": PartState(km: 165_000, date: "2025-03-01"), "polen": PartState(km: 175_000, date: "2026-02-01"),
                    "bujias": PartState(km: 150_000, date: "2024-01-01"), "glp_gas": PartState(km: 172_000, date: "2025-11-01"), "glp_liq": PartState(km: 172_000, date: "2025-11-01"),
                    "pastillas_del": PartState(km: 160_000, date: "2025-01-01"), "neumaticos": PartState(km: 168_000, date: "2025-05-01"), "bateria": PartState(date: "2023-02-01"),
                    "frenos_liq": PartState(date: "2024-05-01"), "escobillas": PartState(date: "2025-12-01")]
        st.logs = [LogEntry(part: "aceite", date: "2025-10-01", km: 170_000, cost: 89.9, where: "Taller Paco", note: "Castrol 5W-30 dexos2"),
                   LogEntry(part: "glp_gas", date: "2025-11-01", km: 172_000, cost: 45, where: "Taller GLP"),
                   LogEntry(title: "Cambio de luneta", date: "2026-03-14", km: 178_500, cost: 160, where: "Carglass")]
        store.s = st
    }
}
