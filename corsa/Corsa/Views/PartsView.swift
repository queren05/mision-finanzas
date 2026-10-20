import SwiftUI

struct PartsView: View {
    @Environment(Store.self) private var store
    @State private var filter = "todas"
    @State private var open: Pieza? = nil
    @State private var confirm: Pieza? = nil
    @State private var askChanged = false
    @Namespace private var ns

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            chip("todas", "Todas")
                            ForEach(Datos.catOrder, id: \.self) { k in chip(k, store.datos.CATS[k] ?? k) }
                        }
                        .padding(.horizontal, 4)
                    }
                    .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                }
                Section {
                    let list = store.sorted.filter { filter == "todas" || $0.p.cat == filter }
                    ForEach(list, id: \.p.id) { x in
                        Button { open = x.p } label: { PartRow(p: x.p, i: x.i) }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                if x.p.use != nil {
                                    Button { Haptic.tap(); confirm = x.p; askChanged = true } label: { Label("Cambiado hoy", systemImage: "checkmark.circle.fill") }.tint(.green)
                                }
                            }
                    }
                    if list.isEmpty { Text("Nada en esta categoría.").foregroundStyle(.secondary) }
                }
            }
            .navigationTitle("Piezas")
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: filter)
            .sheet(item: $open) { PartDetail(p: $0) }
            .confirmationDialog("¿Has cambiado hoy «\(confirm?.n ?? "")»?", isPresented: $askChanged, titleVisibility: .visible, presenting: confirm) { p in
                Button("Sí, apuntar el cambio a \(Money.km(store.s.km))") { Haptic.success(); store.changedToday(p) }
                Button("Cancelar", role: .cancel) {}
            } message: { _ in Text("Se registrará con fecha de hoy y los kilómetros actuales. Luego puedes editarlo en el Historial.") }
        }
    }

    private func chip(_ k: String, _ label: String) -> some View {
        Button { Haptic.select(); withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { filter = k } } label: {
            Text(label).font(.subheadline.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 8)
                .foregroundStyle(filter == k ? Color.black : Color.primary)
                .background {
                    if filter == k { Capsule().fill(Color.accentColor).matchedGeometryEffect(id: "chip", in: ns) }
                    else { Capsule().fill(Color.white.opacity(0.07)) }
                }
        }
        .buttonStyle(.plain)
    }
}

