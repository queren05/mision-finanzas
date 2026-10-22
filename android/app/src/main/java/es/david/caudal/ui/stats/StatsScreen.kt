package es.david.caudal.ui.stats

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
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
import es.david.caudal.domain.model.CatKind
import es.david.caudal.domain.model.TxType
import es.david.caudal.ui.charts.Donut
import es.david.caudal.ui.charts.Slice
import es.david.caudal.ui.common.AmountText
import es.david.caudal.ui.common.Card
import es.david.caudal.ui.common.CircleIconButton
import es.david.caudal.ui.common.EmptyState
import es.david.caudal.ui.common.FinanceViewModel
import es.david.caudal.ui.common.Gotita
import es.david.caudal.ui.common.LocalFmt
import es.david.caudal.ui.common.LocalMascot
import es.david.caudal.ui.common.Mood
import es.david.caudal.ui.common.ProgressBar
import es.david.caudal.ui.common.RowDivider
import es.david.caudal.ui.common.ScreenScaffold
import es.david.caudal.ui.common.SectionHeader
import es.david.caudal.ui.common.SegmentedPills
import es.david.caudal.ui.common.appear
import es.david.caudal.ui.common.budgetColor
import es.david.caudal.ui.common.pressable
import es.david.caudal.ui.common.rememberHaptics
import es.david.caudal.ui.nav.WrappedRoute
import es.david.caudal.ui.theme.CaudalTheme
import es.david.caudal.ui.theme.LocalMotion
import es.david.caudal.ui.theme.hexColor
import kotlin.math.max

/** Análisis del mes (financiero): indicadores, historias, previsión, en qué se va el dinero, 6 meses, presupuestos y conceptos */
@Composable
fun StatsScreen(nav: NavController) {
    val vm: FinanceViewModel = hiltViewModel()
    val ledger by vm.ledger.collectAsStateWithLifecycle()
    val l = ledger ?: return
    val f = LocalFmt.current
    val h = rememberHaptics()
    var start by rememberSaveable { mutableStateOf(l.periodStart(Day.today)) }
    var showIncome by rememberSaveable { mutableStateOf(false) }
    var selectedCat by remember { mutableStateOf<String?>(null) }
    val range = l.periodRange(start)
    val isCurrent = Day.today in range

    ScreenScaffold(title = stringResource(R.string.analysis), onBack = { nav.popBackStack() }) { pad ->
        LazyColumn(
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = pad.calculateTopPadding(), bottom = 60.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            item {
                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.appear(0)) {
                    CircleIconButton(Icons.AutoMirrored.Filled.KeyboardArrowLeft, stringResource(R.string.prev_month)) { h.select(); start = Day.addMonths(start, -1); selectedCat = null }
                    AnimatedContent(f.monthYear(start), Modifier.weight(1f), transitionSpec = { fadeIn() togetherWith fadeOut() }, label = "mes") { t ->
                        Text(t, style = MaterialTheme.typography.titleLarge, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
                    }
                    Box(Modifier.alpha(if (range.end < Day.today) 1f else 0.35f)) {
                        CircleIconButton(Icons.AutoMirrored.Filled.KeyboardArrowRight, stringResource(R.string.next_month)) {
                            if (range.end < Day.today) { h.select(); start = Day.addMonths(start, 1); selectedCat = null }
                        }
                    }
                }
            }
            item { Box(Modifier.appear(1)) { Kpis(l, range) } }
            item { Box(Modifier.appear(2)) { WrappedCard(f.month(start)) { h.tap(); nav.navigate(WrappedRoute(Day.monthKey(start))) } } }
            if (isCurrent) item { Box(Modifier.appear(3)) { ForecastCard(l) } }
            item {
                Box(Modifier.appear(4)) {
                    CategoriesDonut(l, range, showIncome, selectedCat, onKind = { showIncome = it; selectedCat = null }, onSelect = { h.select(); selectedCat = it })
                }
            }
            item { Box(Modifier.appear(5)) { MonthsChart(l, start) } }
            item { Box(Modifier.appear(6)) { Budgets(l, range) } }
            item { Box(Modifier.appear(7)) { TopConcepts(l, range) } }
            if (l.data.txs.isEmpty()) item { EmptyState(stringResource(R.string.nothing_in_period)) }
        }
    }
}

// MARK: indicadores

