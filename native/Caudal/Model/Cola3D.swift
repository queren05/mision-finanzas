import Foundation
import SwiftUI
import UserNotifications
import BackgroundTasks

// Cola 3D: la web de pedidos de impresión 3D (queren05.github.io/cola-3d) gestionada desde Caudal.
// Lee de Supabase con la clave pública y escribe con las funciones del taller (llevan la clave del taller).

struct C3Linea: Codable, Hashable {
    var filamento_id: String?
    var nombre: String
    var color: String
    var gramos: Double
}

struct C3LineaCoste: Codable, Hashable {
    var nombre: String
    var color: String
    var gramos: Double
    var precio: Double
    var peso: Double
    var coste: Double
}

struct C3Detalle: Codable, Hashable {
    var filamento: Double = 0
    var merma: Double = 0
    var merma_pct: Double = 0
    var luz: Double = 0
    var gramos: Double = 0
    var total: Double = 0
    var lineas: [C3LineaCoste] = []
    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        filamento = (try? c.decode(Double.self, forKey: .filamento)) ?? 0
        merma = (try? c.decode(Double.self, forKey: .merma)) ?? 0
        merma_pct = (try? c.decode(Double.self, forKey: .merma_pct)) ?? 0
        luz = (try? c.decode(Double.self, forKey: .luz)) ?? 0
        gramos = (try? c.decode(Double.self, forKey: .gramos)) ?? 0
        total = (try? c.decode(Double.self, forKey: .total)) ?? 0
        lineas = (try? c.decode([C3LineaCoste].self, forKey: .lineas)) ?? []
    }
}

enum C3Estado: String, Codable, CaseIterable, Identifiable {
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
        case .pendiente: .orange
        case .imprimiendo: .blue
        case .impreso: .green
        case .entregado: .teal
        case .cancelado: .gray
        }
    }
    var icon: String {
        switch self {
        case .pendiente: "clock.fill"
        case .imprimiendo: "printer.fill"
        case .impreso: "checkmark.seal.fill"
        case .entregado: "hand.thumbsup.fill"
        case .cancelado: "xmark.circle.fill"
        }
    }
}

struct C3Pedido: Codable, Identifiable, Hashable {
    var id: String
    var creado: String
    var actualizado: String = ""
    var nombre: String
    var url: String
    var titulo: String = ""
    var imagen: String = ""
    var lineas: [C3Linea] = []
    var minutos: Int = 0
    var copias: Int = 1
    var notas: String = ""
    var estado: C3Estado = .pendiente
    var pagado: Bool = false
    var coste: Double = 0
    var coste_detalle: C3Detalle = C3Detalle()

    init(id: String, creado: String, nombre: String, url: String, titulo: String, imagen: String, lineas: [C3Linea], minutos: Int, copias: Int = 1, notas: String = "", estado: C3Estado, pagado: Bool, coste: Double) {
        self.id = id; self.creado = creado; self.nombre = nombre; self.url = url; self.titulo = titulo; self.imagen = imagen
        self.lineas = lineas; self.minutos = minutos; self.copias = copias; self.notas = notas; self.estado = estado; self.pagado = pagado; self.coste = coste
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        creado = (try? c.decode(String.self, forKey: .creado)) ?? ""
        actualizado = (try? c.decode(String.self, forKey: .actualizado)) ?? ""
        nombre = (try? c.decode(String.self, forKey: .nombre)) ?? ""
        url = (try? c.decode(String.self, forKey: .url)) ?? ""
        titulo = (try? c.decode(String.self, forKey: .titulo)) ?? ""
        imagen = (try? c.decode(String.self, forKey: .imagen)) ?? ""
        lineas = (try? c.decode([C3Linea].self, forKey: .lineas)) ?? []
        minutos = (try? c.decode(Int.self, forKey: .minutos)) ?? 0
        copias = (try? c.decode(Int.self, forKey: .copias)) ?? 1
        notas = (try? c.decode(String.self, forKey: .notas)) ?? ""
        estado = (try? c.decode(C3Estado.self, forKey: .estado)) ?? .pendiente
        pagado = (try? c.decode(Bool.self, forKey: .pagado)) ?? false
        coste = (try? c.decode(Double.self, forKey: .coste)) ?? 0
        coste_detalle = (try? c.decode(C3Detalle.self, forKey: .coste_detalle)) ?? C3Detalle()
    }

    var nombreFigura: String { titulo.isEmpty ? (URL(string: url)?.host ?? "Pedido") : titulo }
    var gramos: Double { coste_detalle.gramos > 0 ? coste_detalle.gramos : lineas.reduce(0) { $0 + $1.gramos } * Double(copias) }
    var fecha: Date { C3.fecha(creado) ?? Date() }
}

