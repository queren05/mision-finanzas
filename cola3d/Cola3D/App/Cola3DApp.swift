import SwiftUI
import UserNotifications

@main
struct Cola3DApp: App {
    @State private var t = Tienda.shared
    @Environment(\.scenePhase) private var fase
    @AppStorage("tema") private var tema = "auto"

    init() {
        UNUserNotificationCenter.current().delegate = AvisosDelegado.shared
        // las fotos se guardan en el móvil y no se vuelven a descargar
        URLCache.shared = URLCache(memoryCapacity: 40 * 1024 * 1024, diskCapacity: 400 * 1024 * 1024)
    }

    var body: some Scene {
        WindowGroup {
            Raiz()
                .environment(t)
                .tint(.hot)
                .preferredColorScheme(tema == "claro" ? .light : tema == "oscuro" ? .dark : nil)
                .task {
                    let args = ProcessInfo.processInfo.arguments
                    if let i = args.firstIndex(of: "-tab"), i + 1 < args.count {
                        switch args[i + 1] {
                        case "pedir": t.pestana = .pedir
                        case "filamentos": t.pestana = .filamentos
                        case "gente": t.pestana = .gente
                        case "vitrina": t.pestana = .vitrina
                        case "taller": t.pestana = .taller
                        default: break
                        }
                    }
                    await t.cargar()
                    await t.comprobarAdmin()
                    if !t.demo { t.pedirPermiso() }
                }

        }
        .onChange(of: fase) { _, f in
            if f == .active { Task { await t.cargar(); await t.comprobarAdmin() } }
            if f == .background { Tienda.programar() }
        }
        .backgroundTask(.appRefresh(Tienda.tarea)) {
            Tienda.programar()
            await Tienda.shared.cargar()
        }
    }
}

final class AvisosDelegado: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AvisosDelegado()
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}

struct Raiz: View {
    @Environment(Tienda.self) private var t
    @Environment(\.scenePhase) private var fase

    var body: some View {
        @Bindable var t = t
        TabView(selection: $t.pestana) {
            ColaView()
                .tabItem { Label("Cola", systemImage: "list.bullet.rectangle.portrait") }
                .badge(t.pedidos.filter { $0.estado == .pendiente }.count)
                .tag(Tienda.Pestana.cola)
            PedirView()
                .tabItem { Label("Pedir", systemImage: "plus.circle.fill") }
                .tag(Tienda.Pestana.pedir)
            VitrinaView()
                .tabItem { Label("Vitrina", systemImage: "square.grid.2x2.fill") }
                .tag(Tienda.Pestana.vitrina)
            GenteView()
                .tabItem { Label("Gente", systemImage: "person.2.fill") }
                .tag(Tienda.Pestana.gente)
            // como mucho 5 pestañas: el taller lleva dentro los filamentos
            if t.admin {
                TallerView()
                    .tabItem { Label("Taller", systemImage: "wrench.and.screwdriver.fill") }
                    .tag(Tienda.Pestana.taller)
            } else {
                FilamentosView()
                    .tabItem { Label("Filamentos", systemImage: "circle.circle") }
                    .tag(Tienda.Pestana.filamentos)
            }
        }
        .overlay(alignment: .top) {
            if let a = t.aviso {
                Label(a.texto, systemImage: a.error ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(a.error ? .white : .primary)
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    .background(a.error ? AnyShapeStyle(Color.red.gradient) : AnyShapeStyle(.regularMaterial), in: Capsule())
                    .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
                    .padding(.top, 6)
                    .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.9)))
                    .onTapGesture { withAnimation { t.aviso = nil } }
            }
        }
        .sensoryFeedback(.success, trigger: t.aviso?.texto) { _, n in n != nil && t.aviso?.error == false }
        // la cola se refresca sola cada 20 s, solo con la app delante
        .task(id: fase) {
            guard fase == .active else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                if Task.isCancelled { break }
                await t.cargar()
            }
        }
    }
}
