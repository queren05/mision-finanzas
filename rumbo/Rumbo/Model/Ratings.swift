import SwiftUI

// MARK: - Notas de IMDb, Letterboxd y Rotten Tomatoes

struct FilmRatings: Codable, Hashable {
    var imdb: Double? = nil
    var imdbVotes: Int? = nil
    var metascore: Int? = nil
    var letterboxd: Double? = nil
    /// ruta de la ficha (film/…) para abrirla
    var letterboxdPath: String = ""
    var rtCritics: Int? = nil
    var rtAudience: Int? = nil
    /// m/… o tv/…
    var rtPath: String = ""
    var fetched: Date = Date()

    var isEmpty: Bool { imdb == nil && letterboxd == nil && rtCritics == nil && rtAudience == nil }

    init() {}
    enum CodingKeys: String, CodingKey { case imdb, imdbVotes, metascore, letterboxd, letterboxdPath, rtCritics, rtAudience, rtPath, fetched }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        imdb = try? c.decodeIfPresent(Double.self, forKey: .imdb)
        imdbVotes = try? c.decodeIfPresent(Int.self, forKey: .imdbVotes)
        metascore = try? c.decodeIfPresent(Int.self, forKey: .metascore)
        letterboxd = try? c.decodeIfPresent(Double.self, forKey: .letterboxd)
        letterboxdPath = (try? c.decodeIfPresent(String.self, forKey: .letterboxdPath)) ?? ""
        rtCritics = try? c.decodeIfPresent(Int.self, forKey: .rtCritics)
        rtAudience = try? c.decodeIfPresent(Int.self, forKey: .rtAudience)
        rtPath = (try? c.decodeIfPresent(String.self, forKey: .rtPath)) ?? ""
        fetched = (try? c.decodeIfPresent(Date.self, forKey: .fetched)) ?? .distantPast
    }
}

enum Ratings {
    private static let ua = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

