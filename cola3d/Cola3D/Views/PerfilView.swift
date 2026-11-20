import SwiftUI
import PhotosUI

/// tu perfil: foto, nombre, lo que llevas, tus piezas, me gusta y listas de guardados; y abajo los ajustes de la cuenta
struct PerfilView: View {
    @Environment(Tienda.self) private var t
    let cerrar: () -> Void
    enum Pestana: String, CaseIterable { case mias = "Mis impresiones", gustan = "Me gusta", guardados = "Guardados" }
    @State private var pestana = Pestana.mias
    @State private var foto: PhotosPickerItem? = nil
    @State private var subiendo = false
    @State private var editando = false
    @State private var nombre = ""
    @State private var lista = ""
    @State private var renombrar = false
    @State private var nuevoNombreLista = ""
    @State private var borrarLista = false
    @State private var abierto: Pedido? = nil
    @State private var clave = ""
    @State private var cambiando = false
    @State private var salir = false
    @AppStorage("tema") private var tema = "auto"

    var body: some View {
        if let s = t.sesion {
            let mios = t.pedidos.filter { t.esMio($0) }.sorted { $0.creado > $1.creado }
            let vivos = mios.filter { $0.estado != .cancelado }
            let gustan = t.pedidos.filter { t.votos[$0.id]?.contains(s.id) ?? false }
            let recibidos = mios.reduce(0) { $0 + (t.votos[$1.id]?.count ?? 0) }
            let listas = t.nombresListas.filter { l in t.listas.contains { $0.lista == l } }
            let actual = listas.contains(lista) ? lista : (listas.first ?? "")
            let enLista = t.listas.filter { $0.lista == actual }.compactMap { x in t.pedidos.first { $0.id == x.pedido } }
            let piezas = pestana == .mias ? mios : pestana == .gustan ? gustan : enLista
            ScrollView {
                VStack(spacing: 18) {
                    cabecera(s)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                        Cifra(etiqueta: "Pedidos", valor: "\(vivos.count)")
                        Cifra(etiqueta: "Has pagado", valor: Fmt.eur(vivos.filter(\.pagado).reduce(0) { $0 + $1.coste }), color: .green)
                        let debe = vivos.filter { !$0.pagado && !$0.peticion }.reduce(0) { $0 + $1.coste }
                        Cifra(etiqueta: "Debes", valor: Fmt.eur(debe), color: debe > 0 ? .red : .primary)
                        Cifra(etiqueta: "Impreso", valor: Fmt.gramos(vivos.filter(\.hecho).reduce(0) { $0 + $1.gramos }))
                        Cifra(etiqueta: "Me gusta recibidos", valor: "\(recibidos)", color: .pink)
                        Cifra(etiqueta: "Gramos de regalo", valor: Fmt.gramos(t.admin ? 0 : gratisRestante(t.pedidos, t.ajustes, uid: s.id, nombre: s.nombre)))
                    }
                    Picker("Pestaña", selection: $pestana.animation(.snappy)) {
                        ForEach(Pestana.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if pestana == .guardados && !listas.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(listas, id: \.self) { l in
                                    ChipFiltro(texto: "\(l) · \(t.listas.filter { $0.lista == l }.count)", activo: l == actual) { withAnimation(.snappy) { lista = l } }
                                }
                                Menu {
                                    Button { nuevoNombreLista = actual; renombrar = true } label: { Label("Renombrar «\(actual)»", systemImage: "pencil") }
                                    Button(role: .destructive) { borrarLista = true } label: { Label("Borrar «\(actual)»", systemImage: "trash") }
                                } label: { EtiquetaChip(texto: "Lista", icono: "ellipsis", activo: false) }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    if piezas.isEmpty {
                        Vacio(titulo: pestana == .mias ? "Todavía no has pedido nada" : pestana == .gustan ? "Aún no te ha gustado nada" : "Aún no has guardado nada", icono: "square.grid.2x2")
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                            ForEach(piezas) { p in
                                FichaMini(p: p, mia: pestana == .mias).onTapGesture { abierto = p }
                            }
                        }
                    }
                    ajustes
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .sheet(item: $abierto) { p in DetallePedido(id: p.id) }
            .onChange(of: foto) { _, it in
                guard let it else { return }
                foto = nil
                Task {
                    subiendo = true
                    if let d = try? await it.loadTransferable(type: Data.self), let img = UIImage(data: d), let jpg = cuadrada(img) {
                        _ = await t.guardarPerfil(nombre: s.nombre, foto: jpg)
                    }
                    subiendo = false
                }
            }
            .alert("Renombrar lista", isPresented: $renombrar) {
                TextField("Nombre", text: $nuevoNombreLista)
                Button("Cancelar", role: .cancel) {}
                Button("Guardar") { Task { await t.renombrarLista(actual, a: nuevoNombreLista); lista = nuevoNombreLista } }
            }
            .confirmationDialog("¿Borrar la lista «\(actual)»? Las piezas siguen en la vitrina.", isPresented: $borrarLista, titleVisibility: .visible) {
                Button("Borrar lista", role: .destructive) { Task { await t.borrarLista(actual); lista = "" } }
            }
        }
    }

    private func cabecera(_ s: Sesion) -> some View {
        HStack(spacing: 16) {
            PhotosPicker(selection: $foto, matching: .images) {
                Avatar(nombre: s.nombre, size: 84, uid: s.id)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: subiendo ? "hourglass" : "camera.fill").font(.caption.weight(.bold)).foregroundStyle(.white)
                            .frame(width: 30, height: 30).background(Color.hot, in: Circle())
                            .overlay(Circle().strokeBorder(Color(.systemGroupedBackground), lineWidth: 3))
                    }
            }
            .disabled(subiendo)
            .accessibilityLabel("Cambiar foto de perfil")
            VStack(alignment: .leading, spacing: 6) {
                if editando {
                    TextField("Tu nombre", text: $nombre).font(.title2.weight(.bold)).textContentType(.nickname)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                    HStack {
                        Button("Guardar") { Task { if await t.guardarPerfil(nombre: nombre) { withAnimation { editando = false } } } }
                            .buttonStyle(.borderedProminent).disabled(nombre.trimmingCharacters(in: .whitespaces).isEmpty)
                        Button("Cancelar") { withAnimation { editando = false } }.buttonStyle(.bordered)
                    }
                    .font(.subheadline.weight(.semibold))
                } else {
                    Text(s.nombre).font(.largeTitle.weight(.heavy)).lineLimit(1).minimumScaleFactor(0.5)
                    Text(s.email).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                    HStack(spacing: 8) {
                        Button { nombre = s.nombre; withAnimation { editando = true } } label: { Label("Cambiar nombre", systemImage: "pencil") }
                            .font(.footnote.weight(.semibold)).buttonStyle(.bordered)
                        if t.admin { Etiqueta(texto: "Taller", color: .hot, icono: "wrench.and.screwdriver.fill") }
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var ajustes: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AJUSTES").font(.caption.weight(.bold)).foregroundStyle(.secondary).tracking(0.6)
            VStack(alignment: .leading, spacing: 10) {
                Text("Aspecto").font(.subheadline.weight(.semibold))
                Picker("Aspecto", selection: $tema) {
                    Text("Como el móvil").tag("auto")
                    Text("Claro").tag("claro")
                    Text("Oscuro").tag("oscuro")
                }
                .pickerStyle(.segmented)
            }
            .padding(14).tarjeta()
            VStack(alignment: .leading, spacing: 10) {
                Text("Cambiar contraseña").font(.subheadline.weight(.semibold))
                CampoClave(titulo: "Contraseña nueva", texto: $clave, nueva: true)
                    .padding(.horizontal, 12).padding(.vertical, 4)
                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
                Button {
                    Task {
                        cambiando = true
                        defer { cambiando = false }
                        guard let tk = await t.token() else { return }
                        do { try await Supa.cambiarClave(clave, token: tk); clave = ""; t.avisar("Contraseña cambiada") }
                        catch { t.avisar(error.localizedDescription, error: true) }
                    }
                } label: { if cambiando { ProgressView() } else { Text("Guardar contraseña").frame(maxWidth: .infinity) } }
                .buttonStyle(.bordered).disabled(clave.count < 6 || cambiando)
            }
            .padding(14).tarjeta()
            Button(role: .destructive) { salir = true } label: { Text("Salir de la cuenta").frame(maxWidth: .infinity).padding(.vertical, 6) }
                .buttonStyle(.bordered)
                .confirmationDialog("¿Salir de la cuenta?", isPresented: $salir, titleVisibility: .visible) {
                    Button("Salir", role: .destructive) { Task { await t.salir(); cerrar() } }
                }
        }
        .padding(.top, 8)
    }

    /// foto de perfil cuadrada de 512 px
    private func cuadrada(_ img: UIImage) -> Data? {
        let lado = min(img.size.width, img.size.height)
        let tam = CGSize(width: 512, height: 512)
        let f = UIGraphicsImageRendererFormat(); f.scale = 1
        return UIGraphicsImageRenderer(size: tam, format: f).image { _ in
            let k = 512 / lado
            img.draw(in: CGRect(x: -(img.size.width - lado) / 2 * k, y: -(img.size.height - lado) / 2 * k, width: img.size.width * k, height: img.size.height * k))
        }.jpegData(compressionQuality: 0.88)
    }
}

/// ficha pequeña de una pieza (perfil)
private struct FichaMini: View {
    @Environment(Tienda.self) private var t
    let p: Pedido
    let mia: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Portada(p: p).frame(height: 130).frame(maxWidth: .infinity).clipped()
            VStack(alignment: .leading, spacing: 6) {
                Text(p.nombreFigura).font(.subheadline.weight(.bold)).lineLimit(1)
                HStack {
                    if mia { Chip(estado: p.estado) } else { Text(Fmt.gramos(p.gramos)).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary) }
                    Spacer(minLength: 4)
                    if mia { Text(Fmt.eur(p.coste)).font(.system(.caption, design: .monospaced).weight(.semibold)) } else { BotonGusta(p: p) }
                }
            }
            .padding(10)
        }
        .tarjeta()
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 20))
    }
}
