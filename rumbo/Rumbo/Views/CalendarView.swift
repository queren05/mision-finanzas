import SwiftUI

/// día que se abre en el calendario
struct CalDay: Hashable { var day: String }

/// una cosa que pasa un día: evento del iPhone, tarea, vencimiento, recibo o chequeo
struct CalEntry: Identifiable {
    enum Kind: Int { case event, task, due, receipt, checkIn }
    var id: String
    var kind: Kind
    var title: String
    var detail: String = ""
    var color: Color
    var task: TaskItem? = nil
    var doc: BrainDoc? = nil

    static func color(_ k: Kind) -> Color {
        switch k {
        case .event: Color(hex: "#7ac8ff")
        case .task: Color(hex: "#f0c46a")
        case .due: Color(hex: "#ff8686")
        case .receipt: Color(hex: "#62cfd0")
        case .checkIn: Color(hex: "#b39cff")
        }
    }
}

extension Store {
    /// todo lo que hay un día (los eventos del iPhone se pasan ya cargados)
    func entries(_ day: String, events: [AgendaEvent]) -> [CalEntry] {
        var out: [CalEntry] = []
        let start = Calendar.current.startOfDay(for: Day.date(day))
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        for e in events where e.start < end && e.end > start {
            out.append(CalEntry(id: "e" + e.id, kind: .event, title: e.title,
                                detail: e.allDay ? "Todo el día" : "\(Day.time(e.start)) – \(Day.time(e.end))", color: e.color))
        }
        for t in s.tasks where t.due == day {
            out.append(CalEntry(id: "t" + t.id, kind: .task, title: t.title, detail: t.priority ? "Prioridad" : "Tarea", color: CalEntry.color(.task), task: t))
        }
        for d in s.docs {
            if d.due == day {
                out.append(CalEntry(id: "v" + d.id, kind: .due, title: d.title, detail: "Vence" + (d.amount.map { " · " + Money.eur($0) } ?? ""), color: CalEntry.color(.due), doc: d))
            }
            if d.docDate == day {
                out.append(CalEntry(id: "r" + d.id, kind: .receipt, title: d.title,
                                    detail: d.folder.label + (d.amount.map { " · " + Money.eur($0) } ?? ""), color: CalEntry.color(.receipt), doc: d))
            }
        }
        if let c = s.checkIns.first(where: { $0.date == day }), !c.text.isEmpty || !c.wins.isEmpty {
            out.append(CalEntry(id: "c" + day, kind: .checkIn, title: "Chequeo nocturno", detail: (["😞", "😕", "😐", "🙂", "😄"][max(0, min(4, c.mood - 1))]) + " " + c.wins.prefix(2).joined(separator: " · "),
                                color: CalEntry.color(.checkIn)))
        }
        return out
    }
}

struct CalendarView: View {
    @Environment(Store.self) private var store
    @State private var selected: String
    @State private var month: String
    @State private var events: [AgendaEvent] = []
    @State private var newTask: TaskItem? = nil
    @State private var forward = true

    init(day: String) {
        _selected = State(initialValue: day)
        _month = State(initialValue: Day.monthStart(day))
    }

    private var gridStart: String { Store.weekStart(month) }
    private var gridDays: [String] {
        let next = Day.add(month, months: 1)
        var days: [String] = []; var d = gridStart
        while d < next || days.count % 7 != 0 { days.append(d); d = Day.add(d, days: 1) }
        return days
    }

