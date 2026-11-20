import SwiftUI
import PhotosUI

struct DetallePedido: View {
    @Environment(Tienda.self) private var t
    @Environment(\.dismiss) private var cerrar
    let id: String
    @State private var ocupado = false
    @State private var borrar = false
    @State private var cancelar = false
    @State private var ajustar = false
    @State private var copiado = false
    @State private var fotosElegidas: [PhotosPickerItem] = []
    @State private var subiendo = 0
    @State private var grande: String? = nil
    @State private var copiasIgual = 1
    @State private var pidiendo = false

    var body: some View {
        if let p = t.pedidos.first(where: { $0.id == id }) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Portada(p: p).frame(height: 260).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .overlay(alignment: .bottomTrailing) {
                                if p.estado == .imprimiendo {
                                    Image(systemName: "printer.fill").font(.title2).foregroundStyle(Color.hot).symbolEffect(.pulse)
                                        .padding(12).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14)).padding(12)
                                }
                            }
                        cabecera(p)
                        if p.peticion && p.estado == .pendiente { peticion(p) }
                        if !t.admin && !p.pagado && p.estado != .cancelado && !p.delTaller && !p.peticion { pago(p) }
                        if !p.url.isEmpty, let u = URL(string: p.url) {
                            Link(destination: u) {
                                Label("Abrir en \(u.host?.replacingOccurrences(of: "www.", with: "") ?? "la web")", systemImage: "arrow.up.right.square")
                                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                                    .background(Color.hot.gradient, in: Capsule()).foregroundStyle(.white)
                            }
                            .buttonStyle(Encoger())
                        }
                        if p.hecho { vitrina(p) }
                        Camino(p: p)
                        if t.admin { taller(p) }
                        if t.admin || !p.fotos.isEmpty { fotos(p) }
                        if !p.delTaller { coste(p) }
                        if !p.notas.isEmpty {
                            bloque("Notas") { Text(p.notas).frame(maxWidth: .infinity, alignment: .leading).padding(14).tarjeta() }
                        }
                        if !t.admin && t.tokens[p.id] != nil && p.estado == .pendiente {
                            Button(role: .destructive) { cancelar = true } label: {
                                Text("Cancelar mi pedido").frame(maxWidth: .infinity).padding(.vertical, 12)
                            }
                            .buttonStyle(.bordered)
                            .confirmationDialog("¿Cancelar este pedido?", isPresented: $cancelar, titleVisibility: .visible) {
                                Button("Sí, cancelar", role: .destructive) { Task { _ = await t.cancelar(p) } }
                            }
                        }
                    }
                    .padding(16)
                }
                .background(Color(.systemGroupedBackground))
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { cerrar() } label: { Image(systemName: "xmark.circle.fill").font(.title2).symbolRenderingMode(.hierarchical) }
                            .tint(.secondary).accessibilityLabel("Cerrar")
                    }
                }
                .sheet(isPresented: $ajustar) { AjustarGramos(p: p) }
                .fullScreenCover(item: Binding(get: { grande.map { FotoID(url: $0) } }, set: { grande = $0?.url })) { f in
                    FotoGrande(url: f.url)
                }
                .onChange(of: fotosElegidas) { _, items in subir(items, a: p) }
            }
            .presentationDragIndicator(.visible)
        } else {
            ContentUnavailableView("Ese pedido ya no existe", systemImage: "questionmark.folder")
        }
    }

    private func peticion(_ p: Pedido) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Petición: \(p.colores) colores", systemImage: "paintpalette.fill").font(.headline).foregroundStyle(.blue)
            Text(t.admin ? "La impresora lleva 4 colores a la vez. Si te animas a cambiar carretes, acéptala y entra en la cola."
                         : "La impresora lleva 4 colores a la vez. El taller te dirá si se puede; hasta entonces no hace falta pagar.")
                .font(.subheadline).foregroundStyle(.secondary)
            if t.admin {
                Button { Task { await hacer { await t.cambiar(p, ["peticion": false], ok: "Petición aceptada: ya está en la cola") } } } label: {
                    Text("Aceptar petición").font(.subheadline.weight(.bold)).foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 10).background(Color.blue.gradient, in: Capsule())
                }
                .buttonStyle(Encoger()).disabled(ocupado)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.blue.opacity(0.3)))
    }

    /// me gusta, guardar y pedir una igual
    private func vitrina(_ p: Pedido) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                BotonGusta(p: p, grande: true)
                if t.sesion != nil { BotonGuardar(p: p, grande: true) }
            }
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("¿Te gusta? Pide una igual").font(.subheadline.weight(.semibold))
                    Stepper("\(copiasIgual) \(copiasIgual == 1 ? "copia" : "copias")", value: $copiasIgual, in: 1...20)
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Button {
                    pidiendo = true
                    Task {
                        if await t.pedirIgual(p, copias: copiasIgual) { cerrar() }
                        pidiendo = false
                    }
                } label: {
                    Group { if pidiendo { ProgressView().tint(.white) } else { Text("Pedir igual") } }
                        .font(.subheadline.weight(.bold)).foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .background(Color.hot.gradient, in: Capsule())
                }
                .buttonStyle(Encoger())
                .disabled(pidiendo)
            }
            .padding(14)
            .background(Color.hot.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
        }
    }

    private func cabecera(_ p: Pedido) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(p.nombreFigura).font(.title2.weight(.bold)).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                Avatar(nombre: p.nombre, size: 22, uid: p.user_id)
                Text(p.nombre)
                Text("·").foregroundStyle(.tertiary)
                Text(Fmt.fechaLarga(p.fecha))
            }
            .font(.subheadline).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                if p.delTaller {
                    Etiqueta(texto: "Del taller", color: .hot, icono: "wrench.and.screwdriver.fill")
                } else {
                    Text(Fmt.eur(p.coste)).font(.system(.largeTitle, design: .monospaced).weight(.bold)).contentTransition(.numericText())
                }
                if p.estado != .cancelado && !p.delTaller {
                    if p.pagado { Etiqueta(texto: "Pagado", color: .green, icono: "checkmark") } else { Etiqueta(texto: "Sin pagar", color: .red) }
                }
                if p.prioridad > 0 && p.estado == .pendiente { Etiqueta(texto: "Prioridad", color: .hot, icono: "arrow.up") }
            }
        }
    }

    private func pago(_ p: Pedido) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Págalo para que se imprima", systemImage: "eurosign.circle.fill").font(.headline).foregroundStyle(Color.hot)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Importe").font(.caption).foregroundStyle(.secondary)
                    Text(Fmt.eur(p.coste)).font(.system(.title3, design: .monospaced).weight(.bold))
                }
                Spacer()
                if !t.ajustes.bizum.isEmpty {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Bizum").font(.caption).foregroundStyle(.secondary)
                        Text(t.ajustes.bizum).font(.system(.body, design: .monospaced).weight(.semibold))
                    }
                }
            }
            if !t.ajustes.bizum.isEmpty {
                Button {
                    UIPasteboard.general.string = t.ajustes.bizum.replacingOccurrences(of: " ", with: "")
                    withAnimation(.snappy) { copiado = true }
                    Task { try? await Task.sleep(for: .seconds(2)); withAnimation { copiado = false } }
                } label: {
                    Label(copiado ? "Copiado" : "Copiar número", systemImage: copiado ? "checkmark" : "doc.on.doc")
                        .contentTransition(.symbolEffect(.replace)).frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).tint(Color.hot)
                .sensoryFeedback(.success, trigger: copiado)
            }
            Text("También en mano.").font(.footnote).foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color.hot.opacity(0.09), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.hot.opacity(0.3)))
    }

    private func taller(_ p: Pedido) -> some View {
        bloque("Taller") {
            VStack(spacing: 12) {
                Menu {
                    ForEach(Estado.allCases) { e in
                        Button { Task { await hacer { await t.cambiar(p, ["estado": e.rawValue], ok: "Pasado a \(e.label.lowercased())") } } } label: {
                            Label(e.label, systemImage: e.icono)
                        }
                        .disabled(e == p.estado)
                    }
                } label: {
                    HStack {
                        Image(systemName: p.estado.icono).foregroundStyle(p.estado.color)
                        Text("Estado: \(p.estado.label)").foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down").foregroundStyle(.secondary)
                    }
                    .font(.body.weight(.semibold))
                    .padding(14).tarjeta()
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    if !p.delTaller {
                        accion(p.pagado ? "Quitar pagado" : "Marcar pagado", p.pagado ? "xmark.circle" : "checkmark.circle.fill", .green) {
                            await t.cambiar(p, ["pagado": !p.pagado], ok: p.pagado ? "Quitado el pagado" : "Marcado como pagado")
                        }
                    }
                    if p.estado == .pendiente {
                        if p.prioridad > 0 {
                            accion("Quitar prioridad", "arrow.down.circle", .orange) { await t.cambiar(p, ["prioridad": 0], ok: "Vuelve a su sitio en la cola") }
                        } else {
                            accion("Pasar el primero", "arrow.up.circle.fill", .hot) {
                                await t.cambiar(p, ["prioridad": (t.pedidos.map(\.prioridad).max() ?? 0) + 1], ok: "Pasado el primero de la cola")
                            }
                        }
                    }
                    Button { ajustar = true } label: { etiquetaAccion("Ajustar gramos", "scalemass.fill", .blue) }.buttonStyle(Encoger())
                    Button { borrar = true } label: { etiquetaAccion("Borrar", "trash.fill", .red) }.buttonStyle(Encoger())
                }
                .disabled(ocupado)
                .confirmationDialog("¿Borrar este pedido?", isPresented: $borrar, titleVisibility: .visible) {
                    Button("Sí, borrar", role: .destructive) { Task { if await t.borrar(p) { cerrar() } } }
                }
            }
        }
    }

    private func accion(_ titulo: String, _ icono: String, _ color: Color, _ f: @escaping () async -> Void) -> some View {
        Button { Task { await hacer(f) } } label: { etiquetaAccion(titulo, icono, color) }.buttonStyle(Encoger())
    }
    private func etiquetaAccion(_ titulo: String, _ icono: String, _ color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icono).font(.title3).foregroundStyle(color)
            Text(titulo).font(.footnote.weight(.semibold)).foregroundStyle(.primary).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12).tarjeta()
    }
    private func hacer(_ f: () async -> Void) async {
        ocupado = true
        await f()
        ocupado = false
    }

    private func fotos(_ p: Pedido) -> some View {
        bloque("Cómo ha quedado") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                ForEach(p.fotos, id: \.self) { u in
                    Button { grande = u } label: {
                        Color.clear.aspectRatio(1, contentMode: .fit)
                            .overlay { AsyncImage(url: URL(string: u)) { i in i.resizable().scaledToFill() } placeholder: { Color(.tertiarySystemFill) } }
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(Encoger())
                    .overlay(alignment: .topTrailing) {
                        if t.admin {
                            Button { Task { await t.quitarFoto(u, de: p) } } label: {
                                Image(systemName: "xmark").font(.caption.weight(.bold)).padding(6).background(.regularMaterial, in: Circle())
                            }
                            .padding(5).accessibilityLabel("Quitar foto")
                        }
                    }
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
                ForEach(0..<subiendo, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 14).fill(.quaternary).aspectRatio(1, contentMode: .fit).overlay(ProgressView())
                }
                if t.admin && p.fotos.count < 12 {
                    PhotosPicker(selection: $fotosElegidas, maxSelectionCount: 12 - p.fotos.count, matching: .images) {
                        VStack(spacing: 4) {
                            Image(systemName: "camera.fill").font(.title3)
                            Text("Subir foto").font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(Color.hot)
                        .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
                        .background(RoundedRectangle(cornerRadius: 14).strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 5])).foregroundStyle(Color.hot.opacity(0.5)))
                    }
                    .disabled(subiendo > 0)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: p.fotos)
        }
    }

    private func subir(_ items: [PhotosPickerItem], a p: Pedido) {
        guard !items.isEmpty else { return }
        fotosElegidas = []
        subiendo = items.count
        Task {
            var nuevas: [String] = []
            for it in items {
                if let d = try? await it.loadTransferable(type: Data.self), let img = UIImage(data: d), let jpg = reducir(img) {
                    do { nuevas.append(try await t.subirFoto(jpg, a: p)) } catch { t.avisar(error.localizedDescription, error: true) }
                }
                subiendo = max(0, subiendo - 1)
            }
            subiendo = 0
            guard !nuevas.isEmpty, let actual = t.pedidos.first(where: { $0.id == p.id }) else { return }
            await t.cambiar(actual, ["fotos": actual.fotos + nuevas], ok: nuevas.count == 1 ? "Foto subida" : "\(nuevas.count) fotos subidas")
        }
    }

    /// 1600 px como mucho, en JPEG
    private func reducir(_ img: UIImage) -> Data? {
        let k = min(1, 1600 / max(img.size.width, img.size.height))
        let tam = CGSize(width: img.size.width * k, height: img.size.height * k)
        let f = UIGraphicsImageRendererFormat(); f.scale = 1
        return UIGraphicsImageRenderer(size: tam, format: f).image { _ in img.draw(in: CGRect(origin: .zero, size: tam)) }.jpegData(compressionQuality: 0.85)
    }

    private func coste(_ p: Pedido) -> some View {
        let d = p.coste_detalle
        return bloque("Cómo sale el precio") {
            VStack(spacing: 10) {
                ForEach(Array(d.lineas.enumerated()), id: \.offset) { _, l in
                    HStack(spacing: 8) {
                        Muestra(hex: l.color)
                        Text(l.nombre).lineLimit(1)
                        Text(Fmt.gramos(l.gramos)).foregroundStyle(.secondary)
                        Spacer()
                        Text(Fmt.eur(l.coste)).font(.system(.body, design: .monospaced))
                    }
                }
                if d.merma > 0 { fila("Purga de colores (\(Fmt.num(d.merma_pct)) %)", d.merma) }
                if d.descuento > 0 {
                    HStack { Label("Gramos de regalo · \(Fmt.gramos(d.gratis_g))", systemImage: "gift.fill"); Spacer(); Text("−" + Fmt.eur(d.descuento)).font(.system(.body, design: .monospaced)) }
                        .foregroundStyle(.green)
                }
                if d.luz > 0 { fila("Luz y desgaste · \(Fmt.duracion(p.minutos))\(p.copias > 1 ? " × \(p.copias)" : "")", d.luz) }
                Divider()
                HStack {
                    Text("Total").font(.headline)
                    Spacer()
                    Text(Fmt.eur(p.coste)).font(.system(.headline, design: .monospaced))
                }
            }
            .font(.subheadline)
            .padding(14).tarjeta()
        }
    }
    private func fila(_ t: String, _ v: Double) -> some View {
        HStack { Text(t).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8); Spacer(); Text(Fmt.eur(v)).font(.system(.body, design: .monospaced)) }
    }

    private func bloque<C: View>(_ titulo: String, @ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titulo.uppercased()).font(.caption.weight(.bold)).foregroundStyle(.secondary).tracking(0.6)
            c()
        }
    }
}

