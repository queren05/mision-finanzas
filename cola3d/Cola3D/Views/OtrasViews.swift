import SwiftUI

// MARK: - Filamentos

struct FilamentosView: View {
    @Environment(Tienda.self) private var t
    @State private var editando: Filamento? = nil

    private var rollos: [Filamento] {
        t.filamentos.filter { t.admin || $0.activo }.sorted { ($0.activo ? 0 : 1, $0.orden) < ($1.activo ? 0 : 1, $1.orden) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HStack(spacing: 10) {
                        Cifra(etiqueta: "Colores", valor: "\(t.filamentos.filter(\.activo).count)")
                        Cifra(etiqueta: "En stock", valor: Fmt.gramos(t.filamentos.filter(\.activo).reduce(0) { $0 + $1.stock_g }))
                    }
                    if rollos.isEmpty {
                        Vacio(titulo: "Todavía no hay rollos", icono: "circle.circle")
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 12)], spacing: 12) {
                        ForEach(Array(rollos.enumerated()), id: \.element.id) { i, f in
                            Button { if t.admin { editando = f } } label: { FilaRollo(f: f, admin: t.admin) }
                                .buttonStyle(Encoger())
                                .disabled(!t.admin)
                                .transition(.opacity.combined(with: .offset(y: 12)))
                        }
                    }
                }
                .padding(16)
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: rollos)
            }
            .background(Color(.systemGroupedBackground))
            .refreshable { await t.cargar() }
            .navigationTitle("Filamentos")
            .toolbar {
                if t.admin {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { editando = Filamento() } label: { Image(systemName: "plus.circle.fill").font(.title3) }.accessibilityLabel("Añadir rollo")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) { BotonCuenta() }
            }
            .sheet(item: $editando) { f in EditorRollo(f: f) }
        }
    }
}


private struct FilaRollo: View {
    let f: Filamento
    let admin: Bool
    @State private var giro = false
    var body: some View {
        let frac = min(1, max(0, f.stock_g / max(1, f.peso)))
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color(hex: f.color)).frame(width: 52, height: 52)
                    .overlay(Circle().strokeBorder(.primary.opacity(0.15)))
                Circle().fill(Color(.secondarySystemGroupedBackground)).frame(width: 18, height: 18)
                Circle().trim(from: 0, to: frac).stroke(Color.hot, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 60, height: 60).rotationEffect(.degrees(-90))
            }
            .rotationEffect(.degrees(giro ? 360 : 0))
            .onAppear { withAnimation(.easeOut(duration: 1.1)) { giro = true } }
            VStack(alignment: .leading, spacing: 4) {
                Text(f.nombre).font(.headline).foregroundStyle(.primary).lineLimit(1)
                HStack(spacing: 6) {
                    Text(f.material).font(.caption.weight(.bold)).padding(.horizontal, 7).padding(.vertical, 2).background(Color(.tertiarySystemFill), in: Capsule())
                    if admin { Text(f.precio.map { Fmt.eur($0) } ?? "Precio general").font(.caption).foregroundStyle(.secondary) }
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 2) {
                Text(Fmt.gramos(f.stock_g)).font(.system(.subheadline, design: .monospaced).weight(.semibold)).foregroundStyle(.primary)
                if !f.activo { Text("Se ha acabado").font(.caption2.weight(.bold)).foregroundStyle(.red) }
                else if f.stock_g < 100 { Text("Queda poco").font(.caption2.weight(.bold)).foregroundStyle(.orange) }
            }
        }
        .padding(14)
        .tarjeta()
        .opacity(f.activo ? 1 : 0.55)
    }
}

