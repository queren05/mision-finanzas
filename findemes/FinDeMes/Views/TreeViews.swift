import SwiftUI

/// El árbol de mejoras: cinco columnas de diez notas clavadas en el corcho, unidas con hilo, de abajo arriba.
struct TreeView: View {
    @Environment(Game.self) private var game
    @State private var picked: String? = nil
    @State private var bought = 0
    @State private var boughtKey = 0

    private var tree: SkillTree { .main }
    private var defs: [SkillDef] { Content.skills }

    var body: some View {
        ZStack(alignment: .top) {
            CorkBackground()
            VStack(spacing: 0) {
                SheetHeader(title: "Árbol de mejoras", subtitle: "Se pierde con la bancarrota")
                CashPill(value: Fmt.money(game.s.cash)).padding(.bottom, 8)
                legend.padding(.horizontal, 10).padding(.bottom, 4)
                columns
                panel
            }
        }
    }

    private let cell: CGFloat = 92

    // MARK: cinco columnas, una por color, de abajo arriba (todas con las mismas notas: las filas cuadran)

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
                CGPoint(x: colW * (CGFloat(b) + 0.5), y: h - 200 - CGFloat(j) * rowH)
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
        // la dorada, solo en la mejor compra de ahora
        let best = game.bestSkill(defs) == k.id
        return Circle().fill(best ? Ink.gold : branchColor(k))
            .frame(width: best ? 19 : 15, height: best ? 19 : 15)
            .overlay(Circle().fill(.white.opacity(0.6)).frame(width: best ? 7 : 5, height: best ? 7 : 5).offset(x: -2, y: -2))
            .overlay(Circle().strokeBorder(Ink.ink, lineWidth: 2))
            .background { if best { GoldGlow() } }
            .offset(y: -6)
    }

    /// la marca de la rama en la esquina (estrella, euro, corazón, rejilla o rayo)
    private func branchMark(_ k: SkillDef) -> some View {
        let b = Branch.of(k.effect)
        return Image(systemName: b.icon).font(.system(size: 8, weight: .black)).foregroundStyle(b.color)
            .padding(.top, 5).padding(.trailing, 5)
            .rotationEffect(.degrees(tilt(k)))
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

    /// nota cuadrada: el icono suelto, el nombre, el nivel y el precio; abajo a la derecha, la marca de su rama
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
                                Text(Fmt.money(game.cost(k)))
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
            .overlay(alignment: .topTrailing) { if vis && k.id != tree.root.id { branchMark(k) } }
            .opacity(vis ? 1 : 0.8)
            chincheta(k)
        }
        .scaleEffect(sel ? 1.08 : 1)
        .phaseAnimator([0.0, can ? 1.0 : 0.0]) { v, a in v.scaleEffect(1 + a * 0.05) } animation: { _ in .easeInOut(duration: 0.7) }
        .contentShape(Rectangle())
        .onTapGesture { tap(k) }
    }

    // MARK: arriba y abajo

    private var legend: some View {
        HStack(spacing: 4) {
            ForEach(Branch.allCases, id: \.rawValue) { b in
                let n = tree.branches[b.rawValue].filter { game.canGet($0) }.count
                HStack(spacing: 3) {
                    Image(systemName: b.icon).font(.system(size: 9, weight: .black)).foregroundStyle(b.color)
                    Text(b.name.a).font(.typewriter(10, bold: true)).lineLimit(1).minimumScaleFactor(0.6)
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
                        Text(game.canGet(k) ? "+1 · \(Fmt.money(game.cost(k)))" : "Faltan \(Fmt.money(game.missing(k)))").frame(maxWidth: .infinity)
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
