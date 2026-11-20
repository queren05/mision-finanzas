import SwiftUI

struct PedirView: View {
    @Environment(Tienda.self) private var t

    var body: some View {
        NavigationStack {
            Group {
                if t.sesion == nil { FormCuenta(entrarPrimero: true).padding(16) } else { FormPedido() }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Pedir una figura")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { BotonCuenta() } }
        }
    }
}

private struct FormPedido: View {
    @Environment(Tienda.self) private var t
    @State private var enlace = ""
    @State private var vista: Vista? = nil
    @State private var buscando = false
    @State private var fallo: String? = nil
    @State private var perfil: Perfil? = nil
    @State private var lineas: [LineaForm] = []
    @State private var minutos = 0
    @State private var copias = 1
    @State private var notas = ""
    @State private var enviando = false
    @State private var hecho = false
    @FocusState private var foco: Bool

    private var perfilesA1: [Perfil] { (vista?.perfiles ?? []).filter(\.a1mini) }
    private var sinResolver: Bool { lineas.contains { $0.falta != nil && $0.cambio == nil } }
    private var detalle: Detalle { calcularCoste(lineas.map(\.linea), minutos: minutos, copias: copias, filamentos: t.filamentos, ajustes: t.ajustes) }
    private var listo: Bool { perfil != nil && !lineas.isEmpty && !sinResolver && !enviando }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                campoEnlace
                if buscando { cargando }
                if let fallo {
                    Label(fallo, systemImage: "exclamationmark.triangle.fill").font(.subheadline.weight(.semibold)).foregroundStyle(.red)
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading).background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                if let v = vista, !perfilesA1.isEmpty {
                    figura(v)
                    perfiles
                    colores
                    VStack(alignment: .leading, spacing: 8) {
                        titulo("Copias")
                        Stepper(value: $copias.animation(.snappy), in: 1...50) {
                            Text("\(copias)").font(.system(.title3, design: .monospaced).weight(.bold)).contentTransition(.numericText())
                        }
                        .padding(.horizontal, 14).padding(.vertical, 8).tarjeta()
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        titulo("Notas")
                        TextField("Escala 120 %, para el cumple del 12…", text: $notas, axis: .vertical)
                            .lineLimit(2...5).padding(14).tarjeta()
                    }
                    resumen
                }
            }
            .padding(16)
            .padding(.bottom, 20)
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: vista?.titulo)
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: perfil)
            .animation(.snappy, value: fallo)
        }
        .scrollDismissesKeyboard(.interactively)
        .overlay { if hecho { Hecho().transition(.opacity) } }
        .task(id: enlace) {
            // espera a que termine de pegar o escribir
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            await buscar()
        }
    }

    private var campoEnlace: some View {
        VStack(alignment: .leading, spacing: 8) {
            titulo("Enlace de MakerWorld")
            HStack(spacing: 8) {
                TextField("https://makerworld.com/es/models/…", text: $enlace)
                    .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled().focused($foco)
                if enlace.isEmpty {
                    Button { if let s = UIPasteboard.general.string { enlace = s.trimmingCharacters(in: .whitespacesAndNewlines) } } label: {
                        Label("Pegar", systemImage: "doc.on.clipboard").font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered).tint(Color.hot)
                } else {
                    Button { withAnimation { enlace = ""; vista = nil; perfil = nil; lineas = []; fallo = nil } } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Borrar enlace")
                }
            }
            .padding(.leading, 14).padding(.trailing, 8).padding(.vertical, 8).tarjeta()
            Text("Solo modelos de MakerWorld con perfil de impresión para la A1 mini").font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var cargando: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Mirando el modelo…").foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(18).tarjeta()
        .transition(.opacity)
    }

    private func figura(_ v: Vista) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: v.imagen ?? "")) { i in i.resizable().scaledToFill() } placeholder: { Color(.tertiarySystemFill) }
                .frame(width: 76, height: 76).clipShape(RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 4) {
                Text(v.titulo ?? "Modelo").font(.headline).lineLimit(2)
                Label("\(perfilesA1.count) perfil\(perfilesA1.count == 1 ? "" : "es") para tu A1 mini", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(.green)
            }
            Spacer(minLength: 0)
        }
        .padding(12).tarjeta()
        .transition(.scale(scale: 0.95).combined(with: .opacity))
    }

    private var perfiles: some View {
        VStack(alignment: .leading, spacing: 8) {
            titulo("Perfil de impresión")
            ScrollViewReader { sv in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(perfilesA1) { p in
                            Button { elegir(p) } label: { TarjetaPerfil(p: p, elegido: perfil?.id == p.id) }
                                .buttonStyle(Encoger()).id(p.id)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onChange(of: perfil?.id) { _, id in withAnimation { sv.scrollTo(id, anchor: .center) } }
            }
        }
    }

    private var colores: some View {
        VStack(alignment: .leading, spacing: 8) {
            titulo("Colores")
            VStack(spacing: 10) {
                ForEach($lineas) { $l in FilaLinea(l: $l) }
            }
        }
    }

    private var resumen: some View {
        let d = detalle
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(Fmt.eur(d.total)).font(.system(size: 38, weight: .heavy, design: .rounded)).contentTransition(.numericText()).animation(.snappy, value: d.total)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(Fmt.gramos(d.gramos)).font(.system(.subheadline, design: .monospaced))
                    Text(Fmt.duracion(minutos * copias)).font(.caption).foregroundStyle(.secondary)
                }
            }
            VStack(spacing: 6) {
                fila("Filamento", d.filamento)
                if d.merma > 0 { fila("Purga de colores (\(Fmt.num(d.merma_pct)) %)", d.merma) }
                fila("Luz y desgaste", d.luz)
            }
            .font(.subheadline)
            Button { Task { await enviar() } } label: {
                Group {
                    if enviando { ProgressView().tint(.white) }
                    else { Text(sinResolver ? "Elige otro color" : "Pedir por \(Fmt.eur(d.total))") }
                }
                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 15)
                .background(listo ? AnyShapeStyle(Color.hot.gradient) : AnyShapeStyle(Color.gray.opacity(0.35)), in: Capsule())
                .foregroundStyle(.white)
            }
            .buttonStyle(Encoger())
            .disabled(!listo)
            .sensoryFeedback(.success, trigger: hecho)
        }
        .padding(18)
        .tarjeta()
        .shadow(color: .black.opacity(0.08), radius: 16, y: 6)
    }

    private func fila(_ t: String, _ v: Double) -> some View {
        HStack { Text(t).foregroundStyle(.secondary); Spacer(); Text(Fmt.eur(v)).font(.system(.subheadline, design: .monospaced)) }
    }

    private func titulo(_ s: String) -> some View {
        Text(s.uppercased()).font(.caption.weight(.bold)).foregroundStyle(.secondary).tracking(0.6)
    }

    // MARK: acciones

    private func buscar() async {
        let u = enlace.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !u.isEmpty else { return }
        guard Perfiles.esMakerWorld(u) else {
            withAnimation { fallo = "Solo modelos de MakerWorld con perfil de impresión"; vista = nil; perfil = nil; lineas = [] }
            return
        }
        withAnimation { buscando = true; fallo = nil }
        defer { withAnimation { buscando = false } }
        do {
            let v = try await Supa.vistaPrevia(u)
            let a1 = (v.perfiles ?? []).filter(\.a1mini)
            withAnimation {
                vista = v
                if a1.isEmpty {
                    fallo = (v.perfiles ?? []).isEmpty ? "Ese modelo no tiene perfil de impresión" : "Ese modelo no tiene perfil para la A1 mini"
                    perfil = nil; lineas = []
                }
            }
            if let p = Perfiles.inicial(a1, url: u) { elegir(p) }
            foco = false
        } catch {
            withAnimation { fallo = "No se ha podido leer el modelo. Mira el enlace"; vista = nil }
        }
    }

    private func elegir(_ p: Perfil) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            perfil = p
            minutos = Perfiles.minutosA1mini(p)
            lineas = Perfiles.lineas(p, t.filamentos)
        }
    }

    private func enviar() async {
        guard let p = perfil, let v = vista else { return }
        enviando = true
        defer { enviando = false }
        let cambios = lineas.compactMap(\.cambio)
        let n = ([notas.trimmingCharacters(in: .whitespacesAndNewlines)] + cambios).filter { !$0.isEmpty }.joined(separator: "\n")
        do {
            let id = try await t.pedir(nombre: t.sesion?.nombre ?? "", url: Perfiles.urlConPerfil(enlace.trimmingCharacters(in: .whitespacesAndNewlines), p),
                                       titulo: v.titulo ?? "", imagen: v.imagen ?? "", lineas: lineas.map(\.linea), minutos: minutos, copias: copias, notas: n)
            withAnimation(.spring) { hecho = true }
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation { hecho = false; enlace = ""; vista = nil; perfil = nil; lineas = []; notas = ""; copias = 1 }
            t.resaltado = id
            t.pestana = .cola
        } catch {
            t.avisar(error.localizedDescription, error: true)
        }
    }
}

