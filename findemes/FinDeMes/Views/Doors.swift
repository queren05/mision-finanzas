import SwiftUI

// MARK: - Una puerta de la cocina (se abre con el sello «NUEVO» la primera vez)

struct DoorCard: View {
    @Environment(Game.self) private var game
    let door: Door
    let subtitle: String
    var badge = false
    let action: () -> Void

    var body: some View {
        let new = game.isNew(door)
        Button {
            Sound.shared.click()
            game.open(door)
            action()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: door.icon).font(.system(size: 22, weight: .black)).foregroundStyle(door.color)
                    Spacer()
                    if badge && !new {
                        Text("¡!").font(.chunky(15)).foregroundStyle(Ink.paper).padding(.horizontal, 7)
                            .background(Ink.red, in: Capsule()).overlay(Capsule().strokeBorder(Ink.ink, lineWidth: 2))
                    }
                }
                Text(door.title).font(.chunky(22)).foregroundStyle(Ink.ink).lineLimit(1).minimumScaleFactor(0.7)
                Text(subtitle.a).font(.typewriter(12, bold: true)).foregroundStyle(Ink.soft).lineLimit(1).minimumScaleFactor(0.7)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(ChunkyButton(color: Ink.paper, size: 18, radius: 16))
        .overlay(alignment: .topTrailing) {
            if new { Stamp(text: "NUEVO", color: Ink.red).scaleEffect(0.8).offset(x: 8, y: -10) }
        }
        .transition(.scale(scale: 0.4).combined(with: .opacity))
    }
}

// MARK: - Varias pantallas detrás de una puerta, con pestañas abajo

struct DoorTab: Identifiable {
    let id: String
    let name: String
    let icon: String
    var badge = false
    let content: AnyView
}

struct TabbedDoor: View {
    let tabs: [DoorTab]
    @State private var picked = ""

    var body: some View {
        let current = tabs.first { $0.id == picked } ?? tabs[0]
        current.content
            .id(current.id)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if tabs.count > 1 { bar(current.id) }
            }
    }

    private func bar(_ on: String) -> some View {
        HStack(spacing: 6) {
            ForEach(tabs) { t in
                let sel = t.id == on
                Button {
                    Sound.shared.click()
                    picked = t.id
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: t.icon).font(.system(size: 16, weight: .black))
                        Text(t.name).font(.chunky(13)).lineLimit(1).minimumScaleFactor(0.6)
                    }
                    .foregroundStyle(sel ? Ink.paper : Ink.ink)
                    .frame(maxWidth: .infinity).padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 12).fill(sel ? Ink.ink : Ink.paper))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Ink.ink, lineWidth: 2.5))
                    .overlay(alignment: .topTrailing) {
                        if t.badge && !sel { Circle().fill(Ink.red).frame(width: 12, height: 12).overlay(Circle().strokeBorder(Ink.ink, lineWidth: 2)).offset(x: 3, y: -3) }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 4)
        .background(Ink.woodDark.overlay(Rectangle().fill(Ink.ink).frame(height: 3), alignment: .top).ignoresSafeArea())
    }
}

/// las tres puertas con pestañas
struct HammerDoor: View {
    @Environment(Game.self) private var game
    var body: some View {
        var tabs = [DoorTab(id: "martillos", name: "Martillos", icon: "hammer.fill", badge: game.bestHammer != nil, content: AnyView(HammersView()))]
        if game.s.stats.billsPaid >= 3 || game.s.stats.bankruptcies > 0 {
            tabs.append(DoorTab(id: "taller", name: "Taller", icon: "wrench.and.screwdriver.fill", badge: game.bestPart != nil, content: AnyView(WorkshopView())))
        }
        return TabbedDoor(tabs: tabs)
    }
}

struct LegacyDoor: View {
    @Environment(Game.self) private var game
    var body: some View {
        TabbedDoor(tabs: [
            DoorTab(id: "familia", name: "Familia", icon: "tree.fill", badge: Content.family.contains { game.canBuyFamily($0) }, content: AnyView(TreeView(family: true))),
            DoorTab(id: "joyas", name: "Joyas", icon: "sparkles", badge: Content.rings.contains { game.ringLevel($0) < $0.maxLevel && game.s.legacy >= $0.cost(game.ringLevel($0)) }, content: AnyView(JewelryView())),
            DoorTab(id: "totems", name: "Tótems", icon: "pawprint.fill", badge: Content.totems.contains { game.totemLevel($0) < TotemDef.maxLevel && game.s.legacy >= $0.cost(game.totemLevel($0)) }, content: AnyView(TotemsView())),
            DoorTab(id: "mascotas", name: "Mascotas", icon: "pawprint.circle.fill", badge: Content.pets.contains { game.petLevel($0) < PetDef.maxLevel && game.s.legacy >= $0.cost(game.petLevel($0)) }, content: AnyView(PetsView())),
        ])
    }
}

