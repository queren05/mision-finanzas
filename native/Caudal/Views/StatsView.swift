import SwiftUI
import Charts

struct StatsView: View {
    @Environment(Store.self) private var store
    @State private var start: String = ""
    @State private var showIncome = false
    @State private var selectedCat: String? = nil
    @State private var angle: Double? = nil
    /// dentro de otra navegación (desde Inicio o Más) no lleva su propia barra
    var embedded = false

    var body: some View {
        if embedded { content } else { NavigationStack { content } }
    }

    private var content: some View {
            ScrollView {
                VStack(spacing: 18) {
                    periodBar
                    kpis.appear(0)
                    donut.appear(0.05)
                    monthsChart.appear(0.1)
                    budgets.appear(0.15)
                    topConcepts.appear(0.2)
                    Color.clear.frame(height: 60)
                }
                .padding(.horizontal, 16)
            }
            .appBackground()
            .navigationTitle("Análisis")
            .onAppear { if start.isEmpty { start = store.periodStart(for: Day.today) } }
    }

    private var range: ClosedRange<String> { store.periodRange(start.isEmpty ? store.periodStart(for: Day.today) : start) }

    private var periodBar: some View {
        HStack {
            Button { move(-1) } label: { Image(systemName: "chevron.left.circle.fill").font(.title) }
            Spacer()
            Text(Day.monthYearLabel(start.isEmpty ? Day.today : start))
                .font(.title3.weight(.bold))
                .contentTransition(.numericText())
            Spacer()
            Button { move(1) } label: { Image(systemName: "chevron.right.circle.fill").font(.title) }
                .disabled(range.upperBound >= Day.today)
        }
        .symbolRenderingMode(.hierarchical)
        .buttonStyle(PressableStyle(scale: 0.85))
        .padding(.top, 4)
    }

    private func move(_ k: Int) {
        Haptic.select()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { start = Day.add(start, months: k); selectedCat = nil }
    }

