import SwiftUI
import UIKit
import Security

/// Lo que la app deja preparado para los widgets de la pantalla de inicio (en el App Group compartido)
struct WidgetData: Codable {
    struct Acc: Codable, Hashable { var name: String; var icon: String; var color: String; var value: Double }
    struct Cat: Codable, Hashable { var name: String; var icon: String; var color: String; var total: Double }
    struct Pos: Codable, Hashable { var name: String; var value: Double; var change: Double? }
    struct Mov: Codable, Hashable { var title: String; var icon: String; var amount: Double; var date: String }

    var updated = Date()
    var netWorth = 0.0
    var cash = 0.0
    var invest = 0.0
    var investChange: Double? = nil
    var accounts: [Acc] = []
    var month = ""
    var spent = 0.0
    var earned = 0.0
    var budget = 0.0
    var cats: [Cat] = []
    var positions: [Pos] = []
    var recent: [Mov] = []
    var accent = "#e4b3cb"

    static let group = "group.es.david.caudal"
    /// carpeta compartida con el widget: el App Group que tenga de verdad la firma (las apps de instalar a veces le cambian el nombre)
    static let sharedDir: URL? = {
        for id in [group] + profileGroups() {
            guard let u = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) else { continue }
            let probe = u.appendingPathComponent(".probe")
            if (try? Data("ok".utf8).write(to: probe)) != nil { return u }
        }
        return nil
    }()
    /// grupos que trae el perfil de firma metido en la app (embedded.mobileprovision)
    static func profileGroups() -> [String] {
        guard let p = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let d = try? Data(contentsOf: p), let s = String(data: d, encoding: .isoLatin1),
              let a = s.range(of: "<?xml"), let b = s.range(of: "</plist>"),
              let plist = try? PropertyListSerialization.propertyList(from: Data(s[a.lowerBound..<b.upperBound].utf8), format: nil) as? [String: Any],
              let ent = plist["Entitlements"] as? [String: Any] else { return [] }
        return (ent["com.apple.security.application-groups"] as? [String]) ?? []
    }
    static var url: URL? { sharedDir?.appendingPathComponent("widget.json") }

    /// si no hay carpeta compartida: portapapeles privado de Caudal (lo comparten la app y el widget al ir firmados igual)
    private static let pbName = UIPasteboard.Name("es.david.caudal.widget")
    private static let pbType = "es.david.caudal.widget"

    // MARK: llavero compartido (con los certificados de KSign/zsign el perfil permite «EQUIPO.*»)

    /// equipo de la firma: del perfil, o del grupo por defecto del llavero
    static let teamID: String? = {
        if let p = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
           let d = try? Data(contentsOf: p), let s = String(data: d, encoding: .isoLatin1),
           let a = s.range(of: "<?xml"), let b = s.range(of: "</plist>"),
           let plist = try? PropertyListSerialization.propertyList(from: Data(s[a.lowerBound..<b.upperBound].utf8), format: nil) as? [String: Any] {
            if let t = (plist["TeamIdentifier"] as? [String])?.first { return t }
            if let t = (plist["ApplicationIdentifierPrefix"] as? [String])?.first { return t }
        }
        // sin perfil: se mira el grupo que el sistema pone a un elemento de prueba
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: "caudal.probe",
                                kSecAttrService as String: "caudal", kSecReturnAttributes as String: true]
        var out: AnyObject?
        var st = SecItemCopyMatching(q as CFDictionary, &out)
        if st == errSecItemNotFound {
            var add = q; add.removeValue(forKey: kSecReturnAttributes as String); add[kSecValueData as String] = Data("1".utf8)
            SecItemAdd(add as CFDictionary, nil)
            st = SecItemCopyMatching(q as CFDictionary, &out)
        }
        guard st == errSecSuccess, let g = (out as? [String: Any])?[kSecAttrAccessGroup as String] as? String, let dot = g.firstIndex(of: ".") else { return nil }
        return String(g[..<dot])
    }()
    static var keyGroup: String? { teamID.map { "\($0).es.david.caudal.shared" } }
    private static func keyQuery() -> [String: Any]? {
        guard let g = keyGroup else { return nil }
        return [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "es.david.caudal.widget",
                kSecAttrAccount as String: "datos", kSecAttrAccessGroup as String: g]
    }
    @discardableResult
    static func keychainWrite(_ d: Data) -> OSStatus {
        guard let q = keyQuery() else { return errSecMissingEntitlement }
        let st = SecItemUpdate(q as CFDictionary, [kSecValueData as String: d] as CFDictionary)
        if st != errSecItemNotFound { return st }
        var add = q
        add[kSecValueData as String] = d
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(add as CFDictionary, nil)
    }
    static func keychainRead() -> (Data?, OSStatus) {
        guard var q = keyQuery() else { return (nil, errSecMissingEntitlement) }
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        let st = SecItemCopyMatching(q as CFDictionary, &out)
        return (out as? Data, st)
    }

    static func load() -> WidgetData? {
        if let u = url, let d = try? Data(contentsOf: u), let w = try? JSONDecoder().decode(WidgetData.self, from: d) { return w }
        if let d = keychainRead().0, let w = try? JSONDecoder().decode(WidgetData.self, from: d) { return w }
        if let d = UIPasteboard(name: pbName, create: false)?.data(forPasteboardType: pbType), let w = try? JSONDecoder().decode(WidgetData.self, from: d) { return w }
        return nil
    }
    func save() {
        guard let d = try? JSONEncoder().encode(self) else { return }
        if let u = WidgetData.url { try? d.write(to: u, options: .atomic) }
        WidgetData.lastKeychain = WidgetData.keychainWrite(d)
        UIPasteboard(name: WidgetData.pbName, create: true)?.setData(d, forPasteboardType: WidgetData.pbType)
    }
    static var lastKeychain: OSStatus = 0
    /// cómo está llegando la información al widget (para Más → Widgets y para el propio widget)
    static var link: String {
        let g = sharedDir != nil ? "grupo ✓" : "grupo ✗"
        let k = keychainRead().1
        let kc = k == errSecSuccess ? "llavero ✓" : "llavero ✗ \(k)"
        let pb = UIPasteboard(name: pbName, create: false)?.data(forPasteboardType: pbType) != nil ? "portapapeles ✓" : "portapapeles ✗"
        return "\(g) · \(kc) · \(pb) · equipo \(teamID ?? "?")"
    }

    static let sample = WidgetData(netWorth: 1832.40, cash: 232.58, invest: 1599.82, investChange: 0.84,
        accounts: [Acc(name: "Revolut", icon: "🏦", color: "#8fb4ff", value: 127.67), Acc(name: "Trade Republic", icon: "🐷", color: "#e4b3cb", value: 100),
                   Acc(name: "Conjunta", icon: "💞", color: "#f59fc4", value: 4.91), Acc(name: "TR · ETF", icon: "📊", color: "#6fd49b", value: 1599.82)],
        month: "Octubre", spent: 517.48, earned: 441.09, budget: 700,
        cats: [Cat(name: "Comida", icon: "🍔", color: "#ff9f7a", total: 160), Cat(name: "Súper", icon: "🛒", color: "#6fd49b", total: 120),
               Cat(name: "Transporte", icon: "⛽️", color: "#7ac8ff", total: 80), Cat(name: "Ocio", icon: "🎮", color: "#b39cff", total: 45)],
        positions: [Pos(name: "MSCI World", value: 1200, change: 0.9), Pos(name: "Bitcoin", value: 399.82, change: -1.2)],
        recent: [Mov(title: "KFC", icon: "🍔", amount: -10.53, date: "2026-10-20"), Mov(title: "Monster", icon: "☕️", amount: -2, date: "2026-10-20")])
}