struct AlbumDoor: View {
    @Environment(Game.self) private var game
    var body: some View {
        var tabs = [DoorTab(id: "establo", name: "Establo", icon: "house.fill", content: AnyView(BestiaryView()))]
        if game.unlocked(.logros) { tabs.append(DoorTab(id: "logros", name: "Logros", icon: "rosette", badge: game.achievementsReady > 0, content: AnyView(AchievementsView()))) }
        if game.unlocked(.monedas) { tabs.append(DoorTab(id: "monedas", name: "Monedas", icon: "circle.circle.fill", content: AnyView(CoinsView()))) }
        return TabbedDoor(tabs: tabs)
    }
}

// MARK: - La hipoteca pegada en la nevera

struct MortgageCard: View {
    @Environment(Game.self) private var game
    @State private var ask = false

    var body: some View {
        let share = game.mortgageShare
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(game.mortgageName.uppercased()).font(.typewriter(15, bold: true))
                Spacer()
                Text(Mortgage.words(game.mortgageTotal)).font(.chunky(18))
            }
            // barra de lo pagado, como una regla de papel
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Ink.paperDark)
                    Rectangle().fill(Ink.green).frame(width: max(share > 0 ? 3 : 0, g.size.width * share))
                    HStack(spacing: 0) {
                        ForEach(0..<10, id: \.self) { _ in Rectangle().fill(.clear).overlay(alignment: .trailing) { Rectangle().fill(Ink.ink.opacity(0.25)).frame(width: 1) } }
                    }
                }
                .overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 2))
            }
            .frame(height: 14)
            HStack {
                Text("Pagado: \(Fmt.money(game.s.mortgage)) · \(percent(share))").font(.typewriter(12, bold: true)).foregroundStyle(Ink.soft)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Spacer(minLength: 6)
                Button { ask = true } label: { Text("Abonar") }
                    .buttonStyle(ChunkyButton(color: Ink.paper, size: 14, radius: 10))
                    .disabled(game.s.cash < 1)
            }
        }
        .foregroundStyle(Ink.ink)
        .padding(14)
        .paper(Color(hex: "#fff6e0"), tilt: 1.2)
        .confirmationDialog("Abonar a \(game.mortgageName.lowercased())", isPresented: $ask, titleVisibility: .visible) {
            Button("La mitad (\(Fmt.money((game.s.cash / 2).rounded(.down))))") { game.payMortgage((game.s.cash / 2).rounded(.down)) }
            Button("Todo (\(Fmt.money(game.s.cash)))") { game.payMortgage(game.s.cash) }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private func percent(_ v: Double) -> String {
        if v <= 0 { return "0 %" }
        if v >= 0.01 { return Fmt.dec(v * 100, 1) + " %" }
        // muy poquito: con los decimales que hagan falta para que se vea moverse
        let digits = min(12, Int(-floor(log10(v * 100))) + 1)
        return Fmt.dec(v * 100, digits) + " %"
    }
}

// MARK: - El final: hipoteca pagada

struct FinaleView: View {
    @Environment(Game.self) private var game
    let level: Int
    @State private var pop = false

    var body: some View {
        let st = game.s.stats
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 14) {
                Stamp(text: "PAGADA", color: Ink.green).scaleEffect(pop ? 2.2 : 6).opacity(pop ? 1 : 0)
                    .padding(.vertical, 18)
                Text(Mortgage.name(level)).font(.chunky(32)).foregroundStyle(Ink.ink).multilineTextAlignment(.center)
                Text(level == 0 ? "La casa es tuya." : "También es tuyo.").font(.typewriter(16, bold: true))
                VStack(spacing: 4) {
                    line("Días", Fmt.num(st.days))
                    line("{Huchas} rot{as}".a, Fmt.num(st.broken))
                    line("Facturas pagadas", Fmt.num(st.billsPaid))
                    line("Bancarrotas", Fmt.num(st.bankruptcies))
                    line("Dinero ganado", Fmt.money(st.earned))
                }
                .padding(12)
                .background(Ink.paperDark.opacity(0.5))
                VStack(spacing: 2) {
                    Text("RICO DE PUEBLO \(level + 1)").font(.chunky(22)).foregroundStyle(Ink.gold).shadow(color: Ink.ink, radius: 0, x: 2, y: 2)
                    Text("Todo da ×\(level + 2) de dinero para siempre").font(.typewriter(13, bold: true))
                    Text("Siguiente: \(Mortgage.name(level + 1))").font(.typewriter(13)).foregroundStyle(Ink.soft)
                }
                Button { close() } label: { Text("¡A seguir rompiendo!").frame(maxWidth: .infinity) }
                    .buttonStyle(ChunkyButton(color: Ink.gold, size: 20))
            }
            .foregroundStyle(Ink.ink)
            .padding(22)
            .paper(tilt: -0.8)
            .padding(24)
        }
        .onAppear {
            Sound.shared.fanfare()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.5).delay(0.2)) { pop = true }
        }
    }

    private func line(_ k: String, _ v: String) -> some View {
        HStack { Text(k).font(.typewriter(13)); Spacer(); Text(v).font(.typewriter(13, bold: true)) }
    }
    private func close() {
        Sound.shared.click()
        withAnimation { game.finale = nil }
    }
}

