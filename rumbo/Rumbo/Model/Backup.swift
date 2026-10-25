import SwiftUI

/// copia de seguridad en el servidor de casa: todos los datos, los archivos (fotos, PDFs, carátulas)
/// y las claves del Llavero (Claude y Jellyfin)
enum Backup {
    static let server = ServerCopy(app: "rumbo")
    static var files: URL { Extract.filesDir }

    /// los datos y, metidas dentro, las claves
    static func pack(_ s: RState) -> Data? {
        guard let d = try? JSONEncoder().encode(s), var root = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return nil }
        root["_claves"] = ["claude": Keychain.apiKey, "jellyfin": Keychain.jellyfinToken]
        return try? JSONSerialization.data(withJSONObject: root)
    }
    static func keys(in d: Data) -> [String: String] {
        ((try? JSONSerialization.jsonObject(with: d)) as? [String: Any])?["_claves"] as? [String: String] ?? [:]
    }
}

extension Store {
    /// sube una copia (como mucho una cada 10 minutos, salvo que la pidas tú)
    @MainActor
    func backup(force: Bool = false) async {
        guard ServerCopy.ready || force else { return }
        if !force, let l = lastBackup, Date().timeIntervalSince(l) < 600 { return }
        guard let d = Backup.pack(s) else { return }
        do {
            try await Backup.server.upload(d)
            try await Backup.server.uploadFiles(in: Backup.files)
            lastBackup = Date()
            ServerCopy.last = lastBackup
            ServerCopy.ready = true
            if force { Haptic.success() }
        } catch {
            if force { self.error = "No se ha podido hacer la copia. Mira que Tailscale esté conectado." }
        }
    }

    /// al abrir: si es la primera vez y hay copia en el servidor, pregunta si recuperarla
    @MainActor
    func checkBackup() async {
        if ServerCopy.ready { await backup(); return }
        do {
            if let d = try await Backup.server.download(), let st = try? JSONDecoder().decode(RState.self, from: d) {
                pendingRestore = st; pendingKeys = Backup.keys(in: d)
            } else { ServerCopy.ready = true; await backup() }
        } catch {
            // sin conexión: se vuelve a mirar la próxima vez que se abra
        }
    }

    @MainActor
    func restore(_ st: RState) {
        s = st
        if let k = pendingKeys["claude"], !k.isEmpty { Keychain.apiKey = k }
        if let k = pendingKeys["jellyfin"], !k.isEmpty { Keychain.jellyfinToken = k }
        saveNow()
        ServerCopy.ready = true
        pendingRestore = nil
        pendingKeys = [:]
        scheduleNotifications()
        Haptic.success()
        // fotos, PDFs y carátulas
        Task { @MainActor in
            if (try? await Backup.server.downloadFiles(to: Backup.files)) ?? 0 > 0 { s = s }
        }
    }

    /// trae la copia del servidor (pidiéndote confirmación antes de sustituir nada)
    @MainActor
    func fetchBackup() async {
        do {
            if let d = try await Backup.server.download(), let st = try? JSONDecoder().decode(RState.self, from: d) {
                pendingRestore = st; pendingKeys = Backup.keys(in: d)
            } else { self.error = "Todavía no hay ninguna copia en el servidor." }
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
