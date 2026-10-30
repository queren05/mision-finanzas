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
        let base = store.baseline(metric)
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                if let insight {
                    VStack(alignment: .leading, spacing: Space.s) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(insight.display)
                                .font(.system(size: 56, weight: .bold, design: .rounded))
                                .contentTransition(.numericText())
                            Text(metric.unit).font(.title3.weight(.semibold)).foregroundStyle(.secondary)
                        }
                        StatusPill(status: insight.status)
                        Text(insight.sentence)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, Space.xs)
                    }
                    .card(tint: metric.color)
                }

                VStack(alignment: .leading, spacing: Space.m) {
                    Picker("Periodo", selection: $range.animation(.smooth)) {
                        Text("7 días").tag(7)
                        Text("30 días").tag(30)
                    }
                    .pickerStyle(.segmented)

                    MetricChart(metric: metric, points: points, baseline: base, bars: metric.accumulates || metric == .sleep)
                        .frame(height: 220)

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
                    Label("Qué es", systemImage: "info.circle.fill").font(.headline).foregroundStyle(metric.color)
                    Text(Glossary.what(metric)).fixedSize(horizontal: false, vertical: true)
                    Label("Por qué importa", systemImage: "sparkles").font(.headline).foregroundStyle(metric.color).padding(.top, Space.s)
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
}

/// Bien / Normal / Atención.
struct StatusPill: View {
    var status: Status

    var body: some View {
        Label(status.title, systemImage: status.symbol)
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
