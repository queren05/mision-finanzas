import SwiftUI

// MARK: - Avisos

/// campana con tus avisos (arriba, junto a tu foto)
struct BotonAvisos: View {
    @Environment(Tienda.self) private var t
    @State private var abierto = false
    var body: some View {
        if t.sesion != nil {
            Button { abierto = true } label: {
                Image(systemName: t.sinLeer > 0 ? "bell.badge.fill" : "bell")
                    .symbolRenderingMode(.multicolor)
                    .symbolEffect(.bounce, value: t.sinLeer)
                    .font(.title3)
                    .overlay(alignment: .topTrailing) {
                        if t.sinLeer > 0 {
                            Text("\(t.sinLeer)").font(.caption2.weight(.bold)).foregroundStyle(.white)
                                .padding(.horizontal, 5).padding(.vertical, 1).background(Color.hot, in: Capsule()).offset(x: 8, y: -6)
                        }
                    }
            }
            .accessibilityLabel(t.sinLeer > 0 ? "\(t.sinLeer) avisos sin leer" : "Avisos")
            .sheet(isPresented: $abierto) { AvisosView() }
        }
    }
}

private struct AvisosView: View {
    @Environment(Tienda.self) private var t
    @Environment(\.dismiss) private var cerrar
    @State private var abierto: Pedido? = nil
    var body: some View {
        NavigationStack {
            List {
                if t.avisos.isEmpty {
                    Text("Aquí te avisaré cuando tu pieza se imprima, te comenten o el taller te responda.").foregroundStyle(.secondary)
                }
                ForEach(t.avisos) { a in
                    Button {
                        if let id = a.pedido_id { abierto = t.pedidos.first { $0.id == id } }
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(a.texto).font(.subheadline.weight(a.leido ? .regular : .semibold)).foregroundStyle(.primary)
                            Text(Fmt.hace(Fmt.fecha(a.creado) ?? Date())).font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                    .listRowBackground(a.leido ? nil : Color.hot.opacity(0.1))
                }
            }
            .navigationTitle("Avisos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Cerrar") { cerrar() } } }
            .sheet(item: $abierto) { p in DetallePedido(id: p.id) }
            .task { await t.leerAvisos() }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Comentarios

struct ComentariosView: View {
    @Environment(Tienda.self) private var t
    let p: Pedido
    @State private var texto = ""
    @State private var enviando = false
    var body: some View {
        let lista = t.comentarios.filter { $0.pedido_id == p.id }
        VStack(alignment: .leading, spacing: 10) {
            Text("COMENTARIOS\(lista.isEmpty ? "" : " · \(lista.count)")").font(.caption.weight(.bold)).foregroundStyle(.secondary).tracking(0.6)
            ForEach(lista) { c in
                HStack(alignment: .top, spacing: 10) {
                    Avatar(nombre: c.nombre.isEmpty ? "?" : c.nombre, size: 30, uid: c.user_id)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(c.nombre.isEmpty ? "Alguien" : c.nombre).font(.subheadline.weight(.bold))
                            Text(Fmt.hace(Fmt.fecha(c.creado) ?? Date())).font(.caption).foregroundStyle(.secondary)
                        }
                        Text(c.texto).font(.subheadline)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color(.tertiarySystemFill), in: UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 14, bottomTrailingRadius: 14, topTrailingRadius: 14))
                    Spacer(minLength: 0)
                }
                .contextMenu {
                    if c.user_id == t.sesion?.id || t.admin {
                        Button("Borrar comentario", systemImage: "trash", role: .destructive) { Task { await t.borrarComentario(c) } }
                    }
                }
            }
            if t.sesion != nil {
                HStack(spacing: 8) {
                    TextField("Escribe un comentario…", text: $texto, axis: .vertical).lineLimit(1...4)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
                    Button {
                        enviando = true
                        Task { if await t.comentar(p, texto.trimmingCharacters(in: .whitespacesAndNewlines)) { texto = "" }; enviando = false }
                    } label: { Image(systemName: "arrow.up.circle.fill").font(.title) }
                    .disabled(texto.trimmingCharacters(in: .whitespaces).isEmpty || enviando)
                    .accessibilityLabel("Enviar comentario")
                }
            } else {
                Text("Entra con tu cuenta para comentar.").font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Ideas

struct IdeasView: View {
    @Environment(Tienda.self) private var t
    @State private var texto = ""
    var body: some View {
        if let s = t.sesion {
            let mias = t.deseos.filter { $0.user_id == s.id }
            VStack(alignment: .leading, spacing: 10) {
                Text("¿No encuentras el modelo?").font(.headline)
                Text("Cuéntame qué quieres y te busco uno para imprimir.").font(.subheadline).foregroundStyle(.secondary)
                HStack {
                    TextField("Un soporte para el móvil del coche…", text: $texto, axis: .vertical).lineLimit(1...4)
                        .padding(12).background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 14))
                    Button("Enviar") { Task { if await t.crearDeseo(texto.trimmingCharacters(in: .whitespaces)) { texto = "" } } }
                        .buttonStyle(.borderedProminent).tint(Color.hot)
                        .disabled(texto.trimmingCharacters(in: .whitespaces).count < 4)
                }
                ForEach(mias) { d in FilaIdea(d: d, taller: false) }
            }
            .padding(16).tarjeta()
        }
    }
}

struct FilaIdea: View {
    @Environment(Tienda.self) private var t
    let d: Deseo
    let taller: Bool
    @State private var enlace = ""
    @State private var nota = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                if taller { Avatar(nombre: d.nombre.isEmpty ? "?" : d.nombre, size: 22, uid: d.user_id); Text(d.nombre).font(.caption.weight(.semibold)) }
                Spacer()
                Etiqueta(texto: d.estado == "abierto" ? "Esperando respuesta" : d.estado == "encontrado" ? "¡Encontrado!" : "Respondida",
                         color: d.estado == "encontrado" ? .green : .secondary)
            }
            Text(d.texto).font(.subheadline.weight(.semibold))
            if !d.respuesta.isEmpty { Text(d.respuesta).font(.subheadline) }
            if !d.enlace.isEmpty, let u = URL(string: d.enlace) {
                Link(destination: u) { Label("Ver el modelo", systemImage: "arrow.up.right.square") }.font(.subheadline.weight(.bold))
            }
            if taller && d.estado == "abierto" {
                TextField("Enlace del modelo (https://makerworld.com/…)", text: $enlace).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(10).background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
                TextField("Nota (opcional)", text: $nota).padding(10).background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
                HStack {
                    Button("Mandar el modelo") { Task { _ = await t.responderDeseo(d, estado: "encontrado", respuesta: nota, enlace: enlace.trimmingCharacters(in: .whitespaces)) } }
                        .buttonStyle(.borderedProminent).tint(Color.hot).disabled(!enlace.hasPrefix("https://"))
                    Button("No se puede") { Task { _ = await t.responderDeseo(d, estado: "descartado", respuesta: nota, enlace: "") } }.buttonStyle(.bordered)
                }
                .font(.subheadline.weight(.semibold))
            }
            HStack {
                Text(Fmt.hace(Fmt.fecha(d.creado) ?? Date())).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(taller ? "Borrar" : "Quitar", role: .destructive) { Task { await t.borrarDeseo(d) } }.font(.caption.weight(.semibold))
            }
        }
        .padding(12)
        .background(d.estado == "encontrado" ? Color.green.opacity(0.08) : Color(.tertiarySystemFill).opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Taller: rollos que faltan y cuentas

struct FaltanView: View {
    @Environment(Tienda.self) private var t
    var body: some View {
        let cola = t.pedidos.filter { ($0.estado == .pendiente && !$0.peticion) || $0.estado == .imprimiendo }
        var necesita: [String: Double] = [:]
        for p in cola {
            let extra = 1 + p.coste_detalle.merma_pct / 100
            for l in p.lineas { if let f = l.filamento_id { necesita[f, default: 0] += l.gramos * Double(max(1, p.copias)) * extra } }
        }
        let faltan = t.filamentos.compactMap { f -> (Filamento, Double, Double)? in
            let n = necesita[f.id] ?? 0
            return n > f.stock_g ? (f, n, f.stock_g) : nil
        }
        return Group {
            if faltan.isEmpty {
                Label("Tienes filamento de sobra para todo lo que hay en cola", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                ForEach(faltan, id: \.0.id) { f, n, hay in
                    HStack(spacing: 12) {
                        Carrete(hex: f.color, fraccion: hay / max(1, f.peso), size: 34)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Te falta \(f.nombre)").font(.subheadline.weight(.bold))
                            Text("La cola necesita \(Fmt.gramos(n)) y quedan \(Fmt.gramos(hay))").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let u = URL(string: "https://eu.store.bambulab.com/search?q=" + "\(f.material) \(f.nombre)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!) {
                            Link("Comprar", destination: u).font(.subheadline.weight(.bold))
                        }
                    }
                }
            }
        }
    }
}

struct RentabilidadView: View {
    @Environment(Tienda.self) private var t
    var body: some View {
        let ps = t.pedidos.filter { $0.estado != .cancelado && !$0.delTaller }
        let cobrado = ps.filter(\.pagado).reduce(0) { $0 + $1.coste }
        let gramos = ps.filter(\.hecho).reduce(0) { $0 + $1.gramos }
        let coste = gramos * t.ajustes.coste_real_kg / 1000
        let meses = Dictionary(grouping: ps.filter(\.pagado)) { String($0.creado.prefix(7)) }
            .map { ($0.key, $0.value.reduce(0) { $0 + $1.coste }) }.sorted { $0.0 < $1.0 }.suffix(6)
        let maximo = max(1, meses.map(\.1).max() ?? 1)
        return VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                Cifra(etiqueta: "Cobrado", valor: Fmt.eur(cobrado), color: .green)
                Cifra(etiqueta: "Te costó", valor: Fmt.eur(coste))
                Cifra(etiqueta: "Ganas", valor: Fmt.eur(cobrado - coste), color: cobrado - coste < 0 ? .red : .primary)
            }
            if !meses.isEmpty {
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(Array(meses), id: \.0) { k, v in
                        VStack(spacing: 4) {
                            Text(Fmt.eur(v)).font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.6)
                            RoundedRectangle(cornerRadius: 6).fill(Color.hot.gradient).frame(height: max(4, 110 * v / maximo))
                            Text(mes(k)).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 150, alignment: .bottom)
            }
            Text("Con lo que te cuesta el kilo de verdad (\(Fmt.eur(t.ajustes.coste_real_kg))). La luz se cobra a precio de coste.").font(.footnote).foregroundStyle(.secondary)
        }
    }
    private func mes(_ k: String) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM"
        guard let d = f.date(from: k) else { return k }
        f.locale = Locale(identifier: "es_ES"); f.dateFormat = "MMM"
        return f.string(from: d).capitalized
    }
}

