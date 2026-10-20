import SwiftUI

struct TransactionsView: View {
    @Environment(Store.self) private var store
    @State private var search = ""
    @State private var month: String = Day.monthKey(Day.today)
    @State private var typeFilter: TxType? = nil
    @State private var accountFilter: String? = nil
    @State private var editing: Tx? = nil
    @State private var pendingDelete: Tx? = nil
    @State private var askDelete = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    monthPicker
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    summary
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                }
                ForEach(groups, id: \.day) { g in
                    Section {
                        ForEach(g.items) { t in
                            Button { editing = t } label: { TxRow(tx: t) }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button {
                                        Haptic.warning()
                                        pendingDelete = t
                                        askDelete = true
                                    } label: { Label("Eliminar", systemImage: "trash.fill") }
                                    .tint(.red)
                                    Button {
                                        Haptic.tap(); store.duplicate(t)
                                    } label: { Label("Duplicar", systemImage: "plus.square.on.square") }
                                    .tint(.indigo)
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button { editing = t } label: { Label("Editar", systemImage: "pencil") }
                                        .tint(.accentColor)
                                }
                                .contextMenu {
                                    Button { editing = t } label: { Label("Editar", systemImage: "pencil") }
                                    Button { store.duplicate(t) } label: { Label("Duplicar", systemImage: "plus.square.on.square") }
                                    Button(role: .destructive) { pendingDelete = t; askDelete = true } label: { Label("Eliminar", systemImage: "trash") }
                                }
                        }
                    } header: {
                        HStack {
                            Text(Day.header(g.day)).font(.headline).foregroundStyle(.primary).textCase(nil)
                            Spacer()
                            AmountText(value: g.total, signed: true, font: .subheadline.weight(.semibold), color: .secondary)
                        }
                    }
                }
                if groups.isEmpty {
                    ContentUnavailableView(search.isEmpty ? "Sin movimientos" : "Sin resultados",
                                           systemImage: search.isEmpty ? "tray" : "magnifyingglass",
                                           description: nil)
                        .listRowBackground(Color.clear)
                }
                Color.clear.frame(height: 70).listRowBackground(Color.clear)
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Movimientos")
            .searchable(text: $search, prompt: "Buscar concepto, nota o importe")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { filterMenu }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: month)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: typeFilter)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: accountFilter)
            .sheet(item: $editing) { TxEditor(original: $0) }
            .task {
                if ProcessInfo.processInfo.arguments.contains("-askdelete"), let t = groups.first?.items.first {
                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                    pendingDelete = t; askDelete = true
                }
            }
            .confirmationDialog(deleteTitle, isPresented: $askDelete, titleVisibility: .visible, presenting: pendingDelete) { t in
                Button("Eliminar", role: .destructive) {
                    Haptic.heavy()
                    store.delete(t)
                    pendingDelete = nil
                }
                Button("Cancelar", role: .cancel) { pendingDelete = nil }
            } message: { t in
                Text("\(t.title.isEmpty ? t.type.label : t.title) · \(Money.eur(abs(t.amount))) · \(Day.header(t.date)). Podrás deshacerlo justo después.")
            }
        }
    }

    private var deleteTitle: String {
        switch pendingDelete?.type {
        case .income: return "¿Seguro que quieres eliminar este ingreso?"
        case .transfer: return "¿Seguro que quieres eliminar esta transferencia?"
        case .adjust: return "¿Seguro que quieres eliminar este ajuste?"
        default: return "¿Seguro que quieres eliminar este gasto?"
        }
    }

    // MARK: datos

    private struct DayGroup { var day: String; var items: [Tx]; var total: Double }

    private var filtered: [Tx] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        return store.state.txs.filter { t in
            if q.isEmpty && Day.monthKey(t.date) != month { return false }
            if let typeFilter, t.type != typeFilter { return false }
            if let accountFilter, t.accountId != accountFilter && t.toAccountId != accountFilter { return false }
            if !q.isEmpty {
                let cat = store.category(t.categoryId)?.name.lowercased() ?? ""
                let hay = (t.title + " " + t.note).lowercased()
                let amount = Money.num(t.amount)
                if !hay.contains(q) && !cat.contains(q) && !amount.contains(q) { return false }
            }
            return true
        }
        .sorted { $0.sortKey > $1.sortKey }
    }

    private var groups: [DayGroup] {
        var out: [DayGroup] = []
        for t in filtered {
            let v: Double
            switch t.type {
            case .expense: v = -t.amount
            case .income, .adjust: v = t.amount
            case .transfer: v = accountFilter == nil ? 0 : (t.toAccountId == accountFilter ? t.amount : -t.amount)
            }
            if let i = out.firstIndex(where: { $0.day == t.date }) { out[i].items.append(t); out[i].total += v }
            else { out.append(DayGroup(day: t.date, items: [t], total: v)) }
        }
        return out
    }

    private var months: [String] {
        let keys = Set(store.state.txs.map { Day.monthKey($0.date) }).union([Day.monthKey(Day.today)])
        return keys.sorted()
    }

    // MARK: cabecera

    private var monthPicker: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(months, id: \.self) { m in
                        Button {
                            Haptic.select()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { month = m }
                        } label: {
                            Text(Day.month(m + "-01"))
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 16).padding(.vertical, 9)
                                .foregroundStyle(month == m ? Color.black : Color.primary)
                                .background {
                                    if month == m { Capsule().fill(Color.accentColor) }
                                    else { Capsule().fill(Color.white.opacity(0.07)) }
                                }
                        }
                        .buttonStyle(PressableStyle())
                        .id(m)
                    }
                }
                .padding(.horizontal, 4)
            }
            .onAppear { proxy.scrollTo(month, anchor: .trailing) }
        }
        .opacity(search.isEmpty ? 1 : 0.35)
    }

    private var summary: some View {
        let list = filtered
        let out = list.filter { $0.type == .expense && !$0.excluded }.reduce(0) { $0 + $1.amount }
        let inc = list.filter { $0.type == .income && !$0.excluded }.reduce(0) { $0 + $1.amount }
        return HStack(spacing: 10) {
            pill("Gastos", out, .negative, "arrow.down")
            pill("Ingresos", inc, .income, "arrow.up")
        }
    }
    private func pill(_ label: String, _ v: Double, _ c: Color, _ icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.caption.weight(.heavy)).foregroundStyle(c)
                .frame(width: 26, height: 26).background(c.opacity(0.18), in: Circle())
            VStack(alignment: .leading, spacing: 0) {
                Text(label).font(.caption).foregroundStyle(.secondary)
                AmountText(value: v, font: .subheadline.weight(.bold))
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.cardBG, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var filterMenu: some View {
        Menu {
            Picker("Tipo", selection: $typeFilter) {
                Text("Todo").tag(TxType?.none)
                ForEach(TxType.allCases) { Text($0.label).tag(TxType?.some($0)) }
            }
            Picker("Cuenta", selection: $accountFilter) {
                Text("Todas las cuentas").tag(String?.none)
                ForEach(store.accounts) { Text("\($0.icon) \($0.name)").tag(String?.some($0.id)) }
            }
        } label: {
            Image(systemName: typeFilter == nil && accountFilter == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                .contentTransition(.symbolEffect(.replace))
        }
    }
}
