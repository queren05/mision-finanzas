import Foundation

// Lo mismo que calcula la web (src/lib/coste.ts y perfiles.ts) y la base de datos (función _coste).

private func r2(_ v: Double) -> Double { (v * 100).rounded() / 100 }

/// junta las líneas que van al mismo rollo (o, sin rollo, al mismo color): cuentan como un solo color
func juntarLineas(_ ls: [Linea]) -> [Linea] {
    var out: [Linea] = []
    var idx: [String: Int] = [:]
    for l in ls {
        let k = l.filamento_id.map { "f:" + $0 } ?? "c:" + l.color.lowercased()
        if let i = idx[k] { out[i].gramos = ((out[i].gramos + l.gramos) * 10).rounded() / 10 }
        else { idx[k] = out.count; out.append(l) }
    }
    return out
}

func calcularCoste(_ lineasSueltas: [Linea], minutos: Int, copias: Int, filamentos: [Filamento], ajustes a: Ajustes) -> Detalle {
    let lineas = juntarLineas(lineasSueltas)
    let cop = Double(max(1, copias))
    var fil = 0.0, gtot = 0.0, colores = 0
    let out: [LineaCoste] = lineas.map { l in
        let f = l.filamento_id.flatMap { id in filamentos.first { $0.id == id } }
        let precio = f?.precio ?? a.precio_defecto
        let peso = (f?.peso ?? 0) > 0 ? f!.peso : a.peso_defecto
        let g = max(0, l.gramos) * cop
        let c = g * precio / peso
        fil += c; gtot += g
        if g > 0 { colores += 1 }
        return LineaCoste(nombre: f?.nombre ?? l.nombre, color: f?.color ?? l.color, gramos: g, precio: precio, peso: peso, coste: r2(c))
    }
    // cada color de más purga hilo: 2 colores +10 %, 3 colores +20 %… (máximo 50 %)
    let mermaPct = colores > 1 ? min(50, a.merma_pct * Double(colores - 1)) : 0
    let merma = fil * mermaPct / 100
    let luz = Double(minutos) / 60 * cop * a.luz_hora
    return Detalle(filamento: r2(fil), merma: r2(merma), merma_pct: mermaPct, luz: r2(luz), gramos: gtot, total: r2(fil + merma + luz), lineas: out)
}

/// gramos gratis que le quedan a una persona (lo mismo que _gratis_restante en la base de datos)
func gratisRestante(_ pedidos: [Pedido], _ a: Ajustes, uid: String?, nombre: String, excluir: String? = nil) -> Double {
    let n = nombre.trimmingCharacters(in: .whitespaces).lowercased()
    let usados = pedidos.filter { p in
        p.estado != .cancelado && p.id != excluir &&
            (uid != nil ? p.user_id == uid : (p.user_id == nil && p.nombre.trimmingCharacters(in: .whitespaces).lowercased() == n))
    }.reduce(0) { $0 + $1.coste_detalle.gratis_g }
    return max(0, a.gratis_g - usados)
}

/// descuenta el filamento (y su purga) de los gramos gratis; la luz se cobra igual
func aplicarGratis(_ d: Detalle, _ restante: Double) -> Detalle {
    var x = d
    let libre = min(d.gramos, max(0, restante))
    x.gratis_g = (libre * 10).rounded() / 10
    x.descuento = d.gramos > 0 && libre > 0 ? r2((d.filamento + d.merma) * libre / d.gramos) : 0
    x.total = max(0, r2(d.total - x.descuento))
    return x
}

enum Perfiles {
    /// tiempo aproximado en la A1 mini (acelera menos que las X1/P1/H2)
    static func minutosA1mini(_ p: Perfil) -> Int {
        let m = p.modelo
        let f: Double
        if m == "N1" { f = 1 }
        else if m == "N2S" || m == "N9" { f = 1.05 }
        else if ["BL-P", "C1", "N6", "N7", "O1"].contains(where: { m.hasPrefix($0) }) { f = 1.3 }
        else { f = 1.15 }
        return Int((Double(p.minutos) * f).rounded())
    }

