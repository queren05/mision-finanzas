import SwiftUI
import Charts

struct NutritionView: View {
    @Environment(HealthStore.self) private var store
    @State private var yesterday = false
    @Namespace private var zoom

    private var day: Date { yesterday ? Calendar.current.date(byAdding: .day, value: -1, to: store.today)! : store.today }

    var body: some View {
        let hasAny = [Metric.calories, .protein, .carbs, .fat, .water].contains { store.has($0) }
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                if hasAny {
                    Picker("Día", selection: $yesterday.animation(.smooth)) {
                        Text("Hoy").tag(false)
                        Text("Ayer").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, Space.xs)

                    BalanceCard(day: day, isToday: !yesterday).stagger(0)
                    MacrosCard(day: day).stagger(1).scrollFade()
                    if let water = store.value(.water, on: day) {
                        waterCard(water).stagger(2).scrollFade()
                    }
                    NavigationLink(value: Metric.calories) {
                        VStack(alignment: .leading, spacing: Space.m) {
                            Label("Últimos 7 días", systemImage: "chart.bar.fill").font(.headline).foregroundStyle(Palette.nutrition)
                            MetricChart(metric: .calories, points: store.series(.calories, days: 7, includeToday: false), baseline: nil, bars: true)
                                .frame(height: 150)
                        }
                        .card()
                        .zoomSource(Metric.calories, zoom)
                    }
                    .buttonStyle(.plain)
                    .stagger(3)
                    .scrollFade()
                } else {
                    EmptyCard(symbol: "fork.knife", color: Palette.nutrition, title: "Sin datos de nutrición",
                              text: "Activa en los ajustes de Yazio la conexión con Apple Salud y aquí verás lo que comes.")
                }
            }
            .padding(.horizontal, Space.l)
            .padding(.bottom, Space.xxl)
        }
        .background(MoodBackground(mood: .neutral))
        .navigationTitle("Nutrición")
        .navigationDestination(for: Metric.self) { m in MetricDetailView(metric: m).zoomDestination(m, zoom) }
        .refreshable { await store.refresh(full: false) }
        .sensoryFeedback(.selection, trigger: yesterday)
    }

    private func waterCard(_ liters: Double) -> some View {
        HStack(spacing: Space.m) {
            MetricGlyph(symbol: Metric.water.symbol, color: Palette.breath, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(Fmt.value(.water, liters)).bigFont(32)
                    Text("l de agua").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                }
                Text(liters >= 2 ? "Bien hidratado." : liters >= 1.2 ? "Algo justo: un par de vasos más no vendrían mal." : "Poca agua apuntada. Bebe un poco más.")
                    .font(.subheadline)
            }
        }
        .card()
    }
}

/// Lo que has comido frente a lo que has gastado.
struct BalanceCard: View {
    var day: Date
    var isToday: Bool
    @Environment(HealthStore.self) private var store

    var body: some View {
        let eaten = store.value(.calories, on: day) ?? 0
        let active = store.value(.activeEnergy, on: day) ?? 0
        let basal = store.value(.basalEnergy, on: day) ?? (store.baseline(.basalEnergy)?.median ?? 0)
        let burned = active + basal
        VStack(alignment: .leading, spacing: Space.l) {
            HStack(spacing: Space.l) {
                ZStack {
                    Ring(progress: burned > 0 ? min(1, eaten / burned) : 0, color: Palette.nutrition, lineWidth: 12)
                    VStack(spacing: 0) {
                        Text(Fmt.value(.calories, eaten)).bigFont(24)
                            .minimumScaleFactor(0.6).lineLimit(1)
                        Text(Fmt.energyUnit).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    }
                    .padding(Space.l)
                }
                .frame(width: 112, height: 112)
                VStack(alignment: .leading, spacing: Space.s) {
                    row("Comido", eaten, Palette.nutrition)
                    row("Gastado", burned, Palette.effort)
                    if burned > 0 {
                        let diff = eaten - burned
                        row(diff >= 0 ? "De más" : "De menos", abs(diff), .secondary)
                    }
                }
            }
            Text(sentence(eaten: eaten, burned: burned, active: active))
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card(tint: Palette.nutrition)
    }

    private func row(_ title: String, _ v: Double, _ color: Color) -> some View {
        HStack {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(Fmt.full(.calories, v)).font(.subheadline.weight(.semibold)).foregroundStyle(color).monospacedDigit()
        }
    }

    private func sentence(eaten: Double, burned: Double, active: Double) -> String {
        guard eaten > 0 else { return isToday ? "Aún no has apuntado comidas hoy." : "No apuntaste comidas ese día." }
        guard burned > 0 else { return "Has comido \(Fmt.full(.calories, eaten))." }
        let diff = eaten - burned
        let d = Fmt.full(.calories, abs(diff))
        let effortHigh = (store.baseline(.activeEnergy)?.median).map { active > $0 * 1.3 } ?? false
        if isToday {
            if diff < -500 && effortHigh { return "Hoy te estás moviendo mucho y vas \(d) por debajo. Come algo con carbohidratos para recuperar." }
            if diff < 0 { return "Llevas \(d) menos de lo que has gastado. El día no ha acabado: es normal ir por debajo a estas horas." }
            return "Llevas \(d) más de lo que has gastado hasta ahora."
        }
        if abs(diff) < 200 { return "Comiste más o menos lo que gastaste (\(d) de diferencia). Peso estable." }
        if diff < 0 { return "Comiste \(d) menos de lo que gastaste. Si buscas bajar de peso, vas bien; si no, come un poco más." }
        return "Comiste \(d) más de lo que gastaste. Si se repite muchos días, el peso subirá."
    }
}

/// Proteínas, carbohidratos y grasas, con lo que aporta cada uno.
struct MacrosCard: View {
    var day: Date
    @Environment(HealthStore.self) private var store

