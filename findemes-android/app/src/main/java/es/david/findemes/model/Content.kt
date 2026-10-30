package es.david.findemes.model

import androidx.compose.ui.graphics.Color
import es.david.findemes.support.Fmt
import es.david.findemes.support.Ink
import es.david.findemes.support.filling
import es.david.findemes.support.hex
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import es.david.findemes.support.rnd

// Todo el contenido son datos: para añadir martillos, huchas, facturas, mejoras, joyas o monedas
// basta con ampliar estas listas.

data class Pt(val x: Double, val y: Double)

// MARK: - Martillos

enum class HammerStyle { chancla, toy, claw, mallet, mace, jack, sledge, thunder, thunderGold, diamond, cosmic, goldFlop, fire, ice, viking, anvil, plunger, swatter, pan, bat, choco, gavel }

class HammerDef(
    val id: Int,
    val name: String,
    val line: String,
    cost: Number,
    damage: Number,
    speed: Number,      // golpes por segundo
    radius: Number,     // alcance en puntos
    val style: HammerStyle,
    val head: String,
    val handle: String,
) {
    val cost = cost.toDouble()
    val damage = damage.toDouble()
    val speed = speed.toDouble()
    val radius = radius.toDouble()
}

// MARK: - Huchas

enum class PigKind(
    val title: String,
    val line: String,
    val hp: Double,
    val value: Double,
    val size: Double,
    val speed: Double,
    /** a partir de qué nivel de las huchas aparece (el nivel sube rompiéndolas) */
    val minTier: Int,
    val weight: Double,
    val color: Color,
    val dark: Color,
    /** qué versión del personaje se usa para cada tipo de hucha */
    val look: String,
) {
    normal("{Hucha}", "{La} de toda la vida.", 1.0, 1.0, 62.0, 14.0, 0, 100.0, Ink.pink, Ink.pinkDark, "normal"),
    gorda("{Hucha} gord{a}", "Aguanta más y suelta más.", 3.0, 3.5, 84.0, 7.0, 2, 20.0, hex("#ee93a8"), Ink.pinkDark, "normal"),
    ruedas("{Hucha} con ruedas", "Corre que se las pela.", 0.8, 2.0, 54.0, 85.0, 4, 12.0, hex("#8fc3ea"), hex("#5e98c6"), "normal"),
    cristal("{Hucha} de cristal", "Frágil. Te devuelve aguante.", 0.3, 0.8, 56.0, 10.0, 6, 10.0, hex("#cdeaf4"), hex("#93c6d8"), "cristal"),
    acorazada("{Hucha} acorazad{a}", "Lleva coraza: cuesta hacerle daño.", 4.0, 5.0, 70.0, 9.0, 9, 10.0, hex("#b9b3ad"), hex("#8a847d"), "hierro"),
    bomba("{Hucha} bomba", "Al romper{lo}, explota y rompe {las} de al lado.", 1.2, 1.5, 60.0, 18.0, 12, 8.0, hex("#4a4552"), hex("#2c2833"), "bomba"),
    dorada("{Hucha} dorad{a}", "Rar{a}. Puede soltar monedas del álbum.", 1.5, 12.0, 64.0, 26.0, 0, 0.0, Ink.gold, hex("#c98d1d"), "oro"),
    rey("Rey {Hucha}", "El jefe. Muchísima vida y un botín enorme.", 40.0, 60.0, 128.0, 12.0, 15, 0.0, hex("#f08aa3"), Ink.pinkDark, "normal"),
    gigante("{Hucha} gigante", "Del tamaño de una lavadora.", 14.0, 22.0, 150.0, 5.0, 19, 3.0, hex("#f2a0b4"), Ink.pinkDark, "normal"),
    fantasma("{Hucha} fantasma", "Desaparece y aparece donde quiere.", 1.5, 6.0, 64.0, 20.0, 23, 7.0, hex("#eef2f6"), hex("#c4ccd6"), "normal"),
    madre("Mamá {hucha}", "Al romper{lo} salen tres {huchas} pequeñ{as}.", 5.0, 6.0, 92.0, 8.0, 27, 5.0, hex("#f7b6c6"), Ink.pinkDark, "normal"),
    diamante("{Hucha} de diamante", "Durísim{a}. Vale una fortuna.", 12.0, 45.0, 70.0, 16.0, 32, 2.0, hex("#9fe8ff"), hex("#4fb8d8"), "cristal"),
    arcoiris("{Hucha} arcoíris", "Casi siempre suelta un sobre.", 3.0, 10.0, 66.0, 30.0, 38, 2.0, hex("#b48ef0"), hex("#f2b632"), "normal"),
    robot("{Hucha} robot", "Blindad{a} y rápid{a}. Odia los martillos.", 9.0, 18.0, 72.0, 45.0, 45, 6.0, hex("#8fa3b8"), hex("#5b6b7c"), "hierro"),
    lava("{Hucha} de lava", "Explota como diez bombas.", 6.0, 14.0, 74.0, 12.0, 52, 4.0, hex("#f0642a"), hex("#a52a12"), "normal"),
    cosmica("{Hucha} cósmic{a}", "Viene del espacio con un tesoro dentro.", 30.0, 150.0, 96.0, 22.0, 60, 1.5, hex("#6a4bc4"), hex("#f2b632"), "normal"),
    hielo("{Hucha} de hielo", "Congelad{a} y durísim{a}. Lenta como un lunes.", 25.0, 40.0, 88.0, 4.0, 68, 5.0, hex("#c9f1ff"), hex("#7cc8e8"), "cristal"),
    suerte("{Hucha} de la suerte", "Al romper{lo}, suelta un sobre raro.", 6.0, 30.0, 64.0, 28.0, 75, 2.0, hex("#5fd36a"), hex("#2f8f3a"), "normal"),
    zombi("{Hucha} zombi", "{Lo} rompes y vuelve a levantarse.", 10.0, 35.0, 70.0, 10.0, 82, 5.0, hex("#93b07a"), hex("#5a6b4a"), "normal"),
    millonaria("{Hucha} millonari{a}", "Rarísim{a}. Vale mil {huchas}.", 60.0, 1000.0, 110.0, 18.0, 100, 0.6, Ink.gold, hex("#c98d1d"), "oro"),
    ninja("{Hucha} ninja", "No {lo} ves venir. Ni irse.", 6.0, 45.0, 58.0, 140.0, 90, 6.0, hex("#3a3540"), hex("#1d1a17"), "normal"),
    payaso("{Hucha} payaso", "Al romper{lo} salen cinco {huchas} pequeñ{as} de colores.", 12.0, 30.0, 80.0, 22.0, 96, 4.0, hex("#ffd23a"), hex("#e8483a"), "normal"),
    pirata("{Hucha} pirata", "Siempre lleva un sobre escondido.", 20.0, 90.0, 76.0, 20.0, 108, 3.0, hex("#c9965e"), hex("#6e4126"), "normal"),
    vampiro("{Hucha} vampiro", "Al romper{lo} te devuelve 3 de aguante.", 18.0, 70.0, 72.0, 34.0, 120, 4.0, hex("#8a1f2a"), hex("#4a0f18"), "normal"),
    titan("{Hucha} titán", "Enorme. Al romper{lo} tiembla toda la mesa.", 120.0, 500.0, 175.0, 4.0, 135, 1.2, hex("#9aa1a9"), hex("#5a5f66"), "hierro"),
    momia("{Hucha} momia", "Lleva tres mil años ahorrando.", 40.0, 120.0, 80.0, 6.0, 150, 4.0, hex("#e7d8b4"), hex("#b9a77e"), "normal"),
    alien("{Hucha} alienígena", "Al romper{lo} se lleva a tres {huchas} en su nave.", 25.0, 160.0, 68.0, 50.0, 165, 3.0, hex("#8fe36a"), hex("#3d8b4f"), "normal"),
    nube("{Hucha} nube", "Al romper{lo} llueven {huchas} dorad{as}.", 15.0, 140.0, 92.0, 60.0, 180, 3.0, hex("#f4f8ff"), hex("#b8c8e0"), "normal"),
    reina("Reina {Hucha}", "La reina de todas. Suelta sobres buenos.", 150.0, 800.0, 140.0, 8.0, 190, 0.8, hex("#f5a7b8"), Ink.pinkDark, "normal"),
    fenix("{Hucha} fénix", "Renace de sus cenizas una vez.", 30.0, 200.0, 76.0, 30.0, 205, 2.0, hex("#f0642a"), hex("#f2b632"), "normal"),
    agujero("{Hucha} agujero negro", "Al romper{lo} se traga todo lo que tiene cerca.", 80.0, 600.0, 100.0, 3.0, 220, 1.0, hex("#2a2440"), hex("#8a5cc2"), "bomba");

    /** las que salen al azar (la dorada y el rey salen aparte) */
    val special: Boolean get() = this == dorada || this == rey
}

