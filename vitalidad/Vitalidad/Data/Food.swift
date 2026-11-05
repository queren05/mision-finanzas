import Foundation
import SwiftUI

/// Un alimento: valores por 100 g.
struct FoodItem: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var brand: String?
    var kcal: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    /// Gramos de una ración, si se sabe.
    var serving: Double?
    var image: String?
}

enum Meal: String, CaseIterable, Codable, Identifiable {
    case desayuno, comida, merienda, cena, picoteo
    var id: String { rawValue }
    var title: String {
        switch self {
        case .desayuno: "Desayuno"
        case .comida: "Comida"
        case .merienda: "Merienda"
        case .cena: "Cena"
        case .picoteo: "Picoteo"
        }
    }
    var symbol: String {
        switch self {
        case .desayuno: "cup.and.saucer.fill"
        case .comida: "fork.knife"
        case .merienda: "carrot.fill"
        case .cena: "moon.stars.fill"
        case .picoteo: "popcorn.fill"
        }
    }
    static var now: Meal {
        let h = Calendar.current.component(.hour, from: .now)
        return h < 11 ? .desayuno : h < 16 ? .comida : h < 19 ? .merienda : h < 23 ? .cena : .picoteo
    }
}

/// Lo que has apuntado que comiste.
struct FoodEntry: Codable, Hashable, Identifiable {
    var id = UUID()
    var date: Date
    var meal: Meal
    var item: FoodItem
    var grams: Double
    /// Lo guardado en Salud (para poder borrarlo).
    var saved: [UUID] = []

    var kcal: Double { item.kcal * grams / 100 }
    var protein: Double { item.protein * grams / 100 }
    var carbs: Double { item.carbs * grams / 100 }
    var fat: Double { item.fat * grams / 100 }
}

@Observable @MainActor
final class FoodLog {
    static let shared = FoodLog()

    private(set) var entries: [FoodEntry] = []
    private(set) var recents: [FoodItem] = []
    private let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("comidas.json")

    private struct Saved: Codable {
        var entries: [FoodEntry]
        var recents: [FoodItem]
    }

    init() {
        if Launch.demo {
            let cal = Calendar.current
            let t = cal.startOfDay(for: .now)
            let items = [
                (FoodItem(id: "d1", name: "Tostada con tomate y aceite", kcal: 230, protein: 6, carbs: 34, fat: 8), 120.0, Meal.desayuno, 8.0),
                (FoodItem(id: "d2", name: "Café con leche", kcal: 45, protein: 3, carbs: 4.5, fat: 1.6), 250, .desayuno, 8.1),
                (FoodItem(id: "d3", name: "Lentejas estofadas", kcal: 120, protein: 8, carbs: 15, fat: 3), 400, .comida, 14.5),
                (FoodItem(id: "d4", name: "Yogur griego", brand: "Danone", kcal: 120, protein: 5, carbs: 4, fat: 9.5), 125, .merienda, 17.5),
            ]
            entries = items.map { FoodEntry(date: t.addingTimeInterval($0.3 * 3600), meal: $0.2, item: $0.0, grams: $0.1) }
            recents = items.map(\.0)
        } else if let d = try? Data(contentsOf: url), let s = try? JSONDecoder().decode(Saved.self, from: d) {
            entries = s.entries
            recents = s.recents
        }
    }

    private func save() {
        guard !Launch.demo else { return }
        if let d = try? JSONEncoder().encode(Saved(entries: entries, recents: recents)) { try? d.write(to: url, options: .atomic) }
    }

    func entries(on day: Date) -> [FoodEntry] {
        entries.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }.sorted { $0.date < $1.date }
    }

    func add(_ item: FoodItem, grams: Double, meal: Meal, day: Date, store: HealthStore) async {
        let cal = Calendar.current
        let date = cal.isDateInToday(day) ? Date.now : cal.date(bySettingHour: 13, minute: 0, second: 0, of: day) ?? day
        var e = FoodEntry(date: date, meal: meal, item: item, grams: grams)
        e.saved = await store.source.saveFood(name: item.name, date: date, kcal: e.kcal, protein: e.protein, carbs: e.carbs, fat: e.fat)
        entries.append(e)
        recents.removeAll { $0.id == item.id }
        recents.insert(item, at: 0)
        recents = Array(recents.prefix(40))
        save()
        await store.refresh(full: false)
    }

    func delete(_ e: FoodEntry, store: HealthStore) async {
        await store.source.deleteSamples(e.saved)
        entries.removeAll { $0.id == e.id }
        save()
        await store.refresh(full: false)
    }

    func addWater(_ liters: Double, store: HealthStore) async {
        _ = await store.source.saveWater(liters, date: .now)
        await store.refresh(full: false)
    }
}

