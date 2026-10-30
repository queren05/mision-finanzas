import SwiftUI

// MARK: - Vistas de los widgets (también se enseñan dentro de la app, en Más → Widgets)

/// enlaces que abren la app en el sitio justo
enum WLink {
    static let new = URL(string: "caudal://nuevo")!
    static func tab(_ t: String) -> URL { URL(string: "caudal://tab/\(t)")! }
}

/// fondo: oscuro con un brillo suave del color de la app
struct WBackground: View {
    var accent: String

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(wHex: "#221f2b"), Color(wHex: "#121116")], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Color(wHex: accent).opacity(0.32), .clear], center: .topTrailing, startRadius: 0, endRadius: 170)
            RadialGradient(colors: [Color(wHex: "#8fc8ff").opacity(0.12), .clear], center: .bottomLeading, startRadius: 0, endRadius: 150)
        }
    }
}

/// Gotita con la cara de cómo va el mes
struct WGotita: View {
    var d: WidgetData
    var size: CGFloat = 44

    var body: some View {
        GotitaStill(mood: Mood(rawValue: d.mood ?? "") ?? .happy, size: size, hat: d.mascotHat ?? "nada",
                    color: Color(wHex: d.mascotColor ?? d.accent))
    }
}

/// emoji dentro de una burbuja de su color
struct WBubble: View {
    var icon: String
    var color: String
    var size: CGFloat = 24

    var body: some View {
        Text(icon)
            .font(.system(size: size * 0.55))
            .frame(width: size, height: size)
            .background(Color(wHex: color).opacity(0.28), in: Circle())
    }
}

/// barra de progreso gordita
struct WBar: View {
    var value: Double
    var color: Color
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.1))
                Capsule()
                    .fill(LinearGradient(colors: [color.opacity(0.75), color], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(height, g.size.width * min(1, max(0, value))))
            }
        }
        .frame(height: height)
    }
}

/// botón «+ Apuntar» que abre el teclado de apuntar
struct WAddButton: View {
    var d: WidgetData
    var label = true

    var body: some View {
        Link(destination: WLink.new) {
            HStack(spacing: 4) {
                Image(systemName: "plus").font(.system(size: 11, weight: .heavy))
                if label { Text("Apuntar").font(.system(size: 11, weight: .bold, design: .rounded)) }
            }
            .foregroundStyle(.black)
            .padding(.horizontal, label ? 10 : 7)
            .padding(.vertical, 6)
            .background(Color(wHex: d.accent), in: Capsule())
        }
    }
}

// MARK: Disponible hoy

struct WAllowanceSmall: View {
    var d: WidgetData

    var body: some View {
        let left = d.left ?? 0
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .top) {
                Text(left < 0 ? "Este mes\nte pasas" : "Hoy puedes\ngastar")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(wHex: d.accent))
                    .lineSpacing(-2)
                Spacer(minLength: 0)
                WGotita(d: d, size: 46)
            }
            Spacer(minLength: 0)
            Text(WMoney.eur(left < 0 ? -left : (d.perDay ?? 0)))
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(left < 0 ? Color.wRed : .white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(left < 0 ? "por encima de lo previsto" : "quedan \(d.daysLeft ?? 0) días · \(WMoney.eur(left))")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.65))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct WAllowanceMedium: View {
    var d: WidgetData

    var body: some View {
        HStack(spacing: 16) {
            WAllowanceSmall(d: d).frame(width: 128)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Gastado en \(d.month.lowercased())").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.7))
                    Spacer(minLength: 0)
                }
                Text(WMoney.eur(d.spent)).font(.system(size: 18, weight: .bold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.6)
                if d.budget > 0 {
                    WBar(value: d.spent / d.budget, color: d.spent > d.budget ? .wRed : Color(wHex: d.accent))
                    Text("de \(WMoney.eur(d.budget))").font(.system(size: 10)).foregroundStyle(.white.opacity(0.6))
                }
                Spacer(minLength: 0)
                HStack {
                    Spacer()
                    WAddButton(d: d)
                }
            }
        }
    }
}

// MARK: Cuentas

