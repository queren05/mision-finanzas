package es.david.caudal.ui.stats

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
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
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.filled.TrendingDown
import androidx.compose.material.icons.automirrored.filled.TrendingUp
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Savings
import androidx.compose.material3.FilledTonalIconButton
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import es.david.caudal.R
import es.david.caudal.core.Day
import es.david.caudal.core.Money
import es.david.caudal.domain.calc.DateRange
import es.david.caudal.domain.calc.Ledger
import es.david.caudal.domain.model.CatKind
import es.david.caudal.domain.model.TxType
import es.david.caudal.ui.charts.Donut
import es.david.caudal.ui.charts.Slice
import es.david.caudal.ui.common.AmountText
import es.david.caudal.ui.common.Card
import es.david.caudal.ui.common.EmptyText
import es.david.caudal.ui.common.FinanceViewModel
import es.david.caudal.ui.common.LocalFmt
import es.david.caudal.ui.common.ProgressBar
import es.david.caudal.ui.common.ScreenScaffold
import es.david.caudal.ui.common.SegmentedPills
import es.david.caudal.ui.common.budgetColor
import es.david.caudal.ui.common.rememberHaptics
import es.david.caudal.ui.theme.CaudalTheme
import es.david.caudal.ui.theme.hexColor
import kotlin.math.max

/** Análisis del mes (financiero): indicadores, en qué se va el dinero, 6 meses, presupuestos y conceptos */
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

    ScreenScaffold(title = stringResource(R.string.analysis), onBack = { nav.popBackStack() }) { pad ->
        LazyColumn(
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = pad.calculateTopPadding(), bottom = 48.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            item {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    FilledTonalIconButton(onClick = { h.select(); start = Day.addMonths(start, -1); selectedCat = null }) {
                        Icon(Icons.AutoMirrored.Filled.KeyboardArrowLeft, stringResource(R.string.prev_month))
                    }
                    Text(f.monthYear(start), style = MaterialTheme.typography.titleLarge, textAlign = TextAlign.Center, modifier = Modifier.weight(1f))
                    FilledTonalIconButton(onClick = { h.select(); start = Day.addMonths(start, 1); selectedCat = null }, enabled = range.end < Day.today) {
                        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, stringResource(R.string.next_month))
                    }
                }
            }
            item { Kpis(l, range) }
            item {
                CategoriesDonut(l, range, showIncome, selectedCat, onKind = { showIncome = it; selectedCat = null }, onSelect = { h.select(); selectedCat = it })
            }
            item { MonthsChart(l, start) }
            item { Budgets(l, range) }
            item { TopConcepts(l, range) }
        }
    }
}

@Composable
private fun Kpis(l: Ledger, r: DateRange) {
    val f = LocalFmt.current
    val colors = CaudalTheme.colors
    val spent = l.spent(r)
    val earned = l.earned(r)
    val days = (Day.daysBetween(r.start, Day.today) + 1).coerceIn(1, 31)
    val saving = Ledger.savingPct(earned, spent)
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Kpi(Modifier.weight(1f), stringResource(R.string.spent), f.money(spent), Icons.AutoMirrored.Filled.TrendingDown, colors.negative)
            Kpi(Modifier.weight(1f), stringResource(R.string.earned), f.money(earned), Icons.AutoMirrored.Filled.TrendingUp, colors.income)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Kpi(Modifier.weight(1f), stringResource(R.string.saving), saving?.let { f.pct(it) } ?: "—", Icons.Filled.Savings, if ((saving ?: 0.0) >= 0) colors.income else colors.negative)
            Kpi(Modifier.weight(1f), stringResource(R.string.daily_avg), f.money(spent / days), Icons.Filled.CalendarMonth, MaterialTheme.colorScheme.primary)
        }
    }
}

