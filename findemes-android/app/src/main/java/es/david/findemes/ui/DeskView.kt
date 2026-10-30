package es.david.findemes.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.unit.toSize
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import es.david.findemes.logic.Desk
import es.david.findemes.logic.Game
import es.david.findemes.logic.P
import es.david.findemes.logic.Sound
import es.david.findemes.model.Content
import es.david.findemes.support.Fmt
import es.david.findemes.support.Ink

/** Un día rompiendo huchas */
@Composable
fun DeskView(zoo: Boolean = false, parade: Boolean = false) {
    val game = Game.shared
    val desk = remember {
        Desk(game.stats, game.s.tier, Content.hammers[game.s.hammer], game.s.day, Content.playing(game.s.skin)).also {
            it.tutorial = game.s.tutorial < 9
            it.zoo = zoo; it.parade = parade
            it.top = 130.0; it.bottom = 120.0
        }
    }
    val scene = remember { DeskScene(desk) }
    var frame by remember { mutableLongStateOf(0L) }
    var stamina by remember { mutableDoubleStateOf(desk.stamina) }
    var cash by remember { mutableDoubleStateOf(game.s.cash) }
    var askQuit by remember { mutableStateOf(false) }
    val density = LocalDensity.current.density

    DisposableEffect(desk) {
        desk.onChange = {
            if (desk.earnedPending > 0) { game.earn(desk.earnedPending); desk.earnedPending = 0.0 }
            cash = game.s.cash
            stamina = desk.stamina
        }
        desk.onFinish = { r ->
            if (desk.earnedPending > 0) { game.earn(desk.earnedPending); desk.earnedPending = 0.0 }
            game.finishDay(r)
        }
        onDispose { desk.onChange = null; desk.onFinish = null }
    }
    var size by remember { mutableStateOf(androidx.compose.ui.geometry.Size.Zero) }
    LaunchedEffect(desk) {
        while (true) {
            withFrameNanos { n ->
                if (size.width > 0) desk.frame(n, size.width / density.toDouble(), size.height / density.toDouble())
                frame = n
            }
        }
    }

    Box(Modifier.fillMaxSize()) {
        Canvas(Modifier.fillMaxSize().onSizeChanged { size = it.toSize() }.pointerInput(desk) {
            awaitEachGesture {
                val down = awaitFirstDown()
                val d = density
                desk.tap(P(down.position.x / d.toDouble(), down.position.y / d.toDouble()))
                desk.holding = P(down.position.x / d.toDouble(), down.position.y / d.toDouble())
                while (true) {
                    val ev = awaitPointerEvent()
                    // otro dedo que toca: también golpea
                    for (c in ev.changes) if (c.pressed && !c.previousPressed && c.id != down.id) desk.tap(P(c.position.x / d.toDouble(), c.position.y / d.toDouble()))
                    val alive = ev.changes.filter { it.pressed }
                    if (alive.isEmpty()) { desk.holding = null; break }
                    val p = alive.last().position
                    desk.holding = P(p.x / d.toDouble(), p.y / d.toDouble())
                }
            }
        }) {
            @Suppress("UNUSED_EXPRESSION") frame
            drawIntoCanvas { c ->
                val nc = c.nativeCanvas
                nc.save()
                nc.scale(density, density)
                scene.draw(nc, this.size.width / density.toDouble(), this.size.height / density.toDouble())
                nc.restore()
            }
        }
        Column(Modifier.fillMaxSize()) {
            Hud(cash, stamina)
            Spacer(Modifier.weight(1f))
            BottomBar(stamina) { Sound.click(); askQuit = true }
        }
        ActionDialog(askQuit, "¿Terminar el día ya?", "Te quedan ${stamina.toInt()} de aguante sin usar.",
            listOf(DialogAction("Terminar el día", destructive = true) { desk.quit() }), cancel = "Seguir rompiendo") { askQuit = false }
    }
}

@Composable
private fun Hud(cash: Double, stamina: Double) {
    val game = Game.shared
    Row(Modifier.fillMaxWidth().statusBarsPadding().padding(horizontal = 14.dp).padding(top = 6.dp), verticalAlignment = Alignment.Top) {
        // la cartera
        Row(Modifier.weight(1f, fill = false).outlined(16.0, Ink.paper).padding(horizontal = 12.dp, vertical = 7.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            SymIcon("eurosign.circle.fill", 28.0, Ink.gold)
            T(Fmt.money(cash), chunky(26.0), maxLines = 1, minScale = 0.6f)
        }
        Spacer(Modifier.weight(1f).padding(6.dp))
        Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(4.dp)) {
            T("DÍA ${game.s.day}", chunky(22.0).hardShadow(2.0, 2.0), color = Ink.paper)
            val left = game.daysLeft
            Box(Modifier.outlined(0.0, if (left == 0) Ink.red.copy(alpha = 0.85f) else Ink.paper, line = 2.0, shadow = 0.0).padding(horizontal = 7.dp, vertical = 3.dp)) {
                T("Factura: ${Fmt.money(game.billAmount)}", typewriter(13.0, true), maxLines = 1)
            }
            T(if (left == 0) "¡VENCE HOY!" else "vence en $left día${if (left == 1) "" else "s"}", typewriter(11.0, true).hardShadow(1.0, 1.0), color = if (left == 0) Ink.red else Ink.paper)
        }
    }
}

@Composable
private fun BottomBar(stamina: Double, onQuit: () -> Unit) {
    val game = Game.shared
    val max = game.stats.stamina
    Row(Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = 14.dp).padding(bottom = 10.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Column(Modifier.weight(1f).outlined(16.0, Ink.paper).padding(10.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Row {
                T("AGUANTE", chunky(16.0)); Spacer(Modifier.weight(1f))
                T("${maxOf(0.0, stamina).toInt()} / ${max.toInt()}", chunky(16.0))
            }
            InkBar(stamina / maxOf(1.0, max), if (stamina / maxOf(1.0, max) < 0.25) Ink.red else Ink.green, 16.0)
        }
        ChunkyButton(onQuit, color = Ink.paper, size = 18.0) { SymIcon("moon.zzz.fill", 24.0, Ink.ink) }
    }
}
