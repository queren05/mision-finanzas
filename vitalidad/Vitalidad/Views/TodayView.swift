import SwiftUI
import Charts

struct TodayView: View {
    @Environment(HealthStore.self) private var store
    @State private var settings = Launch.args.contains("-settings")
    @Binding var opened: Metric?
    @State private var widgets = Launch.args.contains("-widgets")
    @State private var personalize = Launch.args.contains("-personalizar")
    @Namespace private var zoom
    @AppStorage("hoyEstilo") private var style = TodayStyle(rawValue: Launch.value("-estilo") ?? "") ?? .grid
    @AppStorage("hoyTarjetas") private var cardsRaw = TodayCards.defaultString
    @AppStorage("hoyResumen") private var showSummary = true
    @AppStorage("hoyPuntuaciones") private var showScores = true

    @AppStorage("hoyDia") private var showDay = true
    @AppStorage("hoySenales") private var showSignals = true
    @AppStorage("hoyPlan") private var showPlan = true
    @AppStorage("hoyEnergia") private var showEnergy = true
    @AppStorage("hoyEstres") private var showStress = true
    @AppStorage("hoyEdad") private var showAge = true
    @AppStorage("hoyJornada") private var showWork = true
    @AppStorage("hoyCrono") private var showTimeline = true
    @State private var coach = Launch.args.contains("-entrenador")
    @State private var day: Date = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: -(Int(Launch.value("-dia") ?? "") ?? 0), to: .now)!)

    var body: some View {
        let isToday = store.isToday(day)
        let report = ScoreEngine.report(store, day: day)
        let insights = isToday ? TodayCards.decode(cardsRaw).compactMap { Explainer.insight($0, store: store) } : []
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                DayStrip(selected: $day)
                    .padding(.horizontal, -Space.s)
                    .padding(.top, -Space.s)

                HStack {
                    Text(Fmt.day(day, style: "EEEE, d 'de' MMMM").uppercased())
                        .font(.caption.weight(.bold))
                        .tracking(1.1)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !isToday {
                        Button {
                            withAnimation(.snappy) { day = store.today }
                        } label: {
                            Label("Hoy", systemImage: "arrow.uturn.forward")
                                .font(.caption.weight(.bold))
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.horizontal, Space.xs)

                if showScores && !report.scores.isEmpty {
                    ReadinessHero(report: report, showSummary: showSummary).stagger(0)
                } else if showSummary {
                    Text(report.summary)
                        .font(.title3.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, Space.xs)
                        .stagger(0)
                }

                if isToday && showAge {
                    BioAgeTile().stagger(1)
                }

                if isToday && showPlan {
                    PlanCard().stagger(1).scrollFade()
                }

                if showEnergy {
                    EnergyCard(date: day).stagger(1).scrollFade().id("energia")
                }

                if showWork {
                    WorkCard(day: day).stagger(2).scrollFade().id("jornada")
                }

                if showStress {
                    StressCard(day: day).stagger(2).scrollFade().id("estres")
                }

                if showTimeline {
                    TimelineCard(day: day).stagger(2).scrollFade().id("crono")
                }

                if showDay {
                    DayTimelineCard(day: day).stagger(2).scrollFade()
                }

                if isToday && showSignals {
                    SignalsCard(zoom: zoom).stagger(3).scrollFade()
                }

                if !insights.isEmpty {
                    SectionTitle(title: "Tus datos").stagger(3)
                }
                cards(insights)

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
        .onAppear {
            if let f = Launch.value("-foco") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { proxy.scrollTo(f, anchor: .top) }
            }
        }
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
            ToolbarItemGroup(placement: .topBarLeading) {
                NavigationLink { TrendsView() } label: { Image(systemName: "chart.xyaxis.line") }
                    .accessibilityLabel("Tendencias")
                Button { coach = true } label: { Image(systemName: "sparkles") }
                    .accessibilityLabel("Entrenador")
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { personalize = true } label: { Image(systemName: "slider.horizontal.3") }
                    .accessibilityLabel("Personalizar Hoy")
                Button { settings = true } label: { Image(systemName: "gearshape") }
                    .accessibilityLabel("Ajustes")
            }
        }
        .sheet(isPresented: $settings) { SettingsView() }
        .sheet(isPresented: $personalize) { PersonalizeTodayView() }
        .sheet(isPresented: $coach) { CoachView() }
        .sheet(isPresented: $widgets) { NavigationStack { WidgetsGalleryView() } }
        .animation(.snappy, value: style)
    }

    @ViewBuilder
    private func cards(_ insights: [Insight]) -> some View {
        switch style {
        case .cards:
            ForEach(Array(insights.enumerated()), id: \.element.id) { i, ins in
                NavigationLink(value: ins.metric) {
                    InsightCard(insight: ins).zoomSource(ins.metric, zoom)
                }
                .buttonStyle(.plain)
                .stagger(i + 4)
                .scrollFade()
            }
        case .grid:
            LazyVGrid(columns: [GridItem(.flexible(), spacing: Space.m), GridItem(.flexible(), spacing: Space.m)], spacing: Space.m) {
                ForEach(Array(insights.enumerated()), id: \.element.id) { i, ins in
                    NavigationLink(value: ins.metric) {
                        GridTile(insight: ins).zoomSource(ins.metric, zoom)
                    }
                    .buttonStyle(.plain)
                    .stagger(i + 4)
                }
            }
        case .grouped:
            // Los módulos salen en el orden en que aparece su primera métrica.
            let groups = insights.map(\.metric.group).reduce(into: [MetricGroup]()) { if !$0.contains($1) { $0.append($1) } }
            ForEach(Array(groups.enumerated()), id: \.element) { i, g in
                GroupCard(group: g, insights: insights.filter { $0.metric.group == g }, zoom: zoom)
                    .stagger(i + 4)
                    .scrollFade()
            }
        }
    }
}

