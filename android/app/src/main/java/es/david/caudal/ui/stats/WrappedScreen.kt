package es.david.caudal.ui.stats

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import es.david.caudal.R
import es.david.caudal.core.Day
import es.david.caudal.core.Money
import es.david.caudal.domain.calc.DateRange
import es.david.caudal.domain.calc.Insights
import es.david.caudal.domain.calc.Ledger
import es.david.caudal.domain.model.TxType
import es.david.caudal.ui.common.AmountText
import es.david.caudal.ui.common.Confetti
import es.david.caudal.ui.common.FinanceViewModel
import es.david.caudal.ui.common.Gotita
import es.david.caudal.ui.common.LocalFmt
import es.david.caudal.ui.common.LocalMascot
import es.david.caudal.ui.common.Mood
import es.david.caudal.ui.common.appear
import es.david.caudal.ui.common.breathe
import es.david.caudal.ui.common.pressable
import es.david.caudal.ui.common.rememberHaptics
import es.david.caudal.ui.theme.CaudalTheme
import es.david.caudal.ui.theme.LocalMotion
import kotlinx.coroutines.launch
import kotlin.math.abs
import kotlin.math.roundToInt

/** lo que se cuenta en las historias de un mes */
private data class MonthStory(
    val month: String,
    val spent: Double,
    val prevSpent: Double,
    val earned: Double,
    val topCat: Pair<String, String>?, // emoji, nombre
    val topCatTotal: Double,
    val topDay: Pair<String, Double>?,
    val shop: Triple<String, Int, Double>?,
    val streak: Int,
    val loved: Int,
    val regret: Int,
)

private fun story(l: Ledger, key: String): MonthStory {
    val start = "$key-01"
    val r = DateRange(start, Day.addDays(start, Day.daysInMonth(start) - 1))
    val prevStart = Day.addMonths(start, -1)
    val prev = DateRange(prevStart, Day.addDays(prevStart, Day.daysInMonth(prevStart) - 1))
    val expenses = l.txs(r).filter { it.type == TxType.EXPENSE && !it.excluded }
    val cats = l.byCategory(r)
    val top = cats.firstOrNull()
    val days = Insights.spentByDay(l, r)
    val topDay = days.maxByOrNull { it.value }
    val shop = expenses.filter { it.title.isNotBlank() }.groupBy { it.title.trim().lowercase() }
        .maxByOrNull { it.value.size }?.let { (_, v) -> Triple(v.first().title.trim(), v.size, v.sumOf { Money.fromCents(it.amount) }) }
        ?.takeIf { it.second >= 2 }
    // racha más larga de días apuntando dentro del mes
    val logged = l.txs(r).filter { it.type != TxType.ADJUST && it.recurringId == null }.map { it.date }.toSortedSet()
    var best = 0
    var run = 0
    var last: String? = null
    for (d in logged) { run = if (last != null && Day.addDays(last, 1) == d) run + 1 else 1; best = maxOf(best, run); last = d }
    return MonthStory(
        key, l.spent(r), l.spent(prev), l.earned(r),
        top?.let { it.cat.icon to it.cat.name }, top?.total ?: 0.0,
        topDay?.let { it.key to it.value }, shop, best,
        expenses.count { it.mood == "😍" }, expenses.count { it.mood == "😩" },
    )
}