    private static func get(_ url: URL, headers: [String: String] = [:]) async -> (String, URL?)? {
        var r = URLRequest(url: url, timeoutInterval: 15)
        r.setValue(ua, forHTTPHeaderField: "User-Agent")
        r.setValue("es-ES,es;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        for (k, v) in headers { r.setValue(v, forHTTPHeaderField: k) }
        guard let (d, resp) = try? await URLSession.shared.data(for: r),
              (resp as? HTTPURLResponse)?.statusCode == 200, let s = String(data: d, encoding: .utf8) else { return nil }
        return (s, resp.url)
    }
    private static func first(_ pattern: String, in s: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
              let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)), m.numberOfRanges > 1,
              let r = Range(m.range(at: 1), in: s) else { return nil }
        return String(s[r])
    }

    /// busca el código de IMDb por título y año
    static func imdbId(for f: Film) async -> String? {
        let r = await FilmSearch.search(f.title, kind: f.kind)
        return (r.first { !f.year.isEmpty && $0.film.year == f.year } ?? r.first)?.film.imdb
    }

    static func fetch(imdb: String, kind: FilmKind, title: String, year: String) async -> FilmRatings {
        async let a = imdbScore(imdb)
        async let b = letterboxd(imdb)
        async let c = rotten(imdb: imdb, kind: kind, title: title, year: year)
        var out = FilmRatings()
        let (i, l, r) = await (a, b, c)
        out.imdb = i.0; out.imdbVotes = i.1; out.metascore = i.2
        out.letterboxd = l.0; out.letterboxdPath = l.1
        out.rtCritics = r.0; out.rtAudience = r.1; out.rtPath = r.2
        out.fetched = Date()
        return out
    }

    private static func imdbScore(_ id: String) async -> (Double?, Int?, Int?) {
        var r = URLRequest(url: URL(string: "https://caching.graphql.imdb.com/")!, timeoutInterval: 15)
        r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.setValue("imdb-web-next", forHTTPHeaderField: "x-imdb-client-name")
        r.setValue(ua, forHTTPHeaderField: "User-Agent")
        let q = "{ title(id:\"\(id)\"){ ratingsSummary{aggregateRating voteCount} metacritic{metascore{score}} } }"
        r.httpBody = try? JSONSerialization.data(withJSONObject: ["query": q])
        guard let (d, _) = try? await URLSession.shared.data(for: r),
              let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              let t = (j["data"] as? [String: Any])?["title"] as? [String: Any] else { return (nil, nil, nil) }
        let rs = t["ratingsSummary"] as? [String: Any]
        let meta = ((t["metacritic"] as? [String: Any])?["metascore"] as? [String: Any])?["score"] as? Int
        return ((rs?["aggregateRating"] as? NSNumber)?.doubleValue, rs?["voteCount"] as? Int, meta)
    }

    private static func letterboxd(_ id: String) async -> (Double?, String) {
        guard let (html, final) = await get(URL(string: "https://letterboxd.com/imdb/\(id)/")!) else { return (nil, "") }
        let path = final.map { $0.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) } ?? ""
        let v = first(#"twitter:data2" content="([0-9.]+) out of 5""#, in: html) ?? first(#""ratingValue":([0-9.]+)"#, in: html)
        return (v.flatMap(Double.init), path.hasPrefix("film/") ? path : "")
    }

    private static func rotten(imdb: String, kind: FilmKind, title: String, year: String) async -> (Int?, Int?, String) {
        var path = await rtFromWikidata(imdb) ?? ""
        if path.isEmpty, let p = await rtSearch(title, kind: kind) { path = p }
        guard !path.isEmpty, let (html, _) = await get(URL(string: "https://www.rottentomatoes.com/" + path)!) else { return (nil, nil, path) }
        let critics = first(#""criticsScore":\{[^}]*?"score":"?([0-9]+)"#, in: html)
            ?? first(#""tomatometer":\{"tomatometer":([0-9]+)"#, in: html)
        let audience = first(#""audienceScore":\{[^}]*?"score":"?([0-9]+)"#, in: html)
        return (critics.flatMap { Int($0) }, audience.flatMap { Int($0) }, path)
    }

    /// Wikidata guarda el enlace de Rotten Tomatoes de cada película con su código de IMDb
    private static func rtFromWikidata(_ imdb: String) async -> String? {
        let q = "SELECT ?rt WHERE { ?f wdt:P345 \"\(imdb)\" . ?f wdt:P1258 ?rt }"
        var comps = URLComponents(string: "https://query.wikidata.org/sparql")!
        comps.queryItems = [URLQueryItem(name: "query", value: q), URLQueryItem(name: "format", value: "json")]
        var r = URLRequest(url: comps.url!, timeoutInterval: 15)
        r.setValue("Rumbo/1.0 (app personal)", forHTTPHeaderField: "User-Agent")
        guard let (d, _) = try? await URLSession.shared.data(for: r),
              let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              let b = ((j["results"] as? [String: Any])?["bindings"] as? [[String: Any]])?.first,
              let v = (b["rt"] as? [String: Any])?["value"] as? String else { return nil }
        return v
    }

    private static func rtSearch(_ title: String, kind: FilmKind) async -> String? {
        guard let enc = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let (html, _) = await get(URL(string: "https://www.rottentomatoes.com/search?search=\(enc)")!) else { return nil }
        let prefix = kind == .serie ? "tv" : "m"
        return first(#"href="https://www\.rottentomatoes\.com/("# + prefix + #"/[a-z0-9_\-]+)""#, in: html)
    }
}

extension Store {
    /// baja las notas de las webs (si son de hace más de una semana o se piden)
    @MainActor
    func loadRatings(_ id: String, force: Bool = false) async {
        guard var f = s.films.first(where: { $0.id == id }), !busy.contains("rate-" + id) else { return }
        if !force, let r = f.ratings, Date().timeIntervalSince(r.fetched) < 7 * 86400 { return }
        busy.insert("rate-" + id)
        defer { busy.remove("rate-" + id) }
        if f.imdb.isEmpty, let i = await Ratings.imdbId(for: f) { f.imdb = i }
        guard !f.imdb.isEmpty else { return }
        let r = await Ratings.fetch(imdb: f.imdb, kind: f.kind, title: f.title, year: f.year)
        guard var now = s.films.first(where: { $0.id == id }) else { return }
        now.imdb = f.imdb
        now.ratings = r
        save(now)
    }
}