// MARK: - Mientras no estabas

struct AwayView: View {
    @Environment(Game.self) private var game
    let prize: AwayPrize
    @State private var pop = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("MIENTRAS NO ESTABAS").font(.typewriter(15, bold: true))
                Text(time(prize.minutes)).font(.typewriter(13)).foregroundStyle(Ink.soft)
                SkinIcon(id: Content.playing(game.s.skin).id, size: 70)
                Text("\(Fmt.num(prize.cows)) {huchas} rot{as}".a).font(.chunky(22))
                Text("+" + Fmt.money(prize.cash)).font(.chunky(40)).foregroundStyle(Ink.green)
                    .shadow(color: Ink.ink, radius: 0, x: 2, y: 3)
                    .scaleEffect(pop ? 1 : 0.4)
                Button { game.collectAway() } label: { Text("Cobrar").frame(maxWidth: .infinity) }
                    .buttonStyle(ChunkyButton(color: Ink.gold, size: 20))
            }
            .foregroundStyle(Ink.ink)
            .padding(22)
            .paper(tilt: -0.6)
            .padding(30)
        }
        .onAppear { withAnimation(.spring(response: 0.4, dampingFraction: 0.45)) { pop = true } }
    }

    private func time(_ m: Double) -> String {
        if m < 60 { return "\(Int(m)) minutos" }
        let h = Int(m / 60), r = Int(m) % 60
        return r == 0 || h >= 4 ? "\(h) hora\(h == 1 ? "" : "s")" : "\(h) h y \(r) min"
    }
}

// MARK: - Números grandes: el primer millón, los primeros mil millones…

struct MilestoneView: View {
    @Environment(Game.self) private var game
    let k: Int
    @State private var pop = false

    var body: some View {
        let name = k < Game.milestoneNames.count ? Game.milestoneNames[k] : "1e\(k * 3) €"
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea().onTapGesture { close() }
            VStack(spacing: 6) {
                Text(name.hasPrefix("MIL ") ? "TUS PRIMEROS" : "TU PRIMER")
                    .font(.typewriter(16, bold: true))
                Text(name).font(.chunky(k >= 3 ? 40 : 54)).foregroundStyle(Ink.gold)
                    .multilineTextAlignment(.center)
                    .shadow(color: Ink.ink, radius: 0, x: 3, y: 4)
                    .scaleEffect(pop ? 1 : 0.2)
                    .rotationEffect(.degrees(pop ? -4 : 20))
                Text(Fmt.money(pow(1000, Double(k)))).font(.typewriter(14, bold: true)).foregroundStyle(Ink.soft)
                Button { close() } label: { Text("¡Más!").frame(maxWidth: .infinity) }
                    .buttonStyle(ChunkyButton(color: Ink.gold, size: 20))
                    .padding(.top, 8)
            }
            .foregroundStyle(Ink.ink)
            .padding(22)
            .paper(tilt: 0.8)
            .padding(36)
        }
        .onAppear { withAnimation(.spring(response: 0.45, dampingFraction: 0.4)) { pop = true } }
    }

    private func close() {
        Sound.shared.click()
        withAnimation { game.milestoneShow = nil }
    }
}

// MARK: - La chincheta dorada: lo que más conviene comprar ahora

/// destello que late detrás de la chincheta dorada
struct GoldGlow: View {
    @State private var on = false
    var body: some View {
        Circle().strokeBorder(Ink.gold, lineWidth: 3)
            .frame(width: 34, height: 34)
            .scaleEffect(on ? 1.35 : 0.8)
            .opacity(on ? 0 : 0.9)
            .onAppear { withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false)) { on = true } }
    }
}

/// chincheta dorada para filas (martillos, taller)
struct GoldPin: View {
    var body: some View {
        Circle().fill(Ink.gold)
            .frame(width: 20, height: 20)
            .overlay(Circle().fill(.white.opacity(0.6)).frame(width: 7, height: 7).offset(x: -2, y: -2))
            .overlay(Circle().strokeBorder(Ink.ink, lineWidth: 2))
            .background(GoldGlow())
    }
}
