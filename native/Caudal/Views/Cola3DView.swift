import SwiftUI

/// Impresiones 3D: los pedidos de la web Cola 3D, gestionados desde Caudal
struct Cola3DView: View {
    @Environment(Store.self) private var store
    @State private var c3 = C3.shared
    @State private var filtro = 0
    @State private var conexion = false
    @State private var fallo: String? = nil

    var body: some View {
        Group {
            if c3.configurado { lista } else { C3ConexionForm(primeraVez: true) }
        }
        .navigationTitle("Impresiones 3D")
        .onAppear { withAnimation { store.hideFAB = true } }
        .onDisappear { withAnimation { store.hideFAB = false } }
    }

    private var visibles: [C3Pedido] {
        switch filtro {
        case 0:
            let imp = c3.pedidos.filter { $0.estado == .imprimiendo }.sorted { $0.creado < $1.creado }
            let pen = c3.pedidos.filter { $0.estado == .pendiente }.sorted { ($0.pagado ? 0 : 1, $0.creado) < ($1.pagado ? 0 : 1, $1.creado) }
            return imp + pen
        case 1: return c3.pedidos.filter { $0.estado == .impreso || $0.estado == .entregado }
        default: return c3.pedidos
        }
    }

    private var lista: some View {
        List {
            Section {
                resumen.listRowInsets(EdgeInsets()).listRowBackground(Color.clear).listRowSeparator(.hidden)
                Picker("", selection: $filtro.animation(Motion.layout)) {
                    Text("En cola").tag(0)
                    Text("Impresos").tag(1)
                    Text("Todos").tag(2)
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0)).listRowBackground(Color.clear)
            }
            Section {
                ForEach(visibles) { p in
                    NavigationLink { C3PedidoView(id: p.id) } label: { C3Fila(p: p) }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            if !p.pagado && p.estado != .cancelado {
                                Button { cobrarRapido(p) } label: { Label("Cobrado", systemImage: "eurosign.circle.fill") }.tint(Color.income)
                            }
                        }
                }
                if visibles.isEmpty {
                    Text(filtro == 0 ? "Nada en cola" : "Sin pedidos").foregroundStyle(.secondary)
                }
            }
            Section {
                NavigationLink { C3FilamentosView() } label: {
                    fila("Filamentos", "circle.dotted.circle.fill", .orange, c3.filamentos.filter { $0.activo && $0.stock_g < 100 }.isEmpty ? "\(c3.filamentos.filter(\.activo).count)" : "Queda poco")
                }
                let sinApuntar = c3.cobrosSinApuntar
                if !sinApuntar.isEmpty {
                    NavigationLink { C3ApuntarCobros() } label: {
                        fila("Apuntar cobros en Caudal", "tray.and.arrow.down.fill", .mint, "\(sinApuntar.count) · \(Money.eur(sinApuntar.reduce(0) { $0 + $1.coste }))")
                    }
                }
                NavigationLink { C3PreciosView() } label: { fila("Precios y Bizum", "eurosign.circle.fill", .green, Money.eur(c3.ajustes.precio_defecto) + "/kg") }
                NavigationLink { C3ConexionForm(primeraVez: false) } label: { fila("Conexión y avisos", "bell.badge.fill", .red, c3.avisos ? "Activados" : "") }
                if let u = URL(string: C3.web) {
                    Link(destination: u) { fila("Abrir la web", "safari.fill", .blue, "") }.foregroundStyle(.primary)
                }
            }
            Color.clear.frame(height: 40).listRowBackground(Color.clear)
        }
        .appList()
        .refreshable { await c3.cargar() }
        .task {
            await c3.cargar()
            // mientras está abierto, se refresca solo
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                if Task.isCancelled { break }
                await c3.cargar()
            }
        }
        .overlay(alignment: .top) {
            if let e = c3.error {
                Text(e).font(.footnote.weight(.semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Color.negative.gradient, in: Capsule())
                    .padding(.top, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture { withAnimation { c3.error = nil } }
            }
        }
        .animation(Motion.layout, value: c3.error)
    }

    private func cobrarRapido(_ p: C3Pedido) {
        Haptic.tap()
        Task {
            do { try await c3.cobrar(p, store: store); Haptic.success() }
            catch { c3.error = error.localizedDescription; Haptic.warning() }
        }
    }

    private var resumen: some View {
        let imprimiendo = c3.pedidos.filter { $0.estado == .imprimiendo }
        let cola = c3.pedidos.filter { $0.estado == .pendiente || $0.estado == .imprimiendo }
        let minutos = cola.reduce(0) { $0 + $1.minutos * $1.copias }
        return HStack(spacing: 10) {
            cifra("En cola", "\(c3.pendientes)", C3.duracion(minutos), .orange)
            cifra("Imprimiendo", "\(imprimiendo.count)", imprimiendo.first?.nombre ?? "", .blue)
            cifra("Por cobrar", Money.eur(c3.porCobrar), "", .income)
        }
        .padding(.vertical, 6)
    }

    private func cifra(_ t: String, _ v: String, _ sub: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(t).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(v).font(.title3.weight(.bold)).monospacedDigit().foregroundStyle(c).contentTransition(.numericText())
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(sub.isEmpty ? " " : sub).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(12)
    }

    private func fila(_ title: String, _ icon: String, _ color: Color, _ badge: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 30, height: 30).background(color.gradient, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(title)
            Spacer()
            Text(badge).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Piezas

/// la foto de la figura, o franjas con sus colores si no hay foto
struct C3Foto: View {
    var p: C3Pedido
    var radio: CGFloat = 12
    var body: some View {
        ZStack {
            franjas
            if let u = URL(string: p.imagen), !p.imagen.isEmpty {
                AsyncImage(url: u) { fase in
                    if let img = fase.image { img.resizable().scaledToFill().transition(.opacity) }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: radio, style: .continuous))
    }
    private var franjas: some View {
        let cols = p.lineas.map(\.color).isEmpty ? ["#9aa3ad"] : p.lineas.map(\.color)
        return VStack(spacing: 2) {
            ForEach(0..<8, id: \.self) { i in Color(hex: cols[i % cols.count]).opacity(0.55 + Double(i % 3) * 0.15) }
        }
        .overlay(Text(String(p.nombreFigura.prefix(2)).uppercased()).font(.headline.weight(.heavy)).foregroundStyle(.white.opacity(0.9)))
    }
}

struct C3Chip: View {
    var estado: C3Estado
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: estado.icon).font(.caption2.weight(.bold))
            Text(estado.label)
        }
            .font(.caption.weight(.semibold))
            .lineLimit(1).fixedSize()
            .foregroundStyle(estado.color)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(estado.color.opacity(0.15), in: Capsule())
            .symbolEffect(.pulse, options: .repeating, isActive: estado == .imprimiendo)
    }
}

