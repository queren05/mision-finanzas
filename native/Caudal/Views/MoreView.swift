import SwiftUI
import UniformTypeIdentifiers

struct MoreView: View {
    @Environment(Store.self) private var store
    @State private var importing = false
    @State private var message: String? = nil
    @State private var askReset = false
    @State private var askErase = false

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Text(String(store.state.settings.name.prefix(1)))
                            .font(.title.weight(.bold)).foregroundStyle(.black)
                            .frame(width: 58, height: 58).background(Color.accentColor.gradient, in: Circle())
                        VStack(alignment: .leading) {
                            Text(store.state.settings.name).font(.title3.weight(.bold))
                            AmountText(value: store.netWorth, font: .subheadline)
                        }
                    }
                    .padding(.vertical, 6)
                }
                Section("Gestión") {
                    NavigationLink { StatsView(embedded: true) } label: { row("Análisis", "chart.pie.fill", .green, "") }
                    NavigationLink { WorkView() } label: { row("Horas trabajadas", "briefcase.fill", .teal, Hours.dec(store.summary(store.shifts(month: Day.monthKey(Day.today))).totalMin) + " h") }
                    NavigationLink { AccountsList() } label: { row("Cuentas", "building.columns.fill", .blue, "\(store.accounts.count)") }
                    NavigationLink { CategoriesList() } label: { row("Categorías y presupuestos", "square.grid.2x2.fill", .orange, "\(store.state.categories.count)") }
                    NavigationLink { RecurringList() } label: { row("Recurrentes", "repeat.circle.fill", .purple, "\(store.state.recurring.filter(\.active).count)") }
                    NavigationLink { GoalsList() } label: { row("Objetivos", "target", .pink, "\(store.state.goals.count)") }
                }
                Section("Ajustes") {
                    TextField("Tu nombre", text: $store.state.settings.name)
                    Toggle(isOn: $store.state.settings.faceID) { Label("Bloquear con Face ID", systemImage: "faceid") }
                    Toggle(isOn: $store.state.settings.hideAmountsOnLaunch) { Label("Abrir con los importes ocultos", systemImage: "eye.slash") }
                    Stepper(value: $store.state.settings.monthStart, in: 1...28) {
                        Label("El mes empieza el día \(store.state.settings.monthStart)", systemImage: "calendar.badge.clock")
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Color de la app", systemImage: "paintpalette.fill")
                        ColorRow(color: $store.state.settings.accent)
                    }
                    .padding(.vertical, 4)
                }
                Section {
                    ShareLink(item: BackupFile(data: store.exportData()), preview: SharePreview("Copia de Caudal", image: Image(systemName: "doc.fill"))) {
                        Label("Exportar copia de seguridad", systemImage: "square.and.arrow.up")
                    }
                    Button { importing = true } label: { Label("Importar copia (también de la versión web)", systemImage: "square.and.arrow.down") }
                    Button { askReset = true } label: { Label("Volver a mis datos de partida", systemImage: "arrow.counterclockwise") }
                    Button(role: .destructive) { askErase = true } label: { Label("Borrar todo", systemImage: "trash") }
                } header: { Text("Datos") } footer: {
                    Text("Tus datos se guardan solo en este iPhone. Para pasar lo que tenías en la web: en la web, Más → Copia de seguridad → Exportar JSON, y aquí, Importar copia.")
                }
                Section {
                    LabeledContent("Versión", value: "3.0 · nativa")
                }
                Color.clear.frame(height: 40).listRowBackground(Color.clear)
            }
            .navigationTitle("Más")
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json, .data]) { result in
                guard case .success(let url) = result else { return }
                let ok = url.startAccessingSecurityScopedResource()
                defer { if ok { url.stopAccessingSecurityScopedResource() } }
                do {
                    let data = try Data(contentsOf: url)
                    message = try store.importBackup(data)
                    Haptic.success()
                } catch {
                    message = error.localizedDescription
                    Haptic.warning()
                }
            }
            .alert("Copia de seguridad", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("Vale") { message = nil }
            } message: { Text(message ?? "") }
            .confirmationDialog("¿Seguro que quieres volver a los datos de partida?", isPresented: $askReset, titleVisibility: .visible) {
                Button("Volver a los datos de partida", role: .destructive) { store.resetToSeed(); Haptic.heavy() }
            } message: { Text("Se perderá todo lo que hayas cambiado. Exporta antes una copia si la quieres guardar.") }
            .confirmationDialog("¿Seguro que quieres borrar todo?", isPresented: $askErase, titleVisibility: .visible) {
                Button("Borrar todo", role: .destructive) { store.eraseAll(); Haptic.heavy() }
            } message: { Text("Se borrarán cuentas, movimientos e inversiones. No se puede deshacer.") }
        }
    }

    private func row(_ title: String, _ icon: String, _ color: Color, _ badge: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 30, height: 30).background(color.gradient, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(title)
            Spacer()
            Text(badge).foregroundStyle(.secondary)
        }
    }
}

