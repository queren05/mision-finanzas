package es.david.caudal.ui.txs

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import es.david.caudal.R
import es.david.caudal.core.Day
import es.david.caudal.domain.calc.DateRange
import es.david.caudal.domain.calc.Insights
import es.david.caudal.ui.common.AmountText
import es.david.caudal.ui.common.Card
import es.david.caudal.ui.common.CircleIconButton
import es.david.caudal.ui.common.EmptyText
import es.david.caudal.ui.common.FinanceViewModel
import es.david.caudal.ui.common.LocalFmt
import es.david.caudal.ui.common.RowDivider
import es.david.caudal.ui.common.ScreenScaffold
import es.david.caudal.ui.common.TxRow
import es.david.caudal.ui.common.appear
import es.david.caudal.ui.common.contentOn
import es.david.caudal.ui.common.pressable
import es.david.caudal.ui.common.rememberHaptics
import es.david.caudal.ui.nav.TxEditorRoute
import es.david.caudal.ui.theme.CaudalTheme
import es.david.caudal.ui.theme.LocalMotion

/** Calendario de calor del gasto: cuanto más gastas un día, más intenso su color. Tocar un día enseña sus movimientos. */
@Composable
fun CalendarScreen(month: String?, nav: NavController) {
    val vm: FinanceViewModel = hiltViewModel()
    val ledger by vm.ledger.collectAsStateWithLifecycle()
    val sunday = vm.settings.collectAsStateWithLifecycle().value?.weekStart == 7
    val l = ledger ?: return
    val f = LocalFmt.current
    val h = rememberHaptics()
    val c = CaudalTheme.colors
    var key by rememberSaveable { mutableStateOf(month ?: Day.monthKey(Day.today)) }
    var selected by rememberSaveable { mutableStateOf(if (Day.monthKey(Day.today) == key) Day.today else "$key-01") }
    val start = "$key-01"
    val days = Day.daysInMonth(start)
    val range = DateRange(start, Day.addDays(start, days - 1))
    val byDay = remember(l, key) { Insights.spentByDay(l, range) }
    val total = byDay.values.sum()
    val top = byDay.maxByOrNull { it.value }
    val hi = top?.value?.takeIf { it > 0 } ?: 1.0
    val dayTxs = remember(l, selected) { l.data.txs.filter { it.date == selected }.sortedByDescending { it.sortKey } }

    fun move(k: Int) {
        h.select()
        key = Day.monthKey(Day.addMonths(start, k))
        selected = if (Day.monthKey(Day.today) == key) Day.today else "$key-01"
    }

    ScreenScaffold(title = stringResource(R.string.cal_title), onBack = { nav.popBackStack() }) { pad ->
        LazyColumn(
            Modifier.fillMaxSize(),
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = pad.calculateTopPadding(), bottom = 60.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            item(key = "mes") {
                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.appear(0)) {
                    CircleIconButton(Icons.AutoMirrored.Filled.KeyboardArrowLeft, stringResource(R.string.prev_month)) { move(-1) }
                    AnimatedContent(f.monthYear(start), transitionSpec = { fadeIn() togetherWith fadeOut() }, label = "mes", modifier = Modifier.weight(1f)) {
                        Text(it, style = MaterialTheme.typography.titleLarge, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
                    }
                    CircleIconButton(Icons.AutoMirrored.Filled.KeyboardArrowRight, stringResource(R.string.next_month)) { move(1) }
                }
            }
            item(key = "calendario") {
                Card(Modifier.appear(1), padding = 14.dp) {
                    val labels = stringResource(R.string.weekdays_short).split(",").let { if (sunday) listOf(it.last()) + it.dropLast(1) else it }
                    Row(Modifier.fillMaxWidth()) { labels.forEach { Text(it, Modifier.weight(1f), textAlign = TextAlign.Center, style = MaterialTheme.typography.labelMedium, color = c.textDim) } }
                    Spacer(Modifier.height(8.dp))
                    // la semana empieza en lunes o domingo, según Personalizar
                    val firstDow = if (sunday) Day.date(start).dayOfWeek.value % 7 else Day.date(start).dayOfWeek.value - 1
                    val cells = List(firstDow) { 0 } + (1..days).toList()
                    cells.chunked(7).forEach { week ->
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            week.forEach { d ->
                                if (d == 0) Spacer(Modifier.weight(1f).aspectRatio(1f))
                                else {
                                    val date = start.take(8) + d.toString().padStart(2, '0')
                                    DayCell(
                                        Modifier.weight(1f), d, byDay[date] ?: 0.0, hi, date == Day.today, date == selected,
                                        stringResource(R.string.calendar_day_desc, f.shortLabel(date), f.money(byDay[date] ?: 0.0)),
                                    ) { h.select(); selected = date }
                                }
                            }
                            repeat(7 - week.size) { Spacer(Modifier.weight(1f)) }
                        }
                        Spacer(Modifier.height(6.dp))
                    }
                    Spacer(Modifier.height(4.dp))
                    // leyenda
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.End, modifier = Modifier.fillMaxWidth()) {
                        Text(stringResource(R.string.cal_less), style = MaterialTheme.typography.labelSmall, color = c.textDim)
                        Spacer(Modifier.width(6.dp))
                        listOf(0f, 0.25f, 0.5f, 0.75f, 1f).forEach { k ->
                            Box(Modifier.padding(horizontal = 2.dp).size(14.dp).clip(RoundedCornerShape(4.dp)).background(heat(k)))
                        }
                        Spacer(Modifier.width(6.dp))
                        Text(stringResource(R.string.cal_more), style = MaterialTheme.typography.labelSmall, color = c.textDim)
                    }
                }
            }
            item(key = "totales") {
                Row(Modifier.fillMaxWidth().appear(2), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Stat(Modifier.weight(1f), "💸", stringResource(R.string.cal_month_total), total, null)
                    Stat(Modifier.weight(1f), "🔥", stringResource(R.string.cal_top_day), top?.value ?: 0.0, top?.key?.let { f.shortLabel(it) })
                }
            }
            item(key = "dia") {
                Card(Modifier.appear(3), padding = 6.dp) {
                    Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text(f.dayLong(selected), style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
                        AmountText(byDay[selected] ?: 0.0, style = MaterialTheme.typography.titleMedium, rolling = true)
                    }
                    if (dayTxs.isEmpty()) EmptyText(stringResource(R.string.cal_no_spending_day))
                    dayTxs.forEachIndexed { i, t ->
                        TxRow(t, l, onClick = { nav.navigate(TxEditorRoute(id = t.id)) })
                        if (i < dayTxs.lastIndex) RowDivider(72.dp)
                    }
                }
            }
        }
    }
}