// MARK: - Cómo se ven las fichas

enum ModoVista: String, CaseIterable { case lista, grande, pequena }

struct MenuVista: View {
    @Binding var modo: String
    var body: some View {
        Menu {
            Picker("Ver", selection: $modo.animation(.snappy)) {
                Label("En lista", systemImage: "list.bullet").tag(ModoVista.lista.rawValue)
                Label("Cuadrícula grande", systemImage: "square.grid.2x2").tag(ModoVista.grande.rawValue)
                Label("Cuadrícula pequeña", systemImage: "square.grid.3x3").tag(ModoVista.pequena.rawValue)
            }
        } label: {
            Image(systemName: modo == "lista" ? "list.bullet" : modo == "pequena" ? "square.grid.3x3" : "square.grid.2x2")
        }
        .accessibilityLabel("Cómo se ven las fichas")
    }
}

/// fila de la vista en lista (cola y vitrina)
struct FilaLista: View {
    @Environment(Tienda.self) private var t
    let p: Pedido
    var turno: Int? = nil
    var body: some View {
        HStack(spacing: 12) {
            Portada(p: p).frame(width: 76, height: 76).clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(alignment: .topLeading) {
                    if let turno { Text("#\(turno)").font(.caption2.weight(.bold)).foregroundStyle(.white).padding(4).background(Color.tinta, in: RoundedRectangle(cornerRadius: 6)).padding(4) }
                }
            VStack(alignment: .leading, spacing: 4) {
                Text(p.nombreFigura).font(.subheadline.weight(.bold)).lineLimit(2).foregroundStyle(.primary)
                HStack(spacing: 5) { Avatar(nombre: p.nombre, size: 16, uid: p.user_id); Text(p.nombre).lineLimit(1); Text("· \(Fmt.hace(p.fecha))").lineLimit(1) }
                    .font(.caption).foregroundStyle(.secondary)
                Chip(estado: p.estado)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 4) {
                if !p.delTaller { Text(Fmt.eur(p.coste)).font(.system(.subheadline, design: .monospaced).weight(.bold)).foregroundStyle(.primary) }
                Text(Fmt.gramos(p.gramos)).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
            }
            .fixedSize()
        }
        .padding(10)
        .tarjeta()
    }
}