/// la copia de seguridad como archivo para compartir
struct BackupFile: Transferable {
    var data: Data
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { $0.data }
            .suggestedFileName("caudal-copia.json")
    }
}

/// selector de color con la paleta
struct ColorRow: View {
    @Binding var color: String
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(palette, id: \.self) { c in
                    Circle().fill(Color(hex: c)).frame(width: 32, height: 32)
                        .overlay(Circle().strokeBorder(.white, lineWidth: color == c ? 3 : 0))
                        .scaleEffect(color == c ? 1.15 : 1)
                        .onTapGesture { Haptic.select(); withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { color = c } }
                }
            }
            .padding(.vertical, 4).padding(.horizontal, 2)
        }
    }
}

// MARK: - Cuentas

struct AccountsList: View {
    @Environment(Store.self) private var store
    @State private var editing: Account? = nil
    @State private var adding = false
    var body: some View {
        List {
            ForEach(store.accounts) { a in
                NavigationLink(value: a) {
                    HStack(spacing: 12) {
                        IconBubble(icon: a.icon, color: a.color, size: 40)
                        VStack(alignment: .leading) {
                            Text(a.name).font(.body.weight(.semibold))
                            Text(a.type.label).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        AmountText(value: store.value(a), font: .body.weight(.semibold))
                    }
                }
            }
            .onMove { from, to in
                var list = store.accounts
                list.move(fromOffsets: from, toOffset: to)
                for (i, a) in list.enumerated() { if let k = store.state.accounts.firstIndex(where: { $0.id == a.id }) { store.state.accounts[k].order = i } }
            }
            let archived = store.state.accounts.filter(\.archived)
            if !archived.isEmpty {
                Section("Archivadas") {
                    ForEach(archived) { a in
                        Button { editing = a } label: { Text("\(a.icon) \(a.name)").foregroundStyle(.secondary) }
                    }
                }
            }
        }
        .navigationTitle("Cuentas")
        .navigationDestination(for: Account.self) { AccountDetail(accountId: $0.id) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
            ToolbarItem(placement: .topBarTrailing) { Button { adding = true } label: { Image(systemName: "plus") } }
        }
        .sheet(isPresented: $adding) { AccountEditor(original: nil) }
        .sheet(item: $editing) { AccountEditor(original: $0) }
    }
}

struct AccountDetail: View {
    @Environment(Store.self) private var store
    let accountId: String
    @State private var editingTx: Tx? = nil
    @State private var editing = false
    @State private var adjusting = false
    @State private var newBalance = ""
    @State private var pendingDelete: Tx? = nil
    @State private var askDelete = false

