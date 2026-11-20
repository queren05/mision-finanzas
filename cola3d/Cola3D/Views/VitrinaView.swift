import SwiftUI
import PhotosUI

/// todo lo que ha salido de la impresora, con las fotos de cómo ha quedado
struct VitrinaView: View {
    @Environment(Tienda.self) private var t
    @State private var soloFotos = false
    @State private var abierto: Pedido? = nil
    @State private var nueva = false

    /// cuándo se terminó de imprimir
    private func cuando(_ p: Pedido) -> String {
        p.historial.last { $0.estado == .impreso }?.fecha ?? (p.actualizado.isEmpty ? p.creado : p.actualizado)
    }

    private var hechas: [Pedido] { t.pedidos.filter(\.hecho).sorted { cuando($0) > cuando($1) } }

    var body: some View {
        NavigationStack {
            ScrollView {
                let todas = hechas
                let lista = soloFotos ? todas.filter { !$0.fotos.isEmpty } : todas
                VStack(spacing: 16) {
                    if !todas.isEmpty {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                            Cifra(etiqueta: "Piezas", valor: "\(todas.reduce(0) { $0 + max(1, $1.copias) })")
                            Cifra(etiqueta: "Filamento", valor: Fmt.gramos(todas.reduce(0) { $0 + $1.gramos }))
                            Cifra(etiqueta: "Imprimiendo", valor: Fmt.num(Double(todas.reduce(0) { $0 + $1.minutos * max(1, $1.copias) }) / 60, 1) + " h")
                            Cifra(etiqueta: "Fotos", valor: "\(todas.reduce(0) { $0 + $1.fotos.count })")
                        }
                        Picker("Filtro", selection: $soloFotos.animation(.snappy)) {
                            Text("Todas").tag(false)
                            Text("Con foto").tag(true)
                        }
                        .pickerStyle(.segmented)
                    }
                    if t.cargado && lista.isEmpty {
                        Vacio(titulo: todas.isEmpty ? "Aún no se ha impreso nada" : "Todavía no hay fotos", icono: "square.grid.2x2")
                    } else {
                        // dos columnas que se van llenando como un mosaico
                        HStack(alignment: .top, spacing: 10) {
                            ForEach(0..<2, id: \.self) { col in
                                LazyVStack(spacing: 10) {
                                    ForEach(Array(lista.enumerated()).filter { $0.offset % 2 == col }, id: \.element.id) { i, p in
                                        Button { abierto = p } label: { Pieza(p: p, alto: (i / 2 + col) % 2 == 0 ? 220 : 170, cuando: Fmt.fecha(cuando(p)) ?? p.fecha) }
                                            .buttonStyle(Encoger())
                                            .transition(.scale(scale: 0.92).combined(with: .opacity))
                                    }
                                }
                            }
                        }
                        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: lista.map(\.id))
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
                ToolbarItem(placement: .topBarTrailing) { BotonCuenta() }
            }
            .sheet(item: $abierto) { p in DetallePedido(id: p.id) }
            .sheet(isPresented: $nueva) { NuevaPieza { id in abierto = t.pedidos.first { $0.id == id } } }
        }
    }
}

private struct Pieza: View {
    let p: Pedido
    let alto: CGFloat
    let cuando: Date
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
            VStack(alignment: .leading, spacing: 4) {
                Text(p.nombreFigura).font(.subheadline.weight(.bold)).foregroundStyle(.primary).lineLimit(2).multilineTextAlignment(.leading)
                HStack(spacing: 5) {
                    Avatar(nombre: p.nombre, size: 16)
                    Text("\(p.nombre) · \(Fmt.hace(cuando))").lineLimit(1)
                }
                .font(.caption).foregroundStyle(.secondary)
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
