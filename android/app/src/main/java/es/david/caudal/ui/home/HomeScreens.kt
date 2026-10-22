package es.david.caudal.ui.home

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
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.PageSize
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForwardIos
import androidx.compose.material.icons.automirrored.filled.TrendingDown
import androidx.compose.material.icons.automirrored.filled.TrendingUp
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Dashboard
import androidx.compose.material.icons.filled.ShowChart
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material.icons.filled.Work
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import es.david.caudal.R
import es.david.caudal.core.Day
import es.david.caudal.core.Money
import es.david.caudal.domain.calc.Debts
import es.david.caudal.domain.calc.Hours
import es.david.caudal.domain.calc.Insights
import es.david.caudal.domain.calc.Ledger
import es.david.caudal.domain.calc.MonthMood
import es.david.caudal.domain.model.Account
import es.david.caudal.domain.model.AccountType
import es.david.caudal.domain.model.AccountsStyle
import es.david.caudal.domain.model.AppSettings
import es.david.caudal.ui.charts.Donut
import es.david.caudal.ui.charts.LineChart
import es.david.caudal.ui.charts.Slice
import es.david.caudal.ui.common.AmountText
import es.david.caudal.ui.common.Card
import es.david.caudal.ui.common.CircleIconButton
import es.david.caudal.ui.common.FinanceViewModel
import es.david.caudal.ui.common.GlowBackground
import es.david.caudal.ui.common.Gotita
import es.david.caudal.ui.common.IconBubble
import es.david.caudal.ui.common.LocalFmt
import es.david.caudal.ui.common.LocalMascot
import es.david.caudal.ui.common.Mood
import es.david.caudal.ui.common.ProgressBar
import es.david.caudal.ui.common.RowDivider
import es.david.caudal.ui.common.SectionHeader
import es.david.caudal.ui.common.TxRow
import es.david.caudal.ui.common.appear
import es.david.caudal.ui.common.pressable
import es.david.caudal.ui.common.rememberHaptics
import es.david.caudal.ui.nav.AccountDetailRoute
import es.david.caudal.ui.nav.DebtsRoute
import es.david.caudal.ui.nav.HomeCustomizeRoute
import es.david.caudal.ui.nav.InvestRoute
import es.david.caudal.ui.nav.StatsRoute
import es.david.caudal.ui.nav.TxEditorRoute
import es.david.caudal.ui.nav.TxsRoute
import es.david.caudal.ui.nav.WorkRoute
import es.david.caudal.ui.nav.navigateTab
import es.david.caudal.ui.theme.CaudalTheme
import es.david.caudal.ui.theme.hexColor
import java.time.LocalTime
import kotlin.math.abs
import kotlin.math.roundToInt

@Composable
fun HomeScreen(nav: NavController, onToggleHidden: () -> Unit) {
    val vm: FinanceViewModel = hiltViewModel()
    val ledger by vm.ledger.collectAsStateWithLifecycle()
    val settings by vm.settings.collectAsStateWithLifecycle()
    val l = ledger ?: return
    val s = settings ?: return
    val c = CaudalTheme.colors
    val list = rememberLazyListState()
    val scrolled by remember { derivedStateOf { list.firstVisibleItemIndex > 0 || list.firstVisibleItemScrollOffset > 120 } }

    val cards = s.home.filter { it.on }.map { it.id }.filter { id ->
        when (id) {
            "horas" -> s.moduleWork && l.data.companies.isNotEmpty()
            "inversiones" -> s.moduleInvest
            "deudas" -> s.moduleDebts
            else -> true
        }
    }
    Box(Modifier.fillMaxSize()) {
        GlowBackground(c.accent, Modifier.fillMaxWidth().height(380.dp).graphicsLayer { translationY = -list.firstVisibleItemScrollOffset * 0.3f; alpha = if (list.firstVisibleItemIndex > 0) 0f else 1f })
        LazyColumn(
            state = list,
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = 140.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp),
            modifier = Modifier.fillMaxSize(),
        ) {
            item(key = "cabecera") { Header(l, s, onToggleHidden) }
            cards.forEachIndexed { i, id ->
                item(key = id) {
                    Box(Modifier.animateItem().appear(i + 1)) {
                        when (id) {
                            "patrimonio" -> NetWorthCard(l)
                            "disponible" -> AllowanceCard(l)
                            "cuentas" -> AccountsCard(l, s, vm, nav)
                            "consejos" -> InsightsCard(l)
                            "horas" -> WorkCard(l) { nav.navigate(WorkRoute) }
                            "mes" -> MonthCard(l)
                            "calendario" -> CalendarCard(l) { nav.navigate(es.david.caudal.ui.nav.CalendarRoute()) }
                            "categorias" -> CategoriesCard(l) { nav.navigate(StatsRoute) }
                            "proximos" -> UpcomingCard(l)
                            "recientes" -> RecentCard(l, onTx = { nav.navigate(TxEditorRoute(id = it)) }, onAll = { nav.navigateTab(TxsRoute) })
                            "inversiones" -> InvestCard(l) { nav.navigateTab(InvestRoute) }
                            "deudas" -> DebtsCard(l) { nav.navigateTab(DebtsRoute) }
                        }
                    }
                }
            }
            item(key = "personalizar") {
                val h = rememberHaptics()
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(22.dp))
                        .pressable { h.tap(); nav.navigate(HomeCustomizeRoute) }
                        .background(c.card)
                        .border(1.dp, c.hairline, RoundedCornerShape(22.dp))
                        .heightIn(min = 56.dp)
                        .padding(14.dp),
                    horizontalArrangement = Arrangement.Center,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.Filled.Dashboard, null, tint = c.accent)
                    Spacer(Modifier.width(8.dp))
                    Text(stringResource(R.string.customize_home), style = MaterialTheme.typography.labelLarge)
                }
            }
        }
        // barra pequeña con el saludo cuando se ha bajado
        if (scrolled) {
            Row(
                Modifier.fillMaxWidth().background(c.bg).statusBarsPadding().padding(horizontal = 16.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(greeting(s.name), style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                EyeButton(onToggleHidden)
            }
        }
    }
}