    var body: some View {
        if let a = store.account(accountId) {
            let txs = store.state.txs.filter { $0.accountId == a.id || $0.toAccountId == a.id }.sorted { $0.sortKey > $1.sortKey }
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(a.icon) \(a.name)").font(.headline).foregroundStyle(.white.opacity(0.85))
                        AmountText(value: store.balance(a), font: .system(size: 38, weight: .bold, design: .rounded), color: .white)
                        let inv = store.value(a) - store.balance(a)
                        if inv > 0 { Text("+ \(Money.eur(inv)) en inversiones").font(.subheadline.weight(.semibold)).foregroundStyle(.white.opacity(0.8)) }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(LinearGradient(colors: [Color(hex: a.color), Color(hex: a.color).opacity(0.45)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                Section("Movimientos") {
                    ForEach(txs) { t in
                        Button { editingTx = t } label: { TxRow(tx: t, showDate: true) }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button { Haptic.warning(); pendingDelete = t; askDelete = true } label: { Label("Eliminar", systemImage: "trash.fill") }.tint(.red)
                            }
                    }
                    if txs.isEmpty { Text("Sin movimientos").foregroundStyle(.secondary) }
                }
            }
            .navigationTitle(a.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { newBalance = Money.num(store.balance(a)).replacingOccurrences(of: ".", with: ""); adjusting = true } label: { Label("Ajustar saldo", systemImage: "slider.horizontal.3") }
                        Button { editing = true } label: { Label("Editar cuenta", systemImage: "pencil") }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
            .sheet(item: $editingTx) { TxEditor(original: $0) }
            .sheet(isPresented: $editing) { AccountEditor(original: a) }
            .alert("Ajustar saldo", isPresented: $adjusting) {
                TextField("Saldo real", text: $newBalance).keyboardType(.decimalPad)
                Button("Ajustar") { if let v = Money.parse(newBalance) { store.adjust(a, to: v); Haptic.success() } }
                Button("Cancelar", role: .cancel) {}
            } message: { Text("Escribe el saldo que ves en tu banco y se apuntará la diferencia.") }
            .confirmationDialog("¿Seguro que quieres eliminar este movimiento?", isPresented: $askDelete, titleVisibility: .visible, presenting: pendingDelete) { t in
                Button("Eliminar", role: .destructive) { Haptic.heavy(); store.delete(t) }
            } message: { t in Text("\(t.title.isEmpty ? t.type.label : t.title) · \(Money.eur(abs(t.amount)))") }
        } else {
            ContentUnavailableView("Cuenta eliminada", systemImage: "trash")
        }
    }
}

struct AccountEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let original: Account?
    @State private var a = Account(name: "")
    @State private var initial = ""
    @State private var askDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("🏦", text: $a.icon).frame(width: 44).font(.title)
                        TextField("Nombre", text: $a.name).font(.title3.weight(.semibold))
                    }
                    Picker("Tipo", selection: $a.type) { ForEach(AccountType.allCases) { Text("\($0.icon) \($0.label)").tag($0) } }
                    if original == nil {
                        LabeledContent("Saldo actual") { TextField("0,00", text: $initial).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    }
                }
                Section("Color") { ColorRow(color: $a.color) }
                Section {
                    Toggle("Suma al patrimonio", isOn: $a.includeInTotal)
                    Toggle("Archivada", isOn: $a.archived)
                    TextField("Nota", text: $a.note)
                }
                if original != nil {
                    Section { Button("Eliminar cuenta", role: .destructive) { askDelete = true } }
                }
            }
            .navigationTitle(original == nil ? "Nueva cuenta" : "Editar cuenta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        var n = a
                        if original == nil { n.initial = Money.parse(initial) ?? 0; if n.icon.isEmpty { n.icon = n.type.icon } }
                        store.save(n); Haptic.success(); dismiss()
                    }.bold().disabled(a.name.isEmpty)
                }
            }
            .confirmationDialog("¿Seguro que quieres eliminar la cuenta «\(a.name)»?", isPresented: $askDelete, titleVisibility: .visible) {
                Button("Eliminar cuenta y sus movimientos", role: .destructive) { store.deleteAccount(a); Haptic.heavy(); dismiss() }
            } message: { Text("Si solo quieres quitarla de la vista, archívala.") }
            .onAppear { if let original { a = original } else { a.color = palette[store.state.accounts.count % palette.count]; a.icon = "" } }
        }
    }
}

// MARK: - Categorías