@Composable
private fun Kpi(modifier: Modifier, label: String, value: String, icon: androidx.compose.ui.graphics.vector.ImageVector, c: Color) {
    Card(modifier.semantics(mergeDescendants = true) {}, padding = 14.dp) {
        Icon(icon, null, tint = c)
        Spacer(Modifier.height(8.dp))
        Text(label, style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(value, style = MaterialTheme.typography.titleLarge.copy(fontFeatureSettings = "tnum"), maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

@Composable
private fun CategoriesDonut(l: Ledger, r: DateRange, income: Boolean, selected: String?, onKind: (Boolean) -> Unit, onSelect: (String?) -> Unit) {
    val f = LocalFmt.current
    val cats = remember(l, r, income) { l.byCategory(r, if (income) TxType.INCOME else TxType.EXPENSE) }
    val total = cats.sumOf { it.total }
    val sel = cats.firstOrNull { it.cat.id == selected }
    val noCat = stringResource(R.string.no_category)
    Card {
        SegmentedPills(listOf(stringResource(R.string.expenses), stringResource(R.string.incomes)), if (income) 1 else 0, { onKind(it == 1) })
        Spacer(Modifier.height(14.dp))
        if (cats.isEmpty()) {
            EmptyText(stringResource(R.string.nothing_in_period), Modifier.heightIn(min = 120.dp))
            return@Card
        }
        Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
            Donut(
                cats.map { Slice(it.total, hexColor(it.cat.color)) }, size = 230.dp, thickness = 32.dp,
                highlighted = cats.indexOfFirst { it.cat.id == selected }.takeIf { it >= 0 },
                description = stringResource(R.string.where_you_spend),
                onTap = { i -> onSelect(i?.let { cats[it].cat.id }) },
            )
            Column(Modifier.width(130.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                Text(sel?.let { "${it.cat.icon} ${it.cat.name.ifEmpty { noCat }}" } ?: stringResource(R.string.total), style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1, overflow = TextOverflow.Ellipsis)
                AmountText(sel?.total ?: total, style = MaterialTheme.typography.titleLarge, weight = FontWeight.Bold)
                if (sel != null) Text(f.num(sel.total / max(total, 0.01) * 100) + " %", style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        Spacer(Modifier.height(10.dp))
        val top = cats.first().total.coerceAtLeast(0.01)
        cats.forEach { c ->
            val name = c.cat.name.ifEmpty { noCat }
            val desc = stringResource(R.string.category_share, name, f.money(c.total), f.num(c.total / max(total, 0.01) * 100))
            Column(
                Modifier
                    .fillMaxWidth()
                    .clip(MaterialTheme.shapes.medium)
                    .clickable { onSelect(if (selected == c.cat.id) null else c.cat.id) }
                    .semantics(mergeDescendants = true) { contentDescription = desc }
                    .padding(vertical = 8.dp)
                    .alpha(if (selected == null || selected == c.cat.id) 1f else 0.45f),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(c.cat.icon)
                    Spacer(Modifier.width(8.dp))
                    Text(name, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium, modifier = Modifier.weight(1f))
                    AmountText(c.total, style = MaterialTheme.typography.bodyMedium, weight = FontWeight.SemiBold)
                }
                Spacer(Modifier.height(6.dp))
                ProgressBar(c.total / top, hexColor(c.cat.color), height = 6.dp)
            }
        }
    }
}

@Composable
private fun MonthsChart(l: Ledger, base: String) {
    val f = LocalFmt.current
    val colors = CaudalTheme.colors
    val months = remember(l, base) {
        (5 downTo 0).map { k ->
            val s = Day.addMonths(base, -k)
            val r = l.periodRange(s)
            Triple(f.month(s).take(3), l.earned(r), l.spent(r))
        }
    }
    val progress = remember { Animatable(0f) }
    LaunchedEffect(months) { progress.snapTo(0f); progress.animateTo(1f, tween(800)) }
    val desc = stringResource(R.string.months_chart_desc) + ". " + months.joinToString("; ") { "${it.first}: ${f.money(it.second)}, ${f.money(it.third)}" }
    Card {
        Text(stringResource(R.string.last_6_months), style = MaterialTheme.typography.titleMedium)
        Spacer(Modifier.height(8.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Legend(colors.income, stringResource(R.string.incomes))
            Spacer(Modifier.width(14.dp))
            Legend(colors.expenseAccent, stringResource(R.string.expenses))
        }
        Spacer(Modifier.height(10.dp))
        Canvas(Modifier.fillMaxWidth().height(180.dp).semantics { contentDescription = desc }) {
            val hi = months.maxOf { max(it.second, it.third) }.takeIf { it > 0 } ?: 1.0
            val slot = size.width / months.size
            val bw = slot * 0.3f
            months.forEachIndexed { i, (_, inc, out) ->
                listOf(inc to colors.income, out to colors.expenseAccent).forEachIndexed { j, (v, c) ->
                    val bh = (v / hi * size.height * progress.value).toFloat().coerceAtLeast(if (v > 0) 3f else 0f)
                    drawRoundRect(c, Offset(i * slot + slot * 0.18f + j * (bw + slot * 0.04f), size.height - bh), Size(bw, bh), CornerRadius(5.dp.toPx()))
                }
            }
        }
        Row(Modifier.fillMaxWidth()) {
            months.forEach { Text(it.first, Modifier.weight(1f), textAlign = TextAlign.Center, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant) }
        }
    }
}

@Composable
private fun Legend(c: Color, label: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Canvas(Modifier.size(10.dp)) { drawCircle(c) }
        Spacer(Modifier.width(6.dp))
        Text(label, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun Budgets(l: Ledger, r: DateRange) {
    val cats = l.data.categories.filter { it.kind == CatKind.EXPENSE && it.budget > 0 }.sortedBy { it.position }
    if (cats.isEmpty()) return
    val f = LocalFmt.current
    val colors = CaudalTheme.colors
    val spent = remember(l, r) { l.byCategory(r).associate { it.cat.id to it.total } }
    Card {
        Text(stringResource(R.string.budgets), style = MaterialTheme.typography.titleMedium)
        Spacer(Modifier.height(10.dp))
        cats.forEach { c ->
            val s = spent[c.id] ?: 0.0
            val b = Money.fromCents(c.budget)
            Column(Modifier.padding(vertical = 7.dp).semantics(mergeDescendants = true) {}) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("${c.icon} ${c.name}", style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium, modifier = Modifier.weight(1f))
                    Text("${f.money(s)} / ${f.money(b)}", style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.SemiBold, color = if (s > b) colors.negative else MaterialTheme.colorScheme.onSurfaceVariant)
                }
                Spacer(Modifier.height(6.dp))
                ProgressBar(s / b, budgetColor(s, b, hexColor(c.color), colors.warning, colors.negative))
            }
        }
    }
}

@Composable
private fun TopConcepts(l: Ledger, r: DateRange) {
    val noConcept = stringResource(R.string.no_concept)
    val top = remember(l, r) {
        val m = LinkedHashMap<String, Double>()
        for (t in l.txs(r)) if (t.type == TxType.EXPENSE && !t.excluded) {
            val k = t.title.ifEmpty { l.category(t.categoryId)?.name ?: noConcept }
            m[k] = (m[k] ?: 0.0) + Money.fromCents(t.amount)
        }
        m.entries.sortedByDescending { it.value }.take(6)
    }
    Card {
        Text(stringResource(R.string.where_most), style = MaterialTheme.typography.titleMedium)
        Spacer(Modifier.height(8.dp))
        if (top.isEmpty()) Text(stringResource(R.string.no_spending), color = MaterialTheme.colorScheme.onSurfaceVariant)
        top.forEachIndexed { i, e ->
            Row(Modifier.fillMaxWidth().padding(vertical = 6.dp).semantics(mergeDescendants = true) {}, verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.size(26.dp).clip(CircleShape), contentAlignment = Alignment.Center) {
                    Canvas(Modifier.size(26.dp)) { drawCircle(Color.Gray.copy(alpha = 0.18f)) }
                    Text("${i + 1}", style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Bold)
                }
                Spacer(Modifier.width(10.dp))
                Text(e.key, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                AmountText(e.value, style = MaterialTheme.typography.bodyMedium, weight = FontWeight.SemiBold)
            }
        }
    }
}
