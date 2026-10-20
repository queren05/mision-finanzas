import SwiftUI
import UniformTypeIdentifiers

struct LogView: View {
    @Environment(Store.self) private var store
    @State private var newLog = false
    @State private var editing: LogEntry? = nil
    @State private var pendingDelete: LogEntry? = nil
    @State private var askDelete = false

    var body: some View {
        NavigationStack {
            List {
                let logs = store.s.logs.sorted { $0.date != $1.date ? $0.date > $1.date : $0.km > $1.km }
                let year = String(Day.today.prefix(4))
                Section {
                    HStack(spacing: 10) {
                        stat(logs.filter { $0.date.hasPrefix(year) }.reduce(0) { $0 + $1.cost }, "Gastado en \(year)")
                        stat(logs.reduce(0) { $0 + $1.cost }, "Total registrado")
                    }
                    .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                    Button { Haptic.tap(); newLog = true } label: {
                        Label("Registrar un cambio", systemImage: "plus").font(.headline).frame(maxWidth: .infinity).frame(height: 50)
                            .foregroundStyle(.black).background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(PressableStyle())
                    .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                }
                Section {
                    ForEach(logs) { l in
                        let p = store.pieza(l.part)
                        Button { editing = l } label: {
                            HStack(spacing: 12) {
                                Text(p?.ic ?? "🧾").font(.title2).frame(width: 44, height: 44).background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p?.n ?? (l.title.isEmpty ? "Otro" : l.title)).font(.body.weight(.semibold)).lineLimit(1)
                                    Text([Day.shortLabel(l.date), Money.km(l.km), l.where].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if l.cost > 0 { Text(Money.eur(l.cost)).font(.subheadline.weight(.semibold)).monospacedDigit() }
                            }
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button { Haptic.warning(); pendingDelete = l; askDelete = true } label: { Label("Borrar", systemImage: "trash.fill") }.tint(.red)
                        }
                    }
                    if logs.isEmpty {
                        Text("Sin cambios registrados").foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Historial")
            .sheet(isPresented: $newLog) { LogEditor(original: nil, part: "") }
            .sheet(item: $editing) { LogEditor(original: $0, part: $0.part) }
            .confirmationDialog("¿Seguro que quieres borrar este registro?", isPresented: $askDelete, titleVisibility: .visible, presenting: pendingDelete) { l in
                Button("Borrar", role: .destructive) { Haptic.heavy(); store.delete(l) }
                Button("Cancelar", role: .cancel) {}
            } message: { l in Text("\(store.pieza(l.part)?.n ?? l.title) · \(Day.shortLabel(l.date)) · \(Money.km(l.km))") }
        }
    }

    private func stat(_ v: Double, _ l: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Money.eur(v)).font(.title3.weight(.bold)).monospacedDigit().contentTransition(.numericText(value: v))
            Text(l).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading).card(14)
    }
}

struct LogEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let original: LogEntry?
    @State var part: String
    @State private var title = ""
    @State private var date = Date()
    @State private var km = ""
    @State private var cost = ""
    @State private var place = ""
    @State private var note = ""
    @State private var askDelete = false
    @State private var saved = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Qué se ha hecho") {
                    Picker("Pieza", selection: $part) {
                        Text("Otro (escríbelo abajo)").tag("")
                        ForEach(Datos.catOrder, id: \.self) { k in
                            Section(store.datos.CATS[k] ?? k) {
                                ForEach(store.datos.PIEZAS.filter { $0.cat == k }) { p in Text("\(p.ic) \(p.n)").tag(p.id) }
                            }
                        }
                    }
                    .pickerStyle(.navigationLink)
                    if part.isEmpty { TextField("Descripción (ej.: cambio de luneta)", text: $title) }
                }
                Section {
                    DatePicker("Fecha", selection: $date, in: ...Date(), displayedComponents: .date)
                    LabeledContent("Kilómetros") { TextField("0", text: $km).keyboardType(.numberPad).multilineTextAlignment(.trailing) }
                    LabeledContent("Coste (€)") { TextField("0", text: $cost).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    TextField("Dónde (taller, yo…)", text: $place)
                    TextField("Notas (marca, referencia…)", text: $note)
                }
                if original != nil {
                    Section { Button("Borrar registro", role: .destructive) { Haptic.warning(); askDelete = true } }
                }
            }
            .navigationTitle(original == nil ? "Registrar un cambio" : "Editar cambio").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Guardar", action: save).bold().disabled(part.isEmpty && title.trimmingCharacters(in: .whitespaces).isEmpty) }
            }
            .confirmationDialog("¿Seguro que quieres borrar este registro?", isPresented: $askDelete, titleVisibility: .visible) {
                Button("Borrar", role: .destructive) { if let o = original { store.delete(o) }; Haptic.heavy(); dismiss() }
            }
            .overlay {
                if saved {
                    VStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 64, weight: .bold)).foregroundStyle(Color(hex: "#5fe0a0")).symbolEffect(.bounce, value: saved)
                        Text("Guardado").font(.headline)
                    }
                    .padding(30).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .onAppear {
                if let o = original {
                    part = o.part; title = o.title; date = Day.date(o.date); km = Money.int(o.km)
                    cost = o.cost > 0 ? Money.num(o.cost) : ""; place = o.where; note = o.note
                } else { km = Money.int(store.s.km) }
            }
        }
    }

    private func save() {
        let l = LogEntry(id: original?.id ?? UUID().uuidString, part: part, title: title.trimmingCharacters(in: .whitespaces), date: Day.str(date),
                         km: Int(km.filter(\.isNumber)) ?? store.s.km, cost: Money.parse(cost) ?? 0, where: place.trimmingCharacters(in: .whitespaces), note: note)
        store.save(l)
        Haptic.success()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { saved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { dismiss() }
    }
}

