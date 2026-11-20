import SwiftUI
import PhotosUI

/// todo lo que ha salido de la impresora, con las fotos de cómo ha quedado
struct VitrinaView: View {
    @Environment(Tienda.self) private var t
    @State private var abierto: Pedido? = nil
    @State private var nueva = false
    @AppStorage("ver-vitrina") private var modo = ModoVista.grande.rawValue
    @State private var orden = Orden.recientes
    @State private var soloFotos = false
    @State private var soloGuardadas = false
    @State private var persona = ""
    @State private var tamano = Tamano.todos
    @State private var precio = Precio.todos

    enum Orden: String, CaseIterable { case recientes = "Recientes", gustan = "Más gustan", grandes = "Más grandes", caras = "Más caras" }
    enum Tamano: String, CaseIterable {
        case todos = "Cualquier tamaño", p = "Pequeñas (< 50 g)", m = "Medianas (50–200 g)", g = "Grandes (> 200 g)"
        func vale(_ g: Double) -> Bool { switch self { case .todos: true; case .p: g < 50; case .m: g >= 50 && g <= 200; case .g: g > 200 } }
    }
    enum Precio: String, CaseIterable {
        case todos = "Cualquier precio", uno = "Hasta 1 €", cinco = "De 1 a 5 €", mas = "Más de 5 €"
        func vale(_ c: Double) -> Bool { switch self { case .todos: true; case .uno: c <= 1; case .cinco: c > 1 && c <= 5; case .mas: c > 5 } }
    }

    /// cuándo se terminó de imprimir
    private func cuando(_ p: Pedido) -> String {
        p.historial.last { $0.estado == .impreso }?.fecha ?? (p.actualizado.isEmpty ? p.creado : p.actualizado)
    }

    private var hechas: [Pedido] { t.pedidos.filter(\.hecho) }
    private var filtrando: Bool { soloFotos || soloGuardadas || !persona.isEmpty || tamano != .todos || precio != .todos }

