import Foundation
import SwiftUI

/// Cada dato diario que la app sabe leer.
enum Metric: String, CaseIterable, Codable, Identifiable, Sendable {
    case steps, activeEnergy, basalEnergy, exerciseMinutes, standHours
    case heartRate, restingHR, hrv, respiratoryRate, vo2max, walkingHR, weight
    case calories, protein, carbs, fat, water
    case sleep

    var id: String { rawValue }

    /// Cómo se resume un día.
    enum Aggregation { case sum, average, latest }

    var aggregation: Aggregation {
        switch self {
        case .steps, .activeEnergy, .basalEnergy, .exerciseMinutes, .standHours,
             .calories, .protein, .carbs, .fat, .water, .sleep: .sum
        case .heartRate, .restingHR, .hrv, .respiratoryRate, .walkingHR: .average
        case .vo2max, .weight: .latest
        }
    }

    /// Qué dirección es buena: subir, bajar o quedarse cerca de lo normal.
    enum Direction { case higher, lower, stable, none }

    var direction: Direction {
        switch self {
        case .steps, .activeEnergy, .exerciseMinutes, .standHours, .hrv, .vo2max, .sleep: .higher
        case .restingHR, .walkingHR: .lower
        case .respiratoryRate: .stable
        case .heartRate, .weight, .basalEnergy, .calories, .protein, .carbs, .fat, .water: .none
        }
    }

    /// Se va acumulando a lo largo del día (hoy aún no está completo).
    var accumulates: Bool { aggregation == .sum && self != .sleep }

    var title: String {
        switch self {
        case .steps: "Pasos"
        case .activeEnergy: "Energía activa"
        case .basalEnergy: "Energía en reposo"
        case .exerciseMinutes: "Ejercicio"
        case .standHours: "Horas de pie"
        case .heartRate: "Pulso medio"
        case .restingHR: "Pulso en reposo"
        case .hrv: "Variabilidad cardíaca"
        case .respiratoryRate: "Respiración"
        case .vo2max: "VO₂ máx"
        case .walkingHR: "Pulso al caminar"
        case .weight: "Peso"
        case .calories: "Calorías"
        case .protein: "Proteínas"
        case .carbs: "Carbohidratos"
        case .fat: "Grasas"
        case .water: "Agua"
        case .sleep: "Sueño"
        }
    }

    var symbol: String {
        switch self {
        case .steps: "figure.walk"
        case .activeEnergy: "flame.fill"
        case .basalEnergy: "bed.double.fill"
        case .exerciseMinutes: "figure.run"
        case .standHours: "figure.stand"
        case .heartRate: "heart.fill"
        case .restingHR: "heart.fill"
        case .hrv: "waveform.path.ecg"
        case .respiratoryRate: "lungs.fill"
        case .vo2max: "bolt.heart.fill"
        case .walkingHR: "figure.walk.motion"
        case .weight: "scalemass.fill"
        case .calories: "fork.knife"
        case .protein: "fish.fill"
        case .carbs: "carrot.fill"
        case .fat: "drop.fill"
        case .water: "waterbottle.fill"
        case .sleep: "moon.zzz.fill"
        }
    }

    var color: Color {
        switch self {
        case .steps, .activeEnergy, .basalEnergy, .exerciseMinutes, .standHours: Palette.effort
        case .heartRate, .restingHR, .walkingHR: Palette.heart
        case .hrv: Palette.recovery
        case .respiratoryRate: Palette.breath
        case .vo2max: Palette.recovery
        case .weight: Palette.body
        case .calories, .protein, .carbs, .fat: Palette.nutrition
        case .water: Palette.breath
        case .sleep: Palette.sleep
        }
    }

    /// Unidad corta que se pinta junto al número.
    var unit: String {
        switch self {
        case .steps: "pasos"
        case .activeEnergy, .basalEnergy, .calories: Fmt.energyUnit
        case .exerciseMinutes: "min"
        case .standHours: "h"
        case .heartRate, .restingHR, .walkingHR: "lpm"
        case .hrv: "ms"
        case .respiratoryRate: "resp/min"
        case .vo2max: "ml/kg·min"
        case .weight: "kg"
        case .protein, .carbs, .fat: "g"
        case .water: "l"
        case .sleep: ""
        }
    }
}

/// Fase del sueño, tal como la guarda el Apple Watch.
enum SleepStage: Int, Codable, CaseIterable, Sendable {
    case awake, rem, core, deep, unspecified

    var title: String {
        switch self {
        case .awake: "Despierto"
        case .rem: "REM"
        case .core: "Ligero"
        case .deep: "Profundo"
        case .unspecified: "Dormido"
        }
    }

