import SwiftUI

/// lo que lleva puesto cada tipo de hucha encima de la cabeza (sombreros, antenas, lazos…)
@MainActor
enum Hat {
    struct Spec {
        let w: Double, h: Double   // tamaño del lienzo
        let width: Double          // ancho en pantalla (× tamaño de la hucha)
        var ax = 0.5, ay = 0.9     // punto que va sobre la cabeza (0…1, desde arriba a la izquierda)
        var dx = 0.0, dy = 0.04    // desplazamiento desde la cabeza (× tamaño, hacia abajo)
        var onBody = false         // va alrededor del cuerpo, no en la cabeza
    }

    static func spec(_ k: PigKind) -> Spec? {
        switch k {
        case .rey: Spec(w: 90, h: 50, width: 0.42, ay: 0.85)
        case .reina: Spec(w: 90, h: 50, width: 0.36, ay: 0.85)
        case .millonaria: Spec(w: 80, h: 74, width: 0.36)
        case .pirata: Spec(w: 100, h: 60, width: 0.5, ay: 0.85, dy: 0.05)
        case .ninja: Spec(w: 110, h: 40, width: 0.5, ax: 0.55, ay: 0.5, dy: 0.12)
        case .payaso: Spec(w: 60, h: 84, width: 0.24, ay: 0.92)
        case .titan: Spec(w: 110, h: 64, width: 0.52, dy: 0.06)
        case .alien: Spec(w: 70, h: 70, width: 0.3, ay: 0.97, dy: 0.03)
        case .robot: Spec(w: 40, h: 74, width: 0.14, ay: 0.97, dy: 0.03)
        case .madre: Spec(w: 70, h: 44, width: 0.3, ay: 0.7, dx: -0.06, dy: 0.02)
        case .suerte: Spec(w: 50, h: 64, width: 0.2, ay: 0.95, dy: 0.02)
        case .cosmica: Spec(w: 100, h: 50, width: 0.5, ay: 1, dy: -0.04)
        case .hielo: Spec(w: 90, h: 46, width: 0.4)
        case .fenix: Spec(w: 80, h: 70, width: 0.34, ay: 0.95)
        case .lava: Spec(w: 80, h: 60, width: 0.34, ay: 0.95, dy: 0.05)
        case .nube: Spec(w: 110, h: 70, width: 0.55, ay: 1, dy: -0.08)
        case .vampiro: Spec(w: 100, h: 46, width: 0.42, dy: -0.02)
        case .momia: Spec(w: 90, h: 40, width: 0.42, ay: 0.5, dy: 0.1)
        case .zombi: Spec(w: 50, h: 50, width: 0.18, ay: 0.5, dx: -0.08, dy: 0.1)
        case .agujero: Spec(w: 200, h: 80, width: 1.5, ay: 0.5, dy: 0, onBody: true)
        default: nil
        }
    }

    private static var cache: [PigKind: UIImage] = [:]
    static func image(_ k: PigKind) -> UIImage? {
        if let i = cache[k] { return i }
        guard let s = spec(k) else { return nil }
        let f = UIGraphicsImageRendererFormat()
        f.scale = 3
        let img = UIGraphicsImageRenderer(size: CGSize(width: s.w, height: s.h), format: f).image { draw(k, $0.cgContext) }
        cache[k] = img
        return img
    }