struct C3Filamento: Codable, Identifiable, Hashable {
    var id: String = ""
    var nombre: String = ""
    var material: String = "PLA"
    var color: String = "#cccccc"
    var precio: Double? = nil
    var peso: Double = 1000
    var stock_g: Double = 1000
    var activo: Bool = true
    var orden: Int = 0
}

struct C3Ajustes: Codable, Hashable {
    var precio_defecto: Double = 17.99
    var peso_defecto: Double = 1000
    var luz_hora: Double = 0.10
    var merma_pct: Double = 10
    var bizum: String = ""
    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        precio_defecto = (try? c.decode(Double.self, forKey: .precio_defecto)) ?? 17.99
        peso_defecto = (try? c.decode(Double.self, forKey: .peso_defecto)) ?? 1000
        luz_hora = (try? c.decode(Double.self, forKey: .luz_hora)) ?? 0.10
        merma_pct = (try? c.decode(Double.self, forKey: .merma_pct)) ?? 10
        bizum = (try? c.decode(String.self, forKey: .bizum)) ?? ""
    }
}

enum C3Error: LocalizedError {
    case sinConfigurar, mensaje(String)
    var errorDescription: String? {
        switch self {
        case .sinConfigurar: "Falta conectar la web"
        case .mensaje(let m): m
        }
    }
}

/// Conexión con la web: datos, cambios y avisos de pedidos nuevos.
@MainActor @Observable
final class C3 {
    static let shared = C3()
    nonisolated static let tarea = "es.david.caudal.cola3d"
    nonisolated static let web = "https://queren05.github.io/cola-3d/"

    // ajustes de la conexión (solo en este iPhone)
    var url: String { didSet { guardarAjuste("c3.url", url) } }
    var anon: String { didSet { guardarAjuste("c3.anon", anon) } }
    var clave: String { didSet { guardarAjuste("c3.clave", clave) } }
    var avisos: Bool { didSet { UserDefaults.standard.set(avisos, forKey: "c3.avisos") } }

    var pedidos: [C3Pedido] = []
    var filamentos: [C3Filamento] = []
    var ajustes = C3Ajustes()
    var cargando = false
    /// abrir el apartado (al tocar un aviso)
    var abrir = false
    var error: String? = nil
    var actualizado: Date? = nil
    let demo: Bool

    var configurado: Bool { demo || (!url.isEmpty && !anon.isEmpty) }
    var pendientes: Int { pedidos.filter { $0.estado == .pendiente }.count }

    /// cobros ya hechos (marcados pagados en la web o aquí) que aún no están apuntados como ingreso en Caudal
    var cobrosSinApuntar: [C3Pedido] {
        let ya = Set(UserDefaults.standard.stringArray(forKey: "c3.apuntados") ?? [])
        // si alguno ya lo tenías apuntado a mano, «No apuntar estos» lo quita de la lista sin duplicarlo
        return pedidos.filter { $0.pagado && $0.estado != .cancelado && $0.coste > 0 && !ya.contains($0.id) }
            .sorted { $0.creado > $1.creado }
    }
    func marcarApuntado(_ ids: [String]) {
        var ya = Set(UserDefaults.standard.stringArray(forKey: "c3.apuntados") ?? [])
        ids.forEach { ya.insert($0) }
        UserDefaults.standard.set(Array(ya), forKey: "c3.apuntados")
        withAnimation { pedidos = pedidos }
    }
    var porCobrar: Double { pedidos.filter { !$0.pagado && $0.estado != .cancelado }.reduce(0) { $0 + $1.coste } }

    private init() {
        let d = UserDefaults.standard
        url = d.string(forKey: "c3.url") ?? ""
        anon = d.string(forKey: "c3.anon") ?? ""
        clave = d.string(forKey: "c3.clave") ?? ""
        avisos = d.object(forKey: "c3.avisos") as? Bool ?? true
        demo = ProcessInfo.processInfo.arguments.contains("-cola3d")
        if demo { cargarDemo() }
    }

    private func guardarAjuste(_ k: String, _ v: String) {
        UserDefaults.standard.set(v.trimmingCharacters(in: .whitespacesAndNewlines), forKey: k)
    }

    // MARK: lectura

    private func peticion(_ ruta: String, metodo: String = "GET", cuerpo: Any? = nil) throws -> URLRequest {
        let base = url.trimmingCharacters(in: CharacterSet(charactersIn: "/ ").union(.whitespacesAndNewlines))
        guard !base.isEmpty, !anon.isEmpty, let u = URL(string: base + "/rest/v1/" + ruta) else { throw C3Error.sinConfigurar }
        var r = URLRequest(url: u, timeoutInterval: 20)
        r.httpMethod = metodo
        r.setValue(anon, forHTTPHeaderField: "apikey")
        r.setValue("Bearer " + anon, forHTTPHeaderField: "Authorization")
        r.setValue("application/json", forHTTPHeaderField: "Accept")
        if let cuerpo {
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.httpBody = try JSONSerialization.data(withJSONObject: cuerpo)
        }
        return r
    }

