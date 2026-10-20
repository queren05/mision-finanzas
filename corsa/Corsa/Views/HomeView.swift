import SwiftUI

extension PartStatus {
    var color: Color {
        switch self {
        case .bad: Color(hex: "#ff6b6b")
        case .soon: Color(hex: "#f0c46a")
        case .ok: Color(hex: "#5fe0a0")
        case .unk: Color(hex: "#7ac8ff")
        case .watch: .secondary
        }
    }
}

struct StatusPill: View {
    var st: PartStatus
    var body: some View {
        Text(st.label).font(.caption.weight(.bold))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .foregroundStyle(st == .watch ? Color.secondary : st.color)
            .background(st.color.opacity(0.16), in: Capsule())
    }
}

struct PartRow: View {
    var p: Pieza
    var i: PartInfo
    var body: some View {
        HStack(spacing: 12) {
            Text(p.ic).font(.system(size: 24)).frame(width: 44, height: 44).background(i.st.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(p.n).font(.body.weight(.semibold)).lineLimit(1)
                if !i.txt.isEmpty { Text(i.txt).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
                if i.st != .watch && i.st != .unk { ProgressBar(value: i.pct, color: i.st.color, height: 5) }
            }
            Spacer(minLength: 6)
            StatusPill(st: i.st)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

struct ProgressBar: View {
    var value: Double
    var color: Color
    var height: CGFloat = 8
    @State private var shown = 0.0
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule().fill(color.gradient).frame(width: max(height, g.size.width * min(1, max(0, shown))))
            }
        }
        .frame(height: height)
        .onAppear { withAnimation(.spring(response: 0.9, dampingFraction: 0.8).delay(0.1)) { shown = value } }
        .onChange(of: value) { _, v in withAnimation(.spring) { shown = v } }
    }
}

/// aparece desde abajo con un pequeño retraso
struct Appear: ViewModifier {
    var delay: Double
    @State private var on = false
    func body(content: Content) -> some View {
        content.opacity(on ? 1 : 0).offset(y: on ? 0 : 20)
            .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.82).delay(delay)) { on = true } }
    }
}
extension View { func appear(_ d: Double = 0) -> some View { modifier(Appear(delay: d)) } }

