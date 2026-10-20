import SwiftUI
import PhotosUI

/// Pestaña «Cuentas»: Cuentas Claras dentro de Caudal (quién te debe y a quién debes)
struct DebtsView: View {
    @Environment(Store.self) private var store
    @Environment(\.openURL) private var openURL
    @State private var adding: DebtKind? = nil
    @State private var newPerson = false
    @State private var settling: Person? = nil
    @State private var askSettle = false
    @State private var pendingDelete: DebtMove? = nil
    @State private var askDelete = false
    @State private var toast: String? = nil
    @State private var importing = false
    @State private var importText = ""

    var body: some View {
        NavigationStack {
            List {
                if store.state.people.isEmpty {
                    empty.listRowBackground(Color.clear)
                } else {
                    Section { hero.listRowInsets(EdgeInsets()).listRowBackground(Color.clear) }
                    Section { actions.listRowInsets(EdgeInsets()).listRowBackground(Color.clear) }
                    Section("Personas") {
                        ForEach(store.peopleSorted) { p in personRow(p) }
                    }
                    let recent = store.state.debts.sorted { ($0.date, $0.created) > ($1.date, $1.created) }.prefix(8)
                    if !recent.isEmpty {
                        Section("Últimos movimientos") {
                            ForEach(Array(recent)) { m in
                                DebtRow(move: m)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button { Haptic.warning(); pendingDelete = m; askDelete = true } label: { Label("Borrar", systemImage: "trash.fill") }.tint(.red)
                                    }
                            }
                        }
                    }
                }
                Color.clear.frame(height: 60).listRowBackground(Color.clear)
            }
            .navigationTitle("Cuentas")
            .navigationDestination(for: Person.self) { PersonDetail(personId: $0.id) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { newPerson = true } label: { Label("Añadir persona", systemImage: "person.badge.plus") }
                        Button { importing = true } label: { Label("Importar de Cuentas Claras", systemImage: "square.and.arrow.down") }
                    } label: { Image(systemName: "person.crop.circle.badge.plus") }
                }
            }
            .sheet(item: $adding) { k in DebtEditor(kind: k) }
            .sheet(isPresented: $newPerson) { PersonEditor(original: nil) }
            .confirmationDialog(settleTitle, isPresented: $askSettle, titleVisibility: .visible, presenting: settling) { p in
                Button(store.debtBalance(p.id) > 0 ? "Sí, me lo ha pagado todo" : "Sí, ya le he pagado todo") {
                    Haptic.success(); store.settle(p.id); show("¡Cuentas saldadas con \(p.name)! 🎉")
                }
                Button("Cancelar", role: .cancel) {}
            } message: { p in Text("Se apuntará un pago de \(Money.eur(abs(store.debtBalance(p.id)))) y la cuenta quedará a cero.") }
            .confirmationDialog("¿Seguro que quieres borrar este movimiento?", isPresented: $askDelete, titleVisibility: .visible, presenting: pendingDelete) { m in
                Button("Borrar", role: .destructive) { Haptic.heavy(); store.deleteDebt(m) }
                Button("Cancelar", role: .cancel) {}
            } message: { m in Text("\(m.concept.isEmpty ? m.kind.label : m.concept) · \(Money.eur(abs(m.amount))) · \(store.person(m.personId)?.name ?? "")") }
            .alert("Importar de Cuentas Claras", isPresented: $importing) {
                TextField("Pega aquí la copia", text: $importText)
                Button("Importar") {
                    do { show(try store.importCuentasClaras(importText)); Haptic.success() } catch { show("La copia no es válida"); Haptic.warning() }
                    importText = ""
                }
                Button("Cancelar", role: .cancel) { importText = "" }
            } message: { Text("En la app Cuentas Claras: Más → Copiar copia. Luego pégala aquí.") }
            .overlay(alignment: .bottom) {
                if let toast {
                    Text(toast).font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 18).padding(.vertical, 12)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.bottom, 110)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    private var settleTitle: String {
        guard let p = settling else { return "" }
        return store.debtBalance(p.id) > 0 ? "¿\(p.name) te lo ha pagado todo?" : "¿Ya le has pagado todo a \(p.name)?"
    }

    private func show(_ t: String) {
        withAnimation(.spring) { toast = t }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) { withAnimation(.spring) { if toast == t { toast = nil } } }
    }

    private var empty: some View {
        VStack(spacing: 14) {
            Text("🤝").font(.system(size: 64))
            Text("Que no se te olvide nadie").font(.title2.weight(.bold))
            Text("Añade a tus amigos y apunta quién te debe y a quién debes. Así nadie se queda con tu dinero.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button { newPerson = true } label: { Label("Añadir a alguien", systemImage: "person.badge.plus").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).controlSize(.large)
            Button("Importar de Cuentas Claras") { importing = true }
        }
        .padding(24).frame(maxWidth: .infinity)
    }

    private var hero: some View {
        let them = store.owedToMe, me = store.iOwe, net = them - me
        return VStack(alignment: .leading, spacing: 8) {
            Text("Balance total").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            AmountText(value: net, signed: net != 0, font: .system(size: 42, weight: .bold, design: .rounded),
                       color: net > 0 ? .income : net < 0 ? .negative : .primary)
            Text(net > 0 ? "A tu favor: te deben más de lo que debes" : net < 0 ? "En contra: debes más de lo que te deben" : "Todo en paz 🙌")
                .font(.subheadline).foregroundStyle(.secondary)
            if them + me > 0 {
                GeometryReader { g in
                    HStack(spacing: 3) {
                        Capsule().fill(Color.income.gradient).frame(width: max(4, (g.size.width - 3) * them / (them + me)))
                        Capsule().fill(Color.negative.gradient)
                    }
                }
                .frame(height: 10)
                HStack {
                    HStack(spacing: 4) { Circle().fill(Color.income).frame(width: 8, height: 8); Text("Te deben").foregroundStyle(.secondary); AmountText(value: them, font: .footnote.weight(.semibold)) }
                    Spacer()
                    HStack(spacing: 4) { Circle().fill(Color.negative).frame(width: 8, height: 8); Text("Debes").foregroundStyle(.secondary); AmountText(value: me, font: .footnote.weight(.semibold)) }
                }
                .font(.footnote)
            }
        }
        .card(20)
    }

    private var actions: some View {
        HStack(spacing: 10) {
            action("Me debe", "arrow.down.left.circle.fill", .income, .owe)
            action("Le debo", "arrow.up.right.circle.fill", .negative, .debt)
            action("A medias", "person.2.circle.fill", .accentColor, .split)
            action("Pagó otro", "creditcard.circle.fill", .orange, .theypaid)
        }
    }
    private func action(_ t: String, _ icon: String, _ c: Color, _ k: DebtKind) -> some View {
        Button { Haptic.tap(); adding = k } label: {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 28)).foregroundStyle(c)
                Text(t).font(.caption.weight(.semibold)).foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(Color.cardBG, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PressableStyle(scale: 0.9))
    }

    private func personRow(_ p: Person) -> some View {
        let b = store.debtBalance(p.id)
        return NavigationLink(value: p) {
            HStack(spacing: 12) {
                Avatar(person: p, size: 46)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(p.name).font(.body.weight(.semibold))
                        if !p.nick.isEmpty { Text("· \(p.nick)").foregroundStyle(.secondary) }
                    }
                    Text(store.lastDebt(p.id).map { "Último movimiento: \(Day.header($0.date).lowercased())" } ?? "Sin movimientos")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    if b == 0 { Text("En paz").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary) }
                    else {
                        AmountText(value: abs(b), font: .body.weight(.bold), color: b > 0 ? .income : .negative)
                        Text(b > 0 ? "te debe" : "le debes").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if b != 0 {
                Button { settling = p; askSettle = true } label: { Label(b > 0 ? "Me ha pagado" : "Ya le pagué", systemImage: "checkmark.circle.fill") }
                    .tint(b > 0 ? .green : .orange)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if b > 0 {
                Button { remind(p) } label: { Label("Recordar", systemImage: "message.fill") }.tint(Color(hex: "#25b562"))
            }
        }
    }

    private func remind(_ p: Person) {
        Haptic.tap()
        if let url = store.whatsappURL(for: p) { openURL(url) } else {
            UIPasteboard.general.string = store.reminder(for: p)
            show("Mensaje copiado: pégalo donde quieras")
        }
    }
}

