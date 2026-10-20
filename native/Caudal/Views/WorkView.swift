import SwiftUI

/// Horas trabajadas: turnos por empresa, horas normales y nocturnas calculadas solas, bruto, neto, pagado y pendiente
struct WorkView: View {
    @Environment(Store.self) private var store
    @State private var month = Day.monthKey(Day.today)
    @State private var company: String? = nil
    @State private var adding = false
    @State private var editing: Shift? = nil
    @State private var pendingDelete: Shift? = nil
    @State private var askDelete = false
    @State private var paying: Company? = nil
    @State private var editingCompany: Company? = nil
    @State private var newCompany = false

    var body: some View {
        let list = store.shifts(month: month, company: company)
        let sum = store.summary(list)
        List {
            Section {
                monthBar.listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                if store.state.companies.count > 1 { companyChips.listRowInsets(EdgeInsets()).listRowBackground(Color.clear) }
                hero(sum).listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
            }
            if !store.state.companies.isEmpty {
                Section("Por empresa") {
                    ForEach(store.state.companies.filter { company == nil || $0.id == company }) { c in companyRow(c) }
                }
            }
            Section {
                ForEach(list) { s in
                    shiftRow(s)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button { Haptic.warning(); pendingDelete = s; askDelete = true } label: { Label("Borrar", systemImage: "trash.fill") }.tint(.red)
                            Button { store.duplicateShift(s) } label: { Label("Duplicar", systemImage: "plus.square.on.square") }.tint(.indigo)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button { Haptic.success(); store.setPaid([s.id], s.status != .pagado) } label: {
                                Label(s.status == .pagado ? "Pendiente" : "Pagado", systemImage: s.status == .pagado ? "clock" : "checkmark.circle.fill")
                            }
                            .tint(s.status == .pagado ? .orange : .green)
                        }
                }
                if list.isEmpty { Text("No hay turnos este mes. Pulsa + para apuntar uno.").foregroundStyle(.secondary) }
            } header: { Text("Turnos") } footer: {
                Text("Desliza a la derecha para marcar pagado o pendiente. El neto es una estimación con las retenciones de cada empresa (Seguridad Social e IRPF); ajústalas en la empresa para que coincida con tu nómina.")
            }
            Color.clear.frame(height: 40).listRowBackground(Color.clear)
        }
        .navigationTitle("Horas trabajadas")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { newCompany = true } label: { Label("Nueva empresa", systemImage: "building.2") }
                    ForEach(store.state.companies) { c in Button { editingCompany = c } label: { Label("Editar \(c.name)", systemImage: "pencil") } }
                } label: { Image(systemName: "building.2.crop.circle") }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { Haptic.tap(); adding = true } label: { Image(systemName: "plus.circle.fill").font(.title3) }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: month)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: company)
        .sheet(isPresented: $adding) { ShiftEditor(original: nil, companyId: company ?? store.state.companies.first?.id ?? "") }
        .sheet(item: $editing) { ShiftEditor(original: $0, companyId: $0.companyId) }
        .sheet(item: $paying) { c in PayMonthSheet(company: c, month: month) }
        .sheet(item: $editingCompany) { CompanyEditor(original: $0) }
        .sheet(isPresented: $newCompany) { CompanyEditor(original: nil) }
        .confirmationDialog("¿Seguro que quieres borrar este turno?", isPresented: $askDelete, titleVisibility: .visible, presenting: pendingDelete) { s in
            Button("Borrar", role: .destructive) { Haptic.heavy(); store.deleteShift(s) }
            Button("Cancelar", role: .cancel) {}
        } message: { s in Text("\(Day.header(s.date)) · \(Hours.hm(s.start))–\(Hours.hm(s.end)) · \(store.company(s.companyId)?.name ?? "")") }
    }

    // MARK: cabecera

    private var months: [String] {
        let keys = Set(store.state.shifts.map { Day.monthKey($0.date) }).union([Day.monthKey(Day.today)])
        return keys.sorted()
    }
    private var monthBar: some View {
        HStack {
            Button { move(-1) } label: { Image(systemName: "chevron.left.circle.fill").font(.title) }
            Spacer()
            Text(Day.monthYearLabel(month + "-01")).font(.title3.weight(.bold)).contentTransition(.numericText())
            Spacer()
            Button { move(1) } label: { Image(systemName: "chevron.right.circle.fill").font(.title) }
        }
        .symbolRenderingMode(.hierarchical)
        .buttonStyle(PressableStyle(scale: 0.85))
        .padding(.horizontal, 4)
    }
    private func move(_ k: Int) {
        Haptic.select()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { month = Day.monthKey(Day.add(month + "-01", months: k)) }
    }

    private var companyChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chip(nil, "Todas", "#ffffff")
                ForEach(store.state.companies) { c in chip(c.id, c.name, c.color) }
            }
        }
    }
    private func chip(_ id: String?, _ label: String, _ color: String) -> some View {
        Button { Haptic.select(); company = id } label: {
            Text(label).font(.subheadline.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 8)
                .foregroundStyle(company == id ? Color.black : Color.primary)
                .background(company == id ? Color(hex: id == nil ? "#e4b3cb" : color) : Color.white.opacity(0.07), in: Capsule())
        }
        .buttonStyle(PressableStyle())
    }

    private func hero(_ w: WorkSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Neto estimado").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    AmountText(value: w.net, font: .system(size: 40, weight: .bold, design: .rounded))
                    Text("Bruto \(store.hideAmounts ? "•••• €" : Money.eur(w.gross))").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(Hours.dec(w.totalMin) + " h").font(.system(size: 30, weight: .bold, design: .rounded)).contentTransition(.numericText())
                    Text("\(w.days) día\(w.days == 1 ? "" : "s")").font(.caption).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 10) {
                pill("sun.max.fill", "Normales", Hours.dur(w.normalMin), Color(hex: "#f0c46a"))
                pill("moon.stars.fill", "Nocturnas", Hours.dur(w.nightMin), Color(hex: "#8fb4ff"))
            }
            if w.net > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    GeometryReader { g in
                        HStack(spacing: 3) {
                            Capsule().fill(Color.income.gradient).frame(width: max(4, (g.size.width - 3) * w.paidNet / max(w.net, 0.01)))
                            Capsule().fill(Color.orange.gradient)
                        }
                    }
                    .frame(height: 10)
                    HStack {
                        HStack(spacing: 4) { Circle().fill(Color.income).frame(width: 8, height: 8); Text("Pagado").foregroundStyle(.secondary); AmountText(value: w.paidNet, font: .footnote.weight(.semibold)) }
                        Spacer()
                        HStack(spacing: 4) { Circle().fill(Color.orange).frame(width: 8, height: 8); Text("Pendiente").foregroundStyle(.secondary); AmountText(value: w.pendingNet, font: .footnote.weight(.semibold)) }
                    }
                    .font(.footnote)
                }
            }
        }
        .card(20)
    }
    private func pill(_ icon: String, _ t: String, _ v: String, _ c: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(c)
            VStack(alignment: .leading, spacing: 0) {
                Text(t).font(.caption).foregroundStyle(.secondary)
                Text(v).font(.subheadline.weight(.bold)).contentTransition(.numericText())
            }
            Spacer(minLength: 0)
        }
        .padding(12).background(c.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: filas

    private func companyRow(_ c: Company) -> some View {
        let w = store.summary(store.shifts(month: month, company: c.id))
        return HStack(spacing: 12) {
            Circle().fill(Color(hex: c.color)).frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: 2) {
                Text(c.name).font(.body.weight(.semibold))
                Text("\(Hours.dec(w.totalMin)) h · bruto \(Money.eur(w.gross)) · neto \(Money.eur(w.net))").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if w.pendingNet > 0 {
                Button { Haptic.tap(); paying = c } label: {
                    Text("Cobrar").font(.caption.weight(.bold)).padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Color.income, in: Capsule()).foregroundStyle(.black)
                }
                .buttonStyle(PressableStyle())
            } else if w.totalMin > 0 {
                Label("Pagado", systemImage: "checkmark.seal.fill").font(.caption.weight(.bold)).foregroundStyle(Color.income)
            }
        }
    }

    private func shiftRow(_ s: Shift) -> some View {
        let r = store.calc(s)
        let c = store.company(s.companyId)
        return Button { editing = s } label: {
            HStack(spacing: 12) {
                VStack(spacing: 0) {
                    Text(String(Day.date(s.date).formatted(.dateTime.day()))).font(.title3.weight(.bold))
                    Text(Day.date(s.date).formatted(.dateTime.weekday(.abbreviated).locale(Locale(identifier: "es_ES"))).uppercased()).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                }
                .frame(width: 44, height: 48)
                .background(Color(hex: c?.color ?? "#7ac8ff").opacity(0.18), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(Hours.hm(s.start)) – \(Hours.hm(s.end)) · \(Hours.dur(r.totalMin))").font(.body.weight(.semibold))
                    HStack(spacing: 6) {
                        if r.nightMin > 0 { Label(Hours.dur(r.nightMin) + " nocturnas", systemImage: "moon.fill").foregroundStyle(Color(hex: "#8fb4ff")) }
                        Text(c?.name ?? "").foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    AmountText(value: r.gross, font: .body.weight(.bold))
                    Text(s.status.label).font(.caption2.weight(.bold))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background((s.status == .pagado ? Color.income : Color.orange).opacity(0.2), in: Capsule())
                        .foregroundStyle(s.status == .pagado ? Color.income : Color.orange)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

extension Store {
    func duplicateShift(_ s: Shift) {
        var n = s; n.id = UUID().uuidString; n.date = Day.add(s.date, days: 1); n.status = .pendiente; n.paidDate = ""
        save(n); Haptic.tap()
    }
}

/// tarjeta del inicio con las horas del mes
struct WorkCard: View {
    @Environment(Store.self) private var store
    var open: () -> Void
    var body: some View {
        let w = store.summary(store.shifts(month: Day.monthKey(Day.today)))
        Button(action: open) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Trabajo de \(Day.month(Day.today).lowercased())", systemImage: "briefcase.fill").font(.title3.weight(.bold)).foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    item(Hours.dec(w.totalMin) + " h", "trabajadas", nil)
                    item(nil, "neto estimado", w.net)
                    item(nil, "pendiente", w.pendingNet)
                }
            }
            .card()
        }
        .buttonStyle(PressableStyle(scale: 0.98))
    }
    private func item(_ text: String?, _ label: String, _ v: Double?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if let text { Text(text).font(.title3.weight(.bold)).foregroundStyle(.primary) }
            if let v { AmountText(value: v, font: .title3.weight(.bold), color: label == "pendiente" && v > 0 ? .orange : nil) }
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Apuntar turno (uno o varios días)

struct ShiftEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let original: Shift?
    @State var companyId: String
    @State private var days: Set<DateComponents> = []
    @State private var date = Date()
    @State private var start = Calendar.current.date(bySettingHour: 16, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var end = Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var breakMin = 0
    @State private var note = ""
    @State private var status: PayStatus = .pendiente
    @State private var multi = false
    @State private var saved = false
    @State private var askDelete = false

    private func minutes(_ d: Date) -> Int { Calendar.current.component(.hour, from: d) * 60 + Calendar.current.component(.minute, from: d) }
    private var preview: Shift { Shift(companyId: companyId, date: Day.str(date), start: minutes(start), end: minutes(end), breakMin: breakMin) }

    var body: some View {
        NavigationStack {
            Form {
                if store.state.companies.isEmpty {
                    Section { Text("Primero crea una empresa (botón del edificio arriba en Horas trabajadas).").foregroundStyle(.secondary) }
                } else {
                    Section {
                        Picker("Empresa", selection: $companyId) { ForEach(store.state.companies) { Text($0.name).tag($0.id) } }
                        if original == nil { Toggle("Varios días", isOn: $multi.animation()) }
                        if multi {
                            MultiDatePicker("Días", selection: $days).frame(minHeight: 300)
                        } else {
                            DatePicker("Día", selection: $date, displayedComponents: .date)
                        }
                    }
                    Section("Horario") {
                        DatePicker("Entrada", selection: $start, displayedComponents: .hourAndMinute)
                        DatePicker("Salida", selection: $end, displayedComponents: .hourAndMinute)
                        Stepper("Descanso: \(breakMin) min", value: $breakMin, in: 0...240, step: 15)
                    }
                    if let c = store.company(companyId) {
                        let r = Hours.calc(preview, c)
                        Section {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(Hours.dur(r.totalMin)).font(.title2.weight(.bold)).contentTransition(.numericText())
                                    Text("\(Hours.dur(r.normalMin)) normales · \(Hours.dur(r.nightMin)) nocturnas").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(Money.eur(r.gross * Double(max(1, multi ? days.count : 1)))).font(.title3.weight(.bold)).contentTransition(.numericText())
                                    Text("bruto\(multi && days.count > 1 ? " (\(days.count) días)" : "") · neto \(Money.eur(Hours.net(r.gross, c) * Double(max(1, multi ? days.count : 1))))").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .animation(.spring, value: r.totalMin)
                        } footer: {
                            Text("Normal \(Money.eur(c.normalRate))/h · Nocturna \(Money.eur(c.nightRate))/h (de \(Hours.hm(c.nightStart)) a \(Hours.hm(c.nightEnd))). Si sales después de medianoche, cuenta hasta el día siguiente.")
                        }
                    }
                    Section {
                        Picker("Estado", selection: $status) { ForEach(PayStatus.allCases) { Text($0.label).tag($0) } }.pickerStyle(.segmented)
                        TextField("Nota (opcional)", text: $note)
                    }
                    if original != nil {
                        Section { Button("Borrar turno", role: .destructive) { Haptic.warning(); askDelete = true } }
                    }
                }
            }
            .navigationTitle(original == nil ? "Apuntar horas" : "Editar turno").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Guardar", action: save).bold().disabled(companyId.isEmpty || (multi && days.isEmpty)) }
            }
            .confirmationDialog("¿Seguro que quieres borrar este turno?", isPresented: $askDelete, titleVisibility: .visible) {
                Button("Borrar", role: .destructive) { if let o = original { store.deleteShift(o) }; Haptic.heavy(); dismiss() }
            }
            .overlay {
                if saved {
                    VStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 64, weight: .bold)).foregroundStyle(Color.income).symbolEffect(.bounce, value: saved)
                        Text("Apuntado").font(.headline)
                    }
                    .padding(30).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .onAppear {
                if companyId.isEmpty { companyId = store.state.companies.first?.id ?? "" }
                if let o = original {
                    date = Day.date(o.date)
                    start = Calendar.current.date(bySettingHour: o.start / 60, minute: o.start % 60, second: 0, of: Date()) ?? Date()
                    end = Calendar.current.date(bySettingHour: (o.end / 60) % 24, minute: o.end % 60, second: 0, of: Date()) ?? Date()
                    breakMin = o.breakMin; note = o.note; status = o.status
                } else if let last = store.state.shifts.filter({ $0.companyId == companyId }).max(by: { $0.date < $1.date }) {
                    // el último horario de esa empresa, para no tener que escribirlo cada vez
                    start = Calendar.current.date(bySettingHour: last.start / 60, minute: last.start % 60, second: 0, of: Date()) ?? start
                    end = Calendar.current.date(bySettingHour: (last.end / 60) % 24, minute: last.end % 60, second: 0, of: Date()) ?? end
                    breakMin = last.breakMin
                }
            }
        }
    }

    private func save() {
        let dates: [String] = multi ? days.compactMap { Calendar.current.date(from: $0) }.map { Day.str($0) }.sorted() : [Day.str(date)]
        for (i, d) in dates.enumerated() {
            var s = original ?? Shift(companyId: companyId, date: d, start: 0, end: 0)
            if i > 0 { s.id = UUID().uuidString }
            s.companyId = companyId; s.date = d; s.start = minutes(start); s.end = minutes(end); s.breakMin = breakMin; s.note = note
            if s.status != status { s.status = status; s.paidDate = status == .pagado ? Day.today : "" }
            store.save(s)
        }
        Haptic.success()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { saved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { dismiss() }
    }
}

/// cobrar lo pendiente del mes de una empresa
struct PayMonthSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let company: Company
    let month: String
    @State private var amount = ""
    @State private var addIncome = true
    @State private var accountId = ""
    var body: some View {
        let w = store.summary(store.shifts(month: month, company: company.id).filter { $0.status == .pendiente })
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Horas pendientes", value: Hours.dur(w.totalMin))
                    LabeledContent("Bruto", value: Money.eur(w.gross))
                    LabeledContent("Neto estimado", value: Money.eur(w.net))
                }
                Section {
                    LabeledContent("Lo que te han pagado") { TextField("0,00", text: $amount).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    Toggle("Apuntarlo como ingreso", isOn: $addIncome.animation())
                    if addIncome { Picker("Cuenta", selection: $accountId) { ForEach(store.accounts) { Text("\($0.icon) \($0.name)").tag($0.id) } } }
                } footer: { Text("Si lo que te pagan no coincide con el neto estimado, ajusta las retenciones de \(company.name).") }
            }
            .navigationTitle("Cobro de \(Day.month(month + "-01").lowercased())").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Marcar pagado") {
                        store.payMonth(company: company, month: month, amount: Money.parse(amount) ?? w.net, accountId: addIncome ? accountId : nil)
                        Haptic.success(); dismiss()
                    }.bold()
                }
            }
            .onAppear { amount = Money.num(w.net).replacingOccurrences(of: ".", with: ""); accountId = company.accountId ?? store.accounts.first?.id ?? "" }
        }
        .presentationDetents([.medium, .large])
    }
}

