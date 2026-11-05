import SwiftUI
import Charts

// MARK: - Mapa de músculos

/// Un cuerpo de frente y de espaldas, con cada músculo pintado según lo fresco que está.
struct MuscleMap: View {
    var fresh: [Muscle: Double]
    var selected: Muscle? = nil

    static func color(_ v: Double) -> Color { RGB.mix(RGB.readiness, v / 100).color }

    private struct Part {
        var muscle: Muscle?
        var rect: CGRect
        var round: CGFloat
    }

    private static let front: [Part] = [
        Part(muscle: nil, rect: CGRect(x: 47, y: 4, width: 26, height: 28), round: 13),
        Part(muscle: .trapecio, rect: CGRect(x: 46, y: 32, width: 28, height: 10), round: 5),
        Part(muscle: .hombros, rect: CGRect(x: 23, y: 40, width: 20, height: 20), round: 10),
        Part(muscle: .hombros, rect: CGRect(x: 77, y: 40, width: 20, height: 20), round: 10),
        Part(muscle: .pecho, rect: CGRect(x: 43, y: 42, width: 16.5, height: 24), round: 7),
        Part(muscle: .pecho, rect: CGRect(x: 60.5, y: 42, width: 16.5, height: 24), round: 7),
        Part(muscle: .biceps, rect: CGRect(x: 22, y: 62, width: 13, height: 28), round: 6.5),
        Part(muscle: .biceps, rect: CGRect(x: 85, y: 62, width: 13, height: 28), round: 6.5),
        Part(muscle: .antebrazos, rect: CGRect(x: 17, y: 93, width: 12, height: 32), round: 6),
        Part(muscle: .antebrazos, rect: CGRect(x: 91, y: 93, width: 12, height: 32), round: 6),
        Part(muscle: .abdomen, rect: CGRect(x: 46, y: 68, width: 28, height: 40), round: 8),
        Part(muscle: nil, rect: CGRect(x: 44, y: 110, width: 32, height: 12), round: 5),
        Part(muscle: .cuadriceps, rect: CGRect(x: 41, y: 124, width: 18, height: 52), round: 9),
        Part(muscle: .cuadriceps, rect: CGRect(x: 61, y: 124, width: 18, height: 52), round: 9),
        Part(muscle: .gemelos, rect: CGRect(x: 43, y: 182, width: 13, height: 44), round: 6.5),
        Part(muscle: .gemelos, rect: CGRect(x: 64, y: 182, width: 13, height: 44), round: 6.5),
    ]

    private static let back: [Part] = [
        Part(muscle: nil, rect: CGRect(x: 47, y: 4, width: 26, height: 28), round: 13),
        Part(muscle: .trapecio, rect: CGRect(x: 42, y: 32, width: 36, height: 18), round: 8),
        Part(muscle: .hombros, rect: CGRect(x: 23, y: 40, width: 20, height: 20), round: 10),
        Part(muscle: .hombros, rect: CGRect(x: 77, y: 40, width: 20, height: 20), round: 10),
        Part(muscle: .espalda, rect: CGRect(x: 43, y: 52, width: 16.5, height: 38), round: 7),
        Part(muscle: .espalda, rect: CGRect(x: 60.5, y: 52, width: 16.5, height: 38), round: 7),
        Part(muscle: .triceps, rect: CGRect(x: 22, y: 62, width: 13, height: 28), round: 6.5),
        Part(muscle: .triceps, rect: CGRect(x: 85, y: 62, width: 13, height: 28), round: 6.5),
        Part(muscle: .antebrazos, rect: CGRect(x: 17, y: 93, width: 12, height: 32), round: 6),
        Part(muscle: .antebrazos, rect: CGRect(x: 91, y: 93, width: 12, height: 32), round: 6),
        Part(muscle: .lumbar, rect: CGRect(x: 47, y: 92, width: 26, height: 16), round: 6),
        Part(muscle: .gluteos, rect: CGRect(x: 42, y: 110, width: 17.5, height: 22), round: 9),
        Part(muscle: .gluteos, rect: CGRect(x: 60.5, y: 110, width: 17.5, height: 22), round: 9),
        Part(muscle: .isquios, rect: CGRect(x: 41, y: 134, width: 18, height: 44), round: 9),
        Part(muscle: .isquios, rect: CGRect(x: 61, y: 134, width: 18, height: 44), round: 9),
        Part(muscle: .gemelos, rect: CGRect(x: 42, y: 182, width: 15, height: 42), round: 7.5),
        Part(muscle: .gemelos, rect: CGRect(x: 63, y: 182, width: 15, height: 42), round: 7.5),
    ]

