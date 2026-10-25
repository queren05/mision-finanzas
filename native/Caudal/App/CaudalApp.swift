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
            .fontDesign(Look.shared.fontDesign)
            .transformEnvironment(\.dynamicTypeSize) { [size = Look.shared.typeSize] in if let size { $0 = size } }
            .preferredColorScheme(Look.shared.scheme)
            .onAppear { if store.state.settings.faceID { locked = true; unlock() }; store.updateWidgets(now: true); Task { await store.checkBackup() } }
            .alert("Hay una copia de seguridad", isPresented: Binding(get: { store.pendingRestore != nil }, set: { if !$0 { store.pendingRestore = nil } })) {
                Button("Recuperarla") { if let st = store.pendingRestore { store.restore(st) } }
                Button("No", role: .cancel) { store.pendingRestore = nil; ServerCopy.ready = true }
            } message: {
                Text("En tu servidor hay \(store.pendingRestore?.backupSummary ?? ""). Si la recuperas, sustituye lo que hay ahora en Caudal.")
            }
            .onChange(of: phase) { _, p in
                switch p {
                case .background:
                    store.saveNow()
                    let id = UIApplication.shared.beginBackgroundTask()
                    Task { _ = await store.backup(); UIApplication.shared.endBackgroundTask(id) }
                    if store.state.settings.faceID { locked = true }
                case .active:
                    store.runRecurring()
                    store.updateWidgets()
                    Task { await store.checkBackup() }
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
