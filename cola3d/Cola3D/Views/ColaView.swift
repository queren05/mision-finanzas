import SwiftUI

struct ColaView: View {
    @Environment(Tienda.self) private var t
    @State private var filtro = 0
    @State private var abierto: Pedido? = nil

    private var visibles: [Pedido] {
        switch filtro {
        case 0: return t.cola
        case 1: return t.pedidos.filter(\.hecho).sorted { $0.actualizado > $1.actualizado }
        case 2: return t.pedidos.filter { t.esMio($0) }.sorted { $0.creado > $1.creado }
        default: return t.pedidos.sorted { $0.creado > $1.creado }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Cabecera()
                    Picker("Filtro", selection: $filtro.animation(.snappy)) {
                        Text("En cola").tag(0)
                        Text("Impresos").tag(1)
                        Text("Los míos").tag(2)
                        Text("Todos").tag(3)
                    }
                    .pickerStyle(.segmented)

                    if let e = t.error, t.pedidos.isEmpty {
                        Label(e, systemImage: "wifi.exclamationmark").font(.subheadline.weight(.semibold)).foregroundStyle(.red)
                            .frame(maxWidth: .infinity).padding().background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                    }

                    if !t.cargado {
                        ForEach(0..<2, id: \.self) { _ in RoundedRectangle(cornerRadius: 22).fill(.quaternary).frame(height: 260).redacted(reason: .placeholder) }
                    } else if visibles.isEmpty {
                        Vacio(titulo: filtro == 0 ? "No hay nada en cola" : filtro == 2 ? "Todavía no has pedido nada" : "Aquí no hay nada todavía", icono: "printer")
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16)], spacing: 16) {
                            ForEach(Array(visibles.enumerated()), id: \.element.id) { i, p in
                                Button { abierto = p } label: { TarjetaPedido(p: p, turno: t.turno(p)) }
                                    .buttonStyle(Encoger())
                                    .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 16)), removal: .opacity.combined(with: .scale(scale: 0.95))))
                                    .animation(.spring(response: 0.5, dampingFraction: 0.85).delay(Double(min(i, 8)) * 0.03), value: filtro)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .refreshable { await t.cargar() }
            .navigationTitle("La cola")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { BotonCuenta() } }
            .task {
                if ProcessInfo.processInfo.arguments.contains("-detalle") { abierto = t.pedidos.first { $0.id == "d4" } }
            }
            .onChange(of: t.resaltado) { _, id in
                guard id != nil else { return }
                filtro = 0
                Task { try? await Task.sleep(for: .seconds(3)); withAnimation { t.resaltado = nil } }
            }
            .sheet(item: $abierto) { p in
                DetallePedido(id: p.id)
            }
        }
    }
}

/// lo de arriba: qué se imprime ahora y cuánto hay en espera
private struct Cabecera: View {
    @Environment(Tienda.self) private var t
    @State private var brillo = false

    var body: some View {
        let imp = t.pedidos.first { $0.estado == .imprimiendo }
        let pen = t.pedidos.filter { $0.estado == .pendiente }
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.1)).frame(width: 52, height: 52)
                    Image(systemName: "printer.fill").font(.title2).foregroundStyle(imp == nil ? .white.opacity(0.6) : Color.hot)
                        .symbolEffect(.pulse, isActive: imp != nil)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(imp?.nombreFigura ?? "Impresora libre").font(.headline).foregroundStyle(.white).lineLimit(1)
                    Text(imp.map { "Imprimiendo para \($0.nombre)" } ?? "Lista para el siguiente").font(.caption).foregroundStyle(.white.opacity(0.6))
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(imp == nil ? Color.white.opacity(0.06) : Color.hot.opacity(0.22), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(imp == nil ? Color.white.opacity(0.1) : Color.hot.opacity(0.5)))

            HStack(spacing: 10) {
                dato("\(pen.count)", "En espera")
                dato(Fmt.gramos(pen.reduce(0) { $0 + $1.gramos }), "Filamento")
                dato(Fmt.duracion(pen.reduce(0) { $0 + $1.minutos * max(1, $1.copias) }), "Impresión")
            }
        }
        .padding(16)
        .background {
            ZStack(alignment: .topTrailing) {
                Color.tinta
                Circle().fill(RadialGradient(colors: [Color.hot.opacity(0.5), .clear], center: .center, startRadius: 0, endRadius: 160))
                    .frame(width: 320, height: 320).offset(x: 110, y: -150)
                    .scaleEffect(brillo ? 1.12 : 1).opacity(brillo ? 0.8 : 1)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .onAppear { withAnimation(.easeInOut(duration: 3.5).repeatForever()) { brillo = true } }
    }

    private func dato(_ v: String, _ l: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(v).font(.system(.headline, design: .monospaced)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.6).contentTransition(.numericText())
            Text(l).font(.caption2).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
    }
}

