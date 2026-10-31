package es.david.findemes.ui

import es.david.findemes.support.nm
import es.david.findemes.support.tf
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
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
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.unit.dp
import es.david.findemes.logic.BillTwist
import es.david.findemes.logic.Door
import es.david.findemes.logic.Feature
import es.david.findemes.logic.Game
import es.david.findemes.logic.achievementsReady
import es.david.findemes.logic.bestHammer
import es.david.findemes.logic.bestPart
import es.david.findemes.logic.bestSkill
import es.david.findemes.logic.doorOpen
import es.david.findemes.logic.freeScratch
import es.david.findemes.logic.freeSpins
import es.david.findemes.logic.inspection
import es.david.findemes.logic.twist
import es.david.findemes.logic.unlocked
import es.david.findemes.model.Content
import es.david.findemes.model.PigKind
import es.david.findemes.support.Fmt
import es.david.findemes.support.Ink
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

enum class HomeSheet { tree, hammers, herencia, album, bar, settings }

/** La cocina entre día y día: la factura en la nevera, la cartera y las puertas */
@Composable
fun HomeView(startSheet: HomeSheet? = null, startTab: String? = null) {
    val game = Game.shared
    var sheet by remember { mutableStateOf(startSheet) }
    var shown by remember { mutableStateOf(startSheet) }
    if (sheet != null) shown = sheet
    val close = { sheet = null }
    Box(Modifier.fillMaxSize()) {
        KitchenBackground()
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().navigationBarsPadding()
            .padding(horizontal = 18.dp).padding(top = 10.dp, bottom = 30.dp), verticalArrangement = Arrangement.spacedBy(22.dp)) {
            TopBar { sheet = HomeSheet.settings }
            LevelStrip()
            BillCard()
            MortgageCard()
            PlayButton()
            if (game.unlocked(Feature.encargos) && game.s.quests.isNotEmpty()) QuestsCard()
            Doors { sheet = it }
            game.nextBill?.let { next ->
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally)) {
                    T("Después:", typewriter(13.0, true), color = Ink.soft)
                    T(tf("%1 · %2", next.company, Fmt.money(game.billAmount(next))), typewriter(13.0), color = Ink.soft, maxLines = 1, minScale = 0.6f)
                }
            }
        }
        val bg = when (shown) {
            HomeSheet.settings -> Ink.paper
            else -> Ink.wood
        }
        SheetHost(sheet != null, close, bg) {
            when (shown) {
                HomeSheet.tree -> TreeView(close)
                HomeSheet.hammers -> HammersView(close)
                HomeSheet.herencia -> HeritageView(close)
                HomeSheet.album -> AlbumDoor(close, startTab)
                HomeSheet.bar -> BarView(close, startTab?.toIntOrNull() ?: 0)
                HomeSheet.settings -> SettingsView()
                null -> {}
            }
        }
    }
}

@Composable
private fun TopBar(onSettings: () -> Unit) {
    val game = Game.shared
    val st = game.s.stats
    Row(verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            T("FIN DE MES", chunky(34.0).hardShadow(3.0, 3.0), color = Ink.red)
            T(tf("Día %1", game.s.day) + (if (game.s.year > 0) tf(" · año %1", game.s.year + 1) else "") +
                (if (st.bankruptcies > 0) (if (st.bankruptcies == 1.0) tf(" · %1 bancarrota", 1) else tf(" · %1 bancarrotas", st.bankruptcies.toInt())) else ""),
                typewriter(13.0, true), color = Ink.soft)
        }
        ChunkyButton(onSettings, color = Ink.paper, size = 16.0, radius = 12.0) { SymIcon("gearshape.fill", 22.0, Ink.ink) }
    }
}

// MARK: la factura pegada en la nevera

