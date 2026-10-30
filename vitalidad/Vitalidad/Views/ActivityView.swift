import SwiftUI
import Charts

struct ActivityView: View {
    @Environment(HealthStore.self) private var store
    @Namespace private var zoom

    var body: some View {
        let report = ScoreEngine.report(store)
        let recent = store.workouts(days: 14)
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                if let effort = report.effort {
                    hero(effort).stagger(0)
                }
                WeeklyLoadCard().stagger(1).scrollFade()

                if !recent.isEmpty {
                    VStack(alignment: .leading, spacing: Space.m) {
                        Label("Entrenos recientes", systemImage: "figure.run").font(.headline).foregroundStyle(Palette.effort)
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
        .navigationDestination(for: Metric.self) { m in MetricDetailView(metric: m).zoomDestination(m, zoom) }
        .refreshable { await store.refresh(full: false) }
    }

    private func hero(_ s: Score) -> some View {
        HStack(spacing: Space.l) {
            ZStack {
                Ring(progress: Double(s.value) / 100, color: s.color, lineWidth: 12)
                CountingNumber(value: s.value).bigFont(30)
            }
            .frame(width: 104, height: 104)
            VStack(alignment: .leading, spacing: Space.s) {
                Text("Esfuerzo de hoy").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.effort)
                Text(s.sentence).font(.subheadline).fixedSize(horizontal: false, vertical: true)
            }
        }
        .card(tint: Palette.effort)
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
            Label("Carga semanal", systemImage: "chart.bar.fill").font(.headline).foregroundStyle(Palette.effort)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(Fmt.value(.activeEnergy, current)).bigFont(36)
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
        .fontDesign(.rounded)
        .preferredColorScheme(.dark)
}
