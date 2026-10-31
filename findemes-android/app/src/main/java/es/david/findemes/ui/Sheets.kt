package es.david.findemes.ui

import es.david.findemes.support.tr
import es.david.findemes.support.nm
import es.david.findemes.support.tf
import es.david.findemes.money.Reward
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.scaleIn
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import es.david.findemes.logic.ChestPrize
import es.david.findemes.logic.DayReport
import es.david.findemes.logic.Game
import es.david.findemes.logic.GameEvent
import es.david.findemes.logic.Sound
import es.david.findemes.logic.mortgageName
import es.david.findemes.model.CoinDef
import es.david.findemes.model.Content
import es.david.findemes.model.Rarity
import es.david.findemes.support.Fmt
import es.david.findemes.support.Ink
import es.david.findemes.support.a
import es.david.findemes.support.hex
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

// MARK: - Ticket del día y sobres sorpresa

@Composable
fun ReportView(report: DayReport) {
    val game = Game.shared
    var shown by remember { mutableIntStateOf(0) }
    val hadChests = remember { game.s.pendingChests.isNotEmpty() }
    val lines = remember(report.id) {
        val l = mutableListOf(
            "{HUCHAS} ROT{AS}" to "${report.broken}",
            "MARTILLAZOS" to "${report.swings}",
            "CRÍTICOS" to "${report.crits}",
        )
        if (report.golden > 0) l.add("{HUCHAS} DORAD{AS}" to "${report.golden}")
        if (report.kings > 0) l.add("REY {HUCHA}" to "${report.kings}")
        if (report.coins.isNotEmpty()) l.add("MONEDAS RARAS" to "${report.coins.size}")
        if (report.best > 0) l.add("MEJOR {HUCHA}" to Fmt.money(report.best))
        if (report.bestCombo >= 3) l.add("MEJOR COMBO" to "×${report.bestCombo}")
        if (report.frenzies > 0) l.add("FRENESÍ" to "${report.frenzies}")
        l
    }
    LaunchedEffect(report.id) {
        // las líneas del ticket salen una a una, como en la caja
        for (i in lines.indices) {
            delay(140)
            shown = i + 1
            Sound.click()
        }
        delay(200)
        Sound.till()
    }
    val done = shown >= lines.size
    Overlay(0.55) {
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(20.dp).padding(top = 30.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(18.dp)) {
            // el ticket
            Column(Modifier.rotate(-0.8f), horizontalAlignment = Alignment.CenterHorizontally) {
                Column(Modifier.fillMaxWidth().background(hex("#fffdf6")).padding(horizontal = 20.dp).padding(top = 18.dp, bottom = 6.dp),
                    horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    T("SUPERMERCADO DE {HUCHAS}", typewriter(13.0, true))
                    T(tf("TICKET DEL DÍA %1", report.day), typewriter(16.0, true))
                    Dashed()
                    for ((i, l) in lines.withIndex()) {
                        val on = i < shown
                        val off by animateFloatAsState(if (on) 0f else 8f, spring(dampingRatio = 0.7f, stiffness = 600f), label = "l")
                        Row(Modifier.fillMaxWidth().alpha(if (on) 1f else 0f).offset(y = off.dp)) {
                            T(l.first, typewriter(14.0)); Spacer(Modifier.weight(1f)); T(l.second, typewriter(14.0, true))
                        }
                    }
                    Dashed()
                    val sc by animateFloatAsState(if (done) 1f else 0.7f, spring(dampingRatio = 0.7f, stiffness = 600f), label = "t")
                    Row(Modifier.fillMaxWidth().alpha(if (done) 1f else 0f).scale(sc), verticalAlignment = Alignment.Bottom) {
                        T("TOTAL", typewriter(18.0, true), Modifier.padding(bottom = 4.dp)); Spacer(Modifier.weight(1f)); T(Fmt.money(report.earned), chunky(32.0), maxLines = 1, minScale = 0.5f)
                    }
                    Dashed()
                    T(tf("En la cartera: %1", Fmt.money(game.s.cash)), typewriter(13.0, true))
                    val left = game.s.billDue - game.s.day
                    T(if (left < 0) "¡LA FACTURA HA VENCIDO!" else if (left == 0) "La factura vence HOY" else (if (left == 1) tf("La factura vence en %1 día", left) else tf("La factura vence en %1 días", left)),
                        typewriter(13.0, true), color = if (left <= 0) Ink.red else Ink.ink)
                }
                // dientes de sierra del papel
                ZigZag(hex("#fffdf6"), Modifier.fillMaxWidth().height(10.dp))
            }
            if (report.record) Stamp("¡RÉCORD!", Ink.green, Modifier.scale(1.4f).alpha(if (done) 1f else 0f))
            if (report.xp > 0) {
                T(tf("+%1 de experiencia", Fmt.num(report.xp)), chunky(18.0).hardShadow(2.0, 2.0), Modifier.alpha(if (done) 1f else 0f), color = Ink.paper)
            }
            if (hadChests) ChestOpener()
            ChunkyText(if (game.s.pendingChests.isEmpty()) "A LA COCINA" else "Abrir los sobres luego", {
                Sound.click()
                game.afterReport()
            }, Modifier.fillMaxWidth().alpha(if (done) 1f else 0f), size = 22.0, fill = true)
        }
    }
}

