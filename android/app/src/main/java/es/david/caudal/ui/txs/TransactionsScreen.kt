package es.david.caudal.ui.txs

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.TrendingDown
import androidx.compose.material.icons.automirrored.filled.TrendingUp
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.FilterList
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Text
import androidx.compose.material3.rememberSwipeToDismissBoxState
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import androidx.paging.compose.collectAsLazyPagingItems
import es.david.caudal.R
import es.david.caudal.core.Money
import es.david.caudal.domain.calc.Ledger
import es.david.caudal.domain.model.Tx
import es.david.caudal.domain.model.TxType
import es.david.caudal.ui.common.AmountText
import es.david.caudal.ui.common.CircleIconButton
import es.david.caudal.ui.common.ConfirmDialog
import es.david.caudal.ui.common.EmptyState
import es.david.caudal.ui.common.Gotita
import es.david.caudal.ui.common.LocalFmt
import es.david.caudal.ui.common.LocalMascot
import es.david.caudal.ui.common.Mood
import es.david.caudal.ui.common.Pill
import es.david.caudal.ui.common.RowDivider
import es.david.caudal.ui.common.ScreenScaffold
import es.david.caudal.ui.common.TxRow
import es.david.caudal.ui.common.appear
import es.david.caudal.ui.common.contentOn
import es.david.caudal.ui.common.pressable
import es.david.caudal.ui.common.rememberHaptics
import es.david.caudal.ui.common.txTypeLabel
import es.david.caudal.ui.nav.CalendarRoute
import es.david.caudal.ui.nav.TxEditorRoute
import es.david.caudal.ui.nav.WrappedRoute
import es.david.caudal.ui.theme.CaudalTheme
import kotlinx.coroutines.launch
import kotlin.math.abs

