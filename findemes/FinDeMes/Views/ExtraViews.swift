import SwiftUI

// MARK: - El taller de Paco

struct WorkshopView: View {
    @Environment(Game.self) private var game
    var body: some View {
        let any = Content.parts.contains { game.canBuyPart($0) }
        ZStack(alignment: .top) {
            Color(hex: "#5a3d2b").ignoresSafeArea()
            VStack(spacing: 0) {
                SheetHeader(title: "Taller de Paco", subtitle: "Valen para cualquier martillo")
                CashPill(value: Fmt.money(game.s.cash)).padding(.bottom, 8)
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Content.parts) { p in PartRow(def: p) }
                    }
                    .padding(.horizontal, 18).padding(.vertical, 10)
                }
                .scrollIndicators(.hidden)
                Button { game.buyAllParts() } label: {
                    Text(any ? "Comprar todo lo que puedo" : "No llega para nada").frame(maxWidth: .infinity)
                }
                .buttonStyle(ChunkyButton(color: Ink.gold, size: 19))
                .disabled(!any)
                .padding(.horizontal, 18).padding(.vertical, 10)
            }
        }
    }
}

struct PartRow: View {
    @Environment(Game.self) private var game
    let def: PartDef
    var body: some View {
        let l = game.partLevel(def)
        let maxed = l >= def.maxLevel
        let cost = game.partCost(def)
        HStack(spacing: 12) {
            ItemImage(name: "p_" + def.id).frame(width: 58, height: 58)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(def.name).font(.chunky(17)).foregroundStyle(Ink.ink)
                    Text("\(l)/\(def.maxLevel)").font(.typewriter(12, bold: true)).foregroundStyle(Ink.soft)
                }
                Text(perLevel).font(.typewriter(12)).foregroundStyle(Ink.soft)
                if l > 0 { Text(now(l)).font(.typewriter(12, bold: true)).foregroundStyle(Ink.green) }
                HStack(spacing: 8) {
                    Button { game.buyPart(def) } label: { Text(maxed ? "MÁX." : Fmt.money(cost)).frame(maxWidth: .infinity) }
                        .buttonStyle(ChunkyButton(color: Ink.gold, size: 15, radius: 10))
                        .disabled(maxed || game.s.cash < cost)
                    Button { game.buyPartMax(def) } label: { Text("Máx.") }
                        .buttonStyle(ChunkyButton(color: Ink.paper, size: 15, radius: 10))
                        .disabled(maxed || game.s.cash < cost)
                }
                .padding(.top, 4)
            }
        }
        .padding(10)
        .paper()
    }
    private var perLevel: String {
        def.compound ? def.desc.filling(Fmt.dec(1 + def.per / 100, 2)) + " por nivel" : def.desc.filling(Fmt.num(def.per)) + " por nivel"
    }
    private func now(_ l: Int) -> String {
        let v = def.value(l)
        return "Ahora: " + def.desc.filling(Fmt.num(v))
    }
}

// MARK: - Tótems

struct TotemsView: View {
    @Environment(Game.self) private var game
    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: "#2f4a3a").ignoresSafeArea()
            VStack(spacing: 0) {
                SheetHeader(title: "Tótems", subtitle: "Se quedan aunque te arruines")
                CashPill(value: "\(Fmt.num(game.s.legacy)) puntos de herencia", color: Color(hex: "#f2d58a")).padding(.bottom, 8)
                slots.padding(.horizontal, 18).padding(.bottom, 6)
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 14) {
                        ForEach(Content.totems) { t in TotemCard(def: t) }
                    }
                    .padding(.horizontal, 18).padding(.vertical, 10)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    /// los huecos de arriba: lo que tienes puesto
    private var slots: some View {
        HStack(spacing: 10) {
            ForEach(0..<max(3, game.totemSlots), id: \.self) { i in
                let open = i < game.totemSlots
                let id = i < game.s.totemsOn.count ? game.s.totemsOn[i] : nil
                VStack(spacing: 2) {
                    if let id, let t = Content.totems.first(where: { $0.id == id }) {
                        ItemImage(name: "t_" + t.id).frame(height: 54)
                        Text("Nv. \(game.totemLevel(t))").font(.typewriter(11, bold: true)).foregroundStyle(Ink.ink)
                    } else if open {
                        Image(systemName: "plus").font(.system(size: 22, weight: .black)).foregroundStyle(Ink.soft).frame(height: 54)
                        Text("Libre").font(.typewriter(11, bold: true)).foregroundStyle(Ink.soft)
                    } else {
                        Image(systemName: "lock.fill").font(.system(size: 20, weight: .black)).foregroundStyle(Ink.soft).frame(height: 54)
                        Text("Nivel \(Game.totemSlotLevels[i])").font(.typewriter(11, bold: true)).foregroundStyle(Ink.soft)
                    }
                }
                .frame(maxWidth: .infinity).padding(.vertical, 8)
                .outlined(12, color: open ? Ink.paper : Ink.paperDark, shadow: 3)
            }
        }
    }
}