private struct EditorRollo: View {
    @Environment(Tienda.self) private var t
    @Environment(\.dismiss) private var cerrar
    @State var f: Filamento
    @State private var color = Color.gray
    @State private var precio = ""
    @State private var peso = ""
    @State private var stock = ""
    @State private var borrar = false
    @State private var ocupado = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        Circle().fill(color).frame(width: 90, height: 90).overlay(Circle().strokeBorder(.primary.opacity(0.15)))
                            .overlay(Circle().fill(Color(.systemBackground)).frame(width: 26, height: 26))
                            .shadow(color: color.opacity(0.5), radius: 16, y: 6)
                            .animation(.spring, value: color)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                Section {
                    TextField("Nombre (Negro, Blanco…)", text: $f.nombre)
                    TextField("Material", text: $f.material).textInputAutocapitalization(.characters)
                    ColorPicker("Color", selection: $color, supportsOpacity: false)
                }
                Section {
                    LabeledContent("Precio del rollo (€)") {
                        TextField(Fmt.num(t.ajustes.precio_defecto), text: $precio).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Trae (g)") { TextField("1000", text: $peso).keyboardType(.numberPad).multilineTextAlignment(.trailing) }
                    LabeledContent("Quedan (g)") { TextField("0", text: $stock).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    Button("+1 rollo") {
                        let p = Fmt.leer(peso) ?? 1000
                        stock = Fmt.num((Fmt.leer(stock) ?? 0) + p, 1)
                        if !f.activo { f.activo = true }
                    }
                    Toggle("Se puede elegir", isOn: $f.activo)
                }
                if !f.id.isEmpty {
                    Section {
                        Button("Borrar rollo", role: .destructive) { borrar = true }
                            .confirmationDialog("¿Borrar este rollo?", isPresented: $borrar, titleVisibility: .visible) {
                                Button("Sí, borrar", role: .destructive) { Task { if await t.borrar(f) { cerrar() } } }
                            }
                    }
                }
            }
            .navigationTitle(f.id.isEmpty ? "Rollo nuevo" : f.nombre)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cerrar() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        var n = f
                        n.color = color.hex
                        n.precio = Fmt.leer(precio)
                        n.peso = Fmt.leer(peso) ?? 1000
                        n.stock_g = Fmt.leer(stock) ?? n.peso
                        if n.material.trimmingCharacters(in: .whitespaces).isEmpty { n.material = "PLA" }
                        ocupado = true
                        Task { if await t.guardar(n) { cerrar() }; ocupado = false }
                    }
                    .bold()
                    .disabled(f.nombre.trimmingCharacters(in: .whitespaces).isEmpty || ocupado)
                }
            }
            .onAppear {
                color = Color(hex: f.color)
                precio = f.precio.map { Fmt.num($0) } ?? ""
                peso = Fmt.num(f.peso, 0)
                stock = f.id.isEmpty ? "" : Fmt.num(f.stock_g, 1)
            }
        }
    }
}

// MARK: - Gente

struct GenteView: View {
    @Environment(Tienda.self) private var t

    struct Persona: Identifiable, Hashable {
        var id: String
        var nombre: String
        var pedidos: [Pedido] = []
        var gastado = 0.0, enCola = 0.0, debe = 0.0, pagado = 0.0, gramos = 0.0
        var mio = false
        var ultimo = Date.distantPast
    }