enum WMoney {
    private static let f: NumberFormatter = {
        let f = NumberFormatter(); f.locale = Locale(identifier: "es_ES"); f.numberStyle = .decimal
        f.minimumFractionDigits = 2; f.maximumFractionDigits = 2; return f
    }()
    static func eur(_ v: Double) -> String { (f.string(from: NSNumber(value: v)) ?? "0,00") + " €" }
    static func pct(_ v: Double) -> String { (v >= 0 ? "+" : "") + (f.string(from: NSNumber(value: v)) ?? "0") + " %" }
}

extension Color {
    init(wHex: String) {
        let h = wHex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0; Scanner(string: h).scanHexInt64(&v)
        self.init(red: Double((v >> 16) & 0xff) / 255, green: Double((v >> 8) & 0xff) / 255, blue: Double(v & 0xff) / 255)
    }
    static let wGreen = Color(wHex: "#6fd49b")
    static let wRed = Color(wHex: "#ff8686")
}

// MARK: - Vistas de los widgets (también se enseñan dentro de la app, en Más → Widgets)

struct WBalanceSmall: View {
    var d: WidgetData
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Patrimonio", systemImage: "drop.fill").font(.caption2.weight(.bold)).foregroundStyle(Color(wHex: d.accent))
            Spacer(minLength: 0)
            Text(WMoney.eur(d.netWorth)).font(.system(size: 22, weight: .bold, design: .rounded)).minimumScaleFactor(0.5).lineLimit(1)
            Text("Efectivo \(WMoney.eur(d.cash))").font(.caption2).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
            Text("Invertido \(WMoney.eur(d.invest))").font(.caption2).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
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
                Label("Cuentas", systemImage: "drop.fill").font(.caption.weight(.bold)).foregroundStyle(Color(wHex: d.accent))
                Spacer()
                Text(WMoney.eur(d.netWorth)).font(.caption.weight(.bold)).monospacedDigit()
            }
            ForEach(d.accounts.prefix(rows), id: \.self) { a in
                HStack(spacing: 8) {
                    Text(a.icon).font(.callout)
                    Text(a.name).font(.subheadline.weight(.medium)).lineLimit(1)
                    Spacer(minLength: 4)
                    Text(WMoney.eur(a.value)).font(.subheadline.weight(.semibold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

struct WSpentSmall: View {
    var d: WidgetData
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Gastos · \(d.month)", systemImage: "arrow.down.circle.fill").font(.caption2.weight(.bold)).foregroundStyle(Color.wRed).lineLimit(1)
            Spacer(minLength: 0)
            Text(WMoney.eur(d.spent)).font(.system(size: 22, weight: .bold, design: .rounded)).minimumScaleFactor(0.5).lineLimit(1)
            if d.budget > 0 {
                ProgressView(value: min(d.spent / d.budget, 1)).tint(d.spent > d.budget ? Color.wRed : Color(wHex: d.accent))
                Text("de \(WMoney.eur(d.budget))").font(.caption2).foregroundStyle(.secondary)
            } else {
                Text("Ingresos \(WMoney.eur(d.earned))").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct WSpentMedium: View {
    var d: WidgetData
    var body: some View {
        HStack(spacing: 14) {
            WSpentSmall(d: d).frame(width: 120)
            VStack(alignment: .leading, spacing: 6) {
                let total = max(d.cats.reduce(0) { $0 + $1.total }, 0.01)
                ForEach(d.cats.prefix(4), id: \.self) { c in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(c.icon).font(.caption)
                            Text(c.name).font(.caption.weight(.medium)).lineLimit(1)
                            Spacer(minLength: 2)
                            Text(WMoney.eur(c.total)).font(.caption.weight(.semibold)).monospacedDigit().lineLimit(1)
                        }
                        GeometryReader { g in
                            Capsule().fill(Color(wHex: c.color)).frame(width: max(4, g.size.width * c.total / total))
                        }
                        .frame(height: 4)
                    }
                }
                if d.cats.isEmpty { Text("Sin gastos este mes").font(.caption).foregroundStyle(.secondary) }
                Spacer(minLength: 0)
            }
        }
    }
}

struct WInvest: View {
    var d: WidgetData
    var showList = true
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Inversiones", systemImage: "chart.line.uptrend.xyaxis").font(.caption2.weight(.bold)).foregroundStyle(Color.wGreen)
            Spacer(minLength: 0)
            Text(WMoney.eur(d.invest)).font(.system(size: 22, weight: .bold, design: .rounded)).minimumScaleFactor(0.5).lineLimit(1)
            if let c = d.investChange {
                Text("\(WMoney.pct(c)) hoy").font(.caption.weight(.bold)).foregroundStyle(c >= 0 ? Color.wGreen : Color.wRed)
            }
            if showList {
                ForEach(d.positions.prefix(3), id: \.self) { p in
                    HStack {
                        Text(p.name).font(.caption).lineLimit(1)
                        Spacer(minLength: 4)
                        if let c = p.change { Text(WMoney.pct(c)).font(.caption2.weight(.bold)).foregroundStyle(c >= 0 ? Color.wGreen : Color.wRed) }
                        Text(WMoney.eur(p.value)).font(.caption.weight(.semibold)).monospacedDigit()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct WLarge: View {
    var d: WidgetData
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WAccounts(d: d, rows: 5).frame(maxHeight: 150)
            Divider()
            HStack {
                VStack(alignment: .leading) { Text("Gastado en \(d.month.lowercased())").font(.caption).foregroundStyle(.secondary); Text(WMoney.eur(d.spent)).font(.headline).foregroundStyle(Color.wRed) }
                Spacer()
                VStack(alignment: .trailing) { Text("Ingresado").font(.caption).foregroundStyle(.secondary); Text(WMoney.eur(d.earned)).font(.headline).foregroundStyle(Color.wGreen) }
            }
            Divider()
            ForEach(d.recent.prefix(4), id: \.self) { m in
                HStack(spacing: 8) {
                    Text(m.icon)
                    Text(m.title).font(.subheadline).lineLimit(1)
                    Spacer()
                    Text(WMoney.eur(m.amount)).font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(m.amount >= 0 ? Color.wGreen : Color.primary)
                }
            }
            Spacer(minLength: 0)
        }
    }
}
