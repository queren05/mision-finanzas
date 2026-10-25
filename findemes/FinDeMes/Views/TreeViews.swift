import SwiftUI

/// Dónde va cada nota: la primera mejora en el centro y una estrella de cinco rayos (uno por rama)
/// que se curvan un poco; las notas de cada rayo van en zigzag para que los largos no se alarguen tanto.
struct Galaxy {
    let size: CGSize
    let center: CGPoint
    /// centro de cada nota, por rama
    let points: [[CGPoint]]
    /// por dónde pasa el centro de cada rayo (para pintar el haz de color)
    let rays: [[CGPoint]]

    static let r0: CGFloat = 180     // distancia del centro a la primera nota de cada rayo
    static let dr: CGFloat = 64      // lo que avanza el rayo en cada nota
    static let zig: CGFloat = 44     // lo que se aparta cada nota a un lado y a otro
    static let twist: CGFloat = 0.012

    init(_ tree: SkillTree) {
        let n = CGFloat(max(1, tree.branches.count))
        func axis(_ b: Int, _ j: CGFloat) -> (CGPoint, CGFloat) {
            let r = Galaxy.r0 + j * Galaxy.dr
            let ang = -CGFloat.pi / 2 + CGFloat(b) * 2 * .pi / n + Galaxy.twist * j
            return (CGPoint(x: r * cos(ang), y: r * sin(ang)), ang)
        }
        var pts: [[CGPoint]] = [], rays: [[CGPoint]] = []
        for (b, list) in tree.branches.enumerated() {
            pts.append(list.indices.map { j in
                let (c, ang) = axis(b, CGFloat(j))
                let side: CGFloat = j % 2 == 0 ? -Galaxy.zig : Galaxy.zig
                return CGPoint(x: c.x - sin(ang) * side, y: c.y + cos(ang) * side)
            })
            rays.append([.zero] + (0...max(0, list.count - 1)).map { axis(b, CGFloat($0)).0 })
        }
        let all = pts.flatMap { $0 } + [.zero]
        let pad: CGFloat = 90
        let minX = (all.map(\.x).min() ?? 0) - pad, maxX = (all.map(\.x).max() ?? 0) + pad
        let minY = (all.map(\.y).min() ?? 0) - pad, maxY = (all.map(\.y).max() ?? 0) + pad
        size = CGSize(width: maxX - minX, height: maxY - minY)
        center = CGPoint(x: -minX, y: -minY)
        let o = center
        points = pts.map { $0.map { CGPoint(x: $0.x + o.x, y: $0.y + o.y) } }
        self.rays = rays.map { $0.map { CGPoint(x: $0.x + o.x, y: $0.y + o.y) } }
    }

    /// dónde empieza la vista (en el centro de la estrella)
    var anchor: UnitPoint { UnitPoint(x: center.x / size.width, y: center.y / size.height) }

    static let corcho = Galaxy(.corcho)
    static let family = Galaxy(.family)
}

/// El árbol de mejoras (y el familiar): notas clavadas en el corcho con chinchetas y unidas con hilo, en forma de galaxia.
struct TreeView: View {
    @Environment(Game.self) private var game
    var family = false
    @State private var picked: String? = nil
    @State private var bought = 0
    @State private var boughtKey = 0
    @State private var zoom: CGFloat = 0.72
    @State private var baseZoom: CGFloat = 0.72

    private var tree: SkillTree { family ? .family : .corcho }
    private var galaxy: Galaxy { family ? .family : .corcho }
    private var defs: [SkillDef] { family ? Content.family : Content.skills }
    private let card: CGFloat = 86

