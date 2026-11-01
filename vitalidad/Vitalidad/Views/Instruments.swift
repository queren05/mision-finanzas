import SwiftUI
import Charts

// Piezas de diseño comunes: cabeceras, el medidor de rayitas, las barras de puntuación,
// la barra de «tu normal» y las minigráficas.

/// Cabecera de tarjeta: icono de color y título en versalitas.
struct CardHeader: View {
    var title: String
    var symbol: String?
    var color: Color
    var trailing: String?

    init(_ title: String, symbol: String? = nil, color: Color = .secondary, trailing: String? = nil) {
        self.title = title
        self.symbol = symbol
        self.color = color
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 6) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(color)
            }
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1.1)
                .foregroundStyle(.secondary)
            Spacer(minLength: Space.s)
            if let trailing {
                Text(trailing)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Título de sección fuera de las tarjetas.
struct SectionTitle: View {
    var title: String
    var body: some View {
        Text(title)
            .font(.title3.weight(.bold))
            .padding(.horizontal, Space.xs)
            .padding(.top, Space.s)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Colores de una escala

/// Un color en RGB para poder mezclar dos (el medidor pinta cada rayita con su tono).
struct RGB {
    var r: Double, g: Double, b: Double
    var color: Color { Color(red: r, green: g, blue: b) }

    static func mix(_ stops: [RGB], _ t: Double) -> RGB {
        guard stops.count > 1 else { return stops.first ?? RGB(r: 1, g: 1, b: 1) }
        let x = min(1, max(0, t)) * Double(stops.count - 1)
        let i = min(stops.count - 2, Int(x))
        let f = x - Double(i)
        let a = stops[i], b = stops[i + 1]
        return RGB(r: a.r + (b.r - a.r) * f, g: a.g + (b.g - a.g) * f, b: a.b + (b.b - a.b) * f)
    }

    /// De rojo a ámbar y a verde: lo bajo pide atención y lo alto es bueno.
    static let readiness = [RGB(r: 1.0, g: 0.36, b: 0.36), RGB(r: 1.0, g: 0.72, b: 0.26), RGB(r: 0.22, g: 0.86, b: 0.58)]
    static let sleep = [RGB(r: 0.36, g: 0.30, b: 0.92), RGB(r: 0.45, g: 0.48, b: 1.0), RGB(r: 0.55, g: 0.78, b: 1.0)]
    static let effort = [RGB(r: 1.0, g: 0.80, b: 0.30), RGB(r: 1.0, g: 0.58, b: 0.22), RGB(r: 1.0, g: 0.34, b: 0.24)]
}

extension Score {
    var scale: [RGB] {
        switch kind {
        case .recovery: RGB.readiness
        case .sleep: RGB.sleep
        case .effort: RGB.effort
        }
    }

    /// El color que toca a este valor dentro de su escala.
    var tone: Color { RGB.mix(scale, Double(value) / 100).color }

    /// Dos o tres palabras para el centro del medidor.
    var verdict: String {
        switch kind {
        case .recovery: value >= 67 ? "Listo para apretar" : value >= 40 ? "A medio gas" : "Toca descansar"
        case .sleep: value >= 80 ? "Noche excelente" : value >= 60 ? "Noche correcta" : "Noche floja"
        case .effort: value >= 75 ? "Día intenso" : value >= 45 ? "Día moderado" : "Día tranquilo"
        }
    }
}

// MARK: - Medidor de rayitas

/// Arco de 270° hecho de rayitas que se encienden hasta el valor, cada una con su tono de la escala.
struct TickGauge: View, Animatable {
    var progress: Double
    var stops: [RGB]
    var ticks: Int = 60
    var tickLength: CGFloat = 16
    var tickWidth: CGFloat = 3

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        Canvas { ctx, size in
            let r = min(size.width, size.height) / 2
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let lit = Int((progress * Double(ticks - 1)).rounded(.down))
            for i in 0..<ticks {
                let f = Double(i) / Double(ticks - 1)
                let a = (135 + 270 * f) * .pi / 180
                let on = progress > 0.001 && i <= lit
                let tip = on && i == lit
                let outer = r - 1
                let inner = r - tickLength * (tip ? 1.45 : 1)
                var p = Path()
                p.move(to: CGPoint(x: c.x + CGFloat(cos(a)) * inner, y: c.y + CGFloat(sin(a)) * inner))
                p.addLine(to: CGPoint(x: c.x + CGFloat(cos(a)) * outer, y: c.y + CGFloat(sin(a)) * outer))
                let shade: GraphicsContext.Shading = on ? .color(RGB.mix(stops, f).color) : .color(Ink.track)
                ctx.stroke(p, with: shade, style: StrokeStyle(lineWidth: tip ? tickWidth * 1.5 : tickWidth, lineCap: .round))
            }
        }
    }
}

/// El medidor con su animación de entrada.
struct AnimatedGauge: View {
    var value: Double
    var stops: [RGB]
    var ticks: Int = 60
    var tickLength: CGFloat = 16
    var tickWidth: CGFloat = 3
    @State private var shown: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TickGauge(progress: shown, stops: stops, ticks: ticks, tickLength: tickLength, tickWidth: tickWidth)
            .onAppear { go(value, delay: 0.1) }
            .onChange(of: value) { _, v in go(v, delay: 0) }
            .accessibilityHidden(true)
    }

    private func go(_ v: Double, delay: Double) {
        if reduceMotion { shown = v; return }
        withAnimation(.spring(response: 1.4, dampingFraction: 0.9).delay(delay)) { shown = v }
    }
}

// MARK: - Barra de puntuación

/// Nombre, número y una barra fina con el tono de su escala.
struct ScoreBar: View {
    var score: Score
    @State private var shown: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(score.title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Text("\(score.value)")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Ink.track)
                    Capsule()
                        .fill(LinearGradient(colors: score.scale.map(\.color), startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(6, geo.size.width * shown))
                }
            }
            .frame(height: 6)
            Text(score.verdict)
                .font(.caption)
                .foregroundStyle(score.tone)
        }
        .onAppear { withAnimation(.spring(response: 1.2, dampingFraction: 0.9).delay(0.25)) { shown = Double(score.value) / 100 } }
        .onChange(of: score.value) { _, v in withAnimation(.smooth) { shown = Double(v) / 100 } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(score.title): \(score.value) de 100, \(score.verdict)")
    }
}

