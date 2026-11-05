import Foundation
import SwiftUI

// MARK: - Músculos y ejercicios

enum Muscle: String, CaseIterable, Codable, Identifiable {
    case pecho, espalda, hombros, trapecio, biceps, triceps, antebrazos, abdomen, lumbar, gluteos, cuadriceps, isquios, gemelos
    var id: String { rawValue }
    var title: String {
        switch self {
        case .pecho: "Pecho"
        case .espalda: "Espalda"
        case .hombros: "Hombros"
        case .trapecio: "Trapecio"
        case .biceps: "Bíceps"
        case .triceps: "Tríceps"
        case .antebrazos: "Antebrazos"
        case .abdomen: "Abdomen"
        case .lumbar: "Lumbar"
        case .gluteos: "Glúteos"
        case .cuadriceps: "Cuádriceps"
        case .isquios: "Isquios"
        case .gemelos: "Gemelos"
        }
    }
}

enum Equipment: String, Codable, CaseIterable {
    case barra, mancuernas, maquina, polea, cuerpo, kettlebell, banda
    var title: String {
        switch self {
        case .barra: "Barra"
        case .mancuernas: "Mancuernas"
        case .maquina: "Máquina"
        case .polea: "Polea"
        case .cuerpo: "Peso corporal"
        case .kettlebell: "Kettlebell"
        case .banda: "Banda"
        }
    }
}

struct Exercise: Identifiable, Hashable {
    var id: String
    var name: String
    var primary: [Muscle]
    var secondary: [Muscle]
    var equipment: Equipment

    static func by(_ id: String) -> Exercise? { lookup[id] }
    private static let lookup = Dictionary(uniqueKeysWithValues: library.map { ($0.id, $0) })

