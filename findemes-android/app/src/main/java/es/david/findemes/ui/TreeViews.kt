package es.david.findemes.ui

import es.david.findemes.support.tf
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import es.david.findemes.logic.Game
import es.david.findemes.logic.Sound
import es.david.findemes.logic.bestSkill
import es.david.findemes.model.Branch
import es.david.findemes.model.Content
import es.david.findemes.model.SkillDef
import es.david.findemes.model.SkillTree
import es.david.findemes.support.Fmt
import es.david.findemes.support.Ink
import es.david.findemes.support.a
import es.david.findemes.support.hex
import kotlinx.coroutines.delay
import kotlin.math.abs
import kotlin.math.max

private enum class ThreadState { bought, open, locked }

/** El árbol de mejoras: cinco columnas de notas clavadas en el corcho, unidas con hilo, de abajo arriba. */
@Composable
fun TreeView(onClose: () -> Unit) {
    val game = Game.shared
    val tree = SkillTree.main
    val defs = Content.skills
    var picked by remember { mutableStateOf<String?>(null) }
    var bought by remember { mutableIntStateOf(0) }
    var boughtKey by remember { mutableIntStateOf(0) }

    fun branchColor(k: SkillDef): Color = if (k.id == tree.root.id) Ink.red else Branch.of(k.effect).color

    Box(Modifier.fillMaxSize()) {
        CorkBackground()
        Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally) {
            SheetHeader("Árbol de mejoras", "Se pierde con la bancarrota", onClose)
            CashPill(Fmt.money(game.s.cash), modifier = Modifier.padding(bottom = 8.dp))
            // leyenda
            Row(Modifier.padding(horizontal = 10.dp).padding(bottom = 4.dp), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                for (b in Branch.entries) {
                    val n = tree.branches[b.ordinal].count { game.canGet(it) }
                    Row(Modifier.weight(1f).background(Ink.paper, CircleShape).border(1.5.dp, Ink.ink, CircleShape).padding(horizontal = 5.dp, vertical = 3.dp),
                        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(3.dp, Alignment.CenterHorizontally)) {
                        SymIcon(b.icon, 11.0, b.color)
                        T(b.title, typewriter(10.0, true), Modifier.weight(1f, fill = false), maxLines = 1, minScale = 0.6f)
                        if (n > 0) Box(Modifier.background(Ink.red, CircleShape).padding(horizontal = 4.dp)) { T("$n", chunky(10.0), color = Ink.paper, maxLines = 1) }
                    }
                }
            }
            Box(Modifier.weight(1f).fillMaxWidth()) { TreeColumns(picked) { Sound.click(); picked = it } }
            TreePanel(picked, onBuyAll = { n -> bought = n; boughtKey += 1 })
        }
        // aviso de lo comprado de golpe
        if (bought > 0) {
            LaunchedEffect(boughtKey) { delay(1400); bought = 0 }
        }
    }
}

@Composable
private fun TreeColumns(picked: String?, onPick: (String) -> Unit) {
    val game = Game.shared
    val tree = SkillTree.main
    val cell = 92.0
    val card = 70.0
    val rowH = 98.0
    val longest = tree.branches.maxOf { it.size }.toDouble()
    val scroll = rememberScrollState()
    LaunchedEffect(scroll.maxValue) { if (scroll.value == 0 && scroll.maxValue > 0) scroll.scrollTo(scroll.maxValue) }
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val w = maxWidth.value.toDouble()
        val h = longest * rowH + 230
        val colW = w / Branch.entries.size
        val root = Offset((w / 2).toFloat(), (h - 66).toFloat())
        fun at(b: Int, j: Int) = Offset((colW * (b + 0.5)).toFloat(), (h - 200 - j * rowH).toFloat())
        fun pin(c: Offset, size: Double) = Offset(c.x, (c.y - size / 2 + 3).toFloat())
        Box(Modifier.fillMaxSize().verticalScroll(scroll)) {
            Box(Modifier.fillMaxWidth().height(h.dp)) {
                Canvas(Modifier.fillMaxSize()) {
                    val d = density
                    for ((b, list) in tree.branches.withIndex()) {
                        for (j in list.indices) {
                            val from = if (j == 0) pin(root, cell) else pin(at(b, j - 1), card)
                            val st = if (game.level(list[j]) > 0) ThreadState.bought else if (game.isVisible(list[j])) ThreadState.open else ThreadState.locked
                            thread(from * d, pin(at(b, j), card) * d, Branch.entries[b].color, st, (if (j == 0) 30f else 8f) * d)
                        }
                    }
                }
                NoteView(tree.root, cell, root, picked, onPick)
                for ((b, list) in tree.branches.withIndex()) for ((j, k) in list.withIndex()) NoteView(k, card, at(b, j), picked, onPick)
            }
        }
    }
}

