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
    /// me gusta de la vitrina (pieza → cuentas que la han votado)
    var votos: [String: Set<String>] = [:]
    /// piezas que has guardado (en cualquier lista)
    var guardados: Set<String> { Set(listas.map { $0.pedido }) }
    /// tus listas de guardados: qué pieza en qué lista
    var listas: [(pedido: String, lista: String)] = []
    /// foto y nombre de cada cuenta
    var perfiles: [String: (nombre: String, avatar: String)] = [:]
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

    enum Pestana: Hashable { case cola, pedir, vitrina, filamentos, gente, taller }

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

    private var renovando: Task<Sesion?, Never>? = nil

    /// el token de tu cuenta, renovado si ha caducado.
    /// Una sola renovación a la vez (el código de renovar solo vale una vez: si se usa dos veces, Supabase cierra la sesión)
    /// y sin conexión no se cierra la sesión: solo si Supabase dice que ya no vale.
    func token() async -> String? {
        guard let s = sesion else { return nil }
        if s.caduca > Date() { return s.access }
        if let r = renovando { return await r.value?.access }
        let r = Task<Sesion?, Never> { @MainActor in
            do {
                let n = try await Supa.renovar(s)
                self.sesion = n
                return n
            } catch let f as Supa.Fallo where (400..<500).contains(f.codigo) {
                self.sesion = nil
                self.admin = false
                self.avisar("La sesión ha caducado, vuelve a entrar", error: true)
                return nil
            } catch {
                return nil
            }
        }
        renovando = r
        let n = await r.value
        renovando = nil
        return n?.access
    }

    /// cuentas creadas y cuándo han entrado (solo el taller)
    func cuentas() async throws -> [Cuenta] {
        if demo { return [] }
        guard let tk = await token() else { throw Supa.Fallo(mensaje: "Entra con tu cuenta") }
        return try JSONDecoder().decode([Cuenta].self, from: try await Supa.rpc("admin_cuentas", ["p_clave": ""], token: tk))
    }

    func comprobarAdmin() async {
        guard !demo else { return }
        guard let t = await token() else { admin = false; return }
        _ = try? await Supa.rpc("marcar_visita", [:], token: t)
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

    private var cargando = false

    func cargar() async {
        guard !demo, !cargando else { return }
        cargando = true
        defer { cargando = false }
        do {
            async let p: [Pedido] = Supa.leer("pedidos?select=*&order=creado")
            async let f: [Filamento] = Supa.leer("filamentos?select=*&order=orden,creado")
            async let a: [Ajustes] = Supa.leer("ajustes?select=*&id=eq.1")
            let (np, nf, na) = try await (p, f, a)
            // me gusta y guardados: si fallan, lo demás sigue
            struct Voto: Decodable { let pedido_id: String; let user_id: String }
            struct Guardado: Decodable { let pedido_id: String; let lista: String? }
            struct PerfilJ: Decodable { let user_id: String; let nombre: String?; let avatar: String? }
            let pfs: [PerfilJ] = (try? await Supa.leer("perfiles?select=user_id,nombre,avatar")) ?? []
            var npf: [String: (nombre: String, avatar: String)] = [:]
            for x in pfs { npf[x.user_id] = (x.nombre ?? "", x.avatar ?? "") }
            let vs: [Voto] = (try? await Supa.leer("votos?select=pedido_id,user_id")) ?? []
            var nv: [String: Set<String>] = [:]
            for v in vs { nv[v.pedido_id, default: []].insert(v.user_id) }
            var ng: [(pedido: String, lista: String)] = []
            if let tk = await token(), let gs: [Guardado] = try? await Supa.leer("guardados?select=pedido_id,lista", token: tk) {
                ng = gs.map { ($0.pedido_id, $0.lista ?? "Guardados") }
            }
            avisarCambios(np)
            let na1 = na.first ?? Ajustes()
            let listasIguales = listas.count == ng.count && zip(listas, ng).allSatisfy { $0.pedido == $1.pedido && $0.lista == $1.lista }
            let perfilesIguales = perfiles.count == npf.count && npf.allSatisfy { k, v in perfiles[k].map { $0.nombre == v.nombre && $0.avatar == v.avatar } ?? false }
            if pedidos != np || filamentos != nf || ajustes != na1 || votos != nv || !listasIguales || !perfilesIguales {
                withAnimation(.snappy) {
                    if pedidos != np { pedidos = np }
                    if filamentos != nf { filamentos = nf }
                    if ajustes != na1 { ajustes = na1 }
                    if votos != nv { votos = nv }
                    if !listasIguales { listas = ng }
                    if !perfilesIguales { perfiles = npf }
                }
            }
            if error != nil { error = nil }
        } catch {
            // sin conexión: se queda lo que había y se avisa solo si no hay nada que enseñar
            self.error = error.localizedDescription
        }
        if !cargado { cargado = true }
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
                    if let pe = cambios["peticion"] as? Bool { pedidos[i].peticion = pe }
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
            try await taller("admin_ajustes", ["a": ["precio_defecto": a.precio_defecto, "peso_defecto": Int(a.peso_defecto), "luz_hora": a.luz_hora, "merma_pct": a.merma_pct, "bizum": a.bizum, "gratis_g": a.gratis_g, "pago_minimo": a.pago_minimo]])
            if demo { ajustes = a } else { await cargar() }
            avisar("Precios guardados")
            return true
        } catch { avisar(error.localizedDescription, error: true); return false }
    }

    func subirFoto(_ jpeg: Data, a p: Pedido) async throws -> String { try await subirFoto(jpeg, carpeta: p.id) }

    func subirFoto(_ jpeg: Data, carpeta: String) async throws -> String {
        if demo { return "https://picsum.photos/seed/\(UUID().uuidString.prefix(6))/800" }
        guard let t = await token() else { throw Supa.Fallo(mensaje: "Entra con tu cuenta") }
        return try await Supa.subirFoto(jpeg, pedido: carpeta, token: t)
    }

    /// el taller sube a la vitrina algo impreso por su cuenta (sin enlace ni cobro)
    func crearPieza(titulo: String, para: String, url: String, filamento: Filamento?, gramos: Double, entregado: Bool, notas: String, fotos: [String]) async throws -> String {
        var lineas: [[String: Any]] = []
        if let f = filamento, gramos > 0 { lineas = [["filamento_id": f.id, "nombre": f.nombre, "color": f.color, "gramos": gramos]] }
        let p: [String: Any] = ["titulo": titulo, "nombre": para, "url": url, "lineas": lineas, "copias": 1, "minutos": 0,
                                "estado": entregado ? "entregado" : "impreso", "notas": notas, "fotos": fotos]
        if demo {
            var n = Pedido(id: UUID().uuidString)
            n.creado = ISO8601DateFormatter().string(from: Date()); n.nombre = para.isEmpty ? "Taller" : para; n.titulo = titulo
            n.estado = entregado ? .entregado : .impreso; n.pagado = true; n.fotos = fotos; n.coste_detalle.taller = true
            pedidos.append(n)
            return n.id
        }
        guard let tk = await token() else { throw Supa.Fallo(mensaje: "Entra con tu cuenta") }
        let d = try await Supa.rpc("admin_crear_pieza", ["p_clave": "", "p": p], token: tk)
        let id = String(data: d, encoding: .utf8)?.trimmingCharacters(in: CharacterSet(charactersIn: "\" \n")) ?? ""
        await cargar()
        avisar("Pieza añadida a la vitrina")
        return id
    }

    func quitarFoto(_ u: String, de p: Pedido) async {
        await cambiar(p, ["fotos": p.fotos.filter { $0 != u }], ok: "Foto quitada")
        if let t = await token() { await Supa.borrarFoto(u, token: t) }
    }

    // MARK: me gusta, guardar y pedir igual

    func meGusta(_ p: Pedido) -> Bool { sesion.map { votos[p.id]?.contains($0.id) ?? false } ?? false }

    func votar(_ p: Pedido) async {
        guard let s = sesion else { avisar("Entra con tu cuenta para votar", error: true); return }
        let antes = votos[p.id] ?? []
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
            if antes.contains(s.id) { votos[p.id]?.remove(s.id) } else { votos[p.id, default: []].insert(s.id) }
        }
        if demo { return }
        do {
            guard let tk = await token() else { throw Supa.Fallo(mensaje: "Entra con tu cuenta") }
            try await Supa.rpc("votar", ["p_id": p.id], token: tk)
        } catch {
            withAnimation { votos[p.id] = antes }
            avisar(error.localizedDescription, error: true)
        }
    }

    func listasDe(_ p: Pedido) -> [String] { listas.filter { $0.pedido == p.id }.map { $0.lista } }
    var nombresListas: [String] {
        var out = ["Guardados"]
        for l in listas.map { $0.lista } where !out.contains(l) { out.append(l) }
        return out
    }

    /// mete o saca una pieza de una lista
    func guardar(_ p: Pedido, en lista: String = "Guardados") async {
        guard sesion != nil else { avisar("Entra con tu cuenta para guardar", error: true); return }
        let l = String(lista.trimmingCharacters(in: .whitespaces).prefix(40))
        guard !l.isEmpty else { return }
        let antes = listas
        let estaba = listas.contains { $0.pedido == p.id && $0.lista == l }
        withAnimation(.snappy) {
            if estaba { listas.removeAll { $0.pedido == p.id && $0.lista == l } } else { listas.append((p.id, l)) }
        }
        avisar(estaba ? "Quitada de «\(l)»" : "Guardada en «\(l)»")
        if demo { return }
        do {
            guard let tk = await token() else { throw Supa.Fallo(mensaje: "Entra con tu cuenta") }
            try await Supa.rpc("guardar_en", ["p_id": p.id, "p_lista": l], token: tk)
        } catch {
            withAnimation { listas = antes }
            avisar(error.localizedDescription, error: true)
        }
    }

    func renombrarLista(_ l: String, a nueva: String) async {
        let n = nueva.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty, n != l else { return }
        do {
            if !demo {
                guard let tk = await token() else { throw Supa.Fallo(mensaje: "Entra con tu cuenta") }
                try await Supa.rpc("renombrar_lista", ["p_lista": l, "p_nueva": n], token: tk)
                await cargar()
            } else { listas = listas.map { ($0.pedido, $0.lista == l ? n : $0.lista) } }
            avisar("Lista renombrada")
        } catch { avisar(error.localizedDescription, error: true) }
    }

    func borrarLista(_ l: String) async {
        do {
            if !demo {
                guard let tk = await token() else { throw Supa.Fallo(mensaje: "Entra con tu cuenta") }
                try await Supa.rpc("borrar_lista", ["p_lista": l], token: tk)
                await cargar()
            } else { listas.removeAll { $0.lista == l } }
            avisar("Lista borrada")
        } catch { avisar(error.localizedDescription, error: true) }
    }

    // MARK: tu perfil

    func avatar(_ uid: String?) -> URL? {
        guard let uid, let a = perfiles[uid]?.avatar, !a.isEmpty else { return nil }
        return URL(string: a)
    }

    func guardarPerfil(nombre: String, foto: Data? = nil) async -> Bool {
        guard var s = sesion else { return false }
        let n = String(nombre.trimmingCharacters(in: .whitespaces).prefix(40))
        guard !n.isEmpty else { avisar("Pon un nombre", error: true); return false }
        do {
            var avatar = perfiles[s.id]?.avatar ?? ""
            if demo {
                s.nombre = n; sesion = s; perfiles[s.id] = (n, avatar); avisar("Perfil guardado"); return true
            }
            guard let tk = await token() else { throw Supa.Fallo(mensaje: "Entra con tu cuenta") }
            if let foto { avatar = try await Supa.subirAvatar(foto, uid: s.id, token: tk) }
            try await Supa.rpc("guardar_perfil", ["p_nombre": n, "p_avatar": avatar], token: tk)
            s.nombre = n
            sesion = s
            await cargar()
            avisar(foto != nil ? "Foto cambiada" : "Perfil guardado")
            return true
        } catch {
            avisar(error.localizedDescription, error: true)
            return false
        }
    }

    /// pide una pieza de la vitrina tal cual (la base de datos copia modelo, colores y tiempo)
    func pedirIgual(_ p: Pedido, copias: Int) async -> Bool {
        guard let s = sesion else { avisar("Entra con tu cuenta para pedirla", error: true); return false }
        if demo { avisar("¡En la cola!"); return true }
        do {
            let cuerpo: [String: Any] = ["copia_de": p.id, "nombre": s.nombre, "copias": copias, "notas": "Igual que «\(p.nombreFigura)» de \(p.nombre)"]
            let d = try await Supa.rpc("crear_pedido", ["p": cuerpo], token: await token())
            let j = try JSONSerialization.jsonObject(with: d) as? [String: Any]
            if let id = j?["id"] as? String {
                if let tk = j?["token"] as? String { tokens[id] = tk }
                await cargar()
                resaltado = id
                pestana = .cola
            }
            avisar("¡En la cola!")
            return true
        } catch {
            avisar(error.localizedDescription, error: true)
            return false
        }
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

    /// con el código de este iPhone o, si se pidió desde otro sitio, con tu cuenta
    func cancelar(_ p: Pedido) async -> Bool {
        do {
            try await Supa.rpc("cancelar_pedido", ["p_id": p.id, "p_token": tokens[p.id] ?? ""], token: await token())
            await cargar()
            avisar("Pedido cancelado")
            return true
        } catch { avisar(error.localizedDescription, error: true); return false }
    }

    // MARK: pagos pequeños

    /// el mismo que pidió: su cuenta o, sin cuenta, su nombre
    func mismaPersona(_ a: Pedido, _ b: Pedido) -> Bool {
        if let u = a.user_id { return b.user_id == u }
        return b.user_id == nil && a.nombre.trimmingCharacters(in: .whitespaces).lowercased() == b.nombre.trimmingCharacters(in: .whitespaces).lowercased()
    }
    /// lo que debe esa persona entre todos sus pedidos sin pagar
    func deuda(_ p: Pedido) -> (total: Double, pedidos: [Pedido]) {
        let ps = pedidos.filter { mismaPersona(p, $0) && !$0.pagado && $0.estado != .cancelado && !$0.peticion && !$0.delTaller && $0.coste > 0 }
        return ((ps.reduce(0) { $0 + $1.coste } * 100).rounded() / 100, ps)
    }
    /// aún no llega al mínimo: no se pide pagar, se acumula y se imprime igual
    func acumula(_ p: Pedido) -> Bool { !p.pagado && deuda(p).total < ajustes.pago_minimo }

    func cobrarTodo(_ ps: [Pedido]) async {
        for p in ps { await cambiar(p, ["pagado": true]) }
        avisar("Cobrado: \(Fmt.eur(ps.reduce(0) { $0 + $1.coste }))")
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
        let pendientes = pedidos.filter { $0.estado == .pendiente }
        // listo para imprimir: pagado o con deuda tan pequeña que se acumula (se calcula una vez por pedido)
        var listo: [String: Bool] = [:]
        for p in pendientes { listo[p.id] = p.pagado || acumula(p) }
        let pen = pendientes.sorted {
            if $0.peticion != $1.peticion { return !$0.peticion }
            if $0.prioridad != $1.prioridad { return $0.prioridad > $1.prioridad }
            let l0 = listo[$0.id] ?? false, l1 = listo[$1.id] ?? false
            if l0 != l1 { return l0 }
            return $0.creado < $1.creado
        }
        return imp + pen
    }

    func turno(_ p: Pedido) -> Int? {
        guard p.estado == .pendiente else { return nil }
        guard !p.peticion else { return nil }
        return cola.filter { $0.estado == .pendiente && !$0.peticion }.firstIndex { $0.id == p.id }.map { $0 + 1 }
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
        votos = ["d4": ["u1", "u2", "u3"], "d5": ["u2", "u1"]]
        listas = [("d5", "Guardados"), ("d4", "Regalos")]
        tokens["d2"] = "x"
        sesion = Sesion(access: "", refresh: "", caduca: .distantFuture, id: "u1", email: "jorge@ejemplo.es", nombre: "Jorge")
        admin = ProcessInfo.processInfo.arguments.contains("-taller")
        if admin { sesion?.nombre = "David" }
        cargado = true
    }
}
