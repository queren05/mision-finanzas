import SwiftUI
import Charts

struct ActivityView: View {
    @Environment(HealthStore.self) private var store
    @Namespace private var zoom
    @State private var strengthOpen = Launch.args.contains("-fuerza")

    var body: some View {
        let report = ScoreEngine.report(store)
        let recent = store.workouts(days: 14)
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                if let effort = report.effort {
                    hero(effort).stagger(0)
                }
                StrengthCard().stagger(1).scrollFade()
                LoadCard().stagger(1).scrollFade()
                WeeklyLoadCard().stagger(1).scrollFade()

                if !recent.isEmpty {
                    VStack(alignment: .leading, spacing: Space.m) {
                        CardHeader("Entrenos recientes", symbol: "figure.run", color: Palette.effort)
                        ForEach(recent) { w in
                            WorkoutRow(workout: w)
                            if w.id != recent.last?.id { Divider().opacity(0.5) }
                        }
                    }
                    .card()
                    .stagger(2)
                    .scrollFade()
                }

                ForEach(Array([Metric.steps, .exerciseMinutes, .standHours, .vo2max, .walkingHR].compactMap { Explainer.insight($0, store: store) }.enumerated()), id: \.element.id) { i, ins in
                    NavigationLink(value: ins.metric) {
                        InsightCard(insight: ins).zoomSource(ins.metric, zoom)
                    }
                    .buttonStyle(.plain)
                    .stagger(i + 3)
                    .scrollFade()
                }

                if report.effort == nil && recent.isEmpty && !store.has(.steps) {
                    EmptyCard(symbol: "flame.fill", color: Palette.effort, title: "Sin datos de actividad",
                              text: "Cuando el reloj registre pasos, energía o entrenos, aparecerán aquí.")
                }
            }
            .padding(.horizontal, Space.l)
            .padding(.bottom, Space.xxl)
        }
        .background(MoodBackground(mood: report.mood == .night ? .night : .easy))
        .navigationTitle("Actividad")
        .navigationDestination(isPresented: $strengthOpen) { StrengthView() }
        .navigationDestination(for: Metric.self) { m in MetricDetailView(metric: m).zoomDestination(m, zoom) }
        .refreshable { await store.refresh(full: false) }
    }

    private func hero(_ s: Score) -> some View {
        HStack(spacing: Space.l) {
            ZStack {
                AnimatedGauge(value: Double(s.value) / 100, stops: s.scale, ticks: 44, tickLength: 11, tickWidth: 2.8)
                VStack(spacing: 0) {
                    CountingNumber(value: s.value)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    Text("ESFUERZO")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(1.2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 118, height: 118)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Esfuerzo de hoy: \(s.value) de 100")
            VStack(alignment: .leading, spacing: 6) {
                Text(s.verdict)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(s.tone)
                Text(s.sentence)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .card(padding: 22, radius: 30, tint: s.tone)
    }
}

/// Carga semanal: energía activa de cada semana y comparación con tus semanas normales.
struct WeeklyLoadCard: View {
    @Environment(HealthStore.self) private var store

    struct Week: Identifiable {
        var start: Date
        var energy: Double
        var minutes: Double
        var id: Date { start }
    }

    var weeks: [Week] {
        let cal = Calendar.current
        return (0..<8).reversed().compactMap { n -> Week? in
            guard let end = cal.date(byAdding: .day, value: -7 * n, to: store.today),
                  let start = cal.date(byAdding: .day, value: -6, to: end) else { return nil }
            let e = (store.values[.activeEnergy] ?? [:]).filter { $0.key >= start && $0.key <= end }.reduce(0) { $0 + $1.value }
            let m = (store.values[.exerciseMinutes] ?? [:]).filter { $0.key >= start && $0.key <= end }.reduce(0) { $0 + $1.value }
            return Week(start: start, energy: e, minutes: m)
        }
    }

    var body: some View {
        let w = weeks
        let current = w.last?.energy ?? 0
        let previous = w.dropLast().suffix(4).map(\.energy).filter { $0 > 0 }
        let usual = previous.isEmpty ? 0 : previous.reduce(0, +) / Double(previous.count)
        VStack(alignment: .leading, spacing: Space.m) {
            CardHeader("Carga semanal", symbol: "chart.bar.fill", color: Palette.effort)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(Fmt.value(.activeEnergy, current)).bigFont(36).monospacedDigit()
                Text("\(Fmt.energyUnit) en 7 días").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            }
            Text(Self.sentence(current: current, usual: usual, minutes: w.last?.minutes ?? 0))
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            Chart(w) { week in
                BarMark(x: .value("Semana", week.start, unit: .weekOfYear), y: .value("Energía", Fmt.energy(week.energy)))
                    .foregroundStyle(
                        (week.id == w.last?.id ? Palette.effort : Palette.effort.opacity(0.4)).gradient
                    )
                    .cornerRadius(6)
                if usual > 0 {
                    RuleMark(y: .value("Normal", Fmt.energy(usual)))
                        .foregroundStyle(.secondary.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 140)
        }
        .card()
    }

    static func sentence(current: Double, usual: Double, minutes: Double) -> String {
        let mins = "\(Fmt.number(minutes)) min de ejercicio"
        guard usual > 0 else { return "Llevas \(mins) en los últimos 7 días." }
        let ratio = current / usual
        let pct = Int((abs(ratio - 1) * 100).rounded())
        if ratio > 1.3 { return "Esta semana cargas un \(pct) % más que de costumbre (\(mins)). Bien si lo buscas, pero deja hueco para descansar." }
        if ratio < 0.8 { return "Semana más suave que de costumbre: un \(pct) % menos (\(mins))." }
        return "Carga parecida a tus semanas normales: \(mins) en 7 días."
    }
}

struct WorkoutRow: View {
    var workout: Workout

    var body: some View {
        HStack(spacing: Space.m) {
            MetricGlyph(symbol: workout.symbol, color: Palette.effort, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.name).font(.subheadline.weight(.semibold))
                Text(Fmt.day(workout.start, style: "EEEE d · H:mm").capitalizedFirst)
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Fmt.duration(workout.duration)).font(.subheadline.weight(.semibold)).monospacedDigit()
                Text(details).font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
        }
    }

    private var details: String {
        var p: [String] = []
        if let d = workout.distance, d > 100 { p.append("\(Fmt.number(d / 1000, decimals: 1)) km") }
        if let e = workout.energy { p.append(Fmt.full(.activeEnergy, e)) }
        if let h = workout.avgHR { p.append("\(Fmt.number(h)) lpm") }
        return p.prefix(2).joined(separator: " · ")
    }
}

#Preview {
    NavigationStack { ActivityView() }
        .environment(HealthStore.preview())
                .preferredColorScheme(.dark)
}

/// Carga de entreno: aguja sobre cuatro zonas (pierdes forma, óptima, alta, riesgo).
struct LoadCard: View {
    @Environment(HealthStore.self) private var store

    var body: some View {
        if let load = TrainingLoad.compute(store) {
            let zone = TrainingLoad.zone(load.ratio)
            VStack(alignment: .leading, spacing: Space.m) {
                CardHeader("Carga de entreno", symbol: "gauge.with.needle.fill", color: TrainingLoad.color(zone))
                ZStack(alignment: .bottom) {
                    LoadDial(ratio: load.ratio)
                        .frame(height: 140)
                    VStack(spacing: 0) {
                        Text(Fmt.number(load.ratio, decimals: 2))
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text(TrainingLoad.title(zone))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(TrainingLoad.color(zone))
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Últimos 7 días").font(.caption).foregroundStyle(.secondary)
                        Text("\(Fmt.full(.activeEnergy, load.acute))/día").font(.subheadline.weight(.semibold)).monospacedDigit()
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Últimos 28 días").font(.caption).foregroundStyle(.secondary)
                        Text("\(Fmt.full(.activeEnergy, load.chronic))/día").font(.subheadline.weight(.semibold)).monospacedDigit()
                    }
                }
                Text(TrainingLoad.sentence(load))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .card(tint: TrainingLoad.color(zone))
        }
    }
}

/// Medio círculo con las zonas de color y una aguja que se mueve con un muelle.
struct LoadDial: View {
    var ratio: Double
    @State private var shown: Double = 0.4

    static let lo = 0.4, hi = 2.0
    static let zones: [(Double, Double, Color)] = [
        (0.4, 0.8, Palette.breath), (0.8, 1.3, Palette.recovery), (1.3, 1.5, Palette.effort), (1.5, 2.0, Palette.heart),
    ]

    var body: some View {
        NeedleDial(value: shown)
            .onAppear { withAnimation(.spring(response: 1.4, dampingFraction: 0.6).delay(0.2)) { shown = min(Self.hi, max(Self.lo, ratio)) } }
            .onChange(of: ratio) { _, r in withAnimation(.smooth) { shown = min(Self.hi, max(Self.lo, r)) } }
    }
}

struct NeedleDial: View, Animatable {
    var value: Double
    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Canvas { ctx, size in
            let r = min(size.width / 2, size.height) - 10
            let c = CGPoint(x: size.width / 2, y: size.height - 4)
            func angle(_ v: Double) -> Angle { .degrees(180 + 180 * (v - LoadDial.lo) / (LoadDial.hi - LoadDial.lo)) }
            for z in LoadDial.zones {
                var p = Path()
                p.addArc(center: c, radius: r, startAngle: .degrees(angle(z.0).degrees + 1.2), endAngle: .degrees(angle(z.1).degrees - 1.2), clockwise: false)
                ctx.stroke(p, with: .color(z.2), style: StrokeStyle(lineWidth: 12, lineCap: .round))
            }
            // Rayitas finas por dentro.
            for i in 0...32 {
                let a = angle(LoadDial.lo + (LoadDial.hi - LoadDial.lo) * Double(i) / 32).radians
                var t = Path()
                t.move(to: CGPoint(x: c.x + CGFloat(cos(a)) * (r - 16), y: c.y + CGFloat(sin(a)) * (r - 16)))
                t.addLine(to: CGPoint(x: c.x + CGFloat(cos(a)) * (r - (i % 4 == 0 ? 24 : 20)), y: c.y + CGFloat(sin(a)) * (r - (i % 4 == 0 ? 24 : 20))))
                ctx.stroke(t, with: .color(Ink.track), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            }
            let a = angle(value).radians
            let tip = CGPoint(x: c.x + CGFloat(cos(a)) * (r - 6), y: c.y + CGFloat(sin(a)) * (r - 6))
            var n = Path()
            n.move(to: CGPoint(x: c.x + CGFloat(cos(a)) * (r * 0.62), y: c.y + CGFloat(sin(a)) * (r * 0.62)))
            n.addLine(to: tip)
            ctx.stroke(n, with: .color(.primary), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            ctx.fill(Path(ellipseIn: CGRect(x: tip.x - 5, y: tip.y - 5, width: 10, height: 10)), with: .color(.primary))
        }
        .accessibilityHidden(true)
    }
}
