package es.david.findemes.ui

import es.david.findemes.support.tf
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Image
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
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
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
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.ColorMatrix
import androidx.compose.ui.graphics.FilterQuality
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import es.david.findemes.logic.AchDef
import es.david.findemes.logic.Game
import es.david.findemes.logic.Meta
import es.david.findemes.logic.Quest
import es.david.findemes.logic.Sound
import es.david.findemes.logic.claim
import es.david.findemes.logic.claimDaily
import es.david.findemes.logic.dailyIndex
import es.david.findemes.logic.metric
import es.david.findemes.logic.pigNeeded
import es.david.findemes.logic.pigWorth
import es.david.findemes.logic.questReward
import es.david.findemes.logic.xpNeeded
import es.david.findemes.model.Content
import es.david.findemes.model.PigKind
import es.david.findemes.model.Rarity
import es.david.findemes.support.Fmt
import es.david.findemes.support.Ink
import es.david.findemes.support.filling
import es.david.findemes.support.hex
import es.david.findemes.support.rnd
import kotlin.math.cos
import kotlin.math.sin

// MARK: - Nivel y experiencia (arriba en la cocina)

@Composable
fun LevelStrip() {
    val game = Game.shared
    val k = minOf(1.0, game.s.xp / maxOf(1.0, game.xpNeeded))
    Row(Modifier.fillMaxWidth().outlined(14.0, Ink.paper, shadow = 3.0).padding(horizontal = 12.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Box(Modifier.size(38.dp).background(Ink.purple, CircleShape).border(2.5.dp, Ink.ink, CircleShape), contentAlignment = Alignment.Center) {
            T("${game.s.level}", chunky(20.0), color = Ink.paper, maxLines = 1, minScale = 0.5f)
        }
        Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                T(Meta.title(game.s.level), chunky(16.0))
                Spacer(Modifier.weight(1f))
                T("${Fmt.num(game.s.xp)} / ${Fmt.num(game.xpNeeded)}", typewriter(11.0, true), color = Ink.soft)
            }
            InkBar(k, Ink.purple, 10.0)
        }
    }
}

// MARK: - Encargos

@Composable
fun QuestsCard() {
    val game = Game.shared
    Column(Modifier.fillMaxWidth().paper(tilt = 0.4).padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            T("ENCARGOS", chunky(22.0))
            Spacer(Modifier.weight(1f))
            T(tf("%1 hechos", Fmt.num(game.s.stats.missions)), typewriter(12.0, true), color = Ink.soft)
        }
        for (q in game.s.quests) androidx.compose.runtime.key(q.id) { QuestRow(q) }
    }
}

@Composable
fun QuestRow(q: Quest) {
    val game = Game.shared
    val target = if (q.kind.money) Fmt.money(q.target) else Fmt.num(q.target)
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Box(Modifier.width(30.dp), contentAlignment = Alignment.Center) { SymIcon(q.kind.icon, 20.0, Ink.red) }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            T(q.kind.text.filling(target), typewriter(13.0, true), maxLines = 1, minScale = 0.7f)
            InkBar(q.progress / maxOf(1.0, q.target), if (q.done) Ink.green else Ink.gold, 9.0)
            T(tf("+%1 · +%2 exp", Fmt.money(game.questReward(q)), Fmt.num(q.xp)), typewriter(11.0), color = Ink.soft, maxLines = 1, minScale = 0.7f)
        }
        if (q.done) {
            val pulse by rememberInfiniteTransition(label = "q").animateFloat(1f, 1.08f, infiniteRepeatable(tween(500), RepeatMode.Reverse), label = "p")
            ChunkyText("COBRAR", { game.claim(q) }, Modifier.scale(pulse), color = Ink.green, text = Ink.paper, size = 14.0, radius = 10.0)
        }
    }
}

// MARK: - Logros

