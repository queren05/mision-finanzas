import Foundation

/// Cualquier sitio del que la app saque datos de salud (hoy Apple Salud; mañana, por ejemplo, Google Health para una Fitbit).
/// Todo es de solo lectura y nunca lanza por falta de datos: si algo no existe, devuelve vacío.
protocol HealthDataSource: Sendable {
    /// Nombre que se enseña en Ajustes.
    var name: String { get }
    /// Si esta fuente puede usarse en este aparato.
    var isAvailable: Bool { get }
    /// Pide permiso de lectura. Termina sin error aunque el usuario niegue algunos datos.
    func requestAuthorization() async throws
    /// Un valor por día (suma, media o el último, según la métrica) entre dos fechas.
    func daily(_ metric: Metric, from: Date, to: Date) async -> [Date: Double]
    /// Las noches de sueño cuyo despertar cae entre dos fechas.
    func nights(from: Date, to: Date) async -> [SleepNight]
    /// Entrenos entre dos fechas, del más reciente al más antiguo.
    func workouts(from: Date, to: Date) async -> [Workout]
    /// Valores por horas de un día (pulso medio de cada hora, pasos de cada hora…).
    func hourly(_ metric: Metric, day: Date) async -> [TimePoint]
    /// Guarda una comida en Salud (energía y macros). Devuelve lo guardado para poder borrarlo.
    func saveFood(name: String, date: Date, kcal: Double, protein: Double, carbs: Double, fat: Double) async -> [UUID]
    func saveWater(_ liters: Double, date: Date) async -> [UUID]
    /// Borra de Salud lo que guardó la app.
    func deleteSamples(_ ids: [UUID]) async
    /// Fecha de nacimiento y sexo, si están en la fuente.
    func profile() async -> Profile
    /// Avisa cuando cambian los datos, también con la app cerrada si la fuente lo permite.
    func observeChanges(_ onChange: @escaping @Sendable () async -> Void)
}

/// Lo que la fuente sabe de ti (para la edad del cuerpo y el pulso máximo).
struct Profile: Sendable, Equatable {
    var birth: Date?
    var female: Bool?
}