    var body: some View {
        let size = galaxy.size
        ZStack(alignment: .top) {
            CorkBackground(family: family)
            VStack(spacing: 0) {
                SheetHeader(title: family ? "Árbol familiar" : "Árbol de mejoras", subtitle: family ? "Se queda para siempre" : "Se pierde con la bancarrota")
                HStack(spacing: 10) {
                    if family { CashPill(value: "\(Fmt.num(game.s.legacy)) puntos de herencia", color: Color(hex: "#f2d58a")) }
                    else { CashPill(value: Fmt.money(game.s.cash)) }
                    Spacer()
                    Button { setZoom(zoom - 0.15) } label: { Image(systemName: "minus.magnifyingglass").font(.system(size: 16, weight: .black)) }
                        .buttonStyle(ChunkyButton(color: Ink.paper, size: 15, radius: 10))
                    Button { setZoom(zoom + 0.15) } label: { Image(systemName: "plus.magnifyingglass").font(.system(size: 16, weight: .black)) }
                        .buttonStyle(ChunkyButton(color: Ink.paper, size: 15, radius: 10))
                }
                .padding(.horizontal, 16).padding(.bottom, 8)
                legend.padding(.horizontal, 10).padding(.bottom, 4)
                ScrollView([.horizontal, .vertical]) {
                    ZStack(alignment: .topLeading) {
                        Canvas { ctx, _ in drawBoard(ctx) }
                            .frame(width: size.width, height: size.height)
                        note(tree.root, root: true).position(galaxy.center)
                        ForEach(tree.branches.indices, id: \.self) { b in
                            ForEach(tree.branches[b].indices, id: \.self) { j in
                                note(tree.branches[b][j]).position(galaxy.points[b][j])
                            }
                        }
                    }
                    .frame(width: size.width, height: size.height)
                    .scaleEffect(zoom, anchor: .topLeading)
                    .frame(width: size.width * zoom, height: size.height * zoom, alignment: .topLeading)
                }
                .defaultScrollAnchor(galaxy.anchor)
                .scrollIndicators(.hidden)
                .simultaneousGesture(
                    MagnifyGesture()
                        .onChanged { v in zoom = min(1.4, max(0.35, baseZoom * v.magnification)) }
                        .onEnded { _ in baseZoom = zoom }
                )
                panel
            }
        }
    }

    private func setZoom(_ z: CGFloat) {
        Sound.shared.click()
        withAnimation(.snappy) { zoom = min(1.4, max(0.35, z)) }
        baseZoom = zoom
    }

    // MARK: el corcho: estrella a lápiz e hilos

