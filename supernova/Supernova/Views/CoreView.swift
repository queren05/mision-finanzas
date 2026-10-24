import SwiftUI

private struct FloatNum {
    let text: String
    let pos: CGPoint
    let born: Double
    let crit: Bool
    let drift: Double
}

private struct Spark {
    let pos: CGPoint
    let vel: CGVector
    let born: Double
    let color: Color
    let size: Double
}

/// La estrella que se toca: halo, rayos que giran, chispas y números que salen volando.
struct CoreView: View {
    @Environment(GameEngine.self) private var game
    var active: Bool
    @State private var floats: [FloatNum] = []
    @State private var sparks: [Spark] = []
    @State private var taps = 0
    @State private var crits = 0

    /// la estrella cambia de color según el generador más avanzado que tengas
    private var color: Color {
        if let i = game.s.owned.lastIndex(where: { $0 > 0 }) { return Color(hex: Content.generators[i].color) }
        return Palette.energy
    }

    var body: some View {
        GeometryReader { geo in
            let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2 - 14)
            let col = color
            ZStack {
                TimelineView(.animation(minimumInterval: 1 / 60, paused: !active)) { tl in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    Canvas { ctx, size in
                        let R = min(size.width, size.height) * 0.46 * (1 + 0.035 * sin(t * 2.2))
                        // halo
                        ctx.fill(Path(ellipseIn: CGRect(x: c.x - R, y: c.y - R, width: R * 2, height: R * 2)),
                                 with: .radialGradient(Gradient(colors: [col.opacity(0.5), col.opacity(0.12), .clear]), center: c, startRadius: 0, endRadius: R))
                        // rayos
                        ctx.drawLayer { l in
                            l.translateBy(x: c.x, y: c.y)
                            l.rotate(by: .radians(t * 0.15))
                            for k in 0..<12 {
                                let a = Double(k) / 12 * 2 * .pi
                                let len = R * (0.8 + 0.2 * sin(t * 1.3 + Double(k)))
                                var p = Path()
                                p.move(to: .zero)
                                p.addLine(to: CGPoint(x: cos(a - 0.05) * len, y: sin(a - 0.05) * len))
                                p.addLine(to: CGPoint(x: cos(a + 0.05) * len, y: sin(a + 0.05) * len))
                                p.closeSubpath()
                                l.fill(p, with: .linearGradient(Gradient(colors: [col.opacity(0.4), .clear]), startPoint: .zero, endPoint: CGPoint(x: cos(a) * len, y: sin(a) * len)))
                            }
                        }
                        // lunas en órbita
                        for k in 0..<3 {
                            let a = t * (0.6 + Double(k) * 0.25) + Double(k) * 2
                            let rr = R * 0.62 + Double(k) * 12
                            let p = CGPoint(x: c.x + cos(a) * rr, y: c.y + sin(a) * rr * 0.32)
                            let behind = sin(a) < 0
                            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 3.5, y: p.y - 3.5, width: 7, height: 7)), with: .color(.white.opacity(behind ? 0.25 : 0.9)))
                        }
                        // chispas
                        for s in sparks {
                            let age = t - s.born
                            guard age >= 0, age < 0.9 else { continue }
                            let a = 1 - age / 0.9
                            let p = CGPoint(x: s.pos.x + s.vel.dx * age, y: s.pos.y + s.vel.dy * age + 160 * age * age)
                            let r = s.size * a
                            ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(s.color.opacity(a)))
                        }
                        // números
                        for f in floats {
                            let age = t - f.born
                            guard age >= 0, age < 1.1 else { continue }
                            var c2 = ctx
                            c2.opacity = min(1, (1.1 - age) * 2.5)
                            let text = Text(f.text)
                                .font(.system(size: f.crit ? 32 : 21, weight: .heavy, design: .rounded))
                                .foregroundColor(f.crit ? Palette.gold : .white)
                            c2.draw(text, at: CGPoint(x: f.pos.x + f.drift * age, y: f.pos.y - 95 * age))
                        }
                    }
                }

                // el núcleo
                Circle()
                    .fill(RadialGradient(colors: [.white, col, col.opacity(0.55)], center: UnitPoint(x: 0.38, y: 0.34), startRadius: 2, endRadius: 90))
                    .frame(width: 150, height: 150)
                    .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1.5))
                    .shadow(color: col.opacity(0.9), radius: 30)
                    .keyframeAnimator(initialValue: 1.0, trigger: taps) { content, v in
                        content.scaleEffect(v)
                    } keyframes: { _ in
                        SpringKeyframe(0.86, duration: 0.05)
                        SpringKeyframe(1.0, duration: 0.45, spring: .bouncy)
                    }
                    .keyframeAnimator(initialValue: 0.0, trigger: crits) { content, v in
                        content.rotationEffect(.degrees(v))
                    } keyframes: { _ in
                        CubicKeyframe(-6, duration: 0.05)
                        CubicKeyframe(6, duration: 0.06)
                        CubicKeyframe(0, duration: 0.12)
                    }
                    .position(c)
                    .allowsHitTesting(false)

                // combo y valor por toque
                VStack(spacing: 5) {
                    if game.combo > 1.04 {
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill").foregroundStyle(Palette.gold)
                            Text("Combo ×\(Fmt.dec(game.combo, 2))").font(.system(.caption, design: .rounded).weight(.heavy))
                        }
                        GlowBar(value: (game.combo - 1), color: Palette.gold, height: 5).frame(width: 120)
                    } else {
                        Text("+\(Fmt.num(game.tapValue)) por toque").font(.system(.caption, design: .rounded).weight(.semibold)).foregroundStyle(.white.opacity(0.6))
                    }
                }
                .animation(.snappy, value: game.combo > 1.04)
                .position(x: c.x, y: geo.size.height - 16)
                .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .onTapGesture(coordinateSpace: .local) { loc in tapped(at: loc, color: col) }
        }
    }

    private func tapped(at loc: CGPoint, color: Color) {
        let r = game.tap()
        taps += 1
        if r.crit { crits += 1 }
        let now = Date().timeIntervalSinceReferenceDate
        floats.removeAll { now - $0.born > 1.15 }
        sparks.removeAll { now - $0.born > 0.95 }
        floats.append(FloatNum(text: (r.crit ? "¡CRÍTICO! +" : "+") + Fmt.num(r.value),
                               pos: CGPoint(x: loc.x + .random(in: -14...14), y: loc.y - 24),
                               born: now, crit: r.crit, drift: .random(in: -30...30)))
        let n = r.crit ? 24 : 9
        for _ in 0..<n {
            let a = Double.random(in: 0..<(2 * .pi))
            let sp = Double.random(in: 80...(r.crit ? 380 : 230))
            sparks.append(Spark(pos: loc, vel: CGVector(dx: cos(a) * sp, dy: sin(a) * sp - 70), born: now,
                                color: [color, .white, Palette.gold].randomElement() ?? .white,
                                size: .random(in: 2...(r.crit ? 6 : 4))))
        }
        if sparks.count > 260 { sparks.removeFirst(sparks.count - 260) }
    }
}
