import WidgetKit
import SwiftUI

struct Entry: TimelineEntry {
    var date: Date
    var data: WidgetData?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry { Entry(date: .now, data: .sample) }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        if context.isPreview { completion(Entry(date: .now, data: WidgetData.cached() ?? .sample)); return }
        Task { completion(Entry(date: .now, data: await WidgetData.fetch() ?? .sample)) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        Task {
            let e = Entry(date: .now, data: await WidgetData.fetch())
            completion(Timeline(entries: [e], policy: .after(Date().addingTimeInterval(900))))
        }
    }
}

@main
struct VitalidadWidgets: WidgetBundle {
    var body: some Widget {
        ScoresWidget()
        DataWidget()
        LockWidget()
    }
}

/// Fondo y aviso si aún no ha llegado nada.
struct Shell<C: View>: View {
    var entry: Entry
    @ViewBuilder var content: (WidgetData) -> C

    var body: some View {
        Group {
            if let d = entry.data {
                content(d)
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "heart.circle.fill").font(.title2).foregroundStyle(WTone.recovery)
                    Text("Abre Vitalidad").font(.caption.weight(.semibold))
                }
            }
        }
        .fontDesign(.rounded)
        .foregroundStyle(.white)
        .containerBackground(for: .widget) { WTone.background(entry.data?.mood ?? "neutral") }
    }
}

// MARK: - Puntuaciones

struct ScoresWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "puntuaciones", provider: Provider()) { e in ScoresView(entry: e) }
            .configurationDisplayName("Tu día")
            .description("Recuperación, sueño y esfuerzo, con el resumen del día.")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct ScoresView: View {
    @Environment(\.widgetFamily) private var family
    var entry: Entry

    var body: some View {
        Shell(entry: entry) { d in
            switch family {
            case .systemSmall: small(d)
            case .systemLarge: large(d)
            default: medium(d)
            }
        }
    }

    private func small(_ d: WidgetData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                WRing(value: d.recovery, color: WTone.recovery, line: 7, font: .system(size: 22, weight: .bold, design: .rounded))
                    .frame(width: 66, height: 66)
                Spacer(minLength: 0)
            }
            Text("Recuperación").font(.caption2.weight(.bold)).foregroundStyle(WTone.recovery)
            HStack(spacing: 10) {
                mini("moon.zzz.fill", d.sleep, WTone.sleep)
                mini("flame.fill", d.effort, WTone.effort)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func mini(_ symbol: String, _ v: Int?, _ c: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: symbol).font(.caption2).foregroundStyle(c)
            Text(v.map(String.init) ?? "–").font(.caption.weight(.bold)).monospacedDigit()
        }
    }

    private func rings(_ d: WidgetData, size: CGFloat) -> some View {
        HStack(spacing: 10) {
            ring("Recuperación", d.recovery, WTone.recovery, size)
            ring("Sueño", d.sleep, WTone.sleep, size)
            ring("Esfuerzo", d.effort, WTone.effort, size)
        }
    }

    private func ring(_ title: String, _ v: Int?, _ c: Color, _ size: CGFloat) -> some View {
        VStack(spacing: 4) {
            WRing(value: v, color: c, line: size * 0.1, font: .system(size: size * 0.3, weight: .bold, design: .rounded))
                .frame(width: size, height: size)
            Text(title).font(.system(size: 10, weight: .semibold)).foregroundStyle(.white.opacity(0.7)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private func medium(_ d: WidgetData) -> some View {
        HStack(spacing: 14) {
            rings(d, size: 52).frame(width: 190)
            Text(d.summary)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(5)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func large(_ d: WidgetData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            rings(d, size: 76)
            Text(d.summary)
                .font(.subheadline.weight(.semibold))
                .lineLimit(3)
                .minimumScaleFactor(0.85)
            ItemRows(items: Array(d.items.prefix(4)))
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Datos

struct DataWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "datos", provider: Provider()) { e in DataView(entry: e) }
            .configurationDisplayName("Tus datos")
            .description("Las tarjetas que tienes en Hoy, con su estado.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct DataView: View {
    @Environment(\.widgetFamily) private var family
    var entry: Entry

    var body: some View {
        Shell(entry: entry) { d in
            if family == .systemSmall {
                ItemRows(items: Array(d.items.prefix(3)), compact: true)
            } else {
                let items = Array(d.items.prefix(4))
                Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                    GridRow {
                        ForEach(items.prefix(2), id: \.self) { tile($0) }
                    }
                    if items.count > 2 {
                        GridRow {
                            ForEach(items.dropFirst(2), id: \.self) { tile($0) }
                        }
                    }
                }
            }
        }
    }

    private func tile(_ i: WidgetData.Item) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: i.symbol).font(.caption.weight(.semibold)).foregroundStyle(Color(wHex: i.color))
                Spacer()
                Circle().fill(WTone.status(i.status)).frame(width: 7, height: 7)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(i.value).font(.system(size: 20, weight: .bold, design: .rounded)).minimumScaleFactor(0.6).lineLimit(1)
                Text(i.unit).font(.system(size: 10, weight: .semibold)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
            }
            Text(i.title).font(.system(size: 10)).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Filas: icono, nombre, valor y punto de estado.
struct ItemRows: View {
    var items: [WidgetData.Item]
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            ForEach(items, id: \.self) { i in
                HStack(spacing: 6) {
                    Image(systemName: i.symbol).font(.caption.weight(.semibold)).foregroundStyle(Color(wHex: i.color)).frame(width: 16)
                    if !compact {
                        Text(i.title).font(.subheadline).lineLimit(1)
                        Spacer(minLength: 4)
                    }
                    Text(i.value).font((compact ? Font.callout : .subheadline).weight(.bold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                    Text(i.unit).font(.caption2).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                    if compact { Spacer(minLength: 0) }
                    Circle().fill(WTone.status(i.status)).frame(width: 7, height: 7)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Pantalla de bloqueo

struct LockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "bloqueo", provider: Provider()) { e in LockView(entry: e) }
            .configurationDisplayName("Recuperación")
            .description("Tu recuperación en la pantalla de bloqueo.")
            .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct LockView: View {
    @Environment(\.widgetFamily) private var family
    var entry: Entry

    var body: some View {
        let d = entry.data
        Group {
            switch family {
            case .accessoryCircular:
                Gauge(value: Double(d?.recovery ?? 0), in: 0...100) {
                    Image(systemName: "heart.fill")
                } currentValueLabel: {
                    Text(d?.recovery.map(String.init) ?? "–").fontDesign(.rounded)
                }
                .gaugeStyle(.accessoryCircular)
            case .accessoryInline:
                Text("Recuperación \(d?.recovery.map(String.init) ?? "–") · Sueño \(d?.sleep.map(String.init) ?? "–")")
            default:
                VStack(alignment: .leading, spacing: 2) {
                    Text("Vitalidad").font(.headline).widgetAccentable()
                    Text("Recuperación \(d?.recovery.map(String.init) ?? "–")")
                    Text("Sueño \(d?.sleep.map(String.init) ?? "–") · Esfuerzo \(d?.effort.map(String.init) ?? "–")")
                }
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}
