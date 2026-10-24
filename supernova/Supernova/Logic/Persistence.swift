import Foundation

/// Guarda la partida en un archivo JSON (escritura atómica) y conserva una copia de la anterior:
/// si el archivo principal se estropea, se carga la copia.
enum Persistence {
    private static var dir: URL {
        let u = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }
    private static var main: URL { dir.appendingPathComponent("partida.json") }
    private static var backup: URL { dir.appendingPathComponent("partida-copia.json") }

    static func load() -> GameState? {
        for url in [main, backup] {
            if let d = try? Data(contentsOf: url), let s = try? JSONDecoder().decode(GameState.self, from: d) { return s }
        }
        return nil
    }

    static func save(_ s: GameState) {
        guard let d = try? JSONEncoder().encode(s) else { return }
        let fm = FileManager.default
        if fm.fileExists(atPath: main.path) {
            try? fm.removeItem(at: backup)
            try? fm.copyItem(at: main, to: backup)
        }
        try? d.write(to: main, options: .atomic)
    }

    static func erase() {
        try? FileManager.default.removeItem(at: main)
        try? FileManager.default.removeItem(at: backup)
    }
}
