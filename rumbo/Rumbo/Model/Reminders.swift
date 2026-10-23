import SwiftUI
import UserNotifications

/// para que los avisos salgan también con la app abierta
final class NotiDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotiDelegate()
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        await MainActor.run {
            if let id = info["film"] as? String { Router.shared.rateFilm = id }
            if info["smoke"] != nil { Router.shared.open("humo") }
        }
    }
}

enum RemRepeat: String, CaseIterable, Identifiable {
    case nunca = "", dia, semana, mes, año
    var id: String { rawValue }
    var label: String {
        switch self {
        case .nunca: "Nunca"
        case .dia: "Cada día"
        case .semana: "Cada semana"
        case .mes: "Cada mes"
        case .año: "Cada año"
        }
    }
}

extension Reminder {
    var rep: RemRepeat { RemRepeat(rawValue: repeats) ?? .nunca }

    /// próxima vez que salta (nil si ya pasó y no se repite)
    func next(after now: Date = Date()) -> Date? {
        if date > now { return date }
        let cal = Calendar.current
        let unit: Calendar.Component
        switch rep {
        case .nunca: return nil
        case .dia: unit = .day
        case .semana: unit = .weekOfYear
        case .mes: unit = .month
        case .año: unit = .year
        }
        var n = 1
        while n < 5000 {
            if let d = cal.date(byAdding: unit, value: n, to: date), d > now { return d }
            n += 1
        }
        return nil
    }

    /// ¿salta algún día en este día (yyyy-MM-dd)?
    func occurs(on day: String) -> Bool {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date), d = Day.date(day)
        guard cal.startOfDay(for: d) >= start else { return false }
        let a = cal.dateComponents([.weekday, .day, .month], from: date), b = cal.dateComponents([.weekday, .day, .month], from: d)
        switch rep {
        case .nunca: return Day.str(date) == day
        case .dia: return true
        case .semana: return a.weekday == b.weekday
        case .mes: return a.day == b.day
        case .año: return a.day == b.day && a.month == b.month
        }
    }

    var whenText: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "es_ES")
        let d = next() ?? date
        let cal = Calendar.current
        let hm = Day.time(d)
        var s: String
        if cal.isDateInToday(d) { s = "Hoy · \(hm)" }
        else if cal.isDateInTomorrow(d) { s = "Mañana · \(hm)" }
        else { f.dateFormat = cal.component(.year, from: d) == cal.component(.year, from: Date()) ? "EEE d MMM" : "d MMM yyyy"; s = f.string(from: d) + " · " + hm }
        if rep != .nunca { s += " · " + rep.label.lowercased() }
        return s
    }
}

extension Store {
    func save(_ r: Reminder) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if let i = s.reminders.firstIndex(where: { $0.id == r.id }) { s.reminders[i] = r } else { s.reminders.append(r) }
        }
        let c = UNUserNotificationCenter.current()
        c.requestAuthorization(options: [.alert, .sound, .badge]) { ok, _ in
            DispatchQueue.main.async {
                if !ok { self.error = "Las notificaciones de Rumbo están apagadas. Actívalas en Ajustes del iPhone → Rumbo → Notificaciones." }
                self.syncReminders()
            }
        }
    }
    func delete(_ r: Reminder) {
        withAnimation(.spring) { s.reminders.removeAll { $0.id == r.id } }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["rem-" + r.id])
    }

    /// vuelve a programar todos los avisos de los recordatorios
    func syncReminders() {
        let c = UNUserNotificationCenter.current()
        let list = s.reminders
        c.getPendingNotificationRequests { pending in
            c.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix("rem-") })
            for r in list {
                guard let when = r.next() else { continue }
                let n = UNMutableNotificationContent()
                n.title = r.title.isEmpty ? "Recordatorio" : r.title
                n.body = r.note.isEmpty ? "⏰ " + Day.time(when) : r.note
                n.sound = .default
                n.interruptionLevel = .timeSensitive
                let parts: Set<Calendar.Component>
                switch r.rep {
                case .nunca: parts = [.year, .month, .day, .hour, .minute]
                case .dia: parts = [.hour, .minute]
                case .semana: parts = [.weekday, .hour, .minute]
                case .mes: parts = [.day, .hour, .minute]
                case .año: parts = [.month, .day, .hour, .minute]
                }
                let comps = Calendar.current.dateComponents(parts, from: r.rep == .nunca ? when : r.date)
                c.add(UNNotificationRequest(identifier: "rem-" + r.id, content: n,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: r.rep != .nunca)))
            }
        }
    }
}