@Composable
private fun Dashed() {
    T("- ".repeat(22), typewriter(12.0), color = Ink.soft, maxLines = 1)
}

@Composable
fun ZigZag(color: Color, modifier: Modifier) {
    Canvas(modifier) {
        val p = Path()
        p.moveTo(0f, 0f)
        var x = 0f
        var up = false
        val step = 8.dp.toPx()
        while (x < size.width) {
            x += step
            p.lineTo(minOf(x, size.width), if (up) 0f else size.height)
            up = !up
        }
        p.lineTo(size.width, 0f)
        p.close()
        drawPath(p, color)
    }
}

class AllPrizes { var count = 0; var cash = 0.0; val fresh = mutableListOf<CoinDef>(); var legacy = 0.0; var best = Rarity.comun }

/** los sobres sorpresa: se abren uno a uno */
@Composable
fun ChestOpener() {
    val game = Game.shared
    var prize by remember { mutableStateOf<ChestPrize?>(null) }
    var opening by remember { mutableStateOf(false) }
    var all by remember { mutableStateOf<AllPrizes?>(null) }
    val wobble = remember { Animatable(0f) }
    val scope = rememberCoroutineScope()
    fun shake() = scope.launch {
        for ((a, d) in listOf(-9f to 60, 9f to 70, -6f to 70, 0f to 80)) wobble.animateTo(a, tween(d))
    }
    val pending = game.s.pendingChests
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
        T(if (pending.isEmpty()) "¡SOBRES ABIERTOS!" else (if (pending.size == 1) tf("%1 SOBRE SORPRESA", 1) else tf("%1 SOBRES SORPRESA", pending.size)), chunky(24.0).hardShadow(2.0, 2.0), color = Ink.paper)
        prize?.let { p ->
            key(p.id) {
                AnimatedVisibility(true, enter = scaleIn(spring(dampingRatio = 0.6f, stiffness = 300f), 0.3f) + fadeIn()) {
                    Column(Modifier.fillMaxWidth().paper().padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        T(tr(p.rarity.title).uppercase(), chunky(18.0), color = if (p.rarity == Rarity.comun) Ink.ink else p.rarity.color)
                        T("+" + Fmt.money(p.cash), chunky(34.0), color = Ink.green, maxLines = 1, minScale = 0.5f)
                        p.coin?.let { c ->
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                CoinArt(c, true, Modifier.size(54.dp))
                                Column {
                                    T(c.name, chunky(18.0))
                                    T(if (p.duplicate) tf("Repetida: +%1", Fmt.money(p.legacy)) else "¡Nueva para el álbum!", typewriter(12.0, true), color = if (p.duplicate) Ink.soft else Ink.purple)
                                }
                            }
                        }
                    }
                }
            }
        }
        pending.firstOrNull()?.let { next ->
            EnvelopeArt(next, Modifier.width(150.dp).height(104.dp).rotate(wobble.value)
                .clickable(remember { MutableInteractionSource() }, null, enabled = !opening) {
                    all = null
                    opening = true
                    shake()
                    Sound.click()
                    scope.launch {
                        delay(300)
                        val p = game.openChest()
                        prize = p
                        if (p != null) { if (p.rarity == Rarity.comun) Sound.till() else Sound.fanfare() }
                        opening = false
                    }
                })
            if (pending.size >= 2) {
                ChunkyText(tf("Abrir los %1 de golpe", pending.size), {
                    opening = true
                    shake()
                    val a = AllPrizes()
                    for (p in game.openAllChests()) {
                        a.count += 1
                        a.cash += p.cash
                        a.legacy += p.legacy
                        if (p.coin != null && !p.duplicate) a.fresh.add(p.coin)
                        if (p.rarity.order > a.best.order) a.best = p.rarity
                    }
                    prize = null
                    all = a
                    if (a.best == Rarity.comun) Sound.till() else Sound.fanfare()
                    opening = false
                }, Modifier.fillMaxWidth(), size = 18.0, enabled = !opening, fill = true)
            }
        }
        all?.let { a ->
            AnimatedVisibility(true, enter = scaleIn(spring(dampingRatio = 0.6f, stiffness = 300f), 0.3f) + fadeIn()) {
                Column(Modifier.fillMaxWidth().paper().padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    T(tf("%1 SOBRES ABIERTOS", a.count), chunky(20.0), color = if (a.best == Rarity.comun) Ink.ink else a.best.color)
                    T("+" + Fmt.money(a.cash), chunky(34.0), color = Ink.green, maxLines = 1, minScale = 0.5f)
                    if (a.fresh.isNotEmpty()) {
                        T("¡Monedas nuevas para el álbum!", typewriter(12.0, true), color = Ink.purple)
                        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) { for (c in a.fresh.take(6)) CoinArt(c, true, Modifier.size(44.dp)) }
                    }
                    if (a.legacy > 0) T(tf("Repetidas: +%1", Fmt.money(a.legacy)), typewriter(12.0, true), color = Ink.soft)
                }
            }
        }
    }
}