// MARK: - Tu normal

/// Una pista con tu rango normal marcado y un punto donde cae el valor de hoy.
struct RangeBar: View {
    var value: Double
    var baseline: Baseline
    var color: Color
    var status: Status

    var body: some View {
        let lo = min(baseline.low - baseline.spread * 1.6, value - baseline.spread * 0.4)
        let hi = max(baseline.high + baseline.spread * 1.6, value + baseline.spread * 0.4)
        let span = max(hi - lo, 0.0001)
        func x(_ v: Double, _ w: CGFloat) -> CGFloat { CGFloat((v - lo) / span) * w }
        return GeometryReader { geo in
            let w = geo.size.width
            let mid = geo.size.height / 2
            ZStack(alignment: .leading) {
                Capsule().fill(Ink.track).frame(height: 4)
                Capsule()
                    .fill(color.opacity(0.45))
                    .frame(width: max(8, x(baseline.high, w) - x(baseline.low, w)), height: 8)
                    .offset(x: x(baseline.low, w))
                Rectangle()
                    .fill(color)
                    .frame(width: 2, height: 12)
                    .offset(x: x(baseline.median, w) - 1)
                Circle()
                    .fill(status == .learning ? color : status.color)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().strokeBorder(Ink.surface, lineWidth: 2.5))
                    .shadow(color: status.color.opacity(0.6), radius: 5)
                    .offset(x: min(max(0, x(value, w) - 7), w - 14))
            }
            .frame(height: geo.size.height)
            .position(x: w / 2, y: mid)
        }
        .frame(height: 16)
        .accessibilityHidden(true)
    }
}

// MARK: - Minigráficas

/// Siete días en pequeño: barras para lo que se acumula (hoy más tenue) y línea para lo demás.
struct Sparkline: View {
    var metric: Metric
    var points: [TimePoint]

    var body: some View {
        let bars = metric.accumulates || metric == .sleep
        let last = points.last?.date
        Chart(points, id: \.date) { p in
            if bars {
                BarMark(x: .value("Día", p.date, unit: .day), y: .value("Valor", p.value), width: .ratio(0.62))
                    .foregroundStyle(metric.color.opacity(p.date == last && metric.accumulates && Calendar.current.isDateInToday(p.date) ? 0.45 : 0.9))
                    .cornerRadius(2.5)
            } else {
                AreaMark(x: .value("Día", p.date, unit: .day), y: .value("Valor", p.value))
                    .foregroundStyle(LinearGradient(colors: [metric.color.opacity(0.3), metric.color.opacity(0)], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.catmullRom)
                LineMark(x: .value("Día", p.date, unit: .day), y: .value("Valor", p.value))
                    .foregroundStyle(metric.color)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                    .interpolationMethod(.catmullRom)
                if p.date == last {
                    PointMark(x: .value("Día", p.date, unit: .day), y: .value("Valor", p.value))
                        .foregroundStyle(metric.color)
                        .symbolSize(30)
                }
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: .automatic(includesZero: bars))
        .chartLegend(.hidden)
        .accessibilityHidden(true)
    }
}

// MARK: - Diferencia con lo normal

extension Insight {
    /// Lo que sueles tener (a esta hora, si es algo que se acumula).
    var reference: Double? { expected ?? baseline?.median }

    /// «+12 %», «−9 ms», «+35 min».
    var deltaText: String? {
        guard let ref = reference, ref != 0 else { return nil }
        let d = value - ref
        let sign = d >= 0 ? "+" : "−"
        switch metric {
        case .hrv, .restingHR, .walkingHR, .heartRate, .respiratoryRate, .vo2max, .weight:
            let v = Fmt.value(metric, abs(d))
            if v == "0" || v == "0,0" { return "= normal" }
            return "\(sign)\(v) \(metric.unit)"
        case .sleep:
            if abs(d) < 5 * 60 { return "= normal" }
            return "\(sign)\(Fmt.duration(abs(d)))"
        default:
            let pct = Int((abs(d) / ref * 100).rounded())
            return pct == 0 ? "= normal" : "\(sign)\(pct) %"
        }
    }

    var deltaUp: Bool { value >= (reference ?? value) }
}

/// Flecha y diferencia con lo normal, del color de su estado.
struct DeltaChip: View {
    var insight: Insight

    var body: some View {
        if let t = insight.deltaText {
            let flat = t.hasPrefix("=")
            HStack(spacing: 3) {
                Image(systemName: flat ? "equal" : insight.deltaUp ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption2.weight(.heavy))
                Text(flat ? "En tu normal" : "\(t) vs. tu normal")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
            }
            .foregroundStyle(insight.status == .learning ? Color.secondary : insight.status.color)
        }
    }
}