/** el nivel de las huchas: sube muy poco a poco con cada hucha rota */
object PigLevel {
    fun needed(level: Int): Double = rnd(90 * 1.12.pow(level))
}

// MARK: - Facturas

class BillDef(val id: Int, val company: String, val concept: String, amount: Number, val days: Int) {
    val amount = amount.toDouble()
}

// MARK: - Árbol de mejoras

enum class SkillEffect {
    damageFlat, damagePct, speedPct, radiusPct, stamina, killStamina, drainSave, startPigs, spawnPct, maxPigs,
    lootPct, golden, crit, critDamage, collateral, chest, jackpot, pierce, firstHit, fat, bomb, king, glass,
    frenzyEarly, frenzyTime, frenzyMoney,
    pigXPMul, goldenValue, chestValue, comboCap, comboTime
}

/** un tramo de una mejora: cuánto da cada nivel y lo que cuesta */
class SkillStep(val per: Double, val levels: Int, val baseCost: Double, val growth: Double) {
    /** en vacas: el juego lo multiplica por lo que vale una vaca ahora (Game.cost) */
    fun cost(k: Int): Double = baseCost.pow(0.6) * 2.5 * (growth + 0.1).pow(k)
}

class RawStep(val per: Double, val levels: Int, val base: Double, val growth: Double)
fun st(per: Number, levels: Int, base: Number, growth: Number) = RawStep(per.toDouble(), levels, base.toDouble(), growth.toDouble())

/** Cada mejora hace una sola cosa. Las que tienen varios tramos dan más por nivel según suben
 *  (+15 %, luego +25 %, +50 %…), y cada tramo dura hasta que el siguiente sale más a cuenta. */