/// Lo primero que se ve: los tres anillos (esfuerzo, recuperación y sueño) y el resumen.
struct ReadinessHero: View {
    var report: DayReport
    var showSummary: Bool
    @Environment(\.openURL) private var openURL

    var body: some View {
        let order: [Score.Kind] = [.effort, .recovery, .sleep]
        let rings = order.map { k in report.scores.first { $0.kind == k } }
        let main = report.recovery ?? report.sleep ?? report.effort
        VStack(spacing: Space.l) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(order.enumerated()), id: \.offset) { i, k in
                    Button {
                        switch k {
                        case .effort: openURL(URL(string: "vitalidad://tab/activity")!)
                        case .sleep: openURL(URL(string: "vitalidad://tab/sleep")!)
                        case .recovery: openURL(URL(string: "vitalidad://detalle/hrv")!)
                        }
                    } label: {
                        ScoreRing(kind: k, score: rings[i], big: k == .recovery)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                }
            }
            if let main {
                Text(main.verdict)
                    .font(.headline)
                    .foregroundStyle(main.tone)
            }
            if showSummary {
                Text(report.summary)
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, Space.xs)
            }
        }
        .card(padding: 20, radius: 30, tint: main?.tone)
    }
}

/// Un anillo grueso con el número dentro y el nombre debajo.
struct ScoreRing: View {
    var kind: Score.Kind
    var score: Score?
    var big = false
    @State private var shown: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var title: String {
        switch kind {
        case .recovery: "Recuperación"
        case .sleep: "Sueño"
        case .effort: "Esfuerzo"
        }
    }

    private var base: Color {
        switch kind {
        case .recovery: Palette.recovery
        case .sleep: Palette.sleep
        case .effort: Palette.effort
        }
    }

