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
    @State private var editingJob = false
    @State private var payingJob = false

    var body: some View {
        let list = store.shifts(month: month, company: company)
        let sum = store.workSummary(month: month, company: company)
        let jm = store.jobMonth(month)
        let hourly = store.state.companies.filter { c in (company == nil || c.id == company) && (c.archived != true || list.contains { $0.companyId == c.id }) }
        List {
            Section {
                monthBar.listRowInsets(EdgeInsets()).listRowBackground(Color.clear).listRowSeparator(.hidden)
                if store.activeCompanies.count > 1 { companyChips.listRowInsets(EdgeInsets()).listRowBackground(Color.clear).listRowSeparator(.hidden) }
                hero(sum).listRowInsets(EdgeInsets()).listRowBackground(Color.clear).listRowSeparator(.hidden)
            }
            Section {
                if let j = store.state.job {
                    jobRow(j, jm).contentShape(Rectangle()).onTapGesture { Haptic.tap(); editingJob = true }
                } else {
                    Button { Haptic.tap(); editingJob = true } label: { Label("Tengo contrato indefinido", systemImage: "briefcase.fill") }
                }
            } header: { Text("Contrato") }
            if !hourly.isEmpty {
                Section {
                    ForEach(hourly) { c in
                        companyRow(c)
                            .contentShape(Rectangle())
                            .onTapGesture { Haptic.tap(); editingCompany = c }
                    }
                } header: { Text("Por horas") }
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
                if list.isEmpty { Text("Sin turnos este mes").foregroundStyle(.secondary) }
            } header: { Text("Turnos") }
            Color.clear.frame(height: 40).listRowBackground(Color.clear)
        }
        .appList()
        .navigationTitle("Horas trabajadas")
        .onAppear { withAnimation { store.hideFAB = true }; if ProcessInfo.processInfo.arguments.contains("-newshift") { adding = true } }
        .onDisappear { withAnimation { store.hideFAB = false } }
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
        .sheet(isPresented: $adding) { ShiftEditor(original: nil, companyId: company ?? store.activeCompanies.first?.id ?? "") }
        .sheet(item: $editing) { ShiftEditor(original: $0, companyId: $0.companyId) }
        .sheet(item: $paying) { c in PayMonthSheet(company: c, month: month) }
        .sheet(item: $editingCompany) { CompanyEditor(original: $0) }
        .sheet(isPresented: $newCompany) { CompanyEditor(original: nil) }
        .sheet(isPresented: $editingJob) { JobEditor() }
        .sheet(isPresented: $payingJob) { JobPaySheet(month: month) }
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
            Text(Day.monthYearLabel(month + "-01")).font(.title3.weight(.bold)).contentTransition(.numericText())
                .frame(maxWidth: .infinity, alignment: .center)
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
                ForEach(store.activeCompanies) { c in chip(c.id, c.name, c.color) }
            }
        }
    }
    private func chip(_ id: String?, _ label: String, _ color: String) -> some View {
        Button { Haptic.select(); company = id } label: {
            Text(label).font(.subheadline.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 8)
                .foregroundStyle(company == id ? Color.black : Color.primary)
                .background(company == id ? Color(hex: id == nil ? "#e4b3cb" : color) : Color.primary.opacity(0.07), in: Capsule())
        }
        .buttonStyle(PressableStyle())
    }

    private func hero(_ w: WorkSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Neto estimado").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    AmountText(value: w.net, font: .system(size: 40, weight: .bold, design: .rounded))
                    if !w.grossUnknown { Text("Bruto \(store.hideAmounts ? "•••• €" : Money.eur(w.gross))").font(.subheadline).foregroundStyle(.secondary) }
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

    private func jobRow(_ j: Job, _ m: JobMonth?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: "briefcase.fill").font(.system(size: 17, weight: .bold))
                    .frame(width: 44, height: 44).background(Color.income.opacity(0.22), in: Circle()).foregroundStyle(Color.income)
                VStack(alignment: .leading, spacing: 3) {
                    Text(j.company).font(.body.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.75)
                    Text(j.seniority).font(.subheadline).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.75)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 3) {
                    AmountText(value: j.net, font: .body.weight(.semibold), color: .income)
                    Text("neto al mes").font(.caption).foregroundStyle(.secondary)
                }
            }
            if let m {
                HStack(spacing: 10) {
                    jobStat("Al día", m.dayNet, m.dayGross)
                    jobStat(m.paid == nil ? "Llevas" : "Mes entero", m.paid == nil ? m.net : m.fullNet, m.paid == nil ? m.gross : m.fullGross)
                }
                if m.totalMin > 0 {
                    HStack {
                        Label("\(Hours.dec(m.totalMin)) h · \(m.workedDays) día\(m.workedDays == 1 ? "" : "s")", systemImage: "clock.fill")
                        Spacer()
                        if let sc = j.schedule(on: Day.today) { Text("Hoy \(Hours.hm(sc.start)) – \(Hours.hm(sc.end))") }
                    }
                    .font(.footnote).foregroundStyle(.secondary)
                }
                if let p = m.paid {
                    Button { Haptic.tap(); payingJob = true } label: {
                        HStack {
                            Label("Cobrado", systemImage: "checkmark.seal.fill").font(.subheadline.weight(.bold)).foregroundStyle(Color.income)
                            Spacer()
                            AmountText(value: p, font: .subheadline.weight(.bold))
                        }
                    }
                    .buttonStyle(PressableStyle(scale: 0.97))
                } else if month <= Day.monthKey(Day.today) {
                    Button { Haptic.tap(); payingJob = true } label: {
                        Text("Cobrar \(Day.month(month + "-01").lowercased())").font(.subheadline.weight(.bold)).frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(Color.income, in: Capsule()).foregroundStyle(.black)
                    }
                    .buttonStyle(PressableStyle(scale: 0.97))
                }
            }
        }
        .padding(.vertical, 4)
    }
    private func jobStat(_ title: String, _ net: Double, _ gross: Double?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            AmountText(value: net, font: .subheadline.weight(.bold))
            if let gross { Text("bruto \(store.hideAmounts ? "•••• €" : Money.eur(gross))").font(.caption2).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12).background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func companyRow(_ c: Company) -> some View {
        let w = store.summary(store.shifts(month: month, company: c.id))
        return HStack(spacing: 12) {
            Circle().fill(Color(hex: c.color)).frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: 2) {
                Text(c.name).font(.body.weight(.semibold))
                Text("Normal \(Money.eur(c.normalRate))/h · Nocturna \(Money.eur(c.nightRate))/h").font(.caption).foregroundStyle(.secondary)
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
        let w = store.workSummary(month: Day.monthKey(Day.today))
        let jm = store.jobMonth(Day.monthKey(Day.today))
        Button(action: open) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Trabajo de \(Day.month(Day.today).lowercased())", systemImage: "briefcase.fill").font(.title3.weight(.bold)).foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.secondary)
                }
                if let jm {
                    HStack(spacing: 12) {
                        item(nil, "llevas (neto)", w.net)
                        item(nil, "al día", jm.dayNet)
                        item(nil, "pendiente", w.pendingNet)
                    }
                } else {
                    HStack(spacing: 12) {
                        item(Hours.dec(w.totalMin) + " h", "trabajadas", nil)
                        item(nil, "neto estimado", w.net)
                        item(nil, "pendiente", w.pendingNet)
                    }
                }
            }
            .card()
        }
        .buttonStyle(PressableStyle(scale: 0.98))
    }
    private func item(_ text: String?, _ label: String, _ v: Double?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if let text { Text(text).font(.title3.weight(.bold)).foregroundStyle(.primary).lineLimit(1).minimumScaleFactor(0.6) }
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
    @State private var normalText = ""
    @State private var nightText = ""
    @State private var saveRateInCompany = false
    @State private var newCompany = false

    private var normalRate: Double? { Money.parse(normalText) }
    private var nightRate: Double? { Money.parse(nightText) }
    private var rateChanged: Bool {
        guard let c = store.company(companyId) else { return false }
        return (normalRate.map { abs($0 - c.normalRate) > 0.001 } ?? false) || (nightRate.map { abs($0 - c.nightRate) > 0.001 } ?? false)
    }
    private func loadRates() {
        guard let c = store.company(companyId) else { return }
        normalText = Money.num(c.normalRate); nightText = Money.num(c.nightRate)
    }

    private func minutes(_ d: Date) -> Int { Calendar.current.component(.hour, from: d) * 60 + Calendar.current.component(.minute, from: d) }
    private var preview: Shift { Shift(companyId: companyId, date: Day.str(date), start: minutes(start), end: minutes(end), breakMin: breakMin, normalRate: normalRate, nightRate: nightRate) }

    var body: some View {
        NavigationStack {
            Form {
                if store.activeCompanies.isEmpty && store.company(companyId) == nil {
                    Section {
                                                Button { newCompany = true } label: { Label("Nueva empresa", systemImage: "building.2.fill") }
                    }
                } else {
                    Section("Empresa") {
                        Picker("¿Para qué empresa?", selection: $companyId) { ForEach(store.state.companies.filter { $0.archived != true || $0.id == companyId }) { Text($0.name).tag($0.id) } }
                        Button { newCompany = true } label: { Label("Nueva empresa", systemImage: "building.2.fill") }
                    }
                    Section {
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
                    Section {
                        LabeledContent("Hora normal (€)") { TextField("13,59", text: $normalText).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                        LabeledContent("Hora nocturna (€)") { TextField("16,07", text: $nightText).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                        if rateChanged { Toggle("Guardarlo también como precio de \(store.company(companyId)?.name ?? "la empresa")", isOn: $saveRateInCompany) }
                    } header: { Text("Cuánto pagan la hora") }
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
                if companyId.isEmpty { companyId = store.activeCompanies.first?.id ?? "" }
                if let o = original {
                    date = Day.date(o.date)
                    start = Calendar.current.date(bySettingHour: o.start / 60, minute: o.start % 60, second: 0, of: Date()) ?? Date()
                    end = Calendar.current.date(bySettingHour: (o.end / 60) % 24, minute: o.end % 60, second: 0, of: Date()) ?? Date()
                    breakMin = o.breakMin; note = o.note; status = o.status
                    loadRates()
                    if let r = o.normalRate { normalText = Money.num(r) }
                    if let r = o.nightRate { nightText = Money.num(r) }
                } else if let last = store.state.shifts.filter({ $0.companyId == companyId }).max(by: { $0.date < $1.date }) {
                    // el último horario de esa empresa, para no tener que escribirlo cada vez
                    start = Calendar.current.date(bySettingHour: last.start / 60, minute: last.start % 60, second: 0, of: Date()) ?? start
                    end = Calendar.current.date(bySettingHour: (last.end / 60) % 24, minute: last.end % 60, second: 0, of: Date()) ?? end
                    breakMin = last.breakMin
                }
                if original == nil { loadRates() }
            }
            .onChange(of: companyId) { _, _ in loadRates(); saveRateInCompany = false }
            .sheet(isPresented: $newCompany) { CompanyEditor(original: nil) { c in companyId = c.id } }
        }
    }

    private func save() {
        if rateChanged && saveRateInCompany, var c = store.company(companyId) {
            c.normalRate = normalRate ?? c.normalRate; c.nightRate = nightRate ?? c.nightRate; store.save(c)
        }
        let dates: [String] = multi ? days.compactMap { Calendar.current.date(from: $0) }.map { Day.str($0) }.sorted() : [Day.str(date)]
        for (i, d) in dates.enumerated() {
            var s = original ?? Shift(companyId: companyId, date: d, start: 0, end: 0)
            if i > 0 { s.id = UUID().uuidString }
            s.companyId = companyId; s.date = d; s.start = minutes(start); s.end = minutes(end); s.breakMin = breakMin; s.note = note
            s.normalRate = rateChanged && !saveRateInCompany ? normalRate : nil
            s.nightRate = rateChanged && !saveRateInCompany ? nightRate : nil
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
                }
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
    var onSave: ((Company) -> Void)? = nil
    @State private var c = Company(name: "")
    @State private var normal = ""
    @State private var night = ""
    @State private var nStart = Date()
    @State private var nEnd = Date()
    @State private var askDelete = false
    var body: some View {
        NavigationStack {
            Form {
                Section("¿Dónde trabajas?") { TextField("Nombre de la empresa (p. ej. Adecco)", text: $c.name) }
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
                } header: { Text("Para calcular el neto") }
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
                        store.save(n); Haptic.success(); onSave?(n); dismiss()
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

/// cobrar la nómina del contrato de un mes con lo que ha llegado de verdad
struct JobPaySheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let month: String
    @State private var amount = ""
    @State private var accountId = ""
    var body: some View {
        let m = store.jobMonth(month)
        NavigationStack {
            Form {
                Section {
                    if let g = m?.fullGross { LabeledContent("Bruto", value: Money.eur(g)) }
                    LabeledContent("Neto estimado", value: Money.eur(m?.fullNet ?? 0))
                }
                Section {
                    LabeledContent("Lo que te han pagado") { TextField("0,00", text: $amount).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    Picker("Cuenta", selection: $accountId) { ForEach(store.accounts) { Text("\($0.icon) \($0.name)").tag($0.id) } }
                }
            }
            .navigationTitle("Nómina de \(Day.month(month + "-01").lowercased())").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(m?.paid == nil ? "Marcar cobrado" : "Guardar") {
                        store.payJob(month: month, amount: Money.parse(amount) ?? 0, accountId: accountId)
                        Haptic.success(); dismiss()
                    }.bold().disabled((Money.parse(amount) ?? 0) <= 0 || accountId.isEmpty)
                }
            }
            .onAppear {
                amount = Money.num(m?.paid ?? m?.fullNet ?? 0).replacingOccurrences(of: ".", with: "")
                accountId = store.jobTx(month)?.accountId ?? store.state.job?.accountId ?? store.accounts.first?.id ?? ""
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Contrato indefinido: empresa, desde cuándo, bruto al año (lo que dice la oferta), retenciones y neto al mes
struct JobEditor: View {
    private enum Field { case gross, ss, irpf, net }
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focus: Field?
    @State private var name = ""
    @State private var start = Date()
    @State private var gross = ""
    @State private var pays = 12
    @State private var ss = "6,50"
    @State private var irpf = ""
    @State private var irpfManual = false
    @State private var net = ""
    @State private var netManual = false
    @State private var schedules: [JobSchedule] = []
    @State private var editingSchedule: JobSchedule? = nil
    @State private var accountId = ""
    @State private var askRemove = false

    private func plain(_ v: Double) -> String { Money.num(v).replacingOccurrences(of: ".", with: "") }
    private func recompute() {
        guard !netManual, let g = Money.parse(gross), g > 0 else { return }
        net = plain(Job.netMonth(grossYear: g, pays: pays, ss: Money.parse(ss) ?? 0, irpf: Money.parse(irpf) ?? 0))
    }
    private var monthDays: Double { Double(Day.cal.range(of: .day, in: .month, for: Date())?.count ?? 30) }

    var body: some View {
        NavigationStack {
            Form {
                Section("¿Dónde trabajas?") { TextField("Nombre de la empresa", text: $name) }
                Section("Contrato indefinido") {
                    DatePicker("Desde", selection: $start, displayedComponents: .date)
                    Picker("Cuenta donde cobras", selection: $accountId) {
                        ForEach(store.accounts) { Text("\($0.icon) \($0.name)").tag($0.id) }
                    }
                }
                Section("Horario") {
                    ForEach(schedules.sorted { $0.from > $1.from }) { sc in
                        Button { editingSchedule = sc } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(sc.daysLabel) · \(Hours.hm(sc.start)) – \(Hours.hm(sc.end))").font(.body.weight(.semibold)).foregroundStyle(.primary)
                                    Text("Desde el \(Day.shortLabel(sc.from))" + (sc.to.map { " hasta el \(Day.shortLabel($0))" } ?? "")).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(Hours.dur(sc.minutes)).foregroundStyle(.secondary)
                            }
                        }
                    }
                    Button { editingSchedule = JobSchedule(from: schedules.isEmpty ? Day.str(start) : Day.today) } label: { Label("Añadir horario", systemImage: "clock.badge.fill") }
                }
                Section("Sueldo") {
                    LabeledContent("Bruto al año (€)") { TextField("22.000", text: $gross).keyboardType(.decimalPad).multilineTextAlignment(.trailing).focused($focus, equals: .gross) }
                    Picker("Pagas", selection: $pays) { Text("12").tag(12); Text("14").tag(14) }.pickerStyle(.segmented)
                    LabeledContent("Seguridad Social (%)") { TextField("6,50", text: $ss).keyboardType(.decimalPad).multilineTextAlignment(.trailing).focused($focus, equals: .ss) }
                    LabeledContent("IRPF (%)") { TextField("0,00", text: $irpf).keyboardType(.decimalPad).multilineTextAlignment(.trailing).focused($focus, equals: .irpf) }
                    LabeledContent("Neto al mes (€)") { TextField("1.400,00", text: $net).keyboardType(.decimalPad).multilineTextAlignment(.trailing).focused($focus, equals: .net) }
                }
                if let n = Money.parse(net), n > 0 {
                    Section("Al día") {
                        if let g = Money.parse(gross), g > 0 { LabeledContent("Bruto", value: Money.eur(g / Double(pays) / monthDays)) }
                        LabeledContent("Neto", value: Money.eur(n / monthDays))
                    }
                }
                if store.state.job != nil { Section { Button("Quitar contrato", role: .destructive) { askRemove = true } } }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Contrato").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        var j = store.state.job ?? Job(company: "", start: Day.today, net: 0, accountId: accountId)
                        j.company = name.trimmingCharacters(in: .whitespaces); j.start = Day.str(start)
                        j.net = Money.parse(net) ?? 0; j.accountId = accountId; j.schedules = schedules
                        let g = Money.parse(gross) ?? 0
                        j.grossYear = g > 0 ? g : nil; j.pays = pays
                        j.ssPct = Money.parse(ss); j.irpfPct = Money.parse(irpf); j.netManual = netManual
                        store.saveJob(j); Haptic.success(); dismiss()
                    }
                    .bold().disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || (Money.parse(net) ?? 0) <= 0 || accountId.isEmpty)
                }
            }
            .confirmationDialog("¿Seguro que quieres quitar el contrato?", isPresented: $askRemove, titleVisibility: .visible) {
                Button("Quitar contrato", role: .destructive) { store.removeJob(); Haptic.heavy(); dismiss() }
            } message: { Text("Las nóminas ya apuntadas se quedan.") }
            .sheet(item: $editingSchedule) { sc in
                ScheduleEditor(original: sc, isNew: !schedules.contains { $0.id == sc.id }) { n in
                    if let i = schedules.firstIndex(where: { $0.id == n.id }) { schedules[i] = n } else { schedules.append(n) }
                } onDelete: { schedules.removeAll { $0.id == sc.id } }
            }
            .onChange(of: gross) { _, _ in
                if focus == .gross, !irpfManual, let g = Money.parse(gross), g > 0 { irpf = plain(Job.irpfEstimate(g)) }
                recompute()
            }
            .onChange(of: pays) { _, _ in recompute() }
            .onChange(of: ss) { _, _ in recompute() }
            .onChange(of: irpf) { _, _ in if focus == .irpf { irpfManual = !irpf.isEmpty }; recompute() }
            .onChange(of: net) { _, _ in if focus == .net { netManual = !net.isEmpty; if net.isEmpty { recompute() } } }
            .onAppear {
                if let j = store.state.job {
                    name = j.company; start = Day.date(j.start); net = plain(j.net); accountId = j.accountId; schedules = j.schedules ?? []
                    pays = j.pays ?? 12
                    if let v = j.ssPct { ss = plain(v) }
                    if let v = j.irpfPct { irpf = plain(v); irpfManual = true }
                    if let g = j.grossYear { gross = plain(g); netManual = j.netManual ?? false } else { netManual = false }
                } else { accountId = store.accounts.first?.id ?? "" }
            }
        }
    }
}

/// un horario del contrato: días de la semana, horas y entre qué fechas vale
struct ScheduleEditor: View {
    @Environment(\.dismiss) private var dismiss
    let original: JobSchedule
    let isNew: Bool
    var onSave: (JobSchedule) -> Void
    var onDelete: () -> Void
    @State private var days: Set<Int> = []
    @State private var start = Date()
    @State private var end = Date()
    @State private var breakMin = 0
    @State private var from = Date()
    @State private var hasEnd = false
    @State private var to = Date()
    @State private var askDelete = false

    private func minutes(_ d: Date) -> Int { Calendar.current.component(.hour, from: d) * 60 + Calendar.current.component(.minute, from: d) }
    private func time(_ m: Int) -> Date { Calendar.current.date(bySettingHour: (m / 60) % 24, minute: m % 60, second: 0, of: Date()) ?? Date() }
    private var result: JobSchedule {
        var n = original
        n.weekdays = days.sorted(); n.start = minutes(start); n.end = minutes(end); n.breakMin = breakMin
        n.from = Day.str(from); n.to = hasEnd ? Day.str(max(to, from)) : nil
        return n
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Días") {
                    HStack(spacing: 6) {
                        ForEach(1...7, id: \.self) { d in
                            let on = days.contains(d)
                            Button { Haptic.select(); if on { days.remove(d) } else { days.insert(d) } } label: {
                                Text(["L", "M", "X", "J", "V", "S", "D"][d - 1]).font(.subheadline.weight(.bold))
                                    .frame(maxWidth: .infinity).frame(height: 38)
                                    .foregroundStyle(on ? Color.black : Color.primary)
                                    .background(on ? Color.income : Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                }
                Section("Horario") {
                    DatePicker("Entrada", selection: $start, displayedComponents: .hourAndMinute)
                    DatePicker("Salida", selection: $end, displayedComponents: .hourAndMinute)
                    Stepper("Descanso: \(breakMin) min", value: $breakMin, in: 0...240, step: 15)
                    LabeledContent("Al día", value: Hours.dur(result.minutes))
                    LabeledContent("A la semana", value: Hours.dur(result.minutes * days.count))
                }
                Section("Fechas") {
                    DatePicker("Desde", selection: $from, displayedComponents: .date)
                    Toggle("Tiene fin", isOn: $hasEnd.animation())
                    if hasEnd { DatePicker("Hasta", selection: $to, in: from..., displayedComponents: .date) }
                }
                if !isNew { Section { Button("Borrar horario", role: .destructive) { Haptic.warning(); askDelete = true } } }
            }
            .navigationTitle("Horario").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Guardar") { onSave(result); Haptic.success(); dismiss() }.bold().disabled(days.isEmpty) }
            }
            .confirmationDialog("¿Seguro que quieres borrar este horario?", isPresented: $askDelete, titleVisibility: .visible) {
                Button("Borrar", role: .destructive) { onDelete(); Haptic.heavy(); dismiss() }
                Button("Cancelar", role: .cancel) {}
            }
            .onAppear {
                days = Set(original.weekdays); start = time(original.start); end = time(original.end); breakMin = original.breakMin
                from = Day.date(original.from); hasEnd = original.to != nil; to = original.to.map { Day.date($0) } ?? Day.date(original.from)
            }
        }
    }
}
