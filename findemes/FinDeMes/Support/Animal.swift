import SwiftUI

/// Los textos hablan del animal que llevas: «+4 vacas a la vez», «+4 cerdos a la vez».
/// En los textos se escribe {huchas}, {hucha}, {Hucha}, {HUCHAS} y las terminaciones {a}, {as}, {la}, {las}, {una}, {lo}.
enum Animal {
    static var singular = "vaca"
    static var plural = "vacas"
    static var female = true

    static func use(_ s: SkinDef) {
        singular = s.singular; plural = s.plural; female = s.female
    }
}

extension String {
    /// cambia las marcas por el animal de ahora
    var a: String {
        guard contains("{") else { return self }
        let f = Animal.female
        return self
            .replacingOccurrences(of: "{HUCHAS}", with: Animal.plural.uppercased())
            .replacingOccurrences(of: "{HUCHA}", with: Animal.singular.uppercased())
            .replacingOccurrences(of: "{LAS}", with: f ? "LAS" : "LOS")
            .replacingOccurrences(of: "{AS}", with: f ? "AS" : "OS")
            .replacingOccurrences(of: "{A}", with: f ? "A" : "O")
            .replacingOccurrences(of: "{Huchas}", with: Animal.plural.capitalizedFirst)
            .replacingOccurrences(of: "{Hucha}", with: Animal.singular.capitalizedFirst)
            .replacingOccurrences(of: "{huchas}", with: Animal.plural)
            .replacingOccurrences(of: "{hucha}", with: Animal.singular)
            .replacingOccurrences(of: "{as}", with: f ? "as" : "os")
            .replacingOccurrences(of: "{a}", with: f ? "a" : "o")
            .replacingOccurrences(of: "{las}", with: f ? "las" : "los")
            .replacingOccurrences(of: "{Las}", with: f ? "Las" : "Los")
            .replacingOccurrences(of: "{la}", with: f ? "la" : "el")
            .replacingOccurrences(of: "{La}", with: f ? "La" : "El")
            .replacingOccurrences(of: "{una}", with: f ? "una" : "un")
            .replacingOccurrences(of: "{lo}", with: f ? "la" : "lo")
            .replacingOccurrences(of: "{Lo}", with: f ? "La" : "Lo")
    }
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

extension Text {
    /// todo texto que viene de una variable pasa por el animal de ahora
    init(_ s: String) { self.init(verbatim: s.a) }
}