@Composable
fun AchievementsView(onClose: () -> Unit) {
    val game = Game.shared
    /** primero los que se pueden cobrar, luego los que van en camino, al final los conseguidos */
    fun order(a: AchDef): Int = if (a.id in game.s.achievements) 2 else if (game.metric(a.metric) >= a.target) 0 else 1
    val list = Meta.achievements.sortedBy { order(it) }
    Column(Modifier.fillMaxSize().background(hex("#5c3a1e"))) {
        SheetHeader("Logros", tf("%1 de %2 · +%3 % de dinero", game.s.achievements.size, Meta.achievements.size, game.s.achievements.size), onClose)
        LazyColumn(Modifier.fillMaxSize(), contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 18.dp, vertical = 10.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            items(list, key = { it.id }) { AchRow(it) }
        }
    }
}

@Composable
fun AchRow(def: AchDef) {
    val game = Game.shared
    val got = def.id in game.s.achievements
    val v = game.metric(def.metric)
    val ready = !got && v >= def.target
    Row(Modifier.fillMaxWidth().paper(if (got) Ink.paperDark else Ink.paper, shadow = 3.0).padding(10.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Box(Modifier.width(36.dp), contentAlignment = Alignment.Center) {
            SymIcon(if (got) "rosette" else if (ready) "gift.fill" else "lock.fill", 26.0, if (got) Ink.gold else if (ready) Ink.red else Ink.soft)
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            T(def.name, chunky(17.0))
            T(def.desc, typewriter(12.0), color = Ink.soft)
            if (!got && !ready) InkBar(v / def.target, Ink.gold, 7.0)
        }
        if (ready) ChunkyText("+1 %", { game.claim(def) }, color = Ink.green, text = Ink.paper, size = 15.0, radius = 10.0)
        else if (got) Stamp("HECHO", Ink.green, Modifier.scale(0.7f))
    }
}

// MARK: - Premio diario

@Composable
fun DailyView() {
    val game = Game.shared
    val today = game.dailyIndex
    Overlay(0.55) {
        Column(Modifier.padding(22.dp).paper(tilt = -0.5).padding(20.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)) {
            T("PREMIO DEL DÍA", chunky(30.0), color = Ink.red)
            T(if (game.s.streak > 0 && today > 0) (if (today == 1) tf("Llevas %1 día seguido", today) else tf("Llevas %1 días seguidos", today)) else "Vuelve cada día: el premio crece",
                typewriter(13.0, true), color = Ink.soft)
            for (row in listOf(0..3, 4..6)) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    for (i in row) Box(Modifier.weight(1f)) { DailyCell(i, today) }
                    if (row.count() < 4) Spacer(Modifier.weight(1f))
                }
            }
            ChunkyText("¡COGER!", { game.claimDaily() }, Modifier.fillMaxWidth(), size = 22.0, fill = true)
        }
    }
}

