import SwiftUI

// Vistas de los widgets. Están aquí para usarlas también dentro de la app (Ajustes → Widgets).

/// Pastilla pequeña con icono y número.
struct WPill: View {
    var symbol: String
    var value: Int?
    var color: Color

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: symbol).font(.system(size: 10, weight: .bold))
            Text(value.map(String.init) ?? "–").font(.system(size: 13, weight: .bold, design: .rounded)).monospacedDigit()
        }
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(color.opacity(0.18), in: Capsule())
    }
}

/// Pequeño: Latido, la recuperación en grande y sueño y esfuerzo.
struct VWDaySmall: View {
    var d: WidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Latido(mood: d.latido, size: 50)
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: -2) {
                    Text(d.recovery.map(String.init) ?? "–")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundStyle(WTone.recovery)
                        .minimumScaleFactor(0.6)
                    Text("recuperación").font(.system(size: 10, weight: .semibold)).foregroundStyle(.white.opacity(0.7))
                }
            }
            Spacer(minLength: 0)
            Text(WLink.greeting()).font(.system(size: 13, weight: .bold, design: .rounded)).lineLimit(1)
            HStack(spacing: 6) {
                WPill(symbol: "moon.zzz.fill", value: d.sleep, color: WTone.sleep)
                WPill(symbol: "flame.fill", value: d.effort, color: WTone.effort)
            }
            .padding(.top, 5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Pequeño: el consejo del día con Latido.
struct VWAdviceSmall: View {
    var d: WidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Latido(mood: d.latido, size: 34)
                Text(d.night == true ? "Esta noche" : "Para hoy")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(WTone.glow(d.mood))
            }
            Text(d.advice ?? d.summary)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .lineLimit(5)
                .minimumScaleFactor(0.75)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Pequeño: pasos de hoy frente a lo que sueles hacer en un día.
struct VWStepsSmall: View {
    var d: WidgetData

    var body: some View {
        let now = d.stepsNow ?? 0
        let goal = max(1, d.stepsGoal ?? 8000)
        VStack(spacing: 6) {
            ZStack {
                Circle().stroke(WTone.effort.opacity(0.2), lineWidth: 11)
                Circle()
                    .trim(from: 0, to: min(1, now / goal))
                    .stroke(AngularGradient(colors: [WTone.effort.opacity(0.7), WTone.effort], center: .center),
                            style: StrokeStyle(lineWidth: 11, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Image(systemName: now >= goal ? "star.fill" : "figure.walk").font(.system(size: 16, weight: .bold)).foregroundStyle(WTone.effort)
                    Text("\(Int((min(9.99, now / goal) * 100).rounded())) %").font(.system(size: 13, weight: .bold, design: .rounded))
                }
            }
            .padding(5)
            Text(WNum.int(now)).font(.system(size: 17, weight: .heavy, design: .rounded)).lineLimit(1).minimumScaleFactor(0.7)
            Text("de \(WNum.int(goal)) habituales").font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.7)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Las tres puntuaciones, cada una abre su pantalla.
struct VWRings: View {
    var d: WidgetData
    var size: CGFloat
    var links = true

    var body: some View {
        HStack(spacing: 8) {
            ring("Recuperación", d.recovery, WTone.recovery, "today")
            ring("Sueño", d.sleep, WTone.sleep, "sleep")
            ring("Esfuerzo", d.effort, WTone.effort, "activity")
        }
    }

    @ViewBuilder
    private func ring(_ title: String, _ v: Int?, _ c: Color, _ tab: String) -> some View {
        let r = VStack(spacing: 4) {
            WRing(value: v, color: c, line: size * 0.11, font: .system(size: size * 0.32, weight: .heavy, design: .rounded))
                .frame(width: size, height: size)
            Text(title).font(.system(size: 10, weight: .semibold)).foregroundStyle(.white.opacity(0.75)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        if links { Link(destination: WLink.tab(tab)) { r } } else { r }
    }
}

/// Mediano: saludo con Latido, los tres anillos y el consejo.
struct VWDayMedium: View {
    var d: WidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Latido(mood: d.latido, size: 30)
                Text(WLink.greeting()).font(.system(size: 14, weight: .bold, design: .rounded))
                Spacer(minLength: 0)
                if let s = d.slept {
                    Label(s, systemImage: "moon.zzz.fill").font(.system(size: 11, weight: .semibold)).foregroundStyle(WTone.sleep)
                }
            }
            VWRings(d: d, size: 50)
            Text(d.advice ?? d.summary)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Grande: todo junto, con tus tarjetas de Hoy que abren su detalle.
struct VWDayLarge: View {
    var d: WidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Latido(mood: d.latido, size: 54)
                VStack(alignment: .leading, spacing: 3) {
                    Text(WLink.greeting()).font(.system(size: 16, weight: .heavy, design: .rounded))
                    Text(d.summary)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                }
            }
            VWRings(d: d, size: 64)
            VStack(spacing: 6) {
                ForEach(d.items.prefix(4), id: \.self) { i in
                    Link(destination: WLink.detail(i.id)) { VWItemRow(i: i) }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Fila de un dato: icono en burbuja, nombre, valor y estado.
struct VWItemRow: View {
    var i: WidgetData.Item
    var showTitle = true

    var body: some View {
        let c = Color(wHex: i.color)
        HStack(spacing: 7) {
            Image(systemName: i.symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(c)
                .frame(width: 22, height: 22)
                .background(c.opacity(0.2), in: Circle())
            if showTitle {
                Text(i.title).font(.system(size: 12, weight: .medium)).lineLimit(1)
                Spacer(minLength: 4)
            }
            Text(i.value).font(.system(size: 13, weight: .bold, design: .rounded)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
            Text(i.unit).font(.system(size: 9, weight: .semibold)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
            if !showTitle { Spacer(minLength: 0) }
            Circle().fill(WTone.status(i.status)).frame(width: 7, height: 7)
        }
    }
}

/// Pequeño: tres datos de Hoy.
struct VWDataSmall: View {
    var d: WidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(d.items.prefix(4), id: \.self) { VWItemRow(i: $0, showTitle: false) }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Mediano: cuatro baldosas de colores, cada una abre su detalle.
struct VWDataMedium: View {
    var d: WidgetData

    var body: some View {
        let items = Array(d.items.prefix(4))
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow { ForEach(items.prefix(2), id: \.self) { tile($0) } }
            if items.count > 2 {
                GridRow { ForEach(items.dropFirst(2), id: \.self) { tile($0) } }
            }
        }
    }

    private func tile(_ i: WidgetData.Item) -> some View {
        let c = Color(wHex: i.color)
        return Link(destination: WLink.detail(i.id)) {
            VStack(alignment: .leading, spacing: 1) {
                HStack {
                    Image(systemName: i.symbol).font(.system(size: 11, weight: .bold)).foregroundStyle(c)
                    Spacer()
                    Circle().fill(WTone.status(i.status)).frame(width: 7, height: 7)
                }
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(i.value).font(.system(size: 18, weight: .heavy, design: .rounded)).minimumScaleFactor(0.6).lineLimit(1)
                    Text(i.unit).font(.system(size: 9, weight: .semibold)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                }
                Text(i.title).font(.system(size: 9, weight: .medium)).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(c.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

enum WNum {
    /// 6.412 (con punto de miles también en 4 cifras).
    static func int(_ v: Double) -> String {
        let n = Int(v.rounded())
        var out = ""
        for (i, ch) in String(abs(n)).reversed().enumerated() {
            if i > 0 && i % 3 == 0 { out.append(".") }
            out.append(ch)
        }
        return (n < 0 ? "-" : "") + String(out.reversed())
    }
}
