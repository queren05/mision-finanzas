import SwiftUI

/// Entrenador con IA: conoce tus datos de las dos últimas semanas y te contesta.
struct CoachView: View {
    @Environment(HealthStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var turns: [Claude.Turn] = CoachView.load()
    @State private var text = ""
    @State private var thinking = false
    @State private var error: String?
    @State private var askClear = false
    @State private var settings = false
    @FocusState private var focused: Bool

    private static let suggestions = [
        "¿Entreno hoy o descanso?",
        "Hazme un entreno para hoy",
        "¿Por qué duermo mal?",
        "¿Qué tal mi semana?",
        "¿Cómo bajo el estrés?",
    ]

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.m) {
                        if turns.isEmpty {
                            VStack(spacing: Space.m) {
                                Image(systemName: "sparkles").font(.system(size: 44)).foregroundStyle(Palette.recovery)
                                    .symbolEffect(.pulse)
                                Text("Pregúntame lo que quieras").font(.title3.weight(.bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                            .padding(.bottom, Space.l)
                            ForEach(Self.suggestions, id: \.self) { s in
                                Button { send(s) } label: {
                                    HStack {
                                        Text(s).font(.subheadline.weight(.medium))
                                        Spacer()
                                        Image(systemName: "arrow.up.circle.fill").foregroundStyle(Palette.recovery)
                                    }
                                    .padding(14)
                                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Ink.surface))
                                }
                                .buttonStyle(.plain)
                                .disabled(!Claude.hasKey)
                            }
                        }
                        ForEach(turns) { t in
                            Bubble(turn: t).id(t.id)
                        }
                        if thinking {
                            HStack(spacing: Space.s) {
                                ProgressView()
                                Text("Pensando…").font(.subheadline).foregroundStyle(.secondary)
                            }
                            .id("pensando")
                        }
                        if let error {
                            Text(error).font(.subheadline).foregroundStyle(Palette.heart)
                        }
                    }
                    .padding(.horizontal, Space.l)
                    .padding(.bottom, Space.l)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: turns.count) { _, _ in withAnimation { proxy.scrollTo(turns.last?.id, anchor: .bottom) } }
                .onChange(of: thinking) { _, t in if t { withAnimation { proxy.scrollTo("pensando", anchor: .bottom) } } }
            }
            .safeAreaInset(edge: .bottom) {
                if Claude.hasKey {
                    HStack(spacing: Space.s) {
                        TextField("Escribe aquí", text: $text, axis: .vertical)
                            .lineLimit(1...5)
                            .focused($focused)
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background(Capsule().fill(Ink.surfaceHigh))
                        Button { send(text) } label: {
                            Image(systemName: "arrow.up.circle.fill").font(.system(size: 34))
                                .foregroundStyle(text.trimmingCharacters(in: .whitespaces).isEmpty || thinking ? Color.secondary : Palette.recovery)
                        }
                        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty || thinking)
                    }
                    .padding(.horizontal, Space.l).padding(.vertical, Space.s)
                    .background(.bar)
                } else {
                    Button { settings = true } label: {
                        Label("Pon tu clave de Claude", systemImage: "key.fill").font(.headline)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Capsule().fill(Palette.recovery)).foregroundStyle(.black)
                    }
                    .buttonStyle(.plain)
                    .padding(Space.l)
                }
            }
            .background(MoodBackground(mood: .neutral))
            .navigationTitle("Entrenador")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { dismiss() } }
                if !turns.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { askClear = true } label: { Image(systemName: "square.and.pencil") }
                            .accessibilityLabel("Conversación nueva")
                    }
                }
            }
            .confirmationDialog("¿Borrar la conversación?", isPresented: $askClear, titleVisibility: .visible) {
                Button("Borrar", role: .destructive) { turns = []; Self.save([]) }
                Button("Cancelar", role: .cancel) {}
            }
            .sheet(isPresented: $settings) { NavigationStack { CoachKeyView() } }
        }
    }

    private func send(_ raw: String) {
        let q = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !thinking else { return }
        text = ""
        error = nil
        turns.append(Claude.Turn(fromMe: true, text: q))
        Self.save(turns)
        thinking = true
        let context = CoachContext.make(store)
        let history = Array(turns.suffix(16))
        Task {
            do {
                let a = try await Claude.ask(system: CoachContext.system + "\n\n" + context, turns: history)
                turns.append(Claude.Turn(fromMe: false, text: a))
                Self.save(turns)
            } catch {
                self.error = error.localizedDescription
            }
            thinking = false
        }
    }

    private static var url: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("entrenador.json") }
    static func load() -> [Claude.Turn] {
        (try? JSONDecoder().decode([Claude.Turn].self, from: Data(contentsOf: url))) ?? []
    }
    static func save(_ t: [Claude.Turn]) {
        if let d = try? JSONEncoder().encode(Array(t.suffix(60))) { try? d.write(to: url, options: .atomic) }
    }
}

struct Bubble: View {
    var turn: Claude.Turn
    var body: some View {
        HStack {
            if turn.fromMe { Spacer(minLength: 50) }
            Group {
                if turn.fromMe {
                    Text(turn.text)
                } else {
                    Text((try? AttributedString(markdown: turn.text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(turn.text))
                }
            }
            .font(.body)
            .textSelection(.enabled)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(turn.fromMe ? Palette.recovery.opacity(0.25) : Ink.surface))
            if !turn.fromMe { Spacer(minLength: 20) }
        }
    }
}

/// La clave de Claude.
struct CoachKeyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var key = Keychain.apiKey
    var inSheet = true

