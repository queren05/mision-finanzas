import Foundation

/// Lo que se enseña en cada tarjeta: valor, estado y una frase que lo explica.
struct Insight: Identifiable {
    var metric: Metric
    var value: Double
    var day: Date
    var status: Status
    var sentence: String
    var baseline: Baseline?
    /// Para lo acumulado de hoy: lo que sueles llevar a estas horas.
    var expected: Double?

    var id: Metric { metric }
    var display: String { Fmt.value(metric, value) }
}

/// Reglas locales con plantillas. Varias frases por caso; cambian de un día a otro pero no al refrescar.
@MainActor
enum Explainer {
    static func insight(_ m: Metric, store: HealthStore) -> Insight? {
        guard let latest = store.latest(m, within: m == .weight || m == .vo2max ? 30 : 2) else { return nil }
        let cal = Calendar.current
        let isToday = cal.isDateInToday(latest.day)
        let base = store.baseline(m, before: latest.day)
        let expected: Double? = (m.accumulates && isToday) ? base.map { $0.median * store.dayProgress } : nil
        let z = base?.z(latest.value, expected: expected) ?? 0
        var status: Status = base == nil ? .learning : Status.from(z: z, direction: m.direction)
        // A primera hora todavía no se puede decir que vayas corto.
        if m.accumulates && isToday && store.dayProgress < 0.25 && status == .attention { status = .normal }
        let text = sentence(m, value: latest.value, base: base, expected: expected, z: z, status: status, today: isToday, day: latest.day, store: store)
        return Insight(metric: m, value: latest.value, day: latest.day, status: status, sentence: text, baseline: base, expected: expected)
    }

    // MARK: - Frases

    /// Elige una variante fija para ese día y esa métrica.
    static func pick(_ options: [String], _ key: String, _ day: Date) -> String {
        let n = Int(day.timeIntervalSince1970 / 86400)
        let h = key.unicodeScalars.reduce(n) { ($0 &* 31 &+ Int($1.value)) & 0x7fffffff }
        return options[h % options.count]
    }

    /// «algo» o «bastante», según lo lejos que esté de lo normal.
    static func much(_ z: Double) -> String { abs(z) >= 2 ? "bastante" : "algo" }

