import SwiftUI

/// copia de seguridad de los datos en el servidor de casa (solo se llega por Tailscale)
enum Backup {
    static let url = URL(string: "http://100.99.241.98:8790/rumbo/copia")!
    /// hasta saber si en el servidor hay una copia que recuperar no se sube nada,
    /// para no pisarla con los datos vacíos de una app recién instalada
    static var ready: Bool {
        get { UserDefaults.standard.bool(forKey: "copia-lista") }
        set { UserDefaults.standard.set(newValue, forKey: "copia-lista") }
    }
    private static func session() -> URLSession {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 20
        return URLSession(configuration: c)
    }
    static func upload(_ data: Data) async throws {
        var r = URLRequest(url: url)
        r.httpMethod = "PUT"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (_, resp) = try await session().upload(for: r, from: data)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw BackupError("El servidor no ha aceptado la copia.") }
    }
    /// nil si aún no hay ninguna copia
    static func download() async throws -> RState? {
        let (d, resp) = try await session().data(from: url)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if code == 204 { return nil }
        guard code == 200 else { throw BackupError("El servidor no responde bien.") }
        return try JSONDecoder().decode(RState.self, from: d)
    }
}

struct BackupError: LocalizedError {
    var text: String
    init(_ t: String) { text = t }
    var errorDescription: String? { text }
}

extension Store {
    /// sube una copia (como mucho una cada 10 minutos, salvo que la pidas tú)
    @MainActor
    func backup(force: Bool = false) async {
        guard Backup.ready || force else { return }
        if !force, let l = lastBackup, Date().timeIntervalSince(l) < 600 { return }
        guard let d = try? JSONEncoder().encode(s) else { return }
        do {
            try await Backup.upload(d)
            lastBackup = Date()
            UserDefaults.standard.set(lastBackup, forKey: "copia-ultima")
            Backup.ready = true
            if force { Haptic.success() }
        } catch {
            if force { self.error = "No se ha podido hacer la copia. Mira que Tailscale esté conectado." }
        }
    }

    /// al abrir: si es la primera vez y hay copia en el servidor, pregunta si recuperarla
    @MainActor
    func checkBackup() async {
        if Backup.ready { await backup(); return }
        do {
            if let st = try await Backup.download() { pendingRestore = st } else { Backup.ready = true; await backup() }
        } catch {
            // sin conexión: se vuelve a mirar la próxima vez que se abra
        }
    }

    @MainActor
    func restore(_ st: RState) {
        s = st
        saveNow()
        Backup.ready = true
        pendingRestore = nil
        scheduleNotifications()
        Haptic.success()
    }

    /// trae la copia del servidor (pidiéndote confirmación antes de sustituir nada)
    @MainActor
    func fetchBackup() async {
        do {
            if let st = try await Backup.download() { pendingRestore = st } else { self.error = "Todavía no hay ninguna copia en el servidor." }
        } catch {
            self.error = "No se ha podido traer la copia. Mira que Tailscale esté conectado."
        }
    }
}

extension RState {
    var backupSummary: String {
        var p: [String] = []
        func add(_ n: Int, _ one: String, _ many: String) { if n > 0 { p.append(n == 1 ? "1 \(one)" : "\(n) \(many)") } }
        add(tasks.count, "tarea", "tareas"); add(reminders.count, "recordatorio", "recordatorios"); add(docs.count, "nota", "notas")
        add(films.count, "película o serie", "películas y series"); add(pieces.count, "contenido de marca", "contenidos de marca")
        return p.isEmpty ? "una copia vacía" : p.joined(separator: ", ")
    }
}

/// apartado de Ajustes
struct BackupSettings: View {
    @Environment(Store.self) private var store
    @State private var busy = false
    var body: some View {
        Section("Copia de seguridad") {
            LabeledContent("Última copia") {
                if let l = store.lastBackup { Text(l, format: .relative(presentation: .named)) } else { Text("Ninguna") }
            }
            Button {
                busy = true
                Task { await store.backup(force: true); busy = false }
            } label: { HStack { Label("Hacer copia ahora", systemImage: "icloud.and.arrow.up"); if busy { Spacer(); ProgressView() } } }
            .disabled(busy)
            Button { Task { await store.fetchBackup() } } label: { Label("Recuperar la copia", systemImage: "icloud.and.arrow.down") }
        }
    }
}
