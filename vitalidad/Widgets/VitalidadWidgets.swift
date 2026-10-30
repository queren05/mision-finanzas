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
        DayWidget()
        AdviceWidget()
        StepsWidget()
        DataWidget()
        LockWidget()
    }
}

/// Fondo, enlace al tocar y aviso si aún no ha llegado nada.
struct Shell<C: View>: View {
    var entry: Entry
    var url: URL = WLink.tab("today")
    @ViewBuilder var content: (WidgetData) -> C

    var body: some View {
        Group {
            if let d = entry.data {
                content(d)
            } else {
                VStack(spacing: 6) {
                    Latido(mood: .sleepy, size: 44)
                    Text("Abre Vitalidad").font(.caption.weight(.semibold))
                }
            }
        }
        .fontDesign(.rounded)
        .foregroundStyle(.white)
        .widgetURL(url)
        .containerBackground(for: .widget) { WBackground(mood: entry.data?.mood ?? "neutral") }
    }
}

struct DayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "puntuaciones", provider: Provider()) { e in DayView(entry: e) }
            .configurationDisplayName("Tu día")
            .description("Latido, tu recuperación, el sueño y el esfuerzo.")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct DayView: View {
    @Environment(\.widgetFamily) private var family
    var entry: Entry

    var body: some View {
        Shell(entry: entry) { d in
            switch family {
            case .systemSmall: VWDaySmall(d: d)
            case .systemLarge: VWDayLarge(d: d)
            default: VWDayMedium(d: d)
            }
        }
    }
}

struct AdviceWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "consejo", provider: Provider()) { e in
            Shell(entry: e) { VWAdviceSmall(d: $0) }
        }
        .configurationDisplayName("Para hoy")
        .description("Qué te conviene hoy, en una frase.")
        .supportedFamilies([.systemSmall])
    }
}

struct StepsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "pasos", provider: Provider()) { e in
            Shell(entry: e, url: WLink.detail("steps")) { VWStepsSmall(d: $0) }
        }
        .configurationDisplayName("Pasos")
        .description("Tus pasos de hoy frente a un día normal tuyo.")
        .supportedFamilies([.systemSmall])
    }
}

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
            if family == .systemSmall { VWDataSmall(d: d) } else { VWDataMedium(d: d) }
        }
    }
}

// MARK: - Pantalla de bloqueo

struct LockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "bloqueo", provider: Provider()) { e in LockView(entry: e) }
            .configurationDisplayName("Recuperación")
            .description("Tu recuperación y tus pasos en la pantalla de bloqueo.")
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
                .gaugeStyle(.accessoryCircularCapacity)
            case .accessoryInline:
                Label("Recuperación \(d?.recovery.map(String.init) ?? "–") · Sueño \(d?.sleep.map(String.init) ?? "–")", systemImage: "heart.fill")
            default:
                HStack(spacing: 8) {
                    Gauge(value: Double(d?.recovery ?? 0), in: 0...100) {
                        Image(systemName: "heart.fill")
                    } currentValueLabel: {
                        Text(d?.recovery.map(String.init) ?? "–")
                    }
                    .gaugeStyle(.accessoryCircularCapacity)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Sueño \(d?.sleep.map(String.init) ?? "–") · Esfuerzo \(d?.effort.map(String.init) ?? "–")")
                            .font(.caption2.weight(.semibold))
                        if let s = d?.stepsNow { Text("\(WNum.int(s)) pasos").font(.caption2) }
                        Text(d?.advice ?? "").font(.caption2).lineLimit(1)
                    }
                    .widgetAccentable()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .fontDesign(.rounded)
        .widgetURL(WLink.tab("today"))
        .containerBackground(for: .widget) { Color.clear }
    }
}