    private var gente: [Persona] {
        var m: [String: Persona] = [:]
        for p in t.pedidos {
            let k = p.nombre.trimmingCharacters(in: .whitespaces).lowercased()
            var x = m[k] ?? Persona(id: k, nombre: p.nombre)
            x.pedidos.append(p)
            if p.hecho { x.gastado += p.coste; x.gramos += p.gramos }
            if p.estado != .cancelado { if p.pagado { x.pagado += p.coste } else { x.debe += p.coste } }
            if t.esMio(p) { x.mio = true }
            if p.estado == .pendiente || p.estado == .imprimiendo { x.enCola += p.coste }
            x.ultimo = max(x.ultimo, p.fecha)
            m[k] = x
        }
        return m.values.sorted { $0.gastado + $0.enCola > $1.gastado + $1.enCola }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                let g = gente
                let maximo = max(1, g.map { $0.gastado + $0.enCola }.max() ?? 1)
                VStack(spacing: 16) {
                    if t.admin {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                            Cifra(etiqueta: "Cobrado", valor: Fmt.eur(g.reduce(0) { $0 + $1.pagado }), color: .green)
                            Cifra(etiqueta: "Te deben", valor: Fmt.eur(g.reduce(0) { $0 + $1.debe }), color: .red)
                        }
                    } else {
                        let mios = t.pedidos.filter { t.esMio($0) && $0.estado != .cancelado }
                        if !mios.isEmpty {
                            let debo = mios.filter { !$0.pagado }.reduce(0) { $0 + $1.coste }
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                                Cifra(etiqueta: "Has pagado", valor: Fmt.eur(mios.filter(\.pagado).reduce(0) { $0 + $1.coste }), color: .green)
                                Cifra(etiqueta: "Debes", valor: Fmt.eur(debo), color: debo > 0 ? .red : .primary)
                                Cifra(etiqueta: "En cola", valor: Fmt.eur(mios.filter { $0.estado == .pendiente || $0.estado == .imprimiendo }.reduce(0) { $0 + $1.coste }))
                            }
                        }
                    }
                    if g.isEmpty { Vacio(titulo: "Aún no ha pedido nadie", icono: "person.2") }
                    LazyVStack(spacing: 10) {
                        ForEach(g) { x in
                            NavigationLink(value: x) { FilaPersona(x: x, fraccion: (x.gastado + x.enCola) / maximo, verDeuda: t.admin || x.mio) }
                                .buttonStyle(Encoger())
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .refreshable { await t.cargar() }
            .navigationTitle("Gente")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { BotonCuenta() } }
            .navigationDestination(for: Persona.self) { x in PersonaView(x: x) }
        }
    }
}

private struct FilaPersona: View {
    let x: GenteView.Persona
    let fraccion: Double
    let verDeuda: Bool
    @State private var lleno = false
    var body: some View {
        HStack(spacing: 14) {
            Avatar(nombre: x.nombre, size: 46)
            VStack(alignment: .leading, spacing: 5) {
                Text(x.nombre).font(.headline).foregroundStyle(.primary).lineLimit(1)
                Text("\(x.pedidos.count) pedido\(x.pedidos.count == 1 ? "" : "s") · \(Fmt.hace(x.ultimo))").font(.caption).foregroundStyle(.secondary)
                GeometryReader { g in
                    Capsule().fill(Color(.tertiarySystemFill))
                        .overlay(alignment: .leading) { Capsule().fill(Color.hot.gradient).frame(width: g.size.width * (lleno ? fraccion : 0)) }
                }
                .frame(height: 5)
            }
            VStack(alignment: .trailing, spacing: 2) {
                Text(Fmt.eur(x.gastado)).font(.system(.subheadline, design: .monospaced).weight(.bold)).foregroundStyle(.primary)
                if x.debe > 0 && verDeuda { Text("\(x.mio ? "debes" : "debe") \(Fmt.eur(x.debe))").font(.caption2.weight(.bold)).foregroundStyle(.red) }
                else if x.enCola > 0 { Text("\(Fmt.eur(x.enCola)) en cola").font(.caption2).foregroundStyle(.secondary) }
            }
            .fixedSize()
        }
        .padding(14)
        .tarjeta()
        .onAppear { withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.1)) { lleno = true } }
    }
}

