import SwiftUI
import Charts

struct StatsView: View {
    @Environment(Store.self) private var store
    @State private var start: String = ""
    @State private var showIncome = false
    /// categoría resaltada en la rosquilla
    @State private var selectedCat: String? = nil
    /// categoría con el desglose abierto
    @State private var openCat: String? = nil
    @State private var angle: Double? = nil
    @State private var editing: Tx? = nil
    /// dentro de otra navegación (desde Inicio o Más) no lleva su propia barra
    var embedded = false

    var body: some View {
        if embedded { content } else { NavigationStack { content } }
    }

    private var content: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 18) {
                    periodBar
                    StatsKPIs(range: range).appear(0)
                    donut(proxy).appear(0.05)
                    StatsMonths(base: start.isEmpty ? store.periodStart(for: Day.today) : start).appear(0.1)
                    StatsBudgets(range: range).appear(0.15)
                    StatsTop(range: range).appear(0.2)
                    Color.clear.frame(height: 60)
                }
                .padding(.horizontal, 16)
            }
        }
        .appBackground()
        .navigationTitle("Análisis")
        .sheet(item: $editing) { TxEditor(original: $0) }
        .onAppear {
            if start.isEmpty { start = store.periodStart(for: Day.today) }
            // para las capturas de prueba: abre la primera categoría
            if ProcessInfo.processInfo.arguments.contains("-opencat"), openCat == nil,
               let c = store.byCategory(in: range).first { openCat = c.cat.id; selectedCat = c.cat.id }
        }
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
        withAnimation(Motion.layout) { start = Day.add(start, months: k); selectedCat = nil; openCat = nil }
    }

    private func donut(_ proxy: ScrollViewProxy) -> some View {
        let cats = store.byCategory(in: range, kind: showIncome ? .income : .expense)
        let total = cats.reduce(0) { $0 + $1.total }
        let sel = cats.first { $0.cat.id == selectedCat }
        return VStack(alignment: .leading, spacing: 14) {
            Picker("", selection: Binding(get: { showIncome }, set: { v in
                withAnimation(Motion.layout) { showIncome = v; selectedCat = nil; openCat = nil }
            })) {
                Text("Gastos").tag(false); Text("Ingresos").tag(true)
            }
            .pickerStyle(.segmented)
            if cats.isEmpty {
                Text("Nada en este periodo").foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 120)
            } else {
                ZStack {
                    Chart(cats) { c in
                        SectorMark(angle: .value("€", c.total), innerRadius: .ratio(0.64),
                                   outerRadius: .ratio(selectedCat == c.cat.id ? 1 : 0.94), angularInset: 2.5)
                            .cornerRadius(6)
                            .foregroundStyle(Color(hex: c.cat.color))
                            .opacity(selectedCat == nil || selectedCat == c.cat.id ? 1 : 0.3)
                    }
                    .chartAngleSelection(value: $angle)
                    .frame(height: 230)
                    .onChange(of: angle) { _, v in
                        // mientras se arrastra el dedo solo se resalta; el desglose se abre al soltar,
                        // así la lista de debajo no va dando saltos
                        guard let v else {
                            if openCat != selectedCat { withAnimation(Motion.layout) { openCat = selectedCat } }
                            return
                        }
                        var acc = 0.0
                        for c in cats {
                            acc += c.total
                            if v <= acc {
                                if selectedCat != c.cat.id { Haptic.select(); withAnimation(Motion.quick) { selectedCat = c.cat.id } }
                                break
                            }
                        }
                    }
                    VStack(spacing: 2) {
                        Text(sel.map { "\($0.cat.icon) \($0.cat.name)" } ?? "Total").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary).lineLimit(1)
                            .contentTransition(.opacity)
                        AmountText(value: sel?.total ?? total, font: .title2.weight(.bold))
                        if let sel {
                            Text("\(Money.num(sel.total / max(total, 0.01) * 100)) %").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                                .contentTransition(.numericText())
                                .transition(.opacity)
                        }
                    }
                    .frame(width: 130)
                    .allowsHitTesting(false)
                }
                VStack(spacing: 14) {
                    ForEach(cats) { c in
                        let open = openCat == c.cat.id
                        // la fila y su desglose van en una caja recortada: al abrir, la caja crece y va
                        // destapando el contenido (que ya está en su sitio) en vez de deslizarse por encima
                        VStack(spacing: 0) {
                            Button { toggle(c.cat.id, in: cats, proxy) } label: {
                                VStack(spacing: 6) {
                                    HStack {
                                        Text(c.cat.icon)
                                        Text(c.cat.name).font(.subheadline.weight(.medium))
                                        Spacer()
                                        AmountText(value: c.total, font: .subheadline.weight(.semibold))
                                        Image(systemName: "chevron.down").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
                                            .rotationEffect(.degrees(open ? 180 : 0))
                                    }
                                    ProgressBar(value: c.total / max(cats.first?.total ?? 1, 0.01), color: Color(hex: c.cat.color), height: 6)
                                }
                                .contentShape(Rectangle())
                                .opacity(selectedCat == nil || selectedCat == c.cat.id ? 1 : 0.45)
                            }
                            .buttonStyle(.plain)
                            if open {
                                CategoryBreakdown(range: range, catId: c.cat.id, kind: showIncome ? .income : .expense,
                                                  total: c.total, color: Color(hex: c.cat.color)) { editing = $0 }
                                    .padding(.top, 12)
                                    .transition(.opacity)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .top)
                        .clipped()
                        .id("cat-" + c.cat.id)
                    }
                }
            }
        }
        .card()
    }

    private func toggle(_ id: String, in cats: [CatTotal], _ proxy: ScrollViewProxy) {
        Haptic.select()
        let closing = openCat == id
        // si había otra abierta más arriba, al cerrarse la fila tocada se iría de debajo del dedo: se la sigue
        let follow = !closing && openCat != nil
            && (cats.firstIndex(where: { $0.cat.id == openCat }) ?? 0) < (cats.firstIndex(where: { $0.cat.id == id }) ?? 0)
        withAnimation(Motion.layout) {
            openCat = closing ? nil : id
            selectedCat = closing ? nil : id
            if follow { proxy.scrollTo("cat-" + id, anchor: UnitPoint(x: 0.5, y: 0.2)) }
        }
    }
}