@Composable
fun TransactionsScreen(nav: NavController) {
    val vm: TransactionsViewModel = hiltViewModel()
    val filter by vm.filter.collectAsStateWithLifecycle()
    val months by vm.months.collectAsStateWithLifecycle()
    val totals by vm.dayTotals.collectAsStateWithLifecycle()
    val sums by vm.sums.collectAsStateWithLifecycle()
    val ledger by vm.ledger.collectAsStateWithLifecycle()
    val items = vm.pages.collectAsLazyPagingItems()
    val f = LocalFmt.current
    val h = rememberHaptics()
    val c = CaudalTheme.colors
    var pendingDelete by remember { mutableStateOf<Tx?>(null) }
    var filterMenu by remember { mutableStateOf(false) }
    val l = ledger ?: return

    ScreenScaffold(
        title = stringResource(R.string.tab_txs),
        actions = {
            CircleIconButton(Icons.Filled.CalendarMonth, stringResource(R.string.txs_calendar)) { nav.navigate(CalendarRoute(filter.month)) }
            Box {
                CircleIconButton(
                    Icons.Filled.FilterList, stringResource(R.string.filter),
                    tint = if (filter.type != null || filter.accountId != null) c.accent else c.text,
                ) { filterMenu = true }
                FilterMenu(filterMenu, { filterMenu = false }, filter.type, filter.accountId, l, vm::setType, vm::setAccount)
            }
            Spacer(Modifier.width(8.dp))
        },
    ) { pad ->
        LazyColumn(
            Modifier.fillMaxSize(),
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = pad.calculateTopPadding(), bottom = 150.dp),
        ) {
            item(key = "buscar") { SearchPill(filter.query, vm::setQuery, Modifier.appear(0)) }
            item(key = "meses") {
                MonthChips(months, filter.month, enabled = filter.query.isEmpty(), modifier = Modifier.appear(1)) { h.select(); vm.setMonth(it) }
            }
            item(key = "resumen") {
                Row(Modifier.fillMaxWidth().padding(vertical = 12.dp).appear(2), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    SumPill(Modifier.weight(1f), stringResource(R.string.expenses), Money.fromCents(sums.spent ?: 0), c.negative, Icons.AutoMirrored.Filled.TrendingDown)
                    SumPill(Modifier.weight(1f), stringResource(R.string.incomes), Money.fromCents(sums.earned ?: 0), c.income, Icons.AutoMirrored.Filled.TrendingUp)
                }
            }
            if (filter.query.isEmpty()) item(key = "historias") {
                WrappedBanner(f.month("${filter.month}-01"), Modifier.appear(3)) { h.tap(); nav.navigate(WrappedRoute(filter.month)) }
            }
            if (items.itemCount == 0) item(key = "vacio") {
                if (filter.query.isNotEmpty()) EmptyState(stringResource(R.string.txs_empty_search, filter.query), mood = Mood.WOW)
                else EmptyState(stringResource(R.string.txs_empty_title), stringResource(R.string.txs_empty_text), mood = Mood.SLEEPY)
            }
            items(count = items.itemCount, key = { i -> items.peek(i)?.id ?: i }) { i ->
                val t = items[i] ?: return@items
                val prev = if (i > 0) items.peek(i - 1) else null
                val next = if (i < items.itemCount - 1) items.peek(i + 1) else null
                val first = prev?.date != t.date
                val last = next?.date != t.date
                Column(Modifier.animateItem()) {
                    if (first) DayHeader(f.header(t.date), totals[t.date] ?: 0L)
                    // cada día es una tarjeta: arriba redondeada en el primero, abajo en el último
                    val shape = RoundedCornerShape(
                        topStart = if (first) 24.dp else 0.dp, topEnd = if (first) 24.dp else 0.dp,
                        bottomStart = if (last) 24.dp else 0.dp, bottomEnd = if (last) 24.dp else 0.dp,
                    )
                    Box(Modifier.fillMaxWidth().clip(shape).background(c.card).padding(top = if (first) 4.dp else 0.dp, bottom = if (last) 4.dp else 0.dp)) {
                        Column {
                            SwipeTx(
                                t, l,
                                onOpen = { nav.navigate(TxEditorRoute(id = t.id)) },
                                onDuplicate = { h.success(); vm.duplicate(t) },
                                onDelete = { h.warning(); pendingDelete = t },
                            )
                            if (!last) RowDivider(72.dp)
                        }
                    }
                }
            }
        }
    }

    pendingDelete?.let { t ->
        val title = stringResource(
            when (t.type) {
                TxType.INCOME -> R.string.confirm_delete_income
                TxType.TRANSFER -> R.string.confirm_delete_transfer
                TxType.ADJUST -> R.string.confirm_delete_adjust
                else -> R.string.confirm_delete_expense
            },
        )
        val msg = stringResource(R.string.confirm_delete_tx_msg, t.title.ifEmpty { stringResource(txTypeLabel(t.type)) }, f.plain(Money.fromCents(abs(t.amount))), f.header(t.date))
        ConfirmDialog(title, msg, onConfirm = { h.heavy(); vm.delete(t) }, onDismiss = { pendingDelete = null })
    }
}

/** buscador en píldora, como el de iPhone */
@Composable
private fun SearchPill(query: String, onChange: (String) -> Unit, modifier: Modifier = Modifier) {
    val c = CaudalTheme.colors
    val placeholder = stringResource(R.string.search_txs)
    Row(
        modifier
            .fillMaxWidth()
            .heightIn(min = 50.dp)
            .clip(CircleShape)
            .background(c.card)
            .border(1.dp, c.hairline, CircleShape)
            .padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Filled.Search, null, tint = c.textDim)
        Spacer(Modifier.width(10.dp))
        Box(Modifier.weight(1f), contentAlignment = Alignment.CenterStart) {
            if (query.isEmpty()) Text(placeholder, style = MaterialTheme.typography.bodyLarge, color = c.textDim)
            BasicTextField(
                query, onChange, singleLine = true,
                textStyle = MaterialTheme.typography.bodyLarge.copy(color = c.text),
                cursorBrush = SolidColor(c.accent),
                modifier = Modifier.fillMaxWidth().semantics { contentDescription = placeholder },
            )
        }
        if (query.isNotEmpty()) {
            Box(Modifier.size(40.dp).clip(CircleShape).pressable { onChange("") }, contentAlignment = Alignment.Center) {
                Icon(Icons.Filled.Close, stringResource(R.string.close), tint = c.textDim)
            }
        }
    }
}