@Composable
private fun EyeButton(onToggleHidden: () -> Unit) {
    val f = LocalFmt.current
    CircleIconButton(
        if (f.hidden) Icons.Filled.VisibilityOff else Icons.Filled.Visibility,
        stringResource(if (f.hidden) R.string.show_amounts else R.string.hide_amounts),
        onClick = onToggleHidden,
    )
}

@Composable
private fun greeting(name: String): String {
    val hour = LocalTime.now(Day.clock).hour
    val g = stringResource(
        when {
            hour < 6 -> R.string.greeting_night
            hour < 14 -> R.string.greeting_morning
            hour < 21 -> R.string.greeting_afternoon
            else -> R.string.greeting_night
        },
    )
    return if (name.isBlank()) g else stringResource(R.string.greeting_name, g, name)
}

/** saludo con Gotita, su mensaje según cómo va el mes y la racha */
@Composable
private fun Header(l: Ledger, s: AppSettings, onToggleHidden: () -> Unit) {
    val c = CaudalTheme.colors
    val mood = remember(l) { Insights.mood(l) }
    val streak = remember(l) { Insights.streak(l.data.txs) }
    val msg = stringResource(
        when (mood) {
            MonthMood.EMPTY -> R.string.mood_empty
            MonthMood.GREAT -> R.string.mood_great
            MonthMood.OK -> R.string.mood_ok
            MonthMood.CAREFUL -> R.string.mood_careful
            MonthMood.OVER -> R.string.mood_over
        },
    )
    Column(Modifier.statusBarsPadding().padding(top = 8.dp).appear(0)) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) { EyeButton(onToggleHidden) }
        Text(greeting(s.name), style = MaterialTheme.typography.headlineLarge, modifier = Modifier.semantics { heading() })
        Spacer(Modifier.height(10.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (LocalMascot.current) {
                Gotita(
                    when (mood) {
                        MonthMood.GREAT -> Mood.LOVE
                        MonthMood.OK -> Mood.WINK
                        MonthMood.CAREFUL -> Mood.WOW
                        MonthMood.OVER -> Mood.SAD
                        MonthMood.EMPTY -> Mood.HAPPY
                    },
                    size = 58.dp,
                    description = stringResource(R.string.gotita),
                )
                Spacer(Modifier.width(10.dp))
            }
            // bocadillo
            Column(
                Modifier.weight(1f).clip(RoundedCornerShape(topStart = 6.dp, topEnd = 20.dp, bottomEnd = 20.dp, bottomStart = 20.dp)).background(c.card)
                    .border(1.dp, c.hairline, RoundedCornerShape(topStart = 6.dp, topEnd = 20.dp, bottomEnd = 20.dp, bottomStart = 20.dp))
                    .padding(horizontal = 14.dp, vertical = 10.dp),
            ) {
                Text(msg, style = MaterialTheme.typography.bodyMedium)
                if (streak >= 1) {
                    Spacer(Modifier.height(4.dp))
                    Text(
                        if (streak == 1) stringResource(R.string.streak_one) else stringResource(R.string.streak_days, streak),
                        style = MaterialTheme.typography.labelMedium, color = c.warning,
                    )
                }
            }
        }
        Spacer(Modifier.height(4.dp))
    }
}

// MARK: patrimonio con gráfico de 30 días

