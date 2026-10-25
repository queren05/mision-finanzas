import SpriteKit
import SwiftUI

// La mesa dibujada con SpriteKit (con la gráfica del iPhone): la simulación sigue en `Desk`
// y aquí solo se colocan los dibujos en su sitio en cada fotograma.

/// texturas hechas una sola vez (texto con borde, pedazos, sombras, anillos…)
@MainActor
enum Tex {
    private static var cache: [String: SKTexture] = [:]
    private static var texts = 0

    static func cached(_ key: String, _ make: () -> UIImage?) -> SKTexture? {
        if let t = cache[key] { return t }
        guard let img = make() else { return nil }
        let t = SKTexture(image: img)
        cache[key] = t
        return t
    }

    static func draw(_ size: CGSize, _ body: (CGContext) -> Void) -> UIImage {
        let f = UIGraphicsImageRendererFormat()
        f.scale = 3
        return UIGraphicsImageRenderer(size: size, format: f).image { body($0.cgContext) }
    }

    static func key(_ c: UIColor) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return "\(Int(r * 255)),\(Int(g * 255)),\(Int(b * 255))"
    }

    static let ink = UIColor(Ink.ink)

    /// texto gordo con borde de tinta
    static func text(_ s: String, _ size: CGFloat, _ color: UIColor) -> SKTexture {
        let k = "t|\(s)|\(Int(size))|\(key(color))"
        if let t = cache[k] { return t }
        texts += 1
        if texts > 300 {
            // que no crezca sin fin con tantos importes distintos
            for key in cache.keys where key.hasPrefix("t|") { cache[key] = nil }
            texts = 0
        }
        let font = UIFont(name: "LilitaOne", size: size) ?? .boldSystemFont(ofSize: size)
        let str = s as NSString
        let base = str.size(withAttributes: [.font: font])
        let pad: CGFloat = 5
        let img = draw(CGSize(width: ceil(base.width) + pad * 2, height: ceil(base.height) + pad * 2 + 2)) { _ in
            let inkA: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: ink]
            for (dx, dy) in [(-2.5, 0.0), (2.5, 0), (0, -2.5), (0, 2.5), (-1.8, -1.8), (1.8, -1.8), (-1.8, 1.8), (1.8, 1.8), (2, 3.5)] {
                str.draw(at: CGPoint(x: pad + dx, y: pad + dy), withAttributes: inkA)
            }
            str.draw(at: CGPoint(x: pad, y: pad), withAttributes: [.font: font, .foregroundColor: color])
        }
        let t = SKTexture(image: img)
        cache[k] = t
        return t
    }

    static func shard(_ color: UIColor, _ variant: Int) -> SKTexture? {
        cached("sh|\(key(color))|\(variant)") {
            draw(CGSize(width: 48, height: 48)) { c in
                let r = 20.0
                let rots = [0.0, 0.7, 1.9]
                var pts: [CGPoint] = []
                for k in 0..<3 {
                    let b = Double(k) / 3 * 2 * .pi + rots[variant % 3] + (k == 1 ? 0.35 : -0.2)
                    pts.append(CGPoint(x: 24 + cos(b) * r, y: 24 + sin(b) * r))
                }
                c.addLines(between: pts); c.closePath()
                c.setFillColor(color.cgColor); c.setStrokeColor(ink.cgColor); c.setLineWidth(3); c.setLineJoin(.round)
                c.drawPath(using: .fillStroke)
            }
        }
    }

    static var shadow: SKTexture? {
        cached("shadow") {
            draw(CGSize(width: 100, height: 24)) { c in
                c.setFillColor(UIColor.black.withAlphaComponent(0.22).cgColor)
                c.fillEllipse(in: CGRect(x: 0, y: 0, width: 100, height: 24))
            }
        }
    }

    static func ring(_ color: UIColor, width: CGFloat) -> SKTexture? {
        cached("ring|\(key(color))|\(width)") {
            draw(CGSize(width: 220, height: 140)) { c in
                c.setStrokeColor(color.cgColor); c.setLineWidth(width); c.setLineDash(phase: 0, lengths: [12, 14])
                c.strokeEllipse(in: CGRect(x: 6, y: 6, width: 208, height: 128))
            }
        }
    }

    static var impact: SKTexture? {
        cached("impact") {
            draw(CGSize(width: 220, height: 140)) { c in
                c.setStrokeColor(ink.cgColor); c.setLineWidth(5); c.setLineCap(.round)
                for a in stride(from: 0.0, to: 2 * .pi, by: .pi / 4) {
                    c.move(to: CGPoint(x: 110 + cos(a) * 55, y: 70 + sin(a) * 38))
                    c.addLine(to: CGPoint(x: 110 + cos(a) * 94, y: 70 + sin(a) * 60))
                }
                c.strokePath()
            }
        }
    }

    static var blast: SKTexture? {
        cached("blast") {
            draw(CGSize(width: 200, height: 200)) { c in
                c.setFillColor(UIColor(Ink.gold).withAlphaComponent(0.5).cgColor)
                c.fillEllipse(in: CGRect(x: 4, y: 4, width: 192, height: 192))
                c.setStrokeColor(ink.cgColor); c.setLineWidth(6)
                c.strokeEllipse(in: CGRect(x: 4, y: 4, width: 192, height: 192))
            }
        }
    }

    static var crown: SKTexture? {
        cached("crown") {
            draw(CGSize(width: 90, height: 50)) { c in
                var pts = [CGPoint(x: 5, y: 45)]
                for k in 0..<7 { pts.append(CGPoint(x: 5 + Double(k) * 80 / 6, y: k % 2 == 1 ? 32 : 5)) }
                pts.append(CGPoint(x: 85, y: 45))
                c.addLines(between: pts); c.closePath()
                c.setFillColor(UIColor(Ink.gold).cgColor); c.setStrokeColor(ink.cgColor); c.setLineWidth(4); c.setLineJoin(.round)
                c.drawPath(using: .fillStroke)
                c.setFillColor(UIColor(Ink.red).cgColor)
                for k in [1, 3, 5] { c.fillEllipse(in: CGRect(x: 5 + Double(k) * 80 / 6 - 5, y: 30, width: 10, height: 10)) }
            }
        }
    }

    static var fuse: SKTexture? {
        cached("fuse") {
            draw(CGSize(width: 50, height: 50)) { c in
                c.setLineCap(.round)
                c.move(to: CGPoint(x: 30, y: 46)); c.addQuadCurve(to: CGPoint(x: 12, y: 10), control: CGPoint(x: 44, y: 14))
                c.setStrokeColor(ink.cgColor); c.setLineWidth(8); c.strokePath()
                c.move(to: CGPoint(x: 30, y: 46)); c.addQuadCurve(to: CGPoint(x: 12, y: 10), control: CGPoint(x: 44, y: 14))
                c.setStrokeColor(UIColor(Color(hex: "#c9a26b")).cgColor); c.setLineWidth(4); c.strokePath()
            }
        }
    }

    static var flame: SKTexture? {
        cached("flame") {
            draw(CGSize(width: 30, height: 30)) { c in
                c.setFillColor(UIColor(Ink.gold).cgColor); c.fillEllipse(in: CGRect(x: 1, y: 1, width: 28, height: 28))
                c.setFillColor(UIColor(Ink.red).cgColor); c.fillEllipse(in: CGRect(x: 8, y: 8, width: 14, height: 14))
            }
        }
    }

    static var skate: SKTexture? {
        cached("skate") {
            draw(CGSize(width: 120, height: 34)) { c in
                c.setFillColor(ink.cgColor)
                for x in [24.0, 96.0] { c.fillEllipse(in: CGRect(x: x - 10, y: 12, width: 20, height: 20)) }
                c.setFillColor(UIColor.gray.cgColor)
                for x in [24.0, 96.0] { c.fillEllipse(in: CGRect(x: x - 5, y: 17, width: 10, height: 10)) }
                let board = UIBezierPath(roundedRect: CGRect(x: 2, y: 4, width: 116, height: 12), cornerRadius: 6)
                c.addPath(board.cgPath)
                c.setFillColor(UIColor(Color(hex: "#d9573b")).cgColor); c.setStrokeColor(ink.cgColor); c.setLineWidth(3)
                c.drawPath(using: .fillStroke)
            }
        }
    }

    static func pig(_ skin: SkinDef, _ kind: PigKind) -> SKTexture? {
        if skin.drawn {
            return cached("pigd|\(kind.rawValue)") {
                let r = ImageRenderer(content: PigIcon(size: 160, kind: kind))
                r.scale = 2
                return r.uiImage
            }
        }
        return cached("pig|\(skin.id)|\(kind.look)") { SkinArt.uiImage(skin.id, kind.look) }
    }

    static func item(_ name: String, ext: String = "png") -> SKTexture? {
        cached("item|\(name)") { ItemArt.uiImage(name, ext: ext) }
    }
}

