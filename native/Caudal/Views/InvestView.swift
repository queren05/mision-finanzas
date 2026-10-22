import SwiftUI
import Charts

struct InvestView: View {
    @Environment(Store.self) private var store
    @State private var adding = false
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header.appear(0)
                    if !assets.isEmpty { allocation.appear(0.05) }
                    VStack(spacing: 10) {
                        ForEach(Array(assets.enumerated()), id: \.element.id) { i, a in
                            NavigationLink(value: a) { AssetRow(asset: a) }
                                .buttonStyle(PressableStyle(scale: 0.97))
                                .appear(0.08 + Double(i) * 0.04)
                        }
                    }
                    if assets.isEmpty {
                        ContentUnavailableView("Sin inversiones", systemImage: "chart.line.uptrend.xyaxis", description: Text("Añade tus acciones, ETF o cripto con el botón +."))
                    }
                    Color.clear.frame(height: 60)
                }
                .padding(.horizontal, 16)
            }
            .appBackground()
            .navigationTitle("Inversiones")
            .refreshable { await Prices.refresh(store) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if store.refreshing { ProgressView() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { adding = true } label: { Image(systemName: "plus") }
                }
            }
            .navigationDestination(for: Asset.self) { AssetDetail(assetId: $0.id) }
            .sheet(isPresented: $adding) { AssetEditor() }
            .onReceive(timer) { _ in Task { await Prices.refresh(store) } }
        }
    }

    private var assets: [Asset] { store.state.assets.filter { !$0.archived }.sorted { store.assetValue($0) > store.assetValue($1) } }

    private var header: some View {
        let value = store.investValue, cost = store.investCost
        let gain = value - cost
        let pct = cost > 0 ? gain / cost * 100 : 0
        let today = assets.reduce(0.0) { acc, a in
            guard let q = store.state.quotes[a.ySymbol], q.previousClose > 0 else { return acc }
            return acc + store.position(a).qty * (q.price - q.previousClose)
        }
        return VStack(alignment: .leading, spacing: 8) {
            Text("Cartera").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            AmountText(value: value, font: .system(size: 42, weight: .bold, design: .rounded))
            HStack(spacing: 14) {
                VStack(alignment: .leading) {
                    Text("Rentabilidad").font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        AmountText(value: gain, signed: true, font: .headline, color: gain >= 0 ? .income : .negative)
                        Text(Money.pct(pct)).font(.caption.weight(.bold)).foregroundStyle(gain >= 0 ? Color.income : Color.negative)
                    }
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Hoy").font(.caption).foregroundStyle(.secondary)
                    AmountText(value: today, signed: true, font: .headline, color: today >= 0 ? .income : .negative)
                }
            }
            Text("Invertido: \(Money.eur(cost))").font(.footnote).foregroundStyle(.secondary)
        }
        .card(20)
    }

    private var allocation: some View {
        let total = max(store.investValue, 0.01)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Reparto").font(.headline)
            GeometryReader { g in
                HStack(spacing: 3) {
                    ForEach(assets) { a in
                        RoundedRectangle(cornerRadius: 4).fill(Color(hex: a.color))
                            .frame(width: max(4, (g.size.width - CGFloat(assets.count) * 3) * store.assetValue(a) / total))
                    }
                }
            }
            .frame(height: 14)
            .clipShape(Capsule())
            ForEach(assets) { a in
                HStack {
                    Circle().fill(Color(hex: a.color)).frame(width: 10, height: 10)
                    Text(a.name).font(.subheadline).lineLimit(1)
                    Spacer()
                    Text("\(Money.num(store.assetValue(a) / total * 100)) %").font(.subheadline.weight(.semibold)).monospacedDigit()
                }
            }
        }
        .card()
    }
}