class SkillDef(
    val id: String,
    val name: String,
    val desc: String,          // «%» se cambia por el valor
    val effect: SkillEffect,
    val icon: String,
    val steps: List<SkillStep>,
) {
    companion object {
        /** tramos: (por nivel, niveles, precio base, crecimiento) */
        fun of(id: String, name: String, desc: String, effect: SkillEffect, icon: String, vararg raw: RawStep): SkillDef {
            val list = mutableListOf<SkillStep>()
            for ((i, r) in raw.withIndex()) {
                var n = r.levels
                if (i + 1 < raw.size) {
                    val next = SkillStep(raw[i + 1].per, 0, raw[i + 1].base, raw[i + 1].growth)
                    val step = SkillStep(r.per, 0, r.base, r.growth)
                    var k = 0
                    while (k < n && step.cost(k) < next.cost(0)) k += 1
                    n = max(3, k)
                }
                list.add(SkillStep(r.per, n, r.base, r.growth))
            }
            return SkillDef(id, name, desc, effect, icon, list)
        }
    }

    val maxLevel: Int get() = steps.sumOf { it.levels }
    val baseCost: Double get() = steps[0].baseCost
    val compound: Boolean get() = effect == SkillEffect.pigXPMul

    /** el tramo del nivel l (el que se compra al subir desde l) y el nivel dentro de él */
    private fun step(l: Int): Pair<SkillStep, Int> {
        var k = l
        for (s in steps) { if (k < s.levels) return s to k; k -= s.levels }
        return steps.last() to steps.last().levels
    }
    fun cost(l: Int): Double { val (s, k) = step(l); return s.cost(k) }

    /** lo que da en el nivel l */
    fun value(l: Int): Double {
        var left = l
        var v = if (compound) 1.0 else 0.0
        for (s in steps) {
            val n = min(left, s.levels)
            if (compound) v *= (1 + s.per / 100).pow(n) else v += s.per * n
            left -= n
        }
        return v
    }
    /** lo que da en el nivel l, ya escrito */
    fun text(l: Int): String {
        val v = value(l)
        return desc.filling(if (compound) (if (v < 100) Fmt.dec(v, 2) else Fmt.num(v)) else Fmt.num(v))
    }
    /** lo que da el siguiente nivel */
    fun perText(l: Int): String {
        val per = step(min(l, maxLevel - 1)).first.per
        return desc.filling(if (compound) Fmt.dec(1 + per / 100, 2) else Fmt.num(per))
    }
}

// MARK: - Herencia: los recuerdos del abuelo (puntos de herencia: se quedan tras la bancarrota)

enum class RingEffect { crit, stamina, golden, startCash, extraDays, chest, legacy, bills, lootMul, damageMul, keepTier, startHammer, autoBuy }

class RingDef(
    val id: String,
    val name: String,
    val desc: String,
    val effect: RingEffect,
    per: Number,
    val maxLevel: Int,
    baseCost: Number,
    growth: Number,
    /** imagen del objeto; si no hay, el icono */
    val art: String = "",
    val icon: String = "sparkles",
) {
    val per = per.toDouble()
    val baseCost = baseCost.toDouble()
    val growth = growth.toDouble()
    val image: String get() = if (art.isEmpty()) "j_$id" else art
    /** los que multiplican nivel a nivel (×1,25, ×1,56…) */
    val compound: Boolean get() = effect == RingEffect.lootMul || effect == RingEffect.damageMul
    fun cost(level: Int): Double = rnd(baseCost * growth.pow(level))
    fun value(l: Int): Double = if (compound) (1 + per / 100).pow(l) else per * l
    val perText: String get() = if (compound) desc.filling(Fmt.dec(1 + per / 100, 2)) else desc.filling(Fmt.num(per))
}

// MARK: - Colección de monedas y sobres sorpresa

enum class Rarity(val title: String, val color: Color, /** bonus permanente de dinero por tener la moneda */ val bonus: Double, /** lo que vale una moneda repetida (en huchas ×50) */ val duplicate: Double) {
    comun("Común", hex("#c9b48a"), 0.01, 1.0),
    rara("Rara", Ink.blue, 0.02, 4.0),
    epica("Épica", Ink.purple, 0.05, 15.0),
    legendaria("Legendaria", Ink.gold, 0.12, 60.0);

    val order: Int get() = ordinal
}

class CoinDef(val id: String, val name: String, val line: String, val rarity: Rarity, val metal: String, val mark: String)

// MARK: - Personajes (modelos 3D renderizados a imagen)

class SkinDef(
    val id: String,
    val name: String,
    bills: Number,            // facturas pagadas (en total) para tenerlo
    w: Number, h: Number,     // tamaño de la imagen
    val head: Pt,             // dónde va la corona o la mecha (en píxeles de la imagen)
    val shards: List<String>, // colores de los pedazos al romperse
    val singular: String = "hucha", val plural: String = "huchas", val female: Boolean = true,
) {
    val bills = bills.toDouble()
    val w = w.toDouble()
    val h = h.toDouble()
    val drawn: Boolean get() = id == "dibujo"
}

// MARK: - El contenido

