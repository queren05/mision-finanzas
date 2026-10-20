import Foundation

// MARK: - 1. Panel de vida

struct TaskItem: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var title: String
    var done: Bool = false
    var priority: Bool = false
    /// yyyy-MM-dd o vacío
    var due: String = ""
    var created: Date = Date()
    var doneAt: Date? = nil
}

struct Briefing: Codable, Hashable {
    var date: String
    var text: String
}

// MARK: - 2. Segundo cerebro

enum BrainFolder: String, Codable, CaseIterable, Identifiable {
    case contratos, alquileres, seguros, finanzas, salud, notas, recibos, documentos, otros
    var id: String { rawValue }
    var label: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
    var icon: String {
        switch self {
        case .contratos: "signature"
        case .alquileres: "house.fill"
        case .seguros: "shield.lefthalf.filled"
        case .finanzas: "eurosign.circle.fill"
        case .salud: "cross.case.fill"
        case .notas: "note.text"
        case .recibos: "receipt.fill"
        case .documentos: "doc.text.fill"
        case .otros: "folder.fill"
        }
    }
    var color: String {
        switch self {
        case .contratos: "#b39cff"
        case .alquileres: "#ff9f7a"
        case .seguros: "#7ac8ff"
        case .finanzas: "#6fd49b"
        case .salud: "#ff8686"
        case .notas: "#f0c46a"
        case .recibos: "#62cfd0"
        case .documentos: "#8fb4ff"
        case .otros: "#a9b3c2"
        }
    }
}

struct BrainDoc: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var title: String
    var folder: BrainFolder = .documentos
    /// "pdf", "image", "note"
    var kind: String = "note"
    /// archivo guardado en Documentos/files (si lo hay)
    var file: String? = nil
    /// texto del documento (de la nota, del PDF o reconocido en la foto)
    var text: String = ""
    var summary: String = ""
    var created: Date = Date()
    /// importe total (recibos y facturas)
    var amount: Double? = nil
    /// fecha del documento (yyyy-MM-dd) y fecha en que vence o se renueva
    var docDate: String = ""
    var due: String = ""
    /// tienda, empresa o quien lo emite
    var issuer: String = ""
}

extension BrainDoc {
    /// importe y fechas en una línea, para Claude
    var facts: String {
        var f: [String] = []
        if !issuer.isEmpty { f.append("Emisor: \(issuer)") }
        if let amount { f.append("Importe: \(String(format: "%.2f", amount)) €") }
        if !docDate.isEmpty { f.append("Fecha: \(docDate)") }
        if !due.isEmpty { f.append("Vence: \(due)") }
        return f.joined(separator: ". ")
    }
    enum CodingKeys: String, CodingKey { case id, title, folder, kind, file, text, summary, created, amount, docDate, due, issuer }
    // tolera documentos guardados por versiones anteriores
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? "Documento"
        folder = (try? c.decodeIfPresent(BrainFolder.self, forKey: .folder)) ?? .documentos
        kind = try c.decodeIfPresent(String.self, forKey: .kind) ?? "note"
        file = try c.decodeIfPresent(String.self, forKey: .file)
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        summary = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
        created = try c.decodeIfPresent(Date.self, forKey: .created) ?? Date()
        amount = try c.decodeIfPresent(Double.self, forKey: .amount)
        docDate = try c.decodeIfPresent(String.self, forKey: .docDate) ?? ""
        due = try c.decodeIfPresent(String.self, forKey: .due) ?? ""
        issuer = try c.decodeIfPresent(String.self, forKey: .issuer) ?? ""
    }
}

struct QA: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var question: String
    var answer: String
    var sources: [String] = []
    var date: Date = Date()
}

// MARK: - 3. Agente de revisión

struct CheckIn: Codable, Identifiable, Hashable {
    var id: String { date }
    var date: String
    var mood: Int = 3
    var text: String = ""
    var wins: [String] = []
    var improve: [String] = []
}

struct WeeklyReview: Codable, Identifiable, Hashable {
    var id: String { weekStart }
    var weekStart: String
    var summary: [String] = []
    var improvements: [String] = []
    var focus: String = ""
    var goal: String = ""
    var habit: String = ""
}

// MARK: - 4. Kit de marca

struct BrandInfo: Codable, Hashable {
    var about = ""
    var samples = ""
    var visual = ""
    var audience = ""
    var offer = ""
    var avoid = ""
}