@Composable
private fun heat(k: Float) = CaudalTheme.colors.let { c -> if (k <= 0f) c.cardAlt else lerp(lerp(c.cardAlt, c.accent, 0.35f), c.accent, k) }

@Composable
private fun DayCell(modifier: Modifier, day: Int, v: Double, hi: Double, today: Boolean, selected: Boolean, desc: String, onClick: () -> Unit) {
    val c = CaudalTheme.colors
    val k = (v / hi).toFloat().coerceIn(0f, 1f)
    val bg by animateColorAsState(heat(if (v > 0) k else 0f), label = "calor")
    val motion = LocalMotion.current
    val scale by animateFloatAsState(if (selected && motion) 1.12f else 1f, spring(dampingRatio = 0.45f, stiffness = Spring.StiffnessMedium), label = "día")
    Box(
        modifier
            .aspectRatio(1f)
            .graphicsLayer { scaleX = scale; scaleY = scale }
            .pressable(0.85f, role = Role.Button, onClick = onClick)
            .clip(RoundedCornerShape(12.dp))
            .background(bg)
            .then(if (selected) Modifier.border(2.5.dp, c.text, RoundedCornerShape(12.dp)) else if (today) Modifier.border(2.dp, c.accent, RoundedCornerShape(12.dp)) else Modifier)
            .semantics { contentDescription = desc; this.selected = selected },
        contentAlignment = Alignment.Center,
    ) {
        Text("$day", style = MaterialTheme.typography.labelLarge, color = if (v > 0) contentOn(c.accent) else c.textDim)
    }
}

@Composable
private fun Stat(modifier: Modifier, emoji: String, label: String, v: Double, sub: String?) {
    val c = CaudalTheme.colors
    Column(
        modifier.clip(RoundedCornerShape(22.dp)).background(c.card).border(1.dp, c.hairline, RoundedCornerShape(22.dp)).padding(14.dp).semantics(mergeDescendants = true) {},
    ) {
        Text(emoji, fontSize = 22.sp)
        Spacer(Modifier.height(4.dp))
        Text(label, style = MaterialTheme.typography.labelMedium, color = c.textDim)
        AmountText(v, style = MaterialTheme.typography.titleLarge, rolling = true)
        if (sub != null) Text(sub, style = MaterialTheme.typography.labelMedium, color = c.textDim)
    }
}