object Content {
    val hammers: List<HammerDef> = listOf(
        HammerDef(id = 0, name = "La chancla", line = "La de tu madre. Nunca falla.", cost = 0, damage = 4, speed = 1.1, radius = 34, style = HammerStyle.chancla, head = "#3f74b0", handle = "#2a2018"),
        HammerDef(id = 1, name = "Martillo de juguete", line = "Pita al golpear.", cost = 420, damage = 7, speed = 1.4, radius = 40, style = HammerStyle.toy, head = "#e8483a", handle = "#f2b632"),
        HammerDef(id = 2, name = "Martillo de carpintero", line = "Clavos aparte.", cost = 3150, damage = 15, speed = 1.5, radius = 44, style = HammerStyle.claw, head = "#7b8086", handle = "#9a6438"),
        HammerDef(id = 3, name = "Mazo de goma", line = "Rebota que da gusto.", cost = 21000, damage = 32, speed = 1.75, radius = 58, style = HammerStyle.mallet, head = "#2f2b2b", handle = "#c9a26b"),
        HammerDef(id = 4, name = "Maza medieval", line = "De un mercadillo.", cost = 157500, damage = 75, speed = 1.6, radius = 64, style = HammerStyle.mace, head = "#8d8f94", handle = "#6e4126"),
        HammerDef(id = 5, name = "Martillo neumático", line = "Los vecinos encantados.", cost = 1.12e+06, damage = 140, speed = 3.4, radius = 46, style = HammerStyle.jack, head = "#f2b632", handle = "#3a3a3a"),
        HammerDef(id = 6, name = "Mazo de demolición", line = "Para tabiques y {huchas}.", cost = 9.1e+06, damage = 450, speed = 1.5, radius = 86, style = HammerStyle.sledge, head = "#5a5f66", handle = "#b47a48"),
        HammerDef(id = 7, name = "Martillo del trueno", line = "Prestado. No preguntes.", cost = 8.4e+07, damage = 1_300, speed = 2.1, radius = 100, style = HammerStyle.thunder, head = "#c9ccd2", handle = "#7a4a2a"),
        HammerDef(id = 8, name = "Martillo del trueno dorado", line = "Ahora sí es suyo.", cost = 1.2e9, damage = 4_500, speed = 2.3, radius = 110, style = HammerStyle.thunderGold, head = "#f2b632", handle = "#7a1f2a"),
        HammerDef(id = 9, name = "Mazo de diamante", line = "Raya hasta el cristal blindado.", cost = 1.5e10, damage = 16_000, speed = 1.9, radius = 130, style = HammerStyle.diamond, head = "#9fe8ff", handle = "#3a3f45"),
        HammerDef(id = 10, name = "Cetro cósmico", line = "Lo encontraste en un meteorito.", cost = 2e11, damage = 60_000, speed = 2.8, radius = 140, style = HammerStyle.cosmic, head = "#8a5cc2", handle = "#2b1f4a"),
        HammerDef(id = 11, name = "La chancla de oro", line = "La de la abuela. Casi la definitiva.", cost = 3e12, damage = 260_000, speed = 3.2, radius = 160, style = HammerStyle.goldFlop, head = "#f2b632", handle = "#c8323c"),
        HammerDef(id = 12, name = "Martillo de fuego", line = "Funde la cerámica al tocarla.", cost = 4e13, damage = 1.1e6, speed = 3.4, radius = 170, style = HammerStyle.fire, head = "#c8323c", handle = "#3a2a20"),
        HammerDef(id = 13, name = "Mazo de hielo eterno", line = "{Las} {huchas} se quedan helad{as}.", cost = 6e14, damage = 4.5e6, speed = 3.6, radius = 185, style = HammerStyle.ice, head = "#9fe8ff", handle = "#e6f6ff"),
        HammerDef(id = 14, name = "Hacha vikinga", line = "No es un martillo. Da igual.", cost = 9e15, damage = 2e7, speed = 4.0, radius = 200, style = HammerStyle.viking, head = "#c9ccd2", handle = "#8a5a36"),
        HammerDef(id = 15, name = "Un yunque con un palo", line = "El final. Literalmente.", cost = 1.5e17, damage = 1e8, speed = 4.5, radius = 230, style = HammerStyle.anvil, head = "#5a5f66", handle = "#b07a4a"),
        HammerDef(id = 16, name = "Desatascador industrial", line = "Del fontanero del quinto.", cost = 2.2e18, damage = 4e8, speed = 4.0, radius = 220, style = HammerStyle.plunger, head = "#c8323c", handle = "#c9965e"),
        HammerDef(id = 17, name = "Matamoscas eléctrico", line = "Chisporrotea. Mucho.", cost = 3.4e19, damage = 1.4e9, speed = 5.5, radius = 190, style = HammerStyle.swatter, head = "#f2b632", handle = "#3a3a3a"),
        HammerDef(id = 18, name = "La sartén de la abuela", line = "Más peligrosa que la chancla.", cost = 5e20, damage = 6e9, speed = 3.8, radius = 240, style = HammerStyle.pan, head = "#2a2a30", handle = "#2a2420"),
        HammerDef(id = 19, name = "Bate de béisbol", line = "¡Home run!", cost = 7.5e21, damage = 2.4e10, speed = 4.2, radius = 250, style = HammerStyle.bat, head = "#d9b27c", handle = "#1d1a17"),
        HammerDef(id = 20, name = "Mazo de chocolate", line = "Se derrite de tanto dinero.", cost = 1.1e23, damage = 9e10, speed = 4.4, radius = 250, style = HammerStyle.choco, head = "#6b3a1f", handle = "#f4efe6"),
        HammerDef(id = 21, name = "El mazo del juez", line = "Culpables. Todas.", cost = 1.7e24, damage = 4e11, speed = 5.0, radius = 270, style = HammerStyle.gavel, head = "#8a5a36", handle = "#7a4a2a"),
    )