struct CategoriesList: View {
    @Environment(Store.self) private var store
    @State private var kind: CatKind = .expense
    @State private var editing: Category? = nil
    @State private var adding = false
    var body: some View {
        List {
            Picker("", selection: $kind.animation()) { ForEach(CatKind.allCases) { Text($0 == .expense ? "Gastos" : "Ingresos").tag($0) } }
                .pickerStyle(.segmented).listRowBackground(Color.clear)
            ForEach(store.state.categories.filter { $0.kind == kind }) { c in
                Button { editing = c } label: {
                    HStack(spacing: 12) {
                        IconBubble(icon: c.icon, color: c.color, size: 38)
                        VStack(alignment: .leading) {
                            Text(c.name).foregroundStyle(c.hidden ? .secondary : .primary)
                            if c.budget > 0 { Text("Presupuesto: \(Money.eur(c.budget)) al mes").font(.caption).foregroundStyle(.secondary) }
                        }
                        Spacer()
                        if c.hidden { Image(systemName: "eye.slash").foregroundStyle(.secondary) }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Categorías")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { adding = true } label: { Image(systemName: "plus") } } }
        .sheet(item: $editing) { CategoryEditor(original: $0, kind: $0.kind) }
        .sheet(isPresented: $adding) { CategoryEditor(original: nil, kind: kind) }
    }
}

struct CategoryEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let original: Category?
    let kind: CatKind
    @State private var c = Category(name: "")
    @State private var budget = ""
    @State private var askDelete = false
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("📦", text: $c.icon).frame(width: 44).font(.title)
                        TextField("Nombre", text: $c.name).font(.title3.weight(.semibold))
                    }
                    if kind == .expense {
                        LabeledContent("Presupuesto al mes") { TextField("Sin límite", text: $budget).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    }
                    Toggle("Ocultar al apuntar", isOn: $c.hidden)
                }
                Section {
                    TextField("mercadona, lidl, …", text: $c.keywords, axis: .vertical)
                } header: { Text("Palabras clave") } footer: { Text("Si el concepto contiene alguna, se elige esta categoría sola.") }
                Section("Color") { ColorRow(color: $c.color) }
                if original != nil { Section { Button("Eliminar categoría", role: .destructive) { askDelete = true } } }
            }
            .navigationTitle(original == nil ? "Nueva categoría" : "Editar categoría")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        var n = c; n.kind = kind; n.budget = Money.parse(budget) ?? 0
                        if n.icon.isEmpty { n.icon = "📦" }
                        store.save(n); Haptic.success(); dismiss()
                    }.bold().disabled(c.name.isEmpty)
                }
            }
            .confirmationDialog("¿Seguro que quieres eliminar «\(c.name)»?", isPresented: $askDelete, titleVisibility: .visible) {
                Button("Eliminar", role: .destructive) { store.deleteCategory(c); dismiss() }
            } message: { Text("Sus movimientos se quedarán sin categoría.") }
            .onAppear {
                if let original { c = original; budget = original.budget > 0 ? Money.num(original.budget) : "" } else { c.color = palette[store.state.categories.count % palette.count]; c.icon = "" }
            }
        }
    }
}

// MARK: - Recurrentes

struct RecurringList: View {
    @Environment(Store.self) private var store
    @State private var editing: Recurring? = nil
    @State private var adding = false
    @State private var pendingDelete: Recurring? = nil
    @State private var askDelete = false
    var body: some View {
        let monthly = store.state.recurring.filter { $0.active }.reduce(0.0) { acc, r in
            acc + (r.freq == .monthly ? r.amount : r.freq == .weekly ? r.amount * 52 / 12 : r.amount / 12)
        }
        List {
            Section { LabeledContent("Fijo al mes", value: Money.eur(monthly)).font(.headline) }
            ForEach(store.state.recurring) { r in
                Button { editing = r } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(r.name).font(.body.weight(.semibold)).foregroundStyle(r.active ? .primary : .secondary)
                            Text("\(r.freq.label) · próximo \(Day.header(r.next))").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(Money.eur(r.amount)).monospacedDigit()
                    }
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button { Haptic.warning(); pendingDelete = r; askDelete = true } label: { Label("Eliminar", systemImage: "trash.fill") }.tint(.red)
                    Button {
                        if let i = store.state.recurring.firstIndex(where: { $0.id == r.id }) { store.state.recurring[i].active.toggle() }
                    } label: { Label(r.active ? "Pausar" : "Reanudar", systemImage: r.active ? "pause.fill" : "play.fill") }.tint(.orange)
                }
            }
        }
        .navigationTitle("Recurrentes")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { adding = true } label: { Image(systemName: "plus") } } }
        .sheet(item: $editing) { RecurringEditor(original: $0) }
        .sheet(isPresented: $adding) { RecurringEditor(original: nil) }
        .confirmationDialog("¿Seguro que quieres eliminar este recurrente?", isPresented: $askDelete, titleVisibility: .visible, presenting: pendingDelete) { r in
            Button("Eliminar", role: .destructive) { withAnimation { store.state.recurring.removeAll { $0.id == r.id } } }
        } message: { r in Text("«\(r.name)» dejará de apuntarse solo. Lo ya apuntado se queda.") }
    }
}

