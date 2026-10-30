import SwiftUI
import Charts

struct TrendsView: View {
    @Environment(HealthStore.self) private var store
    @State private var days = 30
    @Namespace private var zoom

    private let metrics: [Metric] = [.steps, .sleep, .restingHR, .hrv]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                Picker("Periodo", selection: $days.animation(.smooth)) {
                    Text("7 días").tag(7)
                    Text("30 días").tag(30)
                    Text("90 días").tag(90)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Space.xs)

                ForEach(Array(metrics.filter { store.has($0) }.enumerated()), id: \.element) { i, m in
                    NavigationLink(value: m) {
                        TrendCard(metric: m, days: days).zoomSource(m, zoom)
                    }
                    .buttonStyle(.plain)
                    .stagger(i)
                    .scrollFade()
                }

                if !metrics.contains(where: { store.has($0) }) {
                    EmptyCard(symbol: "chart.xyaxis.line", color: Palette.recovery, title: "Sin tendencias aún",
                              text: "Con unos días de datos del reloj verás aquí cómo evolucionas.")
                }
            }
            .padding(.horizontal, Space.l)
            .padding(.bottom, Space.xxl)
        }
        .background(MoodBackground(mood: .steady))
        .navigationTitle("Tendencias")
        .navigationDestination(for: Metric.self) { m in MetricDetailView(metric: m).zoomDestination(m, zoom) }
        .sensoryFeedback(.selection, trigger: days)
    }
}

struct TrendCard: View {
    var metric: Metric
    var days: Int
    @Environment(HealthStore.self) private var store

    var body: some View {
        // Lo acumulado de hoy aún no está completo: fuera de las tendencias.
        let points = store.series(metric, days: days, includeToday: !metric.accumulates)
        let avg = points.isEmpty ? nil : points.map(\.value).reduce(0, +) / Double(points.count)
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(spacing: Space.s) {
                MetricGlyph(symbol: metric.symbol, color: metric.color)
                Text(metric.title).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                if let avg {
                    Text("media \(Fmt.full(metric, avg))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            Text(Trend.sentence(metric, points: points, days: days))
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            MetricChart(metric: metric, points: points, baseline: nil, bars: days <= 30 && (metric.accumulates || metric == .sleep))
                .frame(height: 150)
        }
        .card()
    }
}

/// Hacia dónde vas: recta de tendencia del periodo y qué significa.
enum Trend {
    /// Cambio de principio a fin según la recta que mejor se ajusta.
    static func change(_ points: [TimePoint]) -> (from: Double, to: Double)? {
        guard points.count >= 5, let t0 = points.first?.date else { return nil }
        let xs = points.map { $0.date.timeIntervalSince(t0) / 86400 }
        let ys = points.map(\.value)
        let n = Double(points.count)
        let mx = xs.reduce(0, +) / n, my = ys.reduce(0, +) / n
        let sxx = zip(xs, xs).reduce(0) { $0 + ($1.0 - mx) * ($1.1 - mx) }
        guard sxx > 0 else { return nil }
        let slope = zip(xs, ys).reduce(0) { $0 + ($1.0 - mx) * ($1.1 - my) } / sxx
        let a = my - slope * mx
        return (a, a + slope * (xs.last ?? 0))
    }

    static func sentence(_ m: Metric, points: [TimePoint], days: Int) -> String {
        guard let c = change(points), c.from != 0 else {
            return "Faltan datos para ver la tendencia de estos \(days) días."
        }
        let from = c.from
        let diff = c.to - from
        let pct = abs(diff / from * 100)
        let period = days == 7 ? "esta semana" : "en \(days) días"
        if pct < 3 { return "Estable \(period): sin cambios que destacar." }
        let up = diff > 0
        let amount: String = switch m {
        case .sleep: Fmt.duration(abs(diff))
        case .restingHR: "\(Fmt.number(abs(diff))) lpm"
        case .hrv: "\(Fmt.number(abs(diff))) ms"
        default: "un \(Int(pct.rounded())) %"
        }
        let good: Bool? = switch m.direction {
        case .higher: up
        case .lower: !up
        default: nil
        }
        let verb = up ? "ha subido" : "ha bajado"
        let tail = good.map { $0 ? " Buena señal." : " Vigílalo." } ?? ""
        let subject: String = switch m {
        case .steps: "Tu media de pasos"
        case .sleep: "Tu sueño"
        case .restingHR: "Tu pulso en reposo"
        case .hrv: "Tu variabilidad"
        default: m.title
        }
        return "\(subject) \(verb) \(amount) \(period).\(tail)"
    }
}

#Preview {
    NavigationStack { TrendsView() }
        .environment(HealthStore.preview())
        .fontDesign(.rounded)
        .preferredColorScheme(.dark)
}