struct CompanyEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let original: Company?
    @State private var c = Company(name: "")
    @State private var normal = ""
    @State private var night = ""
    @State private var nStart = Date()
    @State private var nEnd = Date()
    @State private var askDelete = false
    var body: some View {
        NavigationStack {
            Form {
                Section { TextField("Nombre (p. ej. Adecco)", text: $c.name) }
                Section("Precio por hora (bruto)") {
                    LabeledContent("Hora normal (€)") { TextField("13,59", text: $normal).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    LabeledContent("Hora nocturna (€)") { TextField("16,07", text: $night).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    DatePicker("Nocturna desde", selection: $nStart, displayedComponents: .hourAndMinute)
                    DatePicker("Hasta", selection: $nEnd, displayedComponents: .hourAndMinute)
                }
                Section {
                    Stepper("Seguridad Social: \(Money.num(c.ssPct)) %", value: $c.ssPct, in: 0...15, step: 0.05)
                    Stepper("IRPF: \(Money.num(c.irpfPct)) %", value: $c.irpfPct, in: 0...40, step: 0.5)
                    Picker("Cuenta donde cobras", selection: Binding(get: { c.accountId ?? "" }, set: { c.accountId = $0.isEmpty ? nil : $0 })) {
                        Text("Ninguna").tag("")
                        ForEach(store.accounts) { Text("\($0.icon) \($0.name)").tag($0.id) }
                    }
                } header: { Text("Para calcular el neto") } footer: {
                    Text("En una ETT con contrato temporal la Seguridad Social del trabajador ronda el 6,5 %. El IRPF lo ves en tu nómina (suele ser bajo, del 2 al 10 %).")
                }
                Section("Color") { ColorRow(color: $c.color) }
                if original != nil { Section { Button("Borrar empresa y sus turnos", role: .destructive) { askDelete = true } } }
            }
            .navigationTitle(original == nil ? "Nueva empresa" : c.name).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        var n = c
                        n.normalRate = Money.parse(normal) ?? n.normalRate
                        n.nightRate = Money.parse(night) ?? n.nightRate
                        let cal = Calendar.current
                        n.nightStart = cal.component(.hour, from: nStart) * 60 + cal.component(.minute, from: nStart)
                        n.nightEnd = cal.component(.hour, from: nEnd) * 60 + cal.component(.minute, from: nEnd)
                        store.save(n); Haptic.success(); dismiss()
                    }.bold().disabled(c.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog("¿Seguro que quieres borrar \(c.name)?", isPresented: $askDelete, titleVisibility: .visible) {
                Button("Borrar empresa y sus turnos", role: .destructive) { store.deleteCompany(c); Haptic.heavy(); dismiss() }
            } message: { Text("Se borrarán también todas sus horas apuntadas.") }
            .onAppear {
                if let original { c = original } else { c.color = palette[store.state.companies.count % palette.count]; c.accountId = store.accounts.first?.id }
                normal = Money.num(c.normalRate); night = Money.num(c.nightRate)
                nStart = Calendar.current.date(bySettingHour: c.nightStart / 60, minute: c.nightStart % 60, second: 0, of: Date()) ?? Date()
                nEnd = Calendar.current.date(bySettingHour: c.nightEnd / 60, minute: c.nightEnd % 60, second: 0, of: Date()) ?? Date()
            }
        }
    }
}