struct RecurringEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let original: Recurring?
    @State private var r = Recurring(name: "", amount: 0, accountId: "", next: Day.today)
    @State private var amount = ""
    @State private var next = Date()
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nombre (p. ej. Netflix)", text: $r.name)
                    LabeledContent("Importe") { TextField("0,00", text: $amount).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    Picker("Tipo", selection: $r.type) {
                        Text("Gasto").tag("expense"); Text("Ingreso").tag("income"); Text("Transferencia").tag("transfer"); Text("Inversión").tag("invest")
                    }
                }
                Section {
                    Picker("Cuenta", selection: $r.accountId) { ForEach(store.accounts) { Text("\($0.icon) \($0.name)").tag($0.id) } }
                    if r.type == "transfer" {
                        Picker("Hacia", selection: Binding(get: { r.toAccountId ?? "" }, set: { r.toAccountId = $0 })) {
                            ForEach(store.accounts) { Text("\($0.icon) \($0.name)").tag($0.id) }
                        }
                    } else if r.type == "invest" {
                        Picker("Activo", selection: Binding(get: { r.assetId ?? "" }, set: { r.assetId = $0 })) {
                            Text("Elige").tag("")
                            ForEach(store.state.assets) { Text($0.name).tag($0.id) }
                        }
                    } else {
                        Picker("Categoría", selection: Binding(get: { r.categoryId ?? "" }, set: { r.categoryId = $0.isEmpty ? nil : $0 })) {
                            Text("Sin categoría").tag("")
                            ForEach(store.categories(r.type == "income" ? .income : .expense)) { Text("\($0.icon) \($0.name)").tag($0.id) }
                        }
                    }
                }
                Section {
                    Picker("Frecuencia", selection: $r.freq) { ForEach(Freq.allCases) { Text($0.label).tag($0) } }
                    DatePicker("Próximo cargo", selection: $next, displayedComponents: .date)
                    Toggle("Activo", isOn: $r.active)
                }
            }
            .navigationTitle(original == nil ? "Nuevo recurrente" : "Editar recurrente")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        var n = r; n.amount = Money.parse(amount) ?? 0; n.next = Day.str(next)
                        n.day = Day.cal.component(.day, from: next)
                        store.save(n); Haptic.success(); dismiss()
                    }.bold().disabled(r.name.isEmpty || (Money.parse(amount) ?? 0) <= 0)
                }
            }
            .onAppear {
                if let original { r = original; amount = Money.num(original.amount); next = Day.date(original.next) }
                else { r.accountId = store.accounts.first?.id ?? "" }
            }
        }
    }
}

// MARK: - Objetivos

