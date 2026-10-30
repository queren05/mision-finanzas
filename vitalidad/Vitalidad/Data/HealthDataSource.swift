import Foundation

/// Cualquier sitio del que la app saque datos de salud (hoy Apple Salud; mañana, por ejemplo, Google Health para una Fitbit).
protocol HealthDataSource: Sendable {
    /// Nombre que se enseña en Ajustes.
    var name: String { get }
    /// Si esta fuente puede usarse en este aparato.
    var isAvailable: Bool { get }
    /// Pide permiso de lectura. Termina sin error aunque el usuario niegue algunos datos.
    func requestAuthorization() async throws
}
