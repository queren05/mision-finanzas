import Foundation
import Security

/// Clave de la API de Claude guardada en el Llavero (nunca en los datos de la app).
enum Keychain {
    private static let service = "com.david.salud"

    static var apiKey: String {
        get { read("anthropic-api-key") }
        set { write("anthropic-api-key", newValue) }
    }

    private static func read(_ account: String) -> String {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                kSecAttrAccount as String: account, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return "" }
        return String(data: d, encoding: .utf8) ?? ""
    }

    private static func write(_ account: String, _ value: String) {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
        SecItemDelete(q as CFDictionary)
        let v = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !v.isEmpty else { return }
        var add = q
        add[kSecValueData as String] = Data(v.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }
}

/// Llamadas a Claude (Messages API).
enum Claude {
    static let model = "claude-opus-5-5"

    struct Turn: Codable, Hashable, Identifiable {
        var id = UUID()
        var fromMe: Bool
        var text: String
    }

    enum Failure: LocalizedError {
        case noKey, badKey, refused, server(String), network
        var errorDescription: String? {
            switch self {
            case .noKey: "Pon tu clave de Claude en Ajustes."
            case .badKey: "La clave de Claude no vale. Revísala en Ajustes."
            case .refused: "Claude no ha querido responder a esto."
            case .server(let m): m
            case .network: "No hay conexión. Prueba otra vez."
            }
        }
    }

    static var hasKey: Bool { !Keychain.apiKey.isEmpty }

    /// Conversación: los turnos anteriores y, opcionalmente, una foto en el último.
    static func ask(system: String, turns: [Turn], image: Data? = nil, effort: String = "medium", maxTokens: Int = 4000) async throws -> String {
        let key = Keychain.apiKey
        guard !key.isEmpty else { throw Failure.noKey }
        var messages: [[String: Any]] = turns.map { ["role": $0.fromMe ? "user" : "assistant", "content": $0.text] }
        if let image, var last = messages.last, last["role"] as? String == "user" {
            last["content"] = [
                ["type": "image", "source": ["type": "base64", "media_type": "image/jpeg", "data": image.base64EncodedString()]],
                ["type": "text", "text": last["content"] as? String ?? ""],
            ]
            messages[messages.count - 1] = last
        }
        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": system,
            "output_config": ["effort": effort],
            "fallbacks": "default",
            "messages": messages,
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
            throw Failure.server(code == 429 || code == 529 ? "Claude está saturado. Prueba en un momento." : msg)
        }
        if json["stop_reason"] as? String == "refusal" { throw Failure.refused }
        let blocks = json["content"] as? [[String: Any]] ?? []
        return blocks.filter { $0["type"] as? String == "text" }.compactMap { $0["text"] as? String }.joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// La respuesta como objeto JSON.
    static func askJSON(system: String, prompt: String, image: Data? = nil) async throws -> [String: Any] {
        let text = try await ask(system: system + "\n\nResponde SOLO con un objeto JSON válido, sin texto antes ni después y sin bloques de código.",
                                 turns: [Turn(fromMe: true, text: prompt)], image: image, effort: "low")
        guard let a = text.firstIndex(of: "{"), let b = text.lastIndex(of: "}"),
              let obj = try? JSONSerialization.jsonObject(with: Data(text[a...b].utf8)) as? [String: Any] else {
            throw Failure.server("No se ha podido leer la respuesta. Prueba otra vez.")
        }
        return obj
    }
}