    var body: some View {
        HStack(spacing: Space.xl) {
            figure(Self.front, "DE FRENTE")
            figure(Self.back, "DE ESPALDAS")
        }
    }

    private func figure(_ parts: [Part], _ label: String) -> some View {
        VStack(spacing: Space.s) {
            GeometryReader { g in
                let k = min(g.size.width / 120, g.size.height / 230)
                let dx = (g.size.width - 120 * k) / 2
                ZStack(alignment: .topLeading) {
                    ForEach(Array(parts.enumerated()), id: \.offset) { _, p in
                        let c = p.muscle.map { Self.color(fresh[$0] ?? 100) } ?? Ink.track
                        let on = selected == nil || p.muscle == selected
                        RoundedRectangle(cornerRadius: p.round * k, style: .continuous)
                            .fill(p.muscle == nil ? AnyShapeStyle(Ink.track) : AnyShapeStyle(c.gradient))
                            .opacity(on ? 1 : 0.25)
                            .frame(width: p.rect.width * k, height: p.rect.height * k)
                            .offset(x: dx + p.rect.minX * k, y: p.rect.minY * k)
                    }
                }
            }
            .aspectRatio(120 / 230, contentMode: .fit)
            Text(label).font(.system(size: 10, weight: .heavy)).tracking(0.8).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

extension HealthStore {
    /// Carga de la jornada de los últimos días (para el cansancio de los músculos).
    func workLoads(days: Int = 3) -> [(Date, Double)] {
        let work = WorkSchedule.current
        guard work.kind == .physical else { return [] }
        let cal = Calendar.current
        return (0..<days).compactMap { n -> (Date, Double)? in
            let d = cal.date(byAdding: .day, value: -n, to: today)!
            guard work.isWorkDay(d), let p = HeartLoad.points(self, day: d, onlyWork: true) else { return nil }
            let end = min(Date.now, work.bounds(on: d)?.1 ?? d)
            return (end, p)
        }
    }
}

// MARK: - Tarjeta en Actividad

struct StrengthCard: View {
    @Environment(HealthStore.self) private var store
    @State private var strength = StrengthStore.shared
    @State private var live = false

    var body: some View {
        let fresh = strength.freshness(work: store.workLoads())
        let tired = fresh.filter { $0.value < 60 }.sorted { $0.value < $1.value }.map(\.key)
        VStack(alignment: .leading, spacing: Space.l) {
            NavigationLink { StrengthView() } label: {
                HStack {
                    CardHeader("Fuerza", symbol: "dumbbell.fill", color: Palette.effort,
                               trailing: strength.sessions.first.map { "Último: \(Fmt.day($0.start, style: "EEEE d"))" })
                    Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            HStack(alignment: .center, spacing: Space.l) {
                MuscleMap(fresh: fresh).frame(height: 170).frame(maxWidth: 190)
                VStack(alignment: .leading, spacing: Space.s) {
                    Text(tired.isEmpty ? "Todo fresco" : "Cansados").font(.headline)
                    ForEach(tired.prefix(4)) { m in
                        HStack(spacing: 6) {
                            Circle().fill(MuscleMap.color(fresh[m] ?? 100)).frame(width: 8, height: 8)
                            Text(m.title).font(.subheadline)
                            Spacer()
                            Text("\(Int(fresh[m] ?? 100)) %").font(.caption.weight(.semibold).monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Button {
                if strength.live == nil { strength.start(nil) }
                live = true
            } label: {
                Label(strength.live == nil ? "Empezar entreno" : "Seguir entreno", systemImage: strength.live == nil ? "play.fill" : "timer")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Capsule().fill(Palette.effort))
                    .foregroundStyle(.black)
            }
            .buttonStyle(.plain)
        }
        .card(tint: Palette.effort)
        .fullScreenCover(isPresented: $live) { LiveSessionView() }
        .onAppear {
            // Captura automática: un entreno a medias.
            if Launch.args.contains("-vivo") && strength.live == nil {
                strength.start(strength.routines.first)
                if var s = strength.live, !s.items.isEmpty {
                    for k in 0..<min(2, s.items[0].sets.count) { s.items[0].sets[k].done = true }
                    s.start = .now.addingTimeInterval(-14 * 60)
                    strength.live = s
                }
                live = true
            }
        }
    }
}

// MARK: - Pantalla de fuerza

struct StrengthView: View {
    @Environment(HealthStore.self) private var store
    @State private var strength = StrengthStore.shared
    @State private var live = false
    @State private var focus: Muscle?

    var body: some View {
        let fresh = strength.freshness(work: store.workLoads())
        let weekly = strength.weeklySets()
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                VStack(alignment: .leading, spacing: Space.l) {
                    CardHeader("Músculos frescos", symbol: "figure.strengthtraining.traditional", color: Palette.recovery)
                    MuscleMap(fresh: fresh, selected: focus).frame(height: 230)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Muscle.allCases) { m in
                                Button { withAnimation(.snappy) { focus = focus == m ? nil : m } } label: {
                                    HStack(spacing: 5) {
                                        Circle().fill(MuscleMap.color(fresh[m] ?? 100)).frame(width: 8, height: 8)
                                        Text(m.title).font(.caption.weight(.semibold))
                                        Text("\(Int(fresh[m] ?? 100))").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 7)
                                    .background(Capsule().fill(focus == m ? Ink.surfaceHigh : Ink.track.opacity(0.5)))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .card()

                SectionTitle(title: "Rutinas")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Space.m) {
                        ForEach(strength.routines) { r in
                            Button {
                                strength.start(r)
                                live = true
                            } label: {
                                VStack(alignment: .leading, spacing: Space.s) {
                                    Image(systemName: "play.circle.fill").font(.title2).foregroundStyle(Palette.effort)
                                    Text(r.name).font(.headline)
                                    Text(r.items.compactMap { Exercise.by($0.exercise)?.name }.prefix(3).joined(separator: ", "))
                                        .font(.caption).foregroundStyle(.secondary).lineLimit(2, reservesSpace: true)
                                    Text("\(r.items.count) ejercicios").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                                }
                                .frame(width: 170, alignment: .leading)
                                .card(padding: 16)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) { strength.routines.removeAll { $0.id == r.id } } label: { Label("Quitar rutina", systemImage: "trash") }
                            }
                        }
                    }
                    .padding(.horizontal, Space.l)
                }
                .padding(.horizontal, -Space.l)

                if !weekly.isEmpty {
                    VStack(alignment: .leading, spacing: Space.m) {
                        CardHeader("Series esta semana", symbol: "chart.bar.fill", color: Palette.effort)
                        let rows = weekly.sorted { $0.value > $1.value }
                        Chart(rows, id: \.key) { item in
                            BarMark(x: .value("Series", item.value), y: .value("Músculo", item.key.title))
                                .foregroundStyle(Palette.effort.gradient)
                                .cornerRadius(4)
                                .annotation(position: .trailing) {
                                    Text(Fmt.number(item.value, decimals: item.value.rounded() == item.value ? 0 : 1)).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                                }
                        }
                        .chartXAxis(.hidden)
                        .frame(height: CGFloat(rows.count) * 26 + 10)
                    }
                    .card()
                }

                let used = strength.usedExercises
                if !used.isEmpty {
                    SectionTitle(title: "Récords")
                    VStack(spacing: 0) {
                        ForEach(Array(used.prefix(8).enumerated()), id: \.element.id) { i, ex in
                            NavigationLink { ExerciseDetailView(exercise: ex) } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(ex.name).font(.subheadline.weight(.semibold))
                                        Text(ex.primary.map(\.title).joined(separator: ", ")).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if let r = strength.record(ex.id) {
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text("\(Fmt.number(r.bestOneRM, decimals: 1)) kg").font(.system(.subheadline, design: .rounded).weight(.bold)).monospacedDigit()
                                            Text("1RM estimado").font(.caption2).foregroundStyle(.secondary)
                                        }
                                    }
                                    Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, Space.m)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if i < min(used.count, 8) - 1 { Divider() }
                        }
                    }
                    .card(padding: 16)
                }

                if !strength.sessions.isEmpty {
                    SectionTitle(title: "Historial")
                    ForEach(strength.sessions.prefix(15)) { s in
                        NavigationLink { SessionDetailView(session: s) } label: { SessionRow(session: s) }
                            .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, Space.l)
            .padding(.bottom, Space.xxl)
        }
        .background(MoodBackground(mood: .neutral))
        .navigationTitle("Fuerza")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if strength.live == nil { strength.start(nil) }
                    live = true
                } label: { Image(systemName: strength.live == nil ? "plus" : "timer") }
                    .accessibilityLabel("Empezar entreno")
            }
        }
        .fullScreenCover(isPresented: $live) { LiveSessionView() }
    }
}

struct SessionRow: View {
    var session: StrengthSession
    var body: some View {
        HStack(spacing: Space.m) {
            MetricGlyph(symbol: "dumbbell.fill", color: Palette.effort, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.name).font(.headline)
                Text("\(Fmt.day(session.start, style: "EEEE d MMM")) · \(Fmt.duration(session.duration))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Fmt.number(session.volume / 1000, decimals: 1)) t").font(.system(.subheadline, design: .rounded).weight(.bold))
                Text("\(session.doneSets.count) series").font(.caption).foregroundStyle(.secondary)
            }
        }
        .card(padding: 14)
    }
}

// MARK: - Detalle de un entreno

struct SessionDetailView: View {
    var session: StrengthSession
    @State private var strength = StrengthStore.shared
    @State private var askDelete = false
    @State private var askName = false
    @State private var name = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let records = strength.newRecords(in: session)
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                HStack(spacing: 0) {
                    stat(Fmt.duration(session.duration), "duración")
                    stat("\(session.doneSets.count)", "series")
                    stat("\(Fmt.number(session.volume, decimals: 0)) kg", "volumen")
                }
                .card(padding: 16)
                if !records.isEmpty {
                    VStack(alignment: .leading, spacing: Space.s) {
                        CardHeader("Récords", symbol: "trophy.fill", color: Color(red: 1, green: 0.78, blue: 0.25))
                        ForEach(records, id: \.0.id) { r in
                            HStack {
                                Text(r.0.name).font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(r.1).font(.caption.weight(.semibold)).foregroundStyle(Color(red: 1, green: 0.78, blue: 0.25))
                            }
                        }
                    }
                    .card()
                }
                ForEach(session.items) { i in
                    if let ex = Exercise.by(i.exercise) {
                        VStack(alignment: .leading, spacing: Space.s) {
                            Text(ex.name).font(.headline)
                            ForEach(Array(i.sets.enumerated()), id: \.offset) { n, s in
                                HStack {
                                    Text("\(n + 1)").font(.caption.weight(.bold)).foregroundStyle(.secondary).frame(width: 20)
                                    Text("\(Fmt.number(s.kg, decimals: s.kg.rounded() == s.kg ? 0 : 1)) kg × \(s.reps)").font(.subheadline.monospacedDigit())
                                    Spacer()
                                    Text("1RM \(Fmt.number(s.oneRM, decimals: 0))").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .card(padding: 16)
                    }
                }
            }
            .padding(.horizontal, Space.l)
            .padding(.bottom, Space.xxl)
        }
        .background(MoodBackground(mood: .neutral))
        .navigationTitle(session.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { name = session.name; askName = true } label: { Label("Guardar como rutina", systemImage: "square.and.arrow.down") }
                    Button(role: .destructive) { askDelete = true } label: { Label("Borrar entreno", systemImage: "trash") }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .confirmationDialog("¿Borrar este entreno?", isPresented: $askDelete, titleVisibility: .visible) {
            Button("Borrar", role: .destructive) { strength.delete(session); dismiss() }
            Button("Cancelar", role: .cancel) {}
        }
        .alert("Nombre de la rutina", isPresented: $askName) {
            TextField("Nombre", text: $name)
            Button("Guardar") { strength.saveAsRoutine(session, name: name.isEmpty ? session.name : name) }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private func stat(_ v: String, _ l: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.system(.headline, design: .rounded).weight(.bold)).monospacedDigit()
            Text(l).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Detalle de un ejercicio

struct ExerciseDetailView: View {
    var exercise: Exercise
    @State private var strength = StrengthStore.shared

    var body: some View {
        let pts = strength.progress(exercise.id)
        let rec = strength.record(exercise.id)
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                if let rec {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: Space.m), GridItem(.flexible(), spacing: Space.m)], spacing: Space.m) {
                        tile("\(Fmt.number(rec.bestOneRM, decimals: 1)) kg", "1RM estimado", "trophy.fill")
                        tile("\(Fmt.number(rec.heaviest, decimals: 1)) kg", "Más peso", "scalemass.fill")
                        tile("\(Fmt.number(rec.bestSetVolume, decimals: 0)) kg", "Mejor serie", "square.stack.3d.up.fill")
                        tile("\(rec.mostReps)", "Más repeticiones", "repeat")
                    }
                }
                if pts.count >= 2 {
                    VStack(alignment: .leading, spacing: Space.m) {
                        CardHeader("1RM estimado", symbol: "chart.line.uptrend.xyaxis", color: Palette.effort)
                        Chart(pts, id: \.date) { p in
                            AreaMark(x: .value("Fecha", p.date), yStart: .value("Base", (pts.map(\.value).min() ?? 0) * 0.9), yEnd: .value("1RM", p.value))
                                .foregroundStyle(LinearGradient(colors: [Palette.effort.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom))
                                .interpolationMethod(.monotone)
                            LineMark(x: .value("Fecha", p.date), y: .value("1RM", p.value))
                                .foregroundStyle(Palette.effort)
                                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                                .interpolationMethod(.monotone)
                            PointMark(x: .value("Fecha", p.date), y: .value("1RM", p.value)).foregroundStyle(Palette.effort).symbolSize(20)
                        }
                        .chartYScale(domain: ((pts.map(\.value).min() ?? 0) * 0.9)...((pts.map(\.value).max() ?? 1) * 1.05))
                        .frame(height: 180)
                    }
                    .card()
                }
                VStack(alignment: .leading, spacing: Space.s) {
                    CardHeader("Músculos", symbol: "figure.strengthtraining.traditional", color: Palette.recovery)
                    MuscleMap(fresh: Dictionary(uniqueKeysWithValues: Muscle.allCases.map { m in
                        (m, exercise.primary.contains(m) ? 0.0 : exercise.secondary.contains(m) ? 50.0 : 100.0)
                    }))
                    .frame(height: 200)
                    Text(([exercise.equipment.title] + exercise.primary.map(\.title)).joined(separator: " · "))
                        .font(.caption).foregroundStyle(.secondary)
                }
                .card()
            }
            .padding(.horizontal, Space.l)
            .padding(.bottom, Space.xxl)
        }
        .background(MoodBackground(mood: .neutral))
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func tile(_ v: String, _ l: String, _ s: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: s).foregroundStyle(Palette.effort)
            Text(v).font(.system(.title3, design: .rounded).weight(.bold)).monospacedDigit()
            Text(l).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 14)
    }
}

// MARK: - Entreno en marcha

struct LiveSessionView: View {
    @State private var strength = StrengthStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var picker = false
    @State private var restUntil: Date?
    @State private var askDiscard = false
    @State private var summary: StrengthSession?