/** hilo de chincheta a chincheta, colgando un poco: tenso y de color si ya está comprada, punteado si no */
private fun DrawScope.thread(from: Offset, to: Offset, color: Color, state: ThreadState, sag: Float) {
    val p = Path().apply { moveTo(from.x, from.y); quadraticTo((from.x + to.x) / 2, max(from.y, to.y) + sag, to.x, to.y) }
    val d = density
    when (state) {
        ThreadState.bought -> {
            translate(1.5f * d, 3f * d) { drawPath(p, Ink.ink.copy(alpha = 0.3f), style = Stroke(3.5f * d, cap = StrokeCap.Round)) }
            drawPath(p, Ink.ink, style = Stroke(5.5f * d, cap = StrokeCap.Round))
            drawPath(p, color, style = Stroke(3.2f * d, cap = StrokeCap.Round))
        }
        ThreadState.open -> drawPath(p, color.copy(alpha = 0.8f), style = Stroke(2.5f * d, cap = StrokeCap.Round, pathEffect = PathEffect.dashPathEffect(floatArrayOf(7 * d, 6 * d))))
        ThreadState.locked -> drawPath(p, Ink.ink.copy(alpha = 0.22f), style = Stroke(1.8f * d, cap = StrokeCap.Round, pathEffect = PathEffect.dashPathEffect(floatArrayOf(3 * d, 6 * d))))
    }
}

/** inclinación fija para cada nota (no cambia entre aperturas) */
private fun tilt(k: SkillDef): Double {
    var h = 0L
    for (ch in k.id) h = h * 31 + ch.code
    return (abs(h) % 7).toDouble() - 3
}

