import Foundation

// MARK: - Base de conocimiento (Resources/datos.json, la misma que la versión web)

struct Ivl: Codable, Hashable {
    var km: Int?
    var y: Double?
    var text: String {
        let parts = [km.map { Money.km($0) }, y.map { "\(Int($0)) año\(Int($0) == 1 ? "" : "s")" }].compactMap { $0 }
        return parts.isEmpty ? "Sin intervalo" : parts.joined(separator: " / ")
    }
}

struct Pieza: Codable, Identifiable, Hashable {
    var id: String
    var cat: String
    var ic: String
    var n: String
    var opel: Ivl?
    var rec: Ivl?
    var use: Ivl?
    var why: String
    var spec: String
    var sint: [String]
    var tips: [String]
    var precio: String
    var dif: Int
    var des: String
    var f: [String]
}

struct Averia: Codable, Hashable {
    var n: String
    var sev: Int
    var sint: String
    var causa: String
    var sol: String
    var coste: String
    var f: [String]
}

struct Consejo: Codable, Hashable { var t: String; var d: String }
struct Fuente: Codable, Hashable { var n: String; var u: String }

struct Datos: Codable {
    var FUENTES: [String: Fuente]
    var CATS: [String: String]
    var PIEZAS: [Pieza]
    var AVERIAS: [Averia]
    var CONSEJOS: [Consejo]
    var FICHA: [[String]]

    static let shared: Datos = {
        guard let url = Bundle.main.url(forResource: "datos", withExtension: "json"),
              let d = try? Data(contentsOf: url), let v = try? JSONDecoder().decode(Datos.self, from: d) else {
            return Datos(FUENTES: [:], CATS: [:], PIEZAS: [], AVERIAS: [], CONSEJOS: [], FICHA: [])
        }
        return v
    }()
    static let catOrder = ["motor", "glp", "filtros", "frenos", "susp", "trans", "elec", "otros"]
}

// MARK: - Tus datos

struct PartState: Codable, Hashable {
    var km: Int?
    var date: String?
    var never: Bool?
    var unknown: Bool?
}

struct KmPoint: Codable, Hashable { var d: String; var km: Int }

struct LogEntry: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var part: String = ""
    var title: String = ""
    var date: String
    var km: Int
    var cost: Double = 0
    var `where`: String = ""
    var note: String = ""

    init(id: String = UUID().uuidString, part: String = "", title: String = "", date: String, km: Int, cost: Double = 0, where w: String = "", note: String = "") {
        self.id = id; self.part = part; self.title = title; self.date = date; self.km = km; self.cost = cost; self.where = w; self.note = note
    }
    enum CodingKeys: String, CodingKey { case id, part, title, date, km, cost, `where`, note }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        part = try c.decodeIfPresent(String.self, forKey: .part) ?? ""
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        date = try c.decodeIfPresent(String.self, forKey: .date) ?? Day.today
        km = (try? c.decodeIfPresent(Int.self, forKey: .km)) ?? Int((try? c.decodeIfPresent(Double.self, forKey: .km)) ?? 0)
        cost = (try? c.decodeIfPresent(Double.self, forKey: .cost)) ?? Double((try? c.decodeIfPresent(String.self, forKey: .cost)) ?? "0") ?? 0
        `where` = try c.decodeIfPresent(String.self, forKey: .where) ?? ""
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
    }
}

struct CState: Codable {
    var km: Int = 180000
    var kmLog: [KmPoint] = []
    var matric: String = "2019-06-01"
    var itv: String = ""
    var parts: [String: PartState] = [:]
    var logs: [LogEntry] = []
    var done: Bool = false

    init() {}
    enum CodingKeys: String, CodingKey { case km, kmLog, matric, itv, parts, logs, done }
    // lee también la copia de la versión web (le pueden faltar campos)
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        km = (try? c.decodeIfPresent(Int.self, forKey: .km)) ?? 180000
        kmLog = (try? c.decodeIfPresent([KmPoint].self, forKey: .kmLog)) ?? []
        matric = (try? c.decodeIfPresent(String.self, forKey: .matric)) ?? "2019-06-01"
        itv = (try? c.decodeIfPresent(String.self, forKey: .itv)) ?? ""
        parts = (try? c.decodeIfPresent([String: PartState].self, forKey: .parts)) ?? [:]
        logs = (try? c.decodeIfPresent([LogEntry].self, forKey: .logs)) ?? []
        done = (try? c.decodeIfPresent(Bool.self, forKey: .done)) ?? false
    }
}

// MARK: - Estado de cada pieza

enum PartStatus: String {
    case bad, unk, soon, ok, watch
    var label: String {
        switch self {
        case .bad: "Toca ya"
        case .soon: "Pronto"
        case .ok: "Al día"
        case .unk: "Sin datos"
        case .watch: "Vigilar"
        }
    }
    var order: Int {
        switch self {
        case .bad: 0
        case .unk: 1
        case .soon: 2
        case .ok: 3
        case .watch: 4
        }
    }
}

struct PartInfo {
    var st: PartStatus
    var pct: Double = 0
    var dueKm: Int? = nil
    var dueDate: String? = nil
    var txt: String = ""
}
