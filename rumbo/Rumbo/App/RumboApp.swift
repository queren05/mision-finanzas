import SwiftUI
import LocalAuthentication

@main
struct RumboApp: App {
    @State private var store = Store.shared
    @State private var locked = false
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView().scrollIndicators(.hidden)
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
                if !ProcessInfo.processInfo.arguments.contains("-demo") && !ProcessInfo.processInfo.arguments.contains("-testadd") && !ProcessInfo.processInfo.arguments.contains("-tab") { store.scheduleNotifications() }
                if store.s.settings.faceID { locked = true; unlock() }
            }
            .onChange(of: phase) { _, p in
                if p == .background { store.saveNow(); if store.s.settings.faceID { locked = true }; if store.jellyfinLinked { Jellyfin.scheduleRefresh() } }
                if p == .active { Task { await store.loadAgenda(); try? await store.syncJellyfin() }; if locked { unlock() } }
            }
        }
        .backgroundTask(.appRefresh(Jellyfin.refreshTask)) {
            await MainActor.run { Jellyfin.scheduleRefresh() }
            _ = try? await Store.shared.syncJellyfin()
            await MainActor.run { Store.shared.saveNow() }
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

/// páginas de la app; Hoy va siempre la primera y las demás se eligen en Personalizar
enum Page: String, CaseIterable, Identifiable {
    case hoy, cerebro, revision, cine, marca, humo
    var id: String { rawValue }
    var label: String {
        switch self {
        case .hoy: "Hoy"
        case .cerebro: "Cerebro"
        case .revision: "Revisión"
        case .cine: "Cine"
        case .marca: "Marca"
        case .humo: "Sin humo"
        }
    }
    var icon: String {
        switch self {
        case .hoy: "sun.max.fill"
        case .cerebro: "brain.head.profile"
        case .revision: "moon.stars.fill"
        case .cine: "film.stack.fill"
        case .marca: "paintpalette.fill"
        case .humo: "wind"
        }
    }
    @MainActor @ViewBuilder var view: some View {
        switch self {
        case .hoy: TodayView()
        case .cerebro: BrainView()
        case .revision: ReviewView()
        case .cine: LibraryView()
        case .marca: BrandView()
        case .humo: SmokeView()
        }
    }
}

extension Router {
    /// va a la pestaña o, si no está en la barra, la abre por encima
    func open(_ page: String) {
        if page == "hoy" || Store.shared.s.settings.tabs.contains(page) { tab = page } else { sheetPage = page }
    }
}

struct RootView: View {
    @Environment(Store.self) private var store
    @State private var router = Router.shared

    var body: some View {
        @Bindable var router = router
        let pages = [Page.hoy] + store.s.settings.tabs.compactMap(Page.init(rawValue:))
        TabView(selection: $router.tab) {
            ForEach(pages) { p in
                p.view.tag(p.rawValue).tabItem { Label(p.label, systemImage: p.icon) }
            }
        }
        .onChange(of: router.tab) { _, _ in Haptic.select() }
        .onChange(of: store.s.settings.tabs) { _, t in if router.tab != "hoy" && !t.contains(router.tab) { router.tab = "hoy" } }
        .sheet(item: Binding(get: { router.sheetPage.flatMap(Page.init(rawValue:)) }, set: { router.sheetPage = $0?.rawValue })) { p in
            p.view.presentationDragIndicator(.visible)
        }
        .sheet(item: Binding(get: { router.rateFilm.map { RateID(id: $0) } }, set: { router.rateFilm = $0?.id })) { r in
            RateSheet(filmId: r.id)
        }
        .alert("Algo ha fallado", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("Vale") { store.error = nil }
        } message: { Text(store.error ?? "") }
        .task {
            // (capturas automáticas: -tab brain|review|library|brand|smoke, -demo rellena datos de ejemplo)
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-demo") { Demo.fill(store) }
            if let i = args.firstIndex(of: "-tab"), i + 1 < args.count {
                let map = ["brain": "cerebro", "review": "revision", "library": "cine", "brand": "marca", "smoke": "humo"]
                if let p = map[args[i + 1]] { router.open(p) }
            }
            if args.contains("-rate"), let f = store.s.films.first { router.rateFilm = f.id }
        }
    }
}

private struct RateID: Identifiable { var id: String }

/// botón del engranaje (Ajustes) que va arriba en todas las pestañas
struct SettingsButton: View {
    @State private var open = false
    @State private var demoPersonalize = false
    var body: some View {
        Button { open = true } label: { Image(systemName: "gearshape.fill") }
            .sheet(isPresented: $open) { SettingsView() }
            .sheet(isPresented: $demoPersonalize) { NavigationStack { PersonalizeView() } }
            .task {
                // (captura automática de Personalizar)
                if ProcessInfo.processInfo.arguments.contains("-personalize") && Router.shared.tab == "hoy" { demoPersonalize = true }
            }
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
                    NavigationLink { PersonalizeView() } label: { Label("Personalizar", systemImage: "slider.horizontal.below.square.and.square.filled") }
                    NavigationLink { JellyfinSettings() } label: {
                        HStack {
                            Label("Jellyfin", systemImage: "play.tv.fill")
                            Spacer()
                            if store.jellyfinLinked { Text(store.s.settings.jellyfinUser).foregroundStyle(.secondary) }
                        }
                    }
                }
                if store.s.settings.ai {
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
                    Toggle("Logros sin fumar", isOn: $store.s.settings.notifySmoke)
                }
                Section { LabeledContent("Versión", value: "1.0") }
            }
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { if store.s.settings.ai { Keychain.apiKey = key }; store.scheduleNotifications(); Haptic.success(); dismiss() }.bold()
                }
            }
            .onAppear { key = Keychain.apiKey }
        }
    }
}

