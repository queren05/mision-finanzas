import SwiftUI

/// cuestionario inicial: km actuales y cuándo se cambió por última vez cada cosa
struct WizardView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var step = 0
    @State private var km = ""
    @State private var matric = Date()
    @State private var partKm = ""
    @State private var partDate = Date()
    @State private var hasDate = false
    @State private var choice = 0       // 0 dato, 1 no lo sé, 2 nunca
    @State private var forward = true
    @FocusState private var focused: Bool

    private var ask: [Pieza] { store.datos.PIEZAS.filter { $0.use != nil } }
    private var total: Int { ask.count + 2 }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                if step > 0 {
                    Button { go(-1) } label: { Image(systemName: "chevron.left").font(.headline).frame(width: 36, height: 36).background(.ultraThinMaterial, in: Circle()) }
                }
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.1))
                        Capsule().fill(Color.accentColor.gradient).frame(width: g.size.width * CGFloat(step) / CGFloat(total))
                    }
                }
                .frame(height: 6)
                Button("Saltar") { finish() }.font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 20).padding(.top, 12)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: step)

            ScrollView {
                page
                    .id(step)
                    .transition(.asymmetric(insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                                            removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)))
                    .padding(24)
            }
            .scrollDismissesKeyboard(.interactively)

            Button { go(1) } label: {
                Text(step == 0 ? "Empezar" : step >= total ? "Ver mi coche" : "Siguiente")
                    .font(.headline).frame(maxWidth: .infinity).frame(height: 56)
                    .foregroundStyle(.black).background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(PressableStyle())
            .padding(.horizontal, 20).padding(.bottom, 12)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear { km = Money.int(store.s.km); matric = Day.date(store.s.matric) }
    }

    @ViewBuilder private var page: some View {
        if step == 0 {
            VStack(spacing: 18) {
                if let img = UIImage(named: "corsa") { Image(uiImage: img).resizable().scaledToFit().shadow(color: Color.accentColor.opacity(0.3), radius: 30, y: 10) }
                Text("Pongamos al día tu Corsa").font(.largeTitle.weight(.bold)).multilineTextAlignment(.center)
                Text("Te voy a preguntar a cuántos kilómetros se cambió por última vez cada cosa del mantenimiento. Si no lo sabes, dilo y la app te recomendará revisarlo.")
                    .multilineTextAlignment(.center).foregroundStyle(.secondary)
            }
        } else if step == 1 {
            VStack(spacing: 18) {
                Text("🚗").font(.system(size: 64))
                Text("¿Cuántos kilómetros tiene ahora?").font(.title.weight(.bold)).multilineTextAlignment(.center)
                Text("Míralos en el cuadro.").foregroundStyle(.secondary)
                TextField("0", text: $km).keyboardType(.numberPad).focused($focused)
                    .font(.system(size: 44, weight: .bold, design: .rounded)).multilineTextAlignment(.center).monospacedDigit()
                    .padding(14).background(Color.cardBG, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .onChange(of: km) { _, v in let f = Int(v.filter(\.isNumber)).map(Money.int) ?? ""; if f != v { km = f } }
                DatePicker("Mes de matriculación", selection: $matric, in: ...Date(), displayedComponents: .date)
                    .padding(14).background(Color.cardBG, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        } else if step < total {
            let p = ask[step - 2]
            let byKm = p.use?.km != nil
            VStack(spacing: 16) {
                Text(p.ic).font(.system(size: 64))
                Text("\(store.datos.CATS[p.cat] ?? "") · \(step - 1) de \(ask.count)").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(p.n).font(.title.weight(.bold)).multilineTextAlignment(.center)
                Text(byKm ? "¿A cuántos kilómetros se cambió por última vez?" : "¿Cuándo se cambió por última vez?").foregroundStyle(.secondary).multilineTextAlignment(.center)
                Picker("", selection: $choice.animation(.spring)) { Text("Lo sé").tag(0); Text("No lo sé").tag(1); Text("Nunca").tag(2) }.pickerStyle(.segmented)
                if choice == 0 {
                    if byKm {
                        TextField("Ej.: 150.000", text: $partKm).keyboardType(.numberPad)
                            .font(.system(size: 34, weight: .bold, design: .rounded)).multilineTextAlignment(.center).monospacedDigit()
                            .padding(12).background(Color.cardBG, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .onChange(of: partKm) { _, v in let f = Int(v.filter(\.isNumber)).map(Money.int) ?? ""; if f != v { partKm = f } }
                        Toggle("Sé la fecha aproximada", isOn: $hasDate.animation())
                            .padding(14).background(Color.cardBG, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    if !byKm || hasDate {
                        DatePicker(byKm ? "Fecha aproximada" : "Mes y año", selection: $partDate, in: ...Date(), displayedComponents: .date)
                            .padding(14).background(Color.cardBG, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
                Text("Recomendado: " + [p.use?.km.map { "cada " + Money.km($0) }, p.use?.y.map { "cada \(Int($0)) año\(Int($0) == 1 ? "" : "s")" }].compactMap { $0 }.joined(separator: " o ") + ".")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        } else {
            let c = store.sorted
            let bad = c.filter { $0.i.st == .bad }.count, unk = c.filter { $0.i.st == .unk }.count
            VStack(spacing: 18) {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 80)).foregroundStyle(Color(hex: "#5fe0a0")).symbolEffect(.bounce, value: step)
                Text("¡Listo!").font(.largeTitle.weight(.bold))
                Text(bad > 0 ? "Hay \(bad) cosa\(bad == 1 ? "" : "s") que ya tocan\(unk > 0 ? " y \(unk) sin datos que conviene revisar" : "")." : "No hay nada vencido\(unk > 0 ? ", pero hay \(unk) sin datos que conviene revisar" : "").")
                    .multilineTextAlignment(.center)
                Text("Lo verás ordenado por urgencia en Inicio. Actualiza los kilómetros de vez en cuando y registra cada cambio para que los avisos sean exactos.")
                    .multilineTextAlignment(.center).foregroundStyle(.secondary)
            }
        }
    }

    private func storeStep() {
        if step == 1 {
            if let k = Int(km.filter(\.isNumber)), k > 0 { store.setKm(k) }
            store.s.matric = Day.str(matric)
        } else if step >= 2 && step < total {
            let p = ask[step - 2]
            switch choice {
            case 1: store.s.parts[p.id] = PartState(unknown: true)
            case 2: store.s.parts[p.id] = PartState(never: true)
            default:
                let k = Int(partKm.filter(\.isNumber))
                let d: String? = (p.use?.km == nil || hasDate) ? Day.str(partDate) : nil
                if k != nil || d != nil { store.s.parts[p.id] = PartState(km: k, date: d) }
            }
        }
    }

    private func load() {
        guard step >= 2 && step < total else { return }
        let d = store.s.parts[ask[step - 2].id] ?? PartState()
        choice = d.unknown == true ? 1 : d.never == true ? 2 : 0
        partKm = d.km.map(Money.int) ?? ""
        hasDate = !(d.date ?? "").isEmpty
        partDate = (d.date ?? "").isEmpty ? Date() : Day.date(d.date!)
    }

    private func go(_ dir: Int) {
        Haptic.tap()
        if dir > 0 { storeStep() }
        if dir > 0 && step >= total { finish(); return }
        forward = dir > 0
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { step = max(0, step + dir) }
        load()
    }

    private func finish() {
        store.s.done = true
        Haptic.success()
        dismiss()
    }
}
