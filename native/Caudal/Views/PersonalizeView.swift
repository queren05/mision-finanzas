import SwiftUI

/// Personalizar: tema, color, letra, tarjetas, fondo, barra de abajo, Gotita, icono y cómo se siente la app.
/// Por defecto todo está como ha sido siempre.
struct PersonalizeView: View {
    @Environment(Store.self) private var store
    @State private var askReset = false

    static let themes: [(id: String, name: String)] = [("dark", "Oscuro"), ("light", "Claro"), ("system", "Automático")]
    static let fonts: [(id: String, name: String)] = [("sencilla", "Normal"), ("burbuja", "Redonda"), ("elegante", "Elegante"), ("maquina", "Máquina")]
    static let sizes: [(id: String, name: String)] = [("pequena", "Pequeña"), ("normal", "Normal"), ("grande", "Grande")]
    static let cards: [(id: String, name: String)] = [("solida", "Sólidas"), ("cristal", "Cristal"), ("contorno", "Contorno")]
    static let corners: [(id: String, name: String)] = [("suaves", "Suaves"), ("redondas", "Redondas"), ("muy", "Muy redondas")]
    static let densities: [(id: String, name: String)] = [("comoda", "Cómodo"), ("compacta", "Compacto")]
    static let backgrounds: [(id: String, name: String)] = [("liso", "Liso"), ("agua", "Agua"), ("brillo", "Brillo"), ("puntos", "Puntos")]

    static func design(_ id: String) -> Font.Design {
        switch id { case "burbuja": .rounded; case "elegante": .serif; case "maquina": .monospaced; default: .default }
    }