    var body: some View {
        NavigationStack {
            Group {
                if let s = strength.live {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Space.l) {
                            TimelineView(.periodic(from: .now, by: 1)) { tl in
                                HStack(spacing: 0) {
                                    stat(clock(tl.date.timeIntervalSince(s.start)), "tiempo")
                                    stat("\(s.doneSets.count)", "series")
                                    stat("\(Fmt.number(s.volume, decimals: 0)) kg", "volumen")
                                }
                            }
                            .card(padding: 16)
                            ForEach(Array(s.items.enumerated()), id: \.element.id) { i, item in
                                LiveExerciseCard(index: i, onDone: { restUntil = .now.addingTimeInterval(Double(strength.restSeconds)) })
                            }
                            Button { picker = true } label: {
                                Label("Añadir ejercicio", systemImage: "plus")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Capsule().fill(Palette.effort.opacity(0.16)))
                                    .foregroundStyle(Palette.effort)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, Space.l)
                        .padding(.bottom, 120)
                    }
                    .safeAreaInset(edge: .bottom) { restBar }
                    .navigationTitle(s.name)
                } else if let done = summary {
                    FinishedView(session: done) { dismiss() }
                }
            }
            .background(MoodBackground(mood: .neutral))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if strength.live != nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Menu {
                            Button { dismiss() } label: { Label("Minimizar", systemImage: "chevron.down") }
                            Button(role: .destructive) { askDiscard = true } label: { Label("Descartar entreno", systemImage: "trash") }
                        } label: { Image(systemName: "chevron.down.circle") }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Terminar") {
                            let s = strength.live
                            strength.finish()
                            if let s, let saved = strength.sessions.first, saved.start == s.start { summary = saved } else { dismiss() }
                        }
                        .bold()
                    }
                }
            }
            .confirmationDialog("¿Descartar este entreno?", isPresented: $askDiscard, titleVisibility: .visible) {
                Button("Descartar", role: .destructive) { strength.discard(); dismiss() }
                Button("Cancelar", role: .cancel) {}
            }
            .sheet(isPresented: $picker) {
                ExercisePicker { ex in
                    let last = strength.lastSets(ex.id)
                    let sets = last.isEmpty ? [SetLog(kg: 0, reps: 10), SetLog(kg: 0, reps: 10), SetLog(kg: 0, reps: 10)] : last.map { SetLog(kg: $0.kg, reps: $0.reps) }
                    strength.live?.items.append(ExerciseLog(exercise: ex.id, sets: sets))
                }
            }
            .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        }
    }

    @ViewBuilder
    private var restBar: some View {
        if let until = restUntil {
            TimelineView(.periodic(from: .now, by: 1)) { tl in
                let left = until.timeIntervalSince(tl.date)
                HStack(spacing: Space.m) {
                    Image(systemName: "timer").font(.title3)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(left > 0 ? "Descanso" : "¡A por la siguiente!").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                        Text(clock(max(0, left))).font(.system(.title2, design: .rounded).weight(.bold)).monospacedDigit()
                    }
                    Spacer()
                    Button("−15") { restUntil = until.addingTimeInterval(-15) }.buttonStyle(.bordered)
                    Button("+15") { restUntil = until.addingTimeInterval(15) }.buttonStyle(.bordered)
                    Button { restUntil = nil } label: { Image(systemName: "xmark") }.buttonStyle(.bordered)
                }
                .padding(Space.l)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(.horizontal, Space.l)
                .sensoryFeedback(.success, trigger: left <= 0)
            }
        }
    }

    private func clock(_ t: TimeInterval) -> String {
        let s = Int(t)
        return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s % 3600 / 60, s % 60) : String(format: "%d:%02d", s / 60, s % 60)
    }

    private func stat(_ v: String, _ l: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.system(.headline, design: .rounded).weight(.bold)).monospacedDigit()
            Text(l).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Un ejercicio del entreno en marcha: series con kilos, repeticiones y ✓.