    val bills: List<BillDef> = listOf(
        BillDef(id = 0, company = "NETFLIZ S.L.", concept = "Suscripción mensual", amount = 60, days = 3),
        BillDef(id = 1, company = "MOVISTAAR", concept = "Tarifa del móvil", amount = 125, days = 3),
        BillDef(id = 2, company = "FIBRA YA", concept = "Internet de casa", amount = 260, days = 3),
        BillDef(id = 3, company = "CANAL DE AGUAS", concept = "Consumo bimestral", amount = 550, days = 3),
        BillDef(id = 4, company = "VETERINARIO EL GATO FELIZ", concept = "Vacunas del gato", amount = 1_150, days = 3),
        BillDef(id = 5, company = "IBERDROGA", concept = "Luz (otra vez más cara)", amount = 2_450, days = 3),
        BillDef(id = 6, company = "GYM FIT 24H", concept = "Gimnasio al que no vas", amount = 5_100, days = 3),
        BillDef(id = 7, company = "DGT", concept = "Multa por exceso de velocidad", amount = 10_800, days = 3),
        BillDef(id = 8, company = "COMUNIDAD DE VECINOS", concept = "Derrama del ascensor", amount = 22_700, days = 3),
        BillDef(id = 9, company = "CLÍNICA SONRISAS", concept = "Empaste y limpieza", amount = 47_700, days = 4),
        BillDef(id = 10, company = "SEGUROS MAPHRE", concept = "Seguro del coche", amount = 100_000, days = 4),
        BillDef(id = 11, company = "ITV EXPRESS", concept = "Inspección + multa", amount = 210_000, days = 4),
        BillDef(id = 12, company = "BODA DE TU PRIMO", concept = "Regalo, traje y viaje", amount = 440_000, days = 4),
        BillDef(id = 13, company = "INMOBILIARIA LOS TIBURONES", concept = "Alquiler del piso", amount = 925_000, days = 4),
        BillDef(id = 14, company = "REFORMAS PACO", concept = "El baño nuevo", amount = 1_950_000, days = 4),
        BillDef(id = 15, company = "UNIVERSIDAD PRIVADA", concept = "Matrícula del máster", amount = 4_100_000, days = 5),
        BillDef(id = 16, company = "CONCESIONARIO AUTOCAR", concept = "Coche nuevo (el viejo murió)", amount = 8_600_000, days = 5),
        BillDef(id = 17, company = "AGENCIA TRIBUTARIA", concept = "Declaración de la renta", amount = 18_000_000, days = 5),
    )