@Composable
private fun Kpis(l: Ledger, r: DateRange) {
    val f = LocalFmt.current
    val c = CaudalTheme.colors
    val spent = l.spent(r)
    val earned = l.earned(r)
    val days = (Day.daysBetween(r.start, minOf(Day.today, r.end)) + 1).coerceIn(1, 31)
    val saving = Ledger.savingPct(earned, spent)
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Kpi(Modifier.weight(1f), "💸", stringResource(R.string.spent), f.money(spent), c.negative)
            Kpi(Modifier.weight(1f), "💰", stringResource(R.string.earned), f.money(earned), c.income)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Kpi(Modifier.weight(1f), "🐷", stringResource(R.string.saving), saving?.let { f.pct(it) } ?: "—", if ((saving ?: 0.0) >= 0) c.income else c.negative)
            Kpi(Modifier.weight(1f), "☕", stringResource(R.string.daily_avg), f.money(spent / days), c.accent)
        }
    }
}

/** tarjetita de color con un emoji, el texto y el valor */
@Composable
private fun Kpi(modifier: Modifier, emoji: String, label: String, value: String, tint: Color) {
    val c = CaudalTheme.colors
    Column(
        modifier
            .clip(RoundedCornerShape(24.dp))
            .background(Brush.linearGradient(listOf(tint.copy(alpha = 0.22f), c.card)))
            .border(1.dp, c.hairline, RoundedCornerShape(24.dp))
            .padding(16.dp)
            .semantics(mergeDescendants = true) {},
    ) {
        Box(Modifier.size(38.dp).clip(RoundedCornerShape(12.dp)).background(tint.copy(alpha = 0.22f)), contentAlignment = Alignment.Center) { Text(emoji, fontSize = 20.sp) }
        Spacer(Modifier.height(10.dp))
        Text(label, style = MaterialTheme.typography.labelMedium, color = c.textDim)
        es.david.caudal.ui.common.RollingText(value, MaterialTheme.typography.titleLarge.copy(fontFeatureSettings = "tnum"), c.text)
    }
}

// MARK: historias y previsión

@Composable
private fun WrappedCard(month: String, onClick: () -> Unit) {
    val stops = listOf(Color(0xFFFF8FA3), Color(0xFFB9A4FF), Color(0xFF8FC8FF))
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(26.dp))
            .pressable(0.97f, onClick = onClick)
            .background(Brush.linearGradient(stops))
            .heightIn(min = 88.dp)
            .padding(horizontal = 18.dp, vertical = 14.dp)
            .semantics(mergeDescendants = true) {},
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (LocalMascot.current) { Gotita(Mood.LOVE, 60.dp, color = Color.White); Spacer(Modifier.width(12.dp)) }
        Column(Modifier.weight(1f)) {
            Text(stringResource(R.string.st_wrapped_title), style = MaterialTheme.typography.titleMedium, color = Color(0xFF1A1320))
            Text(stringResource(R.string.st_wrapped_sub, month.lowercase()), style = MaterialTheme.typography.bodySmall, color = Color(0xFF1A1320).copy(alpha = 0.75f))
        }
        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = Color(0xFF1A1320))
    }
}

@Composable
private fun ForecastCard(l: Ledger) {
    val f = LocalFmt.current
    val c = CaudalTheme.colors
    val fc = remember(l) { Insights.forecast(l) }
    val budget = l.totalBudget
    Card {
        SectionHeader(stringResource(R.string.st_forecast_title), emoji = "🔮")
        Spacer(Modifier.height(8.dp))
        if (fc == null) {
            Text(stringResource(R.string.st_forecast_early), style = MaterialTheme.typography.bodyMedium, color = c.textDim)
        } else {
            val over = budget > 0 && fc > budget
            Text(stringResource(R.string.st_forecast_line, f.money(fc)), style = MaterialTheme.typography.titleMedium, color = if (over) c.negative else c.text)
            if (budget > 0) {
                Text(stringResource(R.string.st_forecast_budget, f.money(budget)), style = MaterialTheme.typography.bodySmall, color = c.textDim)
                Spacer(Modifier.height(10.dp))
                ProgressBar(fc / budget, budgetColor(fc, budget, c.income, c.warning, c.negative))
            }
        }
    }
}

// MARK: en qué se va el dinero

