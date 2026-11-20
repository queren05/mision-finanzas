import Foundation

/// Conexión con Supabase por HTTP (sin librerías): tablas, funciones, cuentas, fotos y la vista previa de MakerWorld.
enum Supa {
    static let url = "https://crigyravdsifkffpchlg.supabase.co"
    /// clave pública (la misma que usa la web; no da permisos de escritura)
    static let anon = "sb_publishable_6GUqiZP5JAf43jBGrjZ1YA_jmZ6n8R7"
    static let web = "https://queren05.github.io/cola-3d/"

    struct Fallo: LocalizedError {
        var mensaje: String
        var errorDescription: String? { mensaje }
    }

    static func peticion(_ ruta: String, metodo: String = "GET", json: Any? = nil, token: String? = nil) -> URLRequest {
        var r = URLRequest(url: URL(string: url + ruta)!, timeoutInterval: 25)
        r.httpMethod = metodo
        r.setValue(anon, forHTTPHeaderField: "apikey")
        r.setValue("Bearer " + (token ?? anon), forHTTPHeaderField: "Authorization")
        r.setValue("application/json", forHTTPHeaderField: "Accept")
        if let json {
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.httpBody = try? JSONSerialization.data(withJSONObject: json)
        }
        return r
    }

    static func enviar(_ r: URLRequest) async throws -> Data {
        let data: Data, resp: URLResponse
        do { (data, resp) = try await URLSession.shared.data(for: r) }
        catch { throw Fallo(mensaje: "Sin conexión. Prueba otra vez en un momento") }
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let m = (j?["message"] as? String) ?? (j?["msg"] as? String) ?? (j?["error_description"] as? String) ?? (j?["error"] as? String) ?? "Error \(code)"
            throw Fallo(mensaje: traducir(m))
        }
        return data
    }

    /// los errores de Supabase, en castellano
    static func traducir(_ m: String) -> String {
        let l = m.lowercased()
        if l.contains("invalid login credentials") { return "Correo o contraseña incorrectos" }
        if l.contains("already registered") || l.contains("already exists") { return "Ese correo ya tiene cuenta" }
        if l.contains("email not confirmed") { return "Confirma tu correo antes de entrar" }
        if l.contains("password") && (l.contains("at least") || l.contains("characters")) { return "La contraseña necesita al menos 6 caracteres" }
        if l.contains("same") && l.contains("password") || l.contains("different from the old") { return "Pon una contraseña distinta a la anterior" }
        if l.contains("rate limit") || l.contains("too many") || l.contains("security purposes") { return "Demasiados intentos, espera un poco" }
        if l.contains("invalid") && l.contains("email") || l.contains("unable to validate email") { return "El correo no es válido" }
        if l.contains("jwt expired") { return "La sesión ha caducado, vuelve a entrar" }
        if l.contains("row-level security") || l.contains("unauthorized") { return "Solo el taller puede hacer eso" }
        return m.replacingOccurrences(of: #"^.*?: "#, with: "", options: .regularExpression)
    }

    // MARK: lectura

    static func leer<T: Decodable>(_ ruta: String, token: String? = nil) async throws -> T {
        try JSONDecoder().decode(T.self, from: try await enviar(peticion("/rest/v1/" + ruta, token: token)))
    }

    @discardableResult
    static func rpc(_ fn: String, _ args: [String: Any], token: String? = nil) async throws -> Data {
        try await enviar(peticion("/rest/v1/rpc/" + fn, metodo: "POST", json: args, token: token))
    }

    // MARK: cuentas

    private static func sesion(de data: Data) throws -> Sesion {
        guard let j = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let at = j["access_token"] as? String, let rt = j["refresh_token"] as? String,
              let u = j["user"] as? [String: Any], let id = u["id"] as? String else { throw Fallo(mensaje: "Respuesta rara al entrar") }
        let exp = (j["expires_in"] as? Double) ?? 3600
        let email = (u["email"] as? String) ?? ""
        let meta = u["user_metadata"] as? [String: Any]
        let nombre = (meta?["nombre"] as? String) ?? email.components(separatedBy: "@").first ?? ""
        return Sesion(access: at, refresh: rt, caduca: Date().addingTimeInterval(exp - 60), id: id, email: email, nombre: nombre)
    }

    static func entrar(email: String, clave: String) async throws -> Sesion {
        try sesion(de: try await enviar(peticion("/auth/v1/token?grant_type=password", metodo: "POST", json: ["email": email, "password": clave])))
    }

    static func renovar(_ s: Sesion) async throws -> Sesion {
        try sesion(de: try await enviar(peticion("/auth/v1/token?grant_type=refresh_token", metodo: "POST", json: ["refresh_token": s.refresh])))
    }

    /// crea la cuenta; si Supabase pide confirmar el correo devuelve nil
    static func registrar(nombre: String, email: String, clave: String) async throws -> Sesion? {
        let red = web.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? web
        let d = try await enviar(peticion("/auth/v1/signup?redirect_to=" + red, metodo: "POST", json: ["email": email, "password": clave, "data": ["nombre": nombre]]))
        return try? sesion(de: d)
    }

    static func recuperar(email: String) async throws {
        let red = web.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? web
        _ = try await enviar(peticion("/auth/v1/recover?redirect_to=" + red, metodo: "POST", json: ["email": email]))
    }

    static func cambiarClave(_ clave: String, token: String) async throws {
        _ = try await enviar(peticion("/auth/v1/user", metodo: "PUT", json: ["password": clave], token: token))
    }

    static func salir(token: String) async {
        _ = try? await enviar(peticion("/auth/v1/logout", metodo: "POST", json: [:], token: token))
    }

    // MARK: fotos (Storage)

    static func subirFoto(_ jpeg: Data, pedido: String, token: String) async throws -> String {
        let ruta = "\(pedido)/\(Int(Date().timeIntervalSince1970 * 1000)).jpg"
        var r = peticion("/storage/v1/object/fotos/" + ruta, metodo: "POST", token: token)
        r.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        r.httpBody = jpeg
        r.timeoutInterval = 90
        _ = try await enviar(r)
        return url + "/storage/v1/object/public/fotos/" + ruta
    }

    static func borrarFoto(_ u: String, token: String) async {
        guard let ruta = u.components(separatedBy: "/object/public/fotos/").last, ruta != u else { return }
        _ = try? await enviar(peticion("/storage/v1/object/fotos", metodo: "DELETE", json: ["prefixes": [ruta.removingPercentEncoding ?? ruta]], token: token))
    }

    // MARK: vista previa (función «preview»: foto, nombre y perfiles de MakerWorld)

    static func vistaPrevia(_ enlace: String) async throws -> Vista {
        var r = peticion("/functions/v1/preview", metodo: "POST", json: ["url": enlace])
        r.timeoutInterval = 40
        return try JSONDecoder().decode(Vista.self, from: try await enviar(r))
    }
}