// MARK: - Open Food Facts (base de datos libre y gratuita)

enum OpenFoodFacts {
    private static let fields = "code,product_name,product_name_es,brands,nutriments,serving_quantity,image_front_small_url"

    private static func request(_ url: URL) -> URLRequest {
        var r = URLRequest(url: url)
        r.timeoutInterval = 20
        r.setValue("Vitalidad/1.0 (app personal)", forHTTPHeaderField: "User-Agent")
        return r
    }

    static func product(_ code: String) async -> FoodItem? {
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(code).json?fields=\(fields)"),
              let (data, _) = try? await URLSession.shared.data(for: request(url)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let p = json["product"] as? [String: Any] else { return nil }
        return parse(p, code: code)
    }

    static func search(_ q: String) async -> [FoodItem] {
        var c = URLComponents(string: "https://es.openfoodfacts.org/cgi/search.pl")!
        c.queryItems = [
            URLQueryItem(name: "search_terms", value: q), URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"), URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: "25"), URLQueryItem(name: "fields", value: fields),
        ]
        guard let url = c.url, let (data, _) = try? await URLSession.shared.data(for: request(url)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = json["products"] as? [[String: Any]] else { return [] }
        return list.compactMap { parse($0, code: $0["code"] as? String) }
    }

    private static func num(_ v: Any?) -> Double? {
        if let d = v as? Double { return d }
        if let i = v as? Int { return Double(i) }
        if let s = v as? String { return Double(s.replacingOccurrences(of: ",", with: ".")) }
        return nil
    }

    private static func parse(_ p: [String: Any], code: String?) -> FoodItem? {
        let n = p["nutriments"] as? [String: Any] ?? [:]
        let name = (p["product_name_es"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? (p["product_name"] as? String) ?? ""
        guard !name.isEmpty, let kcal = num(n["energy-kcal_100g"]) ?? num(n["energy_100g"]).map({ $0 / 4.184 }) else { return nil }
        return FoodItem(id: code ?? UUID().uuidString, name: name,
                        brand: (p["brands"] as? String)?.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces),
                        kcal: kcal, protein: num(n["proteins_100g"]) ?? 0, carbs: num(n["carbohydrates_100g"]) ?? 0, fat: num(n["fat_100g"]) ?? 0,
                        serving: num(p["serving_quantity"]), image: p["image_front_small_url"] as? String)
    }
}

// MARK: - Foto con Claude

enum FoodPhoto {
    /// Lo que hay en la foto, con sus gramos y valores ya calculados para esa cantidad.
    static func analyze(_ jpeg: Data, hint: String) async throws -> [(FoodItem, Double)] {
        let obj = try await Claude.askJSON(
            system: "Eres nutricionista. Mira la foto de comida y estima cada alimento por separado, con la cantidad que se ve en el plato. Usa nombres en español de España.",
            prompt: "Devuelve {\"items\":[{\"nombre\":\"…\",\"gramos\":0,\"kcal\":0,\"proteinas\":0,\"carbohidratos\":0,\"grasas\":0}]} con los valores TOTALES de la cantidad de la foto." + (hint.isEmpty ? "" : " Nota: \(hint)"),
            image: jpeg)
        let items = obj["items"] as? [[String: Any]] ?? []
        return items.compactMap { i in
            func d(_ k: String) -> Double { (i[k] as? Double) ?? Double(i[k] as? Int ?? 0) }
            let g = max(1, d("gramos"))
            guard let name = i["nombre"] as? String else { return nil }
            let k = 100 / g
            return (FoodItem(id: "foto-" + UUID().uuidString, name: name, kcal: d("kcal") * k, protein: d("proteinas") * k,
                             carbs: d("carbohidratos") * k, fat: d("grasas") * k, serving: g), g)
        }
    }
}
