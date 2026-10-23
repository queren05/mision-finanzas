import SwiftUI
import UserNotifications
import BackgroundTasks

// MARK: - Jellyfin: lo que ves en el servidor se apunta solo en Mi cine

enum Jellyfin {
    static let refreshTask = "es.david.rumbo.cine"

    enum Failure: LocalizedError {
        case login, server
        var errorDescription: String? {
            switch self {
            case .login: "Usuario o contraseña incorrectos."
            case .server: "No se puede conectar con Jellyfin. Revisa la dirección y que Tailscale esté encendido."
            }
        }
    }

    private static var device: String {
        if let d = UserDefaults.standard.string(forKey: "jf-device") { return d }
        let d = UUID().uuidString
        UserDefaults.standard.set(d, forKey: "jf-device")
        return d
    }
    private static func auth(_ token: String?) -> String {
        "MediaBrowser Client=\"Rumbo\", Device=\"iPhone\", DeviceId=\"\(device)\", Version=\"1.0\"" + (token.map { ", Token=\"\($0)\"" } ?? "")
    }
    static func base(_ url: String) -> String {
        var u = url.trimmingCharacters(in: .whitespacesAndNewlines)
        while u.hasSuffix("/") { u.removeLast() }
        if !u.isEmpty && !u.hasPrefix("http") { u = "http://" + u }
        return u
    }

    /// inicia sesión y devuelve (id del usuario, sesión)
    static func login(url: String, user: String, password: String) async throws -> (String, String) {
        guard let u = URL(string: base(url) + "/Users/AuthenticateByName") else { throw Failure.server }
        var r = URLRequest(url: u, timeoutInterval: 15)
        r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.setValue(auth(nil), forHTTPHeaderField: "Authorization")
        r.httpBody = try JSONSerialization.data(withJSONObject: ["Username": user, "Pw": password])
        guard let (d, resp) = try? await URLSession.shared.data(for: r) else { throw Failure.server }
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if code == 401 || code == 400 { throw Failure.login }
        guard code == 200, let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              let token = j["AccessToken"] as? String, let id = (j["User"] as? [String: Any])?["Id"] as? String else { throw Failure.server }
        return (id, token)
    }

    static func items(url: String, token: String, query: [String: String]) async throws -> [[String: Any]] {
        var c = URLComponents(string: base(url) + "/Items")
        c?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let u = c?.url else { throw Failure.server }
        var r = URLRequest(url: u, timeoutInterval: 20)
        r.setValue(auth(token), forHTTPHeaderField: "Authorization")
        guard let (d, resp) = try? await URLSession.shared.data(for: r) else { throw Failure.server }
        if (resp as? HTTPURLResponse)?.statusCode == 401 { throw Failure.login }
        guard let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any], let items = j["Items"] as? [[String: Any]] else { throw Failure.server }
        return items
    }

    /// «2026-10-22T21:33:12.1234567Z» → fecha
    static func date(_ s: Any?) -> Date? {
        guard let s = s as? String, s.count >= 19 else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: String(s.prefix(19)) + "Z")
    }

    static func scheduleRefresh() {
        let r = BGAppRefreshTaskRequest(identifier: refreshTask)
        r.earliestBeginDate = Date().addingTimeInterval(20 * 60)
        try? BGTaskScheduler.shared.submit(r)
    }
}

/// abre la ficha de una peli para puntuarla (desde el aviso)
@Observable
final class Router {
    static let shared = Router()
    var rateFilm: String? = nil
    var tab: String = "hoy"
    /// página abierta en una hoja (si no está en la barra)
    var sheetPage: String? = nil
}

extension Store {
    var jellyfinLinked: Bool { !s.settings.jellyfinUserId.isEmpty && !Keychain.jellyfinToken.isEmpty }