private struct PersonaView: View {
    @Environment(Tienda.self) private var t
    let x: GenteView.Persona
    @State private var abierto: Pedido? = nil
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    Avatar(nombre: x.nombre, size: 64)
                    VStack(alignment: .leading) {
                        Text(x.nombre).font(.title.weight(.heavy)).lineLimit(1).minimumScaleFactor(0.6)
                        Text("\(x.pedidos.count) pedido\(x.pedidos.count == 1 ? "" : "s") · \(Fmt.gramos(x.gramos)) impresos").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                    Cifra(etiqueta: "Ha pagado", valor: Fmt.eur(x.pagado))
                    Cifra(etiqueta: "En cola", valor: Fmt.eur(x.enCola))
                    if t.admin || x.mio { Cifra(etiqueta: "Debe", valor: Fmt.eur(x.debe), color: x.debe > 0 ? .red : .primary) }
                }
                VStack(spacing: 8) {
                    ForEach(x.pedidos.sorted { $0.creado > $1.creado }) { p in
                        Button { abierto = p } label: {
                            HStack(spacing: 12) {
                                Portada(p: p).frame(width: 54, height: 54).clipShape(RoundedRectangle(cornerRadius: 12))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(p.nombreFigura).font(.subheadline.weight(.semibold)).foregroundStyle(.primary).lineLimit(1)
                                    Text("\(Fmt.hace(p.fecha)) · \(Fmt.gramos(p.gramos))").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 4)
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(Fmt.eur(p.coste)).font(.system(.subheadline, design: .monospaced).weight(.semibold)).foregroundStyle(.primary)
                                        .strikethrough(p.estado == .cancelado)
                                    Chip(estado: p.estado)
                                }
                            }
                            .padding(10).tarjeta()
                        }
                        .buttonStyle(Encoger())
                    }
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(x.nombre)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $abierto) { p in DetallePedido(id: p.id) }
    }
}

// MARK: - Taller (solo la cuenta del dueño)

struct TallerView: View {
    @Environment(Tienda.self) private var t
    @State private var precio = ""
    @State private var peso = ""
    @State private var luz = ""
    @State private var merma = ""
    @State private var bizum = ""
    @State private var ocupado = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                        Cifra(etiqueta: "Por cobrar", valor: Fmt.eur(t.pedidos.filter { !$0.pagado && $0.estado != .cancelado }.reduce(0) { $0 + $1.coste }), color: .red)
                        Cifra(etiqueta: "Cobrado", valor: Fmt.eur(t.pedidos.filter { $0.pagado && $0.estado != .cancelado }.reduce(0) { $0 + $1.coste }), color: .green)
                        Cifra(etiqueta: "Por hacer", valor: "\(t.pedidos.filter { $0.estado == .pendiente || $0.estado == .imprimiendo }.count)")
                        Cifra(etiqueta: "Impreso", valor: Fmt.gramos(t.pedidos.filter(\.hecho).reduce(0) { $0 + $1.gramos }))
                    }
                    .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                }
                Section("Precios") {
                    campo("Rollo sin precio propio (€)", $precio, .decimalPad)
                    campo("Gramos por rollo", $peso, .numberPad)
                    campo("Luz y desgaste por hora (€)", $luz, .decimalPad)
                    campo("Purga con varios colores (%)", $merma, .decimalPad)
                }
                Section("Cobrar") {
                    campo("Teléfono para Bizum", $bizum, .phonePad)
                }
                Section {
                    Button {
                        var a = t.ajustes
                        a.precio_defecto = Fmt.leer(precio) ?? 17.99
                        a.peso_defecto = Fmt.leer(peso) ?? 1000
                        a.luz_hora = Fmt.leer(luz) ?? 0
                        a.merma_pct = Fmt.leer(merma) ?? 0
                        a.bizum = bizum.trimmingCharacters(in: .whitespaces)
                        ocupado = true
                        Task { _ = await t.guardar(a); ocupado = false }
                    } label: {
                        HStack { Spacer(); if ocupado { ProgressView() } else { Text("Guardar").bold() }; Spacer() }
                    }
                    .disabled(ocupado)
                }
                Section {
                    Link(destination: URL(string: Supa.web)!) { Label("Abrir la web", systemImage: "safari") }
                }
            }
            .navigationTitle("Taller")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { BotonCuenta() } }
            .onAppear(perform: rellenar)
            .onChange(of: t.ajustes) { _, _ in rellenar() }
        }
    }

    private func rellenar() {
        let a = t.ajustes
        precio = Fmt.num(a.precio_defecto); peso = Fmt.num(a.peso_defecto, 0); luz = Fmt.num(a.luz_hora)
        merma = Fmt.num(a.merma_pct); bizum = a.bizum
    }

    private func campo(_ titulo: String, _ v: Binding<String>, _ teclado: UIKeyboardType) -> some View {
        LabeledContent(titulo) { TextField("", text: v).keyboardType(teclado).multilineTextAlignment(.trailing) }
    }
}
