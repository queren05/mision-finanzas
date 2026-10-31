package es.david.findemes.ui

import es.david.findemes.support.nm
import es.david.findemes.support.tf
import es.david.findemes.money.Money
import es.david.findemes.money.Reward
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.spring
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameMillis
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.unit.dp
import es.david.findemes.logic.Game
import es.david.findemes.logic.ScratchCard
import es.david.findemes.logic.SpinResult
import es.david.findemes.logic.Sound
import es.david.findemes.logic.bestPart
import es.david.findemes.logic.buyPart
import es.david.findemes.logic.buyPartMax
import es.david.findemes.logic.buyScratch
import es.david.findemes.logic.claimScratch
import es.david.findemes.logic.dailySpins
import es.david.findemes.logic.freeScratch
import es.david.findemes.logic.freeSpins
import es.david.findemes.logic.partCost
import es.david.findemes.logic.partLevel
import es.david.findemes.logic.pigWorth
import es.david.findemes.logic.spin
import es.david.findemes.model.PartDef
import es.david.findemes.model.PigKind
import es.david.findemes.model.Rarity
import es.david.findemes.model.ScratchPrize
import es.david.findemes.model.SlotSymbol
import es.david.findemes.support.Fmt
import es.david.findemes.support.Ink
import es.david.findemes.support.filling
import es.david.findemes.support.hex
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

// MARK: - Mejoras del martillo (en la ferretería, encima de los martillos)

@Composable
fun PartRow(def: PartDef) {
    val game = Game.shared
    val l = game.partLevel(def)
    val maxed = l >= def.maxLevel
    val cost = game.partCost(def)
    Box {
        Row(Modifier.fillMaxWidth().paper().padding(10.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            ItemImage("p_" + def.id, Modifier.size(58.dp))
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    T(def.name, chunky(17.0)); T("$l/${def.maxLevel}", typewriter(12.0, true), Modifier.padding(bottom = 2.dp), color = Ink.soft)
                }
                T(tf("%1 por nivel", def.desc.filling(Fmt.num(def.per))), typewriter(12.0), color = Ink.soft)
                if (l > 0) T(tf("Ahora: %1", def.desc.filling(Fmt.num(def.value(l)))), typewriter(12.0, true), color = Ink.green)
                Row(Modifier.padding(top = 4.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    ChunkyText(if (maxed) "MÁX." else Fmt.money(cost), { game.buyPart(def) }, Modifier.weight(1f), size = 15.0, radius = 10.0, enabled = !(maxed || game.s.cash < cost), fill = true)
                    ChunkyText("Máx.", { game.buyPartMax(def) }, color = Ink.paper, size = 15.0, radius = 10.0, enabled = !(maxed || game.s.cash < cost))
                }
            }
        }
        if (game.bestPart == def.id) GoldPin(Modifier.offset((-6).dp, (-8).dp))
    }
}

// MARK: - La feria: tragaperras (tres tiradas gratis al día) y rasca (uno gratis al día)

@Composable
fun BarView(onClose: () -> Unit, startTab: Int = 0) {
    val game = Game.shared
    var tab by remember { mutableIntStateOf(startTab) }
    Column(Modifier.fillMaxSize().background(hex("#4a1f2a")), horizontalAlignment = Alignment.CenterHorizontally) {
        SheetHeader("La feria", "Tiradas gratis cada día", onClose)
        CashPill(Fmt.money(game.s.cash), modifier = Modifier.padding(bottom = 10.dp))
        Row(Modifier.padding(horizontal = 18.dp).padding(bottom = 8.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            for ((i, t) in listOf(tf("Tragaperras · %1", game.freeSpins), if (game.freeScratch) "Rasca · 1" else "Rasca").withIndex()) {
                ChunkyText(t, { Sound.click(); tab = i }, Modifier.weight(1f), color = if (tab == i) Ink.gold else Ink.paper, size = 16.0, radius = 12.0, fill = true)
            }
        }
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).navigationBarsPadding()) {
            if (tab == 0) SlotMachineView() else ScratchView()
        }
    }
}

