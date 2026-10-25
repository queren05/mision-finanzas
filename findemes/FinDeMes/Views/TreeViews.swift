import SwiftUI

/// Las tres formas de ver el árbol de mejoras (se elige arriba del árbol o en Ajustes)
enum TreeStyle: Int, CaseIterable {
    case corcho, columnas, cajones
    var name: String {
        switch self {
        case .corcho: "Corcho"
        case .columnas: "Columnas"
        case .cajones: "Cajones"
        }
    }
    var icon: String {
        switch self {
        case .corcho: "pin.fill"
        case .columnas: "chart.bar.fill"
        case .cajones: "tray.full.fill"
        }
    }
}

/// El árbol de mejoras (y el familiar): notas de papel clavadas en el corcho con chinchetas y unidas con hilo.
struct TreeView: View {
    @Environment(Game.self) private var game
    var family = false
    @State private var picked: String? = nil
    @State private var bought = 0
    @State private var boughtKey = 0
    @State private var zoom: CGFloat = 0.75
    @State private var baseZoom: CGFloat = 0.75
    @State private var drawer: Branch = .dano

    private var tree: SkillTree { family ? .family : .corcho }
    private var defs: [SkillDef] { family ? Content.family : Content.skills }
    private var style: TreeStyle { TreeStyle(rawValue: game.s.settings.treeStyle) ?? .corcho }