@Composable
private fun NetWorthCard(l: Ledger) {
    val f = LocalFmt.current
    val h = rememberHaptics()
    val c = CaudalTheme.colors
    val series = remember(l) { l.netWorthSeries(30) }
    var selected by remember { mutableStateOf<Int?>(null) }
    val now = l.netWorth
    val first = series.firstOrNull()?.value ?: 0.0
    val diff = now - first
    val point = selected?.let { series.getOrNull(it) }
    Card(padding = 20.dp) {
        Text(point?.let { f.header(it.date) } ?: stringResource(R.string.net_worth), style = MaterialTheme.typography.titleSmall, color = c.textDim)
        AmountText(point?.value ?: now, style = MaterialTheme.typography.displayMedium, rolling = true)
        Row(verticalAlignment = Alignment.CenterVertically) {
            val col = if (diff >= 0) c.income else c.negative
            Box(Modifier.clip(CircleShape).background(col.copy(alpha = 0.16f)).padding(horizontal = 8.dp, vertical = 3.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(if (diff >= 0) Icons.AutoMirrored.Filled.TrendingUp else Icons.AutoMirrored.Filled.TrendingDown, null, tint = col, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(4.dp))
                    AmountText(diff, signed = true, color = col, style = MaterialTheme.typography.labelLarge)
                }
            }
            Spacer(Modifier.width(8.dp))
            Text(stringResource(R.string.in_30_days), style = MaterialTheme.typography.bodyMedium, color = c.textDim)
        }
        Spacer(Modifier.height(10.dp))
        LineChart(
            values = series.map { it.value },
            color = c.accent,
            height = 130.dp,
            selected = selected,
            description = stringResource(R.string.net_worth_chart),
            onSelect = { if (it != null && it != selected) h.select(); selected = it },
        )
        Spacer(Modifier.height(12.dp))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            MiniStat(Modifier.weight(1f), stringResource(R.string.cash), l.cashTotal, "💶")
            MiniStat(Modifier.weight(1f), stringResource(R.string.investments), l.investValue, "📈")
        }
    }
}

@Composable
private fun MiniStat(modifier: Modifier, label: String, v: Double, emoji: String) {
    val c = CaudalTheme.colors
    Row(
        modifier.clip(RoundedCornerShape(18.dp)).background(c.cardAlt).padding(horizontal = 12.dp, vertical = 10.dp).semantics(mergeDescendants = true) {},
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(emoji, fontSize = 20.sp)
        Spacer(Modifier.width(8.dp))
        Column {
            Text(label, style = MaterialTheme.typography.labelMedium, color = c.textDim)
            AmountText(v, style = MaterialTheme.typography.titleSmall)
        }
    }
}

// MARK: disponible hoy

@Composable
private fun AllowanceCard(l: Ledger) {
    val f = LocalFmt.current
    val c = CaudalTheme.colors
    val a = remember(l) { Insights.allowance(l) }
    val forecast = remember(l) { Insights.forecast(l) }
    val r = l.periodRange(l.periodStart(Day.today))
    val elapsed = (Day.daysBetween(r.start, Day.today) + 1).toDouble() / (Day.daysBetween(r.start, r.end) + 1)
    val ok = a.left > 0
    if (a.base <= 0) {
        // sin presupuesto ni ingresos todavía: invitación
        Card(padding = 20.dp) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("☀️", fontSize = 22.sp)
                Spacer(Modifier.width(8.dp))
                Text(stringResource(R.string.home_disponible), style = MaterialTheme.typography.titleMedium, color = c.textDim)
            }
            Spacer(Modifier.height(6.dp))
            Text(stringResource(R.string.allowance_empty), style = MaterialTheme.typography.bodyMedium)
        }
        return
    }
    Card(padding = 20.dp) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("☀️", fontSize = 22.sp)
            Spacer(Modifier.width(8.dp))
            Text(stringResource(R.string.home_disponible), style = MaterialTheme.typography.titleMedium, color = c.textDim, modifier = Modifier.weight(1f))
        }
        Spacer(Modifier.height(4.dp))
        Row(verticalAlignment = Alignment.Bottom) {
            AmountText(a.perDay, style = MaterialTheme.typography.displaySmall, color = if (ok) c.text else c.negative, rolling = true)
            Spacer(Modifier.width(8.dp))
            Text(stringResource(R.string.per_day), style = MaterialTheme.typography.titleMedium, color = c.textDim, modifier = Modifier.padding(bottom = 6.dp))
        }
        Text(
            when {
                !ok -> stringResource(R.string.allowance_over, f.money(-a.left))
                a.daysLeft == 1 -> stringResource(R.string.allowance_left_one, f.money(a.left))
                else -> stringResource(R.string.allowance_left, f.money(a.left), a.daysLeft)
            },
            style = MaterialTheme.typography.bodyMedium,
        )
        Spacer(Modifier.height(12.dp))
        // cuánto del mes ha pasado (barra) frente a lo gastado
        ProgressBar(elapsed, if (ok) c.income else c.negative)
        Spacer(Modifier.height(10.dp))
        if (a.upcoming > 0) Text(stringResource(R.string.allowance_upcoming, f.money(a.upcoming)), style = MaterialTheme.typography.bodySmall, color = c.textDim)
        if (!a.fromBudget) Text(stringResource(R.string.allowance_from_income), style = MaterialTheme.typography.bodySmall, color = c.textDim)
        if (forecast != null && forecast > 0) Text(stringResource(R.string.forecast, f.money(forecast)), style = MaterialTheme.typography.bodySmall, color = c.textDim)
    }
}