@Composable
private fun DailyCell(i: Int, today: Int) {
    val game = Game.shared
    val r = Meta.daily[i]
    val past = i < today
    val now = i == today
    Box(Modifier.scale(if (now) 1.06f else 1f).background(if (now) Ink.gold else if (past) Ink.paperDark else Ink.paper)
        .border(if (now) 3.dp else 1.5.dp, Ink.ink).defaultMinSize(minHeight = 86.dp), contentAlignment = Alignment.Center) {
        Column(Modifier.fillMaxWidth().padding(6.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
            T(tf("Día %1", i + 1), typewriter(11.0, true))
            if (r.chest != null) EnvelopeArt(r.chest, Modifier.width(40.dp).height(28.dp))
            else ItemImage("c_loot", Modifier.size(30.dp))
            T(if (r.chest != null) r.name else Fmt.money(rnd(r.pigs * game.pigWorth)), typewriter(10.0, true), maxLines = 1, minScale = 0.6f)
        }
        if (past) SymIcon("checkmark", 30.0, Ink.green)
    }
}

// MARK: - Subida de nivel

@Composable
fun LevelUpView(level: Int) {
    val game = Game.shared
    var pop by remember { mutableStateOf(false) }
    LaunchedEffect(level) { Sound.fanfare(); pop = true }
    val sc by animateFloatAsState(if (pop) 1f else 0.3f, spring(dampingRatio = 0.45f, stiffness = 250f), label = "p")
    fun close() { Sound.click(); game.levelUp = null }
    Overlay(0.5, { close() }) {
        Column(Modifier.padding(30.dp).paper(tilt = 0.6).padding(22.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
            T(tf("¡NIVEL %1!", level), chunky(44.0).hardShadow(3.0, 3.0), Modifier.scale(sc), color = Ink.purple)
            T(Meta.title(level), chunky(22.0))
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                EnvelopeArt(if (level % 10 == 0) Rarity.legendaria else if (level % 5 == 0) Rarity.epica else Rarity.comun, Modifier.width(60.dp).height(42.dp))
                T("+1 % de dinero para siempre", typewriter(13.0, true))
            }
            ChunkyText("¡Seguimos!", { close() }, Modifier.fillMaxWidth(), size = 20.0, fill = true)
        }
    }
}

// MARK: - La historia del principio (cuatro viñetas y a jugar)

private val introPages = listOf(
    "DÍA 1 DEL MES" to "La nevera, vacía.\nEl buzón, lleno de facturas.",
    "LA HERENCIA" to "Pero la abuela te dejó algo: un trastero lleno de {huchas}.",
    "Y SU CHANCLA" to "La de toda la vida. Nunca falla.",
    "EL PLAN" to "Rompe {huchas}, paga las facturas antes de que venzan… y que no venga el cobrador.",
)

@Composable
fun IntroView() {
    val game = Game.shared
    var page by remember { mutableIntStateOf(0) }
    fun next() {
        Sound.click()
        if (page < introPages.size - 1) { page += 1; return }
        game.s.seenIntro = true
        game.s.tutorial = 1
        game.save()
        game.startDay()
    }
    Overlay(0.6, { next() }) {
        val tilt by animateFloatAsState(if (page % 2 == 0) -0.6f else 0.6f, spring(dampingRatio = 0.7f, stiffness = 300f), label = "t")
        Column(Modifier.padding(24.dp).paper(tilt = tilt.toDouble()).padding(22.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp)) {
            AnimatedContent(page, transitionSpec = { (scaleIn(initialScale = 0.6f) + fadeIn()) togetherWith fadeOut() }, label = "art") { p ->
                Box(Modifier.fillMaxWidth().height(150.dp), contentAlignment = Alignment.Center) { IntroArt(p) }
            }
            T(introPages[page].first, chunky(32.0), color = Ink.red, align = TextAlign.Center)
            T(introPages[page].second, typewriter(16.0), Modifier.defaultMinSize(minHeight = 66.dp), align = TextAlign.Center)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                for (i in introPages.indices) Box(Modifier.size(9.dp).background(if (i == page) Ink.ink else Ink.paperDark, CircleShape))
            }
            ChunkyText(if (page == introPages.size - 1) "¡A ROMPER!" else "Sigue", { next() }, Modifier.fillMaxWidth(), size = 22.0, fill = true)
        }
    }
}

