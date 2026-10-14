import SwiftUI

/// Apuntar o editar un movimiento: importe grande con teclado propio, tipo, categoría, cuenta, fecha y concepto.
struct TxEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let original: Tx?

    @State private var type: TxType = .expense
    @State private var digits = ""          // lo tecleado, p. ej. "12,5"
    @State private var title = ""
    @State private var note = ""
    @State private var categoryId: String? = nil
    @State private var accountId = ""
    @State private var toAccountId = ""
    @State private var date = Date()
    @State private var excluded = false
    @State private var userPickedCategory = false
    @State private var shake = 0
    @State private var saved = false
    @State private var askDelete = false
    @FocusState private var titleFocused: Bool
    @FocusState private var amountFocused: Bool
    @Namespace private var ns

    private var amount: Double { Money.parse(digits) ?? 0 }
    private var types: [TxType] { original?.type == .adjust ? [.adjust] : [.expense, .income, .transfer] }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    typePicker
                    amountDisplay
                    if type == .transfer { transferAccounts } else { categoryGrid; accountPicker }
                    details
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .animation(.spring(response: 0.4, dampingFraction: 0.82), value: type)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .navigationTitle(original == nil ? "Nuevo movimiento" : "Editar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button { save() } label: { Text("Guardar").bold() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button { amountFocused = false; titleFocused = false } label: { Text("Listo") }
                    Button { save() } label: { Label("Guardar", systemImage: "checkmark.circle.fill").labelStyle(.titleAndIcon).bold() }
                }
                if original != nil {
                    ToolbarItem(placement: .bottomBar) {
                        Button(role: .destructive) { Haptic.warning(); askDelete = true } label: {
                            Label("Eliminar movimiento", systemImage: "trash").foregroundStyle(.red)
                        }
                    }
                }
            }
            .confirmationDialog("¿Seguro que quieres eliminar este \(type == .income ? "ingreso" : type == .transfer ? "movimiento" : "gasto")?",
                                isPresented: $askDelete, titleVisibility: .visible) {
                Button("Eliminar", role: .destructive) {
                    if let o = original { Haptic.heavy(); store.delete(o) }
                    dismiss()
                }
                Button("Cancelar", role: .cancel) {}
            } message: { Text("Podrás deshacerlo justo después.") }
            .overlay { if saved { SavedBadge().transition(.scale(scale: 0.6).combined(with: .opacity)) } }
        }
        .presentationDragIndicator(.visible)
        .onAppear {
            load()
            if original == nil { DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { amountFocused = true } }
        }
    }

    // MARK: piezas

    private var typePicker: some View {
        HStack(spacing: 4) {
            ForEach(types) { t in
                Button {
                    Haptic.select()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        type = t
                        if !userPickedCategory { categoryId = nil; autoCategory() }
                    }
                } label: {
                    Text(t.label)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .foregroundStyle(type == t ? Color.black : Color.primary)
                        .background {
                            if type == t { Capsule().fill(color(t)).matchedGeometryEffect(id: "type", in: ns) }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.cardBG, in: Capsule())
        .padding(.top, 6)
    }

    private func color(_ t: TxType) -> Color {
        switch t {
        case .expense: return Color(hex: "#ff9f7a")
        case .income: return .income
        case .transfer: return Color(hex: "#8fb4ff")
        case .adjust: return .gray
        }
    }

    private var amountDisplay: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(type == .expense ? "−" : type == .income ? "+" : "")
                    .foregroundStyle(color(type))
                // se ve siempre al mismo tamaño; lo que se teclea va a un campo invisible con el teclado del iPhone
                Text(digits.isEmpty ? "0" : digits)
                    .foregroundStyle(digits.isEmpty ? Color.secondary : Color.primary)
                    .contentTransition(.numericText())
                    .overlay(alignment: .trailing) {
                        if amountFocused {
                            Capsule().fill(color(type)).frame(width: 3, height: 52).offset(x: 6)
                                .modifier(Blink())
                        }
                    }
                Text("€").foregroundStyle(.secondary)
            }
            // el mismo tamaño para todo (solo baja un punto, a la vez, si el número es muy largo)
            .font(.system(size: digits.count > 8 ? 44 : (digits.count > 6 ? 52 : 60), weight: .bold, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .background {
                TextField("", text: $digits)
                    .keyboardType(.decimalPad)
                    .focused($amountFocused)
                    .opacity(0.01)
                    .allowsHitTesting(false)
                    .onChange(of: digits) { _, v in let c = clean(v); if c != v { digits = c } }
            }
            .modifier(Shake(animatable: CGFloat(shake)))
            .contentShape(Rectangle())
            .onTapGesture { amountFocused = true }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: digits)
            if let a = store.account(accountId), type != .transfer {
                Text("Saldo de \(a.name): \(Money.eur(store.balance(a)))").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private var categoryGrid: some View {
        let cats = store.categories(type == .income ? .income : .expense)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Categoría").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary).padding(.leading, 4)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: [GridItem(.fixed(78)), GridItem(.fixed(78))], spacing: 10) {
                    ForEach(cats) { c in
                        let on = categoryId == c.id
                        Button {
                            Haptic.select()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) { categoryId = c.id; userPickedCategory = true }
                        } label: {
                            VStack(spacing: 4) {
                                Text(c.icon).font(.system(size: 26))
                                    .scaleEffect(on ? 1.18 : 1)
                                Text(c.name).font(.caption2.weight(.medium)).lineLimit(1).frame(width: 70)
                            }
                            .frame(width: 78, height: 78)
                            .background(on ? Color(hex: c.color).opacity(0.35) : Color.cardBG, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(on ? Color(hex: c.color) : .clear, lineWidth: 2))
                        }
                        .buttonStyle(PressableStyle(scale: 0.9))
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private var accountPicker: some View {
        HStack {
            Label("Cuenta", systemImage: "creditcard").foregroundStyle(.secondary)
            Spacer()
            Picker("Cuenta", selection: $accountId) {
                ForEach(store.accounts) { Text("\($0.icon) \($0.name)").tag($0.id) }
            }
            .pickerStyle(.menu)
        }
        .card(14)
    }

    private var transferAccounts: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Desde").foregroundStyle(.secondary)
                Spacer()
                Picker("Desde", selection: $accountId) { ForEach(store.accounts) { Text("\($0.icon) \($0.name)").tag($0.id) } }.pickerStyle(.menu)
            }
            Button {
                Haptic.tap()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { swap(&accountId, &toAccountId) }
            } label: {
                Image(systemName: "arrow.up.arrow.down.circle.fill").font(.title).symbolRenderingMode(.hierarchical)
            }
            .padding(.vertical, 2)
            HStack {
                Text("Hacia").foregroundStyle(.secondary)
                Spacer()
                Picker("Hacia", selection: $toAccountId) { ForEach(store.accounts) { Text("\($0.icon) \($0.name)").tag($0.id) } }.pickerStyle(.menu)
            }
        }
        .card(14)
    }

    private var details: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "text.cursor").foregroundStyle(.secondary).frame(width: 22)
                TextField("Concepto (p. ej. Mercadona)", text: $title)
                    .focused($titleFocused)
                    .submitLabel(.done)
                    .onChange(of: title) { _, _ in if !userPickedCategory { withAnimation(.spring) { autoCategory() } } }
            }
            if titleFocused && !suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(suggestions, id: \.self) { s in
                            Button(s) { title = s; titleFocused = false; Haptic.tap() }
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(Color.white.opacity(0.08), in: Capsule())
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
            Divider()
            HStack {
                Image(systemName: "note.text").foregroundStyle(.secondary).frame(width: 22)
                TextField("Nota", text: $note)
            }
            Divider()
            DatePicker(selection: $date) {
                Label("Fecha", systemImage: "calendar").foregroundStyle(.secondary)
            }
            if type == .expense || type == .income {
                Divider()
                Toggle(isOn: $excluded) { Label("Excluir de las estadísticas", systemImage: "eye.slash").foregroundStyle(.secondary) }
            }
        }
        .card(14)
    }

    private var suggestions: [String] {
        let q = title.lowercased()
        return Array(store.knownTitles.filter { q.isEmpty || ($0.lowercased().hasPrefix(q) && $0.lowercased() != q) }.prefix(8))
    }

    // MARK: lógica

    /// deja solo números y una coma con dos decimales como mucho
    private func clean(_ v: String) -> String {
        var out = ""; var comma = false; var dec = 0
        for ch in v.replacingOccurrences(of: ".", with: ",") {
            if ch == "," { if !comma { comma = true; out += out.isEmpty ? "0," : "," } ; continue }
            guard ch.isNumber else { continue }
            if comma { if dec >= 2 { continue }; dec += 1 }
            if !comma && out == "0" { out = "" }
            if !comma && out.count >= 9 { continue }
            out.append(ch)
        }
        return out
    }

    private func shakeIt() {
        Haptic.warning()
        withAnimation(.linear(duration: 0.35)) { shake += 1 }
    }

    private func autoCategory() {
        guard type != .transfer else { return }
        if let c = store.guessCategory(title, kind: type == .income ? .income : .expense) { categoryId = c.id }
    }

    private func load() {
        accountId = store.state.accounts.first?.id ?? ""
        toAccountId = store.accounts.dropFirst().first?.id ?? accountId
        guard let o = original else { return }
        type = o.type
        digits = Money.num(abs(o.amount)).replacingOccurrences(of: ".", with: "")
        if digits.hasSuffix(",00") { digits.removeLast(3) }
        title = o.title; note = o.note; categoryId = o.categoryId; userPickedCategory = o.categoryId != nil
        accountId = o.accountId; toAccountId = o.toAccountId ?? toAccountId; excluded = o.excluded
        var comps = Day.cal.dateComponents([.year, .month, .day], from: Day.date(o.date))
        let hm = o.time.split(separator: ":")
        comps.hour = Int(hm.first ?? "12"); comps.minute = Int(hm.last ?? "0")
        date = Day.cal.date(from: comps) ?? Date()
    }

    private func save() {
        guard amount > 0 else { shakeIt(); return }
        if type == .transfer && accountId == toAccountId { shakeIt(); return }
        var t = original ?? Tx(amount: 0, accountId: accountId, date: Day.today)
        t.type = type
        t.amount = type == .adjust ? (original.map { $0.amount < 0 ? -amount : amount } ?? amount) : amount
        t.accountId = accountId
        t.toAccountId = type == .transfer ? toAccountId : nil
        t.categoryId = type == .transfer ? nil : categoryId
        t.title = title.trimmingCharacters(in: .whitespaces)
        t.note = note
        t.date = Day.str(date)
        t.time = Day.time(date)
        t.excluded = excluded
        store.save(t)
        Haptic.success()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { saved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { dismiss() }
    }
}

/// cursor que parpadea
struct Blink: ViewModifier {
    @State private var on = true
    func body(content: Content) -> some View {
        content.opacity(on ? 1 : 0)
            .onAppear { withAnimation(.easeInOut(duration: 0.55).repeatForever()) { on = false } }
    }
}

/// sacudida del importe cuando algo no vale
struct Shake: GeometryEffect {
    var animatable: CGFloat
    var animatableData: CGFloat {
        get { animatable }
        set { animatable = newValue }
    }
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 10 * sin(animatable * .pi * 6), y: 0))
    }
}

/// marca de "guardado" que aparece al guardar
struct SavedBadge: View {
    @State private var draw = false
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72, weight: .bold))
                .foregroundStyle(Color.income)
                .symbolEffect(.bounce, value: draw)
            Text("Guardado").font(.headline)
        }
        .padding(32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .onAppear { draw.toggle() }
    }
}