/** nota cuadrada: el icono suelto, el nombre, el nivel y el precio; arriba a la derecha, la marca de su rama */
@Composable
private fun NoteView(k: SkillDef, size: Double, center: Offset, picked: String?, onPick: (String) -> Unit) {
    val game = Game.shared
    val tree = SkillTree.main
    val l = game.level(k)
    val vis = game.isVisible(k)
    val can = game.canGet(k)
    val maxed = l >= k.maxLevel
    val sel = picked == k.id
    val side = if (vis) size else size * 0.72
    val small = size < 80
    val col = if (k.id == tree.root.id) Ink.red else Branch.of(k.effect).color
    val wave by rememberInfiniteTransition(label = "n").animateFloat(0f, 1f, infiniteRepeatable(tween(700), RepeatMode.Reverse), label = "a")
    val pulse = if (can) wave else 0f
    val selScale by animateFloatAsState(if (sel) 1.08f else 1f, label = "s")
    val tl = tilt(k).toFloat()
    // la caja ocupa lo de la nota más la chincheta de arriba
    val boxW = size + 12
    Box(Modifier.offset((center.x - boxW / 2).dp, (center.y - side / 2 - 6).dp).width(boxW.dp).scale(selScale * (1 + pulse * 0.05f))
        .clickable(remember { MutableInteractionSource() }, null) { onPick(k.id) }, contentAlignment = Alignment.TopCenter) {
        Box(Modifier.padding(top = 6.dp).size(side.dp)) {
            Box(Modifier.fillMaxSize().paper(if (can) hex("#fff6c8") else if (vis) Ink.paper else Ink.paperDark, tl.toDouble(), if (vis) 4.0 else 2.0).alpha(if (vis) 1f else 0.8f)) {
                if (vis) {
                    Column(Modifier.fillMaxSize().padding(horizontal = 4.dp).padding(bottom = 6.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        SymIcon(k.icon, if (small) 22.0 else 28.0, if (l > 0) col else Ink.ink, Modifier.padding(top = if (small) 11.dp else 13.dp))
                        T(k.name, chunky(if (small) 10.5 else 12.0), maxLines = 1, minScale = 0.7f, align = TextAlign.Center)
                        Spacer(Modifier.weight(1f))
                        if (maxed) LevelTag(k, if (small) 9.0 else 10.0, col)
                        else Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                            LevelTag(k, if (small) 8.5 else 10.0, col)
                            T(Fmt.money(game.cost(k)), typewriter(if (small) 8.5 else 10.0, true), color = if (can) Ink.ink else Ink.soft, maxLines = 1, minScale = 0.5f)
                        }
                    }
                    if (k.id != tree.root.id) {
                        val b = Branch.of(k.effect)
                        SymIcon(b.icon, 9.0, b.color, Modifier.align(Alignment.TopEnd).padding(top = 5.dp, end = 5.dp))
                    }
                } else {
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { SymIcon("questionmark", 22.0, Ink.soft) }
                }
            }
            if (sel) Box(Modifier.fillMaxSize().rotate(tl).padding(0.dp).drawBehind {
                val e = 5.dp.toPx(); val lw = 4.dp.toPx()
                drawRect(Ink.gold, Offset(-e + lw / 2, -e + lw / 2), androidx.compose.ui.geometry.Size(this.size.width + 2 * e - lw, this.size.height + 2 * e - lw), style = Stroke(lw))
            })
        }
        Chincheta(k, game.bestSkill(Content.skills) == k.id, col)
    }
}

@Composable
private fun Chincheta(k: SkillDef, best: Boolean, col: Color) {
    // la dorada, solo en la mejor compra de ahora
    val s = if (best) 19.0 else 15.0
    Box(contentAlignment = Alignment.Center) {
        if (best) GoldPin(Modifier.size(19.dp))
        else Canvas(Modifier.size(s.dp)) {
            drawCircle(col)
            drawCircle(Color.White.copy(alpha = 0.6f), 2.5.dp.toPx(), center.copy(center.x - 2.dp.toPx(), center.y - 2.dp.toPx()))
            drawCircle(Ink.ink, size.minDimension / 2 - 1.dp.toPx(), style = Stroke(2.dp.toPx()))
        }
    }
}

@Composable
private fun LevelTag(k: SkillDef, size: Double, col: Color) {
    val game = Game.shared
    val l = game.level(k)
    val maxed = l >= k.maxLevel
    Box(Modifier.background(if (maxed) Ink.green else if (l > 0) col else Ink.soft, CircleShape).padding(horizontal = 4.dp, vertical = 1.dp)) {
        T(if (maxed) "MÁX." else "$l/${k.maxLevel}", typewriter(size, true), color = Ink.paper, maxLines = 1)
    }
}