@Composable
fun SlotSymbolView(symbol: SlotSymbol, size: Double = 76.0, modifier: Modifier = Modifier) {
    Box(modifier.size(size.dp), contentAlignment = Alignment.Center) {
        if (symbol == SlotSymbol.cerdo) KindIcon(PigKind.normal, size * 0.84)
        else ItemImage(symbol.image, Modifier.fillMaxSize().padding((size * 0.08).dp))
    }
}

@Composable
fun SlotMachineView() {
    val game = Game.shared
    val reels = remember { mutableStateListOf(SlotSymbol.corona, SlotSymbol.corona, SlotSymbol.corona) }
    val spinning = remember { mutableStateListOf(false, false, false) }
    var result by remember { mutableStateOf<SpinResult?>(null) }
    var flash by remember { mutableIntStateOf(0) }
    var clock by remember { mutableLongStateOf(0L) }
    val scope = rememberCoroutineScope()
    val busy = spinning.any { it }
    val unit = game.pigWorth * 5
    LaunchedEffect(busy) { while (busy) { withFrameMillis { clock = it } } }

    fun pull(extra: Boolean = false) {
        val r = game.spin(extra) ?: return
        Sound.swing()
        result = r
        for (i in 0 until 3) spinning[i] = true
        // los rodillos paran uno detrás de otro
        for (i in 0 until 3) scope.launch {
            delay((700 + i * 450).toLong())
            reels[i] = r.reels[i]
            spinning[i] = false
            Sound.click()
            if (i == 2) {
                flash += 1
                if (r.chest != null || r.won >= game.pigWorth * 150) Sound.fanfare()
                else if (r.won > 0) Sound.till()
                else Sound.denied()
            }
        }
    }

    Column(Modifier.padding(horizontal = 18.dp, vertical = 6.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp)) {
        // la máquina
        Column(Modifier.fillMaxWidth().outlined(18.0, hex("#8a1f2a"), shadow = 6.0).padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
            T("TRAGAPERRAS", chunky(26.0).hardShadow(2.0, 2.0), color = Ink.gold)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                for (i in 0 until 3) {
                    Box(Modifier.width(86.dp).height(96.dp).background(Ink.paper).clipToBounds().border(3.dp, Ink.ink), contentAlignment = Alignment.Center) {
                        if (spinning[i]) {
                            val k = (clock / 70).toInt() + i * 2
                            SlotSymbolView(SlotSymbol.entries[k % SlotSymbol.entries.size], modifier = Modifier.blur(1.5.dp))
                        } else {
                            AnimatedContent(reels[i], transitionSpec = { slideInVertically(spring(dampingRatio = 0.6f, stiffness = 600f)) { -it } togetherWith fadeOut() }, label = "r") { s ->
                                SlotSymbolView(s)
                            }
                        }
                    }
                }
            }
            Box(Modifier.height(26.dp), contentAlignment = Alignment.Center) {
                AnimatedContent(flash, transitionSpec = { (scaleIn() + fadeIn()) togetherWith fadeOut() }, label = "f") { _ ->
                    val r = result
                    if (r != null && !busy) {
                        if (r.won > 0) T("¡+${Fmt.money(r.won)}!" + (if (r.chest != null) tf(" y un sobre %1", nm(r.chest.title)) else ""), chunky(20.0), color = Ink.gold, maxLines = 1, minScale = 0.5f)
                        else T("Nada", chunky(20.0), color = hex("#ff9a8a"))
                    } else T(if (busy) "…" else " ", chunky(20.0), color = Ink.paper)
                }
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            for (i in 0 until dailySpins) SymIcon(if (i < game.freeSpins) "ticket.fill" else "ticket", 28.0, if (i < game.freeSpins) Ink.gold else Ink.paper.copy(alpha = 0.4f))
        }
        if (game.freeSpins > 0 || busy) ChunkyText("¡TIRAR!", { pull() }, Modifier.fillMaxWidth(), color = Ink.red, text = Ink.paper, size = 24.0, enabled = !(busy || game.freeSpins == 0 || game.inRun), fill = true)
        else RewardButton(tf("Tirada extra · %1", Money.usesLeft(Reward.tirada)), Reward.tirada, Modifier.fillMaxWidth(), color = Ink.gold, size = 22.0) { pull(extra = true) }

        // la tabla de premios
        Column(Modifier.fillMaxWidth().paper().padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            T("PREMIOS", chunky(18.0))
            for (s in SlotSymbol.entries.reversed()) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    repeat(3) { SlotSymbolView(s, 30.0) }
                    Spacer(Modifier.weight(1f))
                    T((if (s == SlotSymbol.corona) tf("%1 + sobre legendario", Fmt.money(unit * s.pays)) else if (s == SlotSymbol.anillo) tf("%1 + sobre épico", Fmt.money(unit * s.pays)) else Fmt.money(unit * s.pays)), typewriter(13.0, true), maxLines = 1, minScale = 0.6f)
                }
            }
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                repeat(2) { SlotSymbolView(SlotSymbol.cerdo, 30.0) }
                Spacer(Modifier.weight(1f))
                T(Fmt.money(unit), typewriter(13.0, true))
            }
        }
    }
}

