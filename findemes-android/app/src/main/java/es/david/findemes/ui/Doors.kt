package es.david.findemes.ui

import es.david.findemes.support.tr
import es.david.findemes.support.nm
import es.david.findemes.support.tf
import es.david.findemes.money.Reward
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import es.david.findemes.logic.AwayPrize
import es.david.findemes.logic.Door
import es.david.findemes.logic.Feature
import es.david.findemes.logic.Game
import es.david.findemes.logic.Mortgage
import es.david.findemes.logic.Sound
import es.david.findemes.logic.achievementsReady
import es.david.findemes.logic.collectAway
import es.david.findemes.logic.isNew
import es.david.findemes.logic.milestoneName
import es.david.findemes.support.L10n
import es.david.findemes.support.Lang
import es.david.findemes.logic.mortgageName
import es.david.findemes.logic.mortgageShare
import es.david.findemes.logic.mortgageTotal
import es.david.findemes.logic.open
import es.david.findemes.logic.payMortgage
import es.david.findemes.logic.unlocked
import es.david.findemes.model.Content
import es.david.findemes.support.Fmt
import es.david.findemes.support.Ink
import es.david.findemes.support.hex
import kotlin.math.floor
import kotlin.math.log10
import kotlin.math.min
import kotlin.math.pow

// MARK: - Una puerta de la cocina (se abre con el sello «NUEVO» la primera vez)

@Composable
fun DoorCard(door: Door, subtitle: String, badge: Boolean = false, modifier: Modifier = Modifier, action: () -> Unit) {
    val game = Game.shared
    val new = game.isNew(door)
    Box(modifier) {
        ChunkyButton({ Sound.click(); game.open(door); action() }, Modifier.fillMaxWidth(), color = Ink.paper, size = 18.0, radius = 16.0) {
            Column(Modifier.weight(1f).padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    SymIcon(door.icon, 26.0, door.color)
                    Spacer(Modifier.weight(1f))
                    if (badge && !new) {
                        Box(Modifier.background(Ink.red, CircleShape).border(2.dp, Ink.ink, CircleShape).padding(horizontal = 7.dp)) { T("¡!", chunky(15.0), color = Ink.paper) }
                    }
                }
                T(door.title, chunky(22.0), maxLines = 1, minScale = 0.7f)
                T(subtitle, typewriter(12.0, true), color = Ink.soft, maxLines = 1, minScale = 0.7f)
            }
        }
        if (new) Stamp("NUEVO", Ink.red, Modifier.align(Alignment.TopEnd).offset(8.dp, (-10).dp).scale(0.8f))
    }
}

// MARK: - Varias pantallas detrás de una puerta, con pestañas abajo

class DoorTab(val id: String, val name: String, val icon: String, val badge: Boolean = false, val content: @Composable () -> Unit)