/// foto o emoji de la persona con su color
struct Avatar: View {
    var person: Person
    var size: CGFloat = 44
    var body: some View {
        ZStack {
            Circle().fill(RadialGradient(colors: [Color(hex: person.color).opacity(0.55), Color(hex: person.color).opacity(0.15)], center: .init(x: 0.35, y: 0.3), startRadius: 0, endRadius: size))
            if let d = person.photo, let img = UIImage(data: d) {
                Image(uiImage: img).resizable().scaledToFill().frame(width: size, height: size).clipShape(Circle())
            } else {
                Text(person.emoji).font(.system(size: size * 0.5))
            }
        }
        .frame(width: size, height: size)
        .overlay(Circle().strokeBorder(Color(hex: person.color), lineWidth: 2))
    }
}

struct DebtRow: View {
    @Environment(Store.self) private var store
    var move: DebtMove
    var showName = true
    var body: some View {
        let p = store.person(move.personId)
        HStack(spacing: 12) {
            if let p { Avatar(person: p, size: 40) }
            VStack(alignment: .leading, spacing: 2) {
                Text(title(p)).font(.body.weight(.semibold)).lineLimit(1)
                Text([showName && !isPay ? p?.name : nil, move.kind.label, Day.shortLabel(move.date)].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if isPay {
                Label(Money.eur(abs(move.amount)), systemImage: "checkmark").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            } else {
                AmountText(value: move.amount, signed: true, font: .body.weight(.bold), color: move.amount > 0 ? .income : .negative)
            }
        }
    }
    private var isPay: Bool { move.kind == .pay || move.kind == .ipay }
    private func title(_ p: Person?) -> String {
        switch move.kind {
        case .pay: return "\(p?.name ?? "") te ha pagado"
        case .ipay: return "Le has pagado a \(p?.name ?? "")"
        default: return move.concept.isEmpty ? move.kind.label : move.concept
        }
    }
}

// MARK: - Detalle de una persona

struct PersonDetail: View {
    @Environment(Store.self) private var store
    @Environment(\.openURL) private var openURL
    let personId: String
    @State private var adding: DebtKind? = nil
    @State private var editing = false
    @State private var askSettle = false
    @State private var partial = false
    @State private var partialText = ""
    @State private var pendingDelete: DebtMove? = nil
    @State private var askDelete = false
    @State private var copied = false

    var body: some View {
        if let p = store.person(personId) {
            let b = store.debtBalance(p.id)
            let moves = store.state.debts.filter { $0.personId == p.id }.sorted { ($0.date, $0.created) > ($1.date, $1.created) }
            List {
                Section {
                    VStack(spacing: 8) {
                        Avatar(person: p, size: 92)
                        Text(p.name).font(.title2.weight(.bold))
                        if !p.nick.isEmpty { Text(p.nick).foregroundStyle(.secondary) }
                        if b == 0 { Text("En paz").font(.system(size: 36, weight: .bold, design: .rounded)) }
                        else { AmountText(value: abs(b), font: .system(size: 40, weight: .bold, design: .rounded), color: b > 0 ? .income : .negative) }
                        Text(b > 0 ? "te debe" : b < 0 ? "le debes" : "no os debéis nada 🙌").foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }
                if b != 0 {
                    Section {
                        Button { Haptic.tap(); askSettle = true } label: {
                            Label(b > 0 ? "Me lo ha pagado todo" : "Ya le he pagado todo", systemImage: "checkmark.circle.fill")
                                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent).tint(b > 0 ? .green : .orange)
                        .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                        HStack(spacing: 10) {
                            Button { partialText = ""; partial = true } label: { Label("Pago parcial", systemImage: "circle.lefthalf.filled").frame(maxWidth: .infinity) }
                            if b > 0 {
                                Button { remind(p) } label: { Label("Recordar", systemImage: "message.fill").frame(maxWidth: .infinity) }.tint(Color(hex: "#25b562"))
                            }
                        }
                        .buttonStyle(.bordered).controlSize(.large)
                        .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                    }
                }
                Section {
                    HStack(spacing: 10) {
                        small("Me debe", .owe, .income)
                        small("Le debo", .debt, .negative)
                        small("A medias", .split, .accentColor)
                    }
                    .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                }
                Section("Historial") {
                    ForEach(moves) { m in
                        DebtRow(move: m, showName: false)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button { Haptic.warning(); pendingDelete = m; askDelete = true } label: { Label("Borrar", systemImage: "trash.fill") }.tint(.red)
                            }
                    }
                    if moves.isEmpty { Text("Sin movimientos").foregroundStyle(.secondary) }
                }
            }
            .navigationTitle(p.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Editar") { editing = true } } }
            .sheet(item: $adding) { k in DebtEditor(kind: k, personId: p.id) }
            .sheet(isPresented: $editing) { PersonEditor(original: p) }
            .confirmationDialog(b > 0 ? "¿\(p.name) te lo ha pagado todo?" : "¿Ya le has pagado todo a \(p.name)?", isPresented: $askSettle, titleVisibility: .visible) {
                Button("Sí, dejar la cuenta a cero") { Haptic.success(); store.settle(p.id) }
                Button("Cancelar", role: .cancel) {}
            } message: { Text("Se apuntará un pago de \(Money.eur(abs(b))).") }
            .alert("Pago parcial", isPresented: $partial) {
                TextField("Importe", text: $partialText).keyboardType(.decimalPad)
                Button("Apuntar") { if let v = Money.parse(partialText), v > 0 { Haptic.success(); store.settle(p.id, amount: v) } }
                Button("Cancelar", role: .cancel) {}
            } message: { Text(b > 0 ? "¿Cuánto te ha pagado \(p.name)?" : "¿Cuánto le has pagado a \(p.name)?") }
            .confirmationDialog("¿Seguro que quieres borrar este movimiento?", isPresented: $askDelete, titleVisibility: .visible, presenting: pendingDelete) { m in
                Button("Borrar", role: .destructive) { Haptic.heavy(); store.deleteDebt(m) }
                Button("Cancelar", role: .cancel) {}
            } message: { m in Text("\(m.concept.isEmpty ? m.kind.label : m.concept) · \(Money.eur(abs(m.amount)))") }
            .alert("Mensaje copiado", isPresented: $copied) { Button("Vale") {} } message: { Text("No tiene móvil guardado: pégalo en WhatsApp o donde quieras.") }
        } else {
            ContentUnavailableView("Persona eliminada", systemImage: "person.slash")
        }
    }

    private func small(_ t: String, _ k: DebtKind, _ c: Color) -> some View {
        Button { Haptic.tap(); adding = k } label: {
            Text(t).font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(c.opacity(0.18), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .foregroundStyle(c)
        }
        .buttonStyle(PressableStyle())
    }

    private func remind(_ p: Person) {
        Haptic.tap()
        if let url = store.whatsappURL(for: p) { openURL(url) } else { UIPasteboard.general.string = store.reminder(for: p); copied = true }
    }
}

// MARK: - Apuntar

struct DebtEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var kind: DebtKind
    var personId: String? = nil

    @State private var digits = ""
    @State private var concept = ""
    @State private var selected: Set<String> = []
    @State private var includeMe = true
    @State private var between = 2
    @State private var date = Date()
    @State private var alsoTx = false
    @State private var accountId = ""
    @State private var newPerson = false
    @State private var saved = false
    @FocusState private var amountFocused: Bool
    @Namespace private var ns

    private var amount: Double { Money.parse(digits) ?? 0 }
    private let kinds: [(DebtKind, String)] = [(.owe, "Me debe"), (.debt, "Le debo"), (.split, "A medias"), (.theypaid, "Pagó otro")]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    picker
                    BigAmount(digits: $digits, focused: $amountFocused, color: color)
                    if !shareText.isEmpty { Text(shareText).font(.subheadline.weight(.semibold)).foregroundStyle(color).contentTransition(.numericText()) }
                    VStack(alignment: .leading, spacing: 10) {
                        Text(kind == .split ? "Entre quiénes" : kind == .theypaid ? "¿Quién pagó?" : "Con quién")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(store.peopleSorted) { p in chip(p) }
                                Button { newPerson = true } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: "plus").font(.title2.weight(.semibold)).frame(width: 52, height: 52).background(Color.white.opacity(0.08), in: Circle())
                                        Text("Nuevo").font(.caption)
                                    }
                                }
                                .buttonStyle(PressableStyle())
                            }
                            .padding(.vertical, 4)
                        }
                        if kind == .split {
                            Toggle("Yo también participo", isOn: $includeMe.animation(.spring))
                        }
                        if kind == .theypaid {
                            Stepper("Entre \(between) contándote a ti", value: $between, in: 2...20)
                        }
                    }
                    .card(14)
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "text.cursor").foregroundStyle(.secondary).frame(width: 22)
                            TextField(placeholder, text: $concept)
                        }
                        Divider()
                        DatePicker(selection: $date, displayedComponents: .date) { Label("Fecha", systemImage: "calendar").foregroundStyle(.secondary) }
                        if kind == .split || kind == .owe {
                            Divider()
                            Toggle(isOn: $alsoTx.animation(.spring)) { Label("Apuntar lo que pagué en Movimientos", systemImage: "arrow.triangle.branch").foregroundStyle(.secondary) }
                            if alsoTx {
                                Picker("Cuenta", selection: $accountId) { ForEach(store.accounts) { Text("\($0.icon) \($0.name)").tag($0.id) } }
                            }
                        }
                    }
                    .card(14)
                    Button(action: save) {
                        Label("Guardar", systemImage: "checkmark").font(.headline)
                            .frame(maxWidth: .infinity).frame(height: 56)
                            .foregroundStyle(.black)
                            .background(color.gradient, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(PressableStyle())
                    .opacity(valid ? 1 : 0.5)
                }
                .padding(16)
                .animation(.spring(response: 0.4, dampingFraction: 0.82), value: kind)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Apuntar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Guardar", action: save).bold() }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Listo") { amountFocused = false } }
            }
            .sheet(isPresented: $newPerson) { PersonEditor(original: nil) { p in pick(p.id) } }
            .overlay { if saved { SavedBadge().transition(.scale(scale: 0.6).combined(with: .opacity)) } }
            .onAppear {
                if let personId { selected = [personId] }
                accountId = store.accounts.first?.id ?? ""
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { amountFocused = true }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var color: Color {
        switch kind {
        case .owe: return .income
        case .debt: return .negative
        case .split: return .accentColor
        default: return .orange
        }
    }
    private var placeholder: String {
        switch kind {
        case .owe: return "Ej.: entradas del cine"
        case .debt: return "Ej.: gasolina"
        case .split: return "Ej.: cena del viernes"
        default: return "Ej.: pizzas"
        }
    }
    private var valid: Bool { amount > 0 && !selected.isEmpty }
    private var shareText: String {
        guard amount > 0 else { return "" }
        if kind == .split {
            let n = selected.count + (includeMe ? 1 : 0)
            return selected.isEmpty || n == 0 ? "Elige a las personas" : "Cada uno: \(Money.eur(amount / Double(n))) · te deben \(Money.eur(amount / Double(n) * Double(selected.count)))"
        }
        if kind == .theypaid { return "Te toca pagar \(Money.eur(amount / Double(between)))" }
        return ""
    }

    private var picker: some View {
        HStack(spacing: 4) {
            ForEach(kinds, id: \.0) { k, label in
                Button {
                    Haptic.select()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        kind = k
                        if k != .split, selected.count > 1 { selected = [selected.first!] }
                    }
                } label: {
                    Text(label).font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .foregroundStyle(kind == k ? Color.black : Color.primary)
                        .background { if kind == k { Capsule().fill(color).matchedGeometryEffect(id: "k", in: ns) } }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.cardBG, in: Capsule())
    }

    private func chip(_ p: Person) -> some View {
        let on = selected.contains(p.id)
        return Button { pick(p.id) } label: {
            VStack(spacing: 6) {
                Avatar(person: p, size: 52)
                    .scaleEffect(on ? 1.08 : 1)
                    .overlay(alignment: .bottomTrailing) {
                        if on { Image(systemName: "checkmark.circle.fill").font(.title3).foregroundStyle(.white, color).transition(.scale) }
                    }
                Text(p.name).font(.caption.weight(on ? .bold : .regular)).lineLimit(1).frame(width: 64)
            }
            .opacity(selected.isEmpty || on ? 1 : 0.55)
        }
        .buttonStyle(PressableStyle())
    }

    private func pick(_ id: String) {
        Haptic.select()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
            if kind == .split { if selected.contains(id) { selected.remove(id) } else { selected.insert(id) } }
            else { selected = [id] }
        }
    }

    private func save() {
        guard valid else { Haptic.warning(); return }
        let d = Day.str(date)
        let c = concept.trimmingCharacters(in: .whitespaces)
        var moves: [DebtMove] = []
        switch kind {
        case .split:
            let n = Double(selected.count + (includeMe ? 1 : 0))
            let each = (amount / n * 100).rounded() / 100
            let g = UUID().uuidString
            for pid in selected { moves.append(DebtMove(personId: pid, amount: each, kind: .split, concept: c.isEmpty ? "Gasto a medias" : c, date: d, group: g, total: amount)) }
        case .theypaid:
            moves.append(DebtMove(personId: selected.first!, amount: -((amount / Double(between) * 100).rounded() / 100), kind: .theypaid, concept: c.isEmpty ? "Pagó por ti" : c, date: d, total: amount))
        default:
            moves.append(DebtMove(personId: selected.first!, amount: kind == .owe ? amount : -amount, kind: kind, concept: c, date: d))
        }
        store.add(moves)
        if alsoTx && (kind == .split || kind == .owe) && !accountId.isEmpty {
            let names = selected.compactMap { store.person($0)?.name }.joined(separator: ", ")
            store.save(Tx(type: .expense, amount: amount, accountId: accountId, date: d, time: Day.time(Date()),
                          title: c.isEmpty ? (kind == .split ? "Gasto a medias" : "Pagado por \(names)") : c, note: "Con \(names) (Cuentas)"))
        }
        Haptic.success()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { saved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { dismiss() }
    }
}

/// importe grande con el teclado numérico del iPhone (siempre al mismo tamaño)
struct BigAmount: View {
    @Binding var digits: String
    var focused: FocusState<Bool>.Binding
    var color: Color
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(digits.isEmpty ? "0" : digits)
                .foregroundStyle(digits.isEmpty ? Color.secondary : Color.primary)
                .contentTransition(.numericText())
            Text("€").foregroundStyle(.secondary)
        }
        .font(.system(size: digits.count > 8 ? 44 : (digits.count > 6 ? 52 : 60), weight: .bold, design: .rounded))
        .monospacedDigit()
        .lineLimit(1)
        .background {
            TextField("", text: $digits)
                .keyboardType(.decimalPad)
                .focused(focused)
                .opacity(0.01)
                .allowsHitTesting(false)
                .onChange(of: digits) { _, v in let c = BigAmount.clean(v); if c != v { digits = c } }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture { focused.wrappedValue = true }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: digits)
    }

    static func clean(_ v: String) -> String {
        var out = ""; var comma = false; var dec = 0
        for ch in v.replacingOccurrences(of: ".", with: ",") {
            if ch == "," { if !comma { comma = true; out += out.isEmpty ? "0," : "," }; continue }
            guard ch.isNumber else { continue }
            if comma { if dec >= 2 { continue }; dec += 1 }
            if !comma && out == "0" { out = "" }
            if !comma && out.count >= 9 { continue }
            out.append(ch)
        }
        return out
    }
}