struct PartDetail: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    var p: Pieza
    @State private var newLog = false
    @State private var editLast = false

    var body: some View {
        let i = store.status(p)
        let d = store.s.parts[p.id] ?? PartState()
        let logs = store.s.logs.filter { $0.part == p.id }.sorted { $0.date > $1.date }
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 14) {
                        Text(p.ic).font(.system(size: 40)).frame(width: 64, height: 64).background(i.st.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        VStack(alignment: .leading, spacing: 6) {
                            Text(p.n).font(.title3.weight(.bold))
                            HStack { StatusPill(st: i.st); Text(i.txt).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                    if i.st != .watch && i.st != .unk { ProgressBar(value: i.pct, color: i.st.color, height: 10) }
                    HStack(spacing: 8) {
                        ivl("Opel", p.opel, false)
                        ivl("Foros y talleres", p.rec, false)
                        ivl("La app avisa a", p.use, true)
                    }
                    block("Por qué", p.why)
                    block("Qué lleva", p.spec)
                    if !p.sint.isEmpty { list("Síntomas de que toca", p.sint, "exclamationmark.circle.fill", PartStatus.soon.color) }
                    if !p.tips.isEmpty { list("Consejos", p.tips, "lightbulb.fill", Color.accentColor) }
                    VStack(spacing: 10) {
                        kv("Precio", p.precio)
                        kv("Hacerlo tú", ["", "Fácil", "Con herramientas", "Mejor en taller"][max(0, min(3, p.dif))])
                        kv("Desguace", ["si": "✅ Se puede comprar en desguace", "no": "⛔ Mejor nueva", "cuidado": "⚠️ Solo si viene probada y con garantía"][p.des] ?? "—")
                        kv("Último cambio", lastText(d))
                    }
                    .card(14)
                    if !p.f.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Fuentes").font(.subheadline.weight(.bold))
                            ForEach(p.f, id: \.self) { k in
                                if let f = store.datos.FUENTES[k], let u = URL(string: f.u) { Link(f.n, destination: u).font(.caption) }
                            }
                        }
                    }
                    if !logs.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Historial").font(.subheadline.weight(.bold))
                            ForEach(logs) { l in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("\(Day.shortLabel(l.date)) · \(Money.km(l.km))").font(.subheadline.weight(.semibold))
                                        let extra = [l.where, l.note].filter { !$0.isEmpty }.joined(separator: " · ")
                                        if !extra.isEmpty { Text(extra).font(.caption).foregroundStyle(.secondary) }
                                    }
                                    Spacer()
                                    if l.cost > 0 { Text(Money.eur(l.cost)).font(.subheadline).monospacedDigit() }
                                }
                            }
                        }
                        .card(14)
                    }
                    if p.use != nil {
                        Button { Haptic.tap(); newLog = true } label: {
                            Label("Lo he cambiado", systemImage: "checkmark").font(.headline).frame(maxWidth: .infinity).frame(height: 52)
                                .foregroundStyle(.black).background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(PressableStyle())
                        Button { editLast = true } label: { Text("Corregir último cambio").frame(maxWidth: .infinity).frame(height: 44) }
                            .buttonStyle(.bordered)
                    }
                }
                .padding(18)
            }
            .background(Color(.systemGroupedBackground))
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Cerrar") { dismiss() } } }
            .sheet(isPresented: $newLog) { LogEditor(original: nil, part: p.id) }
            .sheet(isPresented: $editLast) { LastEditor(p: p) }
        }
        .presentationDragIndicator(.visible)
    }

    private func ivl(_ t: String, _ v: Ivl?, _ hl: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(t).font(.caption2.weight(.semibold)).foregroundStyle(hl ? Color.black.opacity(0.7) : .secondary)
            Text(v?.text ?? "No indicado").font(.caption.weight(.bold)).foregroundStyle(hl ? Color.black : .primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(10)
        .background(hl ? Color.accentColor : Color.cardBG, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    private func lastText(_ d: PartState) -> String {
        if d.never == true { return "Nunca (de fábrica)" }
        if d.unknown == true { return "No se sabe" }
        let parts = [d.km.map { Money.km($0) }, d.date.map { Day.shortLabel($0) }].compactMap { $0 }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }
    private func block(_ t: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t).font(.subheadline.weight(.bold))
            Text(v).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
    private func list(_ t: String, _ items: [String], _ icon: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t).font(.subheadline.weight(.bold))
            ForEach(items, id: \.self) { x in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: icon).font(.caption).foregroundStyle(c)
                    Text(x).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
    private func kv(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top) {
            Text(k).font(.subheadline).foregroundStyle(.secondary).frame(width: 110, alignment: .leading)
            Text(v).font(.subheadline.weight(.medium)).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// corregir el último cambio de una pieza (km y mes, o no se sabe / nunca)
struct LastEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    var p: Pieza
    @State private var mode = 0   // 0 dato, 1 no se sabe, 2 nunca
    @State private var km = ""
    @State private var hasDate = false
    @State private var date = Date()
    var body: some View {
        NavigationStack {
            Form {
                Picker("", selection: $mode.animation()) { Text("Lo sé").tag(0); Text("No lo sé").tag(1); Text("Nunca").tag(2) }.pickerStyle(.segmented)
                if mode == 0 {
                    if p.use?.km != nil { LabeledContent("Kilómetros") { TextField("Ej.: 150.000", text: $km).keyboardType(.numberPad).multilineTextAlignment(.trailing) } }
                    Toggle("Con fecha", isOn: $hasDate.animation())
                    if hasDate { DatePicker("Fecha (aprox.)", selection: $date, in: ...Date(), displayedComponents: .date) }
                }
            }
            .navigationTitle("\(p.ic) Último cambio").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        switch mode {
                        case 1: store.s.parts[p.id] = PartState(unknown: true)
                        case 2: store.s.parts[p.id] = PartState(never: true)
                        default: store.s.parts[p.id] = PartState(km: Int(km.filter(\.isNumber)), date: hasDate ? Day.str(date) : nil)
                        }
                        Haptic.success(); dismiss()
                    }.bold()
                }
            }
            .onAppear {
                let d = store.s.parts[p.id] ?? PartState()
                mode = d.unknown == true ? 1 : d.never == true ? 2 : 0
                km = d.km.map(Money.int) ?? ""
                if let dd = d.date, !dd.isEmpty { hasDate = true; date = Day.date(dd) }
            }
        }
        .presentationDetents([.medium])
    }
}