    static let library: [Exercise] = {
        func e(_ id: String, _ n: String, _ p: [Muscle], _ s: [Muscle] = [], _ eq: Equipment) -> Exercise {
            Exercise(id: id, name: n, primary: p, secondary: s, equipment: eq)
        }
        return [
            // Pecho
            e("press-banca", "Press de banca", [.pecho], [.triceps, .hombros], .barra),
            e("press-inclinado", "Press inclinado con barra", [.pecho], [.hombros, .triceps], .barra),
            e("press-banca-manc", "Press de banca con mancuernas", [.pecho], [.triceps, .hombros], .mancuernas),
            e("press-inclinado-manc", "Press inclinado con mancuernas", [.pecho], [.hombros, .triceps], .mancuernas),
            e("aperturas", "Aperturas con mancuernas", [.pecho], [.hombros], .mancuernas),
            e("cruce-poleas", "Cruce de poleas", [.pecho], [.hombros], .polea),
            e("contractor", "Contractor de pecho", [.pecho], [], .maquina),
            e("press-pecho-maq", "Press de pecho en máquina", [.pecho], [.triceps], .maquina),
            e("flexiones", "Flexiones", [.pecho], [.triceps, .hombros, .abdomen], .cuerpo),
            e("fondos", "Fondos en paralelas", [.pecho, .triceps], [.hombros], .cuerpo),
            // Espalda
            e("dominadas", "Dominadas", [.espalda], [.biceps, .antebrazos], .cuerpo),
            e("chin-up", "Dominadas supinas", [.espalda, .biceps], [.antebrazos], .cuerpo),
            e("jalon", "Jalón al pecho", [.espalda], [.biceps], .polea),
            e("jalon-estrecho", "Jalón con agarre estrecho", [.espalda], [.biceps], .polea),
            e("remo-barra", "Remo con barra", [.espalda], [.biceps, .lumbar, .trapecio], .barra),
            e("remo-manc", "Remo con mancuerna", [.espalda], [.biceps], .mancuernas),
            e("remo-polea", "Remo en polea baja", [.espalda], [.biceps, .trapecio], .polea),
            e("remo-maq", "Remo en máquina", [.espalda], [.biceps], .maquina),
            e("remo-t", "Remo en T", [.espalda], [.biceps, .lumbar], .barra),
            e("pullover", "Pullover en polea", [.espalda], [.pecho], .polea),
            e("peso-muerto", "Peso muerto", [.lumbar, .gluteos, .isquios], [.espalda, .trapecio, .antebrazos, .cuadriceps], .barra),
            e("rack-pull", "Peso muerto desde rack", [.lumbar, .espalda], [.trapecio, .gluteos], .barra),
            e("hiperextensiones", "Hiperextensiones", [.lumbar], [.gluteos, .isquios], .cuerpo),
            e("encogimientos", "Encogimientos de hombros", [.trapecio], [.antebrazos], .mancuernas),
            e("face-pull", "Face pull", [.hombros, .trapecio], [.espalda], .polea),
            // Hombros
            e("press-militar", "Press militar", [.hombros], [.triceps, .trapecio], .barra),
            e("press-hombro-manc", "Press de hombro con mancuernas", [.hombros], [.triceps], .mancuernas),
            e("press-arnold", "Press Arnold", [.hombros], [.triceps], .mancuernas),
            e("elevaciones-lat", "Elevaciones laterales", [.hombros], [.trapecio], .mancuernas),
            e("elevaciones-lat-polea", "Elevaciones laterales en polea", [.hombros], [], .polea),
            e("elevaciones-front", "Elevaciones frontales", [.hombros], [.pecho], .mancuernas),
            e("pajaros", "Pájaros (deltoides posterior)", [.hombros], [.espalda, .trapecio], .mancuernas),
            e("remo-menton", "Remo al mentón", [.hombros, .trapecio], [.biceps], .barra),
            e("press-hombro-maq", "Press de hombro en máquina", [.hombros], [.triceps], .maquina),
            // Brazos
            e("curl-barra", "Curl con barra", [.biceps], [.antebrazos], .barra),
            e("curl-manc", "Curl con mancuernas", [.biceps], [.antebrazos], .mancuernas),
            e("curl-martillo", "Curl martillo", [.biceps, .antebrazos], [], .mancuernas),
            e("curl-predicador", "Curl en banco Scott", [.biceps], [], .barra),
            e("curl-polea", "Curl en polea", [.biceps], [.antebrazos], .polea),
            e("curl-concentrado", "Curl concentrado", [.biceps], [], .mancuernas),
            e("press-frances", "Press francés", [.triceps], [], .barra),
            e("extension-polea", "Extensión de tríceps en polea", [.triceps], [], .polea),
            e("extension-cuerda", "Extensión con cuerda", [.triceps], [], .polea),
            e("extension-nuca", "Extensión tras nuca", [.triceps], [], .mancuernas),
            e("patada-triceps", "Patada de tríceps", [.triceps], [], .mancuernas),
            e("press-cerrado", "Press de banca agarre cerrado", [.triceps], [.pecho, .hombros], .barra),
            e("fondos-banco", "Fondos en banco", [.triceps], [.hombros], .cuerpo),
            e("curl-muneca", "Curl de muñeca", [.antebrazos], [], .barra),
            e("paseo-granjero", "Paseo del granjero", [.antebrazos, .trapecio], [.abdomen, .gluteos], .mancuernas),
            // Pierna
            e("sentadilla", "Sentadilla", [.cuadriceps, .gluteos], [.isquios, .lumbar, .abdomen], .barra),
            e("sentadilla-frontal", "Sentadilla frontal", [.cuadriceps], [.gluteos, .abdomen], .barra),
            e("sentadilla-goblet", "Sentadilla goblet", [.cuadriceps, .gluteos], [.abdomen], .kettlebell),
            e("prensa", "Prensa de piernas", [.cuadriceps, .gluteos], [.isquios], .maquina),
            e("hack", "Sentadilla hack", [.cuadriceps], [.gluteos], .maquina),
            e("bulgara", "Sentadilla búlgara", [.cuadriceps, .gluteos], [.isquios], .mancuernas),
            e("zancadas", "Zancadas", [.cuadriceps, .gluteos], [.isquios], .mancuernas),
            e("extension-cuad", "Extensión de cuádriceps", [.cuadriceps], [], .maquina),
            e("curl-femoral", "Curl femoral tumbado", [.isquios], [.gemelos], .maquina),
            e("curl-femoral-sentado", "Curl femoral sentado", [.isquios], [], .maquina),
            e("peso-muerto-rumano", "Peso muerto rumano", [.isquios, .gluteos], [.lumbar], .barra),
            e("buenos-dias", "Buenos días", [.isquios, .lumbar], [.gluteos], .barra),
            e("hip-thrust", "Hip thrust", [.gluteos], [.isquios], .barra),
            e("puente-gluteo", "Puente de glúteo", [.gluteos], [.isquios], .cuerpo),
            e("patada-gluteo", "Patada de glúteo en polea", [.gluteos], [], .polea),
            e("abductores", "Abductores en máquina", [.gluteos], [], .maquina),
            e("gemelos-pie", "Gemelos de pie", [.gemelos], [], .maquina),
            e("gemelos-sentado", "Gemelos sentado", [.gemelos], [], .maquina),
            e("step-up", "Subidas al cajón", [.cuadriceps, .gluteos], [.gemelos], .mancuernas),
            e("swing", "Swing con kettlebell", [.gluteos, .isquios], [.lumbar, .hombros], .kettlebell),
            // Abdomen
            e("plancha", "Plancha", [.abdomen], [.hombros], .cuerpo),
            e("crunch", "Crunch", [.abdomen], [], .cuerpo),
            e("crunch-polea", "Crunch en polea", [.abdomen], [], .polea),
            e("elevacion-piernas", "Elevación de piernas colgado", [.abdomen], [.antebrazos], .cuerpo),
            e("rueda", "Rueda abdominal", [.abdomen], [.hombros, .espalda], .cuerpo),
            e("russian-twist", "Giros rusos", [.abdomen], [], .cuerpo),
            e("pallof", "Press Pallof", [.abdomen], [], .polea),
            e("dead-bug", "Dead bug", [.abdomen], [], .cuerpo),
            e("plancha-lateral", "Plancha lateral", [.abdomen], [.hombros], .cuerpo),
            // Cuerpo entero
            e("burpees", "Burpees", [.cuadriceps, .pecho], [.hombros, .abdomen], .cuerpo),
            e("thruster", "Thruster", [.cuadriceps, .hombros], [.gluteos, .triceps], .barra),
            e("cargada", "Cargada de potencia", [.gluteos, .isquios, .trapecio], [.espalda, .cuadriceps, .hombros], .barra),
            e("arrancada-kb", "Arrancada con kettlebell", [.hombros, .gluteos], [.isquios, .espalda], .kettlebell),
            e("remo-invertido", "Remo invertido", [.espalda], [.biceps], .cuerpo),
            e("band-pull", "Aperturas con banda", [.hombros, .espalda], [.trapecio], .banda),
        ]
    }()
}