// MARK: avisos de Gotita

@Composable
private fun InsightsCard(l: Ledger) {
    val f = LocalFmt.current
    val c = CaudalTheme.colors
    val list = remember(l) { Insights.categoryChanges(l) }
    Card {
        SectionHeader(stringResource(R.string.home_consejos), emoji = "💡")
        Spacer(Modifier.height(6.dp))
        if (list.isEmpty()) {
            Text(stringResource(R.string.no_insights), style = MaterialTheme.typography.bodyMedium, color = c.textDim)
        }
        list.forEachIndexed { i, ins ->
            val less = ins.now < ins.before
            val col = if (less) c.income else c.warning
            Row(Modifier.fillMaxWidth().padding(vertical = 8.dp).semantics(mergeDescendants = true) {}, verticalAlignment = Alignment.CenterVertically) {
                IconBubble(ins.category.icon, ins.category.color, 40.dp)
                Spacer(Modifier.width(12.dp))
                Text(
                    when {
                        ins.before <= 0 -> stringResource(R.string.insight_new, f.money(ins.now), ins.category.name)
                        less -> stringResource(R.string.insight_less, abs(ins.pct).roundToInt().toString(), ins.category.name)
                        else -> stringResource(R.string.insight_more, abs(ins.pct).roundToInt().toString(), ins.category.name)
                    },
                    style = MaterialTheme.typography.bodyMedium, modifier = Modifier.weight(1f),
                )
                Spacer(Modifier.width(8.dp))
                Text(if (less) "🎉" else "👀", fontSize = 20.sp, modifier = Modifier.clip(CircleShape).background(col.copy(alpha = 0.16f)).padding(6.dp))
            }
            if (i < list.lastIndex) RowDivider(52.dp)
        }
    }
}

// MARK: calendario de gastos del mes

@Composable
private fun CalendarCard(l: Ledger, open: () -> Unit) {
    val f = LocalFmt.current
    val c = CaudalTheme.colors
    val start = Day.monthStart(Day.today)
    val days = Day.daysInMonth(start)
    val byDay = remember(l) { Insights.spentByDay(l, es.david.caudal.domain.calc.DateRange(start, Day.addDays(start, days - 1))) }
    val hi = byDay.values.maxOrNull()?.takeIf { it > 0 } ?: 1.0
    val firstDow = Day.date(start).dayOfWeek.value - 1
    val labels = stringResource(R.string.weekdays_short).split(",")
    Card(onClick = open) {
        SectionHeader(f.month(start), emoji = "🗓️")
        Spacer(Modifier.height(8.dp))
        Row(Modifier.fillMaxWidth()) { labels.forEach { Text(it, Modifier.weight(1f), textAlign = TextAlign.Center, style = MaterialTheme.typography.labelSmall, color = c.textDim) } }
        Spacer(Modifier.height(6.dp))
        val cells = List(firstDow) { 0 } + (1..days).toList()
        cells.chunked(7).forEach { week ->
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                week.forEach { d ->
                    if (d == 0) Spacer(Modifier.weight(1f).aspectRatio(1f))
                    else {
                        val date = start.take(8) + d.toString().padStart(2, '0')
                        val v = byDay[date] ?: 0.0
                        val k = (v / hi).toFloat()
                        val isToday = date == Day.today
                        val desc = stringResource(R.string.calendar_day_desc, f.shortLabel(date), f.money(v))
                        Box(
                            Modifier.weight(1f).aspectRatio(1f).clip(RoundedCornerShape(9.dp))
                                .background(if (v > 0) lerp(lerp(c.cardAlt, c.accent, 0.35f), c.accent, k) else c.cardAlt)
                                .then(if (isToday) Modifier.border(2.dp, c.text, RoundedCornerShape(9.dp)) else Modifier)
                                .semantics { contentDescription = desc },
                            contentAlignment = Alignment.Center,
                        ) {
                            Text("$d", style = MaterialTheme.typography.labelSmall, color = if (v > 0) es.david.caudal.ui.common.contentOn(c.accent) else c.textDim)
                        }
                    }
                }
                repeat(7 - week.size) { Spacer(Modifier.weight(1f)) }
            }
            Spacer(Modifier.height(5.dp))
        }
    }
}

// MARK: cuentas (5 estilos)