@Composable
private fun IntroArt(page: Int) {
    when (page) {
        0 -> Column(Modifier.paper(tilt = -4.0).padding(14.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
            T("FACTURA", typewriter(18.0, true))
            T("TOTAL: 15 €", typewriter(14.0))
            Stamp("VENCE PRONTO")
        }
        1 -> Row(horizontalArrangement = Arrangement.spacedBy((-30).dp), verticalAlignment = Alignment.CenterVertically) {
            SkinIcon("cerdo", 90.0); SkinIcon("cerdo", 120.0, "oro"); SkinIcon("cerdo", 90.0)
        }
        2 -> ItemImage("m_chancla", Modifier.height(150.dp).rotate(-20f))
        else -> Row(verticalAlignment = Alignment.CenterVertically) {
            ItemImage("m_chancla", Modifier.width(70.dp).rotate(-35f))
            SkinIcon("cerdo", 120.0)
        }
    }
}

// MARK: - El huchario: las huchas que has descubierto

/** el color con que se tiñe cada tipo en el establo */
private fun PigKind.albumTint(): Color = when (this) {
    PigKind.lava -> hex("#ff7a3a")
    PigKind.cosmica -> hex("#a98bff")
    PigKind.robot -> hex("#b8d8ff")
    PigKind.hielo -> hex("#c8f2ff")
    PigKind.suerte -> hex("#8fe39a")
    PigKind.zombi -> hex("#a9c08f")
    PigKind.ninja -> hex("#6a6474")
    PigKind.payaso -> hex("#ffd9a0")
    PigKind.pirata -> hex("#e0b88a")
    PigKind.vampiro -> hex("#c05060")
    PigKind.momia -> hex("#efe4c4")
    PigKind.alien -> hex("#9fe87a")
    PigKind.fenix -> hex("#ff9a5a")
    PigKind.agujero -> hex("#6a5a90")
    else -> Color.White
}

private fun hueMatrix(deg: Double): ColorMatrix {
    val a = Math.toRadians(deg)
    val c = cos(a).toFloat(); val s = sin(a).toFloat()
    return ColorMatrix(floatArrayOf(
        0.213f + c * 0.787f - s * 0.213f, 0.715f - c * 0.715f - s * 0.715f, 0.072f - c * 0.072f + s * 0.928f, 0f, 0f,
        0.213f - c * 0.213f + s * 0.143f, 0.715f + c * 0.285f + s * 0.140f, 0.072f - c * 0.072f - s * 0.283f, 0f, 0f,
        0.213f - c * 0.213f - s * 0.787f, 0.715f - c * 0.715f + s * 0.715f, 0.072f + c * 0.928f + s * 0.072f, 0f, 0f,
        0f, 0f, 0f, 1f, 0f,
    ))
}

/** la hucha de un tipo con el personaje que llevas puesto */
@Composable
fun KindIcon(kind: PigKind, size: Double, dark: Boolean = false, modifier: Modifier = Modifier) {
    val game = Game.shared
    val skin = Content.playing(game.s.skin)
    val b = Assets.skin(skin.id, kind.look)
    Box(modifier.size(size.dp)) {
        if (b != null) {
            val m = ColorMatrix()
            val t = kind.albumTint()
            m.timesAssign(ColorMatrix(floatArrayOf(t.red, 0f, 0f, 0f, 0f, 0f, t.green, 0f, 0f, 0f, 0f, 0f, t.blue, 0f, 0f, 0f, 0f, 0f, 1f, 0f)))
            if (kind == PigKind.arcoiris) m.timesAssign(hueMatrix(120.0))
            if (kind == PigKind.diamante || kind == PigKind.arcoiris) m.timesAssign(ColorMatrix().apply { setToSaturation(1.7f) })
            if (dark) m.timesAssign(ColorMatrix(floatArrayOf(0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 1f, 0f)))
            Image(remember(b) { b.asImageBitmap() }, null, Modifier.size(size.dp).alpha(if (kind == PigKind.fantasma) 0.55f else 1f),
                colorFilter = ColorFilter.colorMatrix(m), filterQuality = FilterQuality.High)
        }
        val h = Hat.spec(kind); val img = Hat.image(kind)
        if (h != null && img != null && !dark) {
            // en el mismo sitio que en la mesa: la hucha mide 1,5 veces su tamaño de ancho
            val k = minOf(size / skin.w, size / skin.h)
            val iw = skin.w * k; val ih = skin.h * k
            val s = iw / 1.5
            val w = s * h.width; val hh = w * h.h / h.w
            val hx = (size - iw) / 2 + skin.head.x * k; val hy = (size - ih) / 2 + skin.head.y * k
            val cx = if (h.onBody) size / 2 else hx + h.dx * s + (0.5 - h.ax) * w
            val cy = if (h.onBody) size / 2 + ih * 0.05 else hy + h.dy * s + (0.5 - h.ay) * hh
            Image(remember(img) { img.asImageBitmap() }, null, Modifier.offset((cx - w / 2).dp, (cy - hh / 2).dp).size(w.dp, hh.dp), filterQuality = FilterQuality.High)
        }
    }
}

@Composable
fun PigLevelStrip() {
    val game = Game.shared
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        T(tf("{Huchas} nivel %1", game.s.tier), typewriter(12.0, true), maxLines = 1)
        Box(Modifier.weight(1f)) { InkBar(game.s.pigXP / maxOf(1.0, game.pigNeeded), Ink.pink, 8.0) }
        T("${Fmt.num(game.s.pigXP)}/${Fmt.num(game.pigNeeded)}", typewriter(11.0), color = Ink.soft, maxLines = 1)
    }
}