struct C3Fila: View {
    var p: C3Pedido
    var body: some View {
        HStack(spacing: 12) {
            C3Foto(p: p).frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 4) {
                Text(p.nombreFigura).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text("\(p.nombre) · \(p.fecha.formatted(.relative(presentation: .named)))").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                HStack(spacing: 6) {
                    C3Chip(estado: p.estado)
                    if p.estado != .cancelado {
                        Text(p.pagado ? "Pagado" : "Sin pagar").font(.caption2.weight(.bold)).foregroundStyle(p.pagado ? Color.income : Color.negative)
                    }
                }
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 4) {
                Text(Money.eur(p.coste)).font(.subheadline.weight(.bold)).monospacedDigit()
                Text(C3.gramos(p.gramos)).font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Pedido

struct C3PedidoView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var c3 = C3.shared
    let id: String
    @State private var ocupado = false
    @State private var cobrar = false
    @State private var ajustar = false
    @State private var askBorrar = false
    @State private var fallo: String? = nil

    var body: some View {
        if let p = c3.pedidos.first(where: { $0.id == id }) {
            contenido(p)
        } else {
            ContentUnavailableView("Este pedido ya no está", systemImage: "shippingbox")
        }
    }

    private func contenido(_ p: C3Pedido) -> some View {
        List {
            Section {
                C3Foto(p: p, radio: 20).frame(height: 240).listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                VStack(alignment: .leading, spacing: 6) {
                    Text(p.nombreFigura).font(.title2.weight(.bold))
                    Text("\(p.nombre) · \(p.fecha.formatted(date: .abbreviated, time: .shortened))").foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 10, leading: 4, bottom: 4, trailing: 4))
                if let u = URL(string: p.url) {
                    Link(destination: u) {
                        Label("Abrir en MakerWorld", systemImage: "arrow.up.right.square.fill")
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .foregroundStyle(.black)
                    }
                    .buttonStyle(PressableStyle())
                    .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                }
            }

            Section("Estado") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(C3Estado.allCases) { e in
                            Button {
                                guard e != p.estado else { return }
                                Haptic.select()
                                hacer { try await c3.cambiar(p, ["estado": e.rawValue]) }
                            } label: {
                                Label(e.label, systemImage: e.icon)
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 12).padding(.vertical, 9)
                                    .foregroundStyle(p.estado == e ? .white : e.color)
                                    .background(p.estado == e ? AnyShapeStyle(e.color.gradient) : AnyShapeStyle(e.color.opacity(0.14)), in: Capsule())
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                    .padding(.vertical, 4)
                }
                .disabled(ocupado)
            }

            Section("Pago") {
                HStack {
                    Text(Money.eur(p.coste)).font(.title2.weight(.bold)).monospacedDigit()
                    Spacer()
                    Text(p.pagado ? "Pagado" : "Sin pagar").font(.subheadline.weight(.bold)).foregroundStyle(p.pagado ? Color.income : Color.negative)
                }
                if p.pagado {
                    Button("Quitar pagado") { hacer { try await c3.quitarCobro(p, store: store) } }.disabled(ocupado)
                } else {
                    Button {
                        Haptic.tap()
                        hacer { try await c3.cobrar(p, store: store) }
                    } label: {
                        Label("Cobrado · \(Money.eur(p.coste))", systemImage: "eurosign.circle.fill")
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Color.income.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .foregroundStyle(.black)
                    }
                    .buttonStyle(PressableStyle())
                    .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                    .disabled(ocupado || p.coste <= 0)
                    Button { Haptic.tap(); cobrar = true } label: { Label("Otra cantidad o cuenta", systemImage: "square.and.pencil") }.disabled(ocupado)
                }
            }

            Section("Coste") {
                ForEach(Array(p.coste_detalle.lineas.enumerated()), id: \.offset) { _, l in
                    HStack(spacing: 10) {
                        Circle().fill(Color(hex: l.color)).frame(width: 14, height: 14).overlay(Circle().strokeBorder(.secondary.opacity(0.4), lineWidth: 0.5))
                        Text(l.nombre.isEmpty ? "Filamento" : l.nombre)
                        Spacer()
                        Text("\(C3.gramos(l.gramos)) × \(Money.eur(l.precio))/kg").font(.caption).foregroundStyle(.secondary).monospacedDigit()
                        Text(Money.eur(l.coste)).monospacedDigit()
                    }
                }
                if p.coste_detalle.merma > 0 {
                    LabeledContent("Purga de colores +\(Money.num(p.coste_detalle.merma_pct).replacingOccurrences(of: ",00", with: "")) %", value: Money.eur(p.coste_detalle.merma))
                }
                if p.coste_detalle.luz > 0 {
                    LabeledContent("Luz y desgaste · \(C3.duracion(p.minutos * p.copias))", value: Money.eur(p.coste_detalle.luz))
                }
                LabeledContent {
                    Text(Money.eur(p.coste)).bold().monospacedDigit()
                } label: {
                    Text(p.copias > 1 ? "Total · \(p.copias) copias · \(C3.gramos(p.gramos))" : "Total · \(C3.gramos(p.gramos))").bold()
                }
                Button { Haptic.tap(); ajustar = true } label: { Label("Ajustar gramos y tiempo", systemImage: "slider.horizontal.3") }
            }

            if !p.notas.isEmpty {
                Section("Notas") { Text(p.notas) }
            }

            Section {
                Button(role: .destructive) { Haptic.warning(); askBorrar = true } label: { Label("Borrar pedido", systemImage: "trash") }
            }
            Color.clear.frame(height: 40).listRowBackground(Color.clear)
        }
        .appList()
        .navigationBarTitleDisplayMode(.inline)
        .animation(Motion.layout, value: p)
        .sheet(isPresented: $cobrar) { C3CobrarSheet(p: p) }
        .sheet(isPresented: $ajustar) { C3AjustarSheet(p: p) }
        .confirmationDialog("¿Seguro que quieres borrar este pedido?", isPresented: $askBorrar, titleVisibility: .visible) {
            Button("Borrar", role: .destructive) {
                hacer { try await c3.borrar(p); Haptic.heavy(); dismiss() }
            }
            Button("Cancelar", role: .cancel) {}
        } message: { Text("\(p.nombreFigura) · \(p.nombre). No se puede deshacer.") }
        .alert("No se ha podido", isPresented: Binding(get: { fallo != nil }, set: { if !$0 { fallo = nil } })) {
            Button("Vale") { fallo = nil }
        } message: { Text(fallo ?? "") }
    }