@Composable
fun ScratchView() {
    val game = Game.shared
    var card by remember { mutableStateOf<ScratchCard?>(null) }
    var open by remember { mutableStateOf(setOf<Int>()) }
    var claimed by remember { mutableStateOf<String?>(null) }

    fun finish() {
        val c = card ?: return
        if (c.prize != null) claimed = game.claimScratch(c.prize) else Sound.denied()
    }
    fun reveal(i: Int) {
        if (card == null || i in open) return
        Sound.pop()
        open = open + i
        if (open.size == 9) finish()
    }

    Column(Modifier.padding(horizontal = 18.dp, vertical = 6.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        card?.let { c ->
            Column(Modifier.fillMaxWidth().paper(hex("#fff6c8")).padding(14.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
                T("RASCA Y GANA", chunky(24.0))
                for (row in 0 until 3) {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        for (col in 0 until 3) {
                            val i = row * 3 + col
                            val shown = i in open
                            val p = c.cells[i]
                            val win = shown && p != null && p == c.prize && open.size == 9
                            Box(Modifier.weight(1f).aspectRatio(1f).background(if (win) hex("#d9f2c8") else Ink.paper).border(2.5.dp, Ink.ink).clickable { reveal(i) }, contentAlignment = Alignment.Center) {
                                if (p != null) Box(Modifier.fillMaxSize().padding(10.dp)) { PrizeIcon(p) } else SymIcon("xmark", 30.0, Ink.soft)
                                if (!shown) {
                                    Box(Modifier.fillMaxSize().padding(2.5.dp).background(hex("#b9b3ad")), contentAlignment = Alignment.Center) { SymIcon("questionmark", 30.0, hex("#8a847d")) }
                                }
                            }
                        }
                    }
                }
                if (open.size == 9) {
                    T(if (c.prize == null) "Esta vez nada" else "¡${claimed ?: c.prize.title}!", chunky(22.0), color = if (c.prize == null) Ink.soft else Ink.green)
                } else {
                    ChunkyText("Rascar todo", { Sound.pop(); open = (0 until 9).toSet(); finish() }, Modifier.fillMaxWidth(), color = Ink.paper, size = 16.0, radius = 10.0, fill = true)
                }
            }
        }
        if ((card == null || open.size == 9) && game.freeScratch) {
            ChunkyText("Rascar", {
                val c = game.buyScratch()
                if (c != null) { Sound.click(); card = c; open = emptySet(); claimed = null }
            }, Modifier.fillMaxWidth(), size = 20.0, fill = true)
        }
        Column(Modifier.fillMaxWidth().paper().padding(14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            T("PREMIOS", chunky(18.0))
            for (p in ScratchPrize.entries.reversed()) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Box(Modifier.size(30.dp)) { PrizeIcon(p) }
                    T(p.title, typewriter(13.0, true))
                }
            }
        }
    }
}

@Composable
private fun PrizeIcon(p: ScratchPrize) {
    when (p) {
        ScratchPrize.calderilla -> ItemImage("c_loot", Modifier.fillMaxSize())
        ScratchPrize.fajo, ScratchPrize.herencia -> ItemImage("billete", Modifier.fillMaxSize())
        ScratchPrize.sobreRaro -> EnvelopeArt(Rarity.rara, Modifier.fillMaxSize())
        ScratchPrize.sobreEpico -> EnvelopeArt(Rarity.epica, Modifier.fillMaxSize())
        ScratchPrize.sobreLegendario -> EnvelopeArt(Rarity.legendaria, Modifier.fillMaxSize())
    }
}
