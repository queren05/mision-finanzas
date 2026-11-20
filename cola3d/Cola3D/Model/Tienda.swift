import Foundation
import SwiftUI
import UserNotifications
import BackgroundTasks

/// Todo el estado de la app: datos de la web, tu cuenta y si eres el taller.
@MainActor @Observable
final class Tienda {
    static let shared = Tienda()
    nonisolated static let tarea = "es.david.cola3d.mirar"

    var pedidos: [Pedido] = []
    var filamentos: [Filamento] = []
    var ajustes = Ajustes()
    var cargado = false
    var error: String? = nil
    var sesion: Sesion? { didSet { guardarSesion() } }
    var admin = false
    /// códigos para cancelar los pedidos hechos desde este iPhone
    var tokens: [String: String] { didSet { UserDefaults.standard.set(tokens, forKey: "tokens") } }
    var aviso: (texto: String, error: Bool)? = nil
    /// pedido recién hecho (se resalta en la cola)
    var resaltado: String? = nil
    var pestana: Pestana = .cola
    let demo: Bool

    enum Pestana: Hashable { case cola, pedir, filamentos, gente, taller }

    private init() {
        tokens = UserDefaults.standard.dictionary(forKey: "tokens") as? [String: String] ?? [:]
        demo = ProcessInfo.processInfo.arguments.contains("-demo")
        if let d = UserDefaults.standard.data(forKey: "sesion"), let s = try? JSONDecoder().decode(Sesion.self, from: d) { sesion = s }
        if demo { cargarDemo() }
    }

    private func guardarSesion() {
        if let sesion, let d = try? JSONEncoder().encode(sesion) { UserDefaults.standard.set(d, forKey: "sesion") }
        else { UserDefaults.standard.removeObject(forKey: "sesion") }
    }