    private func filtrar(_ todas: [Pedido]) -> [Pedido] {
        let l = todas.filter {
            (!soloFotos || !$0.fotos.isEmpty) && (!soloGuardadas || t.guardados.contains($0.id)) &&
                (persona.isEmpty || $0.nombre.lowercased() == persona) && tamano.vale($0.gramos) && precio.vale($0.coste)
        }
        let gusta = { (p: Pedido) in t.votos[p.id]?.count ?? 0 }
        return l.sorted { a, b in
            switch orden {
            case .gustan where gusta(a) != gusta(b): return gusta(a) > gusta(b)
            case .grandes where a.gramos != b.gramos: return a.gramos > b.gramos
            case .caras where a.coste != b.coste: return a.coste > b.coste
            default: return cuando(a) > cuando(b)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                let todas = hechas
                let lista = filtrar(todas)
                VStack(spacing: 16) {
                    if !todas.isEmpty {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                            Cifra(etiqueta: "Piezas", valor: "\(todas.reduce(0) { $0 + max(1, $1.copias) })")
                            Cifra(etiqueta: "Filamento", valor: Fmt.gramos(todas.reduce(0) { $0 + $1.gramos }))
                            Cifra(etiqueta: "Imprimiendo", valor: Fmt.num(Double(todas.reduce(0) { $0 + $1.minutos * max(1, $1.copias) }) / 60, 1) + " h")
                            Cifra(etiqueta: "Fotos", valor: "\(todas.reduce(0) { $0 + $1.fotos.count })")
                        }
                        filtros(todas)
                    }
                    if t.cargado && lista.isEmpty {
                        Vacio(titulo: todas.isEmpty ? "Aún no se ha impreso nada" : soloGuardadas ? "No has guardado ninguna" : "Nada con estos filtros", icono: "square.grid.2x2")
                    } else {
                        // dos columnas que se van llenando como un mosaico
                        if modo == ModoVista.lista.rawValue {
                            LazyVStack(spacing: 10) {
                                ForEach(lista) { p in
                                    FilaLista(p: p).contentShape(Rectangle()).onTapGesture { abierto = p }.accessibilityAddTraits(.isButton)
                                }
                            }
                        } else {
                        let cols = modo == ModoVista.pequena.rawValue ? 3 : 2
                        HStack(alignment: .top, spacing: cols == 3 ? 8 : 10) {
                            ForEach(0..<cols, id: \.self) { col in
                                LazyVStack(spacing: 10) {
                                    ForEach(Array(lista.enumerated()).filter { $0.offset % cols == col }, id: \.element.id) { i, p in
                                        Pieza(p: p, alto: cols == 3 ? ((i / cols + col) % 2 == 0 ? 130 : 100) : ((i / 2 + col) % 2 == 0 ? 220 : 170), cuando: Fmt.fecha(cuando(p)) ?? p.fecha, compacta: cols == 3)
                                            .contentShape(RoundedRectangle(cornerRadius: 20))
                                            .onTapGesture { abierto = p }
                                            .accessibilityAddTraits(.isButton)
                                            .transition(.scale(scale: 0.92).combined(with: .opacity))
                                    }
                                }
                            }
                        }
                        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: lista.map(\.id))
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .refreshable { await t.cargar() }
            .navigationTitle("Vitrina")
            .toolbar {
                if t.admin {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { nueva = true } label: { Label("Añadir pieza", systemImage: "plus.circle.fill") }
                    }
                }
                ToolbarItem(placement: .topBarLeading) { MenuVista(modo: $modo) }
                ToolbarItem(placement: .topBarTrailing) { BotonCuenta() }
            }
            .sheet(item: $abierto) { p in DetallePedido(id: p.id) }
            .sheet(isPresented: $nueva) { NuevaPieza { id in abierto = t.pedidos.first { $0.id == id } } }
        }
    }

    private func filtros(_ todas: [Pedido]) -> some View {
        let personas = Dictionary(todas.map { ($0.nombre.lowercased(), $0.nombre) }, uniquingKeysWith: { a, _ in a }).sorted { $0.value < $1.value }
        return VStack(alignment: .leading, spacing: 10) {
            Picker("Orden", selection: $orden.animation(.snappy)) {
                ForEach(Orden.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ChipFiltro(texto: "Con foto", icono: "camera.fill", activo: soloFotos) { withAnimation(.snappy) { soloFotos.toggle() } }
                    if t.sesion != nil {
                        ChipFiltro(texto: t.guardados.isEmpty ? "Guardadas" : "Guardadas · \(t.guardados.count)", icono: soloGuardadas ? "bookmark.fill" : "bookmark", activo: soloGuardadas) {
                            withAnimation(.snappy) { soloGuardadas.toggle() }
                        }
                    }
                    Menu {
                        Button("De todos") { withAnimation { persona = "" } }
                        ForEach(personas, id: \.key) { k, n in Button(n) { withAnimation { persona = k } } }
                    } label: { EtiquetaChip(texto: personas.first { $0.key == persona }?.value ?? "De todos", activo: !persona.isEmpty) }
                    Menu {
                        ForEach(Tamano.allCases, id: \.self) { x in Button(x.rawValue) { withAnimation { tamano = x } } }
                    } label: { EtiquetaChip(texto: tamano.rawValue, activo: tamano != .todos) }
                    Menu {
                        ForEach(Precio.allCases, id: \.self) { x in Button(x.rawValue) { withAnimation { precio = x } } }
                    } label: { EtiquetaChip(texto: precio.rawValue, activo: precio != .todos) }
                    if filtrando {
                        Button("Quitar filtros") { withAnimation { soloFotos = false; soloGuardadas = false; persona = ""; tamano = .todos; precio = .todos } }
                            .font(.subheadline.weight(.semibold)).padding(.horizontal, 12).padding(.vertical, 8)
                            .overlay(Capsule().strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3])).foregroundStyle(.secondary))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

/// botón de filtro que se enciende
struct ChipFiltro: View {
    let texto: String
    var icono: String? = nil
    let activo: Bool
    let accion: () -> Void
    var body: some View {
        Button(action: accion) { EtiquetaChip(texto: texto, icono: icono, activo: activo, flecha: false) }
            .buttonStyle(Encoger())
            .sensoryFeedback(.selection, trigger: activo)
    }
}

struct EtiquetaChip: View {
    let texto: String
    var icono: String? = nil
    let activo: Bool
    var flecha = true
    var body: some View {
        HStack(spacing: 5) {
            if let icono { Image(systemName: icono) }
            Text(texto).lineLimit(1)
            if flecha { Image(systemName: "chevron.down").font(.caption2.weight(.bold)) }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(activo ? Color.hot : .primary)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(activo ? Color.hot.opacity(0.14) : Color(.secondarySystemGroupedBackground), in: Capsule())
        .overlay(Capsule().strokeBorder(activo ? Color.hot.opacity(0.5) : Color.primary.opacity(0.1)))
        .fixedSize()
    }
}

/// corazón con contador
struct BotonGusta: View {
    @Environment(Tienda.self) private var t
    let p: Pedido
    var grande = false
    var body: some View {
        let mio = t.meGusta(p)
        let n = t.votos[p.id]?.count ?? 0
        Button { Task { await t.votar(p) } } label: {
            HStack(spacing: 5) {
                Image(systemName: mio ? "heart.fill" : "heart")
                    .symbolEffect(.bounce, value: mio)
                if n > 0 { Text("\(n)").contentTransition(.numericText()) }
                if grande { Text(mio ? "Te gusta" : "Me gusta") }
            }
            .font((grande ? Font.body : .footnote).weight(.bold))
            .foregroundStyle(mio ? Color.pink : .secondary)
            .padding(.horizontal, grande ? 16 : 10).padding(.vertical, grande ? 11 : 6)
            .background(mio ? Color.pink.opacity(0.13) : Color(.tertiarySystemFill), in: Capsule())
        }
        .buttonStyle(Encoger())
        .sensoryFeedback(.impact(weight: .light), trigger: mio)
        .accessibilityLabel(mio ? "Quitar me gusta" : "Me gusta")
    }
}

/// marcador para guardar la pieza: menú con tus listas (o una nueva)
struct BotonGuardar: View {
    @Environment(Tienda.self) private var t
    let p: Pedido
    var grande = false
    @State private var nueva = false
    @State private var nombre = ""
    var body: some View {
        let mias = t.listasDe(p)
        let si = !mias.isEmpty
        Menu {
            Section("Guardar en") {
                ForEach(t.nombresListas, id: \.self) { l in
                    Button { Task { await t.guardar(p, en: l) } } label: {
                        if mias.contains(l) { Label(l, systemImage: "checkmark") } else { Text(l) }
                    }
                }
            }
            Button { nombre = ""; nueva = true } label: { Label("Nueva lista…", systemImage: "plus") }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: si ? "bookmark.fill" : "bookmark").symbolEffect(.bounce, value: si)
                if grande { Text(si ? (mias.count == 1 ? mias[0] : "En \(mias.count) listas") : "Guardar").lineLimit(1) }
            }
            .font((grande ? Font.body : .footnote).weight(.bold))
            .foregroundStyle(si ? Color.hot : (grande ? .secondary : .primary))
            .padding(.horizontal, grande ? 16 : 9).padding(.vertical, grande ? 11 : 8)
            .background(grande ? AnyShapeStyle(Color(.tertiarySystemFill)) : AnyShapeStyle(.regularMaterial), in: Capsule())
        }
        .accessibilityLabel("Guardar en una lista")
        .alert("Lista nueva", isPresented: $nueva) {
            TextField("Nombre (Regalos, Para casa…)", text: $nombre)
            Button("Cancelar", role: .cancel) {}
            Button("Crear y guardar") { Task { await t.guardar(p, en: nombre) } }
        }
    }
}

private struct Pieza: View {
    @Environment(Tienda.self) private var t
    let p: Pedido
    let alto: CGFloat
    let cuando: Date
    var compacta = false
    @State private var visto = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Portada(p: p)
                .frame(height: alto)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay(alignment: .bottomLeading) {
                    Group {
                        if p.fotos.count > 1 { Label("\(p.fotos.count)", systemImage: "photo.on.rectangle") }
                        else if p.fotos.isEmpty { Text("Foto del modelo") }
                    }
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.regularMaterial, in: Capsule())
                    .padding(8)
                }
                .saturation(p.fotos.isEmpty ? 0.85 : 1)
                .overlay(alignment: .topTrailing) { if t.sesion != nil { BotonGuardar(p: p).padding(8) } }
            VStack(alignment: .leading, spacing: 6) {
                Text(p.nombreFigura).font(compacta ? .caption.weight(.bold) : .subheadline.weight(.bold)).foregroundStyle(.primary).lineLimit(2).multilineTextAlignment(.leading)
                if !compacta {
                    HStack(spacing: 5) {
                        Avatar(nombre: p.nombre, size: 16, uid: p.user_id)
                        Text("\(p.nombre) · \(Fmt.hace(cuando))").lineLimit(1)
                    }
                    .font(.caption).foregroundStyle(.secondary)
                }
                HStack {
                    if !compacta { Text(Fmt.gramos(p.gramos)).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary) }
                    Spacer(minLength: 0)
                    BotonGusta(p: p)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .tarjeta()
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.07), radius: 10, y: 4)
        .opacity(visto ? 1 : 0)
        .offset(y: visto ? 0 : 18)
        .onAppear { withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) { visto = true } }
    }
}