    var body: some View {
        let p = store.value(.protein, on: day) ?? 0
        let c = store.value(.carbs, on: day) ?? 0
        let f = store.value(.fat, on: day) ?? 0
        let kcal = max(1, p * 4 + c * 4 + f * 9)
        VStack(alignment: .leading, spacing: Space.m) {
            Label("Macros", systemImage: "chart.pie.fill").font(.headline).foregroundStyle(Palette.nutrition)
            GeometryReader { geo in
                HStack(spacing: 3) {
                    Capsule().fill(Color(red: 1.0, green: 0.42, blue: 0.5)).frame(width: max(4, geo.size.width * p * 4 / kcal))
                    Capsule().fill(Color(red: 1.0, green: 0.72, blue: 0.3)).frame(width: max(4, geo.size.width * c * 4 / kcal))
                    Capsule().fill(Color(red: 0.75, green: 0.55, blue: 1.0)).frame(width: max(4, geo.size.width * f * 9 / kcal))
                }
            }
            .frame(height: 12)
            macro("Proteínas", p, p * 4 / kcal, Color(red: 1.0, green: 0.42, blue: 0.5))
            macro("Carbohidratos", c, c * 4 / kcal, Color(red: 1.0, green: 0.72, blue: 0.3))
            macro("Grasas", f, f * 9 / kcal, Color(red: 0.75, green: 0.55, blue: 1.0))
            Text(sentence(protein: p))
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Space.xs)
        }
        .card()
    }

    private func macro(_ name: String, _ g: Double, _ share: Double, _ color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(name).font(.subheadline)
            Spacer()
            Text("\(Fmt.number(g)) g").font(.subheadline.weight(.semibold)).monospacedDigit()
            Text("\(Int((share * 100).rounded())) %").font(.footnote).foregroundStyle(.secondary).monospacedDigit()
                .frame(width: 44, alignment: .trailing)
        }
    }

    private func sentence(protein: Double) -> String {
        guard protein > 0 else { return "Sin macros apuntados." }
        guard let kg = store.latest(.weight, within: 60)?.value, kg > 30 else {
            return "\(Fmt.number(protein)) g de proteína. Si apuntas tu peso en Salud, te diré si es suficiente para ti."
        }
        let perKg = protein / kg
        let s = Fmt.number(perKg, decimals: 1)
        if perKg >= 1.4 { return "\(s) g de proteína por kilo: buena cantidad para recuperar y mantener músculo." }
        if perKg >= 1.0 { return "\(s) g de proteína por kilo: correcto, aunque si entrenas fuerte te vendría bien llegar a 1,4–1,6." }
        return "\(s) g de proteína por kilo: algo bajo. Añade huevos, legumbres, yogur o carne a alguna comida."
    }
}

#Preview {
    NavigationStack { NutritionView() }
        .environment(HealthStore.preview())
        .fontDesign(.rounded)
        .preferredColorScheme(.dark)
}