    static func sentence(_ m: Metric, value v: Double, base: Baseline?, expected: Double?, z: Double, status: Status, today: Bool, day: Date, store: HealthStore) -> String {
        let V = Fmt.full(m, v)
        let vn = Fmt.value(m, v)
        guard let base else {
            let have = (store.values[m] ?? [:]).count
            return pick([
                "Aún estoy aprendiendo lo normal en ti (\(have) de \(Baseline.minDays) días). Por ahora: \(V).",
                "Con unos días más de datos podré decirte si \(V) es mucho o poco para ti.",
            ], m.rawValue, day)
        }
        let M = Fmt.full(m, base.median)
        let mn = Fmt.value(m, base.median)
        let diff = Fmt.full(m, abs(v - (expected ?? base.median)))
        let q = much(z)

        switch m {
        case .restingHR:
            switch status {
            case .good: return pick([
                "Tu pulso en reposo es \(vn), \(diff.replacingOccurrences(of: " lpm", with: "")) menos que tu media. Buena señal: estás recuperado.",
                "Hoy el corazón late más tranquilo de lo normal (\(vn) frente a \(mn)). Tu cuerpo está descansado.",
                "\(vn) pulsaciones en reposo, por debajo de tu media de \(mn). Señal de buena recuperación.",
            ], "rhr-g", day)
            case .attention: return pick([
                "Tu pulso en reposo es \(vn), \(diff.replacingOccurrences(of: " lpm", with: "")) más que tu media. Puede ser cansancio, estrés, alcohol o que te estés poniendo malo.",
                "Hoy el corazón va \(q) acelerado en reposo (\(vn) frente a \(mn)). Mejor tomártelo con calma.",
                "Pulso en reposo alto para ti: \(vn) cuando lo normal es \(mn). Tu cuerpo todavía se está recuperando.",
            ], "rhr-a", day)
            default: return pick([
                "Tu pulso en reposo es \(vn), dentro de lo normal para ti.",
                "\(vn) en reposo, muy cerca de tu media de \(mn). Nada que vigilar.",
                "Pulso en reposo estable: \(vn), como de costumbre.",
            ], "rhr-n", day)
            }

        case .hrv:
            switch status {
            case .good: return pick([
                "Tu variabilidad está alta (\(V); tu media es \(mn)). Tu cuerpo está descansado y listo para esforzarse.",
                "Variabilidad por encima de lo normal: \(V). Tu sistema nervioso está relajado.",
                "\(V) de variabilidad, más que tu media. Buena recuperación.",
            ], "hrv-g", day)
            case .attention: return pick([
                "Tu variabilidad está \(q) baja (\(V) frente a \(mn)). Suele pasar con estrés, mal sueño o cansancio.",
                "Hoy tu variabilidad es de \(V), por debajo de lo normal. Tu cuerpo pide un día tranquilo.",
                "Variabilidad baja para ti: \(V). Descansa bien esta noche.",
            ], "hrv-a", day)
            default: return pick([
                "Tu variabilidad es de \(V), en tu rango normal.",
                "\(V) de variabilidad, parecido a tu media de \(mn).",
                "Variabilidad estable: \(V). Tu recuperación va como siempre.",
            ], "hrv-n", day)
            }

        case .sleep:
            switch status {
            case .good: return pick([
                "Dormiste \(V), \(diff) más que tu media. Buen descanso.",
                "Noche larga: \(V), por encima de lo normal en ti.",
                "\(V) de sueño, más que de costumbre. Tu cuerpo lo agradecerá.",
            ], "slp-g", day)
            case .attention: return pick([
                "Dormiste \(V), \(q) menos que tu media de \(M). Hoy mejor un día suave.",
                "Noche corta: \(V), \(diff) menos de lo normal en ti.",
                "Solo \(V) de sueño. Intenta acostarte antes esta noche.",
            ], "slp-a", day)
            default: return pick([
                "Dormiste \(V), lo normal para ti.",
                "\(V) de sueño, en tu media.",
                "Noche normal: \(V).",
            ], "slp-n", day)
            }

        case .steps, .activeEnergy, .exerciseMinutes, .standHours:
            let what: String = switch m {
            case .steps: "pasos"
            case .activeEnergy: Fmt.energyUnit + " activas"
            case .exerciseMinutes: "minutos de ejercicio"
            default: "horas de pie"
            }
            if today {
                switch status {
                case .good: return pick([
                    "Llevas \(vn) \(what); a estas horas sueles ir por \(Fmt.value(m, expected ?? base.median)). Vas por delante.",
                    "Vas por encima de tu ritmo: \(vn) \(what) y lo normal a esta hora es \(Fmt.value(m, expected ?? base.median)).",
                    "Buen día: \(vn) \(what), más de lo que sueles llevar a estas horas.",
                ], "\(m.rawValue)-g", day)
                case .attention: return pick([
                    "Llevas \(vn) \(what); a estas horas sueles llevar \(Fmt.value(m, expected ?? base.median)). Un paseo corto te pondría al día.",
                    "Vas por detrás de tu ritmo: \(vn) \(what) de \(Fmt.value(m, expected ?? base.median)) que sueles llevar.",
                    "Día tranquilo de momento: \(vn) \(what). Aún hay tiempo para moverte.",
                ], "\(m.rawValue)-a", day)
                default: return pick([
                    "Llevas \(vn) \(what), a tu ritmo de siempre.",
                    "\(vn) \(what) hasta ahora; vas como un día normal.",
                    "Vas bien: \(vn) \(what), lo esperable a estas horas.",
                ], "\(m.rawValue)-n", day)
                }
            }
            switch status {
            case .good: return "Hiciste \(vn) \(what), más que tu media de \(mn)."
            case .attention: return "Hiciste \(vn) \(what), menos que tu media de \(mn)."
            default: return "Hiciste \(vn) \(what), en tu media."
            }

        case .respiratoryRate:
            if status == .attention {
                return v > base.median
                    ? pick(["Respiras más rápido de lo normal mientras duermes (\(vn) frente a \(mn)). A veces pasa antes de ponerse malo.",
                            "Tu respiración nocturna está alta para ti: \(V). Vigila cómo te encuentras."], "rr-a", day)
                    : "Tu respiración nocturna está más baja de lo normal (\(V)). Si te encuentras bien, no es preocupante."
            }
            return pick(["Respiras \(vn) veces por minuto mientras duermes, lo normal para ti.",
                         "Respiración estable: \(V), como siempre."], "rr-n", day)

        case .vo2max:
            switch status {
            case .good: return "Tu forma física ha mejorado: \(V), por encima de tu media de \(mn)."
            case .attention: return "Tu VO₂ máx ha bajado a \(vn) (tu media es \(mn)). Más cardio lo hará subir."
            default: return pick(["Tu VO₂ máx está en \(vn), estable.", "Forma física estable: VO₂ máx de \(vn)."], "vo2", day)
            }

        case .walkingHR:
            switch status {
            case .good: return "Al caminar tu pulso va a \(vn), más bajo que tu media. Señal de buena forma."
            case .attention: return "Al caminar tu pulso va a \(vn), más alto de lo normal (\(mn)). Puede ser cansancio o calor."
            default: return "Al caminar tu pulso va a \(vn), lo normal en ti."
            }

        case .weight:
            let d = v - base.median
            if abs(d) < 0.3 { return pick(["Tu peso está estable en \(V).", "\(V), igual que tu media del último mes."], "w", day) }
            return "Pesas \(V), \(Fmt.number(abs(d), decimals: 1)) kg \(d > 0 ? "más" : "menos") que tu media del último mes."

        case .heartRate:
            return "Tu pulso medio de hoy es \(vn) lpm; tu media es \(mn)."

        case .calories, .protein, .carbs, .fat, .water, .basalEnergy:
            return today ? "Llevas \(V) hoy." : "Ayer: \(V)."
        }
    }
}