@Composable
fun TabbedDoor(tabs: List<DoorTab>, start: String? = null) {
    var picked by remember { mutableStateOf(start ?: "") }
    val current = tabs.firstOrNull { it.id == picked } ?: tabs[0]
    Column(Modifier.fillMaxSize()) {
        Box(Modifier.weight(1f)) { androidx.compose.runtime.key(current.id) { current.content() } }
        if (tabs.size > 1) {
            Column(Modifier.fillMaxWidth().background(Ink.woodDark)) {
                Box(Modifier.fillMaxWidth().height(3.dp).background(Ink.ink))
                Row(Modifier.navigationBarsPadding().padding(horizontal = 12.dp).padding(top = 8.dp, bottom = 4.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    for (t in tabs) {
                        val sel = t.id == current.id
                        Box(Modifier.weight(1f).clickableNoRipple { Sound.click(); picked = t.id }) {
                            Column(Modifier.fillMaxWidth().background(if (sel) Ink.ink else Ink.paper, RoundedCornerShape(12.dp)).border(2.5.dp, Ink.ink, RoundedCornerShape(12.dp)).padding(vertical = 7.dp),
                                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                SymIcon(t.icon, 20.0, if (sel) Ink.paper else Ink.ink)
                                T(t.name, chunky(13.0), color = if (sel) Ink.paper else Ink.ink, maxLines = 1, minScale = 0.6f)
                            }
                            if (t.badge && !sel) Box(Modifier.align(Alignment.TopEnd).offset(3.dp, (-3).dp).size(12.dp).background(Ink.red, CircleShape).border(2.dp, Ink.ink, CircleShape))
                        }
                    }
                }
            }
        }
    }
}

/** el álbum: el establo, los logros y las monedas (con los sobres sin abrir) */
@Composable
fun AlbumDoor(onClose: () -> Unit, start: String? = null) {
    val game = Game.shared
    val tabs = mutableListOf(DoorTab("establo", "Establo", "house.fill") { BestiaryView(onClose) })
    if (game.unlocked(Feature.logros)) tabs.add(DoorTab("logros", "Logros", "rosette", game.achievementsReady > 0) { AchievementsView(onClose) })
    if (game.unlocked(Feature.monedas)) tabs.add(DoorTab("monedas", "Monedas", "circle.circle.fill", game.s.pendingChests.isNotEmpty()) { CoinsView(onClose) })
    TabbedDoor(tabs, start)
}

// MARK: - La hipoteca pegada en la nevera

@Composable
fun MortgageCard() {
    val game = Game.shared
    var ask by remember { mutableStateOf(false) }
    val share = game.mortgageShare
    Column(Modifier.fillMaxWidth().paper(hex("#fff6e0"), tilt = 1.2).padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(verticalAlignment = Alignment.Bottom) {
            T(tr(game.mortgageName).uppercase(), typewriter(15.0, true), Modifier.padding(bottom = 2.dp))
            Spacer(Modifier.weight(1f))
            T(Mortgage.words(game.mortgageTotal), chunky(18.0), maxLines = 1)
        }
        // barra de lo pagado, como una regla de papel
        Canvas(Modifier.fillMaxWidth().height(14.dp)) {
            drawRect(Ink.paperDark)
            val fw = maxOf(if (share > 0) 3.dp.toPx() else 0f, (size.width * share).toFloat())
            drawRect(Ink.green, size = Size(fw, size.height))
            for (i in 1..10) {
                val x = size.width * i / 10f
                drawRect(Ink.ink.copy(alpha = 0.25f), Offset(x - 1.dp.toPx(), 0f), Size(1.dp.toPx(), size.height))
            }
            val lw = 2.dp.toPx()
            drawRect(Ink.ink, Offset(lw / 2, lw / 2), Size(size.width - lw, size.height - lw), style = Stroke(lw))
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            T(tf("Pagado: %1 · %2", Fmt.money(game.s.mortgage), percent(share)), typewriter(12.0, true), Modifier.weight(1f), color = Ink.soft, maxLines = 1, minScale = 0.6f)
            Spacer(Modifier.size(6.dp))
            ChunkyText("Abonar", { ask = true }, color = Ink.paper, size = 14.0, radius = 10.0, enabled = game.s.cash >= 1)
        }
    }
    ActionDialog(ask, tf("Abonar a %1", nm(game.mortgageName)), null, listOf(
        DialogAction(tf("La mitad (%1)", Fmt.money(floor(game.s.cash / 2)))) { game.payMortgage(floor(game.s.cash / 2)) },
        DialogAction(tf("Todo (%1)", Fmt.money(game.s.cash))) { game.payMortgage(game.s.cash) },
    )) { ask = false }
}

private fun percent(v: Double): String {
    if (v <= 0) return "0 %"
    if (v >= 0.01) return Fmt.dec(v * 100, 1) + " %"
    // muy poquito: con los decimales que hagan falta para que se vea moverse
    val digits = min(12, (-floor(log10(v * 100))).toInt() + 1)
    return Fmt.dec(v * 100, digits) + " %"
}

// MARK: - El final: hipoteca pagada

@Composable
fun FinaleView(level: Int) {
    val game = Game.shared
    val st = game.s.stats
    var pop by remember { mutableStateOf(false) }
    LaunchedEffect(level) { Sound.fanfare(); kotlinx.coroutines.delay(200); pop = true }
    val sc by animateFloatAsState(if (pop) 2.2f else 6f, spring(dampingRatio = 0.5f, stiffness = 160f), label = "s")
    fun close() { Sound.click(); game.finale = null }
    Overlay(0.6) {
        Column(Modifier.padding(24.dp).paper(tilt = -0.8).padding(22.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Stamp("PAGADA", Ink.green, Modifier.padding(vertical = 18.dp).scale(sc).alpha(if (pop) 1f else 0f))
            T(Mortgage.name(level), chunky(32.0), align = TextAlign.Center)
            T(if (level == 0) "La casa es tuya." else "También es tuyo.", typewriter(16.0, true))
            Column(Modifier.fillMaxWidth().background(Ink.paperDark.copy(alpha = 0.5f)).padding(12.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                for ((k, v) in listOf("Días" to Fmt.num(st.days), "{Huchas} rot{as}" to Fmt.num(st.broken), "Facturas pagadas" to Fmt.num(st.billsPaid),
                    "Bancarrotas" to Fmt.num(st.bankruptcies), "Dinero ganado" to Fmt.money(st.earned))) {
                    Row(Modifier.fillMaxWidth()) { T(k, typewriter(13.0)); Spacer(Modifier.weight(1f)); T(v, typewriter(13.0, true)) }
                }
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
                T(tf("RICO DE PUEBLO %1", level + 1), chunky(22.0).hardShadow(2.0, 2.0), color = Ink.gold)
                T(tf("Todo da ×%1 de dinero para siempre", level + 2), typewriter(13.0, true))
                T(tf("Siguiente: %1", Mortgage.name(level + 1)), typewriter(13.0), color = Ink.soft)
            }
            ChunkyText("¡A seguir rompiendo!", { close() }, Modifier.fillMaxWidth(), size = 20.0, fill = true)
        }
    }
}

// MARK: - Mientras no estabas

@Composable
fun AwayView(prize: AwayPrize) {
    val game = Game.shared
    var pop by remember { mutableStateOf(false) }
    LaunchedEffect(prize.id) { pop = true }
    val sc by animateFloatAsState(if (pop) 1f else 0.4f, spring(dampingRatio = 0.45f, stiffness = 250f), label = "s")
    fun time(m: Double): String {
        if (m < 60) return tf("%1 minutos", m.toInt())
        val h = (m / 60).toInt(); val r = m.toInt() % 60
        return if (r == 0 || h >= 4) (if (h == 1) tf("%1 hora", h) else tf("%1 horas", h)) else tf("%1 h y %2 min", h, r)
    }
    Overlay(0.5) {
        Column(Modifier.padding(30.dp).paper(tilt = -0.6).padding(22.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
            T("MIENTRAS NO ESTABAS", typewriter(15.0, true))
            T(time(prize.minutes), typewriter(13.0), color = Ink.soft)
            SkinIcon(Content.playing(game.s.skin).id, 70.0)
            T(tf("%1 {huchas} rot{as}", Fmt.num(prize.cows)), chunky(22.0))
            T("+" + Fmt.money(prize.cash), chunky(40.0).hardShadow(2.0, 3.0), Modifier.scale(sc), color = Ink.green, maxLines = 1, minScale = 0.5f)
            ChunkyText("Cobrar", { game.collectAway() }, Modifier.fillMaxWidth(), size = 20.0, fill = true)
            RewardButton("Cobrar el doble", Reward.doblar, Modifier.fillMaxWidth()) { game.collectAway(double = true) }
        }
    }
}

// MARK: - Números grandes: el primer millón, los primeros mil millones…

@Composable
fun MilestoneView(k: Int) {
    val game = Game.shared
    val name = milestoneName(k)
    var pop by remember(k) { mutableStateOf(false) }
    LaunchedEffect(k) { pop = true }
    val p by animateFloatAsState(if (pop) 1f else 0f, spring(dampingRatio = 0.4f, stiffness = 200f), label = "p")
    fun close() { Sound.click(); game.milestoneShow = null }
    Overlay(0.5, { close() }) {
        Column(Modifier.padding(36.dp).paper(tilt = 0.8).padding(22.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
            T(if (name.startsWith("MIL ")) "TUS PRIMEROS" else if (L10n.lang == Lang.pt && k == 1) "SEUS PRIMEIROS" else if (L10n.lang == Lang.pt) "SEU PRIMEIRO" else "TU PRIMER", typewriter(16.0, true))
            T(name, chunky(if (k >= 3) 40.0 else 54.0).hardShadow(3.0, 4.0), Modifier.scale(0.2f + 0.8f * p).rotate(20f - 24f * p), color = Ink.gold, align = TextAlign.Center)
            T(Fmt.money(1000.0.pow(k)), typewriter(14.0, true), color = Ink.soft)
            ChunkyText("¡Más!", { close() }, Modifier.fillMaxWidth().padding(top = 8.dp), size = 20.0, fill = true)
        }
    }
}

fun Modifier.clickableNoRipple(onClick: () -> Unit): Modifier = this.clickable(null, null, onClick = onClick)