    func avisar(_ t: String, error: Bool = false) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { aviso = (t, error) }
        let ahora = t
        Task { try? await Task.sleep(for: .seconds(2.6)); if aviso?.texto == ahora { withAnimation(.easeOut(duration: 0.3)) { aviso = nil } } }
    }

    // MARK: sesión

    /// el token de tu cuenta, renovado si ha caducado
    func token() async -> String? {
        guard var s = sesion else { return nil }
        if s.caduca < Date() {
            do { s = try await Supa.renovar(s); sesion = s }
            catch { sesion = nil; admin = false; return nil }
        }
        return s.access
    }

    func comprobarAdmin() async {
        guard !demo else { return }
        guard let t = await token() else { admin = false; return }
        let d = try? await Supa.rpc("soy_admin", [:], token: t)
        let si = d.flatMap { String(data: $0, encoding: .utf8) }?.contains("true") == true
        withAnimation { admin = si }
        if !si && pestana == .taller { pestana = .cola }
    }

    func entrar(email: String, clave: String) async throws {
        sesion = try await Supa.entrar(email: email.trimmingCharacters(in: .whitespaces).lowercased(), clave: clave)
        await comprobarAdmin()
        avisar("Hola, \(sesion?.nombre ?? "")")
    }

    /// devuelve true si ya ha entrado (si no, hay que confirmar el correo)
    func registrar(nombre: String, email: String, clave: String) async throws -> Bool {
        let s = try await Supa.registrar(nombre: nombre.trimmingCharacters(in: .whitespaces), email: email.trimmingCharacters(in: .whitespaces).lowercased(), clave: clave)
        if let s { sesion = s; await comprobarAdmin(); return true }
        return false
    }

    func salir() async {
        if let t = sesion?.access { await Supa.salir(token: t) }
        withAnimation { sesion = nil; admin = false; if pestana == .taller { pestana = .cola } }
    }

    // MARK: datos

    func cargar() async {
        guard !demo else { return }
        do {
            async let p: [Pedido] = Supa.leer("pedidos?select=*&order=creado")
            async let f: [Filamento] = Supa.leer("filamentos?select=*&order=orden,creado")
            async let a: [Ajustes] = Supa.leer("ajustes?select=*&id=eq.1")
            let (np, nf, na) = try await (p, f, a)
            avisarCambios(np)
            withAnimation(.snappy) {
                pedidos = np
                filamentos = nf
                ajustes = na.first ?? Ajustes()
            }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        cargado = true
    }

    /// llamadas del taller: van con tu cuenta (la base de datos comprueba que eres el dueño)
    private func taller(_ fn: String, _ args: [String: Any]) async throws {
        if demo { return }
        guard let t = await token() else { throw Supa.Fallo(mensaje: "Entra con tu cuenta") }
        var a = args
        a["p_clave"] = ""
        try await Supa.rpc(fn, a, token: t)
    }

    func cambiar(_ p: Pedido, _ cambios: [String: Any], ok: String? = nil) async {
        do {
            try await taller("admin_pedido", ["p_id": p.id, "p": cambios])
            if demo, let i = pedidos.firstIndex(where: { $0.id == p.id }) {
                withAnimation(.snappy) {
                    if let e = cambios["estado"] as? String, let es = Estado(rawValue: e) { pedidos[i].estado = es }
                    if let pg = cambios["pagado"] as? Bool { pedidos[i].pagado = pg }
                    if let pr = cambios["prioridad"] as? Int { pedidos[i].prioridad = pr }
                    if let fs = cambios["fotos"] as? [String] { pedidos[i].fotos = fs }
                }
            } else { await cargar() }
            if let ok { avisar(ok) }
        } catch { avisar(error.localizedDescription, error: true) }
    }

    func borrar(_ p: Pedido) async -> Bool {
        do {
            try await taller("admin_borrar_pedido", ["p_id": p.id])
            if demo { pedidos.removeAll { $0.id == p.id } } else { await cargar() }
            avisar("Pedido borrado")
            return true
        } catch { avisar(error.localizedDescription, error: true); return false }
    }

    func guardar(_ f: Filamento) async -> Bool {
        var j: [String: Any] = ["nombre": f.nombre, "material": f.material, "color": f.color, "peso": Int(f.peso), "stock_g": f.stock_g, "activo": f.activo, "orden": f.orden]
        if !f.id.isEmpty { j["id"] = f.id }
        j["precio"] = f.precio.map { $0 as Any } ?? NSNull()
        do {
            try await taller("admin_filamento", ["f": j])
            if demo {
                if let i = filamentos.firstIndex(where: { $0.id == f.id && !f.id.isEmpty }) { filamentos[i] = f }
                else { var n = f; n.id = UUID().uuidString; filamentos.append(n) }
            } else { await cargar() }
            avisar("Rollo guardado")
            return true
        } catch { avisar(error.localizedDescription, error: true); return false }
    }

    func borrar(_ f: Filamento) async -> Bool {
        do {
            try await taller("admin_borrar_filamento", ["p_id": f.id])
            if demo { filamentos.removeAll { $0.id == f.id } } else { await cargar() }
            avisar("Rollo borrado")
            return true
        } catch { avisar(error.localizedDescription, error: true); return false }
    }

    func guardar(_ a: Ajustes) async -> Bool {
        do {
            try await taller("admin_ajustes", ["a": ["precio_defecto": a.precio_defecto, "peso_defecto": Int(a.peso_defecto), "luz_hora": a.luz_hora, "merma_pct": a.merma_pct, "bizum": a.bizum]])
            if demo { ajustes = a } else { await cargar() }
            avisar("Precios guardados")
            return true
        } catch { avisar(error.localizedDescription, error: true); return false }
    }

    func subirFoto(_ jpeg: Data, a p: Pedido) async throws -> String {
        if demo { return "https://picsum.photos/seed/\(UUID().uuidString.prefix(6))/800" }
        guard let t = await token() else { throw Supa.Fallo(mensaje: "Entra con tu cuenta") }
        return try await Supa.subirFoto(jpeg, pedido: p.id, token: t)
    }

    func quitarFoto(_ u: String, de p: Pedido) async {
        await cambiar(p, ["fotos": p.fotos.filter { $0 != u }], ok: "Foto quitada")
        if let t = await token() { await Supa.borrarFoto(u, token: t) }
    }

    // MARK: pedir y cancelar

    func pedir(nombre: String, url: String, titulo: String, imagen: String, lineas: [Linea], minutos: Int, copias: Int, notas: String) async throws -> String {
        let p: [String: Any] = [
            "nombre": nombre, "url": url, "titulo": titulo, "imagen": imagen,
            "lineas": lineas.map { l -> [String: Any] in ["filamento_id": l.filamento_id.map { $0 as Any } ?? NSNull(), "nombre": l.nombre, "color": l.color, "gramos": l.gramos] },
            "minutos": minutos, "copias": copias, "notas": notas,
        ]
        if demo { return "demo" }
        let d = try await Supa.rpc("crear_pedido", ["p": p], token: await token())
        let j = try JSONSerialization.jsonObject(with: d) as? [String: Any]
        guard let id = j?["id"] as? String else { throw Supa.Fallo(mensaje: "No se ha podido hacer el pedido") }
        if let tk = j?["token"] as? String { tokens[id] = tk }
        await cargar()
        return id
    }

    func cancelar(_ p: Pedido) async -> Bool {
        guard let tk = tokens[p.id] else { return false }
        do {
            try await Supa.rpc("cancelar_pedido", ["p_id": p.id, "p_token": tk], token: await token())
            await cargar()
            avisar("Pedido cancelado")
            return true
        } catch { avisar(error.localizedDescription, error: true); return false }
    }

    // MARK: cálculos de la cola

    func esMio(_ p: Pedido) -> Bool {
        if tokens[p.id] != nil { return true }
        if let s = sesion, p.user_id == s.id { return true }
        return false
    }

    /// lo que se imprime, luego los pendientes (prioridad, pagados primero, por llegada)
    var cola: [Pedido] {
        let imp = pedidos.filter { $0.estado == .imprimiendo }.sorted { $0.creado < $1.creado }
        let pen = pedidos.filter { $0.estado == .pendiente }.sorted {
            if $0.prioridad != $1.prioridad { return $0.prioridad > $1.prioridad }
            if $0.pagado != $1.pagado { return $0.pagado }
            return $0.creado < $1.creado
        }
        return imp + pen
    }

    func turno(_ p: Pedido) -> Int? {
        guard p.estado == .pendiente else { return nil }
        return cola.filter { $0.estado == .pendiente }.firstIndex { $0.id == p.id }.map { $0 + 1 }
    }

    // MARK: avisos

    func pedirPermiso() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// avisa si un pedido tuyo cambia de estado (o, al taller, si llega uno nuevo)
    private func avisarCambios(_ nuevos: [Pedido]) {
        let d = UserDefaults.standard
        let antes = d.dictionary(forKey: "estados") as? [String: String]
        var ahora: [String: String] = [:]
        nuevos.forEach { ahora[$0.id] = $0.estado.rawValue }
        d.set(ahora, forKey: "estados")
        guard let antes else { return }
        for p in nuevos {
            let previo = antes[p.id]
            var titulo: String? = nil, cuerpo = p.nombreFigura
            if admin && previo == nil && p.estado == .pendiente {
                titulo = "Pedido nuevo de \(p.nombre)"
                cuerpo = "\(p.nombreFigura) · \(Fmt.eur(p.coste))"
            } else if esMio(p), let previo, previo != p.estado.rawValue {
                switch p.estado {
                case .imprimiendo: titulo = "Ya se está imprimiendo"
                case .impreso: titulo = "¡Tu pieza está impresa!"
                case .entregado: titulo = "Pedido entregado"
                case .cancelado: titulo = "Pedido cancelado"
                case .pendiente: titulo = nil
                }
            }
            guard let titulo else { continue }
            let c = UNMutableNotificationContent()
            c.title = titulo; c.body = cuerpo; c.sound = .default
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "c3-\(p.id)-\(p.estado.rawValue)", content: c, trigger: nil))
        }
    }

    nonisolated static func programar() {
        let r = BGAppRefreshTaskRequest(identifier: tarea)
        r.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(r)
    }

    // MARK: datos de muestra para las capturas

    private func cargarDemo() {
        let ahora = Date()
        func hace(_ h: Double) -> String { ISO8601DateFormatter().string(from: ahora.addingTimeInterval(-h * 3600)) }
        filamentos = [
            Filamento(id: "f1", nombre: "Azul marino mate", material: "PLA", color: "#0078bf", stock_g: 820, orden: 1),
            Filamento(id: "f2", nombre: "Gris ceniza mate", material: "PLA", color: "#9b9ea0", stock_g: 1000, orden: 2),
            Filamento(id: "f3", nombre: "Carbón mate", material: "PLA", color: "#1c1c1c", stock_g: 410, orden: 3),
            Filamento(id: "f4", nombre: "Blanco marfil mate", material: "PLA", color: "#f2efe6", stock_g: 60, orden: 4),
        ]
        ajustes.bizum = "+34 600 11 22 33"
        func ped(_ id: String, _ h: Double, _ quien: String, _ t: String, _ e: Estado, _ pagado: Bool, _ ls: [Linea], _ min: Int, copias: Int = 1) -> Pedido {
            var p = Pedido(id: id)
            p.creado = hace(h); p.nombre = quien; p.url = "https://makerworld.com/es/models/1400373"; p.titulo = t
            p.estado = e; p.pagado = pagado; p.lineas = ls; p.minutos = min; p.copias = copias
            p.coste_detalle = calcularCoste(ls, minutos: min, copias: copias, filamentos: filamentos, ajustes: ajustes)
            p.coste = p.coste_detalle.total
            p.historial = [Cambio(estado: .pendiente, fecha: p.creado)]
            return p
        }
        let az = Linea(filamento_id: "f1", nombre: "Azul marino mate", color: "#0078bf", gramos: 62)
        let ca = Linea(filamento_id: "f3", nombre: "Carbón mate", color: "#1c1c1c", gramos: 18)
        let bl = Linea(filamento_id: "f4", nombre: "Blanco marfil mate", color: "#f2efe6", gramos: 140)
        let gr = Linea(filamento_id: "f2", nombre: "Gris ceniza mate", color: "#9b9ea0", gramos: 9)
        pedidos = [
            ped("d1", 26, "Mamá", "Maceta con autorriego", .imprimiendo, true, [bl], 707),
            ped("d2", 0.4, "Jorge", "Dragón articulado", .pendiente, false, [az, ca], 290),
            ped("d3", 3, "Lucía", "Llavero gatito", .pendiente, true, [gr], 38, copias: 3),
            ped("d4", 50, "Jorge", "Soporte de mando", .impreso, false, [ca], 260),
            ped("d5", 120, "David", "Organizador de cables", .entregado, true, [az], 140),
        ]
        pedidos[3].fotos = ["https://picsum.photos/seed/c3a/900", "https://picsum.photos/seed/c3b/900"]
        tokens["d2"] = "x"
        sesion = Sesion(access: "", refresh: "", caduca: .distantFuture, id: "u1", email: "jorge@ejemplo.es", nombre: "Jorge")
        admin = ProcessInfo.processInfo.arguments.contains("-taller")
        if admin { sesion?.nombre = "David" }
        cargado = true
    }
}