/// Desglose de una categoría: por concepto y cada movimiento.
private struct CategoryBreakdown: View {
    @Environment(Store.self) private var store
    var range: ClosedRange<String>
    var catId: String
    var kind: TxType
    var total: Double
    var color: Color
    var onEdit: (Tx) -> Void
    @State private var showAll = false

    var body: some View {
        let list = store.txs(in: range).filter { $0.type == kind && !$0.excluded && ($0.categoryId ?? "") == catId }
            .sorted { ($0.date, $0.time) > ($1.date, $1.time) }
        var groups: [String: (Double, Int)] = [:]
        for t in list {
            let k = t.title.isEmpty ? "Sin concepto" : t.title
            let g = groups[k] ?? (0, 0)
            groups[k] = (g.0 + t.amount, g.1 + 1)
        }
        let concepts = groups.sorted { $0.value.0 != $1.value.0 ? $0.value.0 > $1.value.0 : $0.key < $1.key }
        let shown = showAll ? list : Array(list.prefix(8))
        return VStack(alignment: .leading, spacing: 12) {
            if concepts.count > 1 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("POR CONCEPTO").font(.caption2.weight(.heavy)).foregroundStyle(.secondary)
                    ForEach(concepts, id: \.key) { item in
                        let k = item.key, v = item.value
                        HStack(spacing: 8) {
                            Text(k).font(.subheadline).lineLimit(1)
                            if v.1 > 1 { Text("×\(v.1)").font(.caption.weight(.semibold)).foregroundStyle(.secondary) }
                            Spacer()
                            Text("\(Money.num(v.0 / max(total, 0.01) * 100)) %").font(.caption).foregroundStyle(.secondary)
                            AmountText(value: v.0, font: .subheadline.weight(.semibold))
                        }
                        ProgressBar(value: v.0 / max(concepts.first?.value.0 ?? 1, 0.01), color: color.opacity(0.7), height: 4)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("MOVIMIENTOS · \(list.count)").font(.caption2.weight(.heavy)).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(shown) { t in
                        Button { onEdit(t) } label: { TxRow(tx: t, showDate: true) }
                            .buttonStyle(.plain)
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .clipped()
                if list.count > 8 {
                    Button(showAll ? "Ver menos" : "Ver los \(list.count)") {
                        Haptic.tap()
                        withAnimation(Motion.layout) { showAll.toggle() }
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.top, 4)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct StatsMonths: View {
    @Environment(Store.self) private var store
    var base: String
    private struct MonthBar: Identifiable { var id: String { month + kind }; var month: String; var kind: String; var value: Double }

    var body: some View {
        var bars: [MonthBar] = []
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

}

private struct StatsBudgets: View {
    @Environment(Store.self) private var store
    var range: ClosedRange<String>

    @ViewBuilder var body: some View {
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

}

private struct StatsTop: View {
    @Environment(Store.self) private var store
    var range: ClosedRange<String>

    var body: some View {
        var m: [String: Double] = [:]
        for t in store.txs(in: range) where t.type == .expense && !t.excluded {
            m[t.title.isEmpty ? (store.category(t.categoryId)?.name ?? "Sin concepto") : t.title, default: 0] += t.amount
        }
        let top = m.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.prefix(6)
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

private struct StatsKPIs: View {
    @Environment(Store.self) private var store
    var range: ClosedRange<String>

    var body: some View {
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
}
