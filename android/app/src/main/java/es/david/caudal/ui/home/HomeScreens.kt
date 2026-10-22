package es.david.caudal.ui.home

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.lazy.items
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
import androidx.compose.material.icons.filled.ThumbUp
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.filled.Work
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
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
import es.david.caudal.domain.calc.Ledger
import es.david.caudal.domain.model.Account
import es.david.caudal.domain.model.AccountsStyle
import es.david.caudal.domain.model.AppSettings
import es.david.caudal.ui.charts.Donut
import es.david.caudal.ui.charts.LineChart
import es.david.caudal.ui.charts.Slice
import es.david.caudal.ui.common.AmountText
import es.david.caudal.ui.common.Card
import es.david.caudal.ui.common.FinanceViewModel
import es.david.caudal.ui.common.IconBubble
import es.david.caudal.ui.common.LocalFmt
import es.david.caudal.ui.common.ProgressBar
import es.david.caudal.ui.common.ScreenScaffold
import es.david.caudal.ui.common.SectionHeader
import es.david.caudal.ui.common.TxRow
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
    val f = LocalFmt.current
    val h = rememberHaptics()
    ScreenScaffold(
        title = greeting(s.name),
        actions = {
            IconButton(onClick = { h.tap(); onToggleHidden() }) {
                Icon(
                    if (f.hidden) Icons.Filled.VisibilityOff else Icons.Filled.Visibility,
                    stringResource(if (f.hidden) R.string.show_amounts else R.string.hide_amounts),
                )
            }
        },
    ) { pad ->
        val cards = s.home.filter { it.on }.map { it.id }.filter { id ->
            when (id) {
                "horas" -> s.moduleWork && l.data.companies.isNotEmpty()
                "inversiones" -> s.moduleInvest
                "deudas" -> s.moduleDebts
                else -> true
            }
        }
        LazyColumn(
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = pad.calculateTopPadding() + 4.dp, bottom = 96.dp),
            verticalArrangement = Arrangement.spacedBy(22.dp),
        ) {
            items(cards, key = { it }) { id ->
                Box(Modifier.animateItem()) {
                    when (id) {
                        "patrimonio" -> NetWorthCard(l)
                        "cuentas" -> AccountsCard(l, s, vm, nav)
                        "horas" -> WorkCard(l) { nav.navigate(WorkRoute) }
                        "mes" -> MonthCard(l)
                        "categorias" -> CategoriesCard(l) { nav.navigate(StatsRoute) }
                        "proximos" -> UpcomingCard(l)
                        "recientes" -> RecentCard(l, onTx = { nav.navigate(TxEditorRoute(id = it)) }, onAll = { nav.navigateTab(TxsRoute) })
                        "inversiones" -> InvestCard(l) { nav.navigateTab(InvestRoute) }
                        "deudas" -> DebtsCard(l) { nav.navigateTab(DebtsRoute) }
                    }
                }
            }
            item(key = "personalizar") {
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(18.dp))
                        .background(CaudalTheme.colors.card)
                        .clickable { h.tap(); nav.navigate(HomeCustomizeRoute) }
                        .heightIn(min = 52.dp)
                        .padding(14.dp),
                    horizontalArrangement = Arrangement.Center,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.Filled.Dashboard, null, tint = MaterialTheme.colorScheme.primary)
                    Spacer(Modifier.width(8.dp))
                    Text(stringResource(R.string.customize_home), fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }
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

// MARK: patrimonio con gráfico de 30 días