@Composable
fun EnvelopeArt(rarity: Rarity, modifier: Modifier) {
    Canvas(modifier) {
        val d = 1.dp.toPx()
        val r = Rect(4 * d, 4 * d, size.width - 6 * d, size.height - 6 * d)
        drawRect(Ink.ink, Offset(r.left + 4 * d, r.top + 5 * d), r.size)
        drawRect(if (rarity == Rarity.comun) Ink.paper else rarity.color, r.topLeft, r.size)
        drawRect(Ink.ink, r.topLeft, r.size, style = Stroke(3 * d))
        val flap = Path().apply { moveTo(r.left, r.top); lineTo(r.center.x, r.center.y + 6 * d); lineTo(r.right, r.top) }
        drawPath(flap, Ink.ink, style = Stroke(3 * d))
        val c = Offset(r.center.x, r.center.y + 6 * d)
        drawCircle(Ink.red, 14 * d, c)
        drawCircle(Ink.ink, 14 * d - 1.25f * d, c, style = Stroke(2.5f * d))
        drawContext.canvas.nativeCanvas.apply {
            val p = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply { typeface = Tex.chunky; textSize = 16 * d; color = Ink.paper.toArgb(); textAlign = android.graphics.Paint.Align.CENTER }
            drawText(Fmt.coin, c.x, c.y - (p.ascent() + p.descent()) / 2, p)
        }
    }
}

// MARK: - El cobrador, Hacienda y la bancarrota