    private static let ink = UIColor(Ink.ink)
    private static func ui(_ hex: String) -> UIColor { UIColor(Color(hex: hex)) }
    private static func fillStroke(_ c: CGContext, _ fill: UIColor, _ lw: CGFloat = 4) {
        c.setFillColor(fill.cgColor); c.setStrokeColor(ink.cgColor); c.setLineWidth(lw); c.setLineJoin(.round); c.setLineCap(.round)
        c.drawPath(using: .fillStroke)
    }
    private static func ellipse(_ c: CGContext, _ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ fill: UIColor, _ lw: CGFloat = 3.5) {
        c.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)); fillStroke(c, fill, lw)
    }
    private static func star(_ c: CGContext, _ x: CGFloat, _ y: CGFloat, _ r: CGFloat) {
        var pts: [CGPoint] = []
        for i in 0..<10 {
            let a = Double(i) * .pi / 5 - .pi / 2
            let rr = i % 2 == 0 ? r : r * 0.45
            pts.append(CGPoint(x: x + cos(a) * rr, y: y + sin(a) * rr))
        }
        c.addLines(between: pts); c.closePath(); fillStroke(c, UIColor(Ink.gold), 3)
    }
    private static func flame(_ c: CGContext, _ x: CGFloat, _ base: CGFloat, _ w: CGFloat, _ h: CGFloat, _ fill: UIColor) {
        c.move(to: CGPoint(x: x, y: base - h))
        c.addCurve(to: CGPoint(x: x, y: base), control1: CGPoint(x: x + w, y: base - h * 0.5), control2: CGPoint(x: x + w * 0.8, y: base))
        c.addCurve(to: CGPoint(x: x, y: base - h), control1: CGPoint(x: x - w * 0.8, y: base), control2: CGPoint(x: x - w, y: base - h * 0.5))
        fillStroke(c, fill, 3.5)
    }

    private static func draw(_ k: PigKind, _ c: CGContext) {
        switch k {
        case .rey, .reina:
            if k == .rey {
                var pts = [CGPoint(x: 5, y: 45)]
                for i in 0..<7 { pts.append(CGPoint(x: 5 + Double(i) * 80 / 6, y: i % 2 == 1 ? 32 : 5)) }
                pts.append(CGPoint(x: 85, y: 45))
                c.addLines(between: pts); c.closePath(); fillStroke(c, UIColor(Ink.gold))
                c.setFillColor(UIColor(Ink.red).cgColor)
                for i in [1, 3, 5] { c.fillEllipse(in: CGRect(x: 5 + Double(i) * 80 / 6 - 5, y: 30, width: 10, height: 10)) }
            } else {
                // diadema: un arco fino con picos y un corazón
                c.move(to: CGPoint(x: 6, y: 46))
                c.addQuadCurve(to: CGPoint(x: 84, y: 46), control: CGPoint(x: 45, y: 26))
                c.addLine(to: CGPoint(x: 72, y: 30)); c.addLine(to: CGPoint(x: 62, y: 36)); c.addLine(to: CGPoint(x: 45, y: 8))
                c.addLine(to: CGPoint(x: 28, y: 36)); c.addLine(to: CGPoint(x: 18, y: 30)); c.closePath()
                fillStroke(c, UIColor(Ink.gold))
                ellipse(c, 45, 26, 7, ui("#ff6f9a"), 3)
            }
        case .millonaria:
            c.addPath(UIBezierPath(roundedRect: CGRect(x: 18, y: 6, width: 44, height: 54), cornerRadius: 4).cgPath); fillStroke(c, ui("#2f2a36"))
            c.setFillColor(UIColor(Ink.gold).cgColor); c.fill(CGRect(x: 20, y: 44, width: 40, height: 9))
            c.addPath(UIBezierPath(roundedRect: CGRect(x: 4, y: 56, width: 72, height: 12), cornerRadius: 6).cgPath); fillStroke(c, ui("#2f2a36"))
        case .pirata:
            c.move(to: CGPoint(x: 4, y: 48))
            c.addQuadCurve(to: CGPoint(x: 30, y: 14), control: CGPoint(x: 10, y: 20))
            c.addQuadCurve(to: CGPoint(x: 70, y: 14), control: CGPoint(x: 50, y: 2))
            c.addQuadCurve(to: CGPoint(x: 96, y: 48), control: CGPoint(x: 90, y: 20))
            c.addQuadCurve(to: CGPoint(x: 4, y: 48), control: CGPoint(x: 50, y: 34))
            fillStroke(c, ui("#2b2730"))
            c.setStrokeColor(UIColor.white.cgColor); c.setLineWidth(3.5); c.setLineCap(.round)
            c.move(to: CGPoint(x: 40, y: 38)); c.addLine(to: CGPoint(x: 60, y: 22))
            c.move(to: CGPoint(x: 40, y: 22)); c.addLine(to: CGPoint(x: 60, y: 38)); c.strokePath()
            c.setFillColor(UIColor.white.cgColor); c.fillEllipse(in: CGRect(x: 43, y: 18, width: 14, height: 13))
            c.setFillColor(ui("#2b2730").cgColor)
            c.fillEllipse(in: CGRect(x: 46, y: 22, width: 3.5, height: 3.5)); c.fillEllipse(in: CGRect(x: 51, y: 22, width: 3.5, height: 3.5))
        case .ninja:
            // la cinta y sus dos colas hacia atrás
            c.move(to: CGPoint(x: 22, y: 18)); c.addLine(to: CGPoint(x: 2, y: 30)); c.addLine(to: CGPoint(x: 8, y: 36)); c.addLine(to: CGPoint(x: 24, y: 24)); c.closePath()
            fillStroke(c, UIColor(Ink.red), 3)
            c.move(to: CGPoint(x: 22, y: 20)); c.addLine(to: CGPoint(x: 6, y: 16)); c.addLine(to: CGPoint(x: 6, y: 24)); c.closePath()
            fillStroke(c, UIColor(Ink.red), 3)
            c.addPath(UIBezierPath(roundedRect: CGRect(x: 18, y: 10, width: 86, height: 18), cornerRadius: 6).cgPath); fillStroke(c, UIColor(Ink.red))
            c.setFillColor(ui("#d9d6dc").cgColor); c.fill(CGRect(x: 72, y: 13, width: 18, height: 12))
        case .payaso:
            c.move(to: CGPoint(x: 6, y: 78)); c.addLine(to: CGPoint(x: 30, y: 16)); c.addLine(to: CGPoint(x: 54, y: 78))
            c.addQuadCurve(to: CGPoint(x: 6, y: 78), control: CGPoint(x: 30, y: 86))
            fillStroke(c, ui("#ffd23a"))
            c.setFillColor(UIColor(Ink.red).cgColor)
            for (x, y) in [(24.0, 44.0), (36.0, 58.0), (22.0, 68.0), (40.0, 72.0), (30.0, 32.0)] { c.fillEllipse(in: CGRect(x: x - 4, y: y - 4, width: 8, height: 8)) }
            ellipse(c, 30, 12, 9, UIColor(Ink.red))
        case .titan:
            // casco con cuernos
            c.move(to: CGPoint(x: 28, y: 44)); c.addQuadCurve(to: CGPoint(x: 6, y: 4), control: CGPoint(x: 6, y: 34)); c.addQuadCurve(to: CGPoint(x: 36, y: 34), control: CGPoint(x: 22, y: 30))
            fillStroke(c, ui("#efe3c4"))
            c.move(to: CGPoint(x: 82, y: 44)); c.addQuadCurve(to: CGPoint(x: 104, y: 4), control: CGPoint(x: 104, y: 34)); c.addQuadCurve(to: CGPoint(x: 74, y: 34), control: CGPoint(x: 88, y: 30))
            fillStroke(c, ui("#efe3c4"))
            c.move(to: CGPoint(x: 22, y: 58)); c.addArc(center: CGPoint(x: 55, y: 58), radius: 33, startAngle: .pi, endAngle: 0, clockwise: false); c.closePath()
            fillStroke(c, ui("#9aa1a9"))
            c.setFillColor(ink.cgColor)
            for x in [38.0, 55, 72] { c.fillEllipse(in: CGRect(x: x - 3, y: 48, width: 6, height: 6)) }
        case .alien:
            c.setStrokeColor(ink.cgColor); c.setLineWidth(5); c.setLineCap(.round)
            c.move(to: CGPoint(x: 26, y: 68)); c.addQuadCurve(to: CGPoint(x: 14, y: 14), control: CGPoint(x: 26, y: 30))
            c.move(to: CGPoint(x: 44, y: 68)); c.addQuadCurve(to: CGPoint(x: 56, y: 14), control: CGPoint(x: 44, y: 30)); c.strokePath()
            ellipse(c, 14, 12, 9, ui("#8fe36a")); ellipse(c, 56, 12, 9, ui("#8fe36a"))
        case .robot:
            c.setStrokeColor(ink.cgColor); c.setLineWidth(6); c.move(to: CGPoint(x: 20, y: 72)); c.addLine(to: CGPoint(x: 20, y: 20)); c.strokePath()
            c.setStrokeColor(ui("#8fa3b8").cgColor); c.setLineWidth(3); c.move(to: CGPoint(x: 20, y: 70)); c.addLine(to: CGPoint(x: 20, y: 22)); c.strokePath()
            ellipse(c, 20, 14, 10, UIColor(Ink.red))
        case .madre:
            c.move(to: CGPoint(x: 35, y: 22)); c.addLine(to: CGPoint(x: 4, y: 6)); c.addLine(to: CGPoint(x: 6, y: 40)); c.closePath(); fillStroke(c, ui("#ff8fb1"))
            c.move(to: CGPoint(x: 35, y: 22)); c.addLine(to: CGPoint(x: 66, y: 6)); c.addLine(to: CGPoint(x: 64, y: 40)); c.closePath(); fillStroke(c, ui("#ff8fb1"))
            ellipse(c, 35, 22, 8, ui("#ff6f9a"))
        case .suerte:
            c.setStrokeColor(ink.cgColor); c.setLineWidth(5); c.setLineCap(.round)
            c.move(to: CGPoint(x: 25, y: 30)); c.addQuadCurve(to: CGPoint(x: 30, y: 62), control: CGPoint(x: 22, y: 50)); c.strokePath()
            for (x, y) in [(15.0, 14.0), (35.0, 14.0), (15.0, 32.0), (35.0, 32.0)] { ellipse(c, x, y, 10, ui("#4fc25c")) }
            c.setFillColor(ui("#4fc25c").cgColor); c.fillEllipse(in: CGRect(x: 17, y: 15, width: 16, height: 16))
        case .cosmica:
            star(c, 20, 30, 14); star(c, 52, 16, 12); star(c, 82, 32, 13)
        case .hielo:
            var pts = [CGPoint(x: 6, y: 42)]
            for (i, x) in [6.0, 18, 30, 45, 60, 72, 84].enumerated() { pts.append(CGPoint(x: x, y: i % 2 == 0 ? 10 + Double(i % 3) * 3 : 30)) }
            pts.append(CGPoint(x: 84, y: 42))
            c.addLines(between: pts); c.closePath(); fillStroke(c, ui("#bfefff"))
            c.setStrokeColor(UIColor.white.cgColor); c.setLineWidth(3); c.move(to: CGPoint(x: 14, y: 36)); c.addLine(to: CGPoint(x: 76, y: 36)); c.strokePath()
        case .fenix:
            flame(c, 20, 66, 16, 46, ui("#f0642a"))
            flame(c, 60, 66, 16, 46, ui("#f0642a"))
            flame(c, 40, 66, 18, 62, UIColor(Ink.gold))
        case .lava:
            flame(c, 22, 56, 14, 34, UIColor(Ink.red))
            flame(c, 58, 56, 14, 38, UIColor(Ink.red))
            flame(c, 40, 56, 16, 50, ui("#ff9a2a"))
        case .nube:
            for (x, y, r) in [(30.0, 32.0, 18.0), (55.0, 22.0, 22.0), (80.0, 32.0, 18.0)] {
                c.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
            }
            c.addPath(UIBezierPath(roundedRect: CGRect(x: 12, y: 30, width: 86, height: 20), cornerRadius: 10).cgPath)
            c.setStrokeColor(ink.cgColor); c.setLineWidth(8); c.strokePath()
            c.setFillColor(UIColor.white.cgColor)
            for (x, y, r) in [(30.0, 32.0, 18.0), (55.0, 22.0, 22.0), (80.0, 32.0, 18.0)] { c.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)) }
            c.fill(CGRect(x: 12, y: 30, width: 86, height: 20))
            c.setStrokeColor(ui("#5aa8e6").cgColor); c.setLineWidth(4); c.setLineCap(.round)
            for x in [36.0, 56, 76] { c.move(to: CGPoint(x: x, y: 58)); c.addLine(to: CGPoint(x: x - 3, y: 67)) }
            c.strokePath()
        case .vampiro:
            // un murciélago
            c.move(to: CGPoint(x: 50, y: 18))
            c.addQuadCurve(to: CGPoint(x: 4, y: 10), control: CGPoint(x: 26, y: 2))
            c.addQuadCurve(to: CGPoint(x: 18, y: 30), control: CGPoint(x: 6, y: 26))
            c.addQuadCurve(to: CGPoint(x: 32, y: 32), control: CGPoint(x: 24, y: 26))
            c.addQuadCurve(to: CGPoint(x: 50, y: 40), control: CGPoint(x: 40, y: 30))
            c.addQuadCurve(to: CGPoint(x: 68, y: 32), control: CGPoint(x: 60, y: 30))
            c.addQuadCurve(to: CGPoint(x: 82, y: 30), control: CGPoint(x: 76, y: 26))
            c.addQuadCurve(to: CGPoint(x: 96, y: 10), control: CGPoint(x: 94, y: 26))
            c.addQuadCurve(to: CGPoint(x: 50, y: 18), control: CGPoint(x: 74, y: 2))
            fillStroke(c, ui("#2b2730"))
            c.setFillColor(UIColor(Ink.red).cgColor)
            c.fillEllipse(in: CGRect(x: 43, y: 20, width: 5, height: 5)); c.fillEllipse(in: CGRect(x: 52, y: 20, width: 5, height: 5))
        case .momia:
            c.addPath(UIBezierPath(roundedRect: CGRect(x: 4, y: 8, width: 82, height: 14), cornerRadius: 4).cgPath); fillStroke(c, ui("#efe4c4"), 3.5)
            c.saveGState(); c.translateBy(x: 45, y: 22); c.rotate(by: -0.25)
            c.addPath(UIBezierPath(roundedRect: CGRect(x: -40, y: 0, width: 80, height: 13), cornerRadius: 4).cgPath); fillStroke(c, ui("#e2d4ac"), 3.5)
            c.restoreGState()
        case .zombi:
            // tirita en cruz
            for a in [0.6, -0.6] {
                c.saveGState(); c.translateBy(x: 25, y: 25); c.rotate(by: a)
                c.addPath(UIBezierPath(roundedRect: CGRect(x: -22, y: -7, width: 44, height: 14), cornerRadius: 5).cgPath); fillStroke(c, ui("#f2c9a0"), 3)
                c.restoreGState()
            }
        case .agujero:
            c.setStrokeColor(ink.cgColor); c.setLineWidth(9)
            c.strokeEllipse(in: CGRect(x: 8, y: 14, width: 184, height: 52))
            c.setStrokeColor(ui("#9b7bff").cgColor); c.setLineWidth(4); c.setLineDash(phase: 0, lengths: [16, 10])
            c.strokeEllipse(in: CGRect(x: 8, y: 14, width: 184, height: 52))
        default: break
        }
    }
}