struct TotemCard: View {
    @Environment(Game.self) private var game
    let def: TotemDef
    var body: some View {
        let l = game.totemLevel(def)
        let on = game.s.totemsOn.contains(def.id)
        let maxed = l >= TotemDef.maxLevel
        let cost = def.cost(l)
        VStack(spacing: 6) {
            ItemImage(name: "t_" + def.id).frame(height: 96)
                .opacity(l == 0 ? 0.55 : 1)
            Text(def.name).font(.chunky(16)).foregroundStyle(Ink.ink).multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.8)
            Text(l == 0 ? "Sin comprar" : "Nivel \(l)/\(TotemDef.maxLevel)").font(.typewriter(11, bold: true)).foregroundStyle(Ink.soft)
            Text(def.desc(l)).font(.typewriter(11)).foregroundStyle(Ink.ink).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if l > 0 && !maxed {
                Text("Siguiente: " + def.desc(l + 1)).font(.typewriter(10)).foregroundStyle(Ink.soft).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button { game.buyTotem(def) } label: {
                Text(maxed ? "MÁX." : (l == 0 ? "Comprar · \(Fmt.num(cost))" : "Subir · \(Fmt.num(cost))")).frame(maxWidth: .infinity)
            }
            .buttonStyle(ChunkyButton(color: Color(hex: "#f2d58a"), size: 14, radius: 10))
            .disabled(maxed || game.s.legacy < cost)
            if l > 0 {
                Button { game.toggleTotem(def) } label: { Text(on ? "Quitar" : "Poner").frame(maxWidth: .infinity) }
                    .buttonStyle(ChunkyButton(color: on ? Ink.paperDark : Ink.green, text: on ? Ink.ink : Ink.paper, size: 14, radius: 10))
                    .disabled(!on && game.s.totemsOn.count >= game.totemSlots)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .paper(on ? Color(hex: "#fff6c8") : Ink.paper)
    }
}

// MARK: - El bar: tragaperras y rasca

struct BarView: View {
    @Environment(Game.self) private var game
    @State private var tab = 0
    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: "#4a1f2a").ignoresSafeArea()
            VStack(spacing: 0) {
                SheetHeader(title: "El bar de Manolo", subtitle: "La casa siempre gana. Casi.")
                CashPill(value: Fmt.money(game.s.cash)).padding(.bottom, 10)
                HStack(spacing: 10) {
                    tabButton("Tragaperras", 0)
                    tabButton(game.freeScratch ? "Rasca (gratis)" : "Rasca", 1)
                    tabButton("Carreras", 2)
                }
                .padding(.horizontal, 18).padding(.bottom, 8)
                ScrollView {
                    if tab == 0 { SlotMachineView() } else if tab == 1 { ScratchView() } else { RaceView() }
                }
                .scrollIndicators(.hidden)
            }
        }
    }
    private func tabButton(_ t: String, _ i: Int) -> some View {
        Button { Sound.shared.click(); tab = i } label: { Text(t).frame(maxWidth: .infinity) }
            .buttonStyle(ChunkyButton(color: tab == i ? Ink.gold : Ink.paper, size: 16, radius: 12))
    }
}

struct SlotSymbolView: View {
    let symbol: SlotSymbol
    var size: CGFloat = 76
    var body: some View {
        Group {
            if symbol == .cerdo { KindIcon(kind: .normal, size: size * 0.84) } else { ItemImage(name: symbol.image).padding(size * 0.08) }
        }
        .frame(width: size, height: size)
    }
}