// MARK: - Entrenos

struct SetLog: Codable, Hashable, Identifiable {
    var id = UUID()
    var kg: Double
    var reps: Int
    var done = false

    /// 1RM estimado (Epley).
    var oneRM: Double { reps <= 1 ? kg : kg * (1 + Double(reps) / 30) }
    var volume: Double { kg * Double(reps) }
}

struct ExerciseLog: Codable, Hashable, Identifiable {
    var id = UUID()
    var exercise: String
    var sets: [SetLog]
}

struct StrengthSession: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var start: Date
    var end: Date?
    var items: [ExerciseLog]

    var doneSets: [(String, SetLog)] { items.flatMap { i in i.sets.filter(\.done).map { (i.exercise, $0) } } }
    var volume: Double { doneSets.reduce(0) { $0 + $1.1.volume } }
    var duration: TimeInterval { (end ?? .now).timeIntervalSince(start) }
}

struct Routine: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    /// ejercicio → series
    var items: [ExerciseLog]
}

// MARK: - Almacén

@Observable @MainActor
final class StrengthStore {
    static let shared = StrengthStore()

    private(set) var sessions: [StrengthSession] = []
    var routines: [Routine] = [] { didSet { save() } }
    /// El entreno en marcha (se guarda por si se cierra la app).
    var live: StrengthSession? { didSet { save() } }
    var restSeconds = 90 { didSet { save() } }

    private let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("fuerza.json")
    private var loading = true

    private struct Saved: Codable {
        var sessions: [StrengthSession]
        var routines: [Routine]
        var live: StrengthSession?
        var rest: Int
    }

    init() {
        if Launch.demo {
            fillDemo()
        } else if let d = try? Data(contentsOf: url), let s = try? JSONDecoder().decode(Saved.self, from: d) {
            sessions = s.sessions; routines = s.routines; live = s.live; restSeconds = s.rest
        } else {
            routines = Self.starterRoutines
        }
        loading = false
        if routines.isEmpty { routines = Self.starterRoutines }
    }