    val skills: List<SkillDef> = listOf(
        SkillDef.of("golpe", "Primer golpe", "+% de daño", SkillEffect.damageFlat, "hammer.fill", st(2, 5, 10, 1.7)),
        // daño
        SkillDef.of("muneca", "Muñeca fuerte", "+%\u2009% de daño", SkillEffect.damagePct, "hand.raised.fill",
                 st(15, 30, 40, 1.55), st(25, 30, 3_000, 1.6), st(50, 40, 4e5, 1.7), st(100, 50, 4e7, 1.5), st(200, 60, 1e10, 1.45), st(600, 50, 1e14, 1.5)),
        SkillDef.of("certero", "Golpe certero", "+%\u2009% de crítico", SkillEffect.crit, "scope", st(4, 5, 150, 1.8), st(5, 5, 3e6, 2)),
        SkillDef.of("rompe", "Rompe{huchas}", "Críticos +%\u2009%", SkillEffect.critDamage, "burst.fill", st(50, 5, 600, 1.9), st(100, 30, 5e10, 1.55)),
        SkillDef.of("onda", "Onda expansiva", "Las de al lado reciben un %\u2009%", SkillEffect.collateral, "dot.radiowaves.left.and.right", st(10, 5, 3_500, 1.9), st(10, 10, 2e11, 1.9)),
        SkillDef.of("primero", "Primer impacto", "+%\u2009% al primer golpe", SkillEffect.firstHit, "1.circle.fill", st(100, 5, 15_000, 1.9)),
        SkillDef.of("abrelatas", "Abrelatas", "Atraviesa el +%\u2009% de la coraza", SkillEffect.pierce, "shield.slash.fill", st(15, 4, 60_000, 2.2)),
        // dinero
        SkillDef.of("sofa", "Rebuscar en el sofá", "+%\u2009% de dinero", SkillEffect.lootPct, "sofa.fill",
                 st(20, 30, 80, 1.55), st(40, 40, 5e4, 1.65), st(100, 50, 6e7, 1.5), st(200, 60, 1.5e10, 1.45), st(600, 50, 1e14, 1.5)),
        SkillDef.of("ojo", "Ojo para el oro", "+%\u2009% de {huchas} dorad{as}", SkillEffect.golden, "eye.fill", st(1, 5, 2_000, 2), st(0.5, 10, 1e11, 1.8)),
        SkillDef.of("sobres", "Sobres sorpresa", "+%\u2009% de sobres", SkillEffect.chest, "envelope.fill", st(1, 5, 40_000, 2)),
        SkillDef.of("bote", "El bote", "%\u2009% de que {una} {hucha} dé ×20", SkillEffect.jackpot, "dollarsign.circle.fill", st(0.5, 4, 2e6, 2.2)),
        SkillDef.of("cartero", "El cartero", "Los sobres dan +%\u2009% de dinero", SkillEffect.chestValue, "envelope.open.fill", st(50, 20, 2e10, 1.6)),
        SkillDef.of("orfebre", "Orfebre", "Las doradas valen +%\u2009%", SkillEffect.goldenValue, "seal.fill", st(50, 20, 4e10, 1.6)),
        // aguante y cuerpo
        SkillDef.of("desayuno", "Desayuno fuerte", "+% de aguante", SkillEffect.stamina, "cup.and.saucer.fill",
                 st(5, 20, 25, 1.5), st(8, 20, 300, 1.55), st(9, 25, 7e5, 1.7), st(15, 20, 3e7, 1.6), st(20, 25, 5e10, 1.6)),
        SkillDef.of("brazo", "Brazo largo", "+%\u2009% de alcance", SkillEffect.radiusPct, "arrow.up.left.and.arrow.down.right", st(10, 6, 120, 1.75)),
        SkillDef.of("reflejos", "Reflejos", "+%\u2009% de velocidad", SkillEffect.speedPct, "bolt.fill", st(8, 25, 500, 1.6), st(15, 5, 2.5e6, 2)),
        SkillDef.of("segundo", "Segundo aire", "%\u2009% de recuperar 1 al romper", SkillEffect.killStamina, "wind", st(6, 5, 1_200, 1.8)),
        SkillDef.of("respira", "Respirar hondo", "%\u2009% de golpes gratis", SkillEffect.drainSave, "lungs.fill", st(4, 5, 5_000, 1.9), st(3, 5, 1e13, 2)),
        SkillDef.of("cristalero", "Cristalero", "Las de cristal dan +% de aguante", SkillEffect.glass, "drop.fill", st(1, 3, 80_000, 2.5)),
        // huchas
        SkillDef.of("mas", "Más {huchas}", "+% {huchas} al empezar", SkillEffect.startPigs, "plus.circle.fill", st(3, 15, 30, 1.8), st(5, 15, 2e8, 1.6)),
        SkillDef.of("repartidor", "El repartidor", "Salen un %\u2009% más rápido", SkillEffect.spawnPct, "shippingbox.fill",
                 st(12, 25, 250, 1.6), st(15, 35, 25_000, 1.65), st(25, 30, 6e8, 1.55), st(40, 30, 2e10, 1.5)),
        SkillDef.of("mesa", "Mesa más grande", "+% {huchas} a la vez", SkillEffect.maxPigs, "rectangle.expand.vertical",
                 st(4, 20, 1_000, 1.9), st(4, 25, 5e7, 1.55), st(15, 30, 5e9, 1.5), st(25, 20, 1e13, 1.6)),
        SkillDef.of("gordas", "{Huchas} gord{as}", "+%\u2009% de {huchas} gord{as}", SkillEffect.fat, "circle.fill", st(5, 4, 4_000, 2)),
        SkillDef.of("corte", "La corte del rey", "+%\u2009% de que venga el Rey", SkillEffect.king, "crown.fill", st(10, 5, 1e6, 2)),
        SkillDef.of("granja", "Granja de {huchas}", "{Las} {huchas} suben de nivel ×%", SkillEffect.pigXPMul, "leaf.fill", st(8, 30, 1e11, 1.7)),
        // frenesí
        SkillDef.of("bombas", "Pólvora", "Explosiones +%\u2009%", SkillEffect.bomb, "flame.circle.fill", st(50, 4, 90_000, 2.2), st(100, 10, 2e11, 1.9)),
        SkillDef.of("horapunta", "Hora punta", "Frenesí con % {huchas} menos de combo", SkillEffect.frenzyEarly, "timer", st(2, 8, 8e7, 1.8)),
        SkillDef.of("fiesta", "Fiesta", "El frenesí dura +% s", SkillEffect.frenzyTime, "party.popper.fill", st(1, 12, 3e8, 1.75), st(1, 15, 5e12, 1.7)),
        SkillDef.of("locura", "Locura", "En frenesí, +%\u2009% de dinero", SkillEffect.frenzyMoney, "sparkles", st(50, 25, 1e9, 1.6)),
        SkillDef.of("comboloco", "Combo loco", "El combo llega +% más alto", SkillEffect.comboCap, "flame", st(10, 10, 3e10, 2)),
        SkillDef.of("pegamento", "Combo pegajoso", "El combo aguanta +% s", SkillEffect.comboTime, "hourglass", st(0.15, 8, 6e10, 2)),
    )