// MARK: - Persona

struct PersonEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let original: Person?
    var onSave: ((Person) -> Void)? = nil
    @State private var p = Person(name: "")
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var askDelete = false

    private let emojis: [(String, [String])] = [
        ("Caras", ["😎", "🤠", "🥸", "🤓", "😏", "🥳", "😴", "🤑", "😇", "🤪", "😈", "👻", "💀", "🤡", "👽", "🤖", "🙃", "😬", "🫠", "🥹", "😤", "🤯", "🧐", "😵‍💫"]),
        ("Gente", ["🧔", "👨", "👩", "🧑", "👱", "👨‍🦱", "👩‍🦰", "🧑‍🎤", "👸", "🤴", "🧙", "🧛", "🥷", "💃", "🕺", "🧑‍🍳", "🧑‍🚀", "🦸", "🦹", "🧜", "👮", "🧑‍🎓", "🧑‍💻", "🧑‍🎨"]),
        ("Animales", ["🐻", "🦊", "🐸", "🐱", "🐶", "🦁", "🐼", "🐵", "🐙", "🦄", "🐯", "🐨", "🐷", "🐔", "🐧", "🦉", "🐢", "🦖", "🐬", "🦈", "🐝", "🦋", "🐘", "🦒"]),
        ("Comida", ["🍕", "🍔", "🌮", "🍣", "🍜", "🍩", "🍰", "🍦", "🍺", "🍷", "🍹", "☕", "🧋", "🍓", "🍉", "🥑", "🌶️", "🍟", "🥐", "🍪", "🧀", "🥓", "🍿", "🥨"]),
        ("Aficiones", ["⚽", "🏀", "🎾", "🏐", "🥊", "🏋️", "🚴", "🏄", "⛷️", "🎮", "🎧", "🎸", "🎤", "🎨", "📸", "🎬", "📚", "✈️", "🚗", "🏍️", "🛹", "🎲", "♟️", "🎯"]),
        ("Símbolos", ["⭐", "🔥", "💎", "🌈", "⚡", "🌙", "☀️", "🍀", "💖", "💜", "🖤", "👑", "💯", "🚀", "🎉", "🧿", "🪩", "🌸", "🌵", "🐾", "💸", "💰", "🎁", "🏆"]),
    ]
    private let colors = ["#b9a4ff", "#8f7bff", "#5fe0a0", "#2ecc9a", "#ff8a7a", "#ff5f6d", "#ffcc66", "#ffa94d", "#7cc8ff", "#4d9dff", "#ff9ecf", "#ff6fb5", "#8fe3e0", "#c9d36a", "#e0c3a0", "#f4f2fa", "#9aa3b5", "#c792ea"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        Avatar(person: p, size: 96).animation(.spring, value: p)
                        HStack {
                            PhotosPicker(selection: $photoItem, matching: .images) { Label(p.photo == nil ? "Poner foto" : "Cambiar foto", systemImage: "photo") }
                            if p.photo != nil { Button("Quitar foto", role: .destructive) { withAnimation { p.photo = nil } } }
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
                Section {
                    TextField("Nombre (ej.: Álex)", text: $p.name)
                    TextField("Apodo o nota (opcional)", text: $p.nick)
                    TextField("Móvil para WhatsApp (opcional)", text: $p.phone).keyboardType(.phonePad)
                }
                Section("Color") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(colors, id: \.self) { c in
                                Circle().fill(Color(hex: c)).frame(width: 32, height: 32)
                                    .overlay(Circle().strokeBorder(.white, lineWidth: p.color == c ? 3 : 0))
                                    .scaleEffect(p.color == c ? 1.15 : 1)
                                    .onTapGesture { Haptic.select(); withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { p.color = c } }
                            }
                        }
                        .padding(4)
                    }
                }
                ForEach(emojis, id: \.0) { cat, list in
                    Section(cat) {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 8) {
                            ForEach(list, id: \.self) { e in
                                Text(e).font(.title2)
                                    .frame(width: 38, height: 38)
                                    .background(p.emoji == e ? Color(hex: p.color).opacity(0.35) : .clear, in: Circle())
                                    .onTapGesture { Haptic.select(); withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { p.emoji = e; p.photo = nil } }
                            }
                        }
                    }
                }
                if original != nil {
                    Section { Button("Borrar persona y sus movimientos", role: .destructive) { askDelete = true } }
                }
            }
            .navigationTitle(original == nil ? "Nueva persona" : "Editar persona")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        var n = p; n.name = n.name.trimmingCharacters(in: .whitespaces)
                        store.save(n); Haptic.success(); onSave?(n); dismiss()
                    }.bold().disabled(p.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog("¿Seguro que quieres borrar a \(p.name)?", isPresented: $askDelete, titleVisibility: .visible) {
                Button("Borrar persona y sus movimientos", role: .destructive) { store.deletePerson(p); Haptic.heavy(); dismiss() }
            } message: { Text("Se borrarán también todas sus cuentas.") }
            .onChange(of: photoItem) { _, item in
                Task {
                    guard let item, let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) else { return }
                    let side: CGFloat = 256
                    let r = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
                    let small = r.jpegData(withCompressionQuality: 0.8) { _ in
                        let s = max(side / img.size.width, side / img.size.height)
                        let w = img.size.width * s, h = img.size.height * s
                        img.draw(in: CGRect(x: (side - w) / 2, y: (side - h) / 2, width: w, height: h))
                    }
                    withAnimation { p.photo = small }
                }
            }
            .onAppear {
                if let original { p = original } else { p.color = colors[store.state.people.count % colors.count]; p.emoji = emojis[0].1.randomElement() ?? "😎" }
            }
        }
    }
}
