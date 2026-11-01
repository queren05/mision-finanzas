import SwiftUI

/// Cómo se reparten las tarjetas de Hoy.
enum TodayStyle: String, CaseIterable, Identifiable {
    case cards, grid, grouped
    var id: String { rawValue }

    var title: String {
        switch self {
        case .cards: "Grandes"
        case .grid: "Cuadrícula"
        case .grouped: "Agrupadas"
        }
    }

    var symbol: String {
        switch self {
        case .cards: "rectangle.grid.1x2.fill"
        case .grid: "square.grid.2x2.fill"
        case .grouped: "list.bullet.rectangle.fill"
        }
    }
}

/// Qué tarjetas salen en Hoy y en qué orden (se guarda como «steps,hrv,…»).
enum TodayCards {
    static let available: [Metric] = [
        .steps, .activeEnergy, .exerciseMinutes, .standHours,
        .restingHR, .hrv, .respiratoryRate, .walkingHR, .vo2max,
        .sleep, .weight, .calories, .protein, .water,
    ]
    static let defaults: [Metric] = [.steps, .activeEnergy, .exerciseMinutes, .standHours, .calories, .vo2max]
    static let defaultString = defaults.map(\.rawValue).joined(separator: ",")

    static func decode(_ s: String) -> [Metric] { s.split(separator: ",").compactMap { Metric(rawValue: String($0)) } }
    static func encode(_ m: [Metric]) -> String { m.map(\.rawValue).joined(separator: ",") }
}

/// Familias para el modo agrupado: varias métricas en un solo módulo.
enum MetricGroup: String, CaseIterable {
    case activity, heart, sleep, body, nutrition

    var title: String {
        switch self {
        case .activity: "Actividad"
        case .heart: "Corazón"
        case .sleep: "Sueño"
        case .body: "Cuerpo"
        case .nutrition: "Nutrición"
        }
    }

    var symbol: String {
        switch self {
        case .activity: "flame.fill"
        case .heart: "heart.fill"
        case .sleep: "moon.zzz.fill"
        case .body: "figure"
        case .nutrition: "fork.knife"
        }
    }

    var color: Color {
        switch self {
        case .activity: Palette.effort
        case .heart: Palette.heart
        case .sleep: Palette.sleep
        case .body: Palette.body
        case .nutrition: Palette.nutrition
        }
    }
}

extension Metric {
    var group: MetricGroup {
        switch self {
        case .steps, .activeEnergy, .basalEnergy, .exerciseMinutes, .standHours: .activity
        case .heartRate, .restingHR, .hrv, .respiratoryRate, .vo2max, .walkingHR: .heart
        case .sleep: .sleep
        case .weight: .body
        case .calories, .protein, .carbs, .fat, .water: .nutrition
        }
    }
}

// MARK: - Módulos compactos

/// Cuadrícula: valor, diferencia con lo normal y siete días en pequeño, sin frase.
struct GridTile: View {
    var insight: Insight
    @Environment(HealthStore.self) private var store

    var body: some View {
        let m = insight.metric
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(spacing: 5) {
                Image(systemName: m.symbol).font(.caption.weight(.bold)).foregroundStyle(m.color)
                Text(m.title).font(.footnote.weight(.semibold)).foregroundStyle(.secondary).lineLimit(1)
                Spacer(minLength: 2)
                Circle().fill(insight.status.color).frame(width: 7, height: 7)
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(insight.display)
                    .bigFont(28)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(m.unit).font(.caption.weight(.semibold)).foregroundStyle(.secondary).lineLimit(1)
            }
            .padding(.top, 2)
            Sparkline(metric: m, points: store.series(m, days: 7))
                .frame(height: 34)
            DeltaChip(insight: insight)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(minHeight: 150, alignment: .topLeading)
        .card(padding: Space.l, radius: 24)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(m.title): \(insight.display) \(m.unit), \(insight.status.title)")
    }
}

/// Agrupado: varias métricas de la misma familia en un módulo, con la frase de la más importante.
struct GroupCard: View {
    var group: MetricGroup
    var insights: [Insight]
    var zoom: Namespace.ID

