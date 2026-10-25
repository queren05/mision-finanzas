import Foundation

/// la habilidad especial de cada martillo
extension HammerStyle {
    var perkName: String {
        switch self {
        case .chancla: "Puntería de madre"
        case .toy: "Ligero"
        case .claw: "Uña"
        case .mallet: "Rebote"
        case .mace: "Pinchos"
        case .jack: "Neumático"
        case .sledge: "Demolición"
        case .thunder: "Rayo"
        case .thunderGold: "Rayo de oro"
        case .diamond: "Filo de diamante"
        case .cosmic: "Gravedad cero"
        case .goldFlop: "La de la abuela"
        case .fire: "Quemadura"
        case .ice: "Congelación"
        case .viking: "Furia vikinga"
        case .anvil: "Temblor"
        case .plunger: "Ventosa"
        case .swatter: "Descarga"
        case .pan: "Sartenazo"
        case .bat: "Home run"
        case .choco: "Bombón"
        case .gavel: "Sentencia"
        }
    }
    var perk: String {
        switch self {
        case .chancla: "+10 % de crítico"
        case .toy: "+25 % de velocidad"
        case .claw: "Atraviesa el 40 % de las corazas"
        case .mallet: "25 % de dar dos golpes de una vez"
        case .mace: "Críticos +100 %"
        case .jack: "25 % de golpes que no gastan aguante"
        case .sledge: "Golpea también un poco a las de alrededor"
        case .thunder: "30 % de que caiga un rayo sobre 3 huchas"
        case .thunderGold: "Rayos y +100 % de dinero"
        case .diamond: "+15 % de crítico y críticos +200 %"
        case .cosmic: "El frenesí sale con 10 de combo menos"
        case .goldFlop: "+50 % de dinero y el doble de sobres"
        case .fire: "Las huchas golpeadas arden y pierden vida"
        case .ice: "Las huchas golpeadas se congelan y reciben +30 % de daño"
        case .viking: "+25 % de crítico y críticos +150 %"
        case .anvil: "Cada golpe hace temblar toda la mesa"
        case .plunger: "+25 huchas a la vez y +10 al empezar"
        case .swatter: "Rayos y +40 % de velocidad"
        case .pan: "+30 % de crítico y el triple de sobres"
        case .bat: "+40 % de alcance y golpea fuerte a las de alrededor"
        case .choco: "×3 de dinero"
        case .gavel: "8 % de romper una hucha de un golpe"
        }
    }
    var lightning: Bool { self == .thunder || self == .thunderGold || self == .swatter }
}