    private func save() {
        guard !loading, !Launch.demo else { return }
        let s = Saved(sessions: sessions, routines: routines, live: live, rest: restSeconds)
        if let d = try? JSONEncoder().encode(s) { try? d.write(to: url, options: .atomic) }
    }

    func start(_ r: Routine?) {
        let items = (r?.items ?? []).map { i in
            ExerciseLog(exercise: i.exercise, sets: i.sets.map { s in
                let last = lastSets(i.exercise)
                return SetLog(kg: last.first?.kg ?? s.kg, reps: last.first?.reps ?? s.reps)
            })
        }
        live = StrengthSession(name: r?.name ?? "Entreno", start: .now, items: items)
    }

    func finish() {
        guard var s = live else { return }
        s.end = .now
        s.items = s.items.compactMap { i in
            let sets = i.sets.filter(\.done)
            return sets.isEmpty ? nil : ExerciseLog(id: i.id, exercise: i.exercise, sets: sets)
        }
        if !s.items.isEmpty { sessions.insert(s, at: 0) }
        live = nil
        save()
    }

    func discard() { live = nil }

    func delete(_ s: StrengthSession) {
        sessions.removeAll { $0.id == s.id }
        save()
    }

    func saveAsRoutine(_ s: StrengthSession, name: String) {
        routines.append(Routine(name: name, items: s.items.map { ExerciseLog(exercise: $0.exercise, sets: $0.sets.map { SetLog(kg: $0.kg, reps: $0.reps) }) }))
    }

    /// Las series de la última vez que hiciste ese ejercicio.
    func lastSets(_ ex: String) -> [SetLog] {
        sessions.lazy.compactMap { $0.items.first { $0.exercise == ex }?.sets }.first ?? []
    }

    // MARK: Récords

    struct Record {
        var heaviest: Double
        var bestOneRM: Double
        var bestSetVolume: Double
        var mostReps: Int
    }

    func record(_ ex: String, before: Date? = nil) -> Record? {
        let sets = sessions.filter { before == nil || $0.start < before! }.flatMap { $0.items.filter { $0.exercise == ex }.flatMap(\.sets) }
        guard !sets.isEmpty else { return nil }
        return Record(heaviest: sets.map(\.kg).max() ?? 0, bestOneRM: sets.map(\.oneRM).max() ?? 0,
                      bestSetVolume: sets.map(\.volume).max() ?? 0, mostReps: sets.map(\.reps).max() ?? 0)
    }

    /// Récords batidos en un entreno.
    func newRecords(in s: StrengthSession) -> [(Exercise, String)] {
        s.items.compactMap { i -> (Exercise, String)? in
            guard let ex = Exercise.by(i.exercise), let best = i.sets.filter(\.done).max(by: { $0.oneRM < $1.oneRM }) else { return nil }
            guard let old = record(i.exercise, before: s.start) else { return nil }
            if best.kg > old.heaviest { return (ex, "Más peso: \(Fmt.number(best.kg, decimals: 1)) kg") }
            if best.oneRM > old.bestOneRM + 0.5 { return (ex, "Mejor 1RM: \(Fmt.number(best.oneRM, decimals: 1)) kg") }
            return nil
        }
    }

    /// 1RM estimado de cada entreno, para la gráfica de progreso.
    func progress(_ ex: String) -> [TimePoint] {
        sessions.compactMap { s in
            s.items.filter { $0.exercise == ex }.flatMap(\.sets).map(\.oneRM).max().map { TimePoint(date: s.start, value: $0) }
        }
        .sorted { $0.date < $1.date }
    }

    /// Ejercicios hechos alguna vez, del más reciente al más antiguo.
    var usedExercises: [Exercise] {
        var seen = Set<String>()
        return sessions.flatMap { $0.items.map(\.exercise) }.filter { seen.insert($0).inserted }.compactMap(Exercise.by)
    }

    // MARK: Músculos

    /// Series de la última semana por músculo (la principal cuenta 1, la secundaria 0,5).
    func weeklySets() -> [Muscle: Double] {
        let from = Date.now.addingTimeInterval(-7 * 86400)
        var out: [Muscle: Double] = [:]
        for s in sessions where s.start >= from {
            for i in s.items {
                guard let ex = Exercise.by(i.exercise) else { continue }
                let n = Double(i.sets.count)
                for m in ex.primary { out[m, default: 0] += n }
                for m in ex.secondary { out[m, default: 0] += n * 0.5 }
            }
        }
        return out
    }

