import SwiftUI

/// El árbol de mejoras (y el familiar): un tronco abajo y cinco ramas que crecen hacia arriba, una por color.
struct TreeView: View {
    @Environment(Game.self) private var game
    var family = false
    @State private var picked: String? = nil
    @State private var bought = 0
    @State private var boughtKey = 0

    private var tree: SkillTree { family ? .family : .corcho }
    private var defs: [SkillDef] { family ? Content.family : Content.skills }
    private let rowH: CGFloat = 100
    private let node: CGFloat = 58
    private let base: CGFloat = 170

    var body: some View {
        let longest = tree.branches.map(\.count).max() ?? 0
        ZStack(alignment: .top) {
            CorkBackground(family: family)
            VStack(spacing: 0) {
                SheetHeader(title: family ? "Árbol familiar" : "Árbol de mejoras", subtitle: family ? "Se queda para siempre" : "Se pierde con la bancarrota")
                Group {
                    if family { CashPill(value: "\(Fmt.num(game.s.legacy)) puntos de herencia", color: Color(hex: "#f2d58a")) }
                    else { CashPill(value: Fmt.money(game.s.cash)) }
                }
                .padding(.bottom, 6)
                legend.padding(.horizontal, 10).padding(.bottom, 4)
                GeometryReader { g in
                    let w = g.size.width
                    let h = CGFloat(longest) * rowH + base + 40
                    ScrollView(.vertical) {
                        ZStack(alignment: .topLeading) {
                            Canvas { ctx, _ in drawTree(ctx, w: w, h: h) }
                                .frame(width: w, height: h)
                            nodeView(tree.root).position(rootPos(w, h))
                            ForEach(tree.branches.indices, id: \.self) { b in
                                ForEach(tree.branches[b].indices, id: \.self) { j in
                                    nodeView(tree.branches[b][j]).position(pos(b, j, w, h))
                                }
                            }
                        }
                        .frame(width: w, height: h)
                    }
                    .defaultScrollAnchor(.bottom)
                    .scrollIndicators(.hidden)
                }
                panel
            }
        }
    }

    // MARK: dibujo

    private func colX(_ b: Int, _ w: CGFloat) -> CGFloat { w * (CGFloat(b) + 0.5) / CGFloat(Branch.allCases.count) }
    private func rootPos(_ w: CGFloat, _ h: CGFloat) -> CGPoint { CGPoint(x: w / 2, y: h - 62) }
    private func pos(_ b: Int, _ j: Int, _ w: CGFloat, _ h: CGFloat) -> CGPoint {
        CGPoint(x: colX(b, w), y: h - base - CGFloat(j) * rowH)
    }