/// conectar con Jellyfin para que lo que ves se apunte solo
struct JellyfinSettings: View {
    @Environment(Store.self) private var store
    @State private var url = ""
    @State private var user = ""
    @State private var pass = ""
    @State private var working = false
    @State private var result: String? = nil

    var body: some View {
        @Bindable var store = store
        Form {
            if store.jellyfinLinked {
                Section {
                    LabeledContent("Servidor", value: store.s.settings.jellyfinURL)
                    LabeledContent("Usuario", value: store.s.settings.jellyfinUser)
                    if let d = store.s.settings.jellyfinLastSync { LabeledContent("Visto por última vez", value: Day.header(Day.str(d)) + ", " + Day.time(d)) }
                }
                Section {
                    Toggle("Preguntarme qué me ha parecido", isOn: $store.s.settings.askRating)
                    Button {
                        Task {
                            working = true
                            do { let n = try await store.syncJellyfin(); result = n == 0 ? "Todo al día" : "\(n) novedades" } catch { result = error.localizedDescription }
                            working = false
                        }
                    } label: { HStack { Label("Comprobar ahora", systemImage: "arrow.triangle.2.circlepath"); if working { Spacer(); ProgressView() } } }
                    if let result { Text(result).foregroundStyle(.secondary) }
                }
                Section { Button("Desconectar", role: .destructive) { store.unlinkJellyfin(); Haptic.tap() } }
            } else {
                Section {
                    TextField("http://servidor:8096", text: $url).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Usuario", text: $user).textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("Contraseña", text: $pass)
                }
                Section {
                    Button {
                        Task {
                            working = true; result = nil
                            do { try await store.linkJellyfin(url: url, user: user, password: pass); pass = ""; Haptic.success() }
                            catch { result = error.localizedDescription; Haptic.warning() }
                            working = false
                        }
                    } label: { HStack { Text("Conectar").bold(); if working { Spacer(); ProgressView() } } }
                    .disabled(url.isEmpty || user.isEmpty || working)
                    if let result { Text(result).foregroundStyle(Color.negative) }
                }
            }
        }
        .navigationTitle("Jellyfin")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { url = store.s.settings.jellyfinURL; user = store.s.settings.jellyfinUser }
    }
}