    private func hacer(_ fn: @escaping () async throws -> Void) {
        ocupado = true
        Task {
            do { try await fn(); Haptic.success() } catch { fallo = error.localizedDescription; Haptic.warning() }
            ocupado = false
        }
    }
}

/// marcar pagado y, si quieres, apuntarlo como ingreso en Caudal
struct C3CobrarSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let p: C3Pedido
    @State private var importe = ""
    @State private var apuntar = true
    @State private var cuenta = ""
    @State private var ocupado = false
    @State private var fallo: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Pedido", value: "\(p.nombreFigura) · \(p.nombre)")
                    LabeledContent("Te han pagado") { TextField("0,00", text: $importe).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                }
                Section {
                    Toggle("Apuntarlo como ingreso", isOn: $apuntar.animation())
                    if apuntar { Picker("Cuenta", selection: $cuenta) { ForEach(store.accounts) { Text("\($0.icon) \($0.name)").tag($0.id) } } }
                }
                if let fallo { Text(fallo).foregroundStyle(Color.negative) }
            }
            .navigationTitle("Cobrar").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Marcar pagado") { cobrar() }.bold()
                        .disabled(ocupado || (apuntar && ((Money.parse(importe) ?? 0) <= 0 || cuenta.isEmpty)))
                }
            }
            .onAppear {
                importe = Money.num(p.coste).replacingOccurrences(of: ".", with: "")
                cuenta = C3.shared.cuentaCobros(store)
            }
        }
        .presentationDetents([.medium])
    }

    private func cobrar() {
        ocupado = true
        Task {
            do {
                try await C3.shared.cobrar(p, store: store, importe: Money.parse(importe), cuenta: cuenta, apuntar: apuntar)
                Haptic.success()
                dismiss()
            } catch {
                fallo = error.localizedDescription
                Haptic.warning()
            }
            ocupado = false
        }
    }
}

