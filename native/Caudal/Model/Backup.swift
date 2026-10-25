import SwiftUI

/// copia automática de todos los datos de Caudal en el servidor de casa
extension Store {
    static let server = ServerCopy(app: "caudal")

    /// sube una copia (como mucho una cada 10 minutos, salvo que la pidas tú)
    @MainActor
    func backup(force: Bool = false) async -> Bool {
        guard ServerCopy.ready || force else { return false }
        if !force, let l = lastBackup, Date().timeIntervalSince(l) < 600 { return true }
        do {
            try await Store.server.upload(exportData())
            lastBackup = Date()
            ServerCopy.last = lastBackup
            ServerCopy.ready = true
            return true
        } catch {
            return false
        }
    }

    /// al abrir: si es la primera vez y hay copia en el servidor, pregunta si recuperarla
    @MainActor
    func checkBackup() async {
        if ServerCopy.ready { _ = await backup(); return }
        do {
            if let d = try await Store.server.download(), let st = try? JSONDecoder().decode(AppState.self, from: d) {
                pendingRestore = st
            } else {
                ServerCopy.ready = true
                _ = await backup()
            }
        } catch {
            // sin conexión: se vuelve a mirar la próxima vez que se abra
        }
    }

    /// trae la copia del servidor (pidiéndote confirmación antes de sustituir nada)
    @MainActor
    func fetchBackup() async -> String? {
        do {
            guard let d = try await Store.server.download(), let st = try? JSONDecoder().decode(AppState.self, from: d) else {
                return "Todavía no hay ninguna copia en el servidor."
            }
            pendingRestore = st
            return nil
        } catch {
            return "No se ha podido traer la copia. Mira que Tailscale esté conectado."
        }
    }

    @MainActor
    func restore(_ st: AppState) {
        withAnimation { state = st }
        runRecurring()
        saveNow()
        ServerCopy.ready = true
        pendingRestore = nil
        Haptic.success()
    }
}

extension AppState {
    var backupSummary: String {
        var p: [String] = []
        func add(_ n: Int, _ one: String, _ many: String) { if n > 0 { p.append(n == 1 ? "1 \(one)" : "\(n) \(many)") } }
        add(accounts.count, "cuenta", "cuentas"); add(txs.count, "movimiento", "movimientos"); add(assets.count, "inversión", "inversiones")
        add(shifts.count, "turno", "turnos"); add(debts.count, "apunte de Cuentas Claras", "apuntes de Cuentas Claras")
        return p.isEmpty ? "una copia vacía" : p.joined(separator: ", ")
    }
}

/// apartado de Más
struct BackupSection: View {
    @Environment(Store.self) private var store
    @Binding var message: String?
    @State private var busy = false
    var body: some View {
        Section("Copia en el servidor") {
            LabeledContent("Última copia") {
                if let l = store.lastBackup { Text(l, format: .relative(presentation: .named)) } else { Text("Ninguna") }
            }
            Button {
                busy = true
                Task {
                    if await store.backup(force: true) { Haptic.success() } else { message = "No se ha podido hacer la copia. Mira que Tailscale esté conectado." }
                    busy = false
                }
            } label: { HStack { Label("Hacer copia ahora", systemImage: "icloud.and.arrow.up"); if busy { Spacer(); ProgressView() } } }
            .disabled(busy)
            Button { Task { message = await store.fetchBackup() } } label: { Label("Recuperar la copia", systemImage: "icloud.and.arrow.down") }
        }
    }
}