/// una hucha en pantalla
final class PigNode: SKNode {
    let body = SKSpriteNode()
    let shadow = SKSpriteNode()
    let bar = SKNode()
    let barFill = SKSpriteNode(color: UIColor(Ink.red), size: CGSize(width: 1, height: 9))
    var cracks: SKShapeNode? = nil
    var crackCount = 0
    var flame: SKSpriteNode? = nil
}

final class DeskScene: SKScene {
    let desk: Desk
    private let world = SKNode()
    private let bg = SKSpriteNode()
    private var pigNodes: [Int: PigNode] = [:]
    private var shardNodes: [SKSpriteNode] = []
    private var lootNodes: [SKSpriteNode] = []
    private var floaterNodes: [SKSpriteNode] = []
    private var floaterKeys: [String] = []
    private var ringNodes: [SKSpriteNode] = []
    private var impactNodes: [SKSpriteNode] = []
    private var hammerNodes: [SKSpriteNode] = []
    private var blastNodes: [SKSpriteNode] = []
    private let comboNode = SKSpriteNode()
    private let multNode = SKSpriteNode()
    private let comboBar = SKSpriteNode(color: UIColor(Ink.paper), size: CGSize(width: 90, height: 5))
    private let frenzyTint = SKSpriteNode(color: UIColor(Ink.gold), size: CGSize(width: 10, height: 10))
    private let frenzyBack = SKSpriteNode(color: UIColor(Ink.ink), size: CGSize(width: 10, height: 16))
    private let frenzyFill = SKSpriteNode(color: UIColor(Ink.red), size: CGSize(width: 10, height: 10))
    private let tutRing = SKSpriteNode()
    private let tutText = SKSpriteNode()
    private let tutHand = SKSpriteNode()
    private let tutLow1 = SKSpriteNode()
    private let tutLow2 = SKSpriteNode()
    private var lastCombo = -1
    private let happNode = SKSpriteNode()
    private var lastHapp = ""
    private var lastComboColor = ""