/// cambiar los gramos de cada color, el tiempo y las copias (recalcula el coste)
struct C3AjustarSheet: View {
    @Environment(\.dismiss) private var dismiss
    let p: C3Pedido
    @State private var gramos: [String] = []
    @State private var horas = ""
    @State private var mins = ""
    @State private var copias = 1
    @State private var ocupado = false
    @State private var fallo: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("Gramos por copia") {
                    ForEach(Array(p.lineas.enumerated()), id: \.offset) { i, l in
                        HStack {
                            Circle().fill(Color(hex: l.color)).frame(width: 14, height: 14)
                            Text(l.nombre.isEmpty ? "Color" : l.nombre)
                            Spacer()
                            if i < gramos.count {
                                TextField("0", text: $gramos[i]).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80)
                            }
                            Text("g").foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Tiempo por copia") {
                    HStack {
                        TextField("0", text: $horas).keyboardType(.numberPad).multilineTextAlignment(.trailing)
                        Text("h").foregroundStyle(.secondary)
                        TextField("0", text: $mins).keyboardType(.numberPad).multilineTextAlignment(.trailing)
                        Text("min").foregroundStyle(.secondary)
                    }
                    Stepper("Copias: \(copias)", value: $copias, in: 1...50)
                }
                if let fallo { Text(fallo).foregroundStyle(Color.negative) }
            }
            .navigationTitle("Ajustar").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Guardar") { guardar() }.bold().disabled(ocupado) }
            }
            .onAppear {
                gramos = p.lineas.map { Money.num($0.gramos).replacingOccurrences(of: ",00", with: "") }
                horas = p.minutos >= 60 ? "\(p.minutos / 60)" : ""
                mins = p.minutos % 60 > 0 ? "\(p.minutos % 60)" : ""
                copias = p.copias
            }
        }
    }

    private func guardar() {
        ocupado = true
        let lineas: [[String: Any]] = p.lineas.enumerated().map { i, l in
            var d: [String: Any] = ["nombre": l.nombre, "color": l.color, "gramos": Money.parse(i < gramos.count ? gramos[i] : "") ?? 0]
            d["filamento_id"] = l.filamento_id ?? NSNull()
            return d
        }
        let minutos = (Int(horas) ?? 0) * 60 + (Int(mins) ?? 0)
        Task {
            do {
                try await C3.shared.cambiar(p, ["lineas": lineas, "minutos": minutos, "copias": copias])
                Haptic.success(); dismiss()
            } catch { fallo = error.localizedDescription; Haptic.warning() }
            ocupado = false
        }
    }
}

