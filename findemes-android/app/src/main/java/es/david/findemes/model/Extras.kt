package es.david.findemes.model

import kotlin.random.Random

// MARK: - Mejoras del martillo (valen para cualquiera y se pierden con la bancarrota)

enum class PartEffect { damage, loot, speed }

class PartDef(
    val id: String,
    val name: String,
    val desc: String,          // «%» se cambia por el valor por nivel
    val effect: PartEffect,
    val per: Double,
    val maxLevel: Int,
    val base: Double,          // en huchas del nivel de ahora
    val growth: Double,
) {
    fun value(l: Int): Double = per * l
}

// MARK: - La feria: la tragaperras (tiradas gratis, sin apostar) y el rasca

enum class SlotSymbol(val weight: Double, /** cuánto paga sacar tres iguales (en premios pequeños: 5 {huchas} cada uno) */ val pays: Double, val image: String) {
    cerdo(32.0, 3.0, ""), moneda(26.0, 6.0, "c_loot"), billete(20.0, 12.0, "billete"), chancla(12.0, 30.0, "m_chancla"), anillo(7.0, 100.0, "j_oro"), corona(3.0, 400.0, "j_rey");

    companion object {
        fun random(): SlotSymbol {
            var r = Random.nextDouble() * entries.sumOf { it.weight }
            for (s in entries) { if (r < s.weight) return s; r -= s.weight }
            return cerdo
        }
    }
}

enum class ScratchPrize(val title: String, /** probabilidad de que el rasca toque esto (lo que falta hasta 1 es no tocar nada) */ val chance: Double) {
    calderilla("Calderilla", 0.3),
    fajo("Un fajo de billetes", 0.18),
    sobreRaro("Sobre raro", 0.12),
    sobreEpico("Sobre épico", 0.06),
    herencia("Un maletín de billetes", 0.04),
    sobreLegendario("¡Sobre legendario!", 0.015),
}

// la habilidad especial de cada martillo
val HammerStyle.perkName: String
    get() = when (this) {
        HammerStyle.chancla -> "Puntería de madre"
        HammerStyle.toy -> "Ligero"
        HammerStyle.claw -> "Uña"
        HammerStyle.mallet -> "Rebote"
        HammerStyle.mace -> "Pinchos"
        HammerStyle.jack -> "Neumático"
        HammerStyle.sledge -> "Demolición"
        HammerStyle.thunder -> "Rayo"
        HammerStyle.thunderGold -> "Rayo de oro"
        HammerStyle.diamond -> "Filo de diamante"
        HammerStyle.cosmic -> "Gravedad cero"
        HammerStyle.goldFlop -> "La de la abuela"
        HammerStyle.fire -> "Quemadura"
        HammerStyle.ice -> "Congelación"
        HammerStyle.viking -> "Furia vikinga"
        HammerStyle.anvil -> "Temblor"
        HammerStyle.plunger -> "Ventosa"
        HammerStyle.swatter -> "Descarga"
        HammerStyle.pan -> "Sartenazo"
        HammerStyle.bat -> "Home run"
        HammerStyle.choco -> "Bombón"
        HammerStyle.gavel -> "Sentencia"
    }

val HammerStyle.perk: String
    get() = when (this) {
        HammerStyle.chancla -> "+10 % de crítico"
        HammerStyle.toy -> "+25 % de velocidad"
        HammerStyle.claw -> "Atraviesa el 40 % de las corazas"
        HammerStyle.mallet -> "25 % de dar dos golpes de una vez"
        HammerStyle.mace -> "Críticos +100 %"
        HammerStyle.jack -> "25 % de golpes que no gastan aguante"
        HammerStyle.sledge -> "Golpea también un poco a las de alrededor"
        HammerStyle.thunder -> "30 % de que caiga un rayo sobre 3 {huchas}"
        HammerStyle.thunderGold -> "Rayos y +100 % de dinero"
        HammerStyle.diamond -> "+15 % de crítico y críticos +200 %"
        HammerStyle.cosmic -> "El frenesí sale con 10 de combo menos"
        HammerStyle.goldFlop -> "+50 % de dinero y el doble de sobres"
        HammerStyle.fire -> "{Las} {huchas} golpead{as} arden y pierden vida"
        HammerStyle.ice -> "{Las} {huchas} golpead{as} se congelan y reciben +30 % de daño"
        HammerStyle.viking -> "+25 % de crítico y críticos +150 %"
        HammerStyle.anvil -> "Cada golpe hace temblar toda la mesa"
        HammerStyle.plunger -> "+25 {huchas} a la vez y +10 al empezar"
        HammerStyle.swatter -> "Rayos y +40 % de velocidad"
        HammerStyle.pan -> "+30 % de crítico y el triple de sobres"
        HammerStyle.bat -> "+40 % de alcance y golpea fuerte a las de alrededor"
        HammerStyle.choco -> "×3 de dinero"
        HammerStyle.gavel -> "8 % de romper {una} {hucha} de un golpe"
    }

val HammerStyle.lightning: Boolean get() = this == HammerStyle.thunder || this == HammerStyle.thunderGold || this == HammerStyle.swatter