private struct TarjetaPerfil: View {
    let p: Perfil
    let elegido: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(p.titulo.isEmpty ? "Perfil" : p.titulo).font(.subheadline.weight(.semibold)).lineLimit(2).multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(.primary)
            HStack(spacing: 10) {
                Label(Fmt.duracion(Perfiles.minutosA1mini(p)), systemImage: "clock")
                Label(Fmt.gramos(p.gramos), systemImage: "scalemass")
            }
            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            HStack(spacing: 3) {
                ForEach(Array(p.colores.prefix(6).enumerated()), id: \.offset) { _, c in Muestra(hex: c.color, size: 12) }
                Spacer()
                if p.modelo == "N1" { Text("A1 mini").font(.caption2.weight(.bold)).foregroundStyle(.green) }
                else { Text(p.impresora).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
            }
        }
        .padding(12)
        .frame(width: 210, height: 110)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(elegido ? Color.hot : Color.primary.opacity(0.08), lineWidth: elegido ? 2.5 : 1))
        .overlay(alignment: .topTrailing) {
            if elegido { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.hot).background(Circle().fill(.background)).offset(x: 6, y: -6).transition(.scale) }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: elegido)
    }
}

/// una línea de color: el rollo elegido o el aviso de que no hay ese color
private struct FilaLinea: View {
    @Environment(Tienda.self) private var t
    @Binding var l: LineaForm

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Muestra(hex: l.linea.color, size: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text(l.linea.filamento_id == nil ? (l.cambio != nil ? "Lo elige el taller" : "No hay este color") : l.linea.nombre)
                        .font(.subheadline.weight(.semibold)).lineLimit(1)
                    if let f = l.falta, l.cambio == nil { Text("\(f.material) \(Perfiles.nombreColor(f.color))").font(.caption).foregroundStyle(.secondary) }
                }
                Spacer()
                Text(Fmt.gramos(l.linea.gramos)).font(.system(.subheadline, design: .monospaced)).foregroundStyle(.secondary)
            }
            if let f = l.falta, l.cambio == nil {
                VStack(alignment: .leading, spacing: 8) {
                    Label("No tenemos \(f.material) \(Perfiles.nombreColor(f.color)). Elige otro:", systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote.weight(.semibold)).foregroundStyle(.red)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Perfiles.alternativas(f, t.filamentos)) { a in
                                Button { cambiar(a, f) } label: {
                                    HStack(spacing: 6) { Muestra(hex: a.color, size: 16); Text(a.nombre).lineLimit(1) }
                                        .font(.footnote.weight(.semibold)).padding(.horizontal, 10).padding(.vertical, 7)
                                        .background(Color(.tertiarySystemFill), in: Capsule())
                                }
                                .buttonStyle(Encoger()).foregroundStyle(.primary)
                            }
                            Button { queElija(f) } label: {
                                Text("Que lo elija el taller").font(.footnote.weight(.semibold)).padding(.horizontal, 10).padding(.vertical, 7)
                                    .background(Color.hot.opacity(0.14), in: Capsule()).foregroundStyle(Color.hot)
                            }
                            .buttonStyle(Encoger())
                        }
                    }
                }
                .padding(12)
                .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            if let c = l.cambio {
                HStack {
                    Label(c, systemImage: "arrow.triangle.swap").font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    Spacer()
                    Button("Deshacer") { deshacer() }.font(.caption.weight(.bold))
                }
                .transition(.opacity)
            }
        }
        .padding(12)
        .tarjeta()
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: l)
    }

    private func cambiar(_ a: Filamento, _ f: LineaForm.Falta) {
        l.linea = Linea(filamento_id: a.id, nombre: a.nombre, color: a.color, gramos: l.linea.gramos)
        l.cambio = "En vez de \(f.material) \(Perfiles.nombreColor(f.color)): \(a.nombre)"
    }
    private func queElija(_ f: LineaForm.Falta) {
        l.cambio = "No había \(f.material) \(Perfiles.nombreColor(f.color)): que lo elija el taller"
    }
    private func deshacer() {
        guard let f = l.falta else { return }
        l.linea = Linea(filamento_id: nil, nombre: f.material, color: f.color, gramos: l.linea.gramos)
        l.cambio = nil
    }
}

/// animación al hacer el pedido: capas que se apilan
private struct Hecho: View {
    @State private var capas = 0
    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            VStack(spacing: 18) {
                VStack(spacing: 6) {
                    ForEach((0..<5).reversed(), id: \.self) { i in
                        Capsule().fill(i == 0 ? Color.hot : Color.hot2.opacity(0.6 + Double(i) * 0.08))
                            .frame(width: 60 + CGFloat(5 - i) * 18, height: 12)
                            .scaleEffect(x: capas > i ? 1 : 0.01, anchor: .center)
                            .opacity(capas > i ? 1 : 0)
                    }
                }
                Text("¡Pedido hecho!").font(.title2.weight(.heavy))
            }
        }
        .task {
            for i in 1...5 {
                try? await Task.sleep(for: .milliseconds(110))
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { capas = i }
            }
        }
    }
}