    var color: Color {
        switch self {
        case .awake: Color(red: 1.0, green: 0.55, blue: 0.45)
        case .rem: Color(red: 0.45, green: 0.78, blue: 1.0)
        case .core: Color(red: 0.42, green: 0.48, blue: 1.0)
        case .deep: Color(red: 0.36, green: 0.22, blue: 0.85)
        case .unspecified: Palette.sleep
        }
    }

    /// Orden de arriba abajo en la gráfica de fases.
    var level: Int {
        switch self {
        case .awake: 0
        case .rem: 1
        case .core, .unspecified: 2
        case .deep: 3
        }
    }
}

struct SleepSegment: Codable, Hashable, Sendable {
    var stage: SleepStage
    var start: Date
    var end: Date
    var duration: TimeInterval { end.timeIntervalSince(start) }
}

/// Una noche de sueño. `day` es el día en que te despiertas.
struct SleepNight: Codable, Hashable, Identifiable, Sendable {
    var day: Date
    var segments: [SleepSegment]
    var id: Date { day }

    var start: Date { segments.map(\.start).min() ?? day }
    var end: Date { segments.map(\.end).max() ?? day }
    var inBed: TimeInterval { end.timeIntervalSince(start) }

    func time(_ stage: SleepStage) -> TimeInterval {
        segments.filter { $0.stage == stage }.reduce(0) { $0 + $1.duration }
    }

    var asleep: TimeInterval { segments.filter { $0.stage != .awake }.reduce(0) { $0 + $1.duration } }
    var awake: TimeInterval { time(.awake) }
    var hasStages: Bool { segments.contains { $0.stage == .deep || $0.stage == .rem || $0.stage == .core } }
    /// Porcentaje del tiempo en la cama que pasaste dormido.
    var efficiency: Double { inBed > 0 ? min(1, asleep / inBed) : 0 }
}

/// Un entreno guardado en Salud.
struct Workout: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var kind: UInt
    var start: Date
    var end: Date
    var energy: Double?       // kcal
    var distance: Double?     // metros
    var avgHR: Double?

    var duration: TimeInterval { end.timeIntervalSince(start) }
    var day: Date { Calendar.current.startOfDay(for: start) }
}

/// Un punto del día (por ejemplo, el pulso de cada hora).
struct TimePoint: Codable, Hashable, Sendable {
    var date: Date
    var value: Double
}

extension Calendar {
    func days(back n: Int, from today: Date = .now) -> [Date] {
        let t = startOfDay(for: today)
        return (0..<n).reversed().compactMap { date(byAdding: .day, value: -$0, to: t) }
    }
}

extension Workout {
    private static let names: [UInt: (String, String)] = [
        37: ("Correr", "figure.run"), 52: ("Caminar", "figure.walk"), 13: ("Bici", "figure.outdoor.cycle"),
        50: ("Fuerza", "dumbbell.fill"), 20: ("Fuerza funcional", "figure.strengthtraining.functional"),
        63: ("HIIT", "figure.highintensity.intervaltraining"), 46: ("Natación", "figure.pool.swim"),
        24: ("Senderismo", "figure.hiking"), 57: ("Yoga", "figure.yoga"), 16: ("Elíptica", "figure.elliptical"),
        35: ("Remo", "figure.rower"), 41: ("Fútbol", "figure.soccer"), 6: ("Baloncesto", "figure.basketball"),
        48: ("Tenis", "figure.tennis"), 79: ("Pickleball", "figure.pickleball"), 44: ("Escaleras", "figure.stair.stepper"),
        68: ("Escaleras", "figure.stairs"), 59: ("Core", "figure.core.training"), 66: ("Pilates", "figure.pilates"),
        14: ("Baile", "figure.dance"), 77: ("Baile", "figure.dance"), 8: ("Boxeo", "figure.boxing"),
        65: ("Kickboxing", "figure.kickboxing"), 28: ("Artes marciales", "figure.martial.arts"),
        9: ("Escalada", "figure.climbing"), 64: ("Comba", "figure.jumprope"), 73: ("Cardio", "figure.mixed.cardio"),
        11: ("Entreno cruzado", "figure.cross.training"), 62: ("Estiramientos", "figure.flexibility"),
        80: ("Vuelta a la calma", "figure.cooldown"), 29: ("Mente y cuerpo", "figure.mind.and.body"),
        43: ("Squash", "figure.squash"), 34: ("Pádel", "figure.racquetball"), 70: ("Silla de ruedas", "figure.roll"),
    ]
    var name: String { Self.names[kind]?.0 ?? "Entreno" }
    var symbol: String { Self.names[kind]?.1 ?? "figure.mixed.cardio" }
}