struct AssetRow: View {
    @Environment(Store.self) private var store
    var asset: Asset
    @State private var flash: Color? = nil
    var body: some View {
        let pos = store.position(asset)
        let value = store.assetValue(asset)
        let gain = value - pos.cost
        HStack(spacing: 14) {
            Text(String(asset.symbol.prefix(4)))
                .font(.caption.weight(.heavy))
                .frame(width: 48, height: 48)
                .background(Color(hex: asset.color).opacity(0.25), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .foregroundStyle(Color(hex: asset.color))
            VStack(alignment: .leading, spacing: 3) {
                Text(asset.name).font(.body.weight(.semibold)).lineLimit(1).foregroundStyle(.primary)
                HStack(spacing: 6) {
                    Text(Money.eur(store.price(asset))).monospacedDigit()
                    if let ch = store.dayChange(asset) {
                        Text(Money.pct(ch)).foregroundStyle(ch >= 0 ? Color.income : Color.negative).fontWeight(.semibold)
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                AmountText(value: value, font: .body.weight(.bold))
                AmountText(value: gain, signed: true, font: .caption.weight(.semibold), color: gain >= 0 ? .income : .negative)
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.cardBG)
            if let flash { RoundedRectangle(cornerRadius: 20, style: .continuous).fill(flash.opacity(0.25)) }
        }
        .onChange(of: store.price(asset)) { old, new in
            guard old != new else { return }
            withAnimation(.easeOut(duration: 0.15)) { flash = new > old ? .income : .negative }
            withAnimation(.easeIn(duration: 0.9).delay(0.3)) { flash = nil }
        }
    }
}

struct AssetDetail: View {
    @Environment(Store.self) private var store
    let assetId: String
    @State private var range = "1mo"
    @State private var points: [PricePoint] = []
    @State private var loading = false
    @State private var selected: Date? = nil
    @State private var addOp = false
    @State private var editing = false

    private let ranges: [ChartRange] = [ChartRange(label: "1S", range: "5d", interval: "30m"), ChartRange(label: "1M", range: "1mo", interval: "1d"), ChartRange(label: "3M", range: "3mo", interval: "1d"), ChartRange(label: "1A", range: "1y", interval: "1d"), ChartRange(label: "5A", range: "5y", interval: "1wk")]

    var body: some View {
        if let a = store.asset(assetId) {
            content(a)
        } else {
            ContentUnavailableView("Inversión eliminada", systemImage: "trash")
        }
    }

    private func content(_ a: Asset) -> some View {
        let pos = store.position(a)
        let value = store.assetValue(a)
        let first = points.first?.close ?? store.price(a)
        let point = selected.flatMap { s in points.min(by: { abs($0.date.timeIntervalSince(s)) < abs($1.date.timeIntervalSince(s)) }) }
        let shown = point?.close ?? store.price(a)
        let ch = (shown / max(first, 0.0001) - 1) * 100
        let up = ch >= 0
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(point.map { Day.header(Day.str($0.date)) } ?? "Precio").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    Text(Money.eur(shown)).font(.system(size: 40, weight: .bold, design: .rounded)).monospacedDigit()
                        .contentTransition(.numericText(value: shown))
                    Text(Money.pct(ch)).font(.headline).foregroundStyle(up ? Color.income : Color.negative)
                }
                ZStack {
                    Chart(points) { p in
                        AreaMark(x: .value("Fecha", p.date), y: .value("Precio", p.close))
                            .foregroundStyle(LinearGradient(colors: [(up ? Color.income : Color.negative).opacity(0.35), .clear], startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.monotone)
                        LineMark(x: .value("Fecha", p.date), y: .value("Precio", p.close))
                            .foregroundStyle(up ? Color.income : Color.negative)
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .interpolationMethod(.monotone)
                        if let point, point.date == p.date {
                            RuleMark(x: .value("Fecha", p.date)).foregroundStyle(Color.primary.opacity(0.35))
                            PointMark(x: .value("Fecha", p.date), y: .value("Precio", p.close)).foregroundStyle(Color.primary)
                        }
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .chartXAxis(.hidden)
                    .chartXSelection(value: $selected)
                    .onChange(of: selected) { _, v in if v != nil { Haptic.select() } }
                    if loading { ProgressView() }
                }
                .frame(height: 220)
                .animation(.easeInOut(duration: 0.35), value: points.count)
                HStack(spacing: 6) {
                    ForEach(ranges) { r in
                        Button {
                            Haptic.select(); range = r.range
                        } label: {
                            Text(r.label).font(.subheadline.weight(.bold)).frame(maxWidth: .infinity).padding(.vertical, 8)
                                .foregroundStyle(range == r.range ? Color.black : Color.primary)
                                .background(range == r.range ? Color.accentColor : Color.cardBG, in: Capsule())
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                VStack(spacing: 12) {
                    row("Valor", Money.eur(value))
                    row("Participaciones", Money.num(pos.qty))
                    row("Precio medio", Money.eur(pos.qty > 0 ? pos.cost / pos.qty : 0))
                    row("Invertido", Money.eur(pos.cost))
                    row("Rentabilidad", "\(Money.signed(value - pos.cost)) (\(Money.pct(pos.cost > 0 ? (value / pos.cost - 1) * 100 : 0)))")
                    if pos.realized != 0 { row("Realizada", Money.signed(pos.realized)) }
                    if !a.isin.isEmpty { row("ISIN", a.isin) }
                    row("Símbolo", a.ySymbol)
                }
                .card()
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Operaciones").font(.headline)
                        Spacer()
                        Button { addOp = true } label: { Label("Añadir", systemImage: "plus.circle.fill") }
                    }
                    ForEach(a.ops.sorted { $0.date > $1.date }) { op in
                        HStack {
                            Image(systemName: op.side == .sell ? "arrow.up.right.circle.fill" : "arrow.down.left.circle.fill")
                                .foregroundStyle(op.side == .sell ? Color.negative : Color.income).font(.title2)
                            VStack(alignment: .leading) {
                                Text("\(op.side.label) · \(Money.num(op.qty))").font(.subheadline.weight(.semibold))
                                Text("\(Day.header(op.date)) · \(Money.eur(op.price))").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(Money.eur(op.qty * op.price)).font(.subheadline.weight(.semibold)).monospacedDigit()
                        }
                    }
                }
                .card()
            }
            .padding(16)
        }
        .appBackground()
        .navigationTitle(a.symbol)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Editar") { editing = true } } }
        .sheet(isPresented: $addOp) { OpEditor(assetId: a.id) }
        .sheet(isPresented: $editing) { AssetEditor(original: a) }
        .task(id: range) { await load(a) }
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack { Text(k).foregroundStyle(.secondary); Spacer(); Text(v).fontWeight(.semibold).monospacedDigit() }
    }

    private func load(_ a: Asset) async {
        loading = true
        defer { loading = false }
        let r = ranges.first { $0.range == range } ?? ranges[1]
        if let c = try? await Prices.chart(a.ySymbol, range: r.range, interval: r.interval) {
            withAnimation(.easeInOut(duration: 0.4)) { points = c.points.map { PricePoint(date: $0.date, close: $0.close) } }
            if range == "1mo" || range == "5d" { store.state.quotes[a.ySymbol] = c.quote }
        }
    }
}

struct ChartRange: Identifiable { var label: String; var range: String; var interval: String; var id: String { range } }
struct PricePoint: Identifiable { var date: Date; var close: Double; var id: Date { date } }

/// nueva compra o venta de un activo
struct OpEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let assetId: String
    @State private var side: OpSide = .buy
    @State private var amount = ""
    @State private var price = ""
    @State private var fee = ""
    @State private var date = Date()
    @State private var cashAccount = ""

    var body: some View {
        NavigationStack {
            Form {
                Picker("Tipo", selection: $side) { ForEach(OpSide.allCases) { Text($0.label).tag($0) } }.pickerStyle(.segmented)
                Section("Operación") {
                    LabeledContent("Importe (€)") { TextField("100", text: $amount).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    LabeledContent("Precio por unidad") { TextField("0", text: $price).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    LabeledContent("Comisión") { TextField("0", text: $fee).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    DatePicker("Fecha", selection: $date, displayedComponents: .date)
                }
                Section("Dinero") {
                    Picker("Cuenta", selection: $cashAccount) {
                        Text("Sin mover dinero").tag("")
                        ForEach(store.accounts) { Text("\($0.icon) \($0.name)").tag($0.id) }
                    }
                }
            }
            .navigationTitle("Operación")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Guardar") { save() }.bold() }
            }
            .onAppear {
                if let a = store.asset(assetId) { price = Money.num(store.price(a)).replacingOccurrences(of: ".", with: "") }
            }
        }
    }

    private func save() {
        guard let a = store.asset(assetId), let total = Money.parse(amount), let p = Money.parse(price), p > 0 else { Haptic.warning(); return }
        var n = a
        n.ops.append(AssetOp(side: side, qty: total / p, price: p, fee: Money.parse(fee) ?? 0, date: Day.str(date), cashAccountId: cashAccount.isEmpty ? nil : cashAccount))
        store.save(n)
        Haptic.success()
        dismiss()
    }
}

/// alta o edición de un activo
struct AssetEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    var original: Asset? = nil
    @State private var kind = "stock"
    @State private var name = ""
    @State private var symbol = ""
    @State private var ySymbol = ""
    @State private var isin = ""
    @State private var accountId = ""
    @State private var color = palette[2]
    @State private var checking = false
    @State private var found: Double? = nil
    @State private var askDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Picker("Tipo", selection: $kind) { Text("Acción / ETF").tag("stock"); Text("Cripto").tag("crypto") }.pickerStyle(.segmented)
                Section {
                    TextField("Nombre (p. ej. MSCI World)", text: $name)
                    TextField(kind == "crypto" ? "Símbolo (BTC, ETH…)" : "Símbolo corto", text: $symbol).textInputAutocapitalization(.characters)
                    TextField(kind == "crypto" ? "Yahoo (BTC-EUR)" : "Símbolo de Yahoo (IUSQ.DE, AAPL…)", text: $ySymbol)
                        .textInputAutocapitalization(.characters).autocorrectionDisabled()
                    if kind == "stock" { TextField("ISIN (opcional)", text: $isin).textInputAutocapitalization(.characters) }
                    HStack {
                        Button("Comprobar precio") { Task { await check() } }
                        Spacer()
                        if checking { ProgressView() }
                        if let found { Text(Money.eur(found)).foregroundStyle(Color.income).bold() }
                    }
                }
                Section("Cuenta") {
                    Picker("Cuenta", selection: $accountId) {
                        Text("Ninguna").tag("")
                        ForEach(store.accounts) { Text("\($0.icon) \($0.name)").tag($0.id) }
                    }
                }
                Section("Color") { ColorRow(color: $color) }
                if original != nil {
                    Section {
                        Button("Eliminar inversión", role: .destructive) { askDelete = true }
                    }
                }
            }
            .navigationTitle(original == nil ? "Nueva inversión" : "Editar inversión")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Guardar") { save() }.bold().disabled(name.isEmpty || effectiveY.isEmpty) }
            }
            .confirmationDialog("¿Seguro que quieres eliminar esta inversión?", isPresented: $askDelete, titleVisibility: .visible) {
                Button("Eliminar", role: .destructive) {
                    if let o = original { store.state.assets.removeAll { $0.id == o.id } }
                    dismiss()
                }
            } message: { Text("Se borrarán también sus operaciones.") }
            .onAppear {
                guard let o = original else { accountId = store.accounts.first { $0.type == .broker }?.id ?? ""; return }
                kind = o.kind; name = o.name; symbol = o.symbol; ySymbol = o.ySymbol; isin = o.isin; accountId = o.accountId ?? ""; color = o.color
            }
        }
    }

    private var effectiveY: String {
        let y = ySymbol.trimmingCharacters(in: .whitespaces)
        if !y.isEmpty { return y }
        return kind == "crypto" && !symbol.isEmpty ? symbol.uppercased() + "-EUR" : symbol
    }

    private func check() async {
        checking = true; found = nil
        found = try? await Prices.chart(effectiveY, range: "5d").quote.price
        checking = false
        if found != nil { Haptic.success() } else { Haptic.warning() }
    }

    private func save() {
        var a = original ?? Asset(symbol: "", ySymbol: "", name: "")
        a.kind = kind; a.name = name; a.symbol = symbol.isEmpty ? effectiveY : symbol; a.ySymbol = effectiveY; a.isin = isin
        a.accountId = accountId.isEmpty ? nil : accountId; a.color = color
        if let found { a.manualPrice = found }
        store.save(a)
        Task { await Prices.refresh(store) }
        Haptic.success()
        dismiss()
    }
}
