import SwiftUI

// MARK: - Mejoras del martillo (en la ferretería, encima de los martillos)

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
        .overlay(alignment: .topLeading) { if game.bestPart == def.id { GoldPin().offset(x: -6, y: -8) } }
    }
    private var perLevel: String { def.desc.filling(Fmt.num(def.per)) + " por nivel" }
    private func now(_ l: Int) -> String {
        let v = def.value(l)
        return "Ahora: " + def.desc.filling(Fmt.num(v))
    }
}

// MARK: - La feria: tragaperras (tres tiradas gratis al día) y rasca (uno gratis al día)

struct BarView: View {
    @Environment(Game.self) private var game
    @State private var tab = 0
    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: "#4a1f2a").ignoresSafeArea()
            VStack(spacing: 0) {
                SheetHeader(title: "La feria", subtitle: "Tiradas gratis cada día")
                CashPill(value: Fmt.money(game.s.cash)).padding(.bottom, 10)
                HStack(spacing: 10) {
                    tabButton("Tragaperras · \(game.freeSpins)", 0)
                    tabButton(game.freeScratch ? "Rasca · 1" : "Rasca", 1)
                }
                .padding(.horizontal, 18).padding(.bottom, 8)
                ScrollView {
                    if tab == 0 { SlotMachineView() } else { ScratchView() }
                }
                .task {
                    let args = ProcessInfo.processInfo.arguments
                    if let i = args.firstIndex(of: "-tab"), i + 1 < args.count, let n = Int(args[i + 1]) { tab = n }
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
    @State private var flash = 0

    var body: some View {
        let busy = spinning.contains(true)
        let unit = game.pigWorth * 5
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
                        if r.won > 0 {
                            Text("¡+\(Fmt.money(r.won))!" + (r.chest != nil ? " y un sobre \(r.chest!.name.lowercased())" : ""))
                                .foregroundStyle(Ink.gold)
                        } else {
                            Text("Nada").foregroundStyle(Color(hex: "#ff9a8a"))
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

            HStack(spacing: 8) {
                ForEach(0..<Game.dailySpins, id: \.self) { i in
                    Image(systemName: i < game.freeSpins ? "ticket.fill" : "ticket").font(.system(size: 24, weight: .black))
                        .foregroundStyle(i < game.freeSpins ? Ink.gold : Ink.paper.opacity(0.4))
                }
            }
            Button { pull() } label: { Text("¡TIRAR!").frame(maxWidth: .infinity) }
                .buttonStyle(ChunkyButton(color: Ink.red, text: Ink.paper, size: 24))
                .disabled(busy || game.freeSpins == 0 || game.inRun)

            // la tabla de premios
            VStack(alignment: .leading, spacing: 6) {
                Text("PREMIOS").font(.chunky(18)).foregroundStyle(Ink.ink)
                ForEach(SlotSymbol.allCases.reversed(), id: \.self) { s in
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { _ in SlotSymbolView(symbol: s, size: 30) }
                        Spacer()
                        Text(Fmt.money(unit * s.pays) + (s == .corona ? " + sobre legendario" : (s == .anillo ? " + sobre épico" : "")))
                            .font(.typewriter(13, bold: true)).foregroundStyle(Ink.ink)
                    }
                }
                HStack(spacing: 4) {
                    ForEach(0..<2, id: \.self) { _ in SlotSymbolView(symbol: .cerdo, size: 30) }
                    Spacer()
                    Text(Fmt.money(unit)).font(.typewriter(13, bold: true)).foregroundStyle(Ink.ink)
                }
            }
            .padding(14)
            .paper()
        }
        .padding(.horizontal, 18).padding(.vertical, 6)
    }

    private func pull() {
        guard let r = game.spin() else { return }
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
                    if r.chest != nil || r.won >= game.pigWorth * 150 { Sound.shared.fanfare() }
                    else if r.won > 0 { Sound.shared.till() }
                    else { Sound.shared.denied() }
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
            if (card == nil || open.count == 9) && game.freeScratch {
                Button { newCard() } label: { Text("Rascar").frame(maxWidth: .infinity) }
                    .buttonStyle(ChunkyButton(color: Ink.gold, size: 20))
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
        case .herencia: ItemImage(name: "billete")
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