@Composable
private fun CategoriesDonut(l: Ledger, r: DateRange, income: Boolean, selected: String?, onKind: (Boolean) -> Unit, onSelect: (String?) -> Unit) {
    val f = LocalFmt.current
    val c = CaudalTheme.colors
    val cats = remember(l, r, income) { l.byCategory(r, if (income) TxType.INCOME else TxType.EXPENSE) }
    val total = cats.sumOf { it.total }
    val sel = cats.firstOrNull { it.cat.id == selected }
    val noCat = stringResource(R.string.no_category)
    Card {
        SegmentedPills(listOf(stringResource(R.string.expenses), stringResource(R.string.incomes)), if (income) 1 else 0, { onKind(it == 1) }, colors = listOf(c.negative, c.income))
        Spacer(Modifier.height(16.dp))
        if (cats.isEmpty()) {
            EmptyState(stringResource(R.string.nothing_in_period), mood = Mood.SLEEPY)
            return@Card
        }
        Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
            Donut(
                cats.map { Slice(it.total, hexColor(it.cat.color)) }, size = 236.dp, thickness = 34.dp,
                highlighted = cats.indexOfFirst { it.cat.id == selected }.takeIf { it >= 0 },
                description = stringResource(R.string.where_you_spend),
                onTap = { i -> onSelect(i?.let { cats[it].cat.id }) },
            )
            AnimatedContent(sel, transitionSpec = { fadeIn() togetherWith fadeOut() }, label = "centro") { s ->
                Column(Modifier.width(136.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(s?.cat?.icon ?: "🍩", fontSize = 28.sp)
                    Text(s?.let { it.cat.name.ifEmpty { noCat } } ?: stringResource(R.string.st_total_desc), style = MaterialTheme.typography.labelLarge, color = c.textDim, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    AmountText(s?.total ?: total, style = MaterialTheme.typography.titleLarge)
                    if (s != null) Text(f.num(s.total / max(total, 0.01) * 100) + " %", style = MaterialTheme.typography.labelMedium, color = c.textDim)
                }
            }
        }
        Spacer(Modifier.height(14.dp))
        val top = cats.first().total.coerceAtLeast(0.01)
        cats.forEachIndexed { i, ct ->
            val name = ct.cat.name.ifEmpty { noCat }
            val desc = stringResource(R.string.category_share, name, f.money(ct.total), f.num(ct.total / max(total, 0.01) * 100))
            Column(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .pressable(0.98f) { onSelect(if (selected == ct.cat.id) null else ct.cat.id) }
                    .semantics(mergeDescendants = true) { contentDescription = desc }
                    .padding(vertical = 8.dp, horizontal = 4.dp)
                    .alpha(if (selected == null || selected == ct.cat.id) 1f else 0.4f),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    es.david.caudal.ui.common.IconBubble(ct.cat.icon, ct.cat.color, 36.dp)
                    Spacer(Modifier.width(10.dp))
                    Text(name, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                    AmountText(ct.total, style = MaterialTheme.typography.bodyLarge, weight = FontWeight.ExtraBold)
                }
                Spacer(Modifier.height(6.dp))
                ProgressBar(ct.total / top, hexColor(ct.cat.color), height = 8.dp)
            }
            if (i < cats.lastIndex) Spacer(Modifier.height(2.dp))
        }
    }
}

// MARK: 6 meses

@Composable
private fun MonthsChart(l: Ledger, base: String) {
    val f = LocalFmt.current
    val c = CaudalTheme.colors
    val motion = LocalMotion.current
    val months = remember(l, base) {
        (5 downTo 0).map { k ->
            val s = Day.addMonths(base, -k)
            val r = l.periodRange(s)
            Triple(f.month(s).take(3), l.earned(r), l.spent(r))
        }
    }
    val progress = remember { Animatable(if (motion) 0f else 1f) }
    LaunchedEffect(months) { if (motion) { progress.snapTo(0f); progress.animateTo(1f, spring(dampingRatio = 0.7f, stiffness = Spring.StiffnessVeryLow)) } }
    val desc = stringResource(R.string.months_chart_desc) + ". " + months.joinToString("; ") { "${it.first}: ${f.money(it.second)}, ${f.money(it.third)}" }
    Card {
        SectionHeader(stringResource(R.string.last_6_months), emoji = "📊")
        Spacer(Modifier.height(6.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Legend(c.income, stringResource(R.string.incomes))
            Spacer(Modifier.width(14.dp))
            Legend(c.expenseAccent, stringResource(R.string.expenses))
        }
        Spacer(Modifier.height(12.dp))
        Canvas(Modifier.fillMaxWidth().height(180.dp).semantics { contentDescription = desc }) {
            val hi = months.maxOf { max(it.second, it.third) }.takeIf { it > 0 } ?: 1.0
            val slot = size.width / months.size
            val bw = slot * 0.3f
            months.forEachIndexed { i, (_, inc, out) ->
                listOf(inc to c.income, out to c.expenseAccent).forEachIndexed { j, (v, col) ->
                    val bh = (v / hi * size.height * progress.value).toFloat().coerceAtLeast(if (v > 0) 4f else 0f)
                    val x = i * slot + slot * 0.18f + j * (bw + slot * 0.04f)
                    drawRoundRect(
                        Brush.verticalGradient(listOf(lerp(col, Color.White, 0.25f), col), startY = size.height - bh, endY = size.height),
                        Offset(x, size.height - bh), Size(bw, bh), CornerRadius(8.dp.toPx()),
                    )
                }
            }
        }
        Spacer(Modifier.height(6.dp))
        Row(Modifier.fillMaxWidth()) {
            months.forEachIndexed { i, m ->
                Text(m.first, Modifier.weight(1f), textAlign = TextAlign.Center, style = MaterialTheme.typography.labelSmall, color = if (i == months.lastIndex) c.text else c.textDim)
            }
        }
    }
}

@Composable
private fun Legend(col: Color, label: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(10.dp).clip(CircleShape).background(col))
        Spacer(Modifier.width(6.dp))
        Text(label, style = MaterialTheme.typography.labelMedium, color = CaudalTheme.colors.textDim)
    }
}

