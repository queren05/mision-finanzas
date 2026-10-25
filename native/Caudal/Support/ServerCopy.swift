import Foundation

/// copia de seguridad en el servidor de casa (solo se llega por Tailscale):
/// los datos en JSON y, aparte, los archivos sueltos (fotos, PDFs)
struct ServerCopy {
    let app: String
    private var base: String { "http://100.99.241.98:8790/\(app)/" }

    /// hasta saber si en el servidor hay una copia que recuperar no se sube nada,
    /// para no pisarla con los datos de una app recién instalada
    static var ready: Bool {
        get { UserDefaults.standard.bool(forKey: "copia-lista") }
        set { UserDefaults.standard.set(newValue, forKey: "copia-lista") }
    }
    static var last: Date? {
        get { UserDefaults.standard.object(forKey: "copia-ultima") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "copia-ultima") }
    }

    private func session(_ timeout: TimeInterval) -> URLSession {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = timeout
        return URLSession(configuration: c)
    }
    private func put(_ path: String, _ data: Data, type: String) async throws {
        guard let u = URL(string: base + path) else { return }
        var r = URLRequest(url: u)
        r.httpMethod = "PUT"
        r.setValue(type, forHTTPHeaderField: "Content-Type")
        let (_, resp) = try await session(120).upload(for: r, from: data)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw ServerCopyError("El servidor no ha aceptado la copia.") }
    }
    /// nil si no hay nada
    private func get(_ path: String, timeout: TimeInterval = 30) async throws -> Data? {
        guard let u = URL(string: base + path) else { return nil }
        let (d, resp) = try await session(timeout).data(from: u)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if code == 204 { return nil }
        guard code == 200 else { throw ServerCopyError("El servidor no responde bien.") }
        return d
    }

    func upload(_ data: Data) async throws { try await put("copia", data, type: "application/json") }
    func download(timeout: TimeInterval = 30) async throws -> Data? { try await get("copia", timeout: timeout) }

    /// sube los archivos de la carpeta que todavía no estén en el servidor
    func uploadFiles(in dir: URL) async throws {
        let local = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        guard !local.isEmpty else { return }
        let remote = Set(try await fileList())
        for name in local where !remote.contains(name) && !name.hasPrefix(".") {
            guard let d = try? Data(contentsOf: dir.appendingPathComponent(name)), !d.isEmpty else { continue }
            try await put("archivo/" + name, d, type: "application/octet-stream")
        }
    }
    /// baja los archivos que falten en la carpeta; devuelve cuántos ha bajado
    @discardableResult
    func downloadFiles(to dir: URL) async throws -> Int {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var n = 0
        for name in try await fileList() where !FileManager.default.fileExists(atPath: dir.appendingPathComponent(name).path) {
            if let d = try await get("archivo/" + name, timeout: 120) {
                try? d.write(to: dir.appendingPathComponent(name), options: .atomic)
                n += 1
            }
        }
        return n
    }
    private func fileList() async throws -> [String] {
        guard let d = try await get("archivos") else { return [] }
        return (try? JSONDecoder().decode([String].self, from: d)) ?? []
    }
}

struct ServerCopyError: LocalizedError {
    var text: String
    init(_ t: String) { text = t }
    var errorDescription: String? { text }
}