struct SlotMachineView: View {
    @Environment(Game.self) private var game
    @State private var reels: [SlotSymbol] = [.corona, .corona, .corona]
    @State private var spinning = [false, false, false]
    @State private var result: SpinResult? = nil
    @State private var share = 0.1
    @State private var flash = 0

    private let shares: [(String, Double)] = [("10 %", 0.1), ("25 %", 0.25), ("50 %", 0.5), ("Todo", 1)]

    var body: some View {
        let bet = (game.s.cash * share).rounded(.down)
        let busy = spinning.contains(true)
        VStack(spacing: 16) {
            // la máquina
            VStack(spacing: 12) {
                Text("TRAGAPERRAS").font(.chunky(26)).foregroundStyle(Ink.gold).shadow(color: Ink.ink, radius: 0, x: 2, y: 2)
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { i in
                        ZStack {
                            Rectangle().fill(Ink.paper)
                            if spinning[i] {
                                TimelineView(.animation(minimumInterval: 0.07)) { ctx in
                                    let k = Int(ctx.date.timeIntervalSinceReferenceDate * 14) + i * 2
                                    SlotSymbolView(symbol: SlotSymbol.allCases[k % SlotSymbol.allCases.count]).blur(radius: 1.5)
                                }
                            } else {
                                SlotSymbolView(symbol: reels[i]).transition(.move(edge: .top))
                            }
                        }
                        .frame(width: 86, height: 96)
                        .clipped()
                        .overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 3))
                    }
                }
                Group {
                    if let r = result, !busy {
                        if r.won > r.bet {
                            Text("¡+\(Fmt.money(r.won - r.bet))!" + (r.chest != nil ? " y un sobre \(r.chest!.name.lowercased())" : ""))
                                .foregroundStyle(Ink.gold)
                        } else if r.won == r.bet {
                            Text("Recuperas lo apostado").foregroundStyle(Ink.paper)
                        } else {
                            Text("Nada. −\(Fmt.money(r.bet))").foregroundStyle(Color(hex: "#ff9a8a"))
                        }
                    } else {
                        Text(busy ? "…" : " ").foregroundStyle(Ink.paper)
                    }
                }
                .font(.chunky(20)).frame(height: 26)
                .id(flash)
                .transition(.scale.combined(with: .opacity))
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .outlined(18, color: Color(hex: "#8a1f2a"), shadow: 6)

            // apuesta
            VStack(alignment: .leading, spacing: 8) {
                Text("Apuesta: \(Fmt.money(max(0, bet)))").font(.chunky(18)).foregroundStyle(Ink.ink)
                HStack(spacing: 8) {
                    ForEach(0..<shares.count, id: \.self) { i in
                        let s = shares[i]
                        Button { Sound.shared.click(); share = s.1 } label: { Text(s.0).frame(maxWidth: .infinity) }
                            .buttonStyle(ChunkyButton(color: share == s.1 ? Ink.gold : Ink.paper, size: 14, radius: 10))
                    }
                }
                Button { pull(bet) } label: { Text("¡TIRAR!").frame(maxWidth: .infinity) }
                    .buttonStyle(ChunkyButton(color: Ink.red, text: Ink.paper, size: 24))
                    .disabled(busy || bet < 1 || game.inRun)
                    .padding(.top, 4)
            }
            .padding(14)
            .paper()

            // la tabla de premios
            VStack(alignment: .leading, spacing: 6) {
                Text("PREMIOS").font(.chunky(18)).foregroundStyle(Ink.ink)
                ForEach(SlotSymbol.allCases.reversed(), id: \.self) { s in
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { _ in SlotSymbolView(symbol: s, size: 30) }
                        Spacer()
                        Text("×\(Fmt.num(s.pays * game.casinoBoost))" + (s == .corona ? " + sobre legendario" : (s == .anillo ? " + sobre épico" : "")))
                            .font(.typewriter(13, bold: true)).foregroundStyle(Ink.ink)
                    }
                }
                Text("Dos iguales: recuperas lo apostado").font(.typewriter(12)).foregroundStyle(Ink.soft)
            }
            .padding(14)
            .paper()
        }
        .padding(.horizontal, 18).padding(.vertical, 6)
    }

    private func pull(_ bet: Double) {
        guard let r = game.spin(bet: bet) else { return }
        Sound.shared.swing()
        result = r
        spinning = [true, true, true]
        // los rodillos paran uno detrás de otro
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7 + Double(i) * 0.45) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                    reels[i] = r.reels[i]
                    spinning[i] = false
                }
                Sound.shared.click()
                if i == 2 {
                    withAnimation(.spring) { flash += 1 }
                    if r.chest != nil || r.won >= r.bet * 30 { Sound.shared.fanfare() }
                    else if r.won > r.bet { Sound.shared.till() }
                    else if r.won < r.bet { Sound.shared.denied() }
                }
            }
        }
    }
}