    var body: some View {
        Form {
            Section {
                SecureField("sk-ant-…", text: $key)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("Clave de Claude")
            }
            if !key.isEmpty {
                Section {
                    Button("Quitar la clave", role: .destructive) { key = ""; Keychain.apiKey = "" }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(MoodBackground(mood: .neutral))
        .navigationTitle("Entrenador con IA")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") { Keychain.apiKey = key; if inSheet { dismiss() } }.bold()
            }
        }
    }
}

/// Lo que el entrenador sabe de ti, en texto.
@MainActor
enum CoachContext {
    static let system = """
    Eres el entrenador personal y de salud de la app Vitalidad. Hablas en español de España, cercano y directo, como un buen entrenador que conoce bien al usuario.
    Contesta corto (como mucho 8-10 líneas salvo que te pidan un plan), con números concretos de sus datos cuando ayuden. Usa listas solo si de verdad aclaran.
    No diagnostiques enfermedades; si algo parece preocupante, dile que lo consulte con un médico.
    Las puntuaciones van de 0 a 100. La recuperación sale de la variabilidad, el pulso en reposo y el sueño; el esfuerzo de la energía activa, el ejercicio y el pulso de cada hora.
    """

    static func make(_ store: HealthStore) -> String {
        let cal = Calendar.current
        var out: [String] = ["Hoy es \(Fmt.day(.now, style: "EEEE d 'de' MMMM, H:mm"))."]
        if let age = BioAge.realAge(store) { out.append("Edad: \(Int(age)) años, \(BioAge.female(store) ? "mujer" : "hombre").") }
        let work = WorkSchedule.current
        if work.active {
            out.append("Trabajo: \(work.kind.title.lowercased()) (mozo de almacén), \(work.summary).")
        }
        if let b = BioAge.today(store) { out.append("Edad del cuerpo estimada: \(BioAge.ageText(b.age)) años.") }
        out.append("\nÚltimos 14 días (día: recuperación / sueño / esfuerzo / estrés / horas dormidas / pasos):")
        for d in cal.days(back: 14, from: store.today) {
            let r = ScoreEngine.report(store, day: d)
            let n = store.night(for: d).map { Fmt.duration($0.asleep) } ?? "–"
            let steps = store.value(.steps, on: d).map { Fmt.number($0) } ?? "–"
            let stress = StressEngine.score(store, day: d).map(String.init) ?? "–"
            out.append("\(Fmt.day(d, style: "EEE d")): \(r.recovery?.value.description ?? "–") / \(r.sleep?.value.description ?? "–") / \(r.effort?.value.description ?? "–") / \(stress) / \(n) / \(steps)")
        }
        for m in [Metric.restingHR, .hrv, .vo2max, .weight] {
            if let l = store.latest(m), let b = store.baseline(m) {
                out.append("\(m.title): \(Fmt.full(m, l.value)) (su normal \(Fmt.full(m, b.median))).")
            }
        }
        if let e = EnergyEngine.today(store) { out.append("Batería ahora: \(Int(e.now)) %.") }
        let ws = store.workouts(days: 14)
        if !ws.isEmpty {
            out.append("\nEntrenos (Apple Watch): " + ws.prefix(10).map { "\(Fmt.day($0.start, style: "EEE d")) \($0.name) \(Fmt.duration($0.duration))" }.joined(separator: "; "))
        }
        let strength = StrengthStore.shared
        if !strength.sessions.isEmpty {
            out.append("Fuerza apuntada: " + strength.sessions.prefix(6).map { s in
                "\(Fmt.day(s.start, style: "EEE d")) \(s.name): " + s.items.compactMap { i in Exercise.by(i.exercise).map { ex in "\(ex.name) \(i.sets.count)×\(i.sets.first?.reps ?? 0) \(Fmt.number(i.sets.map(\.kg).max() ?? 0)) kg" } }.joined(separator: ", ")
            }.joined(separator: " | "))
        }
        let fresh = strength.freshness(work: store.workLoads()).filter { $0.value < 60 }
        if !fresh.isEmpty { out.append("Músculos cansados: " + fresh.map { "\($0.key.title) \(Int($0.value)) %" }.joined(separator: ", ")) }
        let effects = HabitImpact.effects(store, journal: Journal.shared).filter { $0.sleep != nil || $0.recovery != nil }
        if !effects.isEmpty {
            out.append("Diario (efecto en la noche siguiente, puntos): " + effects.map { e in
                "\(e.habit.title): sueño \(e.sleep.map { Fmt.number($0) } ?? "?"), recuperación \(e.recovery.map { Fmt.number($0) } ?? "?")"
            }.joined(separator: "; "))
        }
        let today = Journal.shared.entry(store.today)
        if !today.isEmpty { out.append("Hoy ha apuntado: " + today.compactMap { item in Habit.by(item.key).map { $0.counted ? "\($0.title) \(item.value)" : $0.title } }.joined(separator: ", ")) }
        if let kcal = store.value(.calories, on: store.today) { out.append("Hoy ha comido \(Fmt.number(kcal)) kcal y quemado \(Fmt.number(store.value(.activeEnergy, on: store.today) ?? 0)) kcal activas.") }
        return out.joined(separator: "\n")
    }
}