struct FaultsView: View {
    @Environment(Store.self) private var store
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(store.datos.AVERIAS.enumerated()), id: \.offset) { i, a in
                        FaultCard(a: a).appear(Double(i) * 0.04)
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Averías típicas")
        }
    }
}

struct FaultCard: View {
    @Environment(Store.self) private var store
    var a: Averia
    @State private var open = false
    var body: some View {
        let c = a.sev >= 3 ? PartStatus.bad.color : a.sev == 2 ? PartStatus.soon.color : PartStatus.unk.color
        VStack(alignment: .leading, spacing: 10) {
            Button { Haptic.select(); withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) { open.toggle() } } label: {
                HStack(spacing: 10) {
                    Circle().fill(c).frame(width: 10, height: 10)
                    Text(a.n).font(.headline).foregroundStyle(.primary).multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: "chevron.down").rotationEffect(.degrees(open ? 180 : 0)).foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            Text(a.sint).font(.subheadline).foregroundStyle(.secondary)
            if open {
                VStack(alignment: .leading, spacing: 8) {
                    row("Causa", a.causa)
                    row("Solución", a.sol)
                    row("Coste", a.coste)
                    ForEach(a.f, id: \.self) { k in
                        if let f = store.datos.FUENTES[k], let u = URL(string: f.u) { Link(f.n, destination: u).font(.caption) }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .card()
        .overlay(alignment: .leading) { Capsule().fill(c).frame(width: 4).padding(.vertical, 14) }
    }
    private func row(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(k).font(.caption.weight(.bold)).foregroundStyle(.secondary)
            Text(v).font(.subheadline)
        }
    }
}

struct MoreView: View {
    @Environment(Store.self) private var store
    @Binding var wizard: Bool
    @State private var importing = false
    @State private var importText = ""
    @State private var message: String? = nil
    @State private var askReset = false
    @State private var matric = false
    @State private var matricDate = Date()

    var body: some View {
        NavigationStack {
            List {
                Section("Consejos") {
                    ForEach(store.datos.CONSEJOS, id: \.t) { c in
                        DisclosureGroup {
                            Text(c.d).font(.subheadline).foregroundStyle(.secondary)
                        } label: { Text(c.t).font(.body.weight(.semibold)) }
                    }
                }
                Section("Ficha del coche") {
                    ForEach(store.datos.FICHA, id: \.self) { kv in
                        LabeledContent(kv.first ?? "", value: kv.count > 1 ? kv[1] : "")
                    }
                }
                Section("Fuentes consultadas") {
                    ForEach(store.datos.FUENTES.values.sorted { $0.n < $1.n }, id: \.u) { f in
                        if let u = URL(string: f.u) { Link(f.n, destination: u).font(.subheadline) }
                    }
                }
                Section {
                    Button { importing = true } label: { Label("Importar código o copia de la web", systemImage: "square.and.arrow.down") }
                    ShareLink(item: String(data: store.exportData(), encoding: .utf8) ?? "") { Label("Exportar copia de seguridad", systemImage: "square.and.arrow.up") }
                    Button { wizard = true } label: { Label("Volver a hacer el cuestionario inicial", systemImage: "list.number") }
                    Button { matricDate = Day.date(store.s.matric); matric = true } label: {
                        LabeledContent { Text(Day.monthYearLabel(store.s.matric)) } label: { Label("Matriculación", systemImage: "calendar") }
                    }
                    Button(role: .destructive) { askReset = true } label: { Label("Borrar todo", systemImage: "trash") }
                } header: { Text("Datos") }
            }
            .navigationTitle("Más")
            .alert("Importar", isPresented: $importing) {
                TextField("Pega aquí el código o la copia", text: $importText)
                Button("Importar") {
                    do { message = try store.importText(importText); Haptic.success() } catch { message = error.localizedDescription; Haptic.warning() }
                    importText = ""
                }
                Button("Cancelar", role: .cancel) { importText = "" }
            } message: { Text("Pega un código de facturas/km o la copia de seguridad de la versión web (Más → Copiar copia de seguridad).") }
            .alert("Importar", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("Vale") { message = nil } } message: { Text(message ?? "") }
            .confirmationDialog("¿Seguro que quieres borrar todos los datos?", isPresented: $askReset, titleVisibility: .visible) {
                Button("Borrar todo", role: .destructive) { withAnimation { store.s = CState() }; Haptic.heavy(); wizard = true }
            } message: { Text("Se borrarán los km, el historial y lo que contestaste en el cuestionario.") }
            .sheet(isPresented: $matric) {
                NavigationStack {
                    DatePicker("Fecha de matriculación", selection: $matricDate, in: ...Date(), displayedComponents: .date).datePickerStyle(.graphical).padding()
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Guardar") { store.s.matric = Day.str(matricDate); matric = false; Haptic.success() }.bold() } }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }
}
