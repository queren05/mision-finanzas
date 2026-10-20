import SwiftUI
import Charts

struct HomeView: View {
    @Environment(Store.self) private var store
    @Binding var tab: MainTab
    @State private var selected: Date? = nil
    @State private var editing: Tx? = nil
    @State private var showStats = false
    @State private var showWork = false
    @State private var customizing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    ForEach(Array(store.state.home.filter(\.on).enumerated()), id: \.element.id) { i, item in
                        card(item.id).appear(Double(min(i, 6)) * 0.04)
                    }
                    Button { Haptic.tap(); customizing = true } label: {
                        Label("Personalizar inicio", systemImage: "square.grid.2x2")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Color.cardBG, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(PressableStyle())
                    Color.clear.frame(height: 80)
                }
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: store.state.home)
                .padding(.horizontal, 16)
            }
            .background(Color(.systemGroupedBackground))
            .refreshable { await Prices.refresh(store) }
            .navigationTitle(greeting)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptic.tap()
                        withAnimation(.snappy) { store.hideAmounts.toggle() }
                    } label: {
                        Image(systemName: store.hideAmounts ? "eye.slash.fill" : "eye.fill")
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
            }
            .navigationDestination(for: Account.self) { AccountDetail(accountId: $0.id) }
            .navigationDestination(isPresented: $showStats) { StatsView(embedded: true) }
            .navigationDestination(isPresented: $showWork) { WorkView() }
            .task { if ProcessInfo.processInfo.arguments.contains("-work") { showWork = true } }
            .sheet(item: $editing) { TxEditor(original: $0) }
            .sheet(isPresented: $customizing) { HomeCustomizer() }
            .task { if ProcessInfo.processInfo.arguments.contains("-customize") { customizing = true } }
        }
    }

    @ViewBuilder private func card(_ id: String) -> some View {
        switch id {
        case "patrimonio": hero
        case "cuentas": accountsStrip
        case "horas": if !store.state.companies.isEmpty { WorkCard { showWork = true } }
        case "mes": monthCard
        case "categorias": categoriesCard
        case "proximos": upcomingCard
        case "recientes": recentCard
        case "inversiones": investCard
        case "deudas": debtsCard
        default: EmptyView()
        }
    }

    // MARK: inversiones

    @ViewBuilder private var investCard: some View {
        let assets = store.state.assets.filter { !$0.archived }.sorted { store.assetValue($0) > store.assetValue($1) }
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Inversiones", action: "Ver") { tab = .invest }
            HStack {
                AmountText(value: store.investValue, font: .title2.weight(.bold))
                Spacer()
            }
            if assets.isEmpty { Text("Sin inversiones").foregroundStyle(.secondary) }
            ForEach(assets.prefix(4)) { a in
                HStack {
                    Text(a.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                    Spacer()
                    if let ch = store.dayChange(a) {
                        Text((ch >= 0 ? "+" : "") + Money.num(ch) + " %").font(.caption.weight(.bold)).foregroundStyle(ch >= 0 ? Color.income : Color.negative)
                    }
                    AmountText(value: store.assetValue(a), font: .subheadline.weight(.semibold))
                }
            }
        }
        .card()
    }

    // MARK: cuentas claras

    @ViewBuilder private var debtsCard: some View {
        let people = store.peopleSorted.filter { abs(store.debtBalance($0.id)) > 0.004 }
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Cuentas claras", action: "Ver") { tab = .debts }
            HStack(spacing: 12) {
                tile("Te deben", store.owedToMe, "arrow.down.left.circle.fill", .income)
                tile("Debes", store.iOwe, "arrow.up.right.circle.fill", .negative)
            }
            ForEach(people.prefix(4)) { p in
                let b = store.debtBalance(p.id)
                HStack {
                    Text(p.emoji); Text(p.name).font(.subheadline.weight(.semibold))
                    Spacer()
                    AmountText(value: b, signed: true, font: .subheadline.weight(.semibold), color: b >= 0 ? .income : .negative)
                }
            }
        }
        .card()
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        let s = h < 6 ? "Buenas noches" : h < 14 ? "Buenos días" : h < 21 ? "Buenas tardes" : "Buenas noches"
        return "\(s), \(store.state.settings.name)"
    }

    // MARK: patrimonio con gráfico de 30 días

    private var hero: some View {
        let series = store.netWorthSeries(days: 30)
        let first = series.first?.value ?? 0
        let now = store.netWorth
        let point = selected.flatMap { s in series.min(by: { abs($0.date.timeIntervalSince(s)) < abs($1.date.timeIntervalSince(s)) }) }
        let diff = now - first
        return VStack(alignment: .leading, spacing: 6) {
            Text(point.map { Day.header(Day.str($0.date)) } ?? "Patrimonio")
                .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            AmountText(value: point?.value ?? now, font: .system(size: 44, weight: .bold, design: .rounded))
            HStack(spacing: 6) {
                Image(systemName: diff >= 0 ? "arrow.up.right" : "arrow.down.right")
                AmountText(value: diff, signed: true, font: .subheadline.weight(.semibold), color: diff >= 0 ? .income : .negative)
                Text("en 30 días").font(.subheadline).foregroundStyle(.secondary)
            }
            .foregroundStyle(diff >= 0 ? Color.income : Color.negative)
            Chart(series) { p in
                AreaMark(x: .value("Día", p.date), y: .value("€", p.value))
                    .foregroundStyle(LinearGradient(colors: [Color.accentColor.opacity(0.45), Color.accentColor.opacity(0.0)], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.monotone)
                LineMark(x: .value("Día", p.date), y: .value("€", p.value))
                    .foregroundStyle(Color.accentColor)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    .interpolationMethod(.monotone)
                if let point, point.date == p.date {
                    RuleMark(x: .value("Día", p.date)).foregroundStyle(.white.opacity(0.35))
                    PointMark(x: .value("Día", p.date), y: .value("€", p.value)).symbolSize(90).foregroundStyle(.white)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: .automatic(includesZero: false))
            .chartXSelection(value: $selected)
            .frame(height: 130)
            .padding(.top, 8)
            .onChange(of: selected) { _, v in if v != nil { Haptic.select() } }
            HStack {
                stat("Efectivo", store.cashTotal)
                Divider().frame(height: 30)
                stat("Inversiones", store.investValue)
            }
            .padding(.top, 6)
        }
        .card(20)
    }

    private func stat(_ label: String, _ v: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            AmountText(value: v, font: .headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: cuentas en tarjetas

    private var accountsStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Cuentas")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(store.accounts) { a in
                        NavigationLink(value: a) {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(a.icon).font(.title2)
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.white.opacity(0.6))
                                }
                                Spacer(minLength: 0)
                                Text(a.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white.opacity(0.85)).lineLimit(1)
                                AmountText(value: store.value(a), font: .title3.weight(.bold), color: .white)
                            }
                            .padding(16)
                            .frame(width: 168, height: 128)
                            .background(
                                LinearGradient(colors: [Color(hex: a.color).opacity(0.95), Color(hex: a.color).opacity(0.45)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.15)))
                        }
                        .buttonStyle(PressableStyle())
                        .scrollTransition { c, phase in
                            c.scaleEffect(phase.isIdentity ? 1 : 0.92).opacity(phase.isIdentity ? 1 : 0.6)
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
        }
    }

    // MARK: el mes

    private var monthCard: some View {
        let start = store.periodStart(for: Day.today)
        let r = store.periodRange(start)
        let prevR = store.periodRange(Day.add(start, months: -1))
        let spent = store.spent(in: r), earned = store.earned(in: r)
        let prevSpent = store.spent(in: prevR)
        let budget = store.state.categories.filter { $0.kind == .expense }.reduce(0) { $0 + $1.budget }
        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: Day.month(start))
            HStack(spacing: 12) {
                tile("Gastado", spent, "arrow.down.circle.fill", .negative)
                tile("Ingresado", earned, "arrow.up.circle.fill", .income)
            }
            HStack {
                Text("Balance del mes").foregroundStyle(.secondary)
                Spacer()
                AmountText(value: earned - spent, signed: true, font: .headline, color: earned - spent >= 0 ? .income : .negative)
            }
            if prevSpent > 0 {
                let pct = (spent / prevSpent - 1) * 100
                Label(pct <= 0 ? "Llevas un \(Money.num(-pct)) % menos que el mes pasado" : "Llevas un \(Money.num(pct)) % más que el mes pasado",
                      systemImage: pct <= 0 ? "hand.thumbsup.fill" : "exclamationmark.triangle.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(pct <= 0 ? Color.income : Color.orange)
            }
            if budget > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Presupuesto").font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(Money.eur(spent)) de \(Money.eur(budget))").font(.caption).foregroundStyle(.secondary)
                    }
                    ProgressBar(value: spent / budget, color: spent > budget ? .red : .accentColor)
                }
            }
        }
        .card()
    }

    private func tile(_ label: String, _ v: Double, _ icon: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).font(.title2).foregroundStyle(color)
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            AmountText(value: v, font: .title3.weight(.bold))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: en qué se va el dinero

    private var categoriesCard: some View {
        let r = store.periodRange(store.periodStart(for: Day.today))
        let cats = Array(store.byCategory(in: r).prefix(6))
        let total = cats.reduce(0) { $0 + $1.total }
        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "En qué gastas", action: "Análisis") { showStats = true }
            if cats.isEmpty {
                Text("Aún no hay gastos este mes").foregroundStyle(.secondary)
            } else {
                HStack(spacing: 18) {
                    Chart(cats) { c in
                        SectorMark(angle: .value("€", c.total), innerRadius: .ratio(0.62), angularInset: 2)
                            .cornerRadius(5)
                            .foregroundStyle(Color(hex: c.cat.color))
                    }
                    .frame(width: 120, height: 120)
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(cats.prefix(4))) { c in
                            HStack(spacing: 8) {
                                Text(c.cat.icon)
                                Text(c.cat.name).font(.subheadline).lineLimit(1)
                                Spacer(minLength: 4)
                                Text("\(Int((c.total / max(total, 0.01) * 100).rounded())) %").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .card()
    }

    // MARK: próximos cargos

    @ViewBuilder private var upcomingCard: some View {
        let up = Array(store.upcoming(days: 21).prefix(4))
        if !up.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Próximos cargos")
                ForEach(up) { u in
                    HStack(spacing: 12) {
                        Image(systemName: u.r.type == "invest" ? "chart.line.uptrend.xyaxis.circle.fill" : "calendar.circle.fill")
                            .font(.title).foregroundStyle(u.r.type == "invest" ? Color.income : Color.accentColor)
                        VStack(alignment: .leading) {
                            Text(u.r.name).font(.body.weight(.semibold))
                            Text(Day.header(u.date)).font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        AmountText(value: -u.r.amount, font: .body.weight(.semibold))
                    }
                }
            }
            .card()
        }
    }

    // MARK: últimos movimientos

    private var recentCard: some View {
        let recent = Array(store.state.txs.sorted { $0.sortKey > $1.sortKey }.prefix(6))
        return VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Últimos movimientos", action: "Ver todos") { tab = .txs }
            ForEach(recent) { t in
                Button { editing = t } label: { TxRow(tx: t, showDate: true) }
                    .buttonStyle(.plain)
                    .transition(.asymmetric(insertion: .push(from: .top), removal: .opacity))
                if t.id != recent.last?.id { Divider().padding(.leading, 58) }
            }
        }
        .card()
    }
}