    var body: some View {
        ZStack(alignment: .top) {
            CorkBackground(family: family)
            VStack(spacing: 0) {
                SheetHeader(title: family ? "Árbol familiar" : "Árbol de mejoras", subtitle: family ? "Se queda para siempre" : "Se pierde con la bancarrota")
                HStack(spacing: 8) {
                    if family { CashPill(value: "\(Fmt.num(game.s.legacy)) puntos", color: Color(hex: "#f2d58a")) }
                    else { CashPill(value: Fmt.money(game.s.cash)) }
                    Spacer(minLength: 4)
                    if style == .corcho {
                        Button { setZoom(zoom - 0.15) } label: { Image(systemName: "minus.magnifyingglass").font(.system(size: 15, weight: .black)) }
                            .buttonStyle(ChunkyButton(color: Ink.paper, size: 14, radius: 10))
                        Button { setZoom(zoom + 0.15) } label: { Image(systemName: "plus.magnifyingglass").font(.system(size: 15, weight: .black)) }
                            .buttonStyle(ChunkyButton(color: Ink.paper, size: 14, radius: 10))
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 8)
                TreeStylePicker().padding(.horizontal, 16).padding(.bottom, 8)
                switch style {
                case .corcho: corkboard
                case .columnas:
                    legend.padding(.horizontal, 10).padding(.bottom, 4)
                    columns
                case .cajones:
                    drawerTabs.padding(.horizontal, 10).padding(.bottom, 6)
                    drawers
                }
                panel
            }
        }
        .task {
            // capturas automáticas: -treestyle 0|1|2
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-treestyle"), i + 1 < args.count, let n = Int(args[i + 1]) { game.s.settings.treeStyle = n }
        }
    }

    private func setZoom(_ z: CGFloat) {
        Sound.shared.click()
        withAnimation(.snappy) { zoom = min(1.6, max(0.45, z)) }
        baseZoom = zoom
    }

    // MARK: 1 · el corcho de antes (cada nota en su sitio y un hilo rojo a la que la desbloquea)

    private let cell: CGFloat = 92

    private func corkCenter(_ k: SkillDef) -> CGPoint {
        CGPoint(x: 20 + CGFloat(k.col) * (cell + 16) + cell / 2, y: 26 + CGFloat(k.row) * (cell + 26) + cell / 2)
    }

    private var corkboard: some View {
        let cols = (defs.map(\.col).max() ?? 0) + 1
        let rows = (defs.map(\.row).max() ?? 0) + 1
        let w = CGFloat(cols) * cell + CGFloat(cols - 1) * 16 + 40
        let h = CGFloat(rows) * cell + CGFloat(rows - 1) * 26 + 52
        return ScrollView([.horizontal, .vertical]) {
            ZStack(alignment: .topLeading) {
                Canvas { ctx, _ in
                    for k in defs {
                        guard let pid = tree.parent[k.id], let p = defs.first(where: { $0.id == pid }),
                              game.isVisible(k) || game.isVisible(p) else { continue }
                        thread(ctx, from: pin(corkCenter(p), cell), to: pin(corkCenter(k), cell), color: Ink.red, state: threadState(k), sag: 14)
                    }
                }
                .frame(width: w, height: h)
                ForEach(defs) { k in note(k, size: cell).position(corkCenter(k)) }
            }
            .frame(width: w, height: h)
            .scaleEffect(zoom, anchor: .topLeading)
            .frame(width: w * zoom, height: h * zoom, alignment: .topLeading)
            .frame(minWidth: UIScreen.main.bounds.width)
        }
        .defaultScrollAnchor(.top)
        .scrollIndicators(.hidden)
        .simultaneousGesture(
            MagnifyGesture()
                .onChanged { v in zoom = min(1.6, max(0.45, baseZoom * v.magnification)) }
                .onEnded { _ in baseZoom = zoom }
        )
    }

    // MARK: 2 · cinco columnas, una por color, de abajo arriba

    private var columns: some View {
        let card: CGFloat = 70
        let rowH: CGFloat = 98
        let longest = CGFloat(tree.branches.map(\.count).max() ?? 0)
        return GeometryReader { g in
            let w = g.size.width
            let h = longest * rowH + 230
            let colW = w / CGFloat(Branch.allCases.count)
            let root = CGPoint(x: w / 2, y: h - 66)
            let at = { (b: Int, j: Int) -> CGPoint in
                CGPoint(x: colW * (CGFloat(b) + 0.5), y: h - 200 - CGFloat(j) * rowH + (b % 2 == 1 ? 20 : 0))
            }
            ScrollView(.vertical) {
                ZStack(alignment: .topLeading) {
                    Canvas { ctx, _ in
                        for (b, list) in tree.branches.enumerated() {
                            for j in list.indices {
                                let from = j == 0 ? pin(root, cell) : pin(at(b, j - 1), card)
                                thread(ctx, from: from, to: pin(at(b, j), card), color: Branch(rawValue: b)!.color, state: threadState(list[j]), sag: j == 0 ? 30 : 8)
                            }
                        }
                    }
                    .frame(width: w, height: h)
                    note(tree.root, size: cell).position(root)
                    ForEach(tree.branches.indices, id: \.self) { b in
                        ForEach(tree.branches[b].indices, id: \.self) { j in
                            note(tree.branches[b][j], size: card).position(at(b, j))
                        }
                    }
                }
                .frame(width: w, height: h)
            }
            .defaultScrollAnchor(.bottom)
            .scrollIndicators(.hidden)
        }
    }

    // MARK: 3 · cajones: un color cada vez, notas grandes en zigzag

    private var drawerTabs: some View {
        HStack(spacing: 5) {
            ForEach(Branch.allCases, id: \.rawValue) { b in
                let n = tree.branches[b.rawValue].filter { game.canGet($0) }.count
                let on = drawer == b
                Button {
                    Sound.shared.click()
                    withAnimation(.snappy) { drawer = b }
                } label: {
                    Text(b.name(family: family)).font(.chunky(13)).lineLimit(1).minimumScaleFactor(0.6)
                        .foregroundStyle(on ? Ink.paper : Ink.ink)
                        .shadow(color: on ? Ink.ink : .clear, radius: 0, x: 1, y: 1)
                        .frame(maxWidth: .infinity).padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 10).fill(on ? b.color : Ink.paper))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Ink.ink, lineWidth: 2.5))
                        .offset(y: on ? 3 : 0)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Ink.ink).offset(y: 4))
                        .overlay(alignment: .topTrailing) {
                            if n > 0 {
                                Text("\(n)").font(.chunky(10)).foregroundStyle(Ink.paper)
                                    .frame(minWidth: 16, minHeight: 16)
                                    .background(Circle().fill(Ink.red)).overlay(Circle().strokeBorder(Ink.ink, lineWidth: 1.5))
                                    .offset(x: 5, y: -6)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var drawers: some View {
        let list = [tree.root] + tree.branches[drawer.rawValue]
        let rowH: CGFloat = 112
        return GeometryReader { g in
            let w = g.size.width
            let cardW = min(300, w * 0.74)
            let h = CGFloat(list.count) * rowH + 40
            let at = { (j: Int) -> CGPoint in CGPoint(x: w * (j % 2 == 0 ? 0.42 : 0.58), y: 62 + CGFloat(j) * rowH) }
            ScrollView(.vertical) {
                ZStack(alignment: .topLeading) {
                    Canvas { ctx, _ in
                        for j in list.indices.dropFirst() {
                            thread(ctx, from: pin(at(j - 1), 78), to: pin(at(j), 78), color: drawer.color, state: threadState(list[j]), sag: 26)
                        }
                    }
                    .frame(width: w, height: h)
                    ForEach(list.indices, id: \.self) { j in
                        wideNote(list[j], width: cardW, tilt: j % 2 == 0 ? 1.5 : -1.5).position(at(j))
                    }
                }
                .frame(width: w, height: h)
                .id(drawer)
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: piezas comunes: hilo, chincheta y notas

    private enum Thread { case bought, open, locked }

    private func threadState(_ k: SkillDef) -> Thread {
        game.level(k) > 0 ? .bought : (game.isVisible(k) ? .open : .locked)
    }

    private func pin(_ c: CGPoint, _ size: CGFloat) -> CGPoint { CGPoint(x: c.x, y: c.y - size / 2 + 3) }

    /// hilo de chincheta a chincheta, colgando un poco: tenso y de color si ya está comprada, punteado si no
    private func thread(_ ctx: GraphicsContext, from: CGPoint, to: CGPoint, color: Color, state: Thread, sag: CGFloat) {
        var p = Path()
        p.move(to: from)
        p.addQuadCurve(to: to, control: CGPoint(x: (from.x + to.x) / 2, y: max(from.y, to.y) + sag))
        switch state {
        case .bought:
            ctx.stroke(p.applying(CGAffineTransform(translationX: 1.5, y: 3)), with: .color(Ink.ink.opacity(0.3)), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
            ctx.stroke(p, with: .color(Ink.ink), style: StrokeStyle(lineWidth: 5.5, lineCap: .round))
            ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
        case .open:
            ctx.stroke(p, with: .color(color.opacity(0.8)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [7, 6]))
        case .locked:
            ctx.stroke(p, with: .color(Ink.ink.opacity(0.22)), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, dash: [3, 6]))
        }
    }

    private func branchColor(_ k: SkillDef) -> Color { k.id == tree.root.id ? Ink.red : Branch.of(k.effect).color }

    /// inclinación fija para cada nota (no cambia entre aperturas)
    private func tilt(_ k: SkillDef) -> Double {
        let h = k.id.unicodeScalars.reduce(0) { $0 &* 31 &+ Int($1.value) }
        return Double(abs(h) % 7) - 3
    }

    private func chincheta(_ k: SkillDef) -> some View {
        Circle().fill(game.canGet(k) ? Ink.gold : branchColor(k))
            .frame(width: 15, height: 15)
            .overlay(Circle().fill(.white.opacity(0.55)).frame(width: 5, height: 5).offset(x: -2, y: -2))
            .overlay(Circle().strokeBorder(Ink.ink, lineWidth: 2))
            .offset(y: -6)
    }

    private func levelTag(_ k: SkillDef, _ size: CGFloat) -> some View {
        let l = game.level(k)
        let maxed = l >= k.maxLevel
        return Text(maxed ? "MÁX." : "\(l)/\(k.maxLevel)")
            .font(.typewriter(size, bold: true)).foregroundStyle(Ink.paper)
            .padding(.horizontal, 4).padding(.vertical, 1)
            .background(maxed ? Ink.green : (l > 0 ? branchColor(k) : Ink.soft), in: Capsule())
            .fixedSize()
    }

    private func tap(_ k: SkillDef) {
        // tocar solo la elige: abajo se ve qué hace y se compra con el botón
        Sound.shared.click()
        withAnimation(.snappy) { picked = k.id }
    }

    /// nota cuadrada (corcho y columnas)
    private func note(_ k: SkillDef, size: CGFloat) -> some View {
        let l = game.level(k)
        let vis = game.isVisible(k)
        let can = game.canGet(k)
        let maxed = l >= k.maxLevel
        let sel = picked == k.id
        let side = vis ? size : size * 0.72
        let small = size < 80
        return ZStack(alignment: .top) {
            Group {
                if vis {
                    VStack(spacing: 2) {
                        Image(systemName: k.icon)
                            .font(.system(size: small ? 19 : 24, weight: .black))
                            .foregroundStyle(l > 0 ? branchColor(k) : Ink.ink)
                            .padding(.top, small ? 11 : 13)
                        Text(k.name).font(.chunky(small ? 10.5 : 12)).foregroundStyle(Ink.ink)
                            .lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.7)
                        Spacer(minLength: 0)
                        if maxed { levelTag(k, small ? 9 : 10) }
                        else {
                            HStack(spacing: 3) {
                                levelTag(k, small ? 8.5 : 10)
                                Text(game.price(k, game.cost(k)))
                                    .font(.typewriter(small ? 8.5 : 10, bold: true)).foregroundStyle(can ? Ink.ink : Ink.soft)
                                    .lineLimit(1).minimumScaleFactor(0.5)
                            }
                        }
                    }
                    .padding(.horizontal, 4).padding(.bottom, 6)
                } else {
                    Image(systemName: "questionmark").font(.system(size: 18, weight: .black)).foregroundStyle(Ink.soft)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: side, height: side)
            .paper(can ? Color(hex: "#fff6c8") : (vis ? Ink.paper : Ink.paperDark), tilt: tilt(k), shadow: vis ? 4 : 2)
            .overlay { if sel { Rectangle().strokeBorder(Ink.gold, lineWidth: 4).padding(-5).rotationEffect(.degrees(tilt(k))) } }
            .opacity(vis ? 1 : 0.8)
            chincheta(k)
        }
        .scaleEffect(sel ? 1.08 : 1)
        .phaseAnimator([0.0, can ? 1.0 : 0.0]) { v, a in v.scaleEffect(1 + a * 0.05) } animation: { _ in .easeInOut(duration: 0.7) }
        .contentShape(Rectangle())
        .onTapGesture { tap(k) }
    }

    /// nota apaisada con lo que hace (cajones)
    private func wideNote(_ k: SkillDef, width: CGFloat, tilt: Double) -> some View {
        let l = game.level(k)
        let vis = game.isVisible(k)
        let can = game.canGet(k)
        let maxed = l >= k.maxLevel
        let sel = picked == k.id
        let col = branchColor(k)
        return ZStack(alignment: .top) {
            HStack(spacing: 12) {
                Image(systemName: vis ? k.icon : "questionmark")
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(vis ? (l > 0 ? col : Ink.ink) : Ink.soft)
                    .frame(width: 46)
                VStack(alignment: .leading, spacing: 3) {
                    Text(vis ? k.name : "???").font(.chunky(16)).foregroundStyle(Ink.ink).lineLimit(1).minimumScaleFactor(0.7)
                    Text(vis ? k.perText + " por nivel" : "Compra antes la de arriba").font(.typewriter(10.5, bold: true)).foregroundStyle(Ink.soft)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    HStack {
                        levelTag(k, 10.5)
                        Spacer(minLength: 4)
                        if vis && !maxed {
                            Text(game.price(k, game.cost(k))).font(.typewriter(12, bold: true)).foregroundStyle(can ? Ink.ink : Ink.soft)
                                .lineLimit(1).minimumScaleFactor(0.6)
                        }
                    }
                }
            }
            .padding(.horizontal, 12).padding(.top, 14).padding(.bottom, 10)
            .frame(width: width, height: 78)
            .paper(can ? Color(hex: "#fff6c8") : (vis ? Ink.paper : Ink.paperDark), tilt: tilt, shadow: 4)
            .overlay { if sel { Rectangle().strokeBorder(Ink.gold, lineWidth: 4).padding(-5).rotationEffect(.degrees(tilt)) } }
            .opacity(vis ? 1 : 0.85)
            chincheta(k)
        }
        .phaseAnimator([0.0, can ? 1.0 : 0.0]) { v, a in v.scaleEffect(1 + a * 0.03) } animation: { _ in .easeInOut(duration: 0.7) }
        .contentShape(Rectangle())
        .onTapGesture { tap(k) }
    }

    // MARK: arriba y abajo

    private var legend: some View {
        HStack(spacing: 4) {
            ForEach(Branch.allCases, id: \.rawValue) { b in
                let n = tree.branches[b.rawValue].filter { game.canGet($0) }.count
                HStack(spacing: 3) {
                    Circle().fill(b.color).frame(width: 9, height: 9).overlay(Circle().strokeBorder(Ink.ink, lineWidth: 1.5))
                    Text(b.name(family: family)).font(.typewriter(10, bold: true)).lineLimit(1).minimumScaleFactor(0.6)
                    if n > 0 { Text("\(n)").font(.chunky(10)).foregroundStyle(Ink.paper).padding(.horizontal, 4).background(Ink.red, in: Capsule()) }
                }
                .foregroundStyle(Ink.ink)
                .padding(.horizontal, 5).padding(.vertical, 3)
                .frame(maxWidth: .infinity)
                .background(Ink.paper, in: Capsule())
                .overlay(Capsule().strokeBorder(Ink.ink, lineWidth: 1.5))
            }
        }
    }

    private var selected: SkillDef {
        if let id = picked, let k = defs.first(where: { $0.id == id }) { return k }
        let pool = style == .cajones ? [tree.root] + tree.branches[drawer.rawValue] : defs
        return pool.filter { game.canGet($0) }.min { game.cost($0) < game.cost($1) } ?? (style == .cajones ? pool.last { game.isVisible($0) } ?? tree.root : tree.root)
    }

    private var panel: some View {
        let k = selected
        let l = game.level(k)
        let vis = game.isVisible(k)
        let maxed = l >= k.maxLevel
        let col = branchColor(k)
        let affordable = defs.filter { game.canGet($0) }.count
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: vis ? k.icon : "lock.fill").font(.system(size: 20, weight: .black)).foregroundStyle(col)
                    .frame(width: 40, height: 40).background(Circle().fill(col.opacity(0.18))).overlay(Circle().strokeBorder(Ink.ink, lineWidth: 2))
                VStack(alignment: .leading, spacing: 0) {
                    Text(vis ? k.name : "Bloqueada").font(.chunky(19)).foregroundStyle(Ink.ink)
                    Text(vis ? k.perText + " por nivel" : "Compra antes «\(parentName(k))»").font(.typewriter(12, bold: true)).foregroundStyle(Ink.soft)
                }
                Spacer(minLength: 4)
                Text("\(l)/\(k.maxLevel)").font(.chunky(16)).foregroundStyle(Ink.paper)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(maxed ? Ink.green : (l > 0 ? col : Ink.soft), in: Capsule())
            }
            if vis && l > 0 {
                HStack(spacing: 6) {
                    Text("Ahora: " + k.text(l)).foregroundStyle(Ink.ink)
                    if !maxed {
                        Image(systemName: "arrow.right").font(.system(size: 10, weight: .black))
                        Text(k.text(l + 1)).foregroundStyle(Ink.green)
                    }
                }
                .font(.typewriter(11, bold: true)).lineLimit(1).minimumScaleFactor(0.6)
            }
            HStack(spacing: 8) {
                if vis && !maxed {
                    Button { game.get(k) } label: {
                        Text(game.canGet(k) ? "+1 · \(game.price(k, game.cost(k)))" : "Faltan \(game.price(k, game.missing(k)))").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ChunkyButton(color: Ink.gold, size: 16, radius: 12))
                    .disabled(!game.canGet(k))
                    Button {
                        var n = 0
                        while n < 200 && game.canGet(k) { game.get(k, quiet: true); n += 1 }
                        if n > 0 { game.save(); Sound.shared.till() }
                    } label: { Text("Máx.") }
                    .buttonStyle(ChunkyButton(color: Ink.green, text: Ink.paper, size: 16, radius: 12))
                    .disabled(!game.canGet(k))
                }
                Button { buyAll() } label: { Text(affordable == 0 ? "Nada" : "Todo (\(affordable))").frame(maxWidth: vis && !maxed ? nil : .infinity) }
                    .buttonStyle(ChunkyButton(color: Ink.paper, size: 16, radius: 12))
                    .disabled(affordable == 0)
            }
        }
        .padding(12)
        .paper()
        .padding(.horizontal, 12).padding(.bottom, 8)
        .overlay(alignment: .top) {
            if bought > 0 {
                Text("+\(bought) mejoras").font(.chunky(20)).foregroundStyle(Ink.green)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .outlined(10, color: Ink.paper, shadow: 3)
                    .offset(y: -30)
                    .id(boughtKey)
                    .transition(.scale.combined(with: .opacity))
                    .task { try? await Task.sleep(nanoseconds: 1_400_000_000); withAnimation { bought = 0 } }
            }
        }
    }

    private func parentName(_ k: SkillDef) -> String {
        guard let p = tree.parent[k.id], let d = defs.first(where: { $0.id == p }) else { return "" }
        return d.name.a
    }

    private func buyAll() {
        var n = 0
        while n < 500, let k = defs.filter({ game.canGet($0) }).min(by: { game.cost($0) < game.cost($1) }) {
            game.get(k, quiet: true)
            n += 1
        }
        if n > 0 { game.save(); Sound.shared.till() }
        withAnimation(.spring) { bought = n; boughtKey += 1 }
    }
}

/// selector de la forma del árbol (arriba del árbol y en Ajustes)
struct TreeStylePicker: View {
    @Environment(Game.self) private var game
    var body: some View {
        HStack(spacing: 6) {
            ForEach(TreeStyle.allCases, id: \.rawValue) { t in
                let on = game.s.settings.treeStyle == t.rawValue
                Button {
                    Sound.shared.click()
                    withAnimation(.snappy) { game.s.settings.treeStyle = t.rawValue }
                    game.save()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: t.icon).font(.system(size: 12, weight: .black))
                        Text(t.name).font(.chunky(14)).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(on ? Ink.paper : Ink.ink)
                    .frame(maxWidth: .infinity).padding(.vertical, 6)
                    .background(Capsule().fill(on ? Ink.ink : Ink.paper))
                    .overlay(Capsule().strokeBorder(Ink.ink, lineWidth: 2))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