    /// el primer enlace del texto pegado (o el texto, si ya es un enlace)
    static func limpiar(_ texto: String) -> String {
        let t = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        if let r = t.range(of: #"https?://[^\s]+"#, options: [.regularExpression, .caseInsensitive]) { return String(t[r]) }
        if !t.isEmpty && !t.contains(" ") && t.contains(".") { return "https://" + t }
        return t
    }

    static func esMakerWorld(_ url: String) -> Bool {
        url.range(of: #"^https?://([a-z0-9-]+\.)*makerworld\.com(\.cn)?/"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// el perfil del enlace (#profileId-…), el hecho para la A1 mini, el principal o el primero
    static func inicial(_ ps: [Perfil], url: String) -> Perfil? {
        let id = url.range(of: #"profileId-(\d+)"#, options: .regularExpression).map { String(url[$0].dropFirst(10)) }
        return ps.first { $0.id == id } ?? ps.first { $0.modelo == "N1" } ?? ps.first { $0.porDefecto && $0.a1mini } ?? ps.first { $0.a1mini } ?? ps.first
    }

    static func urlConPerfil(_ url: String, _ p: Perfil?) -> String {
        guard let p, url.lowercased().contains("makerworld.com") else { return url }
        return (url.components(separatedBy: "#").first ?? url) + "#profileId-" + p.id
    }

    private static func rgb(_ h: String) -> (Double, Double, Double) {
        var x = h.replacingOccurrences(of: "#", with: "")
        if x.count == 3 { x = x.map { "\($0)\($0)" }.joined() }
        x = x.padding(toLength: 6, withPad: "0", startingAt: 0)
        let v = UInt64(x.prefix(6), radix: 16) ?? 0
        return (Double((v >> 16) & 0xff), Double((v >> 8) & 0xff), Double(v & 0xff))
    }
    static func distancia(_ a: String, _ b: String) -> Double {
        let (r1, g1, b1) = rgb(a), (r2, g2, b2) = rgb(b)
        let rm = (r1 + r2) / 2
        return ((2 + rm / 256) * pow(r1 - r2, 2) + 4 * pow(g1 - g2, 2) + (2 + (255 - rm) / 256) * pow(b1 - b2, 2)).squareRoot()
    }
    static func mismoMaterial(_ a: String, _ b: String) -> Bool {
        a.trimmingCharacters(in: .whitespaces).uppercased() == b.trimmingCharacters(in: .whitespaces).uppercased()
    }

    /// reparte los gramos del perfil entre los rollos que hay: mismo material y color parecido.
    /// Si no hay ninguno así, la línea lleva «falta» para avisar.
    static func lineas(_ p: Perfil, _ fils: [Filamento]) -> [LineaForm] {
        var out: [LineaForm] = []
        for c in p.colores where c.gramos > 0 {
            var mejor: Filamento? = nil
            var dmin = Double.infinity
            for f in fils where f.disponible && mismoMaterial(f.material, c.material) {
                let d = distancia(c.color, f.color)
                if d < dmin { dmin = d; mejor = f }
            }
            if let m = mejor, dmin < 150 {
                if let i = out.firstIndex(where: { $0.linea.filamento_id == m.id }) { out[i].linea.gramos += c.gramos }
                else { out.append(LineaForm(linea: Linea(filamento_id: m.id, nombre: m.nombre, color: m.color, gramos: c.gramos))) }
            } else {
                out.append(LineaForm(linea: Linea(filamento_id: nil, nombre: c.material, color: c.color, gramos: c.gramos), falta: .init(color: c.color, material: c.material)))
            }
        }
        for i in out.indices { out[i].linea.gramos = (out[i].linea.gramos * 10).rounded() / 10; out[i].orig = out[i].linea }
        return out
    }

    /// rollos que se pueden ofrecer en lugar de uno que no hay: primero el mismo material, luego el color más parecido
    static func alternativas(_ f: LineaForm.Falta, _ fils: [Filamento], n: Int = 4) -> [Filamento] {
        fils.filter(\.disponible)
            .map { ($0, distancia(f.color, $0.color) + (mismoMaterial($0.material, f.material) ? 0 : 400)) }
            .sorted { $0.1 < $1.1 }
            .prefix(n).map(\.0)
    }

    /// nombre aproximado de un color, para las notas
    static func nombreColor(_ hex: String) -> String {
        let (r, g, b) = rgb(hex)
        let mx = max(r, g, b), mn = min(r, g, b)
        if mx < 60 { return "negro" }
        if mn > 200 { return "blanco" }
        if mx - mn < 30 { return "gris" }
        if r >= g && r >= b { return g > 150 ? (b > 120 ? "rosa" : "amarillo") : (g > 90 ? "naranja" : "rojo") }
        if g >= r && g >= b { return "verde" }
        return r > 120 ? "morado" : "azul"
    }
}

/// una línea del formulario de pedir: el rollo elegido y, si no hay ninguno parecido, lo que falta
struct LineaForm: Identifiable, Hashable {
    struct Falta: Hashable { var color: String; var material: String }
    var id = UUID()
    var linea: Linea
    var falta: Falta? = nil
    /// texto del cambio hecho (va a las notas del pedido)
    var cambio: String? = nil
    /// cómo venía en el perfil (para volver atrás)
    var orig: Linea? = nil
}
