import SwiftUI
import Charts

// MARK: - Días anteriores

/// Las dos últimas semanas en una tira: toca un día para verlo entero.
struct DayStrip: View {
    @Environment(HealthStore.self) private var store
    @Binding var selected: Date

    var body: some View {
        let days = Calendar.current.days(back: 14, from: store.today)
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(days, id: \.self) { d in
                        cell(d).id(d)
                    }
                }
                .padding(.horizontal, Space.xs)
            }
            .onAppear { proxy.scrollTo(selected, anchor: .trailing) }
        }
        .sensoryFeedback(.selection, trigger: selected)
    }

    private func cell(_ d: Date) -> some View {
        let r = ScoreEngine.report(store, day: d)
        let rec = r.recovery?.value
        let eff = r.effort?.value
        let on = store.dayStart(d) == store.dayStart(selected)
        let tone = rec.map { RGB.mix(RGB.readiness, Double($0) / 100).color } ?? .secondary
        return Button {
            withAnimation(.snappy) { selected = store.dayStart(d) }
        } label: {
            VStack(spacing: 5) {
                Text(store.isToday(d) ? "HOY" : Fmt.day(d, style: "EEEEE").uppercased())
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(0.6)
                    .foregroundStyle(on ? .primary : .secondary)
                ZStack {
                    Circle().stroke(tone.opacity(0.2), lineWidth: 3.5)
                    Circle().trim(from: 0, to: Double(rec ?? 0) / 100)
                        .stroke(tone, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(Fmt.day(d, style: "d"))
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .monospacedDigit()
                }
                .frame(width: 36, height: 36)
                Capsule().fill(Palette.effort.opacity(0.18))
                    .frame(width: 26, height: 4)
                    .overlay(alignment: .leading) {
                        Capsule().fill(Palette.effort).frame(width: 26 * Double(eff ?? 0) / 100, height: 4)
                    }
            }
            .padding(.vertical, 8)
            .frame(width: 48)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(on ? Ink.surfaceHigh : .clear)
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(on ? Ink.hairline.opacity(0.25) : .clear))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Fmt.day(d, style: "EEEE d"))
        .accessibilityValue(rec.map { "Recuperación \($0)" } ?? "")
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

// MARK: - Estrés

struct StressCard: View {
    @Environment(HealthStore.self) private var store
    var day: Date

    var body: some View {
        let hours = StressEngine.hours(store, day: day)
        if let v = StressEngine.score(store, day: day) {
            let (label, color) = StressEngine.label(v)
            let cal = Calendar.current
            let start = store.dayStart(day)
            let end = cal.date(byAdding: .day, value: 1, to: start)!
            let week = cal.days(back: 7, from: day).compactMap { d in StressEngine.score(store, day: d).map { (d, $0) } }
            VStack(alignment: .leading, spacing: Space.l) {
                CardHeader("Estrés", symbol: "brain.head.profile", color: color, trailing: label)
                HStack(alignment: .center, spacing: Space.l) {
                    ZStack {
                        Circle().stroke(color.opacity(0.18), lineWidth: 9)
                        Circle().trim(from: 0, to: Double(v) / 100)
                            .stroke(AngularGradient(colors: [Palette.good, Palette.effort, Palette.heart], center: .center, startAngle: .degrees(0), endAngle: .degrees(360 * Double(v) / 100)),
                                    style: StrokeStyle(lineWidth: 9, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        CountingNumber(value: v)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                    }
                    .frame(width: 86, height: 86)
                    Text(StressEngine.sentence(v, hours: hours))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                StressStrip(hours: hours, start: start, end: end)
                if week.count >= 3 {
                    Chart(week, id: \.0) { item in
                        BarMark(x: .value("Día", item.0, unit: .day), y: .value("Estrés", item.1), width: .ratio(0.55))
                            .foregroundStyle(StressEngine.label(item.1).1.gradient)
                            .cornerRadius(4)
                            .opacity(cal.isDate(item.0, inSameDayAs: day) ? 1 : 0.55)
                    }
                    .chartYScale(domain: 0...100)
                    .chartYAxis(.hidden)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { v in
                            AxisValueLabel {
                                if let d = v.as(Date.self) { Text(Fmt.day(d, style: "EEEEE").uppercased()).font(.caption2.weight(.semibold)) }
                            }
                        }
                    }
                    .frame(height: 70)
                }
            }
            .card(tint: color)
        }
    }
}

// MARK: - Trabajo

/// Pregunta una vez si tu trabajo es físico.
struct WorkAskCard: View {
    @Environment(HealthStore.self) private var store
    @AppStorage(WorkSchedule.askedKey) private var asked = false
    @AppStorage(WorkSchedule.kindKey) private var kind = JobKind.physical.rawValue
    @State private var edit = false

    var body: some View {
        if !asked && !Launch.demo {
            VStack(alignment: .leading, spacing: Space.m) {
                CardHeader("Tu trabajo", symbol: "briefcase.fill", color: Palette.effort)
                Text("¿Tu trabajo es físico?").font(.title3.weight(.bold))
                HStack(spacing: Space.s) {
                    ForEach(JobKind.allCases.reversed()) { k in
                        Button {
                            kind = k.rawValue
                            asked = true
                            store.invalidate()
                            if k != .none { edit = true }
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: k.symbol).font(.title3)
                                Text(k.short).font(.caption.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Space.m)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.effort.opacity(k == .none ? 0.08 : 0.16)))
                            .foregroundStyle(k == .none ? Color.secondary : Palette.effort)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .card()
            .sheet(isPresented: $edit) { NavigationStack { WorkSettingsView() } }
        }
    }
}

/// Tipo de trabajo y el horario de cada día.
struct WorkSettingsView: View {
    @Environment(HealthStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage(WorkSchedule.kindKey) private var kind = JobKind.physical.rawValue
    @AppStorage(WorkSchedule.scheduleKey) private var raw = WorkSchedule.defaultSchedule
    @AppStorage(WorkSchedule.askedKey) private var asked = false
    var inSheet = true

    private let weekdays: [(Int, String)] = [(2, "Lunes"), (3, "Martes"), (4, "Miércoles"), (5, "Jueves"), (6, "Viernes"), (7, "Sábado"), (1, "Domingo")]

    var body: some View {
        let shifts = WorkSchedule.decode(raw)
        Form {
            Section("Tipo de trabajo") {
                Picker("Tipo", selection: $kind) {
                    ForEach(JobKind.allCases) { k in
                        Label(k.title, systemImage: k.symbol).tag(k.rawValue)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            if kind != JobKind.none.rawValue {
                Section("Horario") {
                    ForEach(weekdays, id: \.0) { d in
                        let s = shifts[d.0]
                        Toggle(d.1, isOn: Binding(
                            get: { s != nil },
                            set: { on in
                                var m = shifts
                                m[d.0] = on ? (m[d.0] ?? shifts.values.first ?? WorkSchedule.Shift(from: 1050, to: 1350)) : nil
                                raw = WorkSchedule.encode(m)
                            }))
                        if let s {
                            HStack {
                                DatePicker("Entro", selection: time(d.0, s, start: true), displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                Image(systemName: "arrow.right").font(.caption).foregroundStyle(.secondary)
                                DatePicker("Salgo", selection: time(d.0, s, start: false), displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                Spacer()
                                Text(Fmt.duration(Double(s.to - s.from) * 60)).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(MoodBackground(mood: .neutral))
        .navigationTitle("Tu trabajo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if inSheet {
                ToolbarItem(placement: .confirmationAction) { Button("Listo") { dismiss() } }
            }
        }
        .onChange(of: kind) { _, _ in asked = true; store.invalidate() }
        .onChange(of: raw) { _, _ in store.invalidate() }
    }

    private func time(_ day: Int, _ s: WorkSchedule.Shift, start: Bool) -> Binding<Date> {
        Binding(
            get: { Calendar.current.startOfDay(for: .now).addingTimeInterval(Double(start ? s.from : s.to) * 60) },
            set: { d in
                let c = Calendar.current.dateComponents([.hour, .minute], from: d)
                let m = (c.hour ?? 0) * 60 + (c.minute ?? 0)
                var all = WorkSchedule.decode(raw)
                var n = s
                if start { n.from = m } else { n.to = m == 0 ? 1440 : m }
                if n.to > n.from { all[day] = n; raw = WorkSchedule.encode(all) }
            })
    }
}

/// Tu jornada: cuánto te ha cargado el trabajo.
struct WorkCard: View {
    @Environment(HealthStore.self) private var store
    var day: Date
    @State private var edit = false

    var body: some View {
        let work = WorkSchedule.current
        let h = store.dayHours(day)
        let inWork = { (p: TimePoint) in work.isWorkHour(p.date) }
        let hr = h.hr.filter { inWork($0) && $0.value > 0 }
        if work.isWorkDay(day), hr.count >= 2 {
            let steps = h.steps.filter(inWork).reduce(0) { $0 + $1.value }
            let kcal = h.energy.filter(inWork).reduce(0) { $0 + $1.value }
            let dayKcal = h.energy.reduce(0) { $0 + $1.value }
            let avgHR = hr.reduce(0) { $0 + $1.value } / Double(hr.count)
            let load = HeartLoad.points(store, day: day, onlyWork: true) ?? 0
            let (label, color) = HeartLoad.level(load)
            let (start, end) = work.bounds(on: day) ?? (store.dayStart(day), store.dayStart(day).addingTimeInterval(3600))
            VStack(alignment: .leading, spacing: Space.l) {
                HStack {
                    CardHeader("Tu jornada", symbol: work.kind.symbol, color: Palette.effort, trailing: work.hoursText(on: day))
                    Button { edit = true } label: { Image(systemName: "pencil").font(.caption.weight(.bold)).foregroundStyle(.secondary) }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Cambiar tu trabajo")
                }
                HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                    Text("Carga física").font(.title3.weight(.bold))
                    Text(label).font(.title3.weight(.bold)).foregroundStyle(color)
                    Spacer()
                    if dayKcal > 0 {
                        Text("\(Int((kcal / dayKcal * 100).rounded())) % del día")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Capsule().fill(Palette.effort.opacity(0.16)))
                            .foregroundStyle(Palette.effort)
                    }
                }
                Chart {
                    ForEach(h.energy.filter(inWork), id: \.date) { p in
                        BarMark(x: .value("Hora", p.date, unit: .hour), y: .value("Energía", Fmt.energy(p.value)), width: .ratio(0.7))
                            .foregroundStyle(Palette.effort.gradient)
                            .cornerRadius(4)
                    }
                    ForEach(hr, id: \.date) { p in
                        LineMark(x: .value("Hora", p.date.addingTimeInterval(1800)), y: .value("Pulso", p.value), series: .value("s", "pulso"))
                            .foregroundStyle(Palette.heart)
                            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                            .interpolationMethod(.catmullRom)
                    }
                }
                .chartXScale(domain: (Calendar.current.dateInterval(of: .hour, for: start)?.start ?? start)...(Calendar.current.dateInterval(of: .hour, for: end.addingTimeInterval(-1))?.end ?? end))
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: max(1, Int(end.timeIntervalSince(start) / 3600) / 4))) { v in
                        AxisValueLabel { if let d = v.as(Date.self) { Text(Fmt.clock(d)).font(.caption2) } }
                    }
                }
                .frame(height: 90)
                HStack(spacing: 0) {
                    stat(Fmt.full(.activeEnergy, kcal), "activas", Palette.effort)
                    stat("\(Fmt.number(avgHR)) lpm", "pulso medio", Palette.heart)
                    stat(Fmt.number(steps), "pasos", Palette.breath)
                }
            }
            .card(tint: Palette.effort)
            .sheet(isPresented: $edit) { NavigationStack { WorkSettingsView() } }
        }
    }

    private func stat(_ v: String, _ l: String, _ c: Color) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.system(.headline, design: .rounded).weight(.bold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
            Text(l).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Edad del cuerpo

struct BioAgeCard: View {
    @Environment(HealthStore.self) private var store
    @State private var ask = false

    var body: some View {
        if let r = BioAge.today(store) {
            let younger = r.diff < 0
            let tone = younger ? Palette.good : r.diff < 2 ? Palette.effort : Palette.heart
            let hist = BioAge.history(store)
            VStack(alignment: .leading, spacing: Space.l) {
                CardHeader("Edad de tu cuerpo", symbol: "hourglass", color: tone, trailing: "Real \(Int(r.real))")
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(BioAge.ageText(r.age))
                        .font(.system(size: 54, weight: .bold, design: .rounded))
                        .tracking(-1.5)
                        .contentTransition(.numericText())
                    Text("años").font(.title3.weight(.semibold)).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(younger ? "−" : "+")\(BioAge.ageText(abs(r.diff)))")
                        .font(.headline.weight(.bold))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(tone.opacity(0.18)))
                        .foregroundStyle(tone)
                }
                if hist.count >= 3 {
                    Chart(hist, id: \.date) { p in
                        LineMark(x: .value("Fecha", p.date), y: .value("Edad", p.value))
                            .foregroundStyle(tone)
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .interpolationMethod(.catmullRom)
                        PointMark(x: .value("Fecha", p.date), y: .value("Edad", p.value))
                            .foregroundStyle(tone)
                            .symbolSize(22)
                    }
                    .chartYScale(domain: (hist.map(\.value).min()! - 1)...(hist.map(\.value).max()! + 1))
                    .chartYAxis {
                        AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                            AxisGridLine().foregroundStyle(.secondary.opacity(0.15))
                            AxisValueLabel().font(.caption2)
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .month)) { v in
                            AxisValueLabel { if let d = v.as(Date.self) { Text(Fmt.day(d, style: "MMM")).font(.caption2) } }
                        }
                    }
                    .frame(height: 80)
                }
                VStack(spacing: Space.m) {
                    ForEach(r.parts) { p in
                        HStack(spacing: Space.m) {
                            Image(systemName: p.symbol).font(.footnote.weight(.semibold)).foregroundStyle(p.color).frame(width: 20)
                            Text(p.title).font(.subheadline.weight(.medium))
                            Text(p.value).font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text("\(p.years <= 0 ? "−" : "+")\(BioAge.ageText(abs(p.years)))")
                                .font(.subheadline.weight(.bold).monospacedDigit())
                                .foregroundStyle(p.years <= -0.05 ? Palette.good : p.years >= 0.05 ? Palette.heart : .secondary)
                        }
                    }
                }
            }
            .card(tint: tone)
        } else if BioAge.realAge(store) == nil {
            Button { ask = true } label: {
                HStack(spacing: Space.m) {
                    MetricGlyph(symbol: "hourglass", color: Palette.recovery, size: 34)
                    Text("Edad de tu cuerpo").font(.headline).foregroundStyle(.primary)
                    Spacer()
                    Text("Pon tu edad").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.recovery)
                    Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .card()
            .sheet(isPresented: $ask) { NavigationStack { AgeSettingsView() } }
        }
    }
}

/// Edad y sexo, si no están en Salud.
struct AgeSettingsView: View {
    @Environment(HealthStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage(BioAge.ageKey) private var age = 0
    @AppStorage(BioAge.sexKey) private var sex = "hombre"
    var inSheet = true

    var body: some View {
        Form {
            if let b = store.profile.birth {
                LabeledContent("Fecha de nacimiento", value: Fmt.day(b, style: "d MMM yyyy"))
            } else {
                Stepper(age > 0 ? "\(age) años" : "Sin poner", value: $age, in: 0...100)
            }
            if store.profile.female == nil {
                Picker("Sexo", selection: $sex) {
                    Text("Hombre").tag("hombre")
                    Text("Mujer").tag("mujer")
                }
                .pickerStyle(.segmented)
            }
        }
        .scrollContentBackground(.hidden)
        .background(MoodBackground(mood: .neutral))
        .navigationTitle("Tu edad")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if inSheet { ToolbarItem(placement: .confirmationAction) { Button("Listo") { dismiss() } } }
        }
        .onAppear { if age == 0 && store.profile.birth == nil { age = 30 } }
        .onChange(of: age) { _, _ in store.invalidate() }
        .onChange(of: sex) { _, _ in store.invalidate() }
    }
}

// MARK: - Edad biológica: acceso rápido y pantalla

/// Debajo de los anillos: tu edad biológica frente a la real.
struct BioAgeTile: View {
    @Environment(HealthStore.self) private var store
    @State private var open = Launch.args.contains("-edad")
    @State private var ask = false

    var body: some View {
        if let r = BioAge.today(store) {
            let younger = r.diff < 0
            let tone = younger ? Palette.good : r.diff < 2 ? Palette.effort : Palette.heart
            Button { open = true } label: {
                HStack(spacing: Space.l) {
                    ZStack {
                        Circle().fill(tone.opacity(0.16))
                        Image(systemName: "hourglass").font(.title3.weight(.bold)).foregroundStyle(tone)
                    }
                    .frame(width: 46, height: 46)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("EDAD BIOLÓGICA").font(.caption2.weight(.heavy)).tracking(1).foregroundStyle(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(BioAge.ageText(r.age)).font(.system(size: 30, weight: .bold, design: .rounded)).monospacedDigit()
                            Text("años").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(younger ? "−" : "+")\(BioAge.ageText(abs(r.diff)))")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(tone)
                        Text("real \(Int(r.real))").font(.caption).foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .card(padding: 16, tint: tone)
            .navigationDestination(isPresented: $open) { BioAgeView() }
        } else {
            Button { ask = true } label: {
                HStack(spacing: Space.m) {
                    MetricGlyph(symbol: "hourglass", color: Palette.recovery, size: 40)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("EDAD BIOLÓGICA").font(.caption2.weight(.heavy)).tracking(1).foregroundStyle(.secondary)
                        Text(BioAge.realAge(store) == nil ? "Pon tu edad para calcularla" : "Faltan datos de unos días").font(.headline)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .disabled(BioAge.realAge(store) != nil)
            .card(padding: 16)
            .sheet(isPresented: $ask) { NavigationStack { AgeSettingsView() } }
        }
    }
}

/// La pantalla de la edad biológica: el número, cómo ha ido, qué la sube y qué la baja.
struct BioAgeView: View {
    @Environment(HealthStore.self) private var store
    @State private var shown: Double = 0

    var body: some View {
        ScrollView {
            if let r = BioAge.today(store) {
                let younger = r.diff < 0
                let tone = younger ? Palette.good : r.diff < 2 ? Palette.effort : Palette.heart
                VStack(alignment: .leading, spacing: Space.l) {
                    VStack(spacing: Space.m) {
                        Text("Tu cuerpo tiene").font(.headline).foregroundStyle(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(BioAge.ageText(r.real + (r.age - r.real) * shown))
                                .font(.system(size: 84, weight: .bold, design: .rounded))
                                .tracking(-2)
                                .monospacedDigit()
                                .contentTransition(.numericText())
                            Text("años").font(.title2.weight(.semibold)).foregroundStyle(.secondary)
                        }
                        Text(abs(r.diff) < 0.3 ? "Lo mismo que tu edad real" : "\(BioAge.ageText(abs(r.diff))) años \(younger ? "menos" : "más") que tu edad real (\(Int(r.real)))")
                            .font(.headline)
                            .foregroundStyle(tone)
                        AgeScale(real: r.real, bio: r.age, tone: tone).frame(height: 56).padding(.top, Space.s)
                    }
                    .frame(maxWidth: .infinity)
                    .card(padding: 22, radius: 30, tint: tone)

                    let hist = BioAge.history(store)
                    if hist.count >= 3 {
                        VStack(alignment: .leading, spacing: Space.m) {
                            CardHeader("Últimos 3 meses", symbol: "chart.line.downtrend.xyaxis", color: tone,
                                       trailing: hist.first.map { p in
                                           let d = r.age - p.value
                                           return "\(d <= 0 ? "−" : "+")\(BioAge.ageText(abs(d))) años"
                                       })
                            Chart(hist, id: \.date) { p in
                                AreaMark(x: .value("Fecha", p.date), yStart: .value("Base", (hist.map(\.value).min() ?? 0) - 1), yEnd: .value("Edad", p.value))
                                    .foregroundStyle(LinearGradient(colors: [tone.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
                                    .interpolationMethod(.catmullRom)
                                LineMark(x: .value("Fecha", p.date), y: .value("Edad", p.value))
                                    .foregroundStyle(tone)
                                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                                    .interpolationMethod(.catmullRom)
                                RuleMark(y: .value("Real", r.real))
                                    .foregroundStyle(.secondary.opacity(0.5))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            }
                            .chartYScale(domain: (min(hist.map(\.value).min() ?? 0, r.real) - 1)...(max(hist.map(\.value).max() ?? 0, r.real) + 1))
                            .chartYAxis {
                                AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { _ in
                                    AxisGridLine().foregroundStyle(.secondary.opacity(0.15))
                                    AxisValueLabel().font(.caption2)
                                }
                            }
                            .frame(height: 160)
                        }
                        .card()
                    }

                    let worse = r.parts.filter { $0.years > 0.05 }.sorted { $0.years > $1.years }
                    let better = r.parts.filter { $0.years < -0.05 }.sorted { $0.years < $1.years }
                    if !better.isEmpty { partsCard("Lo que te quita años", better, Palette.good) }
                    if !worse.isEmpty { partsCard("Lo que te suma años", worse, Palette.heart) }

                    let tips = BioAge.tips(r)
                    if !tips.isEmpty {
                        VStack(alignment: .leading, spacing: Space.m) {
                            CardHeader("Cómo bajarla", symbol: "arrow.down.heart.fill", color: Palette.recovery)
                            ForEach(tips, id: \.0.id) { tip in
                                let p = tip.0
                                HStack(spacing: Space.m) {
                                    MetricGlyph(symbol: p.symbol, color: p.color, size: 32)
                                    Text(tip.1).font(.subheadline.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                                    Spacer()
                                    Text("−\(BioAge.ageText(p.years))").font(.headline.weight(.bold).monospacedDigit()).foregroundStyle(Palette.good)
                                }
                            }
                        }
                        .card()
                    }
                }
                .padding(.horizontal, Space.l)
                .padding(.bottom, Space.xxl)
            }
        }
        .background(MoodBackground(mood: .neutral))
        .navigationTitle("Edad biológica")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { withAnimation(.spring(response: 1.4, dampingFraction: 0.9).delay(0.2)) { shown = 1 } }
    }

    private func partsCard(_ title: String, _ parts: [BioAge.Part], _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            CardHeader(title, color: c)
            ForEach(parts) { p in
                HStack(spacing: Space.m) {
                    MetricGlyph(symbol: p.symbol, color: p.color, size: 32)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(p.title).font(.subheadline.weight(.semibold))
                        Text(p.value).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(p.years <= 0 ? "−" : "+")\(BioAge.ageText(abs(p.years)))")
                        .font(.headline.weight(.bold).monospacedDigit())
                        .foregroundStyle(c)
                }
            }
        }
        .card()
    }
}

/// Una regla de edades con tu edad real y la biológica marcadas.
struct AgeScale: View {
    var real: Double
    var bio: Double
    var tone: Color

    var body: some View {
        GeometryReader { g in
            let lo = floor(min(real, bio) - 5), hi = ceil(max(real, bio) + 5)
            let x = { (v: Double) in g.size.width * (v - lo) / (hi - lo) }
            ZStack(alignment: .topLeading) {
                Capsule().fill(LinearGradient(colors: [Palette.good, Palette.effort, Palette.heart], startPoint: .leading, endPoint: .trailing).opacity(0.35))
                    .frame(height: 8).offset(y: 20)
                Capsule().fill(tone).frame(width: abs(x(bio) - x(real)), height: 8).offset(x: min(x(bio), x(real)), y: 20)
                marker(x(real), "Real", .secondary).offset(y: 0)
                marker(x(bio), "Tú", tone)
            }
        }
    }

    private func marker(_ px: CGFloat, _ label: String, _ c: Color) -> some View {
        VStack(spacing: 2) {
            Circle().fill(c).frame(width: 14, height: 14).overlay(Circle().strokeBorder(Ink.canvas, lineWidth: 2))
                .offset(y: 17)
            Text(label).font(.caption2.weight(.bold)).foregroundStyle(c).offset(y: 20)
        }
        .frame(width: 40)
        .offset(x: px - 20)
    }
}
