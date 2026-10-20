import SwiftUI

// MARK: - Pelis y series (estilo Letterboxd)

enum FilmKind: String, Codable, CaseIterable, Identifiable {
    case pelicula, serie
    var id: String { rawValue }
    var label: String { self == .pelicula ? "Película" : "Serie" }
}

enum FilmStatus: String, Codable, CaseIterable, Identifiable {
    case quiero, viendo, vista
    var id: String { rawValue }
    func label(_ k: FilmKind) -> String {
        switch self {
        case .quiero: "Quiero verla"
        case .viendo: "Viéndola"
        case .vista: "Vista"
        }
    }
    var icon: String {
        switch self {
        case .quiero: "clock"
        case .viendo: "play.circle"
        case .vista: "eye.fill"
        }
    }
}

struct Film: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var kind: FilmKind = .pelicula
    var title: String
    var year: String = ""
    var director: String = ""
    var genre: String = ""
    var synopsis: String = ""
    var runtime: Int = 0
    var season: String = ""
    /// póster guardado en Documentos/files
    var poster: String? = nil
    var posterURL: String = ""
    var status: FilmStatus = .vista
    /// de 0 a 5, de media en media estrella
    var rating: Double = 0
    var liked: Bool = false
    var review: String = ""
    /// días en que la has visto (yyyy-MM-dd), el más reciente primero
    var watched: [String] = []
    var created: Date = Date()

    var lastWatched: String { watched.max() ?? "" }
}

extension Film {
    enum CodingKeys: String, CodingKey { case id, kind, title, year, director, genre, synopsis, runtime, season, poster, posterURL, status, rating, liked, review, watched, created }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        kind = (try? c.decodeIfPresent(FilmKind.self, forKey: .kind)) ?? .pelicula
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        year = try c.decodeIfPresent(String.self, forKey: .year) ?? ""
        director = try c.decodeIfPresent(String.self, forKey: .director) ?? ""
        genre = try c.decodeIfPresent(String.self, forKey: .genre) ?? ""
        synopsis = try c.decodeIfPresent(String.self, forKey: .synopsis) ?? ""
        runtime = try c.decodeIfPresent(Int.self, forKey: .runtime) ?? 0
        season = try c.decodeIfPresent(String.self, forKey: .season) ?? ""
        poster = try c.decodeIfPresent(String.self, forKey: .poster)
        posterURL = try c.decodeIfPresent(String.self, forKey: .posterURL) ?? ""
        status = (try? c.decodeIfPresent(FilmStatus.self, forKey: .status)) ?? .vista
        rating = try c.decodeIfPresent(Double.self, forKey: .rating) ?? 0
        liked = try c.decodeIfPresent(Bool.self, forKey: .liked) ?? false
        review = try c.decodeIfPresent(String.self, forKey: .review) ?? ""
        watched = try c.decodeIfPresent([String].self, forKey: .watched) ?? []
        created = try c.decodeIfPresent(Date.self, forKey: .created) ?? Date()
    }
}

/// buscador del catálogo de Apple (iTunes), sin clave
enum FilmSearch {
    struct Result: Identifiable, Hashable {
        var id: String
        var film: Film
    }

    static func search(_ q: String, kind: FilmKind) async -> [Result] {
        var c = URLComponents(string: "https://itunes.apple.com/search")!
        c.queryItems = [URLQueryItem(name: "term", value: q), URLQueryItem(name: "country", value: "es"), URLQueryItem(name: "lang", value: "es_es"),
                        URLQueryItem(name: "limit", value: "25"),
                        URLQueryItem(name: "media", value: kind == .pelicula ? "movie" : "tvShow"),
                        URLQueryItem(name: "entity", value: kind == .pelicula ? "movie" : "tvSeason")]
        guard let url = c.url, let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else { return [] }
        var seen = Set<String>()
        return results.compactMap { r in
            let art = (r["artworkUrl100"] as? String ?? "").replacingOccurrences(of: "100x100bb", with: "600x600bb")
            let year = String((r["releaseDate"] as? String ?? "").prefix(4))
            var f = Film(kind: kind, title: "")
            if kind == .pelicula {
                f.title = r["trackName"] as? String ?? ""
                f.director = r["artistName"] as? String ?? ""
                f.runtime = ((r["trackTimeMillis"] as? Int) ?? 0) / 60000
            } else {
                f.title = r["artistName"] as? String ?? (r["collectionName"] as? String ?? "")
                let col = r["collectionName"] as? String ?? ""
                f.season = col.hasPrefix(f.title) ? String(col.dropFirst(f.title.count)).trimmingCharacters(in: CharacterSet(charactersIn: " ,:-–")) : col
            }
            f.year = year
            f.genre = r["primaryGenreName"] as? String ?? ""
            f.synopsis = r["longDescription"] as? String ?? (r["shortDescription"] as? String ?? "")
            f.posterURL = art
            let key = f.title + f.season + f.year
            guard !f.title.isEmpty, !seen.contains(key) else { return nil }
            seen.insert(key)
            return Result(id: key, film: f)
        }
    }

    /// descarga el póster y lo guarda en el iPhone
    static func downloadPoster(_ url: String) async -> String? {
        guard let u = URL(string: url), let (d, _) = try? await URLSession.shared.data(from: u), UIImage(data: d) != nil else { return nil }
        return Extract.store(d, ext: "jpg")
    }
}

extension Store {
    func save(_ f: Film) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if let i = s.films.firstIndex(where: { $0.id == f.id }) { s.films[i] = f } else { s.films.insert(f, at: 0) }
        }
    }
    func delete(_ f: Film) {
        if let p = f.poster { try? FileManager.default.removeItem(at: Extract.url(p)) }
        withAnimation(.spring) { s.films.removeAll { $0.id == f.id } }
    }
    /// guarda la peli y baja su póster
    @MainActor
    func add(_ f: Film) async {
        var f = f
        save(f)
        if f.poster == nil, !f.posterURL.isEmpty, let p = await FilmSearch.downloadPoster(f.posterURL) {
            f = s.films.first { $0.id == f.id } ?? f
            f.poster = p
            save(f)
        }
    }

    @MainActor
    func askFilms(_ q: String) async {
        await run("films") { [self] in
            let list = s.films.map { f in
                "- \(f.kind.label): \(f.title)\(f.year.isEmpty ? "" : " (\(f.year))") · \(f.status.label(f.kind))\(f.rating > 0 ? " · \(f.rating) estrellas" : "")\(f.liked ? " · me encantó" : "")\(f.review.isEmpty ? "" : " · reseña: \(f.review.prefix(300))")"
            }.joined(separator: "\n")
            let a = try await Claude.ask(system: "Eres un crítico de cine cercano que conoce los gustos de \(s.settings.name) por lo que ha visto y puntuado. Responde en español de España, en viñetas «•» cortas. Si recomiendas, da título (año) y por qué le va a gustar según lo que ha visto. No recomiendes lo que ya ha visto.",
                                         parts: [.text("Lo que he visto y quiero ver:\n\(list.isEmpty ? "(nada aún)" : list)\n\nPregunta: \(q)")], effort: "low")
            withAnimation(.spring) { s.filmQA.insert(QA(question: q, answer: a), at: 0) }
        }
    }
}