struct LiveExerciseCard: View {
    var index: Int
    var onDone: () -> Void
    @State private var strength = StrengthStore.shared

    var body: some View {
        if let item = strength.live?.items[safe: index], let ex = Exercise.by(item.exercise) {
            let last = strength.lastSets(ex.id)
            VStack(alignment: .leading, spacing: Space.m) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ex.name).font(.headline)
                        Text(ex.primary.map(\.title).joined(separator: ", ")).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Menu {
                        Button(role: .destructive) { strength.live?.items.remove(at: index) } label: { Label("Quitar ejercicio", systemImage: "trash") }
                    } label: { Image(systemName: "ellipsis").padding(8) }
                }
                HStack {
                    Text("SERIE").frame(width: 40, alignment: .leading)
                    Text("ANTES").frame(maxWidth: .infinity, alignment: .leading)
                    Text("KG").frame(width: 70)
                    Text("REPS").frame(width: 56)
                    Spacer().frame(width: 36)
                }
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(.secondary)
                ForEach(Array(item.sets.enumerated()), id: \.element.id) { n, s in
                    HStack {
                        Text("\(n + 1)").font(.subheadline.weight(.bold)).frame(width: 40, alignment: .leading)
                        Text(last[safe: n].map { "\(Fmt.number($0.kg, decimals: $0.kg.rounded() == $0.kg ? 0 : 1)) × \($0.reps)" } ?? "—")
                            .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                        NumberField(value: binding(n, \.kg), decimals: true).frame(width: 70)
                        NumberField(value: Binding(get: { Double(strength.live?.items[safe: index]?.sets[safe: n]?.reps ?? 0) },
                                                   set: { v in update(n) { $0.reps = Int(v) } }), decimals: false).frame(width: 56)
                        Button {
                            let was = s.done
                            update(n) { $0.done.toggle() }
                            if !was { onDone() }
                        } label: {
                            Image(systemName: s.done ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundStyle(s.done ? Palette.good : .secondary)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .buttonStyle(.plain)
                        .frame(width: 36)
                    }
                    .padding(.vertical, 2)
                    .background(s.done ? Palette.good.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 8))
                }
                Button {
                    let prev = item.sets.last
                    strength.live?.items[index].sets.append(SetLog(kg: prev?.kg ?? 0, reps: prev?.reps ?? 10))
                } label: {
                    Label("Añadir serie", systemImage: "plus").font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderless)
            }
            .card(padding: 16)
            .sensoryFeedback(.success, trigger: item.sets.filter(\.done).count)
        }
    }

    private func update(_ n: Int, _ f: (inout SetLog) -> Void) {
        guard var live = strength.live, index < live.items.count, n < live.items[index].sets.count else { return }
        f(&live.items[index].sets[n])
        strength.live = live
    }

    private func binding(_ n: Int, _ k: WritableKeyPath<SetLog, Double>) -> Binding<Double> {
        Binding(get: { strength.live?.items[safe: index]?.sets[safe: n]?[keyPath: k] ?? 0 },
                set: { v in update(n) { $0[keyPath: k] = v } })
    }
}