/** «Tu mes en Caudal»: historias a pantalla completa, como un Wrapped */
@Composable
fun WrappedScreen(month: String?, nav: NavController) {
    val vm: FinanceViewModel = hiltViewModel()
    val ledger by vm.ledger.collectAsStateWithLifecycle()
    val l = ledger ?: return
    val key = month ?: Day.monthKey(Day.today)
    val s = remember(l, key) { story(l, key) }
    val f = LocalFmt.current
    val c = CaudalTheme.colors
    val h = rememberHaptics()
    val motion = LocalMotion.current
    val scope = rememberCoroutineScope()

    // las historias que hay este mes
    val pages = remember(s) {
        buildList {
            add("intro")
            if (s.spent <= 0) { add("vacio"); return@buildList }
            add("gastado")
            if (s.topCat != null) add("categoria")
            if (s.topDay != null) add("dia")
            if (s.shop != null) add("sitio")
            add("racha")
            add("balance")
            if (s.loved + s.regret > 0) add("valio")
            add("adios")
        }
    }
    val pager = rememberPagerState { pages.size }
    val progress = remember { Animatable(0f) }
    var paused by remember { mutableStateOf(false) }

    // cada historia dura ~5 s y pasa sola a la siguiente (salvo con «Reducir movimiento» o mantenida pulsada)
    LaunchedEffect(pager.currentPage, paused) {
        if (paused || !motion) return@LaunchedEffect
        if (progress.value >= 1f) progress.snapTo(0f)
        progress.animateTo(1f, tween(((1f - progress.value) * 5200).toInt(), easing = LinearEasing))
        if (pager.currentPage < pages.lastIndex) { progress.snapTo(0f); pager.animateScrollToPage(pager.currentPage + 1) }
    }
    LaunchedEffect(pager.currentPage) { progress.snapTo(0f); h.select() }

    val tints = listOf(c.accent, c.transfer, c.warning, c.income, c.negative, c.accent, c.transfer, c.income, c.accent, c.warning)
    val prevLabel = stringResource(R.string.wr_prev)
    val nextLabel = stringResource(R.string.wr_next)
    fun go(k: Int) = scope.launch {
        val t = (pager.currentPage + k).coerceIn(0, pages.lastIndex)
        if (t == pager.currentPage && k > 0) { nav.popBackStack(); return@launch }
        progress.snapTo(0f); pager.animateScrollToPage(t)
    }

    Box(Modifier.fillMaxSize().background(Color.Black)) {
        HorizontalPager(pager, Modifier.fillMaxSize()) { i ->
            val tint = tints[i % tints.size]
            Box(
                Modifier
                    .fillMaxSize()
                    .background(Brush.linearGradient(listOf(lerp(tint, Color.White, 0.25f), lerp(tint, Color(0xFF1A1320), 0.55f))))
                    .pointerInput(i) {
                        detectTapGestures(
                            onPress = { paused = true; tryAwaitRelease(); paused = false },
                            onTap = { o -> if (o.x < size.width / 3f) go(-1) else go(1) },
                        )
                    }
                    .semantics { customActions = listOf(CustomAccessibilityAction(prevLabel) { go(-1); true }, CustomAccessibilityAction(nextLabel) { go(1); true }) },
            ) {
                Page(pages[i], s, f.month("$key-01"), i == pager.currentPage)
            }
        }

        // barras de progreso y cerrar
        Column(Modifier.fillMaxWidth().safeDrawingPadding().padding(horizontal = 12.dp, vertical = 8.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                pages.indices.forEach { i ->
                    val p = when {
                        i < pager.currentPage -> 1f
                        i == pager.currentPage -> if (motion) progress.value else 1f
                        else -> 0f
                    }
                    Box(Modifier.weight(1f).height(4.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.3f))) {
                        Box(Modifier.fillMaxWidth(p).fillMaxHeight().clip(CircleShape).background(Color.White))
                    }
                }
            }
            Row(Modifier.fillMaxWidth().padding(top = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(
                    stringResource(R.string.wr_title), style = MaterialTheme.typography.labelLarge, color = Color.White, modifier = Modifier.weight(1f),
                )
                val pageDesc = stringResource(R.string.wr_progress_desc, pager.currentPage + 1, pages.size)
                Text("${pager.currentPage + 1}/${pages.size}", style = MaterialTheme.typography.labelMedium, color = Color.White.copy(alpha = 0.8f), modifier = Modifier.semantics { contentDescription = pageDesc })
                Spacer(Modifier.width(8.dp))
                Box(
                    Modifier.size(44.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.2f)).pressable(0.85f) { nav.popBackStack() },
                    contentAlignment = Alignment.Center,
                ) { Icon(Icons.Filled.Close, stringResource(R.string.close), tint = Color.White) }
            }
        }
    }
}

