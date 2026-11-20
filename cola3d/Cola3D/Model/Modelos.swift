import Foundation
import SwiftUI

// Los mismos datos que la web Cola 3D (queren05.github.io/cola-3d), leídos de Supabase.
// La lectura es tolerante: si falta un campo se usa un valor por defecto.

extension KeyedDecodingContainer {
    func v<T: Decodable>(_ k: Key, _ def: T) -> T { (try? decodeIfPresent(T.self, forKey: k)) ?? def }
    /// números que a veces llegan como texto («17.99»)
    func num(_ k: Key, _ def: Double = 0) -> Double {
        if let d = try? decodeIfPresent(Double.self, forKey: k) { return d }
        if let s = try? decodeIfPresent(String.self, forKey: k), let d = Double(s) { return d }
        return def
    }
}

struct Linea: Codable, Hashable {
    var filamento_id: String?
    var nombre: String
    var color: String
    var gramos: Double
    init(filamento_id: String?, nombre: String, color: String, gramos: Double) {
        self.filamento_id = filamento_id; self.nombre = nombre; self.color = color; self.gramos = gramos
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        filamento_id = c.v(.filamento_id, nil)
        nombre = c.v(.nombre, "")
        color = c.v(.color, "#9aa3ad")
        gramos = c.num(.gramos)
    }
}

struct LineaCoste: Codable, Hashable {
    var nombre: String = ""
    var color: String = ""
    var gramos: Double = 0
    var precio: Double = 0
    var peso: Double = 1000
    var coste: Double = 0
    init(nombre: String, color: String, gramos: Double, precio: Double, peso: Double, coste: Double) {
        self.nombre = nombre; self.color = color; self.gramos = gramos; self.precio = precio; self.peso = peso; self.coste = coste
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        nombre = c.v(.nombre, ""); color = c.v(.color, "")
        gramos = c.num(.gramos); precio = c.num(.precio); peso = c.num(.peso, 1000); coste = c.num(.coste)
    }
}

struct Detalle: Codable, Hashable {
    var filamento: Double = 0
    var merma: Double = 0
    var merma_pct: Double = 0
    var luz: Double = 0
    var gramos: Double = 0
    var total: Double = 0
    var lineas: [LineaCoste] = []
    /// gramos que han salido gratis en este pedido y lo que se ha descontado
    var gratis_g: Double = 0
    var descuento: Double = 0
    /// pieza que el taller ha subido a la vitrina por su cuenta (no se cobra)
    var taller = false
    init() {}
    init(filamento: Double, merma: Double, merma_pct: Double, luz: Double, gramos: Double, total: Double, lineas: [LineaCoste]) {
        self.filamento = filamento; self.merma = merma; self.merma_pct = merma_pct; self.luz = luz; self.gramos = gramos; self.total = total; self.lineas = lineas
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        filamento = c.num(.filamento); merma = c.num(.merma); merma_pct = c.num(.merma_pct)
        luz = c.num(.luz); gramos = c.num(.gramos); total = c.num(.total)
        lineas = c.v(.lineas, [])
        gratis_g = c.num(.gratis_g); descuento = c.num(.descuento); taller = c.v(.taller, false)
    }
}

enum Estado: String, Codable, CaseIterable, Identifiable {
    case pendiente, imprimiendo, impreso, entregado, cancelado
    var id: String { rawValue }
    var label: String {
        switch self {
        case .pendiente: "Pendiente"
        case .imprimiendo: "Imprimiendo"
        case .impreso: "Impreso"
        case .entregado: "Entregado"
        case .cancelado: "Cancelado"
        }
    }
    var color: Color {
        switch self {
        case .pendiente: Color(hex: "#7c8796")
        case .imprimiendo: Color(hex: "#f08c00")
        case .impreso: Color(hex: "#1f9d55")
        case .entregado: Color(hex: "#3563e9")
        case .cancelado: Color(hex: "#c0392b")
        }
    }
    var icono: String {
        switch self {
        case .pendiente: "clock.fill"
        case .imprimiendo: "printer.fill"
        case .impreso: "checkmark.seal.fill"
        case .entregado: "hand.thumbsup.fill"
        case .cancelado: "xmark.circle.fill"
        }
    }
}

struct Cambio: Codable, Hashable {
    var estado: Estado
    var fecha: String
}