struct HomeView: View {
    @Environment(Store.self) private var store
    @Binding var tab: CTab
    @State private var kmSheet = false
    @State private var newLog = false
    @State private var open: Pieza? = nil
    @State private var itvSheet = false
    @State private var ring = 0.0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    hero.appear(0)
                    healthCard.appear(0.06)
                    stats.appear(0.1)
                    if let itv = store.nextItv() { itvCard(itv).appear(0.14) }
                    next.appear(0.18)
                    Button { Haptic.tap(); newLog = true } label: {
                        Label("Registrar un cambio", systemImage: "plus").font(.headline).frame(maxWidth: .infinity).frame(height: 54)
                            .foregroundStyle(.black).background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(PressableStyle())
                    Color.clear.frame(height: 20)
                }
                .padding(.horizontal, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Mi Corsa")
            .sheet(isPresented: $kmSheet) { KmSheet() }
            .sheet(isPresented: $newLog) { LogEditor(original: nil, part: "") }
            .sheet(item: $open) { PartDetail(p: $0) }
            .sheet(isPresented: $itvSheet) { ItvSheet() }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Opel Corsa E").font(.title3.weight(.bold))
                    Text("1.4 GLP · 90 CV · Selective Pro").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Text("GLP").font(.caption.weight(.heavy)).padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color(hex: "#5fe0a0").opacity(0.2), in: Capsule()).foregroundStyle(Color(hex: "#5fe0a0"))
            }
            if let img = UIImage(named: "corsa") ?? Bundle.main.path(forResource: "corsa", ofType: "png").flatMap(UIImage.init(contentsOfFile:)) {
                Image(uiImage: img).resizable().scaledToFit().frame(maxWidth: .infinity).padding(.vertical, -6)
                    .shadow(color: Color.accentColor.opacity(0.25), radius: 24, y: 10)
            }
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(Money.int(store.s.km)).font(.system(size: 40, weight: .bold, design: .rounded)).monospacedDigit()
                            .contentTransition(.numericText(value: Double(store.s.km)))
                        Text("km").font(.headline).foregroundStyle(.secondary)
                    }
                    Text([store.kmPerMonth.map { "≈ \(Money.km($0))/mes" }, "actualizado " + (store.s.kmLog.last.map { Day.header($0.d).lowercased() } ?? "nunca")].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { Haptic.tap(); kmSheet = true } label: {
                    Text("Actualizar km").font(.subheadline.weight(.bold)).foregroundStyle(.black)
                        .padding(.horizontal, 14).padding(.vertical, 10).background(Color.accentColor, in: Capsule())
                }
                .buttonStyle(PressableStyle())
            }
            if let last = store.s.kmLog.last, Store.daysTo(last.d) < -30 {
                Label("Hace más de un mes que no actualizas los km", systemImage: "exclamationmark.circle.fill").font(.caption.weight(.semibold)).foregroundStyle(Color(hex: "#f0c46a"))
            }
        }
        .card(18)
    }

    private var healthCard: some View {
        let pc = store.health
        let col = pc > 0.7 ? Color(hex: "#5fe0a0") : pc > 0.4 ? Color(hex: "#f0c46a") : Color(hex: "#ff6b6b")
        let bad = store.sorted.filter { $0.i.st == .bad }.count
        return HStack(spacing: 16) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.08), lineWidth: 9)
                Circle().trim(from: 0, to: ring).stroke(col.gradient, style: StrokeStyle(lineWidth: 9, lineCap: .round)).rotationEffect(.degrees(-90))
                Text("\(Int((pc * 100).rounded()))%").font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(col)
            }
            .frame(width: 72, height: 72)
            VStack(alignment: .leading, spacing: 4) {
                Text("del mantenimiento al día").font(.headline)
                Text(bad > 0 ? "\(bad) cosa\(bad == 1 ? "" : "s") por hacer ya" : "Nada vencido ✓").font(.subheadline).foregroundStyle(bad > 0 ? Color(hex: "#ff6b6b") : .secondary)
            }
            Spacer()
        }
        .card()
        .onAppear { withAnimation(.spring(response: 1.2, dampingFraction: 0.8).delay(0.2)) { ring = pc } }
        .onChange(of: pc) { _, v in withAnimation(.spring) { ring = v } }
    }

    private var stats: some View {
        let all = store.sorted
        let bad = all.filter { $0.i.st == .bad }.count, soon = all.filter { $0.i.st == .soon || $0.i.st == .unk }.count, ok = all.filter { $0.i.st == .ok }.count
        return HStack(spacing: 10) {
            stat(bad, "Toca ya", PartStatus.bad.color)
            stat(soon, "Pronto", PartStatus.soon.color)
            stat(ok, "Al día", PartStatus.ok.color)
        }
    }
    private func stat(_ n: Int, _ l: String, _ c: Color) -> some View {
        Button { Haptic.select(); tab = .parts } label: {
            VStack(spacing: 2) {
                Text("\(n)").font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(c).contentTransition(.numericText())
                Text(l).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(c.opacity(0.1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }

    private func itvCard(_ itv: String) -> some View {
        let days = Store.daysTo(itv)
        return Button { itvSheet = true } label: {
            HStack(spacing: 12) {
                Text("📋").font(.title2).frame(width: 44, height: 44).background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Próxima ITV").font(.body.weight(.semibold)).foregroundStyle(.primary)
                    Text("\(Day.monthYearLabel(itv)) · \(days < 0 ? "pasada: compruébala" : "en \(days) días")").font(.subheadline).foregroundStyle(days < 30 ? Color(hex: "#f0c46a") : .secondary)
                }
                Spacer()
                Image(systemName: "pencil").foregroundStyle(.secondary)
            }
            .card(14)
        }
        .buttonStyle(PressableStyle(scale: 0.98))
    }

    private var next: some View {
        let list = store.sorted.filter { $0.i.st != .watch }.prefix(6)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Lo próximo").font(.title3.weight(.bold))
                Spacer()
                Text("ordenado por urgencia").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(Array(list), id: \.p.id) { x in
                Button { open = x.p } label: { PartRow(p: x.p, i: x.i) }.buttonStyle(.plain)
                if x.p.id != list.last?.p.id { Divider().padding(.leading, 56) }
            }
        }
        .card()
    }
}

/// actualizar los km del cuadro
struct KmSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var askLower = false
    @FocusState private var focused: Bool
    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Text("🚗").font(.system(size: 54))
                Text("¿Cuántos kilómetros tiene ahora?").font(.title3.weight(.bold))
                Text("Míralos en el cuadro. Con cada actualización la app calcula cuántos haces al mes.").font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                TextField("0", text: $text).keyboardType(.numberPad).focused($focused)
                    .font(.system(size: 44, weight: .bold, design: .rounded)).multilineTextAlignment(.center).monospacedDigit()
                    .onChange(of: text) { _, v in let d = v.filter(\.isNumber); let f = Int(d).map(Money.int) ?? ""; if f != v { text = f } }
                Spacer()
            }
            .padding(24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Guardar", action: save).bold() }
            }
            .confirmationDialog("Es menos de lo que tenías. ¿Guardar igualmente?", isPresented: $askLower, titleVisibility: .visible) {
                Button("Guardar igualmente") { commit() }
                Button("Cancelar", role: .cancel) {}
            }
            .onAppear { text = Money.int(store.s.km); DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focused = true } }
        }
        .presentationDetents([.medium, .large])
    }
    private var value: Int { Int(text.filter(\.isNumber)) ?? 0 }
    private func save() { guard value > 0 else { return }; if value < store.s.km { askLower = true } else { commit() } }
    private func commit() { store.setKm(value); Haptic.success(); dismiss() }
}

struct ItvSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var known = false
    @State private var date = Date()
    var body: some View {
        NavigationStack {
            Form {
                Toggle("Sé cuándo pasé la última ITV", isOn: $known.animation())
                if known { DatePicker("Última ITV pasada", selection: $date, in: ...Date(), displayedComponents: .date) }
                if let n = store.nextItv() { LabeledContent("Próxima ITV", value: Day.monthYearLabel(n)) }
            }
            .navigationTitle("ITV").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { store.s.itv = known ? Day.str(date) : ""; Haptic.success(); dismiss() }.bold()
                }
            }
            .onAppear { if !store.s.itv.isEmpty { known = true; date = Day.date(store.s.itv) } }
        }
        .presentationDetents([.medium])
    }
}
