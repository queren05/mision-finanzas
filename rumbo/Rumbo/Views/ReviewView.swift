import SwiftUI

/// 3. Agente de revisión: el chequeo de cada noche y el resumen de cada semana
struct ReviewView: View {
    @Environment(Store.self) private var store
    @State private var day = Day.today
    @State private var newWin = ""
    @State private var newImprove = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    streak.appear(0)
                    nightly.appear(0.05)
                    weekly.appear(0.1)
                    history.appear(0.15)
                    Color.clear.frame(height: 30)
                }
                .padding(.horizontal, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Revisión")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { SettingsButton() } }
        }
    }

    private var c: CheckIn { store.checkIn(for: day) }
    private func update(_ f: (inout CheckIn) -> Void) { var n = c; f(&n); store.save(n) }

    private var streak: some View {
        let n = store.streak
        let week = (0..<7).map { Day.add(Store.weekStart(Day.today), days: $0) }
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(n > 0 ? "🔥 \(n) \(n == 1 ? "día" : "días") seguidos" : "Empieza tu racha esta noche").font(.headline)
                Spacer()
            }
            HStack(spacing: 6) {
                ForEach(week, id: \.self) { d in
                    let has = store.s.checkIns.contains { $0.date == d && (!$0.text.isEmpty || !$0.wins.isEmpty) }
                    VStack(spacing: 4) {
                        Text(weekdayLetter(d)).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                        Circle().fill(has ? Color.accentColor : Color.white.opacity(0.08)).frame(width: 30, height: 30)
                            .overlay { if has { Image(systemName: "checkmark").font(.caption.weight(.heavy)).foregroundStyle(.black) } }
                            .overlay(Circle().strokeBorder(d == day ? Color.white : .clear, lineWidth: 2))
                    }
                    .frame(maxWidth: .infinity)
                    .onTapGesture { if d <= Day.today { Haptic.select(); withAnimation(.spring) { day = d } } }
                    .opacity(d > Day.today ? 0.35 : 1)
                }
            }
        }
        .card()
    }
    private func weekdayLetter(_ d: String) -> String {
        ["D", "L", "M", "X", "J", "V", "S"][Day.cal.component(.weekday, from: Day.date(d)) - 1]
    }

    private var nightly: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardTitle(title: "Chequeo nocturno", icon: "moon.fill", color: Color(hex: "#8fb4ff"), subtitle: Day.header(day))
            HStack(spacing: 8) {
                Image(systemName: "bubble.left.fill").foregroundStyle(Color(hex: "#8fb4ff"))
                Text("¿Cómo ha ido hoy?").font(.title3.weight(.bold))
            }
            HStack {
                ForEach(1...5, id: \.self) { m in
                    Text(["😩", "😕", "😐", "🙂", "🤩"][m - 1]).font(.system(size: c.mood == m ? 38 : 28))
                        .opacity(c.mood == m ? 1 : 0.45)
                        .frame(maxWidth: .infinity)
                        .onTapGesture { Haptic.select(); withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { update { $0.mood = m } } }
                }
            }
            TextField("Cuéntalo con tus palabras: qué hiciste, qué salió bien, qué no…", text: Binding(get: { c.text }, set: { v in update { $0.text = v } }), axis: .vertical)
                .lineLimit(3...8)
                .padding(12).background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            HStack { Spacer(); AIButton(title: "Ordenar con Claude", key: "sort") { await store.sortDay(day) } }
            HStack(alignment: .top, spacing: 12) {
                list("Logros", "checkmark.square.fill", .income, c.wins, $newWin) { v in update { $0.wins.append(v) } } remove: { i in update { $0.wins.remove(at: i) } }
                list("A mejorar", "xmark", .negative, c.improve, $newImprove) { v in update { $0.improve.append(v) } } remove: { i in update { $0.improve.remove(at: i) } }
            }
        }
        .card()
    }

    private func list(_ title: String, _ icon: String, _ color: Color, _ items: [String], _ text: Binding<String>, add: @escaping (String) -> Void, remove: @escaping (Int) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon).font(.subheadline.weight(.bold)).foregroundStyle(color)
            ForEach(Array(items.enumerated()), id: \.offset) { i, t in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: icon).font(.caption2.weight(.bold)).foregroundStyle(color)
                    Text(t).font(.caption).fixedSize(horizontal: false, vertical: true)
                }
                .contextMenu { Button("Quitar", role: .destructive) { withAnimation { remove(i) } } }
                .transition(.scale.combined(with: .opacity))
            }
            TextField("Añadir…", text: text).font(.caption)
                .onSubmit {
                    let v = text.wrappedValue.trimmingCharacters(in: .whitespaces)
                    if !v.isEmpty { withAnimation(.spring) { add(v) }; text.wrappedValue = ""; Haptic.tap() }
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var weekly: some View {
        let w = store.s.weekly.first
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                CardTitle(title: "Revisión semanal", icon: "calendar", color: Color(hex: "#b39cff"), subtitle: w.map { "Semana del \(Day.shortLabel($0.weekStart))" } ?? "Cada domingo")
                AIButton(title: w?.weekStart == Store.weekStart(Day.today) ? "Rehacer" : "Hacer", key: "weekly") { await store.makeWeekly() }
            }
            if let w {
                section("Resumen de la semana", "chart.bar.fill", Color(hex: "#7ac8ff")) { Bullets(items: w.summary, color: Color(hex: "#7ac8ff")) }
                section("Mejoras principales", "chart.line.uptrend.xyaxis", .income) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(w.improvements.enumerated()), id: \.offset) { i, t in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text("\(i + 1)").font(.caption.weight(.heavy)).frame(width: 22, height: 22).background(Color.income.opacity(0.2), in: Circle())
                                Text(t).font(.subheadline)
                            }
                        }
                    }
                }
                section("Plan para la próxima semana", "target", Color(hex: "#ff9ecf")) {
                    VStack(alignment: .leading, spacing: 8) {
                        planRow("scope", "Enfoque", w.focus)
                        planRow("flag.fill", "Objetivo", w.goal)
                        planRow("clock.fill", "Hábito", w.habit)
                    }
                }
            } else {
                Text("Cada domingo Claude lee tus chequeos y tareas de la semana y te hace un resumen con qué mejorar y el plan para la siguiente.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private func section<C: View>(_ t: String, _ icon: String, _ color: Color, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(t, systemImage: icon).font(.subheadline.weight(.bold)).foregroundStyle(color)
            content()
        }
    }
    private func planRow(_ icon: String, _ k: String, _ v: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: icon).foregroundStyle(.secondary).frame(width: 20)
            Text(k + ":").font(.subheadline.weight(.bold))
            Text(v).font(.subheadline)
        }
    }

    @ViewBuilder private var history: some View {
        let past = store.s.checkIns.filter { $0.date != day && (!$0.text.isEmpty || !$0.wins.isEmpty) }.sorted { $0.date > $1.date }.prefix(10)
        if !past.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                CardTitle(title: "Días anteriores", icon: "clock.arrow.circlepath", color: .secondary)
                ForEach(Array(past)) { ci in
                    Button { Haptic.select(); withAnimation(.spring) { day = ci.date } } label: {
                        HStack {
                            Text(["😩", "😕", "😐", "🙂", "🤩"][max(0, min(4, ci.mood - 1))]).font(.title2)
                            VStack(alignment: .leading) {
                                Text(Day.header(ci.date)).font(.subheadline.weight(.semibold))
                                Text("\(ci.wins.count) logros · \(ci.improve.count) a mejorar").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .card()
        }
    }
}