@Composable
private fun AccountsCard(l: Ledger, s: AppSettings, vm: FinanceViewModel, nav: NavController) {
    val h = rememberHaptics()
    var menu by remember { mutableStateOf(false) }
    val accounts = l.accounts
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(stringResource(R.string.accounts), style = MaterialTheme.typography.titleLarge, modifier = Modifier.weight(1f).padding(start = 4.dp))
            Box {
                CircleIconButton(Icons.Filled.Dashboard, stringResource(R.string.accounts_style)) { menu = true }
                DropdownMenu(expanded = menu, onDismissRequest = { menu = false }, shape = RoundedCornerShape(20.dp), containerColor = CaudalTheme.colors.card) {
                    AccountsStyle.entries.forEach { st ->
                        DropdownMenuItem(
                            text = { Text(stringResource(styleLabel(st)), fontWeight = if (st == s.accountsStyle) FontWeight.Black else null) },
                            onClick = { h.select(); menu = false; vm.updateSettings { it.copy(accountsStyle = st) } },
                        )
                    }
                    HorizontalDivider()
                    DropdownMenuItem(text = { Text(stringResource(R.string.sort_accounts)) }, onClick = { menu = false; nav.navigate(HomeCustomizeRoute) })
                }
            }
        }
        val open: (Account) -> Unit = { h.tap(); nav.navigate(AccountDetailRoute(it.id)) }
        when (s.accountsStyle) {
            AccountsStyle.CUADRICULA -> Grid(accounts, 2) { AccountTile(it, l.value(it), 124, open) }
            AccountsStyle.PEQUENO -> Grid(accounts, 3) { SmallTile(it, l.value(it), open) }
            AccountsStyle.GRANDE -> Column(verticalArrangement = Arrangement.spacedBy(12.dp)) { accounts.forEach { BigTile(it, l.value(it), open) } }
            AccountsStyle.LISTA -> Card(padding = 4.dp) {
                accounts.forEachIndexed { i, a ->
                    val desc = stringResource(R.string.account_value_desc, a.name, LocalFmt.current.money(l.value(a)))
                    Row(
                        Modifier.fillMaxWidth().pressable(0.985f) { open(a) }.heightIn(min = 58.dp).padding(horizontal = 12.dp, vertical = 8.dp).semantics(mergeDescendants = true) { contentDescription = desc },
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        IconBubble(a.icon, a.color, 40.dp)
                        Spacer(Modifier.width(12.dp))
                        Text(a.name, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.ExtraBold, modifier = Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                        AmountText(l.value(a), weight = FontWeight.ExtraBold)
                    }
                    if (i < accounts.lastIndex) RowDivider(64.dp)
                }
            }
            AccountsStyle.CARRUSEL -> {
                val pager = rememberPagerState { accounts.size }
                HorizontalPager(state = pager, pageSize = TwoPerPage, pageSpacing = 12.dp, modifier = Modifier.fillMaxWidth()) { i ->
                    AccountTile(accounts[i], l.value(accounts[i]), 132, open)
                }
            }
        }
    }
}

private fun styleLabel(s: AccountsStyle) = when (s) {
    AccountsStyle.CUADRICULA -> R.string.style_cuadricula
    AccountsStyle.CARRUSEL -> R.string.style_carrusel
    AccountsStyle.LISTA -> R.string.style_lista
    AccountsStyle.PEQUENO -> R.string.style_pequeno
    AccountsStyle.GRANDE -> R.string.style_grande
}

@Composable
private fun Grid(accounts: List<Account>, columns: Int, tile: @Composable (Account) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        accounts.chunked(columns).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                row.forEach { Box(Modifier.weight(1f)) { tile(it) } }
                repeat(columns - row.size) { Spacer(Modifier.weight(1f)) }
            }
        }
    }
}

private fun gradient(a: Account): Brush {
    val c = hexColor(a.color)
    return Brush.linearGradient(listOf(lerp(c, Color.White, 0.12f), lerp(c, Color.Black, 0.28f)))
}

@Composable
private fun AccountTile(a: Account, value: Double, height: Int, open: (Account) -> Unit) {
    val desc = stringResource(R.string.account_value_desc, a.name, LocalFmt.current.money(value))
    Column(
        Modifier
            .fillMaxWidth()
            .height(height.dp)
            .pressable(0.95f) { open(a) }
            .clip(RoundedCornerShape(26.dp))
            .background(gradient(a))
            .border(1.dp, Color.White.copy(alpha = 0.18f), RoundedCornerShape(26.dp))
            .semantics(mergeDescendants = true) { contentDescription = desc }
            .padding(16.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(a.icon, fontSize = 26.sp, modifier = Modifier.weight(1f))
            Icon(Icons.AutoMirrored.Filled.ArrowForwardIos, null, tint = Color.White.copy(alpha = 0.7f), modifier = Modifier.size(12.dp))
        }
        Spacer(Modifier.weight(1f))
        Text(a.name, color = Color.White.copy(alpha = 0.9f), style = MaterialTheme.typography.labelLarge, maxLines = 1, overflow = TextOverflow.Ellipsis)
        AmountText(value, color = Color.White, style = MaterialTheme.typography.titleLarge)
    }
}

