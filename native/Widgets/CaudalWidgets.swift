import WidgetKit
import SwiftUI

struct Entry: TimelineEntry {
    var date: Date
    var data: WidgetData?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry { Entry(date: Date(), data: .sample) }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        if context.isPreview { completion(Entry(date: Date(), data: WidgetData.cached() ?? .sample)); return }
        Task { completion(Entry(date: Date(), data: await WidgetData.fetch() ?? .sample)) }
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        Task {
            let e = Entry(date: Date(), data: await WidgetData.fetch())
            completion(Timeline(entries: [e], policy: .after(Date().addingTimeInterval(900))))
        }
    }
}

/// fondo, enlace al tocar y aviso si aún no ha llegado nada del servidor
struct Shell<C: View>: View {
    var entry: Entry
    var url = WLink.tab("home")
    @ViewBuilder var content: (WidgetData) -> C
    var body: some View {
        Group {
            if let d = entry.data { content(d) }
            else {
                VStack(spacing: 6) {
                    GotitaStill(mood: .sleepy, size: 44, color: Color(wHex: "#e4b3cb"))
                    Text("Abre Caudal").font(.caption.weight(.semibold))
                }
            }
        }
        .fontDesign(.rounded)
        .foregroundStyle(.white)
        .widgetURL(url)
        .containerBackground(for: .widget) { WBackground(accent: entry.data?.accent ?? "#e4b3cb") }
    }
}

struct AllowanceWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "disponible", provider: Provider()) { e in AllowanceView(entry: e) }
            .configurationDisplayName("Disponible hoy")
            .description("Lo que puedes gastar hoy para llegar a fin de mes, con Gotita.")
            .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}
struct AllowanceView: View {
    @Environment(\.widgetFamily) var family
    var entry: Entry
    var body: some View {
        switch family {
        case .accessoryInline:
            Text("Hoy puedes gastar \(WMoney.eur(entry.data?.perDay ?? 0))")
                .widgetURL(WLink.tab("home"))
                .containerBackground(for: .widget) { Color.clear }
        case .accessoryRectangular:
            let d = entry.data ?? WidgetData()
            VStack(alignment: .leading, spacing: 1) {
                Text("Hoy puedes gastar").font(.caption2.weight(.bold))
                Text(WMoney.eur(d.perDay ?? 0)).font(.headline).widgetAccentable()
                Text("quedan \(d.daysLeft ?? 0) días").font(.caption2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .widgetURL(WLink.tab("home"))
            .containerBackground(for: .widget) { Color.clear }
        case .systemSmall:
            Shell(entry: entry) { WAllowanceSmall(d: $0) }
        default:
            Shell(entry: entry) { WAllowanceMedium(d: $0) }
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
        Shell(entry: entry, url: family == .systemLarge ? WLink.tab("home") : WLink.tab("debts")) { d in
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
            .description("Lo que llevas gastado, en qué, y un botón para apuntar.")
            .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}
struct SpentView: View {
    @Environment(\.widgetFamily) var family
    var entry: Entry
    var body: some View {
        switch family {
        case .accessoryInline:
            Text("Gastado: \(WMoney.eur(entry.data?.spent ?? 0))")
                .widgetURL(WLink.tab("txs"))
                .containerBackground(for: .widget) { Color.clear }
        case .accessoryCircular:
            let d = entry.data ?? WidgetData()
            Gauge(value: d.budget > 0 ? min(d.spent / d.budget, 1) : 0) { Image(systemName: "eurosign") } currentValueLabel: { Text("\(Int(d.spent))") }
                .gaugeStyle(.accessoryCircularCapacity)
                .widgetURL(WLink.new)
                .containerBackground(for: .widget) { Color.clear }
        case .accessoryRectangular:
            let d = entry.data ?? WidgetData()
            VStack(alignment: .leading, spacing: 2) {
                Text("Gastos · \(d.month)").font(.caption2.weight(.bold))
                Text(WMoney.eur(d.spent)).font(.headline).widgetAccentable()
                if d.budget > 0 { ProgressView(value: min(d.spent / d.budget, 1)) }
            }
            .widgetURL(WLink.tab("txs"))
            .containerBackground(for: .widget) { Color.clear }
        case .systemSmall:
            Shell(entry: entry, url: WLink.tab("txs")) { WSpentSmall(d: $0) }
        default:
            Shell(entry: entry, url: WLink.tab("txs")) { WSpentMedium(d: $0) }
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
        Shell(entry: entry, url: WLink.tab("invest")) { WInvest(d: $0, showList: family != .systemSmall) }
    }
}

@main
struct CaudalWidgetBundle: WidgetBundle {
    var body: some Widget {
        AllowanceWidget()
        BalanceWidget()
        SpentWidget()
        InvestWidget()
    }
}