struct ScratchView: View {
    @Environment(Game.self) private var game
    @State private var card: ScratchCard? = nil
    @State private var open: Set<Int> = []
    @State private var claimed: String? = nil

    var body: some View {
        VStack(spacing: 16) {
            if let card {
                VStack(spacing: 10) {
                    Text("RASCA Y GANA").font(.chunky(24)).foregroundStyle(Ink.ink)
                    Text("Tres iguales y te lo llevas").font(.typewriter(12, bold: true)).foregroundStyle(Ink.soft)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(0..<9, id: \.self) { i in cell(card, i) }
                    }
                    if open.count == 9 {
                        Text(card.prize == nil ? "Esta vez nada" : "¡\(claimed ?? card.prize!.name)!")
                            .font(.chunky(22)).foregroundStyle(card.prize == nil ? Ink.soft : Ink.green)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Button { scratchAll() } label: { Text("Rascar todo").frame(maxWidth: .infinity) }
                            .buttonStyle(ChunkyButton(color: Ink.paper, size: 16, radius: 10))
                    }
                }
                .padding(14)
                .paper(Color(hex: "#fff6c8"))
            }
            if card == nil || open.count == 9 {
                Button { newCard() } label: {
                    Text(game.freeScratch ? "Rasca gratis de hoy" : "Comprar rasca · \(Fmt.money(game.scratchPrice))").frame(maxWidth: .infinity)
                }
                .buttonStyle(ChunkyButton(color: Ink.gold, size: 20))
                .disabled(!game.freeScratch && game.s.cash < game.scratchPrice)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("PREMIOS").font(.chunky(18)).foregroundStyle(Ink.ink)
                ForEach(ScratchPrize.allCases.reversed(), id: \.self) { p in
                    HStack(spacing: 8) { prizeIcon(p).frame(width: 30, height: 30); Text(p.name).font(.typewriter(13, bold: true)).foregroundStyle(Ink.ink) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .paper()
        }
        .padding(.horizontal, 18).padding(.vertical, 6)
    }

    private func cell(_ card: ScratchCard, _ i: Int) -> some View {
        let shown = open.contains(i)
        let p = card.cells[i]
        let win = shown && p != nil && p == card.prize && open.count == 9
        return ZStack {
            Rectangle().fill(win ? Color(hex: "#d9f2c8") : Ink.paper)
            if let p { prizeIcon(p).padding(10) } else { Image(systemName: "xmark").font(.system(size: 26, weight: .black)).foregroundStyle(Ink.soft) }
            if !shown {
                Rectangle().fill(Color(hex: "#b9b3ad"))
                Image(systemName: "questionmark").font(.system(size: 26, weight: .black)).foregroundStyle(Color(hex: "#8a847d"))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 2.5))
        .onTapGesture { reveal(i) }
    }

    @ViewBuilder private func prizeIcon(_ p: ScratchPrize) -> some View {
        switch p {
        case .calderilla: ItemImage(name: "c_loot")
        case .fajo: ItemImage(name: "billete")
        case .sobreRaro: EnvelopeArt(rarity: .rara)
        case .sobreEpico: EnvelopeArt(rarity: .epica)
        case .sobreLegendario: EnvelopeArt(rarity: .legendaria)
        case .herencia: ItemImage(name: "j_diamantes")
        }
    }

    private func newCard() {
        guard let c = game.buyScratch() else { return }
        Sound.shared.click()
        withAnimation { card = c; open = []; claimed = nil }
    }
    private func reveal(_ i: Int) {
        guard card != nil, !open.contains(i) else { return }
        Sound.shared.pop()
        withAnimation(.easeOut(duration: 0.2)) { _ = open.insert(i) }
        if open.count == 9 { finish() }
    }
    private func scratchAll() {
        Sound.shared.pop()
        withAnimation(.easeOut(duration: 0.3)) { open = Set(0..<9) }
        finish()
    }
    private func finish() {
        guard let card else { return }
        if card.prize != nil { claimed = game.claimScratch(card.prize) } else { Sound.shared.denied() }
    }
}

// MARK: - Carreras

struct RaceView: View {
    @Environment(Game.self) private var game
    @State private var pick = 0
    @State private var share = 0.1
    @State private var result: RaceResult? = nil
    @State private var start: Date? = nil
    @State private var done = true

    private let shares: [(String, Double)] = [("10 %", 0.1), ("25 %", 0.25), ("50 %", 0.5), ("Todo", 1)]
    private let length = 5.0

    var body: some View {
        let bet = (game.s.cash * share).rounded(.down)
        VStack(spacing: 16) {
            VStack(spacing: 10) {
                Text("LA GRAN CARRERA").font(.chunky(24)).foregroundStyle(Ink.gold).shadow(color: Ink.ink, radius: 0, x: 2, y: 2)
                TimelineView(.animation(paused: done)) { ctx in
                    let t = start.map { ctx.date.timeIntervalSince($0) / length } ?? 0
                    track(t)
                }
                Group {
                    if let r = result, done {
                        if r.won > 0 { Text("¡Ha ganado! +\(Fmt.money(r.won - r.bet))").foregroundStyle(Ink.gold) }
                        else { Text("Ganó \(Content.racers[r.order[0]].name). −\(Fmt.money(r.bet))").foregroundStyle(Color(hex: "#ff9a8a")) }
                    } else { Text(done ? " " : "…").foregroundStyle(Ink.paper) }
                }
                .font(.chunky(19)).frame(height: 26).lineLimit(1).minimumScaleFactor(0.6)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .outlined(18, color: Color(hex: "#3d6b3f"), shadow: 6)

            VStack(alignment: .leading, spacing: 8) {
                Text("¿Por quién apuestas?").font(.chunky(18)).foregroundStyle(Ink.ink)
                ForEach(Content.racers.indices, id: \.self) { i in
                    let r = Content.racers[i]
                    Button { Sound.shared.click(); pick = i } label: {
                        HStack(spacing: 10) {
                            Text("\(i + 1)").font(.chunky(16)).frame(width: 26, height: 26).background(Circle().fill(pick == i ? Ink.red : Ink.paperDark)).foregroundStyle(pick == i ? Ink.paper : Ink.ink)
                            KindIcon(kind: r.kind, size: 34)
                            Text(r.name).font(.chunky(16)).foregroundStyle(Ink.ink)
                            Spacer()
                            Text("×\(Fmt.dec(r.pays * game.casinoBoost, 1))").font(.typewriter(14, bold: true)).foregroundStyle(Ink.ink)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(pick == i ? Color(hex: "#fff6c8") : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .disabled(!done)
                }
                Text("Apuesta: \(Fmt.money(max(0, bet)))").font(.chunky(18)).foregroundStyle(Ink.ink).padding(.top, 4)
                HStack(spacing: 8) {
                    ForEach(0..<shares.count, id: \.self) { i in
                        let s = shares[i]
                        Button { Sound.shared.click(); share = s.1 } label: { Text(s.0).frame(maxWidth: .infinity) }
                            .buttonStyle(ChunkyButton(color: share == s.1 ? Ink.gold : Ink.paper, size: 14, radius: 10))
                    }
                }
                Button { go(bet) } label: { Text("¡SALIDA!").frame(maxWidth: .infinity) }
                    .buttonStyle(ChunkyButton(color: Ink.red, text: Ink.paper, size: 24))
                    .disabled(!done || bet < 1 || game.inRun)
                    .padding(.top, 4)
            }
            .padding(14)
            .paper()
        }
        .padding(.horizontal, 18).padding(.vertical, 6)
    }

    /// la pista: cada cerdo avanza a trompicones y llega en su puesto
    private func track(_ t: Double) -> some View {
        VStack(spacing: 4) {
            ForEach(Content.racers.indices, id: \.self) { i in
                GeometryReader { g in
                    let w = g.size.width - 44
                    let x = progress(i, t) * w
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color(hex: i % 2 == 0 ? "#c9a26b" : "#b8915c"))
                        Rectangle().fill(Ink.paper).frame(width: 4).offset(x: g.size.width - 12)
                        KindIcon(kind: Content.racers[i].kind, size: 38)
                            .scaleEffect(x: -1)
                            .offset(x: x, y: done ? 0 : -abs(sin(t * 40 + Double(i))) * 5)
                        Text("\(i + 1)").font(.chunky(12)).foregroundStyle(Ink.paper).offset(x: x + 14, y: 12)
                    }
                }
                .frame(height: 40)
                .overlay(alignment: .leading) {
                    if pick == i { Rectangle().fill(Ink.red).frame(width: 4) }
                }
            }
        }
        .overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 3))
    }

    private func progress(_ i: Int, _ t: Double) -> Double {
        guard let r = result else { return 0 }
        let place = Double(r.order.firstIndex(of: i) ?? 4)
        let end = 1 + place * 0.06
        let base = min(1, t / end)
        let wobble = sin(t * (9 + Double(i) * 2.3) + Double(i)) * 0.04 * (1 - base)
        return max(0, min(1, base + wobble))
    }

    private func go(_ bet: Double) {
        guard let r = game.race(bet: bet, pick: pick) else { return }
        Sound.shared.fanfare()
        result = r
        start = Date()
        done = false
        DispatchQueue.main.asyncAfter(deadline: .now() + length * 1.3) {
            done = true
            if r.won > 0 { Sound.shared.till() } else { Sound.shared.denied() }
        }
    }
}

// MARK: - Mascotas

struct PetsView: View {
    @Environment(Game.self) private var game
    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: "#3a5a7a").ignoresSafeArea()
            VStack(spacing: 0) {
                SheetHeader(title: "Mascotas", subtitle: "Rompen huchas por su cuenta")
                CashPill(value: "\(Fmt.num(game.s.legacy)) puntos de herencia", color: Color(hex: "#f2d58a")).padding(.bottom, 8)
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Content.pets) { p in PetRow(def: p) }
                    }
                    .padding(.horizontal, 18).padding(.vertical, 10)
                }
                .scrollIndicators(.hidden)
            }
        }
    }
}