@Composable
private fun SmallTile(a: Account, value: Double, open: (Account) -> Unit) {
    val desc = stringResource(R.string.account_value_desc, a.name, LocalFmt.current.money(value))
    Column(
        Modifier
            .fillMaxWidth()
            .height(96.dp)
            .pressable(0.93f) { open(a) }
            .clip(RoundedCornerShape(20.dp))
            .background(gradient(a))
            .semantics(mergeDescendants = true) { contentDescription = desc }
            .padding(11.dp),
    ) {
        Text(a.icon, fontSize = 20.sp)
        Spacer(Modifier.weight(1f))
        Text(a.name, color = Color.White.copy(alpha = 0.9f), style = MaterialTheme.typography.labelMedium, maxLines = 1, overflow = TextOverflow.Ellipsis)
        AmountText(value, color = Color.White, style = MaterialTheme.typography.titleSmall)
    }
}

@Composable
private fun BigTile(a: Account, value: Double, open: (Account) -> Unit) {
    val desc = stringResource(R.string.account_value_desc, a.name, LocalFmt.current.money(value))
    Column(
        Modifier
            .fillMaxWidth()
            .height(176.dp)
            .pressable(0.97f) { open(a) }
            .clip(RoundedCornerShape(30.dp))
            .background(gradient(a))
            .border(1.dp, Color.White.copy(alpha = 0.18f), RoundedCornerShape(30.dp))
            .semantics(mergeDescendants = true) { contentDescription = desc }
            .padding(20.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(a.icon, fontSize = 36.sp, modifier = Modifier.weight(1f))
            Text(
                stringResource(accountTypeLabel(a)), color = Color.White, style = MaterialTheme.typography.labelMedium,
                modifier = Modifier.clip(CircleShape).background(Color.White.copy(alpha = 0.2f)).padding(horizontal = 10.dp, vertical = 5.dp),
            )
        }
        Spacer(Modifier.weight(1f))
        Text(a.name, color = Color.White.copy(alpha = 0.9f), style = MaterialTheme.typography.titleMedium)
        AmountText(value, color = Color.White, style = MaterialTheme.typography.headlineMedium)
    }
}

fun accountTypeLabel(a: Account): Int = when (a.type) {
    AccountType.CORRIENTE -> R.string.acc_corriente
    AccountType.AHORRO -> R.string.acc_ahorro
    AccountType.EFECTIVO -> R.string.acc_efectivo
    AccountType.TARJETA -> R.string.acc_tarjeta
    AccountType.EXCHANGE -> R.string.acc_exchange
    AccountType.BROKER -> R.string.acc_broker
    AccountType.ACTIVO -> R.string.acc_activo
    AccountType.DEUDA -> R.string.acc_deuda
    AccountType.OTRO -> R.string.acc_otro
}

// MARK: horas trabajadas

@Composable
private fun WorkCard(l: Ledger, open: () -> Unit) {
    val f = LocalFmt.current
    val c = CaudalTheme.colors
    val w = remember(l) { Hours.summary(Hours.shifts(l.data.shifts, Day.monthKey(Day.today)), l.data.companies) }
    Card(onClick = open) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.Work, null, tint = c.accent)
            Spacer(Modifier.width(8.dp))
            Text(stringResource(R.string.work_of_month, f.month(Day.today).lowercase(f.locale)), style = MaterialTheme.typography.titleLarge, modifier = Modifier.weight(1f))
            Icon(Icons.AutoMirrored.Filled.ArrowForwardIos, null, Modifier.size(14.dp), tint = c.textDim)
        }
        Spacer(Modifier.height(12.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            WorkItem(Modifier.weight(1f), stringResource(R.string.hours_h, f.hoursDec(w.totalMin)), null, stringResource(R.string.worked))
            WorkItem(Modifier.weight(1f), null, w.net, stringResource(R.string.net_estimated))
            WorkItem(Modifier.weight(1f), null, w.pendingNet, stringResource(R.string.pending_short), warn = w.pendingNet > 0)
        }
    }
}

@Composable
private fun WorkItem(modifier: Modifier, text: String?, v: Double?, label: String, warn: Boolean = false) {
    val c = CaudalTheme.colors
    Column(modifier.clip(RoundedCornerShape(18.dp)).background(c.cardAlt).padding(10.dp).semantics(mergeDescendants = true) {}) {
        if (text != null) Text(text, style = MaterialTheme.typography.titleMedium)
        if (v != null) AmountText(v, style = MaterialTheme.typography.titleMedium, color = if (warn) c.warning else Color.Unspecified)
        Text(label, style = MaterialTheme.typography.labelSmall, color = c.textDim)
    }
}

// MARK: el mes