    private func enviar(_ r: URLRequest) async throws -> Data {
        let (data, resp) = try await URLSession.shared.data(for: r)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            throw C3Error.mensaje((j?["message"] as? String) ?? "La web ha respondido con un error (\(code))")
        }
        return data
    }

    func cargar() async {
        guard !demo else { return }
        guard configurado else { return }
        cargando = true
        defer { cargando = false }
        do {
            let rp = try peticion("pedidos?select=*&order=creado.desc")
            let rf = try peticion("filamentos?select=*&order=orden,creado")
            let ra = try peticion("ajustes?select=*&id=eq.1")
            async let p = enviar(rp)
            async let f = enviar(rf)
            async let a = enviar(ra)
            let dec = JSONDecoder()
            let (dp, df, da) = try await (p, f, a)
            let nuevos = try dec.decode([C3Pedido].self, from: dp)
            withAnimation(Motion.layout) {
                pedidos = nuevos
                filamentos = (try? dec.decode([C3Filamento].self, from: df)) ?? []
                ajustes = (try? dec.decode([C3Ajustes].self, from: da))?.first ?? C3Ajustes()
            }
            vistos(nuevos.map(\.id))
            actualizado = Date()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: escritura (funciones del taller)

    private func rpc(_ funcion: String, _ args: [String: Any]) async throws {
        if demo { return }
        var a = args
        a["p_clave"] = clave
        _ = try await enviar(try peticion("rpc/" + funcion, metodo: "POST", cuerpo: a))
    }

    func comprobarClave() async -> Bool {
        guard let r = try? peticion("rpc/comprobar_clave", metodo: "POST", cuerpo: ["p_clave": clave]),
              let d = try? await enviar(r) else { return false }
        return String(data: d, encoding: .utf8)?.contains("true") == true
    }

    func cambiar(_ p: C3Pedido, _ cambios: [String: Any]) async throws {
        try await rpc("admin_pedido", ["p_id": p.id, "p": cambios])
        if demo, let i = pedidos.firstIndex(where: { $0.id == p.id }) {
            if let e = cambios["estado"] as? String, let es = C3Estado(rawValue: e) { pedidos[i].estado = es }
            if let pg = cambios["pagado"] as? Bool { pedidos[i].pagado = pg }
            return
        }
        await cargar()
    }

    func borrar(_ p: C3Pedido) async throws {
        try await rpc("admin_borrar_pedido", ["p_id": p.id])
        if demo { pedidos.removeAll { $0.id == p.id }; return }
        await cargar()
    }

    func guardar(_ f: C3Filamento) async throws {
        var j: [String: Any] = ["nombre": f.nombre, "material": f.material, "color": f.color, "peso": Int(f.peso), "stock_g": f.stock_g, "activo": f.activo, "orden": f.orden]
        if !f.id.isEmpty { j["id"] = f.id }
        j["precio"] = f.precio ?? NSNull()
        try await rpc("admin_filamento", ["f": j])
        await cargar()
    }

    func borrar(_ f: C3Filamento) async throws {
        try await rpc("admin_borrar_filamento", ["p_id": f.id])
        await cargar()
    }

    func guardar(_ a: C3Ajustes) async throws {
        try await rpc("admin_ajustes", ["a": ["precio_defecto": a.precio_defecto, "peso_defecto": Int(a.peso_defecto), "luz_hora": a.luz_hora, "merma_pct": a.merma_pct, "bizum": a.bizum]])
        await cargar()
    }

    // MARK: avisos de pedidos nuevos

    /// guarda qué pedidos ya se han visto; la primera vez no avisa de los que ya había
    private func vistos(_ ids: [String]) {
        UserDefaults.standard.set(ids, forKey: "c3.vistos")
    }

    func pedirPermiso() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// se llama en segundo plano (y al abrir Caudal): mira si hay pedidos nuevos y avisa
    func comprobarNuevos() async {
        guard avisos, configurado, !demo else { return }
        let antes = Set(UserDefaults.standard.stringArray(forKey: "c3.vistos") ?? [])
        let primeraVez = UserDefaults.standard.object(forKey: "c3.vistos") == nil
        guard let r = try? peticion("pedidos?select=*&order=creado.desc&limit=30"),
              let d = try? await enviar(r),
              let lista = try? JSONDecoder().decode([C3Pedido].self, from: d) else { return }
        let nuevos = lista.filter { !antes.contains($0.id) && $0.estado == .pendiente }
        var todos = antes
        lista.forEach { todos.insert($0.id) }
        UserDefaults.standard.set(Array(todos), forKey: "c3.vistos")
        guard !primeraVez else { return }
        for p in nuevos.prefix(5) {
            let c = UNMutableNotificationContent()
            c.title = "Pedido nuevo de \(p.nombre)"
            c.body = "\(p.nombreFigura) · \(Money.eur(p.coste)) · \(C3.gramos(p.gramos))"
            c.sound = .default
            c.userInfo = ["cola3d": p.id]
            try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "c3-" + p.id, content: c, trigger: nil))
        }
    }

    /// pide a iOS que vuelva a mirar dentro de un rato (iOS decide cuándo exactamente)
    nonisolated static func programar() {
        let r = BGAppRefreshTaskRequest(identifier: tarea)
        r.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(r)
    }

    // MARK: formato

    nonisolated static func fecha(_ s: String) -> Date? {
        // Supabase manda 6 decimales en los segundos: se dejan en 3
        let s = s.replacingOccurrences(of: #"\.(\d{3})\d+"#, with: ".$1", options: .regularExpression)
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }
    nonisolated static func gramos(_ g: Double) -> String { g >= 1000 ? Money.num(g / 1000).replacingOccurrences(of: ",00", with: "") + " kg" : "\(Int(g.rounded())) g" }
    nonisolated static func duracion(_ min: Int) -> String {
        guard min > 0 else { return "" }
        let h = min / 60, m = min % 60
        return h > 0 ? (m > 0 ? "\(h) h \(m) min" : "\(h) h") : "\(m) min"
    }

    // MARK: datos de muestra para las capturas

    private func cargarDemo() {
        let ahora = Date()
        func hace(_ h: Double) -> String { ISO8601DateFormatter().string(from: ahora.addingTimeInterval(-h * 3600)) }
        pedidos = [
            C3Pedido(id: "d1", creado: hace(0.3), nombre: "Jorlo", url: "https://makerworld.com/es/models/1400373", titulo: "Dragón articulado", imagen: "",
                     lineas: [C3Linea(filamento_id: "f1", nombre: "Negro", color: "#222222", gramos: 62), C3Linea(filamento_id: "f3", nombre: "Rojo", color: "#d63a2f", gramos: 18)],
                     minutos: 290, estado: .pendiente, pagado: false, coste: 2.05),
            C3Pedido(id: "d2", creado: hace(26), nombre: "Mamá", url: "https://makerworld.com/es/models/1", titulo: "Maceta con autorriego", imagen: "",
                     lineas: [C3Linea(filamento_id: "f2", nombre: "Blanco", color: "#f4f4f4", gramos: 245)], minutos: 707, estado: .imprimiendo, pagado: true, coste: 5.59),
            C3Pedido(id: "d3", creado: hace(50), nombre: "Lucía", url: "https://makerworld.com/es/models/2", titulo: "Llavero gatito", imagen: "",
                     lineas: [C3Linea(filamento_id: "f4", nombre: "Rosa", color: "#f19cbb", gramos: 9)], minutos: 38, copias: 3, estado: .pendiente, pagado: true, coste: 0.68),
            C3Pedido(id: "d4", creado: hace(120), nombre: "Jorlo", url: "https://makerworld.com/es/models/3", titulo: "Soporte de mando", imagen: "",
                     lineas: [C3Linea(filamento_id: "f1", nombre: "Negro", color: "#222222", gramos: 88)], minutos: 260, estado: .impreso, pagado: false, coste: 2.02),
        ]
        filamentos = [
            C3Filamento(id: "f1", nombre: "Negro", material: "PLA", color: "#222222", precio: nil, peso: 1000, stock_g: 640, activo: true, orden: 0),
            C3Filamento(id: "f2", nombre: "Blanco", material: "PLA", color: "#f4f4f4", precio: 11, peso: 1000, stock_g: 310, activo: true, orden: 1),
            C3Filamento(id: "f3", nombre: "Rojo", material: "PLA", color: "#d63a2f", precio: nil, peso: 1000, stock_g: 35, activo: true, orden: 2),
            C3Filamento(id: "f4", nombre: "Rosa", material: "PLA", color: "#f19cbb", precio: nil, peso: 1000, stock_g: 900, activo: true, orden: 3),
        ]
        ajustes.bizum = "600 11 22 33"
        actualizado = ahora
    }
}

/// enseña los avisos también con Caudal abierta y, al tocarlos, abre el apartado
final class C3Avisos: NSObject, UNUserNotificationCenterDelegate {
    static let shared = C3Avisos()
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard response.notification.request.content.userInfo["cola3d"] != nil else { return }
        await MainActor.run { C3.shared.abrir = true }
    }
}
