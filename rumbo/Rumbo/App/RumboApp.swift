import SwiftUI
import LocalAuthentication

@main
struct RumboApp: App {
    @State private var store = Store()
    @State private var locked = false
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                if locked {
                    ZStack {
                        Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
                        VStack(spacing: 16) {
                            Image(systemName: "faceid").font(.system(size: 60, weight: .light)).symbolEffect(.pulse, options: .repeating)
                            Text("Rumbo está bloqueada").font(.title3.weight(.semibold))
                            Button("Desbloquear", action: unlock).buttonStyle(.borderedProminent).controlSize(.large)
                        }
                    }
                    .transition(.opacity).zIndex(10)
                }
            }
            .environment(store)
            .environment(\.locale, Locale(identifier: "es_ES"))
            .tint(Color(hex: store.s.settings.accent))
            .preferredColorScheme(.dark)
            .onAppear {
                store.scheduleNotifications()
                if store.s.settings.faceID { locked = true; unlock() }
            }
            .onChange(of: phase) { _, p in
                if p == .background { store.saveNow(); if store.s.settings.faceID { locked = true } }
                if p == .active { Task { await store.loadAgenda() }; if locked { unlock() } }
            }
        }
    }

    private func unlock() {
        let ctx = LAContext(); var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else { locked = false; return }
        ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Desbloquea Rumbo") { ok, _ in
            DispatchQueue.main.async { if ok { withAnimation(.spring) { locked = false } } }
        }
    }
}

enum RTab: Hashable { case today, brain, review, library, brand }

struct RootView: View {
    @Environment(Store.self) private var store
    @State private var tab: RTab = .today

    var body: some View {
        TabView(selection: $tab) {
            TodayView().tag(RTab.today).tabItem { Label("Hoy", systemImage: "sun.max.fill") }
            BrainView().tag(RTab.brain).tabItem { Label("Cerebro", systemImage: "brain.head.profile") }
            ReviewView().tag(RTab.review).tabItem { Label("Revisión", systemImage: "moon.stars.fill") }
            LibraryView().tag(RTab.library).tabItem { Label("Biblioteca", systemImage: "books.vertical.fill") }
            BrandView().tag(RTab.brand).tabItem { Label("Marca", systemImage: "paintpalette.fill") }
        }
        .onChange(of: tab) { _, _ in Haptic.select() }
        .alert("Algo ha fallado", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("Vale") { store.error = nil }
        } message: { Text(store.error ?? "") }
        .task {
            // (capturas automáticas: -tab brain|review|library|brand, -demo rellena datos de ejemplo)
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-demo") { Demo.fill(store) }
            if let i = args.firstIndex(of: "-tab"), i + 1 < args.count {
                switch args[i + 1] {
                case "brain": tab = .brain
                case "review": tab = .review
                case "library": tab = .library
                case "brand": tab = .brand
                default: break
                }
            }
        }
    }
}

/// botón del engranaje (Ajustes) que va arriba en todas las pestañas
struct SettingsButton: View {
    @State private var open = false
    var body: some View {
        Button { open = true } label: { Image(systemName: "gearshape.fill") }
            .sheet(isPresented: $open) { SettingsView() }
    }
}

struct SettingsView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var key = ""
    @State private var showKey = false

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Group { if showKey { TextField("sk-ant-…", text: $key) } else { SecureField("sk-ant-…", text: $key) } }
                            .textInputAutocapitalization(.never).autocorrectionDisabled().font(.system(.body, design: .monospaced))
                        Button { showKey.toggle() } label: { Image(systemName: showKey ? "eye.slash" : "eye") }
                    }
                    Link(destination: URL(string: "https://console.anthropic.com/settings/keys")!) { Label("Conseguir una clave", systemImage: "key.fill") }
                } header: { Text("Claude") } footer: {
                    Text("La inteligencia de Rumbo (briefing, preguntar a tus documentos, revisiones, kit de marca y biblioteca) usa Claude con tu clave. Se guarda en el Llavero del iPhone. Cada uso cuesta unos céntimos en tu cuenta de Anthropic.")
                }
                Section("Tú") {
                    TextField("Tu nombre", text: $store.s.settings.name)
                    Toggle(isOn: $store.s.settings.faceID) { Label("Bloquear con Face ID", systemImage: "faceid") }
                    VStack(alignment: .leading) {
                        Text("Color")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(palette, id: \.self) { c in
                                    Circle().fill(Color(hex: c)).frame(width: 30, height: 30)
                                        .overlay(Circle().strokeBorder(.white, lineWidth: store.s.settings.accent == c ? 3 : 0))
                                        .onTapGesture { Haptic.select(); withAnimation(.spring) { store.s.settings.accent = c } }
                                }
                            }
                            .padding(3)
                        }
                    }
                }
                Section("Avisos") {
                    Toggle("Briefing por la mañana", isOn: $store.s.settings.notifyBriefing)
                    if store.s.settings.notifyBriefing { Stepper("A las \(store.s.settings.briefingHour):00", value: $store.s.settings.briefingHour, in: 5...12) }
                    Toggle("Chequeo nocturno", isOn: $store.s.settings.notifyCheckIn)
                    if store.s.settings.notifyCheckIn { Stepper("A las \(store.s.settings.checkInHour):00", value: $store.s.settings.checkInHour, in: 18...23) }
                    Toggle("Revisión semanal (domingo)", isOn: $store.s.settings.notifyWeekly)
                }
                Section { LabeledContent("Versión", value: "1.0") }
            }
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { Keychain.apiKey = key; store.scheduleNotifications(); Haptic.success(); dismiss() }.bold()
                }
            }
            .onAppear { key = Keychain.apiKey }
        }
    }
}