    private func drawTree(_ ctx: GraphicsContext, w: CGFloat, h: CGFloat) {
        let wood = Color(hex: "#7a4a2a"), woodLight = Color(hex: "#9a6438")
        // el tronco
        var trunk = Path()
        trunk.move(to: CGPoint(x: w / 2 - 26, y: h))
        trunk.addQuadCurve(to: CGPoint(x: w / 2 - 12, y: h - 120), control: CGPoint(x: w / 2 - 10, y: h - 50))
        trunk.addLine(to: CGPoint(x: w / 2 + 12, y: h - 120))
        trunk.addQuadCurve(to: CGPoint(x: w / 2 + 26, y: h), control: CGPoint(x: w / 2 + 10, y: h - 50))
        trunk.closeSubpath()
        ctx.fill(trunk, with: .color(woodLight))
        ctx.stroke(trunk, with: .color(Ink.ink), lineWidth: 3)
        for (b, list) in tree.branches.enumerated() {
            guard !list.isEmpty else { continue }
            let x = colX(b, w)
            let start = CGPoint(x: w / 2, y: h - 110)
            let first = pos(b, 0, w, h)
            let last = pos(b, list.count - 1, w, h)
            var p = Path()
            p.move(to: start)
            p.addQuadCurve(to: first, control: CGPoint(x: x, y: start.y))
            p.addLine(to: last)
            ctx.stroke(p, with: .color(Ink.ink), style: StrokeStyle(lineWidth: 13, lineCap: .round, lineJoin: .round))
            ctx.stroke(p, with: .color(wood), style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
            // lo comprado se pinta del color de la rama
            let top = list.lastIndex { game.level($0) > 0 }
            if let top {
                var lit = Path()
                lit.move(to: start)
                lit.addQuadCurve(to: first, control: CGPoint(x: x, y: start.y))
                lit.addLine(to: pos(b, top, w, h))
                ctx.stroke(lit, with: .color(Branch(rawValue: b)!.color), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            }
            // hojitas a los lados
            for j in 0..<list.count {
                let c = pos(b, j, w, h)
                let side: CGFloat = j % 2 == 0 ? 1 : -1
                let leaf = Path(ellipseIn: CGRect(x: c.x + side * 18 - 7, y: c.y + rowH / 2 - 5, width: 14, height: 9))
                ctx.fill(leaf, with: .color(Color(hex: "#5fa04a")))
                ctx.stroke(leaf, with: .color(Ink.ink), lineWidth: 1.5)
            }
        }
    }

    private func branchColor(_ k: SkillDef) -> Color { k.id == tree.root.id ? Ink.wood : Branch.of(k.effect).color }

    private func nodeView(_ k: SkillDef) -> some View {
        let l = game.level(k)
        let vis = game.isVisible(k)
        let can = game.canGet(k)
        let maxed = l >= k.maxLevel
        let col = branchColor(k)
        let sel = picked == k.id
        return VStack(spacing: 1) {
            ZStack {
                Circle().fill(vis ? (l > 0 ? col.opacity(0.22) : Ink.paper) : Ink.paperDark)
                Circle()
                    .trim(from: 0, to: CGFloat(l) / CGFloat(max(1, k.maxLevel)))
                    .stroke(col, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(4)
                Circle().strokeBorder(can ? Ink.gold : Ink.ink, lineWidth: can ? 4 : 3)
                Image(systemName: vis ? k.icon : "lock.fill")
                    .font(.system(size: 21, weight: .black))
                    .foregroundStyle(vis ? (l > 0 ? col : Ink.ink) : Ink.soft)
                if maxed {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 18, weight: .black)).foregroundStyle(Ink.green)
                        .background(Circle().fill(Ink.paper)).offset(x: 22, y: -22)
                }
            }
            .frame(width: node, height: node)
            .background(Circle().fill(Ink.ink).offset(x: 2, y: 3))
            .scaleEffect(sel ? 1.15 : 1)
            Text(vis ? k.name : "???")
                .font(.chunky(11)).foregroundStyle(Ink.ink)
                .lineLimit(1).minimumScaleFactor(0.6)
                .padding(.horizontal, 4)
                .background(Ink.paper.opacity(0.9), in: Capsule())
                .frame(width: 76)
            if vis {
                Text(maxed ? "MÁX." : game.price(k, game.cost(k)))
                    .font(.typewriter(10, bold: true))
                    .foregroundStyle(maxed ? Ink.green : (can ? Ink.ink : Ink.soft))
                    .padding(.horizontal, 4)
                    .background(can ? Color(hex: "#fff6c8") : Ink.paper.opacity(0.8), in: Capsule())
            }
        }
        .phaseAnimator([0.0, can ? 1.0 : 0.0]) { v, a in v.scaleEffect(1 + a * 0.05) } animation: { _ in .easeInOut(duration: 0.7) }
        .contentShape(Rectangle())
        .onTapGesture {
            // tocar compra al momento y enseña abajo qué hace
            withAnimation(.snappy) { picked = k.id }
            if game.canGet(k) { game.get(k) } else { Sound.shared.click() }
        }
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
        return defs.filter { game.canGet($0) }.min { game.cost($0) < game.cost($1) } ?? tree.root
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