@Composable
private fun MonthChips(months: List<String>, selected: String, enabled: Boolean, modifier: Modifier = Modifier, onSelect: (String) -> Unit) {
    val f = LocalFmt.current
    val state = rememberLazyListState()
    LaunchedEffect(months.size) { val i = months.indexOf(selected); if (i >= 0) state.scrollToItem(i) }
    LazyRow(state = state, horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = modifier.padding(top = 12.dp).alpha(if (enabled) 1f else 0.35f)) {
        items(months, key = { it }) { m -> Pill(f.month("$m-01"), m == selected, { onSelect(m) }) }
    }
}

@Composable
private fun SumPill(modifier: Modifier, label: String, v: Double, col: Color, icon: ImageVector) {
    val c = CaudalTheme.colors
    Row(
        modifier.clip(RoundedCornerShape(20.dp)).background(c.card).border(1.dp, c.hairline, RoundedCornerShape(20.dp))
            .padding(12.dp).semantics(mergeDescendants = true) {},
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.size(32.dp).clip(CircleShape).background(col.copy(alpha = 0.18f)), contentAlignment = Alignment.Center) {
            Icon(icon, null, tint = col, modifier = Modifier.size(18.dp))
        }
        Spacer(Modifier.width(10.dp))
        Column {
            Text(label, style = MaterialTheme.typography.labelMedium, color = c.textDim)
            AmountText(v, style = MaterialTheme.typography.titleMedium, rolling = true)
        }
    }
}

/** tarjeta para abrir el resumen del mes en historias */
@Composable
private fun WrappedBanner(month: String, modifier: Modifier = Modifier, onClick: () -> Unit) {
    val c = CaudalTheme.colors
    Row(
        modifier
            .fillMaxWidth()
            .pressable(0.97f, onClick = onClick)
            .clip(RoundedCornerShape(24.dp))
            .background(Brush.linearGradient(listOf(lerp(c.accent, Color.White, 0.15f), lerp(c.accent, c.transfer, 0.55f))))
            .heightIn(min = 72.dp)
            .padding(horizontal = 16.dp, vertical = 12.dp)
            .semantics(mergeDescendants = true) {},
        verticalAlignment = Alignment.CenterVertically,
    ) {
        val fg = contentOn(c.accent)
        if (LocalMascot.current) { Gotita(Mood.LOVE, 48.dp, color = Color.White); Spacer(Modifier.width(10.dp)) } else { Text("✨", fontSize = 28.sp); Spacer(Modifier.width(10.dp)) }
        Column(Modifier.weight(1f)) {
            Text(stringResource(R.string.txs_wrapped_cta), style = MaterialTheme.typography.titleMedium, color = fg)
            Text(stringResource(R.string.txs_wrapped_cta_sub, month), style = MaterialTheme.typography.bodySmall, color = fg.copy(alpha = 0.8f))
        }
        Text("›", fontSize = 28.sp, color = fg, fontWeight = FontWeight.Black)
    }
}