@Composable
fun BestiaryView(onClose: () -> Unit) {
    val game = Game.shared
    val kinds = PigKind.entries.sortedBy { it.minTier }
    val found = kinds.count { game.s.bestTier >= it.minTier }
    Column(Modifier.fillMaxSize().background(hex("#7a2f45"))) {
        SheetHeader("El establo", tf("%1 de %2 {huchas} descubiert{as}", found, kinds.size), onClose)
        Column(Modifier.padding(horizontal = 18.dp).padding(bottom = 8.dp).fillMaxWidth().paper().padding(12.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
            T(tf("NIVEL DE {LAS} {HUCHAS}: %1", game.s.tier), chunky(18.0))
            T(tf("Récord: nivel %1", game.s.bestTier), typewriter(12.0, true), color = Ink.soft)
            PigLevelStrip()
        }
        LazyVerticalGrid(GridCells.Fixed(2), Modifier.fillMaxSize(), contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 18.dp, vertical = 10.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            items(kinds, key = { it.name }) { k -> KindCell(k) }
        }
    }
}

@Composable
private fun KindCell(k: PigKind) {
    val game = Game.shared
    val open = game.s.bestTier >= k.minTier
    val n = game.s.brokenByKind[k.name] ?: 0.0
    Column(Modifier.fillMaxWidth().paper(if (open) Ink.paper else Ink.paperDark, shadow = 3.0).padding(10.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Box(Modifier.height(86.dp), contentAlignment = Alignment.Center) {
            KindIcon(k, 92.0, dark = !open, modifier = Modifier.alpha(if (open) 1f else 0.35f))
            if (!open) SymIcon("lock.fill", 30.0, Ink.paper)
        }
        T(if (open) k.title else "???", chunky(16.0), maxLines = 1, minScale = 0.7f)
        T(if (open) k.line else tf("Sale en el nivel %1", k.minTier), typewriter(11.0), Modifier.defaultMinSize(minHeight = 28.dp), color = Ink.soft, maxLines = 2, align = TextAlign.Center)
        if (open) Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp), verticalAlignment = Alignment.CenterVertically) { SymIcon("hammer.fill", 14.0, Ink.ink); T(Fmt.num(n), typewriter(11.0, true)) }
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp), verticalAlignment = Alignment.CenterVertically) { SymIcon("eurosign.circle.fill", 14.0, Ink.ink); T("×" + Fmt.num(k.value), typewriter(11.0, true)) }
        }
    }
}

/** aviso de hucha nueva */
@Composable
fun NewKindView(kind: PigKind) {
    val game = Game.shared
    var pop by remember(kind) { mutableStateOf(false) }
    LaunchedEffect(kind) { Sound.fanfare(); pop = true }
    val p by animateFloatAsState(if (pop) 1f else 0f, spring(dampingRatio = 0.5f, stiffness = 200f), label = "p")
    fun close() { Sound.click(); if (game.newKinds.isNotEmpty()) game.newKinds = game.newKinds.drop(1) }
    Overlay(0.5, { close() }) {
        Column(Modifier.padding(30.dp).paper(tilt = -0.6).padding(22.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
            T("¡{HUCHA} NUEV{A}!", chunky(36.0), color = Ink.red)
            KindIcon(kind, 150.0, modifier = Modifier.scale(0.2f + 0.8f * p).rotate(-30f * (1 - p)))
            T(kind.title, chunky(24.0))
            T(kind.line, typewriter(14.0), align = TextAlign.Center)
            T(tf("{Huchas} nivel %1: más vida y más dinero", game.s.tier), typewriter(12.0, true), color = Ink.soft, align = TextAlign.Center)
            ChunkyText("¡A por ella!", { close() }, Modifier.fillMaxWidth(), size = 20.0, fill = true)
        }
    }
}