/// tarjeta de recordatorios del panel de Hoy
struct RemindersCard: View {
    @Environment(Store.self) private var store
    @State private var editing: Reminder? = nil
    @State private var pendingDelete: Reminder? = nil
    @State private var askDelete = false

    var body: some View {
        let now = Date()
        let upcoming = store.s.reminders.filter { $0.next(after: now) != nil }.sorted { $0.next(after: now)! < $1.next(after: now)! }
        let past = store.s.reminders.filter { $0.next(after: now) == nil }.sorted { $0.date > $1.date }
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                CardTitle(title: "Recordatorios", icon: "bell.fill", color: Color(hex: "#ff9ecf"))
                Button { Haptic.tap(); editing = Reminder(date: Store.defaultReminderDate()) } label: {
                    Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(Color(hex: "#ff9ecf"))
                }
                .buttonStyle(PressableStyle(scale: 0.85))
            }
            ForEach(upcoming) { r in row(r, past: false) }
            ForEach(past.prefix(5)) { r in row(r, past: true) }
        }
        .card()
        .sheet(item: $editing) { ReminderEditor(original: $0) }
        .confirmationDialog("¿Seguro que quieres eliminar este recordatorio?", isPresented: $askDelete, titleVisibility: .visible, presenting: pendingDelete) { r in
            Button("Eliminar", role: .destructive) { Haptic.heavy(); store.delete(r) }
            Button("Cancelar", role: .cancel) {}
        } message: { r in Text(r.title) }
    }

    private func row(_ r: Reminder, past: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: r.rep == .nunca ? "bell" : "bell.badge").font(.title3)
                .foregroundStyle(past ? .secondary : Color(hex: "#ff9ecf")).frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(r.title.isEmpty ? "Recordatorio" : r.title).foregroundStyle(past ? .secondary : .primary).lineLimit(2)
                Text(r.whenText).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Menu {
                Button { editing = r } label: { Label("Editar", systemImage: "pencil") }
                Button(role: .destructive) { Haptic.warning(); pendingDelete = r; askDelete = true } label: { Label("Eliminar", systemImage: "trash") }
            } label: { Image(systemName: "ellipsis").foregroundStyle(.secondary).frame(width: 30, height: 30) }
        }
        .contentShape(Rectangle())
        .onTapGesture { editing = r }
        .transition(.asymmetric(insertion: .push(from: .top), removal: .opacity))
    }
}

extension Store {
    /// la próxima hora en punto
    static func defaultReminderDate() -> Date {
        let cal = Calendar.current
        let h = cal.date(byAdding: .hour, value: 1, to: Date())!
        return cal.date(bySettingHour: cal.component(.hour, from: h), minute: 0, second: 0, of: h) ?? h
    }
}

struct ReminderEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let original: Reminder
    @State private var r = Reminder()
    @FocusState private var focus: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("¿Qué te recuerdo?", text: $r.title, axis: .vertical).font(.title3.weight(.semibold)).focused($focus)
                    TextField("Nota", text: $r.note, axis: .vertical)
                }
                Section {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            chip("En 1 hora") { Date().addingTimeInterval(3600) }
                            chip("Esta tarde") { at(0, 18) }
                            chip("Esta noche") { at(0, 21) }
                            chip("Mañana") { at(1, 9) }
                            chip("En una semana") { at(7, 9) }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    DatePicker("Día", selection: $r.date, displayedComponents: .date)
                    DatePicker("Hora", selection: $r.date, displayedComponents: .hourAndMinute)
                    Picker("Repetir", selection: $r.repeats) {
                        ForEach(RemRepeat.allCases) { Text($0.label).tag($0.rawValue) }
                    }
                }
            }
            .navigationTitle(original.title.isEmpty ? "Nuevo recordatorio" : "Recordatorio").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { store.save(r); Haptic.success(); dismiss() }.bold()
                        .disabled(r.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { r = original; if original.title.isEmpty { focus = true } }
        }
    }

    private func at(_ days: Int, _ hour: Int) -> Date {
        let cal = Calendar.current
        let d = cal.date(byAdding: .day, value: days, to: Date())!
        return cal.date(bySettingHour: hour, minute: 0, second: 0, of: d) ?? d
    }
    private func chip(_ t: String, _ date: @escaping () -> Date) -> some View {
        Button { Haptic.select(); withAnimation { r.date = date() } } label: {
            Text(t).font(.subheadline.weight(.semibold)).padding(.horizontal, 12).padding(.vertical, 7)
                .background(Color(hex: "#ff9ecf").opacity(0.18), in: Capsule()).foregroundStyle(Color(hex: "#ff9ecf"))
        }
        .buttonStyle(.plain)
    }
}