// MARK: - Filamentos

struct C3FilamentosView: View {
    @State private var c3 = C3.shared
    @State private var editando: C3Filamento? = nil

    var body: some View {
        List {
            Section {
                ForEach(c3.filamentos) { f in
                    Button { Haptic.tap(); editando = f } label: { fila(f) }.foregroundStyle(.primary)
                }
                if c3.filamentos.isEmpty { Text("Sin filamentos").foregroundStyle(.secondary) }
            }
            Color.clear.frame(height: 40).listRowBackground(Color.clear)
        }
        .appList()
        .navigationTitle("Filamentos")
        .refreshable { await c3.cargar() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Haptic.tap(); editando = C3Filamento(peso: c3.ajustes.peso_defecto, stock_g: c3.ajustes.peso_defecto, orden: c3.filamentos.count) } label: { Image(systemName: "plus.circle.fill").font(.title3) }
            }
        }
        .sheet(item: $editando) { C3FilamentoEditor(original: $0) }
    }

    private func fila(_ f: C3Filamento) -> some View {
        let frac = min(1, max(0, f.stock_g / max(1, f.peso)))
        let poco = f.stock_g < 100
        return HStack(spacing: 12) {
            Circle().fill(Color(hex: f.color)).frame(width: 34, height: 34)
                .overlay(Circle().strokeBorder(.secondary.opacity(0.35), lineWidth: 0.5))
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(f.nombre).font(.subheadline.weight(.semibold))
                    Text(f.material).font(.caption).foregroundStyle(.secondary)
                    if !f.activo { Text("Oculto").font(.caption2.weight(.bold)).foregroundStyle(.secondary) }
                }
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.secondary.opacity(0.18))
                        Capsule().fill(poco ? Color.negative : Color(hex: f.color).opacity(0.9)).frame(width: g.size.width * frac)
                    }
                }
                .frame(height: 6)
            }
            VStack(alignment: .trailing, spacing: 3) {
                Text(C3.gramos(f.stock_g)).font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(poco ? Color.negative : .primary)
                Text(Money.eur(f.precio ?? c3.ajustes.precio_defecto)).font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
        }
        .padding(.vertical, 3)
    }
}