/// el taller sube algo que ha impreso por su cuenta: sin enlace, sin cobro, para quien quiera
private struct NuevaPieza: View {
    @Environment(Tienda.self) private var t
    @Environment(\.dismiss) private var cerrar
    let alAcabar: (String) -> Void
    @State private var titulo = ""
    @State private var para = ""
    @State private var elegidas: [PhotosPickerItem] = []
    @State private var imagenes: [UIImage] = []
    @State private var rollo = ""
    @State private var gramos = ""
    @State private var entregado = false
    @State private var enlace = ""
    @State private var notas = ""
    @State private var ocupado: String? = nil

    private var nombres: [String] {
        var vistos = Set<String>(), out: [String] = []
        for p in t.pedidos.sorted(by: { $0.creado > $1.creado }) where vistos.insert(p.nombre.lowercased()).inserted { out.append(p.nombre) }
        return out
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(imagenes.enumerated()), id: \.offset) { i, img in
                                Image(uiImage: img).resizable().scaledToFill().frame(width: 92, height: 92).clipShape(RoundedRectangle(cornerRadius: 14))
                                    .overlay(alignment: .topTrailing) {
                                        Button { withAnimation { _ = imagenes.remove(at: i) } } label: {
                                            Image(systemName: "xmark").font(.caption.weight(.bold)).padding(6).background(.regularMaterial, in: Circle())
                                        }
                                        .padding(4)
                                    }
                                    .transition(.scale.combined(with: .opacity))
                            }
                            if imagenes.count < 12 {
                                PhotosPicker(selection: $elegidas, maxSelectionCount: 12 - imagenes.count, matching: .images) {
                                    VStack(spacing: 4) {
                                        Image(systemName: "camera.fill").font(.title3)
                                        Text(imagenes.isEmpty ? "Fotos" : "Más").font(.caption.weight(.semibold))
                                    }
                                    .foregroundStyle(Color.hot)
                                    .frame(width: 92, height: 92)
                                    .background(RoundedRectangle(cornerRadius: 14).strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 5])).foregroundStyle(Color.hot.opacity(0.5)))
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                }
                Section {
                    TextField("Qué es (Jarrón espiral…)", text: $titulo)
                    HStack {
                        TextField("Para quién (vacío = el taller)", text: $para)
                        if !nombres.isEmpty {
                            Menu {
                                ForEach(nombres, id: \.self) { n in Button(n) { para = n } }
                            } label: { Image(systemName: "person.crop.circle.badge.plus").font(.title3) }
                        }
                    }
                }
                Section("Filamento gastado") {
                    Picker("Rollo", selection: $rollo) {
                        Text("Sin apuntar").tag("")
                        ForEach(t.filamentos.filter(\.activo)) { f in Text("\(f.nombre) · \(f.material)").tag(f.id) }
                    }
                    if !rollo.isEmpty {
                        LabeledContent("Gramos") { TextField("0", text: $gramos).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    }
                }
                Section {
                    Toggle("Ya está entregado", isOn: $entregado)
                    TextField("Enlace (si tiene)", text: $enlace).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Notas", text: $notas, axis: .vertical).lineLimit(1...4)
                }
            }
            .navigationTitle("Añadir a la vitrina")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cerrar() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Añadir") { Task { await guardar() } }
                        .bold().disabled(titulo.trimmingCharacters(in: .whitespaces).isEmpty || ocupado != nil)
                }
            }
            .overlay {
                if let ocupado {
                    VStack(spacing: 12) { ProgressView(); Text(ocupado).font(.subheadline.weight(.semibold)) }
                        .padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                }
            }
            .onAppear { if para.isEmpty { para = t.sesion?.nombre ?? "" } }
            .onChange(of: elegidas) { _, items in
                guard !items.isEmpty else { return }
                elegidas = []
                Task {
                    for it in items {
                        if let d = try? await it.loadTransferable(type: Data.self), let img = UIImage(data: d) { withAnimation { imagenes.append(img) } }
                    }
                }
            }
            .animation(.snappy, value: rollo)
        }
        .interactiveDismissDisabled(ocupado != nil)
    }

    private func reducir(_ img: UIImage) -> Data? {
        let k = min(1, 1600 / max(img.size.width, img.size.height))
        let tam = CGSize(width: img.size.width * k, height: img.size.height * k)
        let f = UIGraphicsImageRendererFormat(); f.scale = 1
        return UIGraphicsImageRenderer(size: tam, format: f).image { _ in img.draw(in: CGRect(origin: .zero, size: tam)) }.jpegData(compressionQuality: 0.85)
    }

    private func guardar() async {
        let carpeta = "taller-" + UUID().uuidString.lowercased()
        var urls: [String] = []
        do {
            for (i, img) in imagenes.enumerated() {
                ocupado = "Subiendo foto \(i + 1) de \(imagenes.count)…"
                if let jpg = reducir(img) { urls.append(try await t.subirFoto(jpg, carpeta: carpeta)) }
            }
            ocupado = "Guardando…"
            let f = t.filamentos.first { $0.id == rollo }
            let id = try await t.crearPieza(titulo: titulo.trimmingCharacters(in: .whitespaces), para: para.trimmingCharacters(in: .whitespaces),
                                            url: enlace.trimmingCharacters(in: .whitespaces), filamento: f, gramos: Fmt.leer(gramos) ?? 0,
                                            entregado: entregado, notas: notas.trimmingCharacters(in: .whitespacesAndNewlines), fotos: urls)
            ocupado = nil
            cerrar()
            try? await Task.sleep(for: .milliseconds(450))
            alAcabar(id)
        } catch {
            ocupado = nil
            t.avisar(error.localizedDescription, error: true)
        }
    }
}