/// Casilla de número que se edita con el teclado numérico.
struct NumberField: View {
    @Binding var value: Double
    var decimals: Bool
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("0", text: $text)
            .keyboardType(decimals ? .decimalPad : .numberPad)
            .multilineTextAlignment(.center)
            .font(.system(.body, design: .rounded).weight(.semibold).monospacedDigit())
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8).fill(Ink.track.opacity(0.6)))
            .focused($focused)
            .onAppear { text = format(value) }
            .onChange(of: value) { _, v in if !focused { text = format(v) } }
            .onChange(of: text) { _, t in
                if let v = Double(t.replacingOccurrences(of: ",", with: ".")) { value = v } else if t.isEmpty { value = 0 }
            }
    }

    private func format(_ v: Double) -> String {
        v == 0 ? "" : (v.rounded() == v ? String(Int(v)) : String(format: "%.1f", v).replacingOccurrences(of: ".", with: ","))
    }
}

/// Buscador de ejercicios por nombre y músculo.
struct ExercisePicker: View {
    var pick: (Exercise) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var muscle: Muscle?

    var body: some View {
        NavigationStack {
            let q = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            let list = Exercise.library.filter { ex in
                (muscle == nil || ex.primary.contains(muscle!)) &&
                (q.isEmpty || ex.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).contains(q))
            }
            List {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Muscle.allCases) { m in
                                Button { muscle = muscle == m ? nil : m } label: {
                                    Text(m.title).font(.caption.weight(.semibold))
                                        .padding(.horizontal, 10).padding(.vertical, 7)
                                        .background(Capsule().fill(muscle == m ? Palette.effort : Ink.track.opacity(0.5)))
                                        .foregroundStyle(muscle == m ? .black : .primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                }
                ForEach(list) { ex in
                    Button {
                        pick(ex)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ex.name).foregroundStyle(.primary)
                            Text(([ex.equipment.title] + ex.primary.map(\.title)).joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Buscar ejercicio")
            .navigationTitle("Ejercicios")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { dismiss() } } }
        }
    }
}

/// Resumen al terminar.
struct FinishedView: View {
    var session: StrengthSession
    var close: () -> Void
    @State private var strength = StrengthStore.shared
    @State private var pop = false

    var body: some View {
        let records = strength.newRecords(in: session)
        VStack(spacing: Space.l) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 76))
                .foregroundStyle(Palette.good)
                .scaleEffect(pop ? 1 : 0.3)
                .symbolEffect(.bounce, value: pop)
            Text("¡Entreno hecho!").font(.largeTitle.weight(.bold))
            HStack(spacing: 0) {
                stat(Fmt.duration(session.duration), "duración")
                stat("\(session.doneSets.count)", "series")
                stat("\(Fmt.number(session.volume, decimals: 0)) kg", "volumen")
            }
            .card(padding: 16)
            ForEach(records, id: \.0.id) { r in
                Label("\(r.0.name): \(r.1)", systemImage: "trophy.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(red: 1, green: 0.78, blue: 0.25))
            }
            Spacer()
            Button(action: close) {
                Text("Listo").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(Capsule().fill(Palette.good)).foregroundStyle(.black)
            }
            .buttonStyle(.plain)
        }
        .padding(Space.l)
        .sensoryFeedback(.success, trigger: pop)
        .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { pop = true } }
    }

    private func stat(_ v: String, _ l: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.system(.headline, design: .rounded).weight(.bold)).monospacedDigit()
            Text(l).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