@Composable
private fun DayHeader(label: String, total: Long) {
    val c = CaudalTheme.colors
    Row(
        Modifier.fillMaxWidth().padding(top = 18.dp, bottom = 8.dp, start = 8.dp, end = 8.dp).semantics(mergeDescendants = true) { heading() },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, style = MaterialTheme.typography.titleSmall, color = c.textDim, modifier = Modifier.weight(1f))
        if (total != 0L) AmountText(Money.fromCents(total), signed = true, style = MaterialTheme.typography.labelLarge, color = if (total > 0) c.income else c.textDim)
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun SwipeTx(t: Tx, l: Ledger, onOpen: () -> Unit, onDuplicate: () -> Unit, onDelete: () -> Unit) {
    val scope = rememberCoroutineScope()
    val c = CaudalTheme.colors
    var menu by remember { mutableStateOf(false) }
    val state = rememberSwipeToDismissBoxState()
    val dup = stringResource(R.string.duplicate)
    val del = stringResource(R.string.delete)
    SwipeToDismissBox(
        state = state,
        onDismiss = { v ->
            if (v == SwipeToDismissBoxValue.EndToStart) onDelete() else if (v == SwipeToDismissBoxValue.StartToEnd) onDuplicate()
            scope.launch { state.reset() }
        },
        backgroundContent = {
            val toDelete = state.dismissDirection == SwipeToDismissBoxValue.EndToStart
            Row(
                Modifier.fillMaxSize().background(if (toDelete) c.negative else c.transfer).padding(horizontal = 24.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = if (toDelete) Arrangement.End else Arrangement.Start,
            ) {
                Icon(if (toDelete) Icons.Filled.Delete else Icons.Filled.ContentCopy, null, tint = Color.White)
                Spacer(Modifier.width(8.dp))
                Text(if (toDelete) del else dup, color = Color.White, style = MaterialTheme.typography.labelLarge)
            }
        },
    ) {
        Box(
            Modifier
                .background(c.card)
                .combinedClickable(onClick = onOpen, onLongClick = { menu = true })
                .semantics { customActions = listOf(CustomAccessibilityAction(dup) { onDuplicate(); true }, CustomAccessibilityAction(del) { onDelete(); true }) },
        ) {
            TxRow(t, l)
            DropdownMenu(expanded = menu, onDismissRequest = { menu = false }, shape = RoundedCornerShape(20.dp), containerColor = c.card) {
                DropdownMenuItem(text = { Text(stringResource(R.string.edit)) }, onClick = { menu = false; onOpen() })
                DropdownMenuItem(text = { Text(dup) }, onClick = { menu = false; onDuplicate() })
                DropdownMenuItem(text = { Text(del, color = c.negative) }, onClick = { menu = false; onDelete() })
            }
        }
    }
}

@Composable
private fun FilterMenu(
    expanded: Boolean,
    onDismiss: () -> Unit,
    type: TxType?,
    account: String?,
    l: Ledger,
    setType: (TxType?) -> Unit,
    setAccount: (String?) -> Unit,
) {
    val c = CaudalTheme.colors
    DropdownMenu(expanded = expanded, onDismissRequest = onDismiss, shape = RoundedCornerShape(20.dp), containerColor = c.card) {
        Text(stringResource(R.string.filter_type), style = MaterialTheme.typography.labelMedium, color = c.textDim, modifier = Modifier.padding(horizontal = 16.dp, vertical = 6.dp))
        DropdownMenuItem(text = { Text(stringResource(R.string.all), fontWeight = if (type == null) FontWeight.Black else null) }, onClick = { setType(null) })
        TxType.entries.forEach { t ->
            DropdownMenuItem(text = { Text(stringResource(txTypeLabel(t)), fontWeight = if (type == t) FontWeight.Black else null) }, onClick = { setType(t) })
        }
        HorizontalDivider(color = c.hairline)
        Text(stringResource(R.string.filter_account), style = MaterialTheme.typography.labelMedium, color = c.textDim, modifier = Modifier.padding(horizontal = 16.dp, vertical = 6.dp))
        DropdownMenuItem(text = { Text(stringResource(R.string.all_accounts), fontWeight = if (account == null) FontWeight.Black else null) }, onClick = { setAccount(null) })
        l.accounts.forEach { a ->
            DropdownMenuItem(text = { Text("${a.icon} ${a.name}", fontWeight = if (account == a.id) FontWeight.Black else null) }, onClick = { setAccount(a.id) })
        }
    }
}