    var body: some View {
        let s = store.state.settings
        List {
            Section { preview }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

            Section("Tema") {
                segmented(Self.themes, bind(\.theme))
                Toggle(isOn: bind(\.amoled)) { Label("Negro puro", systemImage: "moon.stars.fill") }
                    .disabled(s.theme == "light")
            }

            Section("Color") {
                ColorRow(color: bind(\.accent))
                ColorPicker(selection: Binding(get: { Color(hex: store.state.settings.accent) }, set: { store.state.settings.accent = $0.hexString }), supportsOpacity: false) {
                    Label("Color libre", systemImage: "eyedropper.halffull")
                }
            }

            Section("Letra") {
                tiles(Self.fonts, bind(\.font)) { id in
                    VStack(spacing: 1) {
                        Text("Aa").font(.system(size: 26, weight: .bold, design: Self.design(id)))
                        Text("12,50 €").font(.system(size: 11, weight: .semibold, design: Self.design(id))).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.primary.opacity(0.05))
                }
                segmented(Self.sizes, bind(\.textSize))
            }

            Section("Tarjetas") {
                tiles(Self.cards, bind(\.cardStyle), columns: 3) { id in
                    ZStack {
                        AppBackground(style: "brillo")
                        cardSample(id)
                    }
                }
                LabeledContent("Esquinas") { menu(Self.corners, bind(\.corners)) }
                LabeledContent("Espacio") { menu(Self.densities, bind(\.density)) }
            }

            Section("Fondo") {
                tiles(Self.backgrounds, bind(\.background)) { id in AppBackground(style: id) }
            }

            Section("Barra de abajo") {
                NavigationLink { TabsCustomizer() } label: {
                    HStack(spacing: 8) {
                        Label("Pestañas", systemImage: "dock.rectangle")
                        Spacer()
                        ForEach(s.tabs, id: \.self) { id in
                            Image(systemName: MainTab.names[id]?.icon ?? "square").foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }

            Section("Gotita") {
                Toggle(isOn: bind(\.mascot)) {
                    HStack(spacing: 10) {
                        Gotita(mood: s.mascot ? .happy : .sleepy, size: 34)
                        Text("Gotita en Inicio")
                    }
                }
                if s.mascot {
                    tiles(mascotHats, bind(\.mascotHat)) { id in
                        Gotita(mood: id == s.mascotHat ? .love : .happy, size: 50, hat: id)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.primary.opacity(0.05))
                    }
                    mascotColors
                }
            }

            Section("Icono") { icons }

            Section("Importes") {
                Toggle(isOn: bind(\.hideCents)) { Label("Sin céntimos", systemImage: "eurosign.circle") }
            }

            Section("Experiencia") {
                Toggle(isOn: bind(\.haptics)) { Label("Vibración", systemImage: "iphone.radiowaves.left.and.right") }
                Toggle(isOn: bind(\.sounds)) { Label("Sonidos", systemImage: "speaker.wave.2.fill") }
                    .onChange(of: s.sounds) { _, on in if on { Sound.play("plop") } }
                Toggle(isOn: bind(\.ripple)) { Label("Onda al tocar", systemImage: "drop.circle") }
                Toggle(isOn: bind(\.reducedMotion)) { Label("Menos animaciones", systemImage: "figure.walk.motion") }
            }

            Section {
                Button(role: .destructive) { askReset = true } label: { Label("Volver al estilo de siempre", systemImage: "arrow.uturn.backward") }
            }
            Color.clear.frame(height: 40).listRowBackground(Color.clear)
        }
        .appList()
        .navigationTitle("Personalizar")
        .confirmationDialog("¿Volver al estilo de siempre?", isPresented: $askReset, titleVisibility: .visible) {
            Button("Volver al estilo de siempre", role: .destructive) {
                Haptic.heavy()
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { Look.reset(&store.state.settings) }
                AppIcons.set("")
            }
        }
    }

    // MARK: vista previa

    private var preview: some View {
        let L = Look.shared
        return ZStack {
            AppBackground()
            VStack(spacing: 10 * L.space) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Patrimonio").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        AmountText(value: store.netWorth, font: .system(size: 30, weight: .bold, design: L.fontDesign ?? .rounded))
                            .lineLimit(1).minimumScaleFactor(0.6)
                    }
                    Spacer()
                    if store.state.settings.mascot { Gotita(mood: .happy, size: 52) }
                }
                .card()
                HStack(spacing: 12) {
                    IconBubble(icon: "☕️", color: "#f0c46a", size: 38)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Café").font(.body.weight(.semibold))
                        Text("Hoy · 09:41").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(store.hideAmounts ? "•••• €" : Money.eur(-2.5)).font(.body.weight(.semibold)).monospacedDigit()
                }
                .card(12)
            }
            .padding(14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Color.primary.opacity(0.08)))
        .padding(.vertical, 4)
    }

    private func cardSample(_ style: String) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12 * Look.shared.cornerScale, style: .continuous)
        return VStack(alignment: .leading, spacing: 4) {
            Capsule().fill(Color.primary.opacity(0.5)).frame(width: 30, height: 5)
            Capsule().fill(Color.accentColor).frame(width: 46, height: 7)
        }
        .padding(10)
        .frame(width: 78, height: 42, alignment: .leading)
        .background {
            switch style {
            case "cristal": shape.fill(.ultraThinMaterial).overlay(shape.strokeBorder(Color.primary.opacity(0.12)))
            case "contorno": shape.strokeBorder(Color.primary.opacity(0.3), lineWidth: 1.2)
            default: shape.fill(Color.cardBG)
            }
        }
    }

    // MARK: Gotita

    private var mascotColors: some View {
        let cur = store.state.settings.mascotColor
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                Button { Haptic.select(); withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { store.state.settings.mascotColor = "" } } label: {
                    Image(systemName: "paintpalette.fill").font(.system(size: 14, weight: .bold)).foregroundStyle(.black)
                        .frame(width: 32, height: 32).background(Color.accentColor, in: Circle())
                        .overlay(Circle().strokeBorder(Color.primary, lineWidth: cur.isEmpty ? 3 : 0))
                        .scaleEffect(cur.isEmpty ? 1.15 : 1)
                }
                .buttonStyle(.plain)
                ForEach(palette + ["#7fd3ff", "#ffffff"], id: \.self) { c in
                    Button { Haptic.select(); withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { store.state.settings.mascotColor = c } } label: {
                        Circle().fill(Color(hex: c)).frame(width: 32, height: 32)
                            .overlay(Circle().strokeBorder(Color.primary, lineWidth: cur == c ? 3 : 0))
                            .scaleEffect(cur == c ? 1.15 : 1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 6).padding(.horizontal, 2)
        }
    }

    // MARK: icono

    private var icons: some View {
        let cur = store.state.settings.appIcon
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 14) {
            ForEach(AppIcons.all, id: \.id) { ic in
                let on = cur == ic.id
                Button {
                    guard !on else { return }
                    Haptic.select()
                    store.state.settings.appIcon = ic.id
                    AppIcons.set(ic.id)
                } label: {
                    VStack(spacing: 6) {
                        Image(uiImage: UIImage(named: "icono-" + (ic.id.isEmpty ? "Original" : ic.id)) ?? UIImage())
                            .resizable().scaledToFit()
                            .frame(width: 58, height: 58)
                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(on ? Color.accentColor : Color.primary.opacity(0.1), lineWidth: on ? 3 : 1))
                            .scaleEffect(on ? 1.06 : 1)
                        Text(ic.name).font(.caption2.weight(on ? .bold : .medium)).foregroundStyle(on ? Color.accentColor : .secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: cur)
    }

    // MARK: piezas

    private func bind<T>(_ k: WritableKeyPath<Settings, T>) -> Binding<T> {
        Binding(get: { store.state.settings[keyPath: k] },
                set: { v in withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { store.state.settings[keyPath: k] = v } })
    }

    private func segmented(_ opts: [(id: String, name: String)], _ sel: Binding<String>) -> some View {
        Picker("", selection: Binding(get: { sel.wrappedValue }, set: { Haptic.select(); sel.wrappedValue = $0 })) {
            ForEach(opts, id: \.id) { Text($0.name).tag($0.id) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private func menu(_ opts: [(id: String, name: String)], _ sel: Binding<String>) -> some View {
        Picker("", selection: Binding(get: { sel.wrappedValue }, set: { Haptic.select(); sel.wrappedValue = $0 })) {
            ForEach(opts, id: \.id) { Text($0.name).tag($0.id) }
        }
        .pickerStyle(.menu)
        .labelsHidden()
    }

    private func tiles<V: View>(_ opts: [(id: String, name: String)], _ sel: Binding<String>, columns: Int = 4,
                                @ViewBuilder _ preview: @escaping (String) -> V) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columns), spacing: 12) {
            ForEach(opts, id: \.id) { o in
                let on = sel.wrappedValue == o.id
                Button {
                    Haptic.select()
                    sel.wrappedValue = o.id
                } label: {
                    VStack(spacing: 6) {
                        preview(o.id)
                            .frame(maxWidth: .infinity).frame(height: 62)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(on ? Color.accentColor : Color.primary.opacity(0.1), lineWidth: on ? 2.5 : 1))
                        Text(o.name).font(.caption.weight(on ? .bold : .medium))
                            .foregroundStyle(on ? Color.accentColor : .secondary)
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
    }
}

/// qué pestañas salen en la barra de abajo (entre Inicio y Más) y en qué orden
struct TabsCustomizer: View {
    @Environment(Store.self) private var store
    static let limit = 3

    var body: some View {
        let on = store.state.settings.tabs
        List {
            Section("En la barra") {
                fixed("Inicio", "house.fill")
                ForEach(on, id: \.self) { row($0, on: true) }
                    .onMove { from, to in
                        store.state.settings.tabs.move(fromOffsets: from, toOffset: to)
                        Haptic.select()
                    }
                fixed("Más", "ellipsis.circle.fill")
            }
            Section("Añadir") {
                ForEach(Settings.allTabs.filter { !on.contains($0) }, id: \.self) { row($0, on: false) }
            }
        }
        .environment(\.editMode, .constant(.active))
        .appList()
        .navigationTitle("Barra de abajo")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: on)
    }

    private func fixed(_ name: String, _ icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill").font(.title3).foregroundStyle(.tertiary).frame(width: 28)
            Image(systemName: icon).foregroundStyle(.secondary).frame(width: 26)
            Text(name).foregroundStyle(.secondary)
        }
        .moveDisabled(true)
    }

    private func row(_ id: String, on: Bool) -> some View {
        let info = MainTab.names[id] ?? (id, "square")
        let full = !on && store.state.settings.tabs.count >= TabsCustomizer.limit
        return HStack(spacing: 12) {
            Button {
                Haptic.select()
                if on { store.state.settings.tabs.removeAll { $0 == id } } else if !full { store.state.settings.tabs.append(id) }
            } label: {
                Image(systemName: on ? "minus.circle.fill" : "plus.circle.fill")
                    .font(.title2).foregroundStyle(on ? Color.red : full ? Color.gray : Color.green)
            }
            .buttonStyle(.plain)
            .frame(width: 28)
            Image(systemName: info.icon).foregroundStyle(Color.accentColor).frame(width: 26)
            Text(info.name)
        }
    }
}