struct TarjetaPedido: View {
    @Environment(Tienda.self) private var t
    let p: Pedido
    let turno: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Portada(p: p)
                .frame(height: 190)
                .overlay(alignment: .topLeading) {
                    if let turno {
                        Text("#\(turno)").font(.system(.subheadline, design: .monospaced).weight(.bold)).foregroundStyle(.white)
                            .padding(.horizontal, 9).padding(.vertical, 4).background(Color.tinta, in: RoundedRectangle(cornerRadius: 9)).padding(10)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if !p.delTaller { Text(Fmt.eur(p.coste)).font(.system(.subheadline, design: .monospaced).weight(.bold))
                        .padding(.horizontal, 9).padding(.vertical, 4).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 9)).padding(10) }
                }
                .overlay(alignment: .bottomLeading) {
                    if !p.fotos.isEmpty {
                        Label("Foto real", systemImage: "camera.fill").font(.caption2.weight(.bold))
                            .padding(.horizontal, 8).padding(.vertical, 4).background(.regularMaterial, in: Capsule()).padding(10)
                    }
                }
            VStack(alignment: .leading, spacing: 8) {
                Text(p.nombreFigura).font(.headline).lineLimit(2).multilineTextAlignment(.leading).foregroundStyle(.primary)
                HStack(spacing: 6) {
                    Avatar(nombre: p.nombre, size: 20)
                    Text(p.nombre).lineLimit(1)
                    Text("·").foregroundStyle(.tertiary)
                    Text(Fmt.hace(p.fecha)).lineLimit(1)
                    if t.esMio(p) { Etiqueta(texto: "Tuyo", color: .hot) }
                }
                .font(.footnote).foregroundStyle(.secondary)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) { chips; Spacer(minLength: 4); colores }
                    VStack(alignment: .leading, spacing: 8) { HStack(spacing: 6) { chips }; colores }
                }
            }
            .padding(14)
        }
        .tarjeta()
        .overlay(alignment: .bottom) {
            UnevenRoundedRectangle(bottomLeadingRadius: 20, bottomTrailingRadius: 20).fill(p.estado.color).frame(height: 3)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(t.resaltado == p.id ? RoundedRectangle(cornerRadius: 20).strokeBorder(Color.hot, lineWidth: 2.5) : nil)
        .shadow(color: .black.opacity(0.07), radius: 10, y: 4)
    }

    @ViewBuilder private var chips: some View {
        Chip(estado: p.estado)
        if p.prioridad > 0 && p.estado == .pendiente { Etiqueta(texto: "Prioridad", color: .hot, icono: "arrow.up") }
        if p.estado != .cancelado && !p.delTaller {
            if p.pagado { Etiqueta(texto: "Pagado", color: .green, icono: "checkmark") }
            else { Etiqueta(texto: "Sin pagar", color: .red) }
        }
    }

    private var colores: some View {
        HStack(spacing: 3) {
            ForEach(Array(p.lineas.prefix(4).enumerated()), id: \.offset) { _, l in Muestra(hex: l.color, size: 12) }
            Text(Fmt.gramos(p.gramos)).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary).padding(.leading, 4)
        }
        .fixedSize()
    }
}
