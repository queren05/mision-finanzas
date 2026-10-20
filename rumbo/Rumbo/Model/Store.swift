import SwiftUI
import Observation
import EventKit
import UserNotifications

struct AgendaEvent: Identifiable, Hashable {
    var id: String
    var title: String
    var start: Date
    var end: Date
    var allDay: Bool
    var color: Color
}

@Observable
final class Store {
    var s: RState { didSet { scheduleSave() } }
    var agenda: [AgendaEvent] = []
    var calendarDenied = false
    var busy: Set<String> = []          // qué se está pidiendo a Claude ahora mismo
    var error: String? = nil

    @ObservationIgnored private var saveTask: Task<Void, Never>? = nil
    @ObservationIgnored private let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("rumbo.json")
    @ObservationIgnored let events = EKEventStore()

    init() {
        if let d = try? Data(contentsOf: url), let st = try? JSONDecoder().decode(RState.self, from: d) { s = st } else { s = Store.starter() }
    }

    static func starter() -> RState {
        var st = RState()
        st.tasks = [TaskItem(title: "Revisar el presupuesto del mes", priority: true),
                    TaskItem(title: "Llamar al seguro del coche"),
                    TaskItem(title: "Leer 20 páginas")]
        return st
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard let self, !Task.isCancelled else { return }
            self.saveNow()
        }
    }
    func saveNow() {
        if let d = try? JSONEncoder().encode(s) { try? d.write(to: url, options: .atomic) }
    }

    /// ejecuta una petición a Claude marcando la tarea como ocupada y guardando el error para enseñarlo
    @MainActor
    func run(_ key: String, _ work: @escaping () async throws -> Void) async {
        busy.insert(key)
        defer { busy.remove(key) }
        do { try await work(); Haptic.success() } catch {
            Haptic.warning()
            self.error = error.localizedDescription
        }
    }

    // MARK: - Agenda (calendarios del iPhone)

    @MainActor
    func loadAgenda() async {
        do {
            let ok = try await events.requestFullAccessToEvents()
            calendarDenied = !ok
            guard ok else { return }
            let start = Calendar.current.startOfDay(for: Date())
            let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
            let pred = events.predicateForEvents(withStart: start, end: end, calendars: nil)
            agenda = events.events(matching: pred).sorted { $0.startDate < $1.startDate }.map {
                AgendaEvent(id: $0.eventIdentifier ?? UUID().uuidString, title: $0.title ?? "Evento", start: $0.startDate, end: $0.endDate,
                            allDay: $0.isAllDay, color: Color(cgColor: $0.calendar.cgColor))
            }
        } catch { calendarDenied = true }
    }

    /// eventos del calendario del iPhone entre dos días (yyyy-MM-dd, ambos incluidos)
    func events(from a: String, to b: String) -> [AgendaEvent] {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return [] }
        let start = Calendar.current.startOfDay(for: Day.date(a))
        let end = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Day.date(b)))!
        return events.events(matching: events.predicateForEvents(withStart: start, end: end, calendars: nil)).sorted { $0.startDate < $1.startDate }.map {
            AgendaEvent(id: ($0.eventIdentifier ?? UUID().uuidString) + Day.str($0.startDate), title: $0.title ?? "Evento", start: $0.startDate, end: $0.endDate,
                        allDay: $0.isAllDay, color: Color(cgColor: $0.calendar.cgColor))
        }
    }

    // MARK: - Avisos (briefing por la mañana, chequeo por la noche, revisión del domingo)

    func scheduleNotifications() {
        let c = UNUserNotificationCenter.current()
        c.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        c.removeAllPendingNotificationRequests()
        let st = s.settings
        func add(_ id: String, _ title: String, _ body: String, _ comps: DateComponents) {
            let n = UNMutableNotificationContent(); n.title = title; n.body = body; n.sound = .default
            c.add(UNNotificationRequest(identifier: id, content: n, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)))
        }
        if st.notifyBriefing { add("briefing", "Buenos días, \(st.name) ☀️", "Abre Rumbo y mira tu briefing de hoy: agenda, prioridades y tareas.", DateComponents(hour: st.briefingHour, minute: 0)) }
        if st.notifyCheckIn { add("checkin", "Chequeo nocturno 🌙", "¿Cómo ha ido hoy? Apunta tus logros y qué mejorar.", DateComponents(hour: st.checkInHour, minute: 0)) }
        if st.notifyWeekly { add("weekly", "Revisión semanal 📅", "Tu semana en un resumen y el plan para la siguiente.", DateComponents(hour: 19, minute: 0, weekday: 1)) }
    }

    // MARK: - 1. Panel de vida

    func toggle(_ t: TaskItem) {
        guard let i = s.tasks.firstIndex(where: { $0.id == t.id }) else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            s.tasks[i].done.toggle(); s.tasks[i].doneAt = s.tasks[i].done ? Date() : nil
        }
    }
    func save(_ t: TaskItem) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if let i = s.tasks.firstIndex(where: { $0.id == t.id }) { s.tasks[i] = t } else { s.tasks.insert(t, at: 0) }
        }
    }
    func delete(_ t: TaskItem) { withAnimation(.spring) { s.tasks.removeAll { $0.id == t.id } } }

    @MainActor
    func makeBriefing() async {
        await run("briefing") { [self] in
            let fmt = DateFormatter(); fmt.locale = Locale(identifier: "es_ES"); fmt.dateFormat = "EEEE d 'de' MMMM"
            let hm = DateFormatter(); hm.dateFormat = "HH:mm"
            let ag = agenda.map { $0.allDay ? "- Todo el día: \($0.title)" : "- \(hm.string(from: $0.start))–\(hm.string(from: $0.end)): \($0.title)" }.joined(separator: "\n")
            let pri = s.tasks.filter { $0.priority && !$0.done }.map { "- \($0.title)" }.joined(separator: "\n")
            let pend = s.tasks.filter { !$0.priority && !$0.done }.prefix(15).map { "- \($0.title)\($0.due.isEmpty ? "" : " (para el \($0.due))")" }.joined(separator: "\n")
            let last = s.checkIns.sorted { $0.date > $1.date }.first.map { "Ayer: logros \($0.wins.joined(separator: "; ")). A mejorar: \($0.improve.joined(separator: "; "))." } ?? ""
            let plan = s.weekly.sorted { $0.weekStart > $1.weekStart }.first.map { "Plan de la semana: enfoque \($0.focus); objetivo \($0.goal); hábito \($0.habit)." } ?? ""
            let prompt = """
            Hoy es \(fmt.string(from: Date())).
            Agenda de hoy:
            \(ag.isEmpty ? "(sin eventos)" : ag)
            Prioridades:
            \(pri.isEmpty ? "(ninguna)" : pri)
            Otras tareas pendientes:
            \(pend.isEmpty ? "(ninguna)" : pend)
            \(last)
            \(plan)
            """
            let text = try await Claude.ask(system: "Eres el asistente personal de \(s.settings.name). Escribe su briefing del día en español de España, cercano y directo: un saludo de una línea, lo más importante del día en 3–5 viñetas cortas (qué hacer primero y por qué, huecos libres de la agenda para las prioridades, avisos de lo que vence) y una frase final de ánimo. Sin títulos ni markdown pesado: solo viñetas con «•». Máximo 120 palabras.", parts: [.text(prompt)], effort: "low", maxTokens: 2000)
            withAnimation(.spring) { s.briefing = Briefing(date: Day.today, text: text) }
        }
    }

    // MARK: - 2. Segundo cerebro

    func save(_ d: BrainDoc) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if let i = s.docs.firstIndex(where: { $0.id == d.id }) { s.docs[i] = d } else { s.docs.insert(d, at: 0) }
        }
    }
    func delete(_ d: BrainDoc) {
        if let f = d.file { try? FileManager.default.removeItem(at: Extract.url(f)) }
        withAnimation(.spring) { s.docs.removeAll { $0.id == d.id } }
    }

    /// Claude le pone título, carpeta, resumen, importe y fechas a un documento nuevo.
    /// Si es una foto o un PDF sin texto, Claude lee el propio archivo.
    @MainActor
    func organize(_ docId: String) async {
        guard Claude.hasKey, let d = s.docs.first(where: { $0.id == docId }) else { return }
        var parts: [Claude.Part] = []
        let hasText = d.text.trimmingCharacters(in: .whitespacesAndNewlines).count > 20
        if let f = d.file, let data = try? Data(contentsOf: Extract.url(f)) {
            if d.kind == "image", let ui = UIImage(data: data) { parts.append(.image(Extract.jpeg(ui), "image/jpeg")) }
            else if d.kind == "pdf", !hasText, data.count < 20_000_000 { parts.append(.pdf(data)) }
        }
        if hasText { parts.append(.text("Texto reconocido:\n" + String(d.text.prefix(12000)))) }
        guard !parts.isEmpty else { return }
        await run("org-" + docId) { [self] in
            let folders = BrainFolder.allCases.map(\.rawValue).joined(separator: ", ")
            let j = try await Claude.askJSON(system: """
                Clasificas documentos personales (contratos, seguros, recibos, facturas, tickets, nóminas…). Hoy es \(Day.today). Devuelve:
                {"title": título corto en español (máx. 6 palabras, p. ej. «Factura Endesa septiembre»),
                 "folder": una de [\(folders)] (tickets y facturas de compras van en recibos),
                 "summary": 1–2 frases con los datos clave,
                 "issuer": tienda o empresa que lo emite o "",
                 "amount": importe total en euros como número (p. ej. 23.4) o null,
                 "date": fecha del documento "yyyy-MM-dd" o "",
                 "due": fecha en que vence, termina, se renueva o hay que pagarlo "yyyy-MM-dd" o "",
                 "text": si no te he pasado texto, transcribe aquí lo importante del documento; si no, ""}
                """, parts: parts, effort: "low")
            guard var n = s.docs.first(where: { $0.id == docId }) else { return }
            if let t = j["title"] as? String, !t.isEmpty, n.title.hasPrefix("Documento") || n.title.hasPrefix("Escaneo") || n.title.hasPrefix("Foto") || n.title.hasPrefix("Nota del") || n.title.hasPrefix("IMG") { n.title = t }
            if let f = j["folder"] as? String, let bf = BrainFolder(rawValue: f) { n.folder = bf }
            if let sm = j["summary"] as? String { n.summary = sm }
            if let i = j["issuer"] as? String { n.issuer = i }
            if let a = j["amount"] as? Double { n.amount = a } else if let a = j["amount"] as? Int { n.amount = Double(a) }
            if let dt = j["date"] as? String, dt.count == 10 { n.docDate = dt }
            if let du = j["due"] as? String, du.count == 10 { n.due = du }
            if !hasText, let t = j["text"] as? String, !t.isEmpty { n.text = t }
            save(n)
        }
    }

    /// documentos que más tienen que ver con la pregunta (por palabras)
    func relevantDocs(_ q: String, limit: Int = 8) -> [BrainDoc] {
        let words = q.lowercased().folding(options: .diacriticInsensitive, locale: nil)
            .split { !$0.isLetter && !$0.isNumber }.map(String.init).filter { $0.count > 3 }
        let scored = s.docs.map { d -> (BrainDoc, Int) in
            let hay = (d.title + " " + d.summary + " " + d.folder.rawValue + " " + d.text).lowercased().folding(options: .diacriticInsensitive, locale: nil)
            return (d, words.reduce(0) { $0 + (hay.contains($1) ? (d.title.lowercased().contains($1) ? 3 : 1) : 0) })
        }
        let hits = scored.filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }.map(\.0)
        return Array((hits.isEmpty ? s.docs : hits).prefix(limit))
    }

    @MainActor
    func askBrain(_ q: String) async {
        await run("brain") { [self] in
            let docs = relevantDocs(q)
            guard !docs.isEmpty else { throw Claude.Failure.server("Aún no has guardado documentos en tu segundo cerebro.") }
            let ctx = docs.enumerated().map { i, d in "<documento n=\"\(i + 1)\" titulo=\"\(d.title)\" carpeta=\"\(d.folder.label)\">\n\(d.facts)\n\(d.summary)\n\(d.text.prefix(20000))\n</documento>" }.joined(separator: "\n\n")
            let a = try await Claude.ask(system: "Eres el segundo cerebro de \(s.settings.name): respondes SOLO con lo que dicen sus documentos. Responde en español de España, directo y breve (1–4 frases), con fechas e importes exactos. Si la respuesta no está en los documentos, dilo claramente. Al final, en una línea aparte, escribe «Fuentes:» y los títulos de los documentos que has usado separados por «;».",
                                         parts: [.text(ctx + "\n\nPregunta: " + q)], effort: "medium")
            var answer = a; var sources: [String] = []
            if let r = a.range(of: "Fuentes:", options: .backwards) {
                answer = String(a[..<r.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                sources = a[r.upperBound...].split(separator: ";").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            }
            withAnimation(.spring) { s.brainQA.insert(QA(question: q, answer: answer, sources: sources), at: 0) }
        }
    }

    // MARK: - 3. Agente de revisión

    func checkIn(for day: String) -> CheckIn { s.checkIns.first { $0.date == day } ?? CheckIn(date: day) }
    func save(_ c: CheckIn) {
        withAnimation(.spring) {
            if let i = s.checkIns.firstIndex(where: { $0.date == c.date }) { s.checkIns[i] = c } else { s.checkIns.append(c) }
        }
    }
    /// días seguidos con chequeo
    var streak: Int {
        var n = 0; var d = Day.today
        if !s.checkIns.contains(where: { $0.date == d }) { d = Day.add(d, days: -1) }
        while s.checkIns.contains(where: { $0.date == d && (!$0.wins.isEmpty || !$0.text.isEmpty) }) { n += 1; d = Day.add(d, days: -1) }
        return n
    }

    /// Claude ordena lo que has contado del día en logros y cosas a mejorar
    @MainActor
    func sortDay(_ day: String) async {
        let c = checkIn(for: day)
        guard !c.text.isEmpty else { return }
        await run("sort") { [self] in
            let done = s.tasks.filter { $0.done && $0.doneAt.map { Day.str($0) == day } == true }.map(\.title)
            let j = try await Claude.askJSON(system: "Eres un coach de productividad cercano. Con lo que cuenta la persona de su día (y las tareas que completó), devuelve {\"wins\": [logros, frases muy cortas en primera persona], \"improve\": [cosas a mejorar, frases muy cortas]}. Máximo 5 de cada. En español de España.",
                                             parts: [.text("Mi día: \(c.text)\nTareas completadas hoy: \(done.joined(separator: "; "))")], effort: "low")
            var n = checkIn(for: day)
            n.wins = Claude.strings(j["wins"]); n.improve = Claude.strings(j["improve"])
            save(n)
        }
    }

    static func weekStart(_ d: String) -> String {
        let date = Day.date(d)
        let wd = Day.cal.component(.weekday, from: date)   // 1 = domingo
        let back = (wd + 5) % 7
        return Day.add(d, days: -back)
    }

    @MainActor
    func makeWeekly() async {
        await run("weekly") { [self] in
            let ws = Store.weekStart(Day.today)
            let days = (0..<7).map { Day.add(ws, days: $0) }
            let checks = s.checkIns.filter { days.contains($0.date) }.sorted { $0.date < $1.date }
            let txt = checks.map { "\($0.date) (ánimo \($0.mood)/5): \($0.text)\nLogros: \($0.wins.joined(separator: "; "))\nA mejorar: \($0.improve.joined(separator: "; "))" }.joined(separator: "\n\n")
            let done = s.tasks.filter { $0.done && $0.doneAt.map { days.contains(Day.str($0)) } == true }.map(\.title)
            let pending = s.tasks.filter { !$0.done }.map(\.title)
            guard !checks.isEmpty || !done.isEmpty else { throw Claude.Failure.server("Haz al menos un chequeo nocturno esta semana para poder resumirla.") }
            let j = try await Claude.askJSON(system: "Eres un coach que hace la revisión semanal. Devuelve {\"summary\": [3–4 frases cortas sobre cómo fue la semana, con datos], \"improvements\": [3 mejoras principales, imperativo corto], \"focus\": enfoque de la semana que viene (pocas palabras), \"goal\": objetivo concreto, \"habit\": un hábito con hora}. En español de España.",
                                             parts: [.text("Chequeos de la semana:\n\(txt)\n\nTareas completadas: \(done.joined(separator: "; "))\nPendientes: \(pending.prefix(15).joined(separator: "; "))")], effort: "medium")
            let w = WeeklyReview(weekStart: ws, summary: Claude.strings(j["summary"]), improvements: Claude.strings(j["improvements"]),
                                 focus: j["focus"] as? String ?? "", goal: j["goal"] as? String ?? "", habit: j["habit"] as? String ?? "")
            withAnimation(.spring) { s.weekly.removeAll { $0.weekStart == ws }; s.weekly.insert(w, at: 0) }
        }
    }

    // MARK: - 4. Kit de marca

    @MainActor
    func makeKit(images: [Data]) async {
        await run("kit") { [self] in
            let i = s.brandInfo
            var parts: [Claude.Part] = images.prefix(4).map { .image($0, "image/jpeg") }
            parts.append(.text("""
            Sobre la empresa: \(i.about)
            Ejemplos de textos: \(i.samples)
            Referencias visuales: \(i.visual)
            Cliente ideal: \(i.audience)
            Oferta y servicios: \(i.offer)
            Lo que evitamos: \(i.avoid)
            """))
            let j = try await Claude.askJSON(system: "Eres directora de arte y estratega de marca. Con la información (y las imágenes de referencia, si las hay) crea un kit de marca. Devuelve {\"name\": nombre de la marca, \"tagline\": eslogan corto, \"colors\": [{\"name\": nombre del color, \"hex\": \"#RRGGBB\"}] (5 colores: principal, acento, oscuro, claro, neutro), \"heading_font\": una de [rounded, serif, default, monospaced], \"body_font\": una de [default, serif, rounded], \"tone\": [5–6 rasgos del tono de voz, cortos], \"visual\": [4–5 reglas visuales cortas]}. En español de España.",
                                             parts: parts, effort: "medium")
            var k = BrandKit()
            k.name = j["name"] as? String ?? ""
            k.tagline = j["tagline"] as? String ?? ""
            k.colors = ((j["colors"] as? [[String: Any]]) ?? []).compactMap { c in
                guard let h = c["hex"] as? String, h.hasPrefix("#") else { return nil }
                return BrandColor(name: c["name"] as? String ?? "", hex: h)
            }
            k.headingFont = j["heading_font"] as? String ?? "rounded"
            k.bodyFont = j["body_font"] as? String ?? "default"
            k.tone = Claude.strings(j["tone"]); k.visual = Claude.strings(j["visual"])
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { s.kit = k }
        }
    }

    @MainActor
    func makePiece(type: String, topic: String) async {
        guard let k = s.kit else { return }
        await run("piece") { [self] in
            let what: String
            switch type {
            case "post": what = "un post para Instagram/LinkedIn: un gancho de una línea, 3–5 líneas de cuerpo y una llamada a la acción, con 3–5 hashtags"
            case "email": what = "un email de newsletter: asunto, saludo, 3 párrafos cortos y una llamada a la acción"
            case "web": what = "el texto de una landing: titular, subtítulo, 3 beneficios con título y frase, y el texto del botón"
            default: what = "una propuesta comercial breve: título, el problema del cliente, la solución, 3 entregables, plazos orientativos y siguiente paso"
            }
            let j = try await Claude.askJSON(system: "Escribes contenido para la marca «\(k.name)». Tono de voz: \(k.tone.joined(separator: ", ")). Eslogan: \(k.tagline). Cliente ideal: \(s.brandInfo.audience). Oferta: \(s.brandInfo.offer). Evita: \(s.brandInfo.avoid). Ejemplos de cómo escriben: \(s.brandInfo.samples.prefix(1500)). Escribe en español de España. Devuelve {\"title\": titular o asunto, \"text\": el contenido completo}.",
                                             parts: [.text("Escribe \(what). Tema: \(topic)")], effort: "medium")
            let p = BrandPiece(type: type, topic: topic, title: j["title"] as? String ?? topic, text: j["text"] as? String ?? "")
            withAnimation(.spring) { s.pieces.insert(p, at: 0) }
        }
    }

    // MARK: - 5. Biblioteca de vida

    func save(_ it: LibItem) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if let i = s.library.firstIndex(where: { $0.id == it.id }) { s.library[i] = it } else { s.library.insert(it, at: 0) }
        }
    }
    func delete(_ it: LibItem) { withAnimation(.spring) { s.library.removeAll { $0.id == it.id } } }

    @MainActor
    func extractIdeas(_ id: String) async {
        guard let it = s.library.first(where: { $0.id == id }) else { return }
        await run("ideas-" + id) { [self] in
            let j = try await Claude.askJSON(system: "Resumes lo que una persona ha consumido (libros, artículos, podcasts…) en sus ideas clave accionables. Usa sus notas como base principal; si hay pocas, completa con lo que sabes de la obra. Devuelve {\"ideas\": [5–7 ideas clave, una frase cada una]}. En español de España.",
                                             parts: [.text("\(it.kind.label): «\(it.title)»\(it.author.isEmpty ? "" : " de \(it.author)")\nMis notas:\n\(it.notes)")], effort: "low")
            var n = it; n.ideas = Claude.strings(j["ideas"]); save(n)
        }
    }

    @MainActor
    func askLibrary(_ q: String) async {
        await run("library") { [self] in
            guard !s.library.isEmpty else { throw Claude.Failure.server("Aún no hay nada en tu biblioteca.") }
            let ctx = s.library.map { "<fuente titulo=\"\($0.title)\" autor=\"\($0.author)\" tipo=\"\($0.kind.label)\">\nIdeas: \($0.ideas.joined(separator: " | "))\nNotas: \($0.notes.prefix(4000))\n</fuente>" }.joined(separator: "\n")
            let a = try await Claude.ask(system: "Respondes usando la biblioteca personal de \(s.settings.name) (libros, artículos, podcasts que ha consumido y sus notas). Da la respuesta en español de España, en viñetas «•» que digan de qué fuente sale cada idea (título — autor). Si algo no está en su biblioteca, dilo. Al final, en una línea aparte, escribe «Fuentes:» y los títulos usados separados por «;».",
                                         parts: [.text(ctx + "\n\nPregunta: " + q)], effort: "medium")
            var answer = a; var sources: [String] = []
            if let r = a.range(of: "Fuentes:", options: .backwards) {
                answer = String(a[..<r.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                sources = a[r.upperBound...].split(separator: ";").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            }
            withAnimation(.spring) { s.libraryQA.insert(QA(question: q, answer: answer, sources: sources), at: 0) }
        }
    }
}
