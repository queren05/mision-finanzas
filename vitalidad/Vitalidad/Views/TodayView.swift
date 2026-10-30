import SwiftUI

struct TodayView: View {
    @Environment(HealthStore.self) private var store
    @State private var settings = Launch.args.contains("-settings")
    @State private var opened: Metric? = Launch.value("-detail").flatMap(Metric.init(rawValue:))
    @Namespace private var zoom

    private let cards: [Metric] = [.steps, .activeEnergy, .exerciseMinutes, .restingHR, .hrv, .respiratoryRate, .calories]

    var body: some View {
        let report = ScoreEngine.report(store)
        let insights = cards.compactMap { Explainer.insight($0, store: store) }
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                Text(Fmt.day(.now, style: "EEEE, d 'de' MMMM").capitalized)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, Space.xs)

                Text(report.summary)
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Space.xs)
                    .padding(.bottom, Space.xs)
                    .stagger(0)

                if !report.scores.isEmpty {
                    ScoresCard(scores: report.scores).stagger(1)
                }

                ForEach(Array(insights.enumerated()), id: \.element.id) { i, ins in
                    NavigationLink(value: ins.metric) {
                        InsightCard(insight: ins)
                            .zoomSource(ins.metric, zoom)
                    }
                    .buttonStyle(.plain)
                    .stagger(i + 2)
                    .scrollFade()
                }

                if let updated = store.updated {
                    Text("Actualizado a las \(Fmt.clock(updated))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, Space.s)
                }
            }
            .padding(.horizontal, Space.l)
            .padding(.bottom, Space.xxl)
        }
        .background(MoodBackground(mood: report.mood))
        .navigationTitle("Hoy")
        .navigationDestination(for: Metric.self) { m in
            MetricDetailView(metric: m).zoomDestination(m, zoom)
        }
        .navigationDestination(item: $opened) { m in
            MetricDetailView(metric: m)
        }
        .refreshable { await store.refresh(full: false) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { settings = true } label: { Image(systemName: "gearshape") }
            }
        }
        .sheet(isPresented: $settings) { SettingsView() }
    }
}

/// Las tres puntuaciones con anillo y su frase.
struct ScoresCard: View {
    var scores: [Score]

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            HStack(spacing: Space.m) {
                ForEach(scores) { s in
                    VStack(spacing: Space.s) {
                        ZStack {
                            Ring(progress: Double(s.value) / 100, color: s.color, lineWidth: 10)
                            CountingNumber(value: s.value)
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                        }
                        .frame(width: 88, height: 88)
                        Text(s.title).font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(s.title): \(s.value) de 100")
                }
            }
            VStack(alignment: .leading, spacing: Space.m) {
                ForEach(scores) { s in
                    HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                        Circle().fill(s.color).frame(width: 8, height: 8)
                        Text(s.sentence)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .card()
    }
}

/// Número que cuenta desde 0 hasta su valor.
struct CountingNumber: View {
    var value: Int
    @State private var shown = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text("\(shown)")
            .contentTransition(.numericText(value: Double(shown)))
            .monospacedDigit()
            .onAppear { set(value) }
            .onChange(of: value) { _, v in set(v) }
    }

    private func set(_ v: Int) {
        if reduceMotion { shown = v; return }
        withAnimation(.spring(response: 1.0, dampingFraction: 0.9).delay(0.15)) { shown = v }
    }
}

/// Tarjeta de una métrica: valor, estado y su frase. Una sola idea por tarjeta.
struct InsightCard: View {
    var insight: Insight

    var body: some View {
        let m = insight.metric
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(spacing: Space.s) {
                MetricGlyph(symbol: m.symbol, color: m.color)
                Text(m.title).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                StatusPill(status: insight.status)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(insight.display)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(m.unit).font(.headline).foregroundStyle(.secondary)
            }
            Text(insight.sentence)
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

#Preview {
    NavigationStack { TodayView() }
        .environment(HealthStore.preview())
        .fontDesign(.rounded)
        .preferredColorScheme(.dark)
}
