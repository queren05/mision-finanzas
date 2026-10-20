import Foundation
import Security

/// Clave de la API de Claude guardada en el Llavero del iPhone (nunca en el JSON de datos)
enum Keychain {
    private static let service = "es.david.rumbo"
    private static let account = "anthropic-api-key"

    static var apiKey: String {
        get {
            var q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                    kSecAttrAccount as String: account, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
            var out: AnyObject?
            guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return "" }
            q.removeAll()
            return String(data: d, encoding: .utf8) ?? ""
        }
        set {
            let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
            SecItemDelete(q as CFDictionary)
            let v = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !v.isEmpty else { return }
            var add = q
            add[kSecValueData as String] = Data(v.utf8)
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(add as CFDictionary, nil)
        }
    }
}

/// Llamadas a Claude (Messages API) con URLSession
enum Claude {
    static let model = "claude-opus-5-5"

    enum Part {
        case text(String)
        case pdf(Data)
        case image(Data, String)   // datos y tipo (image/jpeg, image/png)
    }

    enum Failure: LocalizedError {
        case noKey, badKey, refused, server(String), network
        var errorDescription: String? {
            switch self {
            case .noKey: "Añade tu clave de Claude en Ajustes para usar esto."
            case .badKey: "La clave de Claude no es válida. Revísala en Ajustes."
            case .refused: "Claude no ha querido responder a esto."
            case .server(let m): m
            case .network: "No hay conexión. Inténtalo de nuevo."
            }
        }
    }

    static var hasKey: Bool { !Keychain.apiKey.isEmpty }

    /// pregunta a Claude y devuelve el texto de la respuesta
    static func ask(system: String, parts: [Part], effort: String = "medium", maxTokens: Int = 8000) async throws -> String {
        let key = Keychain.apiKey
        guard !key.isEmpty else { throw Failure.noKey }
        var content: [[String: Any]] = []
        for p in parts {
            switch p {
            case .text(let t): content.append(["type": "text", "text": t])
            case .pdf(let d): content.append(["type": "document", "source": ["type": "base64", "media_type": "application/pdf", "data": d.base64EncodedString()]])
            case .image(let d, let m): content.append(["type": "image", "source": ["type": "base64", "media_type": m, "data": d.base64EncodedString()]])
            }
        }
        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": system,
            "output_config": ["effort": effort],
            "fallbacks": "default",
            "messages": [["role": "user", "content": content]],
        ]
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 180
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let data: Data, resp: URLResponse
        do { (data, resp) = try await URLSession.shared.data(for: req) } catch { throw Failure.network }
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        if code == 401 || code == 403 { throw Failure.badKey }
        guard code == 200 else {
            let msg = ((json["error"] as? [String: Any])?["message"] as? String) ?? "Error \(code) de Claude"
            throw Failure.server(code == 429 ? "Claude está saturado ahora mismo. Prueba en un momento." : msg)
        }
        if json["stop_reason"] as? String == "refusal" { throw Failure.refused }
        let blocks = json["content"] as? [[String: Any]] ?? []
        let text = blocks.filter { $0["type"] as? String == "text" }.compactMap { $0["text"] as? String }.joined()
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// igual, pero la respuesta es un objeto JSON (se le pide a Claude solo JSON y se busca el primer { … })
    static func askJSON(system: String, parts: [Part], effort: String = "medium") async throws -> [String: Any] {
        let text = try await ask(system: system + "\n\nResponde SOLO con un objeto JSON válido, sin texto antes ni después y sin bloques de código.", parts: parts, effort: effort)
        guard let a = text.firstIndex(of: "{"), let b = text.lastIndex(of: "}"),
              let obj = try? JSONSerialization.jsonObject(with: Data(text[a...b].utf8)) as? [String: Any] else {
            throw Failure.server("La respuesta de Claude no se ha podido leer. Prueba otra vez.")
        }
        return obj
    }

    static func strings(_ v: Any?) -> [String] { (v as? [Any])?.compactMap { $0 as? String } ?? [] }
}