@Composable
private fun TreePanel(picked: String?, onBuyAll: (Int) -> Unit) {
    val game = Game.shared
    val tree = SkillTree.main
    val defs = Content.skills
    val k = picked?.let { id -> defs.firstOrNull { it.id == id } } ?: (defs.filter { game.canGet(it) }.minByOrNull { game.cost(it) } ?: tree.root)
    val l = game.level(k)
    val vis = game.isVisible(k)
    val maxed = l >= k.maxLevel
    val col = if (k.id == tree.root.id) Ink.red else Branch.of(k.effect).color
    val affordable = defs.count { game.canGet(it) }
    var bought by remember { mutableIntStateOf(0) }
    var key by remember { mutableIntStateOf(0) }
    LaunchedEffect(key) { if (bought > 0) { delay(1400); bought = 0 } }

    fun buyAll() {
        var n = 0
        while (n < 500) {
            val next = defs.filter { game.canGet(it) }.minByOrNull { game.cost(it) } ?: break
            game.get(next, quiet = true)
            n += 1
        }
        if (n > 0) { game.save(); Sound.till() }
        bought = n; key += 1
        onBuyAll(n)
    }
    fun parentName(): String {
        val p = tree.parent[k.id] ?: return ""
        return defs.firstOrNull { it.id == p }?.name?.a ?: ""
    }

    Box(Modifier.padding(horizontal = 12.dp).padding(bottom = 8.dp).navigationBarsPadding()) {
        Column(Modifier.fillMaxWidth().paper().padding(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Box(Modifier.size(40.dp).background(col.copy(alpha = 0.18f), CircleShape).border(2.dp, Ink.ink, CircleShape), contentAlignment = Alignment.Center) {
                    SymIcon(if (vis) k.icon else "lock.fill", 22.0, col)
                }
                Column(Modifier.weight(1f)) {
                    T(if (vis) k.name else "Bloqueada", chunky(19.0), maxLines = 1, minScale = 0.6f)
                    T(if (vis) tf("%1 por nivel", k.perText(l)) else tf("Compra antes «%1»", parentName()), typewriter(12.0, true), color = Ink.soft, maxLines = 2)
                }
                Box(Modifier.background(if (maxed) Ink.green else if (l > 0) col else Ink.soft, CircleShape).padding(horizontal = 8.dp, vertical = 2.dp)) {
                    T("$l/${k.maxLevel}", chunky(16.0), color = Ink.paper, maxLines = 1)
                }
            }
            if (vis && l > 0) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    T(tf("Ahora: %1", k.text(l)), typewriter(11.0, true), Modifier.weight(1f, fill = false), maxLines = 1, minScale = 0.6f)
                    if (!maxed) {
                        SymIcon("arrow.right", 12.0, Ink.ink)
                        T(k.text(l + 1), typewriter(11.0, true), Modifier.weight(1f, fill = false), color = Ink.green, maxLines = 1, minScale = 0.6f)
                    }
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                if (vis && !maxed) {
                    ChunkyText("+1 · ${Fmt.money(game.cost(k))}", { game.get(k) }, Modifier.weight(1f), size = 16.0, radius = 12.0, enabled = game.canGet(k), fill = true)
                    ChunkyText("Máx.", {
                        var n = 0
                        while (n < 200 && game.canGet(k)) { game.get(k, quiet = true); n += 1 }
                        if (n > 0) { game.save(); Sound.till() }
                    }, color = Ink.green, text = Ink.paper, size = 16.0, radius = 12.0, enabled = game.canGet(k))
                }
                ChunkyText(if (affordable == 0) "Nada" else tf("Todo (%1)", affordable), { buyAll() }, if (vis && !maxed) Modifier else Modifier.weight(1f),
                    color = Ink.paper, size = 16.0, radius = 12.0, enabled = affordable > 0, fill = !(vis && !maxed))
            }
        }
        AnimatedVisibility(bought > 0, Modifier.align(Alignment.TopCenter).offset(y = (-30).dp), enter = scaleIn() + fadeIn(), exit = fadeOut()) {
            Box(Modifier.outlined(10.0, Ink.paper, shadow = 3.0).padding(horizontal = 10.dp, vertical = 4.dp)) {
                T(tf("+%1 mejoras", bought), chunky(20.0), color = Ink.green, maxLines = 1)
            }
        }
    }
}