struct C3FilamentoEditor: View {
    @Environment(\.dismiss) private var dismiss
    let original: C3Filamento
    @State private var f = C3Filamento()
    @State private var color = Color.gray
    @State private var precio = ""
    @State private var peso = ""
    @State private var stock = ""
    @State private var ocupado = false
    @State private var askBorrar = false
    @State private var fallo: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nombre (Negro, Blanco…)", text: $f.nombre)
                    TextField("Material", text: $f.material)
                    ColorPicker("Color", selection: $color, supportsOpacity: false)
                }
                Section {
                    LabeledContent("Precio del rollo") { TextField(Money.num(C3.shared.ajustes.precio_defecto), text: $precio).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    LabeledContent("Gramos del rollo") { TextField("1000", text: $peso).keyboardType(.numberPad).multilineTextAlignment(.trailing) }
                    LabeledContent("Quedan (g)") { TextField("0", text: $stock).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    Button("Rollo nuevo: lleno") { Haptic.tap(); stock = peso.isEmpty ? "1000" : peso }
                    Toggle("Se puede elegir", isOn: $f.activo)
                }
                if !original.id.isEmpty {
                    Section { Button("Borrar filamento", role: .destructive) { Haptic.warning(); askBorrar = true } }
                }
                if let fallo { Text(fallo).foregroundStyle(Color.negative) }
            }
            .navigationTitle(original.id.isEmpty ? "Nuevo filamento" : original.nombre).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Guardar") { guardar() }.bold().disabled(ocupado || f.nombre.trimmingCharacters(in: .whitespaces).isEmpty) }
            }
            .onAppear {
                f = original
                color = Color(hex: original.color)
                precio = original.precio.map { Money.num($0) } ?? ""
                peso = "\(Int(original.peso))"
                stock = "\(Int(original.stock_g.rounded()))"
            }
            .confirmationDialog("¿Seguro que quieres borrar este filamento?", isPresented: $askBorrar, titleVisibility: .visible) {
                Button("Borrar", role: .destructive) { hacer { try await C3.shared.borrar(original) } }
                Button("Cancelar", role: .cancel) {}
            } message: { Text(original.nombre) }
        }
    }

    private func guardar() {
        var g = f
        g.color = color.hexRGB
        g.precio = precio.trimmingCharacters(in: .whitespaces).isEmpty ? nil : Money.parse(precio)
        g.peso = Money.parse(peso) ?? 1000
        g.stock_g = max(0, Money.parse(stock) ?? 0)
        hacer { try await C3.shared.guardar(g) }
    }

    private func hacer(_ fn: @escaping () async throws -> Void) {
        ocupado = true
        Task {
            do { try await fn(); Haptic.success(); dismiss() } catch { fallo = error.localizedDescription; Haptic.warning() }
            ocupado = false
        }
    }
}

// MARK: - Precios

struct C3PreciosView: View {
    @State private var c3 = C3.shared
    @State private var precio = ""
    @State private var peso = ""
    @State private var luz = ""
    @State private var merma = ""
    @State private var bizum = ""
    @State private var ocupado = false
    @State private var fallo: String? = nil
    @State private var hecho = false

