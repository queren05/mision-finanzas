import SwiftUI

struct TodayView: View {
    @Environment(HealthStore.self) private var store
    @State private var settings = Launch.args.contains("-settings")

    private let cards: [Metric] = [.steps, .activeEnergy, .exerciseMinutes, .restingHR, .hrv, .calories]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                Text(Fmt.day(.now, style: "EEEE, d 'de' MMMM").capitalized)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, Space.xs)

                if let night = store.lastNight {
                    SleepSummaryCard(night: night).stagger(0)
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: Space.m), GridItem(.flexible(), spacing: Space.m)], spacing: Space.m) {
                    ForEach(Array(cards.filter { store.has($0) }.enumerated()), id: \.element) { i, m in
                        let latest = store.latest(m)
                        MetricTile(metric: m, value: latest.map { Fmt.value(m, $0.value) } ?? "—", day: latest?.day)
                            .stagger(i + 1)
                            .scrollFade()
                    }
                }
            }
            .padding(.horizontal, Space.l)
            .padding(.bottom, Space.xxl)
        }
        .background(MoodBackground(mood: .neutral))
        .navigationTitle("Hoy")
        .refreshable { await store.refresh(full: false) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { settings = true } label: { Image(systemName: "gearshape") }
            }
        }
        .sheet(isPresented: $settings) { SettingsView() }
    }
}

/// Resumen de anoche: horas dormido y franja en la cama.
struct SleepSummaryCard: View {
    var night: SleepNight

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Label("Anoche", systemImage: "moon.zzz.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.sleep)
            Text(Fmt.duration(night.asleep))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
            Text("\(Fmt.clock(night.start)) – \(Fmt.clock(night.end))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .card(tint: Palette.sleep)
    }
}

/// Tarjeta pequeña: icono, valor grande y nombre.
struct MetricTile: View {
    var metric: Metric
    var value: String
    var day: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            MetricGlyph(symbol: metric.symbol, color: metric.color)
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(metric.unit).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }
            Text(metric.title).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(minHeight: 120, alignment: .topLeading)
        .card(padding: Space.l)
    }
}

#Preview {
    NavigationStack { TodayView() }
        .environment(HealthStore.preview())
        .fontDesign(.rounded)
        .preferredColorScheme(.dark)
}
