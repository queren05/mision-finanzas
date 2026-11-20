import SwiftUI

// Piezas pequeñas que se repiten en varias pantallas.

struct Avatar: View {
    @Environment(Tienda.self) private var t
    let nombre: String
    var size: CGFloat = 28
    /// cuenta de la persona: si tiene foto de perfil, sale la foto
    var uid: String? = nil
    var body: some View {
        if let u = t.avatar(uid) {
            AsyncImage(url: u) { i in i.resizable().scaledToFill() } placeholder: { inicial }
                .frame(width: size, height: size).clipShape(Circle())
                .overlay(Circle().strokeBorder(.primary.opacity(0.1)))
        } else { inicial }
    }
    private var inicial: some View {
        Text(String(nombre.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased())
            .font(.system(size: size * 0.45, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(colorPersona(nombre).gradient, in: Circle())
    }
}

struct Chip: View {
    let estado: Estado
    var body: some View {
        HStack(spacing: 5) {
            if estado == .imprimiendo { Pulso(color: estado.color) } else { Circle().fill(estado.color).frame(width: 7, height: 7) }
            Text(estado.label).lineLimit(1)
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(estado.color)
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(estado.color.opacity(0.14), in: Capsule())
        .fixedSize()
    }
}

struct Etiqueta: View {
    let texto: String
    var color: Color = .secondary
    var icono: String? = nil
    var body: some View {
        HStack(spacing: 4) {
            if let icono { Image(systemName: icono) }
            Text(texto).lineLimit(1)
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(color)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(color.opacity(0.13), in: Capsule())
        .fixedSize()
    }
}

/// punto que late (se está imprimiendo)
struct Pulso: View {
    var color: Color
    @State private var on = false
    var body: some View {
        Circle().fill(color).frame(width: 7, height: 7)
            .background(Circle().stroke(color, lineWidth: 2).scaleEffect(on ? 2.2 : 0.6).opacity(on ? 0 : 1))
            .onAppear { withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) { on = true } }
    }
}

struct Muestra: View {
    let hex: String
    var size: CGFloat = 14
    var body: some View {
        Circle().fill(Color(hex: hex)).frame(width: size, height: size)
            .overlay(Circle().strokeBorder(.primary.opacity(0.18), lineWidth: 1))
    }
}

/// foto de la figura; sin foto, franjas con los colores como capas impresas
struct Portada: View {
    let p: Pedido
    var body: some View {
        ZStack {
            Color(.secondarySystemBackground)
            if let u = p.portada {
                AsyncImage(url: u, transaction: Transaction(animation: .easeOut(duration: 0.35))) { fase in
                    switch fase {
                    case .success(let img): img.resizable().scaledToFill().transition(.opacity)
                    case .failure: Capas(colores: p.lineas.map(\.color))
                    default: Capas(colores: p.lineas.map(\.color)).opacity(0.5)
                    }
                }
            } else {
                Capas(colores: p.lineas.map(\.color))
            }
        }
        .clipped()
    }
}

struct Capas: View {
    let colores: [String]
    var body: some View {
        let cs = colores.isEmpty ? ["#9aa3ad"] : colores
        GeometryReader { g in
            VStack(spacing: g.size.height * 0.022) {
                ForEach(0..<12, id: \.self) { i in
                    Capsule().fill(Color(hex: cs[i % cs.count]).opacity(0.55 + Double(i % 3) * 0.15))
                        .frame(width: g.size.width * (i < 3 ? 0.36 : i < 6 ? 0.48 : 0.6))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, g.size.height * 0.16)
        }
    }
}

/// botón de la cuenta (arriba a la derecha de cada pantalla)
struct BotonCuenta: View {
    @Environment(Tienda.self) private var t
    @State private var abierto = false
    var body: some View {
        Button { abierto = true } label: {
            if let s = t.sesion { Avatar(nombre: s.nombre, size: 30, uid: s.id) }
            else { Text("Entrar").font(.subheadline.weight(.bold)) }
        }
        .accessibilityLabel(t.sesion == nil ? "Entrar" : "Tu cuenta")
        .sheet(isPresented: $abierto) { CuentaView() }
        .task { if ProcessInfo.processInfo.arguments.contains("-perfil") && t.pestana == .cola { abierto = true } }
    }
}

/// contraseña con botón para verla mientras se escribe
struct CampoClave: View {
    let titulo: String
    @Binding var texto: String
    var nueva = false
    @State private var ver = false
    var body: some View {
        HStack {
            Group {
                if ver { TextField(titulo, text: $texto) } else { SecureField(titulo, text: $texto) }
            }
            .textContentType(nueva ? .newPassword : .password)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            Button { ver.toggle() } label: {
                Image(systemName: ver ? "eye.slash" : "eye").contentTransition(.symbolEffect(.replace))
                    .foregroundStyle(.secondary).frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(ver ? "Ocultar contraseña" : "Ver contraseña")
        }
    }
}

/// tarjeta con fondo y borde suave
struct Tarjeta: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.primary.opacity(0.06)))
    }
}
extension View { func tarjeta() -> some View { modifier(Tarjeta()) } }

/// un dato grande con su etiqueta
struct Cifra: View {
    let etiqueta: String
    let valor: String
    var color: Color = .primary
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(etiqueta.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(.secondary).tracking(0.6).lineLimit(1)
            Text(valor).font(.system(.title3, design: .monospaced).weight(.bold)).foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.6).contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .tarjeta()
    }
}

/// pulsar y que encoja un poco
struct Encoger: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct Vacio: View {
    let titulo: String
    let icono: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icono).font(.system(size: 44)).foregroundStyle(.secondary).symbolEffect(.pulse)
            Text(titulo).font(.headline)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .background(RoundedRectangle(cornerRadius: 22).strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [7, 6])).foregroundStyle(.quaternary))
    }
}