    var body: some View {
        let size: CGFloat = big ? 112 : 92
        let line: CGFloat = big ? 12 : 10
        let colors = score?.scale.map(\.color) ?? [base]
        let tone = score?.tone ?? base
        VStack(spacing: Space.s) {
            ZStack {
                Circle().stroke(base.opacity(0.16), lineWidth: line)
                Circle()
                    .trim(from: 0, to: shown)
                    .stroke(AngularGradient(colors: colors + [colors.last!], center: .center, startAngle: .degrees(0), endAngle: .degrees(360 * max(shown, 0.01))),
                            style: StrokeStyle(lineWidth: line, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: tone.opacity(0.45), radius: 6)
                VStack(spacing: -2) {
                    if let score {
                        CountingNumber(value: score.value)
                            .font(.system(size: big ? 36 : 28, weight: .bold, design: .rounded))
                        Text("%").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                    } else {
                        Text("—").font(.title2.weight(.bold)).foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: size, height: size)
            .padding(line / 2)
            Text(title.uppercased())
                .font(.system(size: 10, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(height: 150, alignment: .bottom)
        .onAppear { go(score.map { Double($0.value) / 100 } ?? 0, 0.15) }
        .onChange(of: score?.value) { _, v in go(Double(v ?? 0) / 100, 0) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(score.map { "\(title): \($0.value) de 100" } ?? "\(title): sin datos")
    }

    private func go(_ v: Double, _ delay: Double) {
        if reduceMotion { shown = v; return }
        withAnimation(.spring(response: 1.2, dampingFraction: 0.85).delay(delay)) { shown = v }
    }
}

/// El pulso hora a hora de hoy, con la noche y los entrenos marcados, y los pasos debajo.
struct DayTimelineCard: View {
    @Environment(HealthStore.self) private var store
    var day: Date = .now

    var body: some View {
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        let hr = store.dayHours(start).hr.filter { $0.value > 0 }
        let steps = store.dayHours(start).steps
        let totalSteps = steps.reduce(0) { $0 + $1.value }
        if hr.count >= 3 {
            let lo = max(30, (hr.map(\.value).min() ?? 50) - 8)
            let hi = (hr.map(\.value).max() ?? 120) + 8
            let night = store.night(for: start).flatMap { n -> (Date, Date)? in
                n.end > start ? (max(n.start, start), n.end) : nil
            }
            let training = store.workouts.filter { $0.end > start && $0.start < end }
            VStack(alignment: .leading, spacing: Space.m) {
                CardHeader("Tu día", symbol: "waveform.path.ecg", color: Palette.heart,
                           trailing: "\(Fmt.number(hr.map(\.value).min() ?? 0))–\(Fmt.number(hr.map(\.value).max() ?? 0)) lpm")
                Chart {
                    if let night {
                        RectangleMark(xStart: .value("Desde", night.0), xEnd: .value("Hasta", night.1),
                                      yStart: .value("Bajo", lo), yEnd: .value("Alto", hi))
                            .foregroundStyle(Palette.sleep.opacity(0.16))
                            .cornerRadius(6)
                    }
                    ForEach(training) { w in
                        RectangleMark(xStart: .value("Desde", max(w.start, start)), xEnd: .value("Hasta", w.end),
                                      yStart: .value("Bajo", lo), yEnd: .value("Alto", hi))
                            .foregroundStyle(Palette.effort.opacity(0.22))
                            .cornerRadius(4)
                    }
                    ForEach(hr, id: \.date) { p in
                        AreaMark(x: .value("Hora", p.date), yStart: .value("Base", lo), yEnd: .value("Pulso", p.value))
                            .foregroundStyle(LinearGradient(colors: [Palette.heart.opacity(0.35), Palette.heart.opacity(0)], startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.catmullRom)
                        LineMark(x: .value("Hora", p.date), y: .value("Pulso", p.value))
                            .foregroundStyle(Palette.heart)
                            .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                            .interpolationMethod(.catmullRom)
                    }
                    if let last = hr.last {
                        PointMark(x: .value("Hora", last.date), y: .value("Pulso", last.value))
                            .foregroundStyle(Palette.heart)
                            .symbolSize(50)
                    }
                }
                .chartXScale(domain: start...end)
                .chartYScale(domain: lo...hi)
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                        AxisGridLine().foregroundStyle(.secondary.opacity(0.15))
                        AxisValueLabel().font(.caption2)
                    }
                }
                .frame(height: 120)

                if totalSteps > 0 {
                    Chart(steps, id: \.date) { p in
                        BarMark(x: .value("Hora", p.date, unit: .hour), y: .value("Pasos", p.value), width: .ratio(0.7))
                            .foregroundStyle(Palette.effort.opacity(0.85))
                            .cornerRadius(2)
                    }
                    .chartXScale(domain: start...end)
                    .chartYAxis(.hidden)
                    .chartXAxis {
                        AxisMarks(values: (0...4).map { cal.date(byAdding: .hour, value: $0 * 6, to: start)! }) { v in
                            AxisValueLabel {
                                if let d = v.as(Date.self) { Text(Fmt.clock(d)).font(.caption2) }
                            }
                        }
                    }
                    .frame(height: 50)
                }

                HStack(spacing: Space.l) {
                    legend(Palette.heart, "Pulso")
                    if night != nil { legend(Palette.sleep, "Sueño") }
                    if !training.isEmpty { legend(Palette.effort, "Entreno") }
                    Spacer()
                    if totalSteps > 0 {
                        Text("\(Fmt.number(totalSteps)) pasos")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
            .card()
        }
    }

    private func legend(_ c: Color, _ t: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(c).frame(width: 10, height: 10)
            Text(t).font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// Las señales del cuerpo frente a tu rango normal: un punto en una pista por cada una.
struct SignalsCard: View {
    var zoom: Namespace.ID
    @Environment(HealthStore.self) private var store

    private let metrics: [Metric] = [.hrv, .restingHR, .respiratoryRate, .sleep, .walkingHR]

    var body: some View {
        let rows = metrics.compactMap { Explainer.insight($0, store: store) }.filter { $0.baseline != nil }
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: Space.l) {
                CardHeader("Frente a tu normal", symbol: "scope", color: Palette.recovery)
                ForEach(rows) { ins in
                    NavigationLink(value: ins.metric) {
                        SignalRow(insight: ins)
                    }
                    .buttonStyle(.plain)
                    .zoomSource(ins.metric, zoom)
                }
            }
            .card()
        }
    }
}

struct SignalRow: View {
    var insight: Insight

    var body: some View {
        let m = insight.metric
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                Image(systemName: m.symbol)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(m.color)
                    .frame(width: 20)
                Text(m.title).font(.subheadline.weight(.medium))
                Spacer(minLength: Space.s)
                Text(insight.display)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .monospacedDigit()
                if !m.unit.isEmpty {
                    Text(m.unit).font(.caption).foregroundStyle(.secondary)
                }
            }
            if let b = insight.baseline {
                RangeBar(value: insight.value, baseline: b, color: m.color, status: insight.status)
                HStack {
                    Text("Normal \(Fmt.value(m, max(0, b.low)))–\(Fmt.full(m, b.high))")
                    Spacer()
                    DeltaChip(insight: insight)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
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

/// Tarjeta de una métrica: valor, diferencia con lo normal, siete días en pequeño y su frase.
struct InsightCard: View {
    var insight: Insight
    @Environment(HealthStore.self) private var store

    var body: some View {
        let m = insight.metric
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(spacing: 6) {
                Image(systemName: m.symbol).font(.caption.weight(.bold)).foregroundStyle(m.color)
                Text(m.title.uppercased()).font(.caption.weight(.bold)).tracking(1.1).foregroundStyle(.secondary)
                Spacer()
                StatusPill(status: insight.status)
            }
            HStack(alignment: .bottom, spacing: Space.m) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(insight.display)
                            .bigFont(40)
                            .contentTransition(.numericText())
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                        Text(m.unit).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    }
                    DeltaChip(insight: insight)
                }
                .layoutPriority(1)
                Spacer(minLength: 0)
                Sparkline(metric: m, points: store.series(m, days: 7))
                    .frame(width: 112, height: 50)
            }
            Text(insight.sentence)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Abre la gráfica y la explicación")
    }
}

#Preview {
    NavigationStack { TodayView(opened: .constant(nil)) }
        .environment(HealthStore.preview())
                .preferredColorScheme(.dark)
}
