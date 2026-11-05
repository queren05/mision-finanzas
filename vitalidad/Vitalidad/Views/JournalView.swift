import SwiftUI

/// Diario: lo que haces cada día y cómo te afecta al sueño y a la recuperación.
struct JournalView: View {
    @Environment(HealthStore.self) private var store
    @State private var journal = Journal.shared
    @State private var day: Date = Calendar.current.startOfDay(for: .now)
    @State private var edit = false

    var body: some View {
        let entry = journal.entry(day)
        let habits = journal.tracked.compactMap(Habit.by)
        let effects = HabitImpact.effects(store, journal: journal)
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                DayStrip(selected: $day)
                    .padding(.horizontal, -Space.s)
                    .padding(.top, -Space.s)

                HStack(alignment: .firstTextBaseline) {
                    Text(store.isToday(day) ? "¿Qué tal hoy?" : "¿Qué tal el \(Fmt.day(day, style: "EEEE d"))?")
                        .font(.title2.weight(.bold))
                    Spacer()
                    if journal.answered(day) {
                        Image(systemName: "checkmark.circle.fill").font(.title3).foregroundStyle(Palette.good)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, Space.xs)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: Space.m), GridItem(.flexible(), spacing: Space.m)], spacing: Space.m) {
                    ForEach(habits) { h in
                        HabitTile(habit: h, value: entry[h.id] ?? 0) { v in
                            withAnimation(.snappy) { journal.set(h.id, v, on: day) }
                        }
                    }
                }

                if !journal.answered(day) {
                    Button {
                        withAnimation(.snappy) { journal.markAnswered(day) }
                    } label: {
                        Text("Nada de esto")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Capsule().fill(Ink.surfaceHigh))
                            .overlay(Capsule().strokeBorder(Ink.hairline.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                }

                StreakRow(streak: journal.streak, logged: journal.days.count)

                SectionTitle(title: "Lo que te afecta")
                let ready = effects.filter { $0.sleep != nil || $0.recovery != nil }
                if ready.isEmpty {
                    VStack(alignment: .leading, spacing: Space.m) {
                        ForEach(effects.prefix(4)) { e in
                            HStack(spacing: Space.m) {
                                MetricGlyph(symbol: e.habit.symbol, color: e.habit.color, size: 28)
                                Text(e.habit.title).font(.subheadline.weight(.medium))
                                Spacer()
                                Text("\(min(e.yes, HabitImpact.minDays))/\(HabitImpact.minDays) sí · \(min(e.no, HabitImpact.minDays))/\(HabitImpact.minDays) no")
                                    .font(.caption.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .card()
                } else {
                    VStack(spacing: Space.l) {
                        HStack {
                            Spacer()
                            legend(Palette.sleep, "Sueño")
                            legend(Palette.recovery, "Recuperación")
                        }
                        ForEach(ready) { e in ImpactRow(effect: e) }
                    }
                    .card()
                }
            }
            .padding(.horizontal, Space.l)
            .padding(.bottom, Space.xxl)
        }
        .background(MoodBackground(mood: .neutral))
        .navigationTitle("Diario")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { edit = true } label: { Image(systemName: "slider.horizontal.3") }
                    .accessibilityLabel("Elegir hábitos")
            }
        }
        .sheet(isPresented: $edit) { HabitsSettingsView(journal: journal) }
        .sensoryFeedback(.selection, trigger: journal.version)
    }

    private func legend(_ c: Color, _ t: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(c).frame(width: 8, height: 8)
            Text(t).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
        }
    }
}

/// Un hábito: se toca para marcarlo; los que se cuentan llevan − y +.
struct HabitTile: View {
    var habit: Habit
    var value: Int
    var change: (Int) -> Void