    var body: some View {
        let days = gridDays
        let byDay = Dictionary(uniqueKeysWithValues: days.map { ($0, store.entries($0, events: events)) })
        ScrollView {
            VStack(spacing: 16) {
                monthHeader
                VStack(spacing: 6) {
                    HStack(spacing: 0) {
                        ForEach(["L", "M", "X", "J", "V", "S", "D"], id: \.self) { Text($0).font(.caption.weight(.bold)).foregroundStyle(.secondary).frame(maxWidth: .infinity) }
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
                        ForEach(days, id: \.self) { d in cell(d, byDay[d] ?? []) }
                    }
                    .id(month)
                    .transition(.asymmetric(insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity), removal: .opacity))
                }
                .card(12)
                .gesture(DragGesture(minimumDistance: 30).onEnded { v in
                    if v.translation.width < -50 { move(1) } else if v.translation.width > 50 { move(-1) }
                })
                legend
                dayList(byDay[selected] ?? store.entries(selected, events: events))
                Color.clear.frame(height: 30)
            }
            .padding(.horizontal, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Calendario").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Hoy") { Haptic.select(); forward = Day.today >= selected; withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { selected = Day.today; month = Day.monthStart(Day.today) } }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { newTask = TaskItem(title: "", due: selected) } label: { Image(systemName: "plus") }
            }
        }
        .sheet(item: $newTask) { TaskEditor(original: $0) }
        .task(id: month) {
            if store.agenda.isEmpty && !store.calendarDenied { await store.loadAgenda() }
            events = store.events(from: gridStart, to: Day.add(Day.add(month, months: 1), days: 7))
        }
    }

    private var monthHeader: some View {
        let total = store.s.docs.filter { Day.monthKey($0.docDate) == Day.monthKey(month) }.compactMap(\.amount).reduce(0, +)
        return HStack {
            Button { move(-1) } label: { Image(systemName: "chevron.left.circle.fill").font(.title) }
            VStack(spacing: 2) {
                Text(Day.monthYearLabel(month)).font(.title3.weight(.bold)).contentTransition(.numericText())
                if total > 0 { Text("Recibos: \(Money.eur(total))").font(.caption.weight(.semibold)).foregroundStyle(CalEntry.color(.receipt)) }
            }
            .frame(maxWidth: .infinity)
            Button { move(1) } label: { Image(systemName: "chevron.right.circle.fill").font(.title) }
        }
        .padding(.top, 6)
    }

    private func move(_ n: Int) {
        Haptic.select(); forward = n > 0
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            month = Day.add(month, months: n)
            selected = Day.monthKey(Day.today) == Day.monthKey(month) ? Day.today : month
        }
    }

    private func cell(_ d: String, _ list: [CalEntry]) -> some View {
        let inMonth = Day.monthKey(d) == Day.monthKey(month)
        let isToday = d == Day.today, isSel = d == selected
        let kinds = Array(Set(list.map(\.kind))).sorted { $0.rawValue < $1.rawValue }
        return Button {
            Haptic.select()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selected = d; if !inMonth { forward = d > month; month = Day.monthStart(d) } }
        } label: {
            VStack(spacing: 4) {
                Text("\(Day.cal.component(.day, from: Day.date(d)))")
                    .font(.system(size: 16, weight: isToday || isSel ? .bold : .medium, design: .rounded))
                    .foregroundStyle(isToday ? Color.black : inMonth ? Color.primary : Color.secondary.opacity(0.5))
                    .frame(width: 34, height: 34)
                    .background(isToday ? Color.accentColor : .clear, in: Circle())
                    .overlay(Circle().strokeBorder(isSel && !isToday ? Color.accentColor : .clear, lineWidth: 2))
                HStack(spacing: 3) {
                    ForEach(kinds.prefix(4), id: \.self) { k in Circle().fill(CalEntry.color(k)).frame(width: 5, height: 5) }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 4)
            .contentShape(Rectangle())
            .opacity(inMonth ? 1 : 0.6)
        }
        .buttonStyle(.plain)
    }

    private var legend: some View {
        HStack(spacing: 12) {
            ForEach([(CalEntry.Kind.event, "Agenda"), (.task, "Tareas"), (.due, "Vence"), (.receipt, "Recibos"), (.checkIn, "Chequeo")], id: \.1) { k, t in
                HStack(spacing: 4) { Circle().fill(CalEntry.color(k)).frame(width: 7, height: 7); Text(t).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func dayList(_ list: [CalEntry]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(Day.header(selected)).font(.headline)
                Text(Day.weekdayName(selected)).font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                let spent = list.filter { $0.kind == .receipt }.compactMap { $0.doc?.amount }.reduce(0, +)
                if spent > 0 { Text(Money.eur(spent)).font(.subheadline.weight(.bold)).foregroundStyle(CalEntry.color(.receipt)) }
            }
            if list.isEmpty {
                Text("Nada este día").font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 6)
            }
            ForEach(list) { e in row(e) }
        }
        .card()
        .id(selected)
        .transition(.opacity)
    }

    @ViewBuilder private func row(_ e: CalEntry) -> some View {
        let content = HStack(spacing: 12) {
            if let t = e.task {
                Button { Haptic.tap(); store.toggle(t) } label: {
                    Image(systemName: t.done ? "checkmark.circle.fill" : "circle").font(.title2)
                        .foregroundStyle(t.done ? Color.income : e.color).contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(PressableStyle(scale: 0.8))
            } else if let d = e.doc {
                Thumb(doc: d, size: 34)
            } else {
                Capsule().fill(e.color).frame(width: 4, height: 34).padding(.horizontal, 15)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(e.title).font(.subheadline.weight(.semibold)).lineLimit(2)
                    .strikethrough(e.task?.done == true).foregroundStyle(e.task?.done == true ? .secondary : .primary)
                Text(e.detail).font(.caption).foregroundStyle(e.kind == .due ? e.color : .secondary).lineLimit(1)
            }
            Spacer()
            if e.doc != nil { Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary) }
        }
        .contentShape(Rectangle())
        if let d = e.doc { NavigationLink(value: d) { content }.buttonStyle(.plain) } else { content }
    }
}

/// tira de la semana para el panel de Hoy: toca un día para abrir el calendario
struct WeekStrip: View {
    @Environment(Store.self) private var store
    var events: [AgendaEvent]
    var body: some View {
        let ws = Store.weekStart(Day.today)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                CardTitle(title: "Esta semana", icon: "calendar", color: Color(hex: "#7ac8ff"))
                NavigationLink(value: CalDay(day: Day.today)) {
                    Text("Ver mes").font(.subheadline.weight(.semibold))
                }
            }
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { i in
                    let d = Day.add(ws, days: i)
                    let list = store.entries(d, events: events)
                    let kinds = Array(Set(list.map(\.kind))).sorted { $0.rawValue < $1.rawValue }
                    NavigationLink(value: CalDay(day: d)) {
                        VStack(spacing: 5) {
                            Text(["L", "M", "X", "J", "V", "S", "D"][i]).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                            Text("\(Day.cal.component(.day, from: Day.date(d)))")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(d == Day.today ? Color.black : d < Day.today ? Color.secondary : Color.primary)
                                .frame(width: 36, height: 36)
                                .background(d == Day.today ? Color.accentColor : Color.white.opacity(0.06), in: Circle())
                            HStack(spacing: 2) { ForEach(kinds.prefix(3), id: \.self) { Circle().fill(CalEntry.color($0)).frame(width: 5, height: 5) } }.frame(height: 5)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
        .card()
    }
}