    val rings: List<RingDef> = listOf(
        RingDef(id = "cartera", name = "La cartera del abuelo", desc = "×% de dinero", effect = RingEffect.lootMul, per = 25, maxLevel = 60, baseCost = 5, growth = 1.3, art = "billete"),
        RingDef(id = "chancla", name = "La chancla de la abuela", desc = "×% de daño", effect = RingEffect.damageMul, per = 25, maxLevel = 60, baseCost = 5, growth = 1.3, art = "m_chancla"),
        RingDef(id = "cuero", name = "Pulsera de cuero", desc = "+% de aguante", effect = RingEffect.stamina, per = 5, maxLevel = 50, baseCost = 8, growth = 1.45),
        RingDef(id = "rubi", name = "Anillo de rubí", desc = "+%\u2009% de crítico", effect = RingEffect.crit, per = 3, maxLevel = 20, baseCost = 15, growth = 1.7),
        RingDef(id = "trebol", name = "Pulsera del trébol", desc = "+%\u2009% de {huchas} dorad{as}", effect = RingEffect.golden, per = 1, maxLevel = 20, baseCost = 20, growth = 1.8),
        RingDef(id = "sello", name = "Anillo de sello", desc = "Empiezas con más dinero", effect = RingEffect.startCash, per = 1, maxLevel = 20, baseCost = 25, growth = 2),
        RingDef(id = "foto", name = "La foto de la bisabuela", desc = "Empiezas con {las} {huchas} al %\u2009% de tu récord", effect = RingEffect.keepTier, per = 5, maxLevel = 10, baseCost = 30, growth = 1.9, icon = "photo.fill"),
        RingDef(id = "gemelos", name = "Pulsera de la suerte", desc = "+%\u2009% de sobres y mejores", effect = RingEffect.chest, per = 1, maxLevel = 5, baseCost = 40, growth = 2),
        RingDef(id = "martillo", name = "El martillo del bisabuelo", desc = "Empiezas con los % primeros martillos", effect = RingEffect.startHammer, per = 1, maxLevel = 12, baseCost = 40, growth = 1.8, icon = "hammer.fill"),
        RingDef(id = "alianza", name = "Alianza", desc = "+%\u2009% de puntos de herencia", effect = RingEffect.legacy, per = 10, maxLevel = 25, baseCost = 50, growth = 2),
        RingDef(id = "reloj", name = "Reloj de bolsillo", desc = "+% días para cada factura", effect = RingEffect.extraDays, per = 1, maxLevel = 3, baseCost = 60, growth = 4),
        RingDef(id = "libreta", name = "La libreta del cuñado", desc = "Al acabar el día compra solo lo más barato", effect = RingEffect.autoBuy, per = 1, maxLevel = 1, baseCost = 150, growth = 1, icon = "list.clipboard.fill"),
        RingDef(id = "rey", name = "Anillo del rey", desc = "Facturas un %\u2009% más baratas", effect = RingEffect.bills, per = 5, maxLevel = 6, baseCost = 200, growth = 2.5),
    )

    val coins: List<CoinDef> = listOf(
        CoinDef(id = "peseta", name = "Peseta", line = "España, 1980", rarity = Rarity.comun, metal = "#c9a24a", mark = "1"),
        CoinDef(id = "duro", name = "Duro", line = "Cinco pesetas", rarity = Rarity.comun, metal = "#c9a24a", mark = "5"),
        CoinDef(id = "perrachica", name = "Perra chica", line = "Cinco céntimos", rarity = Rarity.comun, metal = "#a5703a", mark = "5c"),
        CoinDef(id = "perragorda", name = "Perra gorda", line = "Diez céntimos", rarity = Rarity.comun, metal = "#a5703a", mark = "10c"),
        CoinDef(id = "centimo", name = "Céntimo", line = "El que nadie quiere", rarity = Rarity.comun, metal = "#b0673a", mark = "1c"),
        CoinDef(id = "doseuros", name = "2 euros", line = "Bimetálica", rarity = Rarity.comun, metal = "#c2c4c8", mark = "2€"),
        CoinDef(id = "penique", name = "Penique", line = "Reino Unido", rarity = Rarity.comun, metal = "#a5703a", mark = "p"),
        CoinDef(id = "dime", name = "Dime", line = "Estados Unidos", rarity = Rarity.comun, metal = "#c2c4c8", mark = "10"),
        CoinDef(id = "yen", name = "Yen", line = "Japón, con agujero", rarity = Rarity.comun, metal = "#d8dadd", mark = "¥"),
        CoinDef(id = "ochavo", name = "Ochavo", line = "Siglo XVIII", rarity = Rarity.comun, metal = "#8a5a36", mark = "8"),
        CoinDef(id = "reala8", name = "Real de a ocho", line = "El dólar de su época", rarity = Rarity.rara, metal = "#c2c4c8", mark = "8R"),
        CoinDef(id = "escudo", name = "Escudo", line = "Portugal", rarity = Rarity.rara, metal = "#c9a24a", mark = "E"),
        CoinDef(id = "florin", name = "Florín", line = "Florencia", rarity = Rarity.rara, metal = "#e0b84a", mark = "F"),
        CoinDef(id = "dracma", name = "Dracma", line = "Atenas, con lechuza", rarity = Rarity.rara, metal = "#c2c4c8", mark = "Δ"),
        CoinDef(id = "lira", name = "Lira", line = "Italia, 1970", rarity = Rarity.rara, metal = "#c2c4c8", mark = "L"),
        CoinDef(id = "rublo", name = "Rublo", line = "Rusia zarista", rarity = Rarity.rara, metal = "#c2c4c8", mark = "₽"),
        CoinDef(id = "doblon", name = "Doblón", line = "Oro de las Indias", rarity = Rarity.epica, metal = "#f2b632", mark = "D"),
        CoinDef(id = "sestercio", name = "Sestercio", line = "Roma imperial", rarity = Rarity.epica, metal = "#b0873a", mark = "S"),
        CoinDef(id = "ducado", name = "Ducado", line = "Venecia", rarity = Rarity.epica, metal = "#f2b632", mark = "Du"),
        CoinDef(id = "maravedi", name = "Maravedí de oro", line = "Castilla", rarity = Rarity.epica, metal = "#f2b632", mark = "M"),
        CoinDef(id = "reycerdito", name = "Moneda del Rey", line = "Acuñada en su honor", rarity = Rarity.legendaria, metal = "#f5a7b8", mark = "♛"),
        CoinDef(id = "galeon", name = "Doblón del galeón", line = "Del fondo del mar", rarity = Rarity.legendaria, metal = "#f2b632", mark = "⚓"),
        CoinDef(id = "chocolate", name = "Moneda de chocolate", line = "Sigue envuelta", rarity = Rarity.legendaria, metal = "#7a4a2a", mark = "C"),
        CoinDef(id = "primera", name = "La primera peseta", line = "1868. Única.", rarity = Rarity.legendaria, metal = "#e0b84a", mark = "I"),
        CoinDef(id = "kopek", name = "Kópek", line = "Rusia, céntimo de rublo", rarity = Rarity.comun, metal = "#a5703a", mark = "k"),
        CoinDef(id = "won", name = "Won", line = "Corea, con agujero", rarity = Rarity.comun, metal = "#c2c4c8", mark = "₩"),
        CoinDef(id = "peso", name = "Peso", line = "México", rarity = Rarity.comun, metal = "#c9a24a", mark = "$"),
        CoinDef(id = "thaler", name = "Tálero", line = "Bohemia, 1520", rarity = Rarity.rara, metal = "#d0d2d6", mark = "T"),
        CoinDef(id = "denario", name = "Denario", line = "Roma, plata", rarity = Rarity.rara, metal = "#b9bcc2", mark = "X"),
        CoinDef(id = "cruzado", name = "Cruzado", line = "Portugal, oro", rarity = Rarity.rara, metal = "#e0b84a", mark = "✚"),
        CoinDef(id = "aureo", name = "Áureo", line = "Roma, oro puro", rarity = Rarity.epica, metal = "#f2b632", mark = "A"),
        CoinDef(id = "solidus", name = "Sólido", line = "Bizancio", rarity = Rarity.epica, metal = "#e8c040", mark = "S"),
        CoinDef(id = "ryo", name = "Ryō", line = "Japón, de los samuráis", rarity = Rarity.epica, metal = "#f2c94a", mark = "両"),
        CoinDef(id = "lunar", name = "Moneda lunar", line = "Cayó de la Luna", rarity = Rarity.legendaria, metal = "#e6e8ec", mark = "☾"),
        CoinDef(id = "maldito", name = "Doblón maldito", line = "Del capitán Cerdobarba", rarity = Rarity.legendaria, metal = "#4a4552", mark = "☠"),
        CoinDef(id = "huchaoro", name = "La {hucha} de oro", line = "La madre de todas", rarity = Rarity.legendaria, metal = "#f2b632", mark = "♥"),
    )