struct Pedido: Codable, Identifiable, Hashable {
    var id: String
    var creado: String = ""
    var actualizado: String = ""
    var nombre: String = ""
    var user_id: String? = nil
    var url: String = ""
    var titulo: String = ""
    var imagen: String = ""
    var lineas: [Linea] = []
    var minutos: Int = 0
    var copias: Int = 1
    var notas: String = ""
    var estado: Estado = .pendiente
    var pagado: Bool = false
    var coste: Double = 0
    var coste_detalle: Detalle = Detalle()
    var historial: [Cambio] = []
    var prioridad: Int = 0
    var fotos: [String] = []
    /// más de 4 colores: llega como petición y el taller decide
    var peticion = false
    /// el taller deja imprimirlo sin pagar todavía (se suma a lo que debe)
    var acumulado = false

    init(id: String) { self.id = id }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        creado = c.v(.creado, ""); actualizado = c.v(.actualizado, "")
        nombre = c.v(.nombre, ""); user_id = c.v(.user_id, nil)
        url = c.v(.url, ""); titulo = c.v(.titulo, ""); imagen = c.v(.imagen, "")
        lineas = c.v(.lineas, []); minutos = c.v(.minutos, 0); copias = c.v(.copias, 1)
        notas = c.v(.notas, ""); estado = c.v(.estado, .pendiente); pagado = c.v(.pagado, false)
        coste = c.num(.coste); coste_detalle = c.v(.coste_detalle, Detalle())
        historial = c.v(.historial, []); prioridad = c.v(.prioridad, 0); fotos = c.v(.fotos, []); peticion = c.v(.peticion, false); acumulado = c.v(.acumulado, false)
    }

    var nombreFigura: String { titulo.isEmpty ? (URL(string: url)?.host ?? "Pedido") : titulo }
    var gramos: Double { coste_detalle.gramos > 0 ? coste_detalle.gramos : lineas.reduce(0) { $0 + $1.gramos } * Double(copias) }
    var fecha: Date { Fmt.fecha(creado) ?? Date() }
    var portada: URL? { URL(string: fotos.first ?? imagen) }
    var hecho: Bool { estado == .impreso || estado == .entregado }
    var delTaller: Bool { coste_detalle.taller }
    var colores: Int { lineas.filter { $0.gramos > 0 }.count }
}

struct Filamento: Codable, Identifiable, Hashable {
    var id: String = ""
    var nombre: String = ""
    var material: String = "PLA"
    var color: String = "#cccccc"
    var precio: Double? = nil
    var peso: Double = 1000
    var stock_g: Double = 1000
    var activo: Bool = true
    var orden: Int = 0
    init() {}
    init(id: String, nombre: String, material: String, color: String, precio: Double? = nil, peso: Double = 1000, stock_g: Double, activo: Bool = true, orden: Int = 0) {
        self.id = id; self.nombre = nombre; self.material = material; self.color = color; self.precio = precio
        self.peso = peso; self.stock_g = stock_g; self.activo = activo; self.orden = orden
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = c.v(.id, ""); nombre = c.v(.nombre, ""); material = c.v(.material, "PLA"); color = c.v(.color, "#cccccc")
        let p = c.num(.precio, -1); precio = p < 0 ? nil : p
        peso = c.num(.peso, 1000); stock_g = c.num(.stock_g, 1000); activo = c.v(.activo, true); orden = c.v(.orden, 0)
    }
    var disponible: Bool { activo && stock_g >= 50 }
}

struct Ajustes: Codable, Hashable {
    var precio_defecto: Double = 17.99
    var peso_defecto: Double = 1000
    var luz_hora: Double = 0.10
    var merma_pct: Double = 10
    var bizum: String = ""
    var gratis_g: Double = 50
    /// por debajo no se pide pagar: se acumula (Bizum no deja menos de 0,50 €)
    var pago_minimo: Double = 0.5
    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        precio_defecto = c.num(.precio_defecto, 17.99); peso_defecto = c.num(.peso_defecto, 1000)
        luz_hora = c.num(.luz_hora, 0.1); merma_pct = c.num(.merma_pct, 10); bizum = c.v(.bizum, "")
        gratis_g = c.num(.gratis_g, 50); pago_minimo = c.num(.pago_minimo, 0.5)
    }
}