/// carrete de filamento: aro de plástico, el hilo enrollado (con líneas que se ven en negro y en blanco),
/// el centro con su agujero y, por fuera, cuánto queda
struct Carrete: View {
    let hex: String
    var fraccion: Double = 1
    var size: CGFloat = 60
    var body: some View {
        let c = Color(hex: hex)
        let claro = luminancia(hex) > 0.55
        let linea = claro ? Color.black.opacity(0.12) : Color.white.opacity(0.16)
        ZStack {
            // aro del carrete (plástico gris, se ve en los dos modos)
            Circle().fill(Color(.systemGray3)).frame(width: size * 0.86, height: size * 0.86)
            Circle().strokeBorder(Color.primary.opacity(0.18), lineWidth: 1).frame(width: size * 0.86, height: size * 0.86)
            // el filamento enrollado
            Circle().fill(c).frame(width: size * 0.74, height: size * 0.74)
            ForEach(1..<5, id: \.self) { i in
                Circle().stroke(linea, lineWidth: 0.8).frame(width: size * (0.74 - Double(i) * 0.075), height: size * (0.74 - Double(i) * 0.075))
            }
            Circle().strokeBorder(linea.opacity(1.6), lineWidth: 1).frame(width: size * 0.74, height: size * 0.74)
            // centro del carrete
            Circle().fill(Color(.systemGray2)).frame(width: size * 0.3, height: size * 0.3)
            Circle().fill(Color(.secondarySystemGroupedBackground)).frame(width: size * 0.14, height: size * 0.14)
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.2), lineWidth: 1))
            // lo que queda
            Circle().stroke(Color.primary.opacity(0.08), lineWidth: 3).frame(width: size, height: size)
            Circle().trim(from: 0, to: max(0, min(1, fraccion))).stroke(Color.hot, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: size, height: size).rotationEffect(.degrees(-90))
        }
        .frame(width: size + 3, height: size + 3)
        .accessibilityHidden(true)
    }

    private func luminancia(_ h: String) -> Double {
        var x = h.replacingOccurrences(of: "#", with: "")
        if x.count == 3 { x = x.map { "\($0)\($0)" }.joined() }
        let v = UInt64(x.prefix(6), radix: 16) ?? 0x999999
        return (0.299 * Double((v >> 16) & 0xff) + 0.587 * Double((v >> 8) & 0xff) + 0.114 * Double(v & 0xff)) / 255
    }
}