    val skins: List<SkinDef> = listOf(
        SkinDef(id = "vaca", name = "Vaca", bills = 0, w = 300, h = 226, head = Pt(178.0, 46.0), shards = listOf("#ffffff", "#3a3a3a"), singular = "vaca", plural = "vacas", female = true),
        SkinDef(id = "cerdo", name = "Cerdito", bills = 0, w = 296, h = 211, head = Pt(176.0, 39.0), shards = listOf("#f4b8c4", "#e48aa0"), singular = "cerdo", plural = "cerdos", female = false),
        SkinDef(id = "carlino", name = "Carlino", bills = 5, w = 274, h = 251, head = Pt(232.0, 35.0), shards = listOf("#f3e6c4", "#6b4a3a"), singular = "carlino", plural = "carlinos", female = false),
        SkinDef(id = "llama", name = "Llama", bills = 15, w = 264, h = 307, head = Pt(208.0, 12.0), shards = listOf("#a77b5a", "#ffffff"), singular = "llama", plural = "llamas", female = true),
        SkinDef(id = "caballo", name = "Caballo", bills = 30, w = 294, h = 235, head = Pt(258.0, 12.0), shards = listOf("#a0673e", "#3a2a20"), singular = "caballo", plural = "caballos", female = false),
        SkinDef(id = "cebra", name = "Cebra", bills = 60, w = 292, h = 238, head = Pt(260.0, 10.0), shards = listOf("#ffffff", "#1d1a17"), singular = "cebra", plural = "cebras", female = true),
    )
    fun skin(id: String): SkinDef = skins.firstOrNull { it.id == id } ?: skins[0]
    fun playing(id: String): SkinDef = skin(id)

    /** lo que cuesta la factura número n (contando todos los años), en vacas del nivel de cuando llega:
     *  suben poco al principio y luego cada una vale el triple que la anterior */
    fun billUnits(n: Int): Double = 40 * 1.4.pow(min(n, 10)) * 1.6.pow(max(0, n - 10))
    /** los martillos también se pagan en vacas */
    fun hammerUnits(id: Int): Double = if (id == 0) 0.0 else 1_000 * 4.0.pow(id - 1)

    fun pigHP(tier: Int): Double = 8 * 1.3.pow(tier)
    fun pigValue(tier: Int): Double = 0.9 * 1.12.pow(tier)

    /** las tres mejoras del martillo (valen para cualquiera y se pierden con la bancarrota) */
    val parts: List<PartDef> = listOf(
        PartDef("contrapeso", "Contrapeso de plomo", "+% % de daño", PartEffect.damage, 10.0, 100, 30.0, 1.42),
        PartDef("iman", "Imán de nevera", "+% % de dinero", PartEffect.loot, 10.0, 100, 40.0, 1.42),
        PartDef("mango", "Mango de goma", "+% % de velocidad", PartEffect.speed, 5.0, 40, 35.0, 1.3),
    )
}