/// perfil de impresión de MakerWorld (gramos, tiempo y colores ya laminados)
struct Perfil: Codable, Identifiable, Hashable {
    struct Color3: Codable, Hashable {
        var color: String
        var material: String
        var gramos: Double
    }
    var id: String
    var titulo: String = ""
    var impresora: String = ""
    var modelo: String = ""
    var a1mini: Bool = false
    var minutos: Int = 0
    var gramos: Double = 0
    var placas: Int = 0
    var colores: [Color3] = []
    var porDefecto: Bool = false
}

struct Vista: Codable {
    var titulo: String?
    var imagen: String?
    var perfiles: [Perfil]?
    var error: String?
}

struct Sesion: Codable, Equatable {
    var access: String
    var refresh: String
    var caduca: Date
    var id: String
    var email: String
    var nombre: String
}

// MARK: - formato

enum Fmt {
    static func fecha(_ s: String) -> Date? {
        // Supabase manda 6 decimales en los segundos: se dejan en 3
        let s = s.replacingOccurrences(of: #"\.(\d{3})\d+"#, with: ".$1", options: .regularExpression)
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }
    static func eur(_ v: Double) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "es_ES"); f.numberStyle = .currency; f.currencyCode = "EUR"
        return f.string(from: NSNumber(value: v)) ?? String(format: "%.2f €", v)
    }
    static func num(_ v: Double, _ dec: Int = 2) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "es_ES"); f.minimumFractionDigits = 0; f.maximumFractionDigits = dec
        return f.string(from: NSNumber(value: v)) ?? "\(v)"
    }
    static func gramos(_ g: Double) -> String { g >= 1000 ? num(g / 1000) + " kg" : "\(Int(g.rounded())) g" }
    static func duracion(_ min: Int) -> String {
        guard min > 0 else { return "—" }
        let h = min / 60, m = min % 60
        return h > 0 ? (m > 0 ? "\(h) h \(m) min" : "\(h) h") : "\(m) min"
    }
    static func hace(_ d: Date) -> String {
        let s = Date().timeIntervalSince(d)
        if s < 60 { return "ahora" }
        if s < 3600 { return "hace \(Int(s / 60)) min" }
        if s < 86400 { return "hace \(Int(s / 3600)) h" }
        let dias = Int(s / 86400)
        return dias == 1 ? "ayer" : "hace \(dias) días"
    }
    static func fechaLarga(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES"); f.dateFormat = "d 'de' MMMM, HH:mm"
        return f.string(from: d)
    }
    /// número escrito con coma o punto
    static func leer(_ s: String) -> Double? { Double(s.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)) }
}

extension Color {
    init(hex: String) {
        var x = hex.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
        if x.count == 3 { x = x.map { "\($0)\($0)" }.joined() }
        let v = UInt64(x.prefix(6), radix: 16) ?? 0x9aa3ad
        self.init(red: Double((v >> 16) & 0xff) / 255, green: Double((v >> 8) & 0xff) / 255, blue: Double(v & 0xff) / 255)
    }
    var hex: String {
        let u = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        u.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02x%02x%02x", Int(max(0, min(1, r)) * 255), Int(max(0, min(1, g)) * 255), Int(max(0, min(1, b)) * 255))
    }
    static let hot = Color(hex: "#ff5b1f")
    static let hot2 = Color(hex: "#ff8a57")
    static let tinta = Color(hex: "#12151a")
}

/// color de cada persona (siempre el mismo para el mismo nombre)
func colorPersona(_ nombre: String) -> Color {
    let paleta = ["#e8590c", "#d6336c", "#ae3ec9", "#7048e8", "#4263eb", "#1c7ed6", "#1098ad", "#0ca678", "#37b24d", "#f59f00"]
    let h = nombre.lowercased().unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7fffffff }
    return Color(hex: paleta[h % paleta.count])
}

/// una cuenta creada (solo la ve el taller)
struct Cuenta: Codable, Identifiable, Hashable {
    var id: String
    var nombre: String = ""
    var email: String = ""
    var alta: String = ""
    var ultima: String? = nil
    var veces: Int = 0
    var confirmada: Bool = false
    var pedidos: Int = 0
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        nombre = c.v(.nombre, ""); email = c.v(.email, ""); alta = c.v(.alta, ""); ultima = c.v(.ultima, nil)
        veces = c.v(.veces, 0); confirmada = c.v(.confirmada, false); pedidos = c.v(.pedidos, 0)
    }
}