@Composable
private fun MonthCard(l: Ledger) {
    val f = LocalFmt.current
    val c = CaudalTheme.colors
    val start = l.periodStart(Day.today)
    val r = l.periodRange(start)
    val spent = l.spent(r)
    val earned = l.earned(r)
    val cmp = remember(l) { l.monthComparison() }
    val budget = l.totalBudget
    Card {
        SectionHeader(f.month(start), emoji = "📅")
        Spacer(Modifier.height(12.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            MonthTile(Modifier.weight(1f), stringResource(R.string.spent), spent, Icons.AutoMirrored.Filled.TrendingDown, c.negative)
            MonthTile(Modifier.weight(1f), stringResource(R.string.earned), earned, Icons.AutoMirrored.Filled.TrendingUp, c.income)
        }
        Spacer(Modifier.height(14.dp))
        Row(Modifier.semantics(mergeDescendants = true) {}, verticalAlignment = Alignment.CenterVertically) {
            Text(stringResource(R.string.month_balance), color = c.textDim, modifier = Modifier.weight(1f))
            AmountText(earned - spent, signed = true, style = MaterialTheme.typography.titleMedium, color = if (earned - spent >= 0) c.income else c.negative)
        }
        if (cmp != null) {
            Spacer(Modifier.height(10.dp))
            val less = cmp <= 0
            Text(
                (if (less) "👍 " else "⚠️ ") + stringResource(if (less) R.string.vs_last_month_less else R.string.vs_last_month_more, f.num(abs(cmp))),
                style = MaterialTheme.typography.bodySmall, color = if (less) c.income else c.warning,
            )
        }
        if (budget > 0) {
            Spacer(Modifier.height(14.dp))
            Row(Modifier.semantics(mergeDescendants = true) {}, verticalAlignment = Alignment.CenterVertically) {
                Text(stringResource(R.string.budget), style = MaterialTheme.typography.labelLarge, modifier = Modifier.weight(1f))
                Text(stringResource(R.string.budget_of, f.money(spent), f.money(budget)), style = MaterialTheme.typography.bodySmall, color = c.textDim)
            }
            Spacer(Modifier.height(6.dp))
            ProgressBar(spent / budget, es.david.caudal.ui.common.budgetColor(spent, budget, c.accent, c.warning, c.negative))
        }
    }
}

@Composable
private fun MonthTile(modifier: Modifier, label: String, v: Double, icon: ImageVector, color: Color) {
    Column(
        modifier.clip(RoundedCornerShape(20.dp)).background(color.copy(alpha = 0.1f)).padding(14.dp).semantics(mergeDescendants = true) {},
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Box(Modifier.size(30.dp).clip(CircleShape).background(color.copy(alpha = 0.2f)), contentAlignment = Alignment.Center) { Icon(icon, null, tint = color, modifier = Modifier.size(18.dp)) }
        Text(label, style = MaterialTheme.typography.labelMedium, color = CaudalTheme.colors.textDim)
        AmountText(v, style = MaterialTheme.typography.titleLarge, rolling = true)
    }
}

// MARK: en qué gastas

@Composable
private fun CategoriesCard(l: Ledger, openStats: () -> Unit) {
    val r = l.periodRange(l.periodStart(Day.today))
    val cats = remember(l) { l.byCategory(r).take(6) }
    val total = cats.sumOf { it.total }.coerceAtLeast(0.01)
    val noCat = stringResource(R.string.no_category)
    val c = CaudalTheme.colors
    Card {
        SectionHeader(stringResource(R.string.where_you_spend), stringResource(R.string.analysis), openStats, emoji = "🍩")
        Spacer(Modifier.height(12.dp))
        if (cats.isEmpty()) {
            Text(stringResource(R.string.no_spending), color = c.textDim)
        } else {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Donut(cats.map { Slice(it.total, hexColor(it.cat.color)) }, size = 124.dp, thickness = 22.dp, description = stringResource(R.string.where_you_spend))
                Spacer(Modifier.width(18.dp))
                Column(verticalArrangement = Arrangement.spacedBy(9.dp)) {
                    cats.take(4).forEach { ct ->
                        Row(Modifier.semantics(mergeDescendants = true) {}, verticalAlignment = Alignment.CenterVertically) {
                            Box(Modifier.size(10.dp).clip(CircleShape).background(hexColor(ct.cat.color)))
                            Spacer(Modifier.width(6.dp))
                            Text(ct.cat.icon)
                            Spacer(Modifier.width(6.dp))
                            Text(ct.cat.name.ifEmpty { noCat }, style = MaterialTheme.typography.bodyMedium, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
                            Text(stringResource(R.string.percent_int, (ct.total / total * 100).roundToInt()), style = MaterialTheme.typography.labelMedium, color = c.textDim)
                        }
                    }
                }
            }
        }
    }
}

// MARK: próximos cargos

@Composable
private fun UpcomingCard(l: Ledger) {
    val f = LocalFmt.current
    val c = CaudalTheme.colors
    val up = remember(l) { l.upcoming(21).take(4) }
    if (up.isEmpty()) return
    Card {
        SectionHeader(stringResource(R.string.upcoming), emoji = "⏰")
        Spacer(Modifier.height(6.dp))
        up.forEachIndexed { i, u ->
            Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).semantics(mergeDescendants = true) {}, verticalAlignment = Alignment.CenterVertically) {
                val invest = u.r.type == "invest"
                Box(Modifier.size(42.dp).clip(RoundedCornerShape(14.dp)).background((if (invest) c.income else c.accent).copy(alpha = 0.18f)), contentAlignment = Alignment.Center) {
                    Icon(if (invest) Icons.Filled.ShowChart else Icons.Filled.CalendarMonth, null, tint = if (invest) c.income else c.accent)
                }
                Spacer(Modifier.width(12.dp))
                Column(Modifier.weight(1f)) {
                    Text(u.r.name, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.ExtraBold)
                    Text(f.header(u.date), style = MaterialTheme.typography.bodySmall, color = c.textDim)
                }
                AmountText(-Money.fromCents(u.r.amount), weight = FontWeight.ExtraBold)
            }
            if (i < up.lastIndex) RowDivider(54.dp)
        }
    }
}