/// elige qué tarjetas salen en Inicio y en qué orden
struct HomeCustomizer: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section("En inicio") {
                    ForEach(store.state.home.filter(\.on)) { item in row(item) }
                        .onMove { from, to in move(from, to, on: true) }
                }
                Section("Añadir") {
                    let off = store.state.home.filter { !$0.on }
                    if off.isEmpty { Text("Ya está todo en inicio").foregroundStyle(.secondary) }
                    ForEach(off) { item in row(item) }
                }
                Section {
                    Button("Restablecer") { Haptic.warning(); withAnimation { store.state.home = HomeItem.defaults } }
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Personalizar inicio").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Listo") { Haptic.success(); dismiss() }.bold() } }
        }
    }

    private func row(_ item: HomeItem) -> some View {
        let info = HomeItem.info(item.id)
        return HStack(spacing: 12) {
            Button {
                Haptic.select()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    if let i = store.state.home.firstIndex(where: { $0.id == item.id }) {
                        var h = store.state.home
                        var it = h.remove(at: i); it.on.toggle()
                        // al añadir, va al final de lo que se ve
                        if it.on { h.insert(it, at: (h.lastIndex(where: \.on) ?? -1) + 1) } else { h.append(it) }
                        store.state.home = h
                    }
                }
            } label: {
                Image(systemName: item.on ? "minus.circle.fill" : "plus.circle.fill")
                    .font(.title2).foregroundStyle(item.on ? Color.red : Color.green)
            }
            .buttonStyle(.plain)
            Image(systemName: info.icon).foregroundStyle(Color.accentColor).frame(width: 26)
            Text(info.name)
        }
    }

    private func move(_ from: IndexSet, _ to: Int, on: Bool) {
        var visible = store.state.home.filter(\.on)
        visible.move(fromOffsets: from, toOffset: to)
        store.state.home = visible + store.state.home.filter { !$0.on }
        Haptic.select()
    }
}
