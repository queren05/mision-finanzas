import WidgetKit
import SwiftUI

struct Entry: TimelineEntry {
    var date: Date
    var data: WidgetData?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry { Entry(date: Date(), data: .sample) }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: Date(), data: WidgetData.load() ?? .sample))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let e = Entry(date: Date(), data: WidgetData.load())
        completion(Timeline(entries: [e], policy: .after(Date().addingTimeInterval(1800))))
    }
}

/// fondo y aviso si aún no hay datos (hay que abrir Caudal una vez)
struct Shell<C: View>: View {
    var entry: Entry
    @ViewBuilder var content: (WidgetData) -> C
    var body: some View {
        Group {
            if let d = entry.data { content(d) }
            else {
                VStack(spacing: 6) {
                    Image(systemName: "drop.fill").font(.title2).foregroundStyle(Color(wHex: "#e4b3cb"))
                    Text("Abre Caudal").font(.caption.weight(.semibold))
                }
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(colors: [Color(wHex: "#1c1b22"), Color(wHex: "#111014")], startPoint: .top, endPoint: .bottom)
        }
    }
}

struct BalanceWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "saldo", provider: Provider()) { e in BalanceView(entry: e) }
            .configurationDisplayName("Cuentas")
            .description("Tu patrimonio y el saldo de cada cuenta.")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
struct BalanceView: View {
    @Environment(\.widgetFamily) var family
    var entry: Entry
    var body: some View {
        Shell(entry: entry) { d in
            switch family {
            case .systemSmall: WBalanceSmall(d: d)
            case .systemLarge: WLarge(d: d)
            default: WAccounts(d: d)
            }
        }
    }
}

struct SpentWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "gastos", provider: Provider()) { e in SpentView(entry: e) }
            .configurationDisplayName("Gastos del mes")
            .description("Lo que llevas gastado y en qué.")
            .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}
struct SpentView: View {
    @Environment(\.widgetFamily) var family
    var entry: Entry
    var body: some View {
        switch family {
        case .accessoryInline:
            Text("Gastado: \(WMoney.eur(entry.data?.spent ?? 0))").containerBackground(for: .widget) { Color.clear }
        case .accessoryCircular:
            let d = entry.data ?? WidgetData()
            Gauge(value: d.budget > 0 ? min(d.spent / d.budget, 1) : 0) { Image(systemName: "eurosign") } currentValueLabel: { Text("\(Int(d.spent))") }
                .gaugeStyle(.accessoryCircular)
                .containerBackground(for: .widget) { Color.clear }
        case .accessoryRectangular:
            let d = entry.data ?? WidgetData()
            VStack(alignment: .leading, spacing: 2) {
                Text("Gastos · \(d.month)").font(.caption2.weight(.bold))
                Text(WMoney.eur(d.spent)).font(.headline)
                if d.budget > 0 { ProgressView(value: min(d.spent / d.budget, 1)) }
            }
            .containerBackground(for: .widget) { Color.clear }
        case .systemSmall:
            Shell(entry: entry) { WSpentSmall(d: $0) }
        default:
            Shell(entry: entry) { WSpentMedium(d: $0) }
        }
    }
}

struct InvestWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "inversiones", provider: Provider()) { e in InvestView(entry: e) }
            .configurationDisplayName("Inversiones")
            .description("Lo que valen tus inversiones y cómo van hoy.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}
struct InvestView: View {
    @Environment(\.widgetFamily) var family
    var entry: Entry
    var body: some View {
        Shell(entry: entry) { WInvest(d: $0, showList: family != .systemSmall) }
    }
}

@main
struct CaudalWidgetBundle: WidgetBundle {
    var body: some Widget {
        BalanceWidget()
        SpentWidget()
        InvestWidget()
    }
}