    private var kpis: some View {
        let spent = store.spent(in: range), earned = store.earned(in: range)
        let days = max(1, min(Day.cal.dateComponents([.day], from: Day.date(range.lowerBound), to: Date()).day.map { $0 + 1 } ?? 30, 31))
        let saving = earned > 0 ? (earned - spent) / earned * 100 : 0
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            kpi("Gastado", Money.eur(spent), "arrow.down.circle.fill", .negative)
            kpi("Ingresado", Money.eur(earned), "arrow.up.circle.fill", .income)
            kpi("Ahorro", earned > 0 ? Money.pct(saving) : "—", "banknote.fill", saving >= 0 ? .income : .negative)
            kpi("Media al día", Money.eur(spent / Double(days)), "calendar", .accentColor)
        }
    }

    private func kpi(_ label: String, _ v: String, _ icon: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).font(.title2).foregroundStyle(c)
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(store.hideAmounts && v.contains("€") ? "•••• €" : v).font(.title3.weight(.bold)).monospacedDigit()
                .contentTransition(.numericText()).lineLimit(1).minimumScaleFactor(0.6)
        }
        .card(14)
    }

    private var donut: some View {
        let cats = store.byCategory(in: range, kind: showIncome ? .income : .expense)
        let total = cats.reduce(0) { $0 + $1.total }
        let sel = cats.first { $0.cat.id == selectedCat }
        return VStack(alignment: .leading, spacing: 14) {
            Picker("", selection: $showIncome.animation(.spring)) {
                Text("Gastos").tag(false); Text("Ingresos").tag(true)
            }
            .pickerStyle(.segmented)
            if cats.isEmpty {
                Text("Nada en este periodo").foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 120)
            } else {
                ZStack {
                    Chart(cats) { c in
                        SectorMark(angle: .value("€", c.total), innerRadius: .ratio(0.64), angularInset: 2.5)
                            .cornerRadius(6)
                            .foregroundStyle(Color(hex: c.cat.color))
                            .opacity(selectedCat == nil || selectedCat == c.cat.id ? 1 : 0.3)
                    }
                    .chartAngleSelection(value: $angle)
                    .frame(height: 230)
                    .onChange(of: angle) { _, v in
                        guard let v else { return }
                        var acc = 0.0
                        for c in cats { acc += c.total; if v <= acc { if selectedCat != c.cat.id { Haptic.select() }; withAnimation(.spring) { selectedCat = c.cat.id }; break } }
                    }
                    VStack(spacing: 2) {
                        Text(sel.map { "\($0.cat.icon) \($0.cat.name)" } ?? "Total").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary).lineLimit(1)
                        AmountText(value: sel?.total ?? total, font: .title2.weight(.bold))
                        if let sel { Text("\(Money.num(sel.total / max(total, 0.01) * 100)) %").font(.caption.weight(.bold)).foregroundStyle(.secondary) }
                    }
                    .frame(width: 130)
                }
                ForEach(cats) { c in
                    Button {
                        Haptic.select()
                        withAnimation(.spring) { selectedCat = selectedCat == c.cat.id ? nil : c.cat.id }
                    } label: {
                        VStack(spacing: 6) {
                            HStack {
                                Text(c.cat.icon)
                                Text(c.cat.name).font(.subheadline.weight(.medium))
                                Spacer()
                                AmountText(value: c.total, font: .subheadline.weight(.semibold))
                            }
                            ProgressBar(value: c.total / max(cats.first?.total ?? 1, 0.01), color: Color(hex: c.cat.color), height: 6)
                        }
                        .opacity(selectedCat == nil || selectedCat == c.cat.id ? 1 : 0.45)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .card()
    }

    private struct MonthBar: Identifiable { var id: String { month + kind }; var month: String; var kind: String; var value: Double }

    private var monthsChart: some View {
        var bars: [MonthBar] = []
        let base = start.isEmpty ? store.periodStart(for: Day.today) : start
        for k in stride(from: 5, through: 0, by: -1) {
            let s = Day.add(base, months: -k)
            let r = store.periodRange(s)
            let label = String(Day.month(s).prefix(3))
            bars.append(MonthBar(month: label, kind: "Ingresos", value: store.earned(in: r)))
            bars.append(MonthBar(month: label, kind: "Gastos", value: store.spent(in: r)))
        }
        return VStack(alignment: .leading, spacing: 12) {
            Text("Últimos 6 meses").font(.headline)
            Chart(bars) { b in
                BarMark(x: .value("Mes", b.month), y: .value("€", b.value))
                    .foregroundStyle(by: .value("Tipo", b.kind))
                    .position(by: .value("Tipo", b.kind))
                    .cornerRadius(5)
            }
            .chartForegroundStyleScale(["Ingresos": Color.income, "Gastos": Color(hex: "#ff9f7a")])
            .chartLegend(position: .top, alignment: .leading)
            .frame(height: 200)
        }
        .card()
    }

    @ViewBuilder private var budgets: some View {
        let cats = store.state.categories.filter { $0.kind == .expense && $0.budget > 0 }
        if !cats.isEmpty {
            let spent = Dictionary(uniqueKeysWithValues: store.byCategory(in: range).map { ($0.cat.id, $0.total) })
            VStack(alignment: .leading, spacing: 14) {
                Text("Presupuestos").font(.headline)
                ForEach(cats) { c in
                    let s = spent[c.id] ?? 0
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("\(c.icon) \(c.name)").font(.subheadline.weight(.medium))
                            Spacer()
                            Text("\(Money.eur(s)) / \(Money.eur(c.budget))").font(.caption.weight(.semibold)).foregroundStyle(s > c.budget ? Color.red : Color.secondary)
                        }
                        ProgressBar(value: s / c.budget, color: s > c.budget ? .red : (s > c.budget * 0.8 ? .orange : Color(hex: c.color)))
                    }
                }
            }
            .card()
        }
    }

    private var topConcepts: some View {
        var m: [String: Double] = [:]
        for t in store.txs(in: range) where t.type == .expense && !t.excluded {
            m[t.title.isEmpty ? (store.category(t.categoryId)?.name ?? "Sin concepto") : t.title, default: 0] += t.amount
        }
        let top = m.sorted { $0.value > $1.value }.prefix(6)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Dónde más gastas").font(.headline)
            if top.isEmpty { Text("Sin gastos").foregroundStyle(.secondary) }
            ForEach(Array(top.enumerated()), id: \.element.key) { i, e in
                HStack {
                    Text("\(i + 1)").font(.caption.weight(.heavy)).frame(width: 24, height: 24).background(Color.primary.opacity(0.08), in: Circle())
                    Text(e.key).font(.subheadline).lineLimit(1)
                    Spacer()
                    AmountText(value: e.value, font: .subheadline.weight(.semibold))
                }
            }
        }
        .card()
    }
}