@Composable
fun EventView(event: GameEvent) {
    val game = Game.shared
    var stamped by remember { mutableStateOf(false) }
    LaunchedEffect(event.id) {
        if (event is GameEvent.Collector) { delay(300); stamped = true; delay(50); Sound.stamp() } else { delay(300); stamped = true }
    }
    fun close() { Sound.click(); game.event = null }
    Overlay(0.6) {
        Box(Modifier.padding(22.dp)) {
            Column(Modifier.paper(tilt = -0.8).padding(22.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)) {
                when (event) {
                    is GameEvent.Collector -> {
                        T("¡EL COBRADOR!", chunky(36.0), color = Ink.red)
                        T(tf("No pagaste a %1 a tiempo. Se lo han llevado todo: el dinero, los martillos y las mejoras.", nm(Content.bills[minOf(game.s.billIndex, Content.bills.size - 1)].company)),
                            typewriter(15.0), align = TextAlign.Center)
                        LegacyLine(event.legacy)
                        ChunkyText("Empezar de nuevo", { close() }, Modifier.fillMaxWidth(), size = 20.0, fill = true)
                    }
                    GameEvent.Warning -> {
                        val company = Content.bills[minOf(game.s.billIndex, Content.bills.size - 1)].company
                        T("¡LLAMA EL COBRADOR!", chunky(32.0), color = Ink.red, align = TextAlign.Center)
                        T(tf("No te llega para pagar a %1. Hoy está de buenas: si quieres, te da un día más.", nm(company)),
                            typewriter(15.0), align = TextAlign.Center)
                        T(Fmt.money(game.billAmount), chunky(30.0), color = Ink.red, maxLines = 1, minScale = 0.5f)
                        RewardButton("Un día más", Reward.prorroga, Modifier.fillMaxWidth(), color = Ink.gold, size = 20.0) { game.reprieve() }
                        ChunkyText("Que se lo lleve todo", { game.event = null; game.bankruptcy(forced = true) }, Modifier.fillMaxWidth(), color = Ink.paper, size = 18.0, fill = true)
                    }
                    GameEvent.Taxes -> {
                        T("¡HACIENDA PAGADA!", chunky(32.0), color = Ink.green, align = TextAlign.Center)
                        T("Has sobrevivido a un año entero de facturas. Ahora puedes declararte en bancarrota y cobrar tus puntos de herencia, o aguantar otro año con facturas todavía más caras (y {huchas} más ric{as}).",
                            typewriter(14.0), align = TextAlign.Center)
                        LegacyLine(game.legacyGain)
                        ChunkyText(tf("Bancarrota (+%1 puntos)", Fmt.num(game.legacyGain)), { game.bankruptcy() }, Modifier.fillMaxWidth(), size = 19.0, fill = true)
                        ChunkyText("Otro año más", { game.anotherYear() }, Modifier.fillMaxWidth(), color = Ink.paper, size = 19.0, fill = true)
                    }
                    is GameEvent.Bankrupt -> {
                        T("BANCARROTA", chunky(36.0))
                        T("Vuelves a empezar con la chancla, pero con más experiencia.", typewriter(15.0), align = TextAlign.Center)
                        LegacyLine(event.legacy)
                        ChunkyText("A la herencia y a por otra", { close() }, Modifier.fillMaxWidth(), size = 20.0, fill = true)
                    }
                }
            }
            if (event is GameEvent.Collector) {
                val sc by animateFloatAsState(if (stamped) 1.3f else 3f, spring(dampingRatio = 0.5f, stiffness = 500f), label = "st")
                Stamp("EMBARGADO", modifier = Modifier.align(Alignment.TopEnd).offset((-10).dp, (-14).dp).scale(sc).alpha(if (stamped) 1f else 0f))
            }
        }
    }
}

@Composable
private fun LegacyLine(v: Double) {
    val game = Game.shared
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Row(Modifier.outlined(12.0, hex("#f2d58a"), shadow = 3.0).padding(vertical = 6.dp, horizontal = 12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            SymIcon("sparkles", 20.0, Ink.purple)
            T(tf("+%1 puntos de herencia", Fmt.num(v)), chunky(22.0), maxLines = 1, minScale = 0.6f)
        }
        // lo que quedaba en la cartera se va a la hipoteca
        if (game.mortgageAdded > 0) {
            Row(Modifier.padding(top = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                SymIcon("house.fill", 16.0, Ink.green)
                T(tf("+%1 a %2", Fmt.money(game.mortgageAdded), nm(game.mortgageName)), typewriter(13.0, true), maxLines = 1)
            }
        }
    }
}
