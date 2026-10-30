package es.david.findemes.model

import androidx.compose.ui.graphics.Color
import es.david.findemes.support.Ink

/** Las ramas del árbol: cada mejora va en la rama de lo que hace y se compran en orden, de la más barata a la más cara. */
enum class Branch(val title: String, val color: Color, val icon: String) {
    dano("Daño", Ink.red, "burst.fill"),
    dinero("Dinero", Ink.gold, "eurosign.circle.fill"),
    aguante("Aguante", Ink.blue, "heart.fill"),
    rebano("{Huchas}", Ink.green, "square.grid.3x3.fill"),
    frenesi("Frenesí", Ink.purple, "bolt.fill");

    companion object {
        fun of(e: SkillEffect): Branch = when (e) {
            SkillEffect.damageFlat, SkillEffect.damagePct, SkillEffect.crit, SkillEffect.critDamage, SkillEffect.pierce, SkillEffect.firstHit, SkillEffect.collateral -> dano
            SkillEffect.lootPct, SkillEffect.golden, SkillEffect.goldenValue, SkillEffect.jackpot, SkillEffect.chest, SkillEffect.chestValue -> dinero
            SkillEffect.stamina, SkillEffect.killStamina, SkillEffect.drainSave, SkillEffect.glass, SkillEffect.speedPct, SkillEffect.radiusPct -> aguante
            SkillEffect.startPigs, SkillEffect.spawnPct, SkillEffect.maxPigs, SkillEffect.fat, SkillEffect.pigXPMul, SkillEffect.king -> rebano
            SkillEffect.frenzyEarly, SkillEffect.frenzyTime, SkillEffect.frenzyMoney, SkillEffect.comboCap, SkillEffect.comboTime, SkillEffect.bomb -> frenesi
        }
    }
}

class SkillTree(defs: List<SkillDef>) {
    val root: SkillDef = defs[0]
    val branches: List<List<SkillDef>>
    /** de quién cuelga cada mejora (la anterior de su rama; la primera, del tronco) */
    val parent: Map<String, String>

    init {
        val b = List(Branch.entries.size) { mutableListOf<SkillDef>() }
        for (k in defs) if (k.id != root.id) b[Branch.of(k.effect).ordinal].add(k)
        branches = b.map { list ->
            list.indices.sortedWith { x, y ->
                if (list[x].baseCost != list[y].baseCost) list[x].baseCost.compareTo(list[y].baseCost) else x.compareTo(y)
            }.map { list[it] }
        }
        val p = mutableMapOf<String, String>()
        for (list in branches) for ((i, k) in list.withIndex()) p[k.id] = if (i == 0) root.id else list[i - 1].id
        parent = p
    }

    companion object {
        val main by lazy { SkillTree(Content.skills) }
    }
}