    private func pin(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x, y: p.y - card / 2 + 4) }

    private func drawBoard(_ ctx: GraphicsContext) {
        let c = galaxy.center
        let pencil = Ink.ink.opacity(0.22)
        // los rayos de la estrella: un haz de color muy suave detrás de cada rama
        for (b, ray) in galaxy.rays.enumerated() where ray.count > 1 {
            var p = Path()
            p.addLines(ray)
            let col = Branch(rawValue: b)!.color
            ctx.stroke(p, with: .color(col.opacity(0.13)), style: StrokeStyle(lineWidth: 190, lineCap: .round, lineJoin: .round))
            ctx.stroke(p, with: .color(Ink.paper.opacity(0.10)), style: StrokeStyle(lineWidth: 120, lineCap: .round, lineJoin: .round))
        }
        // estrella de cinco puntas dibujada a lápiz detrás de la primera nota, cada punta hacia su rayo
        var star = Path()
        for i in 0..<10 {
            let r: CGFloat = i % 2 == 0 ? Galaxy.r0 - 50 : Galaxy.r0 * 0.36
            let ang = -CGFloat.pi / 2 + CGFloat(i) * .pi / 5
            let p = CGPoint(x: c.x + r * cos(ang), y: c.y + r * sin(ang))
            if i == 0 { star.move(to: p) } else { star.addLine(to: p) }
        }
        star.closeSubpath()
        ctx.fill(star, with: .color(Ink.paper.opacity(0.35)))
        ctx.stroke(star, with: .color(pencil), style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
        ctx.stroke(star.applying(CGAffineTransform(translationX: 2, y: -1.5)), with: .color(pencil.opacity(0.6)), style: StrokeStyle(lineWidth: 1.2, lineJoin: .round))

        // hilos: de la chincheta de la anterior a la chincheta de cada nota, colgando un poco
        for (b, list) in tree.branches.enumerated() {
            let col = Branch(rawValue: b)!.color
            for j in list.indices {
                let k = list[j]
                let from = j == 0 ? pin(c) : pin(galaxy.points[b][j - 1])
                let to = pin(galaxy.points[b][j])
                var p = Path()
                p.move(to: from)
                p.addQuadCurve(to: to, control: CGPoint(x: (from.x + to.x) / 2, y: max(from.y, to.y) + 16))
                let bought = game.level(k) > 0
                let open = game.isVisible(k)
                if bought {
                    ctx.stroke(p.applying(CGAffineTransform(translationX: 1.5, y: 3)), with: .color(Ink.ink.opacity(0.3)), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    ctx.stroke(p, with: .color(Ink.ink), style: StrokeStyle(lineWidth: 5.5, lineCap: .round))
                    ctx.stroke(p, with: .color(col), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
                } else if open {
                    ctx.stroke(p, with: .color(col.opacity(0.8)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [7, 6]))
                } else {
                    ctx.stroke(p, with: .color(Ink.ink.opacity(0.2)), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, dash: [3, 6]))
                }
            }
        }
    }

    // MARK: cada nota

    private func branchColor(_ k: SkillDef) -> Color { k.id == tree.root.id ? Ink.red : Branch.of(k.effect).color }

    /// inclinación fija para cada nota (no cambia entre aperturas)
    private func tilt(_ k: SkillDef) -> Double {
        let h = k.id.unicodeScalars.reduce(0) { $0 &* 31 &+ Int($1.value) }
        return Double(abs(h) % 7) - 3
    }

    @ViewBuilder
    private func note(_ k: SkillDef, root: Bool = false) -> some View {
        let l = game.level(k)
        let vis = game.isVisible(k)
        let can = game.canGet(k)
        let maxed = l >= k.maxLevel
        let col = branchColor(k)
        let sel = picked == k.id
        let size = root ? card + 18 : (vis ? card : card - 22)
        ZStack(alignment: .top) {
            Group {
                if vis {
                    VStack(spacing: 2) {
                        Image(systemName: k.icon)
                            .font(.system(size: root ? 26 : 21, weight: .black))
                            .foregroundStyle(l > 0 ? col : Ink.ink)
                            .padding(.top, 13)
                        Text(k.name).font(.chunky(root ? 14 : 12)).foregroundStyle(Ink.ink)
                            .lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.7)
                        Spacer(minLength: 0)
                        HStack(spacing: 3) {
                            Text("\(l)/\(k.maxLevel)")
                                .font(.typewriter(10, bold: true)).foregroundStyle(Ink.paper)
                                .padding(.horizontal, 4).padding(.vertical, 1)
                                .background(maxed ? Ink.green : (l > 0 ? col : Ink.soft), in: Capsule())
                            if !maxed {
                                Text(game.price(k, game.cost(k)))
                                    .font(.typewriter(10, bold: true)).foregroundStyle(can ? Ink.ink : Ink.soft)
                                    .lineLimit(1).minimumScaleFactor(0.6)
                            }
                        }
                    }
                    .padding(.horizontal, 5).padding(.bottom, 7)
                } else {
                    Image(systemName: "questionmark").font(.system(size: 20, weight: .black)).foregroundStyle(Ink.soft)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: size, height: size)
            .paper(can ? Color(hex: "#fff6c8") : (vis ? Ink.paper : Ink.paperDark), tilt: tilt(k), shadow: vis ? 4 : 2)
            .overlay {
                if maxed { Stamp(text: "MÁX.", color: Ink.green).scaleEffect(0.6).offset(x: 18, y: 4) }
            }
            .overlay {
                if sel { Rectangle().strokeBorder(Ink.gold, lineWidth: 4).rotationEffect(.degrees(tilt(k))).padding(-5) }
            }
            .opacity(vis ? 1 : 0.75)
            // chincheta
            Circle().fill(can ? Ink.gold : col)
                .frame(width: 15, height: 15)
                .overlay(Circle().fill(.white.opacity(0.55)).frame(width: 5, height: 5).offset(x: -2, y: -2))
                .overlay(Circle().strokeBorder(Ink.ink, lineWidth: 2))
                .offset(y: -6)
        }
        .scaleEffect(sel ? 1.08 : 1)
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