    var body: some View {
        Form {
            Section {
                LabeledContent("Precio del rollo (€)") { TextField("17,99", text: $precio).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                LabeledContent("Gramos por rollo") { TextField("1000", text: $peso).keyboardType(.numberPad).multilineTextAlignment(.trailing) }
                LabeledContent("Luz y desgaste por hora (€)") { TextField("0,10", text: $luz).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                LabeledContent("Purga con varios colores (%)") { TextField("10", text: $merma).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
            }
            Section {
                LabeledContent("Teléfono para Bizum") { TextField("600 000 000", text: $bizum).keyboardType(.phonePad).multilineTextAlignment(.trailing) }
            }
            Section {
                Button {
                    guardar()
                } label: {
                    Label(hecho ? "Guardado" : "Guardar", systemImage: hecho ? "checkmark.circle.fill" : "square.and.arrow.down")
                        .contentTransition(.symbolEffect(.replace))
                }
                .disabled(ocupado)
            }
            if let fallo { Text(fallo).foregroundStyle(Color.negative) }
        }
        .appList()
        .navigationTitle("Precios y Bizum")
        .onAppear {
            let a = c3.ajustes
            precio = Money.num(a.precio_defecto)
            peso = "\(Int(a.peso_defecto))"
            luz = Money.num(a.luz_hora)
            merma = Money.num(a.merma_pct).replacingOccurrences(of: ",00", with: "")
            bizum = a.bizum
        }
    }

    private func guardar() {
        var a = c3.ajustes
        a.precio_defecto = Money.parse(precio) ?? 17.99
        a.peso_defecto = Money.parse(peso) ?? 1000
        a.luz_hora = Money.parse(luz) ?? 0
        a.merma_pct = Money.parse(merma) ?? 0
        a.bizum = bizum.trimmingCharacters(in: .whitespaces)
        ocupado = true
        Task {
            do {
                try await c3.guardar(a)
                Haptic.success(); fallo = nil
                withAnimation { hecho = true }
                try? await Task.sleep(for: .seconds(1.5))
                withAnimation { hecho = false }
            } catch { fallo = error.localizedDescription; Haptic.warning() }
            ocupado = false
        }
    }
}

// MARK: - Conexión

struct C3ConexionForm: View {
    var primeraVez: Bool
    @State private var c3 = C3.shared
    @State private var url = ""
    @State private var anon = ""
    @State private var clave = ""
    @State private var estado: String? = nil
    @State private var bien = false
    @State private var probando = false

    var body: some View {
        Form {
            Section {
                TextField("https://….supabase.co", text: $url).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("Clave anon public", text: $anon, axis: .vertical).lineLimit(1...3).textInputAutocapitalization(.never).autocorrectionDisabled().font(.footnote.monospaced())
            } header: { Text("Supabase") }
            Section {
                SecureField("Clave del taller", text: $clave)
            } header: { Text("Taller") }
            Section {
                Button {
                    probar()
                } label: {
                    HStack {
                        Text(primeraVez ? "Conectar" : "Guardar y comprobar")
                        Spacer()
                        if probando { ProgressView() }
                    }
                }
                .disabled(probando || url.isEmpty || anon.isEmpty)
                if let estado {
                    Label(estado, systemImage: bien ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(bien ? Color.income : Color.negative)
                }
            }
            Section {
                Toggle(isOn: Binding(get: { c3.avisos }, set: { v in c3.avisos = v; if v { c3.pedirPermiso(); C3.programar() } })) {
                    Label("Avisarme de pedidos nuevos", systemImage: "bell.badge.fill")
                }
            }
        }
        .appList()
        .navigationTitle(primeraVez ? "Conectar la web" : "Conexión y avisos")
        .onAppear { url = c3.url; anon = c3.anon; clave = c3.clave }
    }

    private func probar() {
        probando = true
        c3.url = url.trimmingCharacters(in: .whitespacesAndNewlines)
        c3.anon = anon.trimmingCharacters(in: .whitespacesAndNewlines)
        c3.clave = clave
        Task {
            await c3.cargar()
            if let e = c3.error {
                bien = false; estado = e
            } else if clave.isEmpty {
                bien = false; estado = "Falta la clave del taller"
            } else if await c3.comprobarClave() {
                bien = true; estado = "Conectado"
                if c3.avisos { c3.pedirPermiso(); C3.programar() }
            } else {
                bien = false; estado = "La clave del taller no es correcta"
            }
            if bien { Haptic.success() } else { Haptic.warning() }
            probando = false
        }
    }
}

extension Color {
    /// "#rrggbb"
    var hexRGB: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        func c(_ v: CGFloat) -> Int { Int((min(1, max(0, v)) * 255).rounded()) }
        return String(format: "#%02x%02x%02x", c(r), c(g), c(b))
    }
}

/// los cobros hechos desde la web (o en mano) que aún no están apuntados en Caudal: se apuntan de una vez
struct C3ApuntarCobros: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var c3 = C3.shared
    @State private var elegidos: Set<String> = []
    @State private var cuenta = ""
    @State private var porPersona = false

    var body: some View {
        let lista = c3.cobrosSinApuntar
        let total = lista.filter { elegidos.contains($0.id) }.reduce(0) { $0 + $1.coste }
        Form {
            Section {
                ForEach(lista) { p in
                    Button {
                        if elegidos.contains(p.id) { elegidos.remove(p.id) } else { elegidos.insert(p.id) }
                    } label: {
                        HStack {
                            Image(systemName: elegidos.contains(p.id) ? "checkmark.circle.fill" : "circle").foregroundStyle(elegidos.contains(p.id) ? .green : .secondary)
                            VStack(alignment: .leading) {
                                Text(p.nombreFigura).lineLimit(1)
                                Text("\(p.nombre) · \(p.fecha.formatted(.dateTime.day().month(.abbreviated)))").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(Money.eur(p.coste)).monospacedDigit()
                        }
                    }
                    .foregroundStyle(.primary)
                }
            } header: { Text("Cobrados y sin apuntar") }
            Section {
                Picker("Cuenta", selection: $cuenta) { ForEach(store.accounts) { Text("\($0.icon) \($0.name)").tag($0.id) } }
                Toggle("Uno por persona (juntar sus pedidos)", isOn: $porPersona)
            }
            Section {
                Button {
                    apuntar(lista.filter { elegidos.contains($0.id) })
                } label: { Text("Apuntar \(Money.eur(total))").bold().frame(maxWidth: .infinity) }
                .disabled(elegidos.isEmpty || cuenta.isEmpty)
                Button("No apuntar estos (ya los tengo)") { c3.marcarApuntado(Array(elegidos)); dismiss() }
                    .foregroundStyle(.secondary).disabled(elegidos.isEmpty)
            }
        }
        .navigationTitle("Apuntar cobros")
        .onAppear {
            elegidos = Set(lista.map(\.id))
            if cuenta.isEmpty { cuenta = c3.cuentaCobros(store) }
        }
    }

    private func apuntar(_ ps: [C3Pedido]) {
        let cat = store.state.categories.first { c in
            let n = c.name.lowercased()
            return c.kind == .income && (n.contains("3d") || n.contains("impres"))
        } ?? store.state.categories.first { $0.kind == .income && $0.name.lowercased().contains("otro") }
        let grupos: [[C3Pedido]] = porPersona ? Dictionary(grouping: ps) { $0.nombre.lowercased() }.values.map { $0 } : ps.map { [$0] }
        for g in grupos {
            guard let p = g.first else { continue }
            let v = g.reduce(0) { $0 + $1.coste }
            store.save(Tx(type: .income, amount: v, accountId: cuenta, categoryId: cat?.id, date: Day.str(g.map(\.fecha).max() ?? Date()), time: Day.time(Date()),
                          title: "Impresión 3D · \(p.nombre)", note: g.map(\.nombreFigura).joined(separator: ", ")))
        }
        c3.marcarApuntado(ps.map(\.id))
        Haptic.success()
        dismiss()
    }
}

// MARK: - Cobrar (marca pagado y apunta el ingreso en Caudal)

extension C3 {
    /// la cuenta donde se apuntan los cobros (la última que elegiste)
    func cuentaCobros(_ store: Store) -> String {
        let g = UserDefaults.standard.string(forKey: "c3.cuenta") ?? ""
        return store.accounts.contains { $0.id == g } ? g : (store.accounts.first?.id ?? "")
    }

    private func categoriaCobros(_ store: Store) -> Category? {
        store.state.categories.first { c in
            let n = c.name.lowercased()
            return c.kind == .income && (n.contains("3d") || n.contains("impres"))
        } ?? store.state.categories.first { $0.kind == .income && $0.name.lowercased().contains("otro") }
    }

    /// marca pagado en la web y apunta el ingreso; con apuntar = false solo lo marca
    func cobrar(_ p: C3Pedido, store: Store, importe: Double? = nil, cuenta: String? = nil, apuntar: Bool = true) async throws {
        try await cambiar(p, ["pagado": true])
        let v = importe ?? p.coste
        let c = cuenta ?? cuentaCobros(store)
        if apuntar, v > 0, !c.isEmpty {
            let t = Tx(type: .income, amount: v, accountId: c, categoryId: categoriaCobros(store)?.id, date: Day.today, time: Day.time(Date()),
                       title: "Impresión 3D · \(p.nombre)", note: p.nombreFigura)
            store.save(t)
            UserDefaults.standard.set(c, forKey: "c3.cuenta")
            var m = UserDefaults.standard.dictionary(forKey: "c3.ingresos") as? [String: String] ?? [:]
            m[p.id] = t.id
            UserDefaults.standard.set(m, forKey: "c3.ingresos")
        }
        marcarApuntado([p.id])
    }

    /// quita el pagado y, si el ingreso se apuntó desde aquí, lo borra (se puede deshacer)
    func quitarCobro(_ p: C3Pedido, store: Store) async throws {
        try await cambiar(p, ["pagado": false])
        var m = UserDefaults.standard.dictionary(forKey: "c3.ingresos") as? [String: String] ?? [:]
        if let tid = m.removeValue(forKey: p.id) {
            UserDefaults.standard.set(m, forKey: "c3.ingresos")
            if let t = store.state.txs.first(where: { $0.id == tid }) { store.delete(t) }
        }
        var ya = Set(UserDefaults.standard.stringArray(forKey: "c3.apuntados") ?? [])
        ya.remove(p.id)
        UserDefaults.standard.set(Array(ya), forKey: "c3.apuntados")
    }
}
