import SwiftUI
import LocalAuthentication

@main
struct CaudalApp: App {
    @State private var store = Store()
    @State private var locked = false
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView().scrollIndicators(.hidden)
                if locked {
                    LockView(unlock: unlock)
                        .transition(.opacity.combined(with: .scale(scale: 1.08)))
                        .zIndex(10)
                }
            }
            .environment(store)
            .environment(\.locale, Locale(identifier: "es_ES"))
            .tint(Color(hex: store.state.settings.accent))
            .preferredColorScheme(.dark)
            .onAppear { if store.state.settings.faceID { locked = true; unlock() } }
            .onChange(of: phase) { _, p in
                switch p {
                case .background:
                    store.saveNow()
                    if store.state.settings.faceID { locked = true }
                case .active:
                    store.runRecurring()
                    if locked { unlock() }
                default: break
                }
            }
        }
    }

    private func unlock() {
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else { withAnimation { locked = false }; return }
        ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Desbloquea Caudal") { ok, _ in
            DispatchQueue.main.async {
                if ok { withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { locked = false }; Haptic.success() }
            }
        }
    }
}

struct LockView: View {
    var unlock: () -> Void
    @State private var pulse = false
    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "faceid")
                    .font(.system(size: 64, weight: .light))
                    .symbolEffect(.pulse, options: .repeating)
                Text("Caudal está bloqueada").font(.title3.weight(.semibold))
                Button("Desbloquear", action: unlock)
                    .buttonStyle(.borderedProminent).controlSize(.large)
            }
        }
        .onAppear { pulse.toggle() }
    }
}