    /// Lo que más merece contarse: primero lo que pide atención, luego lo bueno.
    private var headline: Insight? {
        insights.first { $0.status == .attention } ?? insights.first { $0.status == .good } ?? insights.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            CardHeader(group.title, symbol: group.symbol, color: group.color)
            VStack(spacing: 0) {
                ForEach(insights) { ins in
                    NavigationLink(value: ins.metric) {
                        HStack(spacing: Space.m) {
                            Image(systemName: ins.metric.symbol)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(ins.metric.color)
                                .frame(width: 24)
                            Text(ins.metric.title).font(.subheadline)
                            Spacer(minLength: Space.s)
                            Text(ins.display).font(.system(.headline, design: .rounded).weight(.bold)).monospacedDigit()
                            Text(ins.metric.unit).font(.caption).foregroundStyle(.secondary)
                            Circle().fill(ins.status.color).frame(width: 8, height: 8)
                        }
                        .padding(.vertical, Space.s + 2)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .zoomSource(ins.metric, zoom)
                    if ins.id != insights.last?.id { Divider().opacity(0.4) }
                }
            }
            if let h = headline {
                Text(h.sentence)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .card()
    }
}

// MARK: - Personalizar

struct PersonalizeTodayView: View {
    @AppStorage("hoyEstilo") private var style = TodayStyle.grid
    @AppStorage("hoyTarjetas") private var cardsRaw = TodayCards.defaultString
    @AppStorage("hoyResumen") private var showSummary = true
    @AppStorage("hoyPuntuaciones") private var showScores = true
    @AppStorage("hoyDia") private var showDay = true
    @AppStorage("hoySenales") private var showSignals = true
    @Environment(\.dismiss) private var dismiss

    private var shown: [Metric] { TodayCards.decode(cardsRaw) }
    private var hidden: [Metric] { TodayCards.available.filter { !shown.contains($0) } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: Space.m) {
                        ForEach(TodayStyle.allCases) { s in
                            Button {
                                withAnimation(.snappy) { style = s }
                            } label: {
                                VStack(spacing: Space.s) {
                                    Image(systemName: s.symbol).font(.title2)
                                    Text(s.title).font(.caption.weight(.semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Space.m)
                                .foregroundStyle(style == s ? Color.accentColor : .secondary)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(style == s ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                } header: {
                    Text("Estilo")
                }

                Section("Arriba") {
                    Toggle("Resumen del día", isOn: $showSummary)
                    Toggle("Puntuaciones", isOn: $showScores)
                    Toggle("Tu día", isOn: $showDay)
                    Toggle("Frente a tu normal", isOn: $showSignals)
                }

                Section("En Hoy") {
                    ForEach(shown) { m in
                        HStack(spacing: Space.m) {
                            MetricGlyph(symbol: m.symbol, color: m.color, size: 28)
                            Text(m.title)
                            Spacer()
                            Button {
                                withAnimation { cardsRaw = TodayCards.encode(shown.filter { $0 != m }) }
                            } label: {
                                Image(systemName: "minus.circle.fill").font(.title3).foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Quitar \(m.title)")
                        }
                    }
                    .onMove { from, to in
                        var list = shown
                        list.move(fromOffsets: from, toOffset: to)
                        cardsRaw = TodayCards.encode(list)
                    }
                }

                if !hidden.isEmpty {
                    Section("Sin mostrar") {
                        ForEach(hidden) { m in
                            Button {
                                withAnimation { cardsRaw = TodayCards.encode(shown + [m]) }
                            } label: {
                                HStack(spacing: Space.m) {
                                    MetricGlyph(symbol: m.symbol, color: m.color, size: 28)
                                    Text(m.title).foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "plus.circle.fill").font(.title3).foregroundStyle(Palette.good)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section {
                    Button("Volver a lo de antes") {
                        withAnimation {
                            style = .grid
                            cardsRaw = TodayCards.defaultString
                            showSummary = true
                            showScores = true
                            showDay = true
                            showSignals = true
                        }
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .scrollContentBackground(.hidden)
            .background(MoodBackground(mood: .neutral))
            .navigationTitle("Personalizar Hoy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
            .sensoryFeedback(.selection, trigger: style)
        }
    }
}

#Preview {
    PersonalizeTodayView().fontDesign(.rounded).preferredColorScheme(.dark)
}