    @MainActor
    init(desk: Desk) {
        self.desk = desk
        super.init(size: CGSize(width: 390, height: 844))
        scaleMode = .resizeFill
        backgroundColor = UIColor(Ink.wood)
        anchorPoint = .zero
        addChild(world)
        bg.zPosition = -1000
        bg.texture = Tex.item("mesa", ext: "jpg")
        world.addChild(bg)
        happNode.zPosition = 620
        for n in [happNode, comboNode, multNode, comboBar, frenzyTint, frenzyBack, frenzyFill, tutRing, tutText, tutHand, tutLow1, tutLow2] {
            n.isHidden = true
            addChild(n)
        }
        frenzyTint.zPosition = 550; frenzyTint.anchorPoint = .zero
        frenzyBack.zPosition = 600; frenzyFill.zPosition = 601; frenzyFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        comboNode.zPosition = 620; multNode.zPosition = 620; comboBar.zPosition = 620
        for n in [tutRing, tutText, tutHand, tutLow1, tutLow2] { n.zPosition = 700 }
        tutRing.texture = Tex.ring(UIColor(Ink.paper), width: 5)
        tutText.texture = Tex.text("¡Toca aquí!", 28, UIColor(Ink.paper))
        tutHand.texture = Tex.text("👆", 44, .white)
        tutLow1.texture = Tex.text("Junta varias en cada golpe", 22, UIColor(Ink.paper))
        tutLow2.texture = Tex.text("Cada golpe gasta aguante ↓", 22, UIColor(Ink.gold))
        for n in [tutText, tutHand, tutLow1, tutLow2] { if let t = n.texture { n.size = CGSize(width: t.size().width, height: t.size().height) } }
    }
    required init?(coder: NSCoder) { fatalError() }

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = true
        layoutBackground()
    }
    override func didChangeSize(_ oldSize: CGSize) { layoutBackground() }

    private func layoutBackground() {
        let w = size.width, h = size.height
        let k = max((w + 40) / 1179, (h + 40) / 2556)
        bg.size = CGSize(width: 1179 * k, height: 2556 * k)
        bg.position = CGPoint(x: w / 2, y: h / 2)
        frenzyTint.size = CGSize(width: w + 40, height: h + 40)
        frenzyTint.position = CGPoint(x: -20, y: -20)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let h = size.height
        let pts = touches.map { $0.location(in: self) }
        MainActor.assumeIsolated {
            for p in pts { desk.tap(CGPoint(x: p.x, y: h - p.y)) }
        }
    }

    override func update(_ currentTime: TimeInterval) {
        let sz = size
        MainActor.assumeIsolated {
            desk.frame(Date(), size: sz)
            sync()
        }
    }

    /// de coordenadas de la mesa (y hacia abajo) a las de SpriteKit (y hacia arriba)
    @inline(__always) private func P(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: size.height - y) }

    // MARK: - Colocar todo

    @MainActor private func sync() {
        let sh = desk.shake
        world.position = sh > 0.3 ? CGPoint(x: Double.random(in: -sh...sh), y: Double.random(in: -sh...sh)) : .zero
        syncPigs()
        syncShards()
        syncLoot()
        syncSwings()
        syncBlasts()
        syncFloaters()
        syncHUD()
        syncTutorial()
    }

    @MainActor private func syncPigs() {
        let t = desk.time
        let skin = desk.skin
        var alive = Set<Int>()
        for p in desk.pigs {
            alive.insert(p.id)
            let n = pigNodes[p.id] ?? makePig(p)
            let s = p.size
            let age = t - p.born
            let pop = age < 0.3 ? max(0.01, 1 + 0.25 * sin(age / 0.3 * .pi) - (1 - age / 0.3) * (1 - age / 0.3) * 0.9) : 1
            let h = t - p.hitAt
            let sq = h < 0.35 ? exp(-h * 12) * cos(h * 40) * 0.22 : 0
            let (dw, dh) = dims(p)
            let wheels = p.kind == .ruedas
            let moving = hypot(p.vel.dx, p.vel.dy) > 2 && h > 0.3
            let ph = t * (p.kind == .bomba ? 11 : 8.5) + Double(p.id) * 1.7
            let up = abs(sin(ph))
            let hop = (wheels || !moving) ? 0 : up * s * 0.14
            let land = (!wheels && moving) ? max(0, 0.22 - up) * 0.4 : 0
            let breathe = moving ? 0 : sin(t * 3 + Double(p.id)) * 0.025
            let tilt = wheels ? -0.05 : (moving ? cos(ph) * 0.08 : 0)
            let feet = p.pos.y + s * 0.42

            n.position = P(p.pos.x, feet - hop)
            n.zPosition = CGFloat(p.pos.y / 10)
            n.zRotation = -tilt * p.facing
            n.xScale = p.facing * pop * (1 + sq + land)
            n.yScale = pop * (1 - sq - land + breathe)

            let sw = dw * 0.62 * pop * (1 - hop / s * 1.6)
            n.shadow.position = P(p.pos.x, feet + (wheels ? s * 0.12 : 0))
            n.shadow.size = CGSize(width: max(1, sw), height: max(1, sw * 0.22))

            // destello al golpear y colores especiales
            if h < 0.08 {
                n.body.color = .white; n.body.colorBlendFactor = 0.6
            } else {
                switch p.kind {
                case .arcoiris:
                    n.body.color = UIColor(hue: (t * 0.45 + Double(p.id) * 0.1).truncatingRemainder(dividingBy: 1), saturation: 0.85, brightness: 1, alpha: 1)
                    n.body.colorBlendFactor = 0.5
                case .diamante:
                    n.body.color = UIColor(red: 0.55, green: 0.9, blue: 1, alpha: 1); n.body.colorBlendFactor = 0.3
                case .lava:
                    n.body.color = UIColor(red: 1, green: 0.35 + 0.15 * sin(t * 6 + Double(p.id)), blue: 0.1, alpha: 1); n.body.colorBlendFactor = 0.55
                case .cosmica:
                    n.body.color = UIColor(hue: 0.72 + 0.08 * sin(t * 2 + Double(p.id)), saturation: 0.8, brightness: 0.9, alpha: 1); n.body.colorBlendFactor = 0.55
                case .hielo:
                    n.body.color = UIColor(red: 0.7, green: 0.95, blue: 1, alpha: 1); n.body.colorBlendFactor = 0.45
                case .suerte:
                    n.body.color = UIColor(red: 0.35, green: 0.85, blue: 0.4, alpha: 1); n.body.colorBlendFactor = 0.5
                case .zombi:
                    n.body.color = UIColor(red: 0.55, green: 0.7, blue: 0.45, alpha: 1); n.body.colorBlendFactor = 0.55
                case .robot:
                    n.body.color = UIColor(red: 0.5, green: 0.75, blue: 1, alpha: 1); n.body.colorBlendFactor = 0.3
                default:
                    n.body.colorBlendFactor = 0
                }
            }
            n.body.alpha = p.kind == .fantasma ? 0.45 + 0.15 * sin(t * 4 + Double(p.id)) : 1
            n.flame?.setScale(0.8 + 0.3 * sin(t * 30))

            // grietas: se dibujan solo cuando sale una nueva
            if p.cracks.count != n.crackCount {
                n.crackCount = p.cracks.count
                let path = CGMutablePath()
                for crack in p.cracks {
                    for (k, pt) in crack.enumerated() {
                        let q = CGPoint(x: pt.x * s * 0.9, y: -(pt.y * s * 0.75 - s * 0.42))
                        if k == 0 { path.move(to: q) } else { path.addLine(to: q) }
                    }
                }
                if n.cracks == nil {
                    let c = SKShapeNode()
                    c.strokeColor = Tex.ink
                    c.lineWidth = max(1.8, s * 0.034)
                    c.lineCap = .round; c.lineJoin = .round
                    c.zPosition = 2
                    n.addChild(c)
                    n.cracks = c
                }
                n.cracks?.path = path
            }

            // vida
            if p.hp < p.maxHP {
                n.bar.isHidden = false
                n.bar.position = P(p.pos.x, feet - hop - dh * pop - 16)
                n.barFill.size = CGSize(width: max(0.5, max(50, s * 0.8) * max(0, p.hp / p.maxHP)), height: 7)
            }
        }
        for (id, n) in pigNodes where !alive.contains(id) {
            n.shadow.removeFromParent(); n.bar.removeFromParent(); n.removeFromParent()
            pigNodes[id] = nil
        }
        _ = skin
    }

    @MainActor private func dims(_ p: Desk.Pig) -> (Double, Double) {
        let skin = desk.skin
        let s = p.size
        var dw = s * 1.5
        var dh = dw * skin.h / skin.w
        if skin.drawn { dw = s * 1.25; dh = dw }
        if dh > s * 1.35 { dh = s * 1.35; dw = dh * skin.w / skin.h }
        return (dw, dh)
    }

    @MainActor private func makePig(_ p: Desk.Pig) -> PigNode {
        let n = PigNode()
        let skin = desk.skin
        let s = p.size
        let (dw, dh) = dims(p)
        n.body.texture = Tex.pig(skin, p.kind)
        n.body.size = CGSize(width: dw, height: dh)
        n.body.anchorPoint = CGPoint(x: 0.5, y: 0)
        n.body.position = CGPoint(x: 0, y: p.kind == .ruedas ? 0 : -s * 0.02)
        n.addChild(n.body)
        n.shadow.texture = Tex.shadow
        n.shadow.zPosition = -500
        world.addChild(n.shadow)

        // cabeza (para la corona y la mecha)
        let hx = skin.drawn ? dw * 0.12 : -dw / 2 + skin.head.x / skin.w * dw
        let hy = skin.drawn ? dh * 0.85 : (dh - skin.head.y / skin.h * dh) + n.body.position.y
        switch p.kind {
        case .rey:
            let c = SKSpriteNode(texture: Tex.crown, size: CGSize(width: s * 0.42, height: s * 0.24))
            c.anchorPoint = CGPoint(x: 0.5, y: 0.15)
            c.position = CGPoint(x: hx, y: hy - s * 0.04)
            c.zPosition = 3
            n.addChild(c)
        case .bomba:
            let f = SKSpriteNode(texture: Tex.fuse, size: CGSize(width: s * 0.3, height: s * 0.3))
            f.anchorPoint = CGPoint(x: 0.6, y: 0.08)
            f.position = CGPoint(x: hx, y: hy - s * 0.04)
            f.zPosition = 3
            n.addChild(f)
            let fl = SKSpriteNode(texture: Tex.flame, size: CGSize(width: s * 0.16, height: s * 0.16))
            fl.position = CGPoint(x: hx - s * 0.13, y: hy + s * 0.2)
            fl.zPosition = 4
            n.addChild(fl)
            n.flame = fl
        case .ruedas:
            let b = SKSpriteNode(texture: Tex.skate, size: CGSize(width: dw * 0.9, height: dw * 0.9 * 34 / 120))
            b.anchorPoint = CGPoint(x: 0.5, y: 0.75)
            b.position = .zero
            b.zPosition = -1
            n.addChild(b)
        default: break
        }

        // barra de vida (fuera del muñeco para que no gire con él)
        let w = max(50, s * 0.8)
        let edge = SKSpriteNode(color: Tex.ink, size: CGSize(width: w + 4, height: 11))
        let back = SKSpriteNode(color: UIColor(Ink.paper), size: CGSize(width: w, height: 7))
        n.barFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        n.barFill.position = CGPoint(x: -w / 2, y: 0)
        edge.zPosition = 0; back.zPosition = 1; n.barFill.zPosition = 2
        n.bar.addChild(edge); n.bar.addChild(back); n.bar.addChild(n.barFill)
        n.bar.zPosition = 450
        n.bar.isHidden = true
        world.addChild(n.bar)

        world.addChild(n)
        pigNodes[p.id] = n
        return n
    }

    /// nodos ligados a un número fijo (así no cambian de dibujo cuando otros desaparecen)
    private var shardMap: [Int: SKSpriteNode] = [:]
    private var lootMap: [Int: SKSpriteNode] = [:]
    private var floatMap: [Int: SKSpriteNode] = [:]
    private var spare: [SKSpriteNode] = []

    @MainActor private func take(_ z: CGFloat) -> SKSpriteNode {
        let n = spare.popLast() ?? { let x = SKSpriteNode(); world.addChild(x); return x }()
        n.isHidden = false
        n.zPosition = z
        n.xScale = 1; n.yScale = 1; n.zRotation = 0; n.alpha = 1
        return n
    }
    @MainActor private func recycle(_ map: inout [Int: SKSpriteNode], keep: Set<Int>) {
        for (id, n) in map where !keep.contains(id) {
            n.isHidden = true
            spare.append(n)
            map[id] = nil
        }
    }

    @MainActor private func syncShards() {
        let t = desk.time
        var keep = Set<Int>()
        for s in desk.shards {
            keep.insert(s.id)
            let n: SKSpriteNode
            if let x = shardMap[s.id] { n = x } else {
                n = take(300)
                let r = s.pts.first.map { hypot($0.x, $0.y) } ?? 6
                n.texture = Tex.shard(UIColor(s.color), s.id % 3)
                n.size = CGSize(width: r * 2.4, height: r * 2.4)
                shardMap[s.id] = n
            }
            n.position = P(s.pos.x, s.pos.y)
            n.zRotation = -s.rot
            n.alpha = max(0, 1 - max(0, (t - s.born) - 0.8) * 2)
        }
        recycle(&shardMap, keep: keep)
    }

    @MainActor private func syncLoot() {
        let t = desk.time
        var keep = Set<Int>()
        for l in desk.loot where t >= l.born {
            keep.insert(l.id)
            let n: SKSpriteNode
            if let x = lootMap[l.id] { n = x } else {
                n = take(350)
                n.texture = l.bill ? Tex.item("billete") : Tex.item("c_loot")
                n.size = l.bill ? CGSize(width: 34, height: 18) : CGSize(width: 22, height: 22)
                lootMap[l.id] = n
            }
            n.position = P(l.pos.x, l.pos.y)
            if l.bill { n.zRotation = -sin(l.rot) * 0.6 } else { n.xScale = max(0.15, abs(cos(l.rot))) }
        }
        recycle(&lootMap, keep: keep)
    }

    @MainActor private func syncSwings() {
        let t = desk.time
        let list = desk.swings
        let hammer = desk.hammer
        let m = HammerArt.meta[hammer.style]!
        let hh = 92.0
        let k = hh / m.h
        while hammerNodes.count < list.count {
            let ring = SKSpriteNode(); ring.zPosition = 380; world.addChild(ring); ringNodes.append(ring)
            let imp = SKSpriteNode(texture: Tex.impact); imp.zPosition = 381; world.addChild(imp); impactNodes.append(imp)
            let h = SKSpriteNode(texture: Tex.item(m.file)); h.zPosition = 400; world.addChild(h); hammerNodes.append(h)
        }
        for i in 0..<hammerNodes.count {
            let ring = ringNodes[i], imp = impactNodes[i], hn = hammerNodes[i]
            guard i < list.count else { ring.isHidden = true; imp.isHidden = true; hn.isHidden = true; continue }
            let sw = list[i]
            let age = t - sw.born
            // polvo del golpe
            let kk = min(1, age / 0.3)
            let r = sw.radius * (0.6 + 0.5 * kk)
            ring.isHidden = !(sw.hit || age < 0.25)
            ring.texture = Tex.ring(UIColor(sw.crit ? Ink.red : Ink.paper), width: sw.crit ? 7 : 4)
            ring.size = CGSize(width: r * 2.1, height: r * 1.33)
            ring.position = P(sw.pos.x, sw.pos.y)
            ring.alpha = 1 - kk
            imp.isHidden = !sw.hit
            imp.size = ring.size
            imp.position = ring.position
            imp.alpha = 1 - kk
            // el martillo gira desde el mango y la cabeza cae donde has tocado
            let v = HammerArt.handle(hammer, height: hh)
            let final = -0.45
            let st = min(1, age / 0.07)
            let ang = final + (1 - st) * 1.25 + (sw.hit ? 0 : 0.12)
            let pivot = CGPoint(x: sw.pos.x + v.dx * cos(final) - v.dy * sin(final), y: sw.pos.y + v.dx * sin(final) + v.dy * cos(final))
            let head = CGPoint(x: pivot.x - (v.dx * cos(ang) - v.dy * sin(ang)), y: pivot.y - (v.dx * sin(ang) + v.dy * cos(ang)))
            hn.isHidden = false
            hn.size = CGSize(width: m.w * k, height: m.h * k)
            hn.anchorPoint = CGPoint(x: m.ax / m.w, y: 1 - m.ay / m.h)
            hn.position = P(head.x, head.y)
            hn.zRotation = -ang
            hn.alpha = age > 0.3 ? max(0, 1 - (age - 0.3) / 0.15) : 1
        }
    }

    @MainActor private func syncBlasts() {
        let t = desk.time
        let list = desk.blasts
        while blastNodes.count < list.count {
            let n = SKSpriteNode(texture: Tex.blast); n.zPosition = 280; world.addChild(n); blastNodes.append(n)
        }
        for (i, n) in blastNodes.enumerated() {
            guard i < list.count else { n.isHidden = true; continue }
            let b = list[i]
            let age = (t - b.born) / 0.6
            let r = b.radius * (0.3 + age * 0.9)
            n.isHidden = false
            n.size = CGSize(width: r * 2, height: r * 2)
            n.position = P(b.pos.x, b.pos.y)
            n.alpha = max(0, 1 - age)
        }
    }

    @MainActor private func syncFloaters() {
        let t = desk.time
        var keep = Set<Int>()
        for f in desk.floaters where t >= f.born {
            keep.insert(f.id)
            let n: SKSpriteNode
            if let x = floatMap[f.id] { n = x } else {
                n = take(500)
                let tex = Tex.text(f.text, f.size, UIColor(f.color == Ink.ink ? Ink.paper : f.color))
                n.texture = tex
                n.size = tex.size()
                floatMap[f.id] = n
            }
            let age = t - f.born
            let y = f.pos.y - 70 * age + 30 * age * age
            let pop = age < 0.12 ? 0.6 + age / 0.12 * 0.5 : (age < 0.2 ? 1.1 - (age - 0.12) / 0.08 * 0.1 : 1)
            n.position = P(f.pos.x, y)
            n.setScale(pop)
            n.alpha = min(1, (1.1 - age) * 3)
        }
        recycle(&floatMap, keep: keep)
    }

    @MainActor private func syncHUD() {
        let t = desk.time
        let w = size.width
        let top = desk.top
        if desk.frenzy {
            let left = (desk.frenzyUntil - t) / (6 + desk.stats.frenzyExtra)
            frenzyTint.isHidden = false
            frenzyTint.alpha = 0.12 + 0.06 * sin(t * 12)
            let bw = w * 0.6
            frenzyBack.isHidden = false
            frenzyBack.size = CGSize(width: bw + 4, height: 16)
            frenzyBack.position = P(w / 2, top + 50)
            frenzyFill.isHidden = false
            frenzyFill.size = CGSize(width: max(0.5, bw * min(1, max(0, left))), height: 12)
            frenzyFill.position = P((w - bw) / 2, top + 50)
        } else {
            frenzyTint.isHidden = true; frenzyBack.isHidden = true; frenzyFill.isHidden = true
        }
        // suceso en marcha (con los segundos que le quedan)
        if let h = desk.happening {
            let left = Int(ceil(desk.happeningUntil - t))
            let name: String
            switch h {
            case .lluvia: name = "Lluvia de oro"
            case .horaFeliz: name = "Hora feliz ×3"
            default: name = ""
            }
            let key = "\(name) \(left)"
            if key != lastHapp {
                lastHapp = key
                let tex = Tex.text(name + " · \(left) s", 18, UIColor(h == .lluvia ? Ink.gold : Ink.green))
                happNode.texture = tex; happNode.size = tex.size()
            }
            happNode.isHidden = name.isEmpty
            happNode.position = P(w / 2, top + 84)
        } else {
            happNode.isHidden = true
        }
        let combo = desk.combo
        guard combo >= 3 else { comboNode.isHidden = true; multNode.isHidden = true; comboBar.isHidden = true; lastCombo = -1; return }
        let since = t - desk.comboAt
        let color = combo >= 25 ? Ink.red : (combo >= 10 ? Ink.gold : Ink.paper)
        if combo != lastCombo {
            lastCombo = combo
            let tex = Tex.text("COMBO ×\(combo)", 26, UIColor(color))
            comboNode.texture = tex; comboNode.size = tex.size()
            let mt = Tex.text("dinero ×" + Fmt.dec(desk.comboMult * (desk.frenzy ? desk.frenzyGain : 1), 2), 15, UIColor(Ink.paper))
            multNode.texture = mt; multNode.size = mt.size()
        }
        comboNode.isHidden = false; multNode.isHidden = false
        comboNode.position = P(w / 2, top + 22)
        comboNode.setScale(1 + 0.35 * exp(-since * 10))
        multNode.position = P(w / 2, top + 46)
        comboBar.isHidden = desk.frenzy
        let k = max(0, 1 - since / Desk.comboWindow)
        comboBar.size = CGSize(width: max(0.5, 90 * k), height: 5)
        comboBar.position = P(w / 2, top + 60)
    }

    @MainActor private func syncTutorial() {
        guard desk.tutorial else { return }
        let t = desk.time
        if desk.report.swings == 0, let p = desk.bestCluster() {
            let k = 0.5 + 0.5 * sin(t * 5)
            let r = 46 + 10 * k
            tutRing.isHidden = false
            tutRing.size = CGSize(width: r * 2, height: r * 2)
            tutRing.position = P(p.x, p.y)
            tutText.isHidden = false
            tutText.position = P(p.x, p.y - r - 24)
            tutHand.isHidden = false
            tutHand.position = P(p.x + 14, p.y + 40 - 8 * k)
        } else {
            tutRing.isHidden = true; tutText.isHidden = true; tutHand.isHidden = true
        }
        let showLow = desk.firstBreakAt.map { t - $0 < 4 } ?? false
        tutLow1.isHidden = !showLow; tutLow2.isHidden = !showLow
        tutLow1.position = P(size.width / 2, size.height - desk.bottom - 70)
        tutLow2.position = P(size.width / 2, size.height - desk.bottom - 36)
    }
}