    @MainActor
    func linkJellyfin(url: String, user: String, password: String) async throws {
        let (id, token) = try await Jellyfin.login(url: url, user: user, password: password)
        Keychain.jellyfinToken = token
        s.settings.jellyfinURL = Jellyfin.base(url)
        s.settings.jellyfinUser = user
        s.settings.jellyfinUserId = id
        s.settings.jellyfinLastSync = nil
        _ = try await syncJellyfin()
    }

    func unlinkJellyfin() {
        Keychain.jellyfinToken = ""
        s.settings.jellyfinUserId = ""
        s.settings.jellyfinLastSync = nil
    }

    /// trae lo visto en Jellyfin; avisa de lo que has terminado desde la última vez. Devuelve cuántas cosas nuevas hay
    @MainActor @discardableResult
    func syncJellyfin() async throws -> Int {
        guard jellyfinLinked, !busy.contains("jellyfin") else { return 0 }
        busy.insert("jellyfin")
        defer { busy.remove("jellyfin") }
        let st = s.settings, token = Keychain.jellyfinToken
        let since = st.jellyfinLastSync
        let first = since == nil
        let fields = "ProviderIds,Overview,Genres,People"
        var newest = since ?? .distantPast
        var finished: [Film] = []
        var changes = 0

        func find(_ title: String, _ year: String, _ imdb: String, _ jf: String, _ kind: FilmKind) -> Int? {
            s.films.firstIndex { f in
                f.kind == kind && ((!jf.isEmpty && f.jellyfin == jf) || (!imdb.isEmpty && f.imdb == imdb)
                    || (f.title.lowercased() == title.lowercased() && (f.year.isEmpty || year.isEmpty || f.year == year)))
            }
        }
        func make(_ it: [String: Any], kind: FilmKind) -> Film {
            var f = Film(kind: kind, title: it["Name"] as? String ?? "")
            f.year = (it["ProductionYear"] as? Int).map(String.init) ?? ""
            f.imdb = (it["ProviderIds"] as? [String: Any])?["Imdb"] as? String ?? ""
            f.jellyfin = it["Id"] as? String ?? ""
            f.synopsis = it["Overview"] as? String ?? ""
            f.genre = (it["Genres"] as? [String] ?? []).prefix(3).joined(separator: ", ")
            if let ticks = it["RunTimeTicks"] as? Int64 { f.runtime = Int(ticks / 600_000_000) } else if let ticks = it["RunTimeTicks"] as? Int { f.runtime = ticks / 600_000_000 }
            f.director = (it["People"] as? [[String: Any]] ?? []).filter { $0["Type"] as? String == "Director" }.compactMap { $0["Name"] as? String }.prefix(2).joined(separator: ", ")
            f.posterURL = Jellyfin.base(st.jellyfinURL) + "/Items/\(f.jellyfin)/Images/Primary?maxHeight=750&quality=85"
            return f
        }

        // películas terminadas
        let played = try await Jellyfin.items(url: st.jellyfinURL, token: token, query: [
            "userId": st.jellyfinUserId, "Recursive": "true", "IncludeItemTypes": "Movie", "Filters": "IsPlayed",
            "SortBy": "DatePlayed", "SortOrder": "Descending", "Fields": fields, "Limit": first ? "500" : "60", "enableUserData": "true"])
        for it in played {
            guard let when = Jellyfin.date((it["UserData"] as? [String: Any])?["LastPlayedDate"]) else { continue }
            if let since, when <= since { continue }
            newest = max(newest, when)
            let day = Day.str(when)
            let n = make(it, kind: .pelicula)
            if let i = find(n.title, n.year, n.imdb, n.jellyfin, .pelicula) {
                var f = s.films[i]
                if f.imdb.isEmpty { f.imdb = n.imdb }
                f.jellyfin = n.jellyfin
                if !f.watched.contains(day) { f.watched.append(day); changes += 1; if !first { finished.append(f) } }
                f.status = .vista
                save(f)
            } else {
                var f = n
                f.status = .vista; f.watched = [day]
                save(f); changes += 1
                if !first { finished.append(f) }
            }
        }

        // películas a medias
        let resume = try await Jellyfin.items(url: st.jellyfinURL, token: token, query: [
            "userId": st.jellyfinUserId, "Recursive": "true", "IncludeItemTypes": "Movie", "Filters": "IsResumable",
            "Fields": fields, "Limit": "20", "enableUserData": "true"])
        for it in resume {
            let n = make(it, kind: .pelicula)
            if let i = find(n.title, n.year, n.imdb, n.jellyfin, .pelicula) {
                if s.films[i].status == .quiero { var f = s.films[i]; f.status = .viendo; f.jellyfin = n.jellyfin; save(f); changes += 1 }
            } else {
                var f = n; f.status = .viendo; save(f); changes += 1
            }
        }

        // series: capítulos vistos desde la última vez
        let eps = try await Jellyfin.items(url: st.jellyfinURL, token: token, query: [
            "userId": st.jellyfinUserId, "Recursive": "true", "IncludeItemTypes": "Episode", "Filters": "IsPlayed",
            "SortBy": "DatePlayed", "SortOrder": "Descending", "Limit": first ? "400" : "100", "enableUserData": "true"])
        var seriesDay: [String: Date] = [:]
        for e in eps {
            guard let sid = e["SeriesId"] as? String, let when = Jellyfin.date((e["UserData"] as? [String: Any])?["LastPlayedDate"]) else { continue }
            if let since, when <= since { continue }
            newest = max(newest, when)
            seriesDay[sid] = max(seriesDay[sid] ?? .distantPast, when)
        }
        if !seriesDay.isEmpty {
            let series = try await Jellyfin.items(url: st.jellyfinURL, token: token, query: [
                "userId": st.jellyfinUserId, "Ids": seriesDay.keys.joined(separator: ","), "Fields": fields, "enableUserData": "true"])
            for it in series {
                let n = make(it, kind: .serie)
                let all = (it["UserData"] as? [String: Any])?["Played"] as? Bool ?? false
                let day = Day.str(seriesDay[n.jellyfin] ?? Date())
                var f = find(n.title, n.year, n.imdb, n.jellyfin, .serie).map { s.films[$0] } ?? { var x = n; x.status = .viendo; return x }()
                if f.imdb.isEmpty { f.imdb = n.imdb }
                f.jellyfin = n.jellyfin
                if all && f.status != .vista {
                    f.status = .vista
                    if !f.watched.contains(day) { f.watched.append(day) }
                    if !first { finished.append(f) }
                } else if !all && f.status != .viendo {
                    f.status = .viendo
                }
                save(f); changes += 1
            }
        }

        s.settings.jellyfinLastSync = newest == .distantPast ? (since ?? Date()) : newest

        // pósters de lo nuevo, sin esperar
        let pending = s.films.filter { $0.poster == nil && !$0.jellyfin.isEmpty && $0.posterURL.contains("/Items/") }
        if !pending.isEmpty {
            Task { @MainActor [weak self] in
                for f in pending {
                    if let p = await FilmSearch.downloadPoster(f.posterURL + "&api_key=" + token), let self, var now = self.s.films.first(where: { $0.id == f.id }) {
                        now.poster = p; self.save(now)
                    }
                }
            }
        }
        if st.askRating { for f in finished { askRating(f) } }
        return changes
    }

    /// «¿Qué te ha parecido…?»: aviso y, si estás dentro de la app, la hoja para puntuar
    @MainActor
    func askRating(_ f: Film) {
        let n = UNMutableNotificationContent()
        n.title = "¿Qué te ha parecido «\(f.title)»?"
        n.body = f.kind == .serie ? "Has terminado la serie. Ponle nota y cuéntame qué tal." : "Ponle nota y cuéntame qué tal."
        n.sound = .default
        n.userInfo = ["film": f.id]
        if UIApplication.shared.applicationState == .active {
            if Router.shared.rateFilm == nil { Router.shared.rateFilm = f.id }
            return
        }
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "rate-" + f.id, content: n, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)))
    }
}
