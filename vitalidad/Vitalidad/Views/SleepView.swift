import SwiftUI
import Charts

struct SleepView: View {
    @Environment(HealthStore.self) private var store
    @Namespace private var zoom

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                if let night = store.lastNight {
                    let score = ScoreEngine.sleep(night, store: store).0
                    let insight = Explainer.insight(.sleep, store: store)
                    hero(night: night, score: score, insight: insight).stagger(0)
                    if night.hasStages {
                        StagesCard(night: night).stagger(1)
                    }
                    RegularityCard(nights: store.recentNights(14)).stagger(2).scrollFade()
                    ComparisonCard(night: night).stagger(3).scrollFade()
                    adviceCard(night: night).stagger(4).scrollFade()
                    NavigationLink(value: Metric.sleep) {
                        VStack(alignment: .leading, spacing: Space.m) {
                            CardHeader("Últimas noches", symbol: "chart.bar.fill", color: Palette.sleep)
                            MetricChart(metric: .sleep, points: store.series(.sleep, days: 7), baseline: store.baseline(.sleep), bars: true)
                                .frame(height: 160)
                        }
                        .card()
                        .zoomSource(Metric.sleep, zoom)
                    }
                    .buttonStyle(.plain)
                    .scrollFade()
                } else {
                    EmptyCard(symbol: "moon.zzz.fill", color: Palette.sleep, title: "Sin datos de sueño",
                              text: "Duerme con el Apple Watch puesto y activa el seguimiento del sueño en la app Salud.")
                }
            }
            .padding(.horizontal, Space.l)
            .padding(.bottom, Space.xxl)
        }
        .background(MoodBackground(mood: .night))
        .navigationTitle("Sueño")
        .navigationDestination(for: Metric.self) { m in MetricDetailView(metric: m).zoomDestination(m, zoom) }
        .refreshable { await store.refresh(full: false) }
    }

    private func hero(night: SleepNight, score: Int, insight: Insight?) -> some View {
        VStack(alignment: .leading, spacing: Space.l) {
            HStack(alignment: .center, spacing: Space.m) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("ANOCHE")
                        .font(.caption.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(.secondary)
                    Text(Fmt.duration(night.asleep))
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .tracking(-1.5)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .contentTransition(.numericText())
                    HStack(spacing: 8) {
                        Label(Fmt.clock(night.start), systemImage: "moon.fill")
                        Image(systemName: "arrow.right").font(.caption2.weight(.bold)).foregroundStyle(.tertiary)
                        Label(Fmt.clock(night.end), systemImage: "sun.max.fill")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .labelStyle(TightLabel())
                }
                Spacer(minLength: 0)
                ZStack {
                    AnimatedGauge(value: Double(score) / 100, stops: RGB.sleep, ticks: 40, tickLength: 10, tickWidth: 2.6)
                    VStack(spacing: 0) {
                        CountingNumber(value: score)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                        Text("PUNTOS")
                            .font(.system(size: 9, weight: .heavy))
                            .tracking(1.2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 108, height: 108)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Puntuación del sueño: \(score) de 100")
            }

            HStack(spacing: 0) {
                stat("En la cama", Fmt.duration(night.inBed))
                Divider().frame(height: 30)
                stat("Eficiencia", "\(Int((night.efficiency * 100).rounded())) %")
                Divider().frame(height: 30)
                stat("Despierto", Fmt.duration(night.awake))
            }
            .padding(.vertical, Space.s)
            .background(Ink.track.opacity(0.35), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            if let insight {
                HStack(spacing: Space.m) {
                    StatusPill(status: insight.status)
                    DeltaChip(insight: insight)
                }
                Text(insight.sentence)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .card(padding: 22, radius: 30, tint: Palette.sleep)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func adviceCard(night: SleepNight) -> some View {
        HStack(alignment: .top, spacing: Space.m) {
            MetricGlyph(symbol: "lightbulb.fill", color: Palette.attention, size: 36)
            Text(SleepAdvice.text(night: night, store: store))
                .font(.subheadline.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }
}

/// Fases de la noche: gráfica tipo escalera y tiempo en cada fase.
struct StagesCard: View {
    var night: SleepNight

    private let stages: [SleepStage] = [.awake, .rem, .core, .deep]

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            CardHeader("Fases", symbol: "waveform.path", color: Palette.sleep)
            let segs = night.segments.sorted { $0.start < $1.start }
            Chart {
                // Líneas finas que unen una fase con la siguiente (el hipnograma de los laboratorios del sueño).
                ForEach(Array(segs.indices.dropLast()), id: \.self) { i in
                    RuleMark(
                        x: .value("Cambio", segs[i + 1].start),
                        yStart: .value("De", Double(3 - segs[i].stage.level)),
                        yEnd: .value("A", Double(3 - segs[i + 1].stage.level))
                    )
                    .foregroundStyle(.secondary.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                }
                ForEach(segs, id: \.start) { s in
                    RectangleMark(
                        xStart: .value("Inicio", s.start),
                        xEnd: .value("Fin", s.end),
                        yStart: .value("Fase", Double(3 - s.stage.level) - 0.32),
                        yEnd: .value("Fase", Double(3 - s.stage.level) + 0.32)
                    )
                    .foregroundStyle(s.stage.color.gradient)
                    .cornerRadius(4)
                }
            }
            .chartYScale(domain: -0.6...3.6)
            .chartYAxis {
                AxisMarks(values: [0, 1, 2, 3]) { v in
                    AxisValueLabel {
                        if let i = v.as(Double.self) {
                            Text(stages.first { Double(3 - $0.level) == i }?.title ?? "")
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 2)) { _ in
                    AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .omitted)))
                }
            }
            .frame(height: 170)

            let asleep = max(1, night.asleep + night.awake)
            GeometryReader { geo in
                HStack(spacing: 3) {
                    ForEach(stages.reversed(), id: \.self) { st in
                        let share = night.time(st) / asleep
                        if share > 0 {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(st.color)
                                .frame(width: max(4, (geo.size.width - 9) * share))
                        }
                    }
                }
            }
            .frame(height: 10)
            .accessibilityHidden(true)
            VStack(spacing: Space.s) {
                ForEach(stages.reversed(), id: \.self) { st in
                    let t = night.time(st)
                    HStack(spacing: Space.m) {
                        Circle().fill(st.color).frame(width: 10, height: 10)
                        Text(st.title).font(.subheadline)
                        Spacer()
                        Text(Fmt.duration(t)).font(.subheadline.weight(.semibold)).monospacedDigit()
                        Text("\(Int((t / asleep * 100).rounded())) %")
                            .font(.footnote).foregroundStyle(.secondary).monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                }
            }
        }
        .card()
    }
}

/// Regularidad: a qué hora te acuestas y te levantas cada noche.
struct RegularityCard: View {
    var nights: [SleepNight]

    var body: some View {
        let beds = nights.map { ScoreEngine.minutesFromMidnight($0.start) }
        let wakes = nights.map { ScoreEngine.minutesFromMidnight($0.end) }
        VStack(alignment: .leading, spacing: Space.m) {
            CardHeader("Regularidad", symbol: "clock.fill", color: Palette.sleep)
            if nights.count >= 3 {
                let sd = Self.sd(beds)
                Text(Self.sentence(sd: sd, bed: Self.median(beds), wake: Self.median(wakes)))
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                Chart(nights) { n in
                    BarMark(
                        x: .value("Noche", n.day, unit: .day),
                        yStart: .value("Acostarse", ScoreEngine.minutesFromMidnight(n.start)),
                        yEnd: .value("Levantarse", ScoreEngine.minutesFromMidnight(n.end)),
                        width: .ratio(0.5)
                    )
                    .foregroundStyle(LinearGradient(colors: [Palette.sleep, Palette.sleep.opacity(0.5)], startPoint: .bottom, endPoint: .top))
                    .cornerRadius(6)
                }
                .chartYScale(domain: .automatic(includesZero: false, reversed: true))
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .stride(by: 120)) { v in
                        AxisGridLine().foregroundStyle(.secondary.opacity(0.2))
                        AxisValueLabel {
                            if let m = v.as(Double.self) { Text(ScoreEngine.clock(fromMinutes: m)) }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 2)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow))
                    }
                }
                .frame(height: 180)
            } else {
                Text("Con tres noches más podré decirte lo regulares que son tus horarios.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .card()
    }

    static func median(_ v: [Double]) -> Double { v.isEmpty ? 0 : v.sorted()[v.count / 2] }

    static func sd(_ v: [Double]) -> Double {
        guard v.count > 1 else { return 0 }
        let mean = v.reduce(0, +) / Double(v.count)
        return sqrt(v.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(v.count - 1))
    }

    static func sentence(sd: Double, bed: Double, wake: Double) -> String {
        let b = ScoreEngine.clock(fromMinutes: bed), w = ScoreEngine.clock(fromMinutes: wake)
        let spread = Int(sd.rounded())
        if sd < 30 { return "Horarios muy regulares: te acuestas sobre las \(b) (± \(spread) min) y te levantas sobre las \(w). Tu reloj interno lo agradece." }
        if sd < 60 { return "Horarios bastante regulares: te acuestas sobre las \(b), con unos \(spread) min arriba o abajo." }
        return "Horarios irregulares: tu hora de acostarte cambia unos \(spread) min de una noche a otra. Acostarte siempre a la misma hora mejora el sueño."
    }
}

/// Anoche frente a tu media.
struct ComparisonCard: View {
    var night: SleepNight
    @Environment(HealthStore.self) private var store

    var body: some View {
        let previous = store.recentNights(31).filter { $0.day < night.day }
        VStack(alignment: .leading, spacing: Space.m) {
            CardHeader("Frente a tu media", symbol: "equal.circle.fill", color: Palette.sleep)
            if previous.count >= Baseline.minDays {
                row("Dormido", night.asleep, previous.map(\.asleep))
                if night.hasStages {
                    row("Profundo", night.time(.deep), previous.filter(\.hasStages).map { $0.time(.deep) })
                    row("REM", night.time(.rem), previous.filter(\.hasStages).map { $0.time(.rem) })
                }
                row("Despierto", night.awake, previous.map(\.awake), lowerIsBetter: true)
            } else {
                Text("Aún estoy aprendiendo cómo duermes tú (\(previous.count) de \(Baseline.minDays) noches).")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private func row(_ title: String, _ v: Double, _ history: [Double], lowerIsBetter: Bool = false) -> some View {
        let med = RegularityCard.median(history)
        let d = v - med
        let better = lowerIsBetter ? d < 0 : d > 0
        let small = abs(d) < 10 * 60
        return HStack {
            Text(title).font(.subheadline)
            Spacer()
            Text(Fmt.duration(v)).font(.subheadline.weight(.semibold)).monospacedDigit()
            HStack(spacing: 2) {
                Image(systemName: small ? "equal" : d > 0 ? "arrow.up" : "arrow.down")
                Text(small ? "media" : Fmt.duration(abs(d)))
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(small ? Palette.normal : better ? Palette.good : Palette.attention)
            .frame(width: 84, alignment: .trailing)
        }
    }
}

/// El consejo de una frase.
enum SleepAdvice {
    @MainActor
    static func text(night: SleepNight, store: HealthStore) -> String {
        let nights = store.recentNights(14)
        let beds = nights.map { ScoreEngine.minutesFromMidnight($0.start) }
        let usualBed = RegularityCard.median(beds)
        if let b = store.baseline(.sleep, before: night.day), night.asleep < b.median - b.spread {
            let target = ScoreEngine.clock(fromMinutes: usualBed - 30)
            return "Esta noche intenta acostarte sobre las \(target) para recuperar el sueño que te falta."
        }
        if RegularityCard.sd(beds) >= 60 {
            return "Elige una hora fija para acostarte (por ejemplo, las \(ScoreEngine.clock(fromMinutes: usualBed))) y cúmplela también el fin de semana."
        }
        if night.hasStages && night.time(.deep) / max(1, night.asleep) < 0.1 {
            return "Poco sueño profundo: cenar pronto, evitar el alcohol y hacer ejercicio por la mañana ayudan a tenerlo."
        }
        if night.efficiency < 0.85 {
            return "Muchos ratos despierto: una habitación fresca (unos 18 °C), oscura y sin pantallas antes de dormir ayuda."
        }
        return "Sigue así: duermes bien y con horarios estables."
    }
}

/// Tarjeta para cuando no hay datos.
struct EmptyCard: View {
    var symbol: String
    var color: Color
    var title: String
    var text: String

    var body: some View {
        VStack(spacing: Space.m) {
            MetricGlyph(symbol: symbol, color: color, size: 64)
            Text(title).font(.title3.weight(.bold))
            Text(text).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .card(padding: Space.xl)
        .padding(.top, Space.xxl)
    }
}

#Preview {
    NavigationStack { SleepView() }
        .environment(HealthStore.preview())
                .preferredColorScheme(.dark)
}

/// Icono y texto muy juntos.
struct TightLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon.font(.caption)
            configuration.title
        }
    }
}