// MARK: presupuestos

@Composable
private fun Budgets(l: Ledger, r: DateRange) {
    val cats = l.data.categories.filter { it.kind == CatKind.EXPENSE && it.budget > 0 }.sortedBy { it.position }
    if (cats.isEmpty()) return
    val f = LocalFmt.current
    val c = CaudalTheme.colors
    val spent = remember(l, r) { l.byCategory(r).associate { it.cat.id to it.total } }
    Card {
        SectionHeader(stringResource(R.string.budgets), emoji = "🎯")
        Spacer(Modifier.height(8.dp))
        cats.forEachIndexed { i, ct ->
            val s = spent[ct.id] ?: 0.0
            val b = Money.fromCents(ct.budget)
            val (emoji, status) = when {
                s > b -> "🚨" to stringResource(R.string.st_budget_over)
                s > b * 0.8 -> "😬" to stringResource(R.string.st_budget_warn)
                else -> "😌" to stringResource(R.string.st_budget_ok)
            }
            Column(Modifier.padding(vertical = 8.dp).semantics(mergeDescendants = true) {}) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    es.david.caudal.ui.common.IconBubble(ct.icon, ct.color, 36.dp)
                    Spacer(Modifier.width(10.dp))
                    Column(Modifier.weight(1f)) {
                        Text(ct.name, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        Text(
                            "$emoji $status · " + if (s > b) stringResource(R.string.st_budget_over_by, f.money(s - b)) else stringResource(R.string.st_budget_left, f.money(b - s)),
                            style = MaterialTheme.typography.bodySmall, color = if (s > b) c.negative else c.textDim,
                        )
                    }
                    Text("${f.money(s)} / ${f.money(b)}", style = MaterialTheme.typography.labelMedium, color = c.textDim)
                }
                Spacer(Modifier.height(8.dp))
                ProgressBar(s / b, budgetColor(s, b, hexColor(ct.color), c.warning, c.negative))
            }
            if (i < cats.lastIndex) RowDivider(0.dp)
        }
    }
}

// MARK: dónde más gastas

@Composable
private fun TopConcepts(l: Ledger, r: DateRange) {
    val c = CaudalTheme.colors
    val noConcept = stringResource(R.string.no_concept)
    val top = remember(l, r) {
        val m = LinkedHashMap<String, Pair<Double, Int>>()
        for (t in l.txs(r)) if (t.type == TxType.EXPENSE && !t.excluded) {
            val k = t.title.ifEmpty { l.category(t.categoryId)?.name ?: noConcept }
            val (v, n) = m[k] ?: (0.0 to 0)
            m[k] = (v + Money.fromCents(t.amount)) to (n + 1)
        }
        m.entries.sortedByDescending { it.value.first }.take(6)
    }
    if (top.isEmpty()) return
    val medals = listOf("🥇", "🥈", "🥉")
    Card {
        SectionHeader(stringResource(R.string.where_most), emoji = "🏆")
        Spacer(Modifier.height(6.dp))
        top.forEachIndexed { i, e ->
            Row(Modifier.fillMaxWidth().heightIn(min = 52.dp).semantics(mergeDescendants = true) {}, verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.size(34.dp).clip(CircleShape).background(c.cardAlt), contentAlignment = Alignment.Center) {
                    if (i < 3) Text(medals[i], fontSize = 18.sp) else Text("${i + 1}", style = MaterialTheme.typography.labelLarge)
                }
                Spacer(Modifier.width(12.dp))
                Column(Modifier.weight(1f)) {
                    Text(e.key, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text(stringResource(R.string.st_top_times, e.value.second), style = MaterialTheme.typography.bodySmall, color = c.textDim)
                }
                AmountText(e.value.first, style = MaterialTheme.typography.bodyLarge, weight = FontWeight.ExtraBold)
            }
            if (i < top.lastIndex) RowDivider(46.dp)
        }
    }
}
