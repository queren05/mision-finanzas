import SwiftUI
import Charts

/// Detalle de una métrica: gráfica de 7 o 30 días con tu rango normal y qué significa.
struct MetricDetailView: View {
    var metric: Metric
    @Environment(HealthStore.self) private var store
    @State private var range = 7

    var body: some View {
        let insight = Explainer.insight(metric, store: store)
        let points = store.series(metric, days: range)
        // Lo de hoy, si aún se está sumando, no cuenta para mínimo, media y máximo.
        let closed = store.series(metric, days: range, includeToday: !metric.accumulates).map(\.value)
        let base = store.baseline(metric)
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                if let insight {
                    VStack(alignment: .leading, spacing: Space.m) {
                        HStack {
                            Text(Calendar.current.isDateInToday(insight.day) ? "HOY" : Fmt.day(insight.day, style: "EEEE d").uppercased())
                                .font(.caption.weight(.bold))
                                .tracking(1.2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            StatusPill(status: insight.status)
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(insight.display)
                                .font(.system(size: 60, weight: .bold, design: .rounded))
                                .tracking(-1.5)
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                                .contentTransition(.numericText())
                            Text(metric.unit).font(.title3.weight(.semibold)).foregroundStyle(.secondary)
                        }
                        if let b = insight.baseline {
                            RangeBar(value: insight.value, baseline: b, color: metric.color, status: insight.status)
                            HStack {
                                Text("Tu normal: \(Fmt.value(metric, max(0, b.low)))–\(Fmt.full(metric, b.high))")
                                Spacer()
                                DeltaChip(insight: insight)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        Text(insight.sentence)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, Space.xs)
                    }
                    .card(padding: 22, radius: 30, tint: metric.color)
                }

                VStack(alignment: .leading, spacing: Space.l) {
                    Picker("Periodo", selection: $range.animation(.smooth)) {
                        Text("7 días").tag(7)
                        Text("30 días").tag(30)
                        Text("90 días").tag(90)
                    }
                    .pickerStyle(.segmented)

                    if !closed.isEmpty {
                        HStack(spacing: 0) {
                            stat("Mínimo", closed.min()!)
                            Divider().frame(height: 30)
                            stat("Media", closed.reduce(0, +) / Double(closed.count))
                            Divider().frame(height: 30)
                            stat("Máximo", closed.max()!)
                        }
                    }

                    MetricChart(metric: metric, points: points, baseline: base, bars: (metric.accumulates || metric == .sleep) && range <= 30, scrub: true)
                        .frame(height: 230)

                    if let base {
                        HStack(spacing: Space.s) {
                            RoundedRectangle(cornerRadius: 3).fill(metric.color.opacity(0.22)).frame(width: 18, height: 10)
                            Text("Tu normal: \(Fmt.value(metric, max(0, base.low))) – \(Fmt.full(metric, base.high))")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .card()

                VStack(alignment: .leading, spacing: Space.m) {
                    CardHeader("Qué es", symbol: "info.circle.fill", color: metric.color)
                    Text(Glossary.what(metric)).fixedSize(horizontal: false, vertical: true)
                    CardHeader("Por qué importa", symbol: "sparkles", color: metric.color).padding(.top, Space.s)
                    Text(Glossary.why(metric)).fixedSize(horizontal: false, vertical: true)
                }
                .card()
            }
            .padding(.horizontal, Space.l)
            .padding(.bottom, Space.xxl)
        }
        .background(MoodBackground(mood: .neutral))
        .navigationTitle(metric.title)
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: range)
    }

    private func stat(_ title: String, _ v: Double) -> some View {
        VStack(spacing: 3) {
            Text(Fmt.value(metric, v))
                .font(.system(.headline, design: .rounded).weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// Bien / Normal / Atención.
struct StatusPill: View {
    var status: Status

    var body: some View {
        Label(status.title, systemImage: status.symbol)
            .symbolEffect(.pulse, options: .repeating, isActive: status == .attention)
            .font(.caption.weight(.bold))
            .foregroundStyle(status.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(status.color.opacity(0.16), in: Capsule())
    }
}

/// Gráfica suave (barras para lo acumulado, línea para el resto) con la franja de lo normal.
struct MetricChart: View {
    var metric: Metric
    var points: [TimePoint]
    var baseline: Baseline?
    var bars: Bool
    var showBand = true
    /// Tocar y arrastrar para ver el valor de cada día.
    var scrub = false
    @State private var selected: Date?

    private func y(_ v: Double) -> Double {
        switch metric {
        case .sleep: v / 3600
        case .activeEnergy, .basalEnergy, .calories: Fmt.energy(v)
        default: v
        }
    }

    var body: some View {
        Chart {
            if showBand, let b = baseline, let first = points.first?.date, let last = points.last?.date {
                RectangleMark(
                    xStart: .value("Desde", first, unit: .day),
                    xEnd: .value("Hasta", Calendar.current.date(byAdding: .day, value: 1, to: last)!, unit: .day),
                    yStart: .value("Bajo", y(max(0, b.low))),
                    yEnd: .value("Alto", y(b.high))
                )
                .foregroundStyle(metric.color.opacity(0.13))
                RuleMark(y: .value("Media", y(b.median)))
                    .foregroundStyle(metric.color.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            if scrub, let sel = selected, let p = points.first(where: { Calendar.current.isDate($0.date, inSameDayAs: sel) }) {
                RuleMark(x: .value("Día", p.date, unit: .day))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .annotation(position: .top, spacing: 4, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        VStack(spacing: 1) {
                            Text(Fmt.full(metric, p.value))
                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                .monospacedDigit()
                            Text(Fmt.day(p.date, style: "EEE d MMM"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Ink.surfaceHigh, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(metric.color.opacity(0.5), lineWidth: 1))
                    }
            }
            ForEach(points, id: \.date) { p in
                if bars {
                    BarMark(x: .value("Día", p.date, unit: .day), y: .value(metric.title, y(p.value)))
                        .foregroundStyle(LinearGradient(colors: [metric.color, metric.color.opacity(0.45)], startPoint: .top, endPoint: .bottom))
                        .cornerRadius(4)
                } else {
                    AreaMark(x: .value("Día", p.date, unit: .day), y: .value(metric.title, y(p.value)))
                        .foregroundStyle(LinearGradient(colors: [metric.color.opacity(0.35), metric.color.opacity(0)], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.catmullRom)
                    LineMark(x: .value("Día", p.date, unit: .day), y: .value(metric.title, y(p.value)))
                        .foregroundStyle(metric.color)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                        .interpolationMethod(.catmullRom)
                    if points.count <= 10 {
                        PointMark(x: .value("Día", p.date, unit: .day), y: .value(metric.title, y(p.value)))
                            .foregroundStyle(metric.color)
                            .symbolSize(28)
                    }
                }
            }
        }
        .chartYScale(domain: .automatic(includesZero: bars))
        .scrubbing(scrub, $selected)
        .sensoryFeedback(.selection, trigger: selected.map { Calendar.current.startOfDay(for: $0) })
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: points.count > 40 ? 30 : points.count > 10 ? 7 : 1)) { _ in
                AxisValueLabel(format: points.count > 10 ? .dateTime.day().month(.abbreviated) : .dateTime.weekday(.narrow))
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing) { _ in
                AxisGridLine().foregroundStyle(.secondary.opacity(0.2))
                AxisValueLabel()
            }
        }
    }
}

extension View {
    @ViewBuilder
    func scrubbing(_ on: Bool, _ selection: Binding<Date?>) -> some View {
        if on {
            self.chartXSelection(value: selection)
        } else {
            self
        }
    }
}