// MARK: últimos movimientos

@Composable
private fun RecentCard(l: Ledger, onTx: (String) -> Unit, onAll: () -> Unit) {
    val recent = remember(l) { l.data.txs.sortedByDescending { it.sortKey }.take(6) }
    Card(padding = 6.dp) {
        Box(Modifier.padding(horizontal = 12.dp, vertical = 8.dp)) { SectionHeader(stringResource(R.string.recent), stringResource(R.string.see_all), onAll, emoji = "🧾") }
        if (recent.isEmpty()) {
            es.david.caudal.ui.common.EmptyState(stringResource(R.string.no_movements), mood = Mood.SLEEPY)
        }
        recent.forEachIndexed { i, t ->
            TxRow(t, l, showDate = true, onClick = { onTx(t.id) })
            if (i < recent.lastIndex) RowDivider(72.dp)
        }
    }
}

// MARK: inversiones y cuentas claras

@Composable
private fun InvestCard(l: Ledger, open: () -> Unit) {
    val f = LocalFmt.current
    val c = CaudalTheme.colors
    val assets = remember(l) { l.data.assets.filter { !it.archived }.sortedByDescending { l.assetValue(it) } }
    Card {
        SectionHeader(stringResource(R.string.investments), stringResource(R.string.see), open, emoji = "📈")
        AmountText(l.investValue, style = MaterialTheme.typography.headlineSmall, rolling = true)
        Spacer(Modifier.height(8.dp))
        if (assets.isEmpty()) Text(stringResource(R.string.no_investments), color = c.textDim)
        assets.take(4).forEach { a ->
            Row(Modifier.fillMaxWidth().padding(vertical = 5.dp).semantics(mergeDescendants = true) {}, verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.size(10.dp).clip(CircleShape).background(hexColor(a.color)))
                Spacer(Modifier.width(8.dp))
                Text(a.name, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                l.dayChange(a)?.let { ch ->
                    Text(f.pct(ch), style = MaterialTheme.typography.labelMedium, color = if (ch >= 0) c.income else c.negative)
                    Spacer(Modifier.width(8.dp))
                }
                AmountText(l.assetValue(a), weight = FontWeight.ExtraBold)
            }
        }
    }
}

@Composable
private fun DebtsCard(l: Ledger, open: () -> Unit) {
    val c = CaudalTheme.colors
    val d = l.data
    val people = remember(l) { Debts.sorted(d.people, d.debts).filter { Debts.balance(d.debts, it.id) != 0L } }
    Card {
        SectionHeader(stringResource(R.string.home_deudas), stringResource(R.string.see), open, emoji = "🤝")
        Spacer(Modifier.height(8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            MonthTile(Modifier.weight(1f), stringResource(R.string.owed_to_me), Money.fromCents(Debts.owedToMe(d.people, d.debts)), Icons.AutoMirrored.Filled.TrendingDown, c.income)
            MonthTile(Modifier.weight(1f), stringResource(R.string.i_owe), Money.fromCents(Debts.iOwe(d.people, d.debts)), Icons.AutoMirrored.Filled.TrendingUp, c.negative)
        }
        Spacer(Modifier.height(8.dp))
        people.take(4).forEach { p ->
            val b = Money.fromCents(Debts.balance(d.debts, p.id))
            Row(Modifier.fillMaxWidth().padding(vertical = 5.dp).semantics(mergeDescendants = true) {}, verticalAlignment = Alignment.CenterVertically) {
                IconBubble(p.emoji, p.color, 34.dp)
                Spacer(Modifier.width(10.dp))
                Text(p.name, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                AmountText(b, signed = true, weight = FontWeight.ExtraBold, color = if (b >= 0) c.income else c.negative)
            }
        }
    }
}

/** dos páginas por pantalla (el carrusel de cuentas) */
private val TwoPerPage = object : PageSize {
    override fun Density.calculateMainAxisPageSize(availableSpace: Int, pageSpacing: Int) = (availableSpace - pageSpacing) / 2
}