private struct FotoID: Identifiable { let url: String; var id: String { url } }

private struct FotoGrande: View {
    let url: String
    @Environment(\.dismiss) private var cerrar
    @State private var zoom: CGFloat = 1
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            AsyncImage(url: URL(string: url)) { i in i.resizable().scaledToFit() } placeholder: { ProgressView().tint(.white) }
                .scaleEffect(zoom)
                .gesture(MagnifyGesture().onChanged { zoom = max(1, $0.magnification) }.onEnded { _ in withAnimation(.spring) { zoom = 1 } })
        }
        .overlay(alignment: .topTrailing) {
            Button { cerrar() } label: { Image(systemName: "xmark.circle.fill").font(.largeTitle).symbolRenderingMode(.hierarchical).foregroundStyle(.white) }
                .padding().accessibilityLabel("Cerrar")
        }
        .onTapGesture { cerrar() }
    }
}

/// línea de estados: pendiente → imprimiendo → impreso → entregado
private struct Camino: View {
    let p: Pedido
    var body: some View {
        let pasos: [Estado] = p.estado == .cancelado ? [.pendiente, .cancelado] : [.pendiente, .imprimiendo, .impreso, .entregado]
        let actual = pasos.firstIndex(of: p.estado) ?? 0
        var fechas: [Estado: Date] = [:]
        for h in p.historial { if let d = Fmt.fecha(h.fecha) { fechas[h.estado] = d } }
        return HStack(alignment: .top, spacing: 0) {
            ForEach(Array(pasos.enumerated()), id: \.offset) { i, e in
                VStack(spacing: 6) {
                    HStack(spacing: 0) {
                        Rectangle().fill(i == 0 ? .clear : (i <= actual ? pasos[actual].color : Color(.systemFill))).frame(height: 3)
                        ZStack {
                            Circle().fill(i <= actual ? e.color : Color(.secondarySystemGroupedBackground)).frame(width: i == actual ? 30 : 24, height: i == actual ? 30 : 24)
                            Circle().strokeBorder(i <= actual ? .clear : Color(.systemFill), lineWidth: 2).frame(width: 24, height: 24)
                            if i < actual { Image(systemName: "checkmark").font(.caption2.weight(.heavy)).foregroundStyle(.white) }
                            if i == actual { Image(systemName: e.icono).font(.caption.weight(.bold)).foregroundStyle(.white) }
                        }
                        .frame(width: 30, height: 30)
                        Rectangle().fill(i == pasos.count - 1 ? .clear : (i < actual ? pasos[actual].color : Color(.systemFill))).frame(height: 3)
                    }
                    Text(e.label).font(.caption2.weight(i == actual ? .bold : .regular)).foregroundStyle(i <= actual ? .primary : .secondary).lineLimit(1).minimumScaleFactor(0.7)
                    Text(i <= actual ? fechas[e].map { $0.formatted(.dateTime.day().month(.abbreviated)) } ?? " " : " ").font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: p.estado)
    }
}

/// el taller corrige gramos, tiempo y copias (recalcula el precio)
struct AjustarGramos: View {
    @Environment(Tienda.self) private var t
    @Environment(\.dismiss) private var cerrar
    let p: Pedido
    @State private var gramos: [String] = []
    @State private var horas = ""
    @State private var mins = ""
    @State private var copias = 1
    @State private var ocupado = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Gramos por copia") {
                    ForEach(Array(p.lineas.enumerated()), id: \.offset) { i, l in
                        HStack {
                            Muestra(hex: l.color)
                            Text(l.nombre).lineLimit(1)
                            Spacer()
                            TextField("0", text: binding(i)).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80)
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
                }
                Section { Stepper("Copias: \(copias)", value: $copias, in: 1...50) }
            }
            .navigationTitle("Ajustar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { cerrar() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        ocupado = true
                        var ls = p.lineas
                        for i in ls.indices { ls[i].gramos = Fmt.leer(gramos[safe: i] ?? "") ?? ls[i].gramos }
                        let m = (Int(horas) ?? 0) * 60 + (Int(mins) ?? 0)
                        let lineas = ls.map { l -> [String: Any] in ["filamento_id": l.filamento_id.map { $0 as Any } ?? NSNull(), "nombre": l.nombre, "color": l.color, "gramos": l.gramos] }
                        Task {
                            await t.cambiar(p, ["lineas": lineas, "minutos": m, "copias": copias], ok: "Precio recalculado")
                            cerrar()
                        }
                    }
                    .disabled(ocupado).bold()
                }
            }
            .onAppear {
                gramos = p.lineas.map { Fmt.num($0.gramos, 1) }
                horas = "\(p.minutos / 60)"; mins = "\(p.minutos % 60)"; copias = p.copias
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func binding(_ i: Int) -> Binding<String> {
        Binding(get: { gramos[safe: i] ?? "" }, set: { if i < gramos.count { gramos[i] = $0 } })
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