@Composable
private fun BillCard() {
    val game = Game.shared
    val b = game.bill
    val amount = game.billAmount
    val left = game.daysLeft
    val can = game.s.cash >= amount
    val shake = remember { Animatable(0f) }
    val scope = rememberCoroutineScope()
    Box {
        Box(contentAlignment = Alignment.TopCenter) {
            Box(Modifier.padding(top = 26.dp).offset(x = shake.value.dp)) {
                Column(Modifier.fillMaxWidth().paper(tilt = -1.2).padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        T(b.company, typewriter(17.0, true), Modifier.weight(1f), maxLines = 1, minScale = 0.6f)
                        T("Nº ${String.format(java.util.Locale.US, "%04d", game.s.stats.billsPaid.toInt() + 1)}", typewriter(12.0))
                    }
                    T(b.concept, typewriter(14.0))
                    if (game.inspection) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            SymIcon("magnifyingglass", 14.0, Ink.red)
                            T("INSPECCIÓN DE HACIENDA · ×2", typewriter(13.0, true), color = Ink.red)
                        }
                    } else if (game.twist != BillTwist.none) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            SymIcon(game.twist.icon, 14.0, Ink.purple)
                            T(game.twist.title, typewriter(13.0, true), color = Ink.purple)
                        }
                    }
                    Box(Modifier.fillMaxWidth().height(1.5.dp).alpha(0.6f).drawBehind {
                        drawRect(Ink.ink)
                        drawLine(Ink.paper, Offset(0f, size.height / 2), Offset(size.width, size.height / 2), size.height, pathEffect = PathEffect.dashPathEffect(floatArrayOf(4.dp.toPx(), 3.dp.toPx())))
                    })
                    Row(verticalAlignment = Alignment.Bottom) {
                        T("TOTAL", typewriter(14.0, true), Modifier.padding(bottom = 6.dp))
                        Spacer(Modifier.weight(1f))
                        T(Fmt.money(amount), chunky(34.0), maxLines = 1, minScale = 0.5f)
                    }
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        T(if (left == 0) "Vence HOY" else (if (left == 1) tf("Vence en %1 día (día %2)", left, game.s.billDue) else tf("Vence en %1 días (día %2)", left, game.s.billDue)),
                            typewriter(13.0, true), Modifier.weight(1f), color = if (left == 0) Ink.red else Ink.ink, maxLines = 1, minScale = 0.7f)
                        T(tf("Tienes %1", Fmt.money(game.s.cash)), typewriter(13.0), color = if (can) Ink.green else Ink.soft, maxLines = 1, minScale = 0.7f)
                    }
                    ChunkyText(if (can) "PAGAR" else tf("Te faltan %1", Fmt.money(amount - game.s.cash)), {
                        game.payBill()
                        scope.launch { shake.animateTo(-8f, tween(50)); shake.animateTo(8f, tween(50)); shake.animateTo(0f, spring(dampingRatio = 0.5f)) }
                    }, Modifier.fillMaxWidth().padding(top = 4.dp), color = Ink.green, text = Ink.paper, size = 22.0, enabled = can, fill = true)
                }
                if (left == 0) Stamp("ÚLTIMO DÍA", modifier = Modifier.align(Alignment.TopEnd).offset((-12).dp, 36.dp))
                else if (game.inspection) Stamp("HACIENDA", modifier = Modifier.align(Alignment.TopEnd).offset((-12).dp, 36.dp))
            }
            // imán
            Box(Modifier.offset(y = 13.dp).size(26.dp).background(Ink.red, CircleShape).border(2.5.dp, Ink.ink, CircleShape))
        }
        game.autoPaid?.let { name ->
            LaunchedEffect(name) { delay(2500); game.autoPaid = null }
            Column(Modifier.align(Alignment.Center).clickableNoRipple { game.autoPaid = null }, horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Stamp("PAGADA", Ink.green)
                Box(Modifier.background(Ink.paper).padding(4.dp)) { T("$name se pagó sola al vencer", typewriter(12.0, true)) }
            }
        }
    }
}

@Composable
private fun PlayButton() {
    val game = Game.shared
    ChunkyButton({ game.startDay() }, Modifier.fillMaxWidth(), color = Ink.gold, size = 24.0, radius = 18.0) {
        Row(Modifier.weight(1f), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            SkinIcon(Content.playing(game.s.skin).id, 52.0)
            Column {
                T("A ROMPER {HUCHAS}", chunky(26.0), maxLines = 1, minScale = 0.6f)
                T(tf("con %1", nm(Content.hammers[game.s.hammer].name)), typewriter(13.0, true), Modifier.alpha(0.75f), maxLines = 1, minScale = 0.6f)
            }
        }
    }
}

// MARK: las puertas (aparecen poco a poco)

@Composable
private fun Doors(open: (HomeSheet) -> Unit) {
    val game = Game.shared
    val grid = listOf(Door.mejoras, Door.martillo, Door.album, Door.herencia).filter { game.doorOpen(it) }
    val kinds = PigKind.entries.count { game.s.bestTier >= it.minTier }
    val legacyBuy = Content.rings.any { game.ringLevel(it) < it.maxLevel && game.s.legacy >= it.cost(game.ringLevel(it)) }
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        for (row in grid.chunked(2)) {
            Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                for (d in row) {
                    val m = Modifier.weight(1f)
                    when (d) {
                        Door.mejoras -> DoorCard(d, "Árbol de mejoras", game.bestSkill(Content.skills) != null, m) { open(HomeSheet.tree) }
                        Door.martillo -> DoorCard(d, Content.hammers[game.s.hammer].name, game.bestHammer != null || ((game.s.stats.billsPaid >= 3 || game.s.stats.bankruptcies > 0) && game.bestPart != null), m) { open(HomeSheet.hammers) }
                        Door.album -> DoorCard(d, tf("%1 {huchas} · %2 logros", kinds, game.s.achievements.size), game.achievementsReady > 0 || game.s.pendingChests.isNotEmpty(), m) { open(HomeSheet.album) }
                        Door.herencia -> DoorCard(d, tf("%1 puntos", Fmt.num(game.s.legacy)), legacyBuy, m) { open(HomeSheet.herencia) }
                        Door.bar -> {}
                    }
                }
                if (row.size == 1) Spacer(Modifier.weight(1f))
            }
        }
        if (game.doorOpen(Door.bar)) DoorCard(Door.bar, "Tragaperras y rasca", game.freeSpins > 0 || game.freeScratch) { open(HomeSheet.bar) }
    }
}