@Composable
private fun Page(id: String, s: MonthStory, monthName: String, current: Boolean) {
    val f = LocalFmt.current
    val c = CaudalTheme.colors
    val white = Color.White
    val mascot = LocalMascot.current
    Column(
        Modifier.fillMaxSize().safeDrawingPadding().padding(horizontal = 28.dp, vertical = 90.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        if (!current) return@Column
        @Composable fun kicker(t: String) = Text(t, style = MaterialTheme.typography.titleMedium, color = white.copy(alpha = 0.85f), textAlign = TextAlign.Center, modifier = Modifier.appear(0))
        @Composable fun big(t: String) = Text(t, style = MaterialTheme.typography.displayMedium, color = white, textAlign = TextAlign.Center, modifier = Modifier.appear(1))
        @Composable fun body(t: String) = Text(t, style = MaterialTheme.typography.titleMedium, color = white, textAlign = TextAlign.Center, modifier = Modifier.appear(3))
        @Composable fun gotita(m: Mood) { if (mascot) Gotita(m, 140.dp, color = white, modifier = Modifier.appear(2).breathe()) }
        @Composable fun emoji(e: String) = Text(e, fontSize = 96.sp, modifier = Modifier.appear(1).breathe(0.06f))

        when (id) {
            "intro" -> { kicker(stringResource(R.string.wr_intro_kicker)); big(monthName); gotita(Mood.HAPPY); body(stringResource(R.string.wr_intro_text)) }
            "vacio" -> { gotita(Mood.SLEEPY); body(stringResource(R.string.wr_empty)) }
            "gastado" -> {
                kicker(stringResource(R.string.wr_spent_kicker))
                AmountText(s.spent, style = MaterialTheme.typography.displayLarge, color = white, rolling = true, modifier = Modifier.appear(1))
                val pct = if (s.prevSpent > 0) (s.spent / s.prevSpent - 1) * 100 else null
                gotita(if (pct == null) Mood.WINK else if (pct <= -3) Mood.LOVE else if (pct >= 3) Mood.WOW else Mood.HAPPY)
                body(
                    when {
                        pct == null -> stringResource(R.string.wr_spent_first)
                        pct <= -3 -> stringResource(R.string.wr_spent_less, abs(pct).roundToInt().toString())
                        pct >= 3 -> stringResource(R.string.wr_spent_more, abs(pct).roundToInt().toString())
                        else -> stringResource(R.string.wr_spent_same)
                    },
                )
            }
            "categoria" -> {
                kicker(stringResource(R.string.wr_top_kicker))
                emoji(s.topCat!!.first)
                big(s.topCat.second)
                AmountText(s.topCatTotal, style = MaterialTheme.typography.headlineMedium, color = white, rolling = true, modifier = Modifier.appear(2))
                body(stringResource(R.string.wr_top_share, (s.topCatTotal / s.spent.coerceAtLeast(0.01) * 100).roundToInt().toString()))
            }
            "dia" -> {
                kicker(stringResource(R.string.wr_day_kicker))
                emoji("📆")
                big(f.dayLong(s.topDay!!.first))
                body(stringResource(R.string.wr_day_text, f.money(s.topDay.second)))
            }
            "sitio" -> {
                kicker(stringResource(R.string.wr_shop_kicker))
                emoji("📍")
                big(s.shop!!.first)
                body(stringResource(R.string.wr_shop_text, s.shop.second, f.money(s.shop.third)))
            }
            "racha" -> {
                kicker(stringResource(R.string.wr_streak_kicker))
                emoji("🔥")
                body(if (s.streak > 0) stringResource(R.string.wr_streak_days, s.streak) else stringResource(R.string.wr_streak_zero))
            }
            "balance" -> {
                kicker(stringResource(R.string.wr_saved_kicker))
                val diff = s.earned - s.spent
                Row(Modifier.fillMaxWidth().appear(1), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Bubble(Modifier.weight(1f), stringResource(R.string.wr_in), s.earned)
                    Bubble(Modifier.weight(1f), stringResource(R.string.wr_out), s.spent)
                }
                gotita(if (diff >= 0) Mood.LOVE else Mood.SAD)
                body(if (diff >= 0) stringResource(R.string.wr_saved_good, f.money(diff)) else stringResource(R.string.wr_saved_bad, f.money(-diff)))
            }
            "valio" -> {
                kicker(stringResource(R.string.wr_mood_kicker))
                Row(Modifier.appear(1), horizontalArrangement = Arrangement.spacedBy(24.dp)) {
                    Text("😍 ${s.loved}", fontSize = 44.sp, color = white)
                    Text("😩 ${s.regret}", fontSize = 44.sp, color = white)
                }
                body(stringResource(R.string.wr_mood_text, s.loved, s.regret))
            }
            "adios" -> { gotita(Mood.LOVE); big(stringResource(R.string.wr_bye_kicker)); body(stringResource(R.string.wr_bye_text)) }
        }
    }
    if (id == "adios" && current) Confetti(id, listOf(white, c.accent, c.warning, c.income, c.transfer))
}

@Composable
private fun Bubble(modifier: Modifier, label: String, v: Double) {
    Column(
        modifier.clip(RoundedCornerShape(24.dp)).background(Color.White.copy(alpha = 0.18f)).padding(16.dp).semantics(mergeDescendants = true) {},
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(label, style = MaterialTheme.typography.labelLarge, color = Color.White.copy(alpha = 0.85f))
        AmountText(v, style = MaterialTheme.typography.titleLarge, color = Color.White, rolling = true)
    }
}