@Composable
private fun NetWorthCard(l: Ledger) {
    val f = LocalFmt.current
    val h = rememberHaptics()
    val series = remember(l) { l.netWorthSeries(30) }
    var selected by remember { mutableStateOf<Int?>(null) }
    val now = l.netWorth
    val first = series.firstOrNull()?.value ?: 0.0
    val diff = now - first
    val point = selected?.let { series.getOrNull(it) }
    val colors = CaudalTheme.colors
    Card(padding = 20.dp) {
        Text(point?.let { f.header(it.date) } ?: stringResource(R.string.net_worth), style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        AmountText(point?.value ?: now, style = MaterialTheme.typography.displaySmall.copy(fontSize = 40.sp), weight = FontWeight.Bold)
        Row(verticalAlignment = Alignment.CenterVertically) {
            val c = if (diff >= 0) colors.income else colors.negative
            Icon(if (diff >= 0) Icons.AutoMirrored.Filled.TrendingUp else Icons.AutoMirrored.Filled.TrendingDown, null, tint = c, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(6.dp))
            AmountText(diff, signed = true, color = c, weight = FontWeight.SemiBold, style = MaterialTheme.typography.bodyMedium)
            Spacer(Modifier.width(6.dp))
            Text(stringResource(R.string.in_30_days), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Spacer(Modifier.height(8.dp))
        LineChart(
            values = series.map { it.value },
            color = MaterialTheme.colorScheme.primary,
            height = 130.dp,
            selected = selected,
            description = stringResource(R.string.net_worth_chart),
            onSelect = { if (it != null && it != selected) h.select(); selected = it },
        )
        Spacer(Modifier.height(10.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Stat(stringResource(R.string.cash), l.cashTotal, Modifier.weight(1f))
            Box(Modifier.width(1.dp).height(30.dp).background(MaterialTheme.colorScheme.outlineVariant))
            Spacer(Modifier.width(12.dp))
            Stat(stringResource(R.string.investments), l.investValue, Modifier.weight(1f))
        }
    }
}

@Composable
private fun Stat(label: String, v: Double, modifier: Modifier = Modifier) {
    Column(modifier.semantics(mergeDescendants = true) {}) {
        Text(label, style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurfaceVariant)
        AmountText(v, style = MaterialTheme.typography.titleMedium, weight = FontWeight.SemiBold)
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
            Text(stringResource(R.string.accounts), style = MaterialTheme.typography.titleLarge, modifier = Modifier.weight(1f))
            Box {
                IconButton(onClick = { menu = true }) { Icon(Icons.Filled.Dashboard, stringResource(R.string.accounts_style)) }
                DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                    AccountsStyle.entries.forEach { st ->
                        DropdownMenuItem(
                            text = { Text(stringResource(styleLabel(st)), fontWeight = if (st == s.accountsStyle) FontWeight.Bold else null) },
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
            AccountsStyle.CUADRICULA -> Grid(accounts, 2) { AccountTile(it, l.value(it), 118, open) }
            AccountsStyle.PEQUENO -> Grid(accounts, 3) { SmallTile(it, l.value(it), open) }
            AccountsStyle.GRANDE -> Column(verticalArrangement = Arrangement.spacedBy(12.dp)) { accounts.forEach { BigTile(it, l.value(it), open) } }
            AccountsStyle.LISTA -> Card(padding = 12.dp) {
                accounts.forEachIndexed { i, a ->
                    val desc = stringResource(R.string.account_value_desc, a.name, LocalFmt.current.money(l.value(a)))
                    Row(
                        Modifier.fillMaxWidth().heightIn(min = 52.dp).clickable { open(a) }.padding(vertical = 8.dp).semantics(mergeDescendants = true) { contentDescription = desc },
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        IconBubble(a.icon, a.color, 38.dp)
                        Spacer(Modifier.width(12.dp))
                        Text(a.name, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                        AmountText(l.value(a), weight = FontWeight.SemiBold)
                    }
                    if (i < accounts.lastIndex) HorizontalDivider(Modifier.padding(start = 50.dp), color = MaterialTheme.colorScheme.outlineVariant)
                }
            }
            AccountsStyle.CARRUSEL -> {
                // dos cuentas por pantalla, sin que asome la siguiente
                val pager = rememberPagerState { accounts.size }
                HorizontalPager(
                    state = pager,
                    pageSize = TwoPerPage,
                    pageSpacing = 12.dp,
                    modifier = Modifier.fillMaxWidth(),
                ) { i -> AccountTile(accounts[i], l.value(accounts[i]), 128, open) }
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
    return Brush.linearGradient(listOf(c.copy(alpha = 0.95f), c.copy(alpha = 0.45f)))
}

@Composable
private fun AccountTile(a: Account, value: Double, height: Int, open: (Account) -> Unit) {
    val desc = stringResource(R.string.account_value_desc, a.name, LocalFmt.current.money(value))
    Column(
        Modifier
            .fillMaxWidth()
            .height(height.dp)
            .clip(RoundedCornerShape(24.dp))
            .background(gradient(a))
            .border(1.dp, Color.White.copy(alpha = 0.15f), RoundedCornerShape(24.dp))
            .clickable { open(a) }
            .semantics(mergeDescendants = true) { contentDescription = desc }
            .padding(16.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(a.icon, fontSize = 24.sp, modifier = Modifier.weight(1f))
            Icon(Icons.AutoMirrored.Filled.ArrowForwardIos, null, tint = Color.White.copy(alpha = 0.6f), modifier = Modifier.size(12.dp))
        }
        Spacer(Modifier.weight(1f))
        Text(a.name, color = Color.White.copy(alpha = 0.85f), fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
        AmountText(value, color = Color.White, weight = FontWeight.Bold, style = MaterialTheme.typography.titleLarge)
    }
}

@Composable
private fun SmallTile(a: Account, value: Double, open: (Account) -> Unit) {
    val desc = stringResource(R.string.account_value_desc, a.name, LocalFmt.current.money(value))
    Column(
        Modifier
            .fillMaxWidth()
            .height(92.dp)
            .clip(RoundedCornerShape(18.dp))
            .background(gradient(a))
            .clickable { open(a) }
            .semantics(mergeDescendants = true) { contentDescription = desc }
            .padding(11.dp),
    ) {
        Text(a.icon, fontSize = 20.sp)
        Spacer(Modifier.weight(1f))
        Text(a.name, color = Color.White.copy(alpha = 0.85f), style = MaterialTheme.typography.labelMedium, maxLines = 1, overflow = TextOverflow.Ellipsis)
        AmountText(value, color = Color.White, weight = FontWeight.Bold, style = MaterialTheme.typography.bodyMedium)
    }
}

@Composable
private fun BigTile(a: Account, value: Double, open: (Account) -> Unit) {
    val desc = stringResource(R.string.account_value_desc, a.name, LocalFmt.current.money(value))
    Column(
        Modifier
            .fillMaxWidth()
            .height(170.dp)
            .clip(RoundedCornerShape(26.dp))
            .background(gradient(a))
            .border(1.dp, Color.White.copy(alpha = 0.15f), RoundedCornerShape(26.dp))
            .clickable { open(a) }
            .semantics(mergeDescendants = true) { contentDescription = desc }
            .padding(20.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(a.icon, fontSize = 34.sp, modifier = Modifier.weight(1f))
            Text(
                stringResource(accountTypeLabel(a)), color = Color.White, style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Bold,
                modifier = Modifier.clip(CircleShape).background(Color.White.copy(alpha = 0.18f)).padding(horizontal = 10.dp, vertical = 5.dp),
            )
        }
        Spacer(Modifier.weight(1f))
        Text(a.name, color = Color.White.copy(alpha = 0.85f), style = MaterialTheme.typography.titleMedium)
        AmountText(value, color = Color.White, weight = FontWeight.Bold, style = MaterialTheme.typography.headlineMedium)
    }
}

fun accountTypeLabel(a: Account): Int = when (a.type) {
    es.david.caudal.domain.model.AccountType.CORRIENTE -> R.string.acc_corriente
    es.david.caudal.domain.model.AccountType.AHORRO -> R.string.acc_ahorro
    es.david.caudal.domain.model.AccountType.EFECTIVO -> R.string.acc_efectivo
    es.david.caudal.domain.model.AccountType.TARJETA -> R.string.acc_tarjeta
    es.david.caudal.domain.model.AccountType.EXCHANGE -> R.string.acc_exchange
    es.david.caudal.domain.model.AccountType.BROKER -> R.string.acc_broker
    es.david.caudal.domain.model.AccountType.ACTIVO -> R.string.acc_activo
    es.david.caudal.domain.model.AccountType.DEUDA -> R.string.acc_deuda
    es.david.caudal.domain.model.AccountType.OTRO -> R.string.acc_otro
}

// MARK: horas trabajadas

@Composable
private fun WorkCard(l: Ledger, open: () -> Unit) {
    val f = LocalFmt.current
    val w = remember(l) { Hours.summary(Hours.shifts(l.data.shifts, Day.monthKey(Day.today)), l.data.companies) }
    Box(Modifier.clip(RoundedCornerShape(22.dp)).clickable(onClick = open)) {
        Card {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Filled.Work, null, tint = MaterialTheme.colorScheme.primary)
                Spacer(Modifier.width(8.dp))
                Text(stringResource(R.string.work_of_month, f.month(Day.today).lowercase(f.locale)), style = MaterialTheme.typography.titleLarge, modifier = Modifier.weight(1f))
                Icon(Icons.AutoMirrored.Filled.ArrowForwardIos, null, Modifier.size(14.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Spacer(Modifier.height(12.dp))
            Row {
                WorkItem(Modifier.weight(1f), stringResource(R.string.hours_h, f.hoursDec(w.totalMin)), null, stringResource(R.string.worked))
                WorkItem(Modifier.weight(1f), null, w.net, stringResource(R.string.net_estimated))
                WorkItem(Modifier.weight(1f), null, w.pendingNet, stringResource(R.string.pending_short), warn = w.pendingNet > 0)
            }
        }
    }
}

@Composable
private fun WorkItem(modifier: Modifier, text: String?, v: Double?, label: String, warn: Boolean = false) {
    Column(modifier.semantics(mergeDescendants = true) {}) {
        if (text != null) Text(text, style = MaterialTheme.typography.titleLarge)
        if (v != null) AmountText(v, style = MaterialTheme.typography.titleLarge, weight = FontWeight.Bold, color = if (warn) CaudalTheme.colors.warning else Color.Unspecified)
        Text(label, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

// MARK: el mes

@Composable
private fun MonthCard(l: Ledger) {
    val f = LocalFmt.current
    val colors = CaudalTheme.colors
    val start = l.periodStart(Day.today)
    val r = l.periodRange(start)
    val spent = l.spent(r)
    val earned = l.earned(r)
    val cmp = remember(l) { l.monthComparison() }
    val budget = l.totalBudget
    Card {
        SectionHeader(f.month(start))
        Spacer(Modifier.height(12.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            MonthTile(Modifier.weight(1f), stringResource(R.string.spent), spent, Icons.AutoMirrored.Filled.TrendingDown, colors.negative)
            MonthTile(Modifier.weight(1f), stringResource(R.string.earned), earned, Icons.AutoMirrored.Filled.TrendingUp, colors.income)
        }
        Spacer(Modifier.height(14.dp))
        Row(Modifier.semantics(mergeDescendants = true) {}, verticalAlignment = Alignment.CenterVertically) {
            Text(stringResource(R.string.month_balance), color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.weight(1f))
            AmountText(earned - spent, signed = true, style = MaterialTheme.typography.titleMedium, color = if (earned - spent >= 0) colors.income else colors.negative)
        }
        if (cmp != null) {
            Spacer(Modifier.height(12.dp))
            val less = cmp <= 0
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(if (less) Icons.Filled.ThumbUp else Icons.Filled.Warning, null, tint = if (less) colors.income else colors.warning, modifier = Modifier.size(16.dp))
                Spacer(Modifier.width(6.dp))
                Text(
                    stringResource(if (less) R.string.vs_last_month_less else R.string.vs_last_month_more, f.num(abs(cmp))),
                    style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.Medium, color = if (less) colors.income else colors.warning,
                )
            }
        }
        if (budget > 0) {
            Spacer(Modifier.height(14.dp))
            Row(Modifier.semantics(mergeDescendants = true) {}, verticalAlignment = Alignment.CenterVertically) {
                Text(stringResource(R.string.budget), fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                Text(stringResource(R.string.budget_of, f.money(spent), f.money(budget)), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Spacer(Modifier.height(6.dp))
            ProgressBar(spent / budget, if (spent > budget) colors.negative else MaterialTheme.colorScheme.primary)
        }
    }
}

@Composable
private fun MonthTile(modifier: Modifier, label: String, v: Double, icon: androidx.compose.ui.graphics.vector.ImageVector, color: Color) {
    Column(
        modifier.clip(RoundedCornerShape(18.dp)).background(CaudalTheme.colors.cardAlt).padding(14.dp).semantics(mergeDescendants = true) {},
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Icon(icon, null, tint = color)
        Text(label, style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurfaceVariant)
        AmountText(v, style = MaterialTheme.typography.titleLarge, weight = FontWeight.Bold)
    }
}

// MARK: en qué gastas

@Composable
private fun CategoriesCard(l: Ledger, openStats: () -> Unit) {
    val r = l.periodRange(l.periodStart(Day.today))
    val cats = remember(l) { l.byCategory(r).take(6) }
    val total = cats.sumOf { it.total }.coerceAtLeast(0.01)
    val noCat = stringResource(R.string.no_category)
    Card {
        SectionHeader(stringResource(R.string.where_you_spend), stringResource(R.string.analysis), openStats)
        Spacer(Modifier.height(12.dp))
        if (cats.isEmpty()) {
            Text(stringResource(R.string.no_spending), color = MaterialTheme.colorScheme.onSurfaceVariant)
        } else {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Donut(cats.map { Slice(it.total, hexColor(it.cat.color)) }, size = 120.dp, thickness = 20.dp, description = stringResource(R.string.where_you_spend))
                Spacer(Modifier.width(18.dp))
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    cats.take(4).forEach { c ->
                        Row(Modifier.semantics(mergeDescendants = true) {}, verticalAlignment = Alignment.CenterVertically) {
                            Text(c.cat.icon)
                            Spacer(Modifier.width(8.dp))
                            Text(c.cat.name.ifEmpty { noCat }, style = MaterialTheme.typography.bodyMedium, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
                            Text(stringResource(R.string.percent_int, (c.total / total * 100).roundToInt()), style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurfaceVariant)
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
    val up = remember(l) { l.upcoming(21).take(4) }
    if (up.isEmpty()) return
    Card {
        SectionHeader(stringResource(R.string.upcoming))
        Spacer(Modifier.height(8.dp))
        up.forEach { u ->
            Row(Modifier.fillMaxWidth().heightIn(min = 52.dp).semantics(mergeDescendants = true) {}, verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    if (u.r.type == "invest") Icons.Filled.ShowChart else Icons.Filled.CalendarMonth, null,
                    tint = if (u.r.type == "invest") CaudalTheme.colors.income else MaterialTheme.colorScheme.primary, modifier = Modifier.size(30.dp),
                )
                Spacer(Modifier.width(12.dp))
                Column(Modifier.weight(1f)) {
                    Text(u.r.name, fontWeight = FontWeight.SemiBold)
                    Text(f.header(u.date), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                AmountText(-Money.fromCents(u.r.amount), weight = FontWeight.SemiBold)
            }
        }
    }
}

// MARK: últimos movimientos

@Composable
private fun RecentCard(l: Ledger, onTx: (String) -> Unit, onAll: () -> Unit) {
    val recent = remember(l) { l.data.txs.sortedByDescending { it.sortKey }.take(6) }
    Card {
        SectionHeader(stringResource(R.string.recent), stringResource(R.string.see_all), onAll)
        if (recent.isEmpty()) Text(stringResource(R.string.no_movements), color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(4.dp))
        recent.forEachIndexed { i, t ->
            TxRow(t, l, showDate = true, onClick = { onTx(t.id) })
            if (i < recent.lastIndex) HorizontalDivider(Modifier.padding(start = 58.dp), color = MaterialTheme.colorScheme.outlineVariant)
        }
    }
}

// MARK: inversiones y cuentas claras

@Composable
private fun InvestCard(l: Ledger, open: () -> Unit) {
    val f = LocalFmt.current
    val assets = remember(l) { l.data.assets.filter { !it.archived }.sortedByDescending { l.assetValue(it) } }
    Card {
        SectionHeader(stringResource(R.string.investments), stringResource(R.string.see), open)
        AmountText(l.investValue, style = MaterialTheme.typography.headlineSmall, weight = FontWeight.Bold)
        Spacer(Modifier.height(8.dp))
        if (assets.isEmpty()) Text(stringResource(R.string.no_investments), color = MaterialTheme.colorScheme.onSurfaceVariant)
        assets.take(4).forEach { a ->
            Row(Modifier.fillMaxWidth().padding(vertical = 4.dp).semantics(mergeDescendants = true) {}, verticalAlignment = Alignment.CenterVertically) {
                Text(a.name, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                l.dayChange(a)?.let { ch ->
                    Text(f.pct(ch), style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Bold, color = if (ch >= 0) CaudalTheme.colors.income else CaudalTheme.colors.negative)
                    Spacer(Modifier.width(8.dp))
                }
                AmountText(l.assetValue(a), weight = FontWeight.SemiBold)
            }
        }
    }
}

@Composable
private fun DebtsCard(l: Ledger, open: () -> Unit) {
    val colors = CaudalTheme.colors
    val d = l.data
    val people = remember(l) { Debts.sorted(d.people, d.debts).filter { Debts.balance(d.debts, it.id) != 0L } }
    Card {
        SectionHeader(stringResource(R.string.home_deudas), stringResource(R.string.see), open)
        Spacer(Modifier.height(8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            MonthTile(Modifier.weight(1f), stringResource(R.string.owed_to_me), Money.fromCents(Debts.owedToMe(d.people, d.debts)), Icons.AutoMirrored.Filled.TrendingDown, colors.income)
            MonthTile(Modifier.weight(1f), stringResource(R.string.i_owe), Money.fromCents(Debts.iOwe(d.people, d.debts)), Icons.AutoMirrored.Filled.TrendingUp, colors.negative)
        }
        Spacer(Modifier.height(8.dp))
        people.take(4).forEach { p ->
            val b = Money.fromCents(Debts.balance(d.debts, p.id))
            Row(Modifier.fillMaxWidth().padding(vertical = 4.dp).semantics(mergeDescendants = true) {}, verticalAlignment = Alignment.CenterVertically) {
                Text(p.emoji)
                Spacer(Modifier.width(8.dp))
                Text(p.name, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                AmountText(b, signed = true, weight = FontWeight.SemiBold, color = if (b >= 0) colors.income else colors.negative)
            }
        }
    }
}

/** dos páginas por pantalla (el carrusel de cuentas) */
private val TwoPerPage = object : PageSize {
    override fun androidx.compose.ui.unit.Density.calculateMainAxisPageSize(availableSpace: Int, pageSpacing: Int) = (availableSpace - pageSpacing) / 2
}
