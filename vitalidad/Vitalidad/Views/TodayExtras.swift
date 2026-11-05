import SwiftUI
import Charts

/// Plan de hoy: esfuerzo que te conviene, pasos y hora de acostarte, con su progreso.
struct PlanCard: View {
    @Environment(HealthStore.self) private var store

    var body: some View {
        let goals = DayPlan.goals(store)
        if !goals.isEmpty {
            let done = goals.filter(\.done).count
            VStack(alignment: .leading, spacing: Space.l) {
                CardHeader("Plan de hoy", symbol: "target", color: Palette.recovery, trailing: "\(done) de \(goals.count)")
                ForEach(goals) { g in
                    HStack(spacing: Space.m) {
                        GoalRing(goal: g).frame(width: 44, height: 44)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(g.title).font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(g.value)
                                    .font(.system(.headline, design: .rounded).weight(.bold))
                                    .monospacedDigit()
                            }
                            Text(g.detail)
                                .font(.caption)
                                .foregroundStyle(g.done ? Palette.good : .secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .card()
        }
    }
}

struct GoalRing: View {
    var goal: DayPlan.Goal
    @State private var shown: Double = 0

    var body: some View {
        ZStack {
            Circle().stroke(goal.color.opacity(0.18), lineWidth: 4)
            Circle()
                .trim(from: 0, to: shown)
                .stroke(goal.done ? Palette.good : goal.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: goal.done ? "checkmark" : goal.symbol)
                .font(.footnote.weight(.bold))
                .foregroundStyle(goal.done ? Palette.good : goal.color)
                .contentTransition(.symbolEffect(.replace))
        }
        .onAppear { withAnimation(.spring(response: 1.1, dampingFraction: 0.9).delay(0.2)) { shown = goal.progress } }
        .onChange(of: goal.progress) { _, p in withAnimation(.smooth) { shown = p } }
    }
}

/// La batería del cuerpo: cuánta energía te queda y cómo ha ido el día.
struct EnergyCard: View {
    @Environment(HealthStore.self) private var store
    var date: Date = .now

    var body: some View {
        if let day = EnergyEngine.day(store, date) {
            let cal = Calendar.current
            let isToday = store.isToday(date)
            let start = cal.startOfDay(for: date)
            let end = cal.date(byAdding: .day, value: 1, to: start)!
            let tone = RGB.mix(RGB.readiness, day.now / 100).color
            VStack(alignment: .leading, spacing: Space.l) {
                CardHeader("Energía del cuerpo", symbol: "bolt.fill", color: tone,
                           trailing: "pico \(Int(day.peak.rounded())) %")
                HStack(alignment: .center, spacing: Space.l) {
                    BatteryGlyph(level: day.now / 100, color: tone)
                        .frame(width: 50, height: 84)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("\(Int(day.now.rounded()))")
                                .font(.system(size: 50, weight: .bold, design: .rounded))
                                .tracking(-1)
                                .contentTransition(.numericText())
                            Text("%").font(.title2.weight(.bold)).foregroundStyle(.secondary)
                        }
                        Text(isToday ? EnergyEngine.sentence(day.now) : "Cargaste hasta el \(Int(day.peak.rounded())) % y acabaste el día con el \(Int(day.now.rounded())) %.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Chart {
                    ForEach(day.points, id: \.date) { p in
                        AreaMark(x: .value("Hora", p.date), yStart: .value("Base", 0), yEnd: .value("Energía", p.value))
                            .foregroundStyle(LinearGradient(colors: [tone.opacity(0.4), tone.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.monotone)
                        LineMark(x: .value("Hora", p.date), y: .value("Energía", p.value))
                            .foregroundStyle(LinearGradient(colors: [Palette.recovery, Color(red: 1, green: 0.72, blue: 0.26), Palette.heart], startPoint: .top, endPoint: .bottom))
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                            .interpolationMethod(.monotone)
                    }
                    if let last = day.points.last {
                        PointMark(x: .value("Hora", last.date), y: .value("Energía", last.value))
                            .foregroundStyle(tone)
                            .symbolSize(70)
                    }
                    if let w = day.wake {
                        RuleMark(x: .value("Despertar", w))
                            .foregroundStyle(.secondary.opacity(0.45))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            .annotation(position: .top, spacing: 2) {
                                Image(systemName: "sun.max.fill").font(.caption2).foregroundStyle(.yellow)
                            }
                    }
                }
                .chartXScale(domain: start...end)
                .chartYScale(domain: 0...105)
                .chartYAxis {
                    AxisMarks(position: .trailing, values: [0, 50, 100]) { _ in
                        AxisGridLine().foregroundStyle(.secondary.opacity(0.15))
                        AxisValueLabel().font(.caption2)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: (0...4).map { cal.date(byAdding: .hour, value: $0 * 6, to: start)! }) { v in
                        AxisValueLabel {
                            if let d = v.as(Date.self) { Text(Fmt.clock(d)).font(.caption2) }
                        }
                    }
                }
                .frame(height: 130)
            }
            .card(tint: tone)
        }
    }
}

/// Una pila dibujada que se llena desde abajo.
struct BatteryGlyph: View {
    var level: Double
    var color: Color
    @State private var shown: Double = 0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let cap = h * 0.07
            let shell = RoundedRectangle(cornerRadius: w * 0.26, style: .continuous)
            VStack(spacing: 2) {
                RoundedRectangle(cornerRadius: 2).fill(Ink.track).frame(width: w * 0.4, height: cap)
                ZStack(alignment: .bottom) {
                    shell.fill(Ink.track.opacity(0.5))
                    shell
                        .fill(LinearGradient(colors: [color, color.opacity(0.65)], startPoint: .top, endPoint: .bottom))
                        .frame(height: max(6, (h - cap - 2) * shown))
                        .padding(3)
                        .shadow(color: color.opacity(0.6), radius: 8)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: w * 0.36, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(maxHeight: .infinity)
                }
                .clipShape(shell)
                .overlay(shell.strokeBorder(Ink.hairline.opacity(0.15), lineWidth: 1))
            }
        }
        .onAppear { withAnimation(.spring(response: 1.3, dampingFraction: 0.85).delay(0.2)) { shown = level } }
        .onChange(of: level) { _, v in withAnimation(.smooth) { shown = v } }
        .accessibilityHidden(true)
    }
}

/// Franja de estrés hora a hora.
struct StressStrip: View {
    var hours: [StressEngine.Hour]
    var start: Date
    var end: Date

    static func color(_ l: Int) -> Color {
        switch l {
        case -2: Palette.effort.opacity(0.4)
        case -1: Palette.sleep.opacity(0.45)
        case 0: Palette.breath.opacity(0.35)
        case 1: Color(red: 1, green: 0.82, blue: 0.35).opacity(0.75)
        case 2: Palette.effort
        default: Palette.heart
        }
    }

    static func summary(_ hours: [StressEngine.Hour]) -> String {
        let awake = hours.filter { $0.level >= 0 }
        guard !awake.isEmpty else { return "" }
        let high = awake.filter { $0.level >= 2 }.count
        let some = awake.filter { $0.level >= 1 }.count
        if high >= 3 { return "Estrés alto" }
        if high >= 1 || Double(some) / Double(awake.count) > 0.5 { return "Estrés medio" }
        return "Estrés bajo"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("POR HORAS").font(.system(size: 10, weight: .heavy)).tracking(1).foregroundStyle(.secondary)
                Spacer()
                if hours.contains(where: { $0.level == -2 }) {
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2).fill(Self.color(-2)).frame(width: 8, height: 8)
                        Text("Trabajo").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    }
                }
            }
            Chart(hours) { s in
                BarMark(x: .value("Hora", s.date, unit: .hour), yStart: .value("Bajo", 0), yEnd: .value("Alto", 1), width: .ratio(0.8))
                    .foregroundStyle(Self.color(s.level))
                    .cornerRadius(3)
            }
            .chartXScale(domain: start...end)
            .chartYScale(domain: 0...1)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 14)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.summary(hours))
    }
}

/// Fondo que respira despacio detrás del medidor grande.
struct BreathingGlow: View {
    var color: Color
    @State private var on = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Circle()
            .fill(RadialGradient(colors: [color.opacity(0.42), color.opacity(0.08), .clear], center: .center, startRadius: 0, endRadius: 150))
            .scaleEffect(on ? 1.1 : 0.88)
            .opacity(on ? 1 : 0.55)
            .onAppear {
                guard !reduceMotion else { on = true; return }
                withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true)) { on = true }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