struct GoalsList: View {
    @Environment(Store.self) private var store
    @State private var editing: Goal? = nil
    @State private var adding = false
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ForEach(store.state.goals) { g in
                    Button { editing = g } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(g.icon).font(.largeTitle)
                                VStack(alignment: .leading) {
                                    Text(g.name).font(.headline)
                                    if !g.deadline.isEmpty { Text("Para el \(Day.header(g.deadline))").font(.caption).foregroundStyle(.secondary) }
                                }
                                Spacer()
                                Text("\(Int((store.saved(g) / max(g.target, 0.01) * 100).rounded())) %").font(.title3.weight(.heavy)).foregroundStyle(Color(hex: g.color))
                            }
                            ProgressBar(value: store.saved(g) / max(g.target, 0.01), color: Color(hex: g.color), height: 12)
                            HStack {
                                AmountText(value: store.saved(g), font: .subheadline.weight(.semibold))
                                Spacer()
                                Text("de \(Money.eur(g.target))").font(.subheadline).foregroundStyle(.secondary)
                            }
                            if let id = g.accountId, let a = store.account(id) { Text("Se mide con el saldo de \(a.name)").font(.caption).foregroundStyle(.secondary) }
                            if !g.deadline.isEmpty, store.saved(g) < g.target {
                                let months = max(1, Day.cal.dateComponents([.month], from: Date(), to: Day.date(g.deadline)).month ?? 1)
                                Text("Aparta \(Money.eur((g.target - store.saved(g)) / Double(months))) al mes").font(.footnote.weight(.semibold)).foregroundStyle(Color(hex: g.color))
                            }
                        }
                        .card()
                    }
                    .buttonStyle(PressableStyle(scale: 0.97))
                }
                if store.state.goals.isEmpty {
                    ContentUnavailableView("Sin objetivos", systemImage: "target", description: Text("Crea uno con el botón +: un viaje, un coche, un colchón…"))
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Objetivos")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { adding = true } label: { Image(systemName: "plus") } } }
        .sheet(item: $editing) { GoalEditor(original: $0) }
        .sheet(isPresented: $adding) { GoalEditor(original: nil) }
    }
}

struct GoalEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let original: Goal?
    @State private var g = Goal(name: "", target: 0)
    @State private var target = ""
    @State private var add = ""
    @State private var hasDeadline = false
    @State private var deadline = Date()
    @State private var askDelete = false
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("🎯", text: $g.icon).frame(width: 44).font(.title)
                        TextField("Nombre", text: $g.name).font(.title3.weight(.semibold))
                    }
                    LabeledContent("Meta") { TextField("0,00", text: $target).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    Toggle("Con fecha límite", isOn: $hasDeadline.animation())
                    if hasDeadline { DatePicker("Fecha", selection: $deadline, displayedComponents: .date) }
                }
                Section("Se mide con") {
                    Picker("Origen", selection: Binding(get: { g.accountId ?? "" }, set: { g.accountId = $0.isEmpty ? nil : $0 })) {
                        Text("Aportaciones a mano").tag("")
                        ForEach(store.accounts) { Text("\($0.icon) \($0.name)").tag($0.id) }
                    }
                }
                if g.accountId == nil {
                Section("Ahorrado: \(Money.eur(g.saved))") {
                    HStack {
                        TextField("Importe", text: $add).keyboardType(.decimalPad)
                        Button("Añadir") { if let v = Money.parse(add) { withAnimation { g.saved += v }; add = ""; Haptic.success() } }
                        Button("Quitar") { if let v = Money.parse(add) { withAnimation { g.saved = max(0, g.saved - v) }; add = ""; Haptic.tap() } }
                    }
                    .buttonStyle(.bordered)
                }
                }
                Section("Color") { ColorRow(color: $g.color) }
                if original != nil { Section { Button("Eliminar objetivo", role: .destructive) { askDelete = true } } }
            }
            .navigationTitle(original == nil ? "Nuevo objetivo" : "Objetivo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        var n = g; n.target = Money.parse(target) ?? 0; n.deadline = hasDeadline ? Day.str(deadline) : ""
                        store.save(n); Haptic.success(); dismiss()
                    }.bold().disabled(g.name.isEmpty || (Money.parse(target) ?? 0) <= 0)
                }
            }
            .confirmationDialog("¿Seguro que quieres eliminar este objetivo?", isPresented: $askDelete, titleVisibility: .visible) {
                Button("Eliminar", role: .destructive) { store.state.goals.removeAll { $0.id == g.id }; dismiss() }
            }
            .onAppear {
                if let original {
                    g = original; target = Money.num(original.target)
                    if !original.deadline.isEmpty { hasDeadline = true; deadline = Day.date(original.deadline) }
                } else { g.color = palette[store.state.goals.count % palette.count] }
            }
        }
    }
}
