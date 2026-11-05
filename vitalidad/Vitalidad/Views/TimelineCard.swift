import SwiftUI

/// Cronología del día: cuándo dormiste, trabajaste, entrenaste y tuviste estrés, en orden.
struct TimelineCard: View {
    @Environment(HealthStore.self) private var store
    var day: Date

    struct Event: Identifiable {
        var time: Date
        var end: Date?
        var symbol: String
        var color: Color
        var title: String
        var detail: String?
        var id: String { "\(time.timeIntervalSince1970)\(title)" }
    }

    var body: some View {
        let events = make()
        let notes = Journal.shared.entry(day)
        if !events.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                CardHeader("Cronología", symbol: "list.bullet.below.rectangle", color: Palette.breath)
                    .padding(.bottom, Space.l)
                ForEach(Array(events.enumerated()), id: \.element.id) { i, e in
                    HStack(alignment: .top, spacing: Space.m) {
                        Text(Fmt.clock(e.time))
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 42, alignment: .trailing)
                            .padding(.top, 6)
                        VStack(spacing: 0) {
                            ZStack {
                                Circle().fill(e.color.opacity(0.18))
                                Image(systemName: e.symbol).font(.caption.weight(.bold)).foregroundStyle(e.color)
                            }
                            .frame(width: 28, height: 28)
                            if i < events.count - 1 {
                                Rectangle().fill(Ink.hairline.opacity(0.12)).frame(width: 2).frame(minHeight: 16, maxHeight: .infinity)
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(e.title).font(.subheadline.weight(.semibold))
                            if let d = e.detail {
                                Text(d).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, 4)
                        .padding(.bottom, Space.l)
                        Spacer(minLength: 0)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                if !notes.isEmpty {
                    let items = notes.sorted { $0.key < $1.key }.compactMap { item -> String? in
                        guard let h = Habit.by(item.key) else { return nil }
                        return h.counted ? "\(h.title) \(item.value)" : h.title
                    }
                    HStack(alignment: .top, spacing: Space.s) {
                        Image(systemName: "book.closed.fill").font(.caption).foregroundStyle(Palette.recovery)
                        Text(items.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.top, Space.xs)
                }
            }
            .card()
        }
    }

    private func make() -> [Event] {
        let cal = Calendar.current
        let start = store.dayStart(day)
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        var out: [Event] = []
        if let n = store.night(for: start) {
            out.append(Event(time: n.start, symbol: "moon.fill", color: Palette.sleep, title: "Te dormiste",
                             detail: "\(Fmt.duration(n.asleep)) de sueño"))
            out.append(Event(time: n.end, symbol: "sun.max.fill", color: Color(red: 1, green: 0.78, blue: 0.25), title: "Te despertaste",
                             detail: ScoreEngine.report(store, day: start).recovery.map { "Recuperación \($0.value) %" }))
        }
        let work = WorkSchedule.current
        if work.isWorkDay(start) {
            let a = cal.date(byAdding: .hour, value: work.from, to: start)!
            let b = cal.date(byAdding: .hour, value: work.to, to: start)!
            if a <= .now {
                let load = HeartLoad.points(store, day: start, onlyWork: true)
                out.append(Event(time: a, end: b, symbol: work.kind.symbol, color: Palette.effort, title: "Jornada",
                                 detail: load.map { "Carga física \(HeartLoad.level($0).0.lowercased())" }))
            }
            if b <= .now {
                out.append(Event(time: b, symbol: "figure.walk.departure", color: Palette.effort, title: "Fin de la jornada", detail: nil))
            }
        }
        for w in store.workouts where w.start >= start && w.start < end {
            var d = [Fmt.duration(w.duration)]
            if let e = w.energy { d.append(Fmt.full(.activeEnergy, e)) }
            if let hr = w.avgHR { d.append("\(Fmt.number(hr)) lpm") }
            out.append(Event(time: w.start, end: w.end, symbol: w.symbol, color: Palette.effort, title: w.name, detail: d.joined(separator: " · ")))
        }
        // Rachas de estrés alto (dos o más niveles seguidos).
        let hours = StressEngine.hours(store, day: start)
        var run: [StressEngine.Hour] = []
        func flush() {
            if let f = run.first, let l = run.last {
                let to = cal.date(byAdding: .hour, value: 1, to: l.date)!
                out.append(Event(time: f.date, end: to, symbol: "bolt.heart.fill", color: Palette.heart, title: "Estrés alto",
                                 detail: "\(Fmt.clock(f.date))–\(Fmt.clock(to))"))
            }
            run = []
        }
        for h in hours {
            if h.level >= 2 { run.append(h) } else { flush() }
        }
        flush()
        // El momento con más energía.
        if let e = EnergyEngine.day(store, start), let top = e.points.max(by: { $0.value < $1.value }), top.value >= 30 {
            out.append(Event(time: top.date, symbol: "bolt.fill", color: Palette.recovery, title: "Batería al \(Int(top.value.rounded())) %", detail: "Lo más alto del día"))
        }
        return out.filter { $0.time >= start.addingTimeInterval(-6 * 3600) && $0.time < end }.sorted { $0.time < $1.time }
    }
}