struct WBalanceSmall: View {
    var d: WidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                Label("Patrimonio", systemImage: "drop.fill")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(wHex: d.accent))
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
            Text(WMoney.eur(d.netWorth)).font(.system(size: 23, weight: .heavy, design: .rounded)).minimumScaleFactor(0.5).lineLimit(1)
            HStack(spacing: -6) {
                ForEach(d.accounts.prefix(4), id: \.self) { a in
                    WBubble(icon: a.icon, color: a.color, size: 26)
                        .overlay(Circle().strokeBorder(Color(wHex: "#1a1820"), lineWidth: 2))
                }
            }
            .padding(.top, 4)
            Text("Efectivo \(WMoney.eur(d.cash))").font(.system(size: 10)).foregroundStyle(.white.opacity(0.65)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct WAccounts: View {
    var d: WidgetData
    var rows = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Cuentas", systemImage: "drop.fill").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(Color(wHex: d.accent))
                Spacer()
                Text(WMoney.eur(d.netWorth)).font(.system(size: 12, weight: .heavy, design: .rounded)).monospacedDigit()
            }
            ForEach(d.accounts.prefix(rows), id: \.self) { a in
                HStack(spacing: 8) {
                    WBubble(icon: a.icon, color: a.color, size: 22)
                    Text(a.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                    Spacer(minLength: 4)
                    Text(WMoney.eur(a.value)).font(.system(size: 13, weight: .bold, design: .rounded)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: Gastos

struct WSpentSmall: View {
    var d: WidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Gastos · \(d.month)", systemImage: "arrow.down.circle.fill")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.wRed)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(WMoney.eur(d.spent)).font(.system(size: 23, weight: .heavy, design: .rounded)).minimumScaleFactor(0.5).lineLimit(1)
            if d.budget > 0 {
                WBar(value: d.spent / d.budget, color: d.spent > d.budget ? .wRed : Color(wHex: d.accent))
                Text("\(Int((d.spent / d.budget * 100).rounded())) % de \(WMoney.eur(d.budget))")
                    .font(.system(size: 10)).foregroundStyle(.white.opacity(0.65)).lineLimit(1).minimumScaleFactor(0.7)
            } else {
                Text("Ingresos \(WMoney.eur(d.earned))").font(.system(size: 10)).foregroundStyle(.white.opacity(0.65)).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct WSpentMedium: View {
    var d: WidgetData

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading) {
                WSpentSmall(d: d)
                WAddButton(d: d)
            }
            .frame(width: 124)
            VStack(alignment: .leading, spacing: 7) {
                let top = max(d.cats.map(\.total).max() ?? 0.01, 0.01)
                ForEach(d.cats.prefix(4), id: \.self) { c in
                    HStack(spacing: 6) {
                        WBubble(icon: c.icon, color: c.color, size: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(c.name).font(.system(size: 11, weight: .medium)).lineLimit(1)
                                Spacer(minLength: 2)
                                Text(WMoney.eur(c.total)).font(.system(size: 11, weight: .bold, design: .rounded)).monospacedDigit().lineLimit(1)
                            }
                            WBar(value: c.total / top, color: Color(wHex: c.color), height: 4)
                        }
                    }
                }
                if d.cats.isEmpty { Text("Sin gastos este mes").font(.caption).foregroundStyle(.white.opacity(0.6)) }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: Inversiones

struct WChange: View {
    var value: Double

    var body: some View {
        Text(WMoney.pct(value))
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .foregroundStyle(value >= 0 ? Color.wGreen : Color.wRed)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background((value >= 0 ? Color.wGreen : Color.wRed).opacity(0.18), in: Capsule())
    }
}

struct WInvest: View {
    var d: WidgetData
    var showList = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label("Inversiones", systemImage: "chart.line.uptrend.xyaxis").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(Color.wGreen)
                Spacer(minLength: 0)
                if showList, let c = d.investChange { WChange(value: c) }
            }
            Spacer(minLength: 0)
            Text(WMoney.eur(d.invest)).font(.system(size: 23, weight: .heavy, design: .rounded)).minimumScaleFactor(0.5).lineLimit(1)
            if !showList, let c = d.investChange {
                HStack(spacing: 4) { WChange(value: c); Text("hoy").font(.system(size: 10)).foregroundStyle(.white.opacity(0.65)) }
            }
            if showList {
                ForEach(d.positions.prefix(3), id: \.self) { p in
                    HStack(spacing: 6) {
                        Text(p.name).font(.system(size: 11, weight: .medium)).lineLimit(1)
                        Spacer(minLength: 4)
                        if let c = p.change { WChange(value: c) }
                        Text(WMoney.eur(p.value)).font(.system(size: 11, weight: .bold, design: .rounded)).monospacedDigit()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: Grande

struct WLarge: View {
    var d: WidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                WGotita(d: d, size: 48)
                VStack(alignment: .leading, spacing: 0) {
                    Text(d.name.map { "Hola, \($0)" } ?? "Hola").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(Color(wHex: d.accent))
                    Text(WMoney.eur(d.netWorth)).font(.system(size: 24, weight: .heavy, design: .rounded)).minimumScaleFactor(0.6).lineLimit(1)
                }
                Spacer(minLength: 0)
                WAddButton(d: d)
            }
            HStack(spacing: 8) {
                ForEach(d.accounts.prefix(4), id: \.self) { a in
                    VStack(spacing: 2) {
                        WBubble(icon: a.icon, color: a.color, size: 28)
                        Text(WMoney.eur(a.value)).font(.system(size: 9, weight: .bold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            if let per = d.perDay, (d.left ?? 0) >= 0 {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles").font(.system(size: 11, weight: .bold)).foregroundStyle(Color(wHex: d.accent))
                    Text("Hoy puedes gastar \(WMoney.eur(per))").font(.system(size: 12, weight: .bold, design: .rounded))
                    Spacer(minLength: 0)
                    Text("\(d.daysLeft ?? 0) días").font(.system(size: 10)).foregroundStyle(.white.opacity(0.6))
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Gastado en \(d.month.lowercased())").font(.system(size: 11)).foregroundStyle(.white.opacity(0.65))
                    Spacer()
                    Text(WMoney.eur(d.spent)).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(Color.wRed)
                }
                if d.budget > 0 { WBar(value: d.spent / d.budget, color: d.spent > d.budget ? .wRed : Color(wHex: d.accent), height: 6) }
            }
            Divider().overlay(.white.opacity(0.1))
            ForEach(d.recent.prefix(4), id: \.self) { m in
                HStack(spacing: 8) {
                    Text(m.icon).font(.system(size: 13)).frame(width: 24, height: 24).background(.white.opacity(0.08), in: Circle())
                    Text(m.title).font(.system(size: 12, weight: .medium)).lineLimit(1)
                    Spacer()
                    Text(WMoney.eur(m.amount)).font(.system(size: 12, weight: .bold, design: .rounded)).monospacedDigit()
                        .foregroundStyle(m.amount >= 0 ? Color.wGreen : .white)
                }
            }
            Spacer(minLength: 0)
        }
    }
}