struct PetRow: View {
    @Environment(Game.self) private var game
    let def: PetDef
    var body: some View {
        let l = game.petLevel(def)
        let on = game.s.pet == def.id && l > 0
        let maxed = l >= PetDef.maxLevel
        let cost = def.cost(l)
        let shown = max(1, l)
        HStack(spacing: 12) {
            ItemImage(name: "pet_" + def.id).frame(width: 86, height: 80).opacity(l == 0 ? 0.55 : 1)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(def.name).font(.chunky(19)).foregroundStyle(Ink.ink)
                    Text(l == 0 ? "Sin adoptar" : "Nv. \(l)/\(PetDef.maxLevel)").font(.typewriter(12, bold: true)).foregroundStyle(Ink.soft)
                }
                Text(def.line).font(.typewriter(11)).foregroundStyle(Ink.soft)
                HStack(alignment: .top, spacing: 5) {
                    Image(systemName: "star.fill").font(.system(size: 11, weight: .black)).foregroundStyle(Ink.gold)
                    Text(def.skillText).font(.typewriter(11, bold: true)).foregroundStyle(Ink.ink)
                }
                Text("Golpea con el \(Int(def.dmg(shown) * 100)) % de tu daño cada \(Fmt.dec(def.interval(shown), 1)) s")
                    .font(.typewriter(11)).foregroundStyle(Ink.ink)
                HStack(spacing: 8) {
                    Button { game.buyPet(def) } label: {
                        Text(maxed ? "MÁX." : (l == 0 ? "Adoptar · \(Fmt.num(cost))" : "Subir · \(Fmt.num(cost))")).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ChunkyButton(color: Color(hex: "#f2d58a"), size: 14, radius: 10))
                    .disabled(maxed || game.s.legacy < cost)
                    if l > 0 {
                        Button { game.pickPet(def) } label: { Text(on ? "Contigo" : "Llevar") }
                            .buttonStyle(ChunkyButton(color: on ? Ink.paperDark : Ink.green, text: on ? Ink.ink : Ink.paper, size: 14, radius: 10))
                    }
                }
                .padding(.top, 3)
            }
        }
        .padding(10)
        .paper(on ? Color(hex: "#fff6c8") : Ink.paper)
    }
}