    var body: some View {
        let on = value > 0
        VStack(alignment: .leading, spacing: Space.s) {
            HStack {
                Image(systemName: habit.symbol)
                    .font(.title3)
                    .foregroundStyle(on ? .white : habit.color)
                    .symbolEffect(.bounce, value: value)
                Spacer()
                if habit.counted && on {
                    Text("\(value)")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                }
            }
            Text(habit.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(on ? .white : .primary)
                .lineLimit(2, reservesSpace: true)
            if habit.counted {
                HStack(spacing: Space.s) {
                    stepButton("minus") { change(max(0, value - 1)) }.opacity(on ? 1 : 0.4).disabled(!on)
                    Spacer()
                    Text(habit.unit ?? "").font(.caption).foregroundStyle(on ? .white.opacity(0.8) : .secondary)
                        .lineLimit(1).minimumScaleFactor(0.7).fixedSize()
                    Spacer()
                    stepButton("plus") { change(value + 1) }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(on ? AnyShapeStyle(LinearGradient(colors: [habit.color, habit.color.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(Ink.surface))
        )
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Ink.hairline.opacity(on ? 0 : 0.08)))
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onTapGesture { if !habit.counted { change(on ? 0 : 1) } else if !on { change(1) } }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }

    private func stepButton(_ s: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Image(systemName: s)
                .font(.footnote.weight(.bold))
                .frame(width: 30, height: 30)
                .background(Circle().fill(value > 0 ? Color.white.opacity(0.22) : habit.color.opacity(0.15)))
                .foregroundStyle(value > 0 ? .white : habit.color)
        }
        .buttonStyle(.plain)
    }
}

struct StreakRow: View {
    var streak: Int
    var logged: Int
    var body: some View {
        HStack(spacing: Space.l) {
            stat("\(streak)", streak == 1 ? "día seguido" : "días seguidos", "flame.fill", Palette.effort)
            Divider().frame(height: 34)
            stat("\(logged)", logged == 1 ? "día apuntado" : "días apuntados", "book.closed.fill", Palette.recovery)
        }
        .frame(maxWidth: .infinity)
        .card(padding: 16)
    }

    private func stat(_ v: String, _ l: String, _ s: String, _ c: Color) -> some View {
        HStack(spacing: Space.s) {
            Image(systemName: s).foregroundStyle(c)
            VStack(alignment: .leading, spacing: 0) {
                Text(v).font(.system(.title3, design: .rounded).weight(.bold)).monospacedDigit()
                Text(l).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// Un hábito con lo que cambian el sueño y la recuperación: barras a izquierda (peor) o derecha (mejor).
struct ImpactRow: View {
    var effect: HabitImpact.Effect

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(spacing: Space.m) {
                MetricGlyph(symbol: effect.habit.symbol, color: effect.habit.color, size: 28)
                Text(effect.habit.title).font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(effect.yes) días").font(.caption).foregroundStyle(.secondary)
            }
            bar(effect.sleep, Palette.sleep)
            bar(effect.recovery, Palette.recovery)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func bar(_ v: Double?, _ c: Color) -> some View {
        if let v {
            HStack(spacing: Space.s) {
                GeometryReader { g in
                    let half = g.size.width / 2
                    let w = min(half, half * abs(v) / 20)
                    ZStack(alignment: .leading) {
                        Capsule().fill(Ink.track).frame(height: 8)
                        Rectangle().fill(Ink.hairline.opacity(0.3)).frame(width: 1, height: 14).offset(x: half)
                        Capsule().fill(c.opacity(v < 0 ? 0.55 : 1))
                            .frame(width: max(4, w), height: 8)
                            .offset(x: v < 0 ? half - w : half)
                    }
                    .frame(maxHeight: .infinity)
                }
                .frame(height: 14)
                Text("\(v >= 0 ? "+" : "−")\(Int(abs(v).rounded()))")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(v <= -3 ? Palette.heart : v >= 3 ? Palette.good : .secondary)
                    .frame(width: 34, alignment: .trailing)
            }
        }
    }
}

/// Qué hábitos apuntar y el aviso de cada noche.
struct HabitsSettingsView: View {
    @Bindable var journal: Journal
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Aviso cada noche", isOn: $journal.reminder)
                    if journal.reminder {
                        DatePicker("Hora", selection: Binding(
                            get: { Calendar.current.date(bySettingHour: journal.reminderHour, minute: journal.reminderMinute, second: 0, of: .now) ?? .now },
                            set: {
                                let c = Calendar.current.dateComponents([.hour, .minute], from: $0)
                                journal.reminderHour = c.hour ?? 21
                                journal.reminderMinute = c.minute ?? 30
                            }), displayedComponents: .hourAndMinute)
                    }
                }
                Section("Apuntar") {
                    ForEach(journal.tracked.compactMap(Habit.by)) { h in
                        row(h, on: true)
                    }
                    .onMove { journal.tracked.move(fromOffsets: $0, toOffset: $1) }
                }
                let rest = Habit.all.filter { !journal.tracked.contains($0.id) }
                if !rest.isEmpty {
                    Section("Más") {
                        ForEach(rest) { h in row(h, on: false) }
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .scrollContentBackground(.hidden)
            .background(MoodBackground(mood: .neutral))
            .navigationTitle("Hábitos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Listo") { dismiss() } } }
        }
    }

    private func row(_ h: Habit, on: Bool) -> some View {
        Button {
            withAnimation {
                if on { journal.tracked.removeAll { $0 == h.id } } else { journal.tracked.append(h.id) }
            }
        } label: {
            HStack(spacing: Space.m) {
                MetricGlyph(symbol: h.symbol, color: h.color, size: 28)
                Text(h.title).foregroundStyle(.primary)
                Spacer()
                Image(systemName: on ? "minus.circle.fill" : "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(on ? Color.secondary : Palette.good)
            }
        }
        .buttonStyle(.plain)
    }
}
