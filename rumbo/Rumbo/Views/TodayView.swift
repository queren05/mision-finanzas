import SwiftUI

/// 1. Panel de vida: agenda de hoy, prioridades, tareas y el briefing diario hecho por Claude
struct TodayView: View {
    @Environment(Store.self) private var store
    @State private var newTask = ""
    @State private var editing: TaskItem? = nil
    @State private var pendingDelete: TaskItem? = nil
    @State private var askDelete = false
    @FocusState private var adding: Bool
    @State private var path = NavigationPath()
    @State private var weekEvents: [AgendaEvent] = []
    @State private var expanded: Set<String> = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 18) {
                    ForEach(Array(store.s.settings.todayModules.enumerated()), id: \.element) { i, m in
                        module(m).appear(Double(i) * 0.03)
                    }
                    Color.clear.frame(height: 30)
                }
                .padding(.horizontal, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(greeting)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { path.append(CalDay(day: Day.today)) } label: { Image(systemName: "calendar") }
                }
                if !hiddenPages.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            ForEach(hiddenPages) { p in
                                Button { Router.shared.open(p.rawValue) } label: { Label(p.label, systemImage: p.icon) }
                            }
                        } label: { Image(systemName: "square.grid.2x2.fill") }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) { SettingsButton() }
            }
            .navigationDestination(for: CalDay.self) { CalendarView(day: $0.day) }
            .navigationDestination(for: BrainDoc.self) { DocDetail(docId: $0.id) }
            .refreshable { await reload() }
            .task {
                await reload()
                if ProcessInfo.processInfo.arguments.contains("-cal") && path.isEmpty { path.append(CalDay(day: Day.today)) }
            }
            .sheet(item: $editing) { TaskEditor(original: $0) }
            .confirmationDialog("¿Seguro que quieres eliminar esta tarea?", isPresented: $askDelete, titleVisibility: .visible, presenting: pendingDelete) { t in
                Button("Eliminar", role: .destructive) { Haptic.heavy(); store.delete(t) }
                Button("Cancelar", role: .cancel) {}
            } message: { t in Text(t.title) }
        }
    }

    private var hiddenPages: [Page] {
        Page.allCases.filter { $0 != .hoy && !store.s.settings.tabs.contains($0.rawValue) }
    }

    @ViewBuilder private func module(_ m: String) -> some View {
        switch m {
        case "resumen": header
        case "semana": WeekStrip(events: weekEvents)
        case "briefing": if store.s.settings.ai { briefing }
        case "agenda": agenda
        case "recordatorios": RemindersCard()
        case "prioridades": priorities
        case "tareas": tasks
        case "humo": SmokeMini()
        case "cine": watching
        default: EmptyView()
        }
    }

    /// lo último que estás viendo o has visto
    @ViewBuilder private var watching: some View {
        let list = store.s.films.filter { $0.status == .viendo } + store.s.films.filter { $0.status == .vista }.sorted { $0.lastWatched > $1.lastWatched }.prefix(6)
        if !list.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                CardTitle(title: "Viendo ahora", icon: "film.fill", color: Color(hex: "#ff8000"))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(list.prefix(10)) { f in
                            Button { Router.shared.open("cine") } label: { Poster(film: f, width: 70) }.buttonStyle(PressableStyle())
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .card()
        }
    }

    private func reload() async {
        await store.loadAgenda()
        let ws = Store.weekStart(Day.today)
        weekEvents = store.events(from: ws, to: Day.add(ws, days: 6))
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        return (h < 6 ? "Buenas noches" : h < 14 ? "Buenos días" : h < 21 ? "Buenas tardes" : "Buenas noches") + ", " + store.s.settings.name
    }

    private var header: some View {
        let open = store.s.tasks.filter { !$0.done }.count
        let doneToday = store.s.tasks.filter { $0.done && $0.doneAt.map { Day.str($0) == Day.today } == true }.count
        return HStack(spacing: 12) {
            stat("\(store.agenda.count)", "eventos hoy", "calendar", Color(hex: "#7ac8ff"))
            stat("\(open)", "pendientes", "checklist", Color(hex: "#f0c46a"))
            stat("\(doneToday)", "hechas hoy", "checkmark.seal.fill", .income)
        }
    }
    private func stat(_ v: String, _ l: String, _ icon: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).foregroundStyle(c)
            Text(v).font(.system(size: 26, weight: .bold, design: .rounded)).contentTransition(.numericText())
            Text(l).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading).card(14)
    }

    private var briefing: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                CardTitle(title: "Briefing diario", icon: "sparkles", subtitle: Day.header(Day.today))
                AIButton(title: store.s.briefing?.date == Day.today ? "Rehacer" : "Hacer", key: "briefing") { await store.makeBriefing() }
            }
            if let b = store.s.briefing, b.date == Day.today {
                Text(b.text).font(.subheadline).lineSpacing(3).textSelection(.enabled)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Text("Claude mira tu agenda, tus prioridades y cómo te fue ayer, y te dice por dónde empezar.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .card()
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(LinearGradient(colors: [Color.accentColor.opacity(0.6), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5))
    }

    private var agenda: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardTitle(title: "Agenda de hoy", icon: "calendar", color: Color(hex: "#7ac8ff"))
            if store.calendarDenied {
                Text("Para ver tu agenda, deja que Rumbo lea tus calendarios en Ajustes del iPhone → Rumbo → Calendarios.").font(.subheadline).foregroundStyle(.secondary)
            } else if store.agenda.isEmpty {
                Text("No tienes nada en el calendario hoy. Día libre para tus prioridades 💪").font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(store.agenda) { e in
                    HStack(spacing: 12) {
                        Capsule().fill(e.color).frame(width: 4, height: 34)
                        Text(e.allDay ? "Todo el día" : Day.time(e.start)).font(.subheadline.weight(.semibold)).monospacedDigit().frame(width: 74, alignment: .leading)
                        Text(e.title).font(.subheadline).lineLimit(2)
                        Spacer()
                        if !e.allDay, e.start <= Date(), e.end > Date() {
                            Text("Ahora").font(.caption2.weight(.heavy)).padding(.horizontal, 8).padding(.vertical, 3).background(Color.accentColor, in: Capsule()).foregroundStyle(.black)
                        }
                    }
                    .opacity(!e.allDay && e.end < Date() ? 0.45 : 1)
                }
            }
        }
        .card()
    }

    private var priorities: some View {
        let list = store.s.tasks.filter { $0.priority }.sorted { !$0.done && $1.done }
        return VStack(alignment: .leading, spacing: 10) {
            CardTitle(title: "Prioridades", icon: "flag.fill", color: Color(hex: "#ff9f7a"))
            if list.isEmpty { Text("Marca una tarea con la bandera para que salga aquí.").font(.subheadline).foregroundStyle(.secondary) }
            ForEach(list) { t in row(t) }
        }
        .card()
    }

    private var tasks: some View {
        let list = store.s.tasks.filter { !$0.priority }.sorted { (!$0.done && $1.done) }
        return VStack(alignment: .leading, spacing: 10) {
            CardTitle(title: "Tareas", icon: "checklist", color: Color(hex: "#f0c46a"))
            HStack {
                Image(systemName: "plus.circle.fill").foregroundStyle(Color.accentColor).font(.title3)
                TextField("Nueva tarea", text: $newTask).focused($adding).submitLabel(.done).onSubmit(addTask)
            }
            .padding(10).background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            ForEach(list.prefix(30)) { t in row(t) }
        }
        .card()
    }

    private func row(_ t: TaskItem) -> some View {
        HStack(spacing: 12) {
            Button { Haptic.tap(); store.toggle(t) } label: {
                Image(systemName: t.done ? "checkmark.circle.fill" : "circle")
                    .font(.title2).foregroundStyle(t.done ? Color.income : .secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(PressableStyle(scale: 0.8))
            VStack(alignment: .leading, spacing: 2) {
                Text(t.title).strikethrough(t.done).foregroundStyle(t.done ? .secondary : .primary)
                    .lineLimit(expanded.contains(t.id) ? nil : 3)
                    .onTapGesture { withAnimation(.snappy) { if expanded.contains(t.id) { expanded.remove(t.id) } else { expanded.insert(t.id) } } }
                if !t.due.isEmpty { Text("Para \(Day.header(t.due).lowercased())").font(.caption).foregroundStyle(t.due < Day.today && !t.done ? Color.negative : .secondary) }
            }
            Spacer()
            Menu {
                Button { editing = t } label: { Label("Editar", systemImage: "pencil") }
                Button { var n = t; n.priority.toggle(); store.save(n); Haptic.select() } label: { Label(t.priority ? "Quitar de prioridades" : "Marcar como prioridad", systemImage: "flag") }
                Button(role: .destructive) { Haptic.warning(); pendingDelete = t; askDelete = true } label: { Label("Eliminar", systemImage: "trash") }
            } label: { Image(systemName: "ellipsis").foregroundStyle(.secondary).frame(width: 30, height: 30) }
        }
        .contentShape(Rectangle())
        .transition(.asymmetric(insertion: .push(from: .top), removal: .opacity))
    }

    private func addTask() {
        let t = newTask.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        store.save(TaskItem(title: t)); newTask = ""; Haptic.success()
    }
}

struct TaskEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let original: TaskItem
    @State private var t = TaskItem(title: "")
    @State private var hasDue = false
    @State private var due = Date()
    var body: some View {
        NavigationStack {
            Form {
                TextField("Tarea", text: $t.title, axis: .vertical).lineLimit(1...12)
                Toggle(isOn: $t.priority) { Label("Prioridad", systemImage: "flag.fill") }
                Toggle("Con fecha", isOn: $hasDue.animation())
                if hasDue { DatePicker("Para el", selection: $due, displayedComponents: .date) }
            }
            .navigationTitle(original.title.isEmpty ? "Nueva tarea" : "Tarea").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { var n = t; n.due = hasDue ? Day.str(due) : ""; store.save(n); Haptic.success(); dismiss() }.bold()
                        .disabled(t.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { t = original; if !original.due.isEmpty { hasDue = true; due = Day.date(original.due) } }
        }
    }
}