struct BrandColor: Codable, Hashable { var name: String; var hex: String }

struct BrandKit: Codable, Hashable {
    var name: String = ""
    var tagline: String = ""
    var colors: [BrandColor] = []
    var headingFont: String = "rounded"
    var bodyFont: String = "default"
    var tone: [String] = []
    var visual: [String] = []
    var created: Date = Date()
}

struct BrandPiece: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    /// post, email, web, propuesta
    var type: String
    var topic: String
    var title: String = ""
    var text: String
    var date: Date = Date()
}

// MARK: - 5. Biblioteca de vida

enum ItemKind: String, Codable, CaseIterable, Identifiable {
    case libro, articulo, podcast, video, curso
    var id: String { rawValue }
    var label: String {
        switch self {
        case .libro: "Libro"
        case .articulo: "Artículo"
        case .podcast: "Podcast"
        case .video: "Vídeo"
        case .curso: "Curso"
        }
    }
    var icon: String {
        switch self {
        case .libro: "book.closed.fill"
        case .articulo: "newspaper.fill"
        case .podcast: "mic.fill"
        case .video: "play.rectangle.fill"
        case .curso: "graduationcap.fill"
        }
    }
}

enum ItemStatus: String, Codable, CaseIterable, Identifiable {
    case pendiente, enCurso, terminado
    var id: String { rawValue }
    var label: String {
        switch self {
        case .pendiente: "Pendiente"
        case .enCurso: "En curso"
        case .terminado: "Terminado"
        }
    }
}

struct LibItem: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var kind: ItemKind = .libro
    var title: String
    var author: String = ""
    var status: ItemStatus = .pendiente
    var rating: Int = 0
    var notes: String = ""
    var ideas: [String] = []
    var color: String = "#b39cff"
    var created: Date = Date()
    var finished: String = ""
}

// MARK: - Ajustes y estado

struct Settings: Codable, Hashable {
    var name: String = "David"
    var accent: String = "#b39cff"
    var notifyBriefing: Bool = true
    var briefingHour: Int = 8
    var notifyCheckIn: Bool = true
    var checkInHour: Int = 22
    var notifyWeekly: Bool = true
    var faceID: Bool = false
}

struct RState: Codable {
    var tasks: [TaskItem] = []
    var briefing: Briefing? = nil
    var docs: [BrainDoc] = []
    var brainQA: [QA] = []
    var checkIns: [CheckIn] = []
    var weekly: [WeeklyReview] = []
    var brandInfo = BrandInfo()
    var kit: BrandKit? = nil
    var pieces: [BrandPiece] = []
    var library: [LibItem] = []
    var libraryQA: [QA] = []
    var films: [Film] = []
    var filmQA: [QA] = []
    var settings = Settings()

    init() {}
    enum CodingKeys: String, CodingKey { case tasks, briefing, docs, brainQA, checkIns, weekly, brandInfo, kit, pieces, library, libraryQA, films, filmQA, settings }
    // tolera datos guardados por versiones anteriores
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        tasks = try c.decodeIfPresent([TaskItem].self, forKey: .tasks) ?? []
        briefing = try c.decodeIfPresent(Briefing.self, forKey: .briefing)
        docs = try c.decodeIfPresent([BrainDoc].self, forKey: .docs) ?? []
        brainQA = try c.decodeIfPresent([QA].self, forKey: .brainQA) ?? []
        checkIns = try c.decodeIfPresent([CheckIn].self, forKey: .checkIns) ?? []
        weekly = try c.decodeIfPresent([WeeklyReview].self, forKey: .weekly) ?? []
        brandInfo = try c.decodeIfPresent(BrandInfo.self, forKey: .brandInfo) ?? BrandInfo()
        kit = try c.decodeIfPresent(BrandKit.self, forKey: .kit)
        pieces = try c.decodeIfPresent([BrandPiece].self, forKey: .pieces) ?? []
        library = try c.decodeIfPresent([LibItem].self, forKey: .library) ?? []
        libraryQA = try c.decodeIfPresent([QA].self, forKey: .libraryQA) ?? []
        films = (try? c.decodeIfPresent([Film].self, forKey: .films)) ?? []
        filmQA = (try? c.decodeIfPresent([QA].self, forKey: .filmQA)) ?? []
        settings = try c.decodeIfPresent(Settings.self, forKey: .settings) ?? Settings()
    }
}