    /// Lo fresco que está cada músculo (100 = recuperado). Cada serie cansa y el cansancio se va a la mitad cada 30 h.
    /// Con un trabajo físico, la jornada también cansa espalda, lumbar, piernas y antebrazos.
    func freshness(work: [(Date, Double)] = []) -> [Muscle: Double] {
        var fatigue: [Muscle: Double] = [:]
        func add(_ m: Muscle, _ amount: Double, at d: Date) {
            let hours = max(0, Date.now.timeIntervalSince(d) / 3600)
            fatigue[m, default: 0] += amount * pow(0.5, hours / 30)
        }
        let from = Date.now.addingTimeInterval(-6 * 86400)
        for s in (sessions + (live.map { [$0] } ?? [])) where s.start >= from {
            for i in s.items {
                guard let ex = Exercise.by(i.exercise) else { continue }
                let n = Double(i.sets.filter(\.done).count)
                for m in ex.primary { add(m, 11 * n, at: s.end ?? s.start) }
                for m in ex.secondary { add(m, 5 * n, at: s.end ?? s.start) }
            }
        }
        for (d, load) in work {
            let k = min(45, load * 0.9)
            for m in [Muscle.lumbar, .espalda, .antebrazos, .cuadriceps, .gluteos] { add(m, k, at: d) }
            for m in [Muscle.hombros, .trapecio, .biceps, .gemelos] { add(m, k * 0.5, at: d) }
        }
        return Dictionary(uniqueKeysWithValues: Muscle.allCases.map { ($0, max(0, 100 - (fatigue[$0] ?? 0))) })
    }

    // MARK: Rutinas de inicio

    static let starterRoutines: [Routine] = {
        func r(_ name: String, _ list: [(String, Int, Int)]) -> Routine {
            Routine(name: name, items: list.map { ExerciseLog(exercise: $0.0, sets: Array(repeating: SetLog(kg: 0, reps: $0.2), count: $0.1)) })
        }
        return [
            r("Empuje", [("press-banca", 4, 8), ("press-inclinado-manc", 3, 10), ("press-militar", 3, 8), ("elevaciones-lat", 3, 12), ("extension-cuerda", 3, 12)]),
            r("Tirón", [("dominadas", 4, 8), ("remo-barra", 3, 8), ("jalon-estrecho", 3, 10), ("face-pull", 3, 15), ("curl-manc", 3, 10)]),
            r("Pierna", [("sentadilla", 4, 6), ("peso-muerto-rumano", 3, 8), ("prensa", 3, 10), ("curl-femoral", 3, 12), ("gemelos-pie", 4, 12)]),
            r("Cuerpo entero", [("sentadilla-goblet", 3, 10), ("press-banca-manc", 3, 10), ("remo-manc", 3, 10), ("press-hombro-manc", 3, 10), ("plancha", 3, 1)]),
        ]
    }()

    private func fillDemo() {
        routines = Self.starterRoutines
        let base: [(String, Double, Int)] = [("press-banca", 70, 8), ("sentadilla", 90, 6), ("remo-barra", 60, 8), ("press-militar", 42.5, 8), ("peso-muerto", 120, 5), ("curl-manc", 14, 10)]
        var r = Rand(seed: 77)
        for n in stride(from: 40, through: 1, by: -2) {
            let d = Calendar.current.date(byAdding: .day, value: -n, to: .now)!.addingTimeInterval(-5 * 3600)
            let pick = n % 4 == 0 ? [0, 2, 3, 5] : [1, 4, 2]
            let items = pick.map { i -> ExerciseLog in
                let (ex, kg, reps) = base[i]
                let w = kg * (1 + Double(40 - n) * 0.004) + (r.next() < 0.5 ? 0 : 2.5)
                return ExerciseLog(exercise: ex, sets: (0..<4).map { _ in SetLog(kg: (w / 2.5).rounded() * 2.5, reps: reps, done: true) })
            }
            sessions.insert(StrengthSession(name: n % 4 == 0 ? "Torso" : "Pierna", start: d, end: d.addingTimeInterval(55 * 60), items: items), at: 0)
        }
    }
}
