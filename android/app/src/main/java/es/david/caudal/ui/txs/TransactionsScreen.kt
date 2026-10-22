package es.david.caudal.ui.txs

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.TrendingDown
import androidx.compose.material.icons.automirrored.filled.TrendingUp
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.FilterList
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
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
import es.david.caudal.ui.common.ConfirmDialog
import es.david.caudal.ui.common.EmptyText
import es.david.caudal.ui.common.LocalFmt
import es.david.caudal.ui.common.Pill
import es.david.caudal.ui.common.ScreenScaffold
import es.david.caudal.ui.common.TxRow
import es.david.caudal.ui.common.rememberHaptics
import es.david.caudal.ui.common.txTypeLabel
import es.david.caudal.ui.nav.TxEditorRoute
import es.david.caudal.ui.theme.CaudalTheme
import kotlinx.coroutines.launch

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
    var pendingDelete by remember { mutableStateOf<Tx?>(null) }
    var filterMenu by remember { mutableStateOf(false) }
    val l = ledger ?: return

    ScreenScaffold(
        title = stringResource(R.string.tab_txs),
        actions = {
            Box {
                IconButton(onClick = { filterMenu = true }) {
                    Icon(Icons.Filled.FilterList, stringResource(R.string.filter), tint = if (filter.type != null || filter.accountId != null) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface)
                }
                FilterMenu(filterMenu, { filterMenu = false }, filter.type, filter.accountId, l, vm::setType, vm::setAccount)
            }
        },
    ) { pad ->
        LazyColumn(
            Modifier.fillMaxSize(),
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = pad.calculateTopPadding(), bottom = 96.dp),
        ) {
            item(key = "buscar") {
                OutlinedTextField(
                    value = filter.query,
                    onValueChange = vm::setQuery,
                    placeholder = { Text(stringResource(R.string.search_txs)) },
                    leadingIcon = { Icon(Icons.Filled.Search, null) },
                    singleLine = true,
                    shape = CircleShape,
                    colors = OutlinedTextFieldDefaults.colors(unfocusedContainerColor = CaudalTheme.colors.card, focusedContainerColor = CaudalTheme.colors.card, unfocusedBorderColor = Color.Transparent),
                    modifier = Modifier.fillMaxWidth().padding(bottom = 10.dp),
                )
            }
            item(key = "meses") {
                MonthChips(months, filter.month, enabled = filter.query.isEmpty()) { h.select(); vm.setMonth(it) }
            }
            item(key = "resumen") {
                Row(Modifier.fillMaxWidth().padding(vertical = 10.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    SumPill(Modifier.weight(1f), stringResource(R.string.expenses), Money.fromCents(sums.spent ?: 0), CaudalTheme.colors.negative, Icons.AutoMirrored.Filled.TrendingDown)
                    SumPill(Modifier.weight(1f), stringResource(R.string.incomes), Money.fromCents(sums.earned ?: 0), CaudalTheme.colors.income, Icons.AutoMirrored.Filled.TrendingUp)
                }
            }
            if (items.itemCount == 0) item(key = "vacio") { EmptyText(stringResource(R.string.nothing_here)) }
            items(count = items.itemCount, key = { i -> items.peek(i)?.id ?: i }) { i ->
                val t = items[i] ?: return@items
                val prev = if (i > 0) items.peek(i - 1) else null
                Column(Modifier.animateItem()) {
                    if (prev?.date != t.date) DayHeader(f.header(t.date), totals[t.date] ?: 0L)
                    SwipeTx(t, l, onOpen = { nav.navigate(TxEditorRoute(id = t.id)) }, onDuplicate = { h.success(); vm.duplicate(t) }, onDelete = { h.warning(); pendingDelete = t })
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
        val msg = stringResource(R.string.confirm_delete_tx_msg, t.title.ifEmpty { stringResource(txTypeLabel(t.type)) }, f.plain(Money.fromCents(kotlin.math.abs(t.amount))), f.header(t.date))
        ConfirmDialog(title, msg, onConfirm = { h.heavy(); vm.delete(t) }, onDismiss = { pendingDelete = null })
    }
}

@Composable
private fun MonthChips(months: List<String>, selected: String, enabled: Boolean, onSelect: (String) -> Unit) {
    val f = LocalFmt.current
    val state = rememberLazyListState()
    LaunchedEffect(months.size) { val i = months.indexOf(selected); if (i >= 0) state.scrollToItem(i) }
    LazyRow(state = state, horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.alpha(if (enabled) 1f else 0.35f)) {
        items(months, key = { it }) { m -> Pill(f.month("$m-01"), m == selected, { onSelect(m) }) }
    }
}

@Composable
private fun SumPill(modifier: Modifier, label: String, v: Double, c: Color, icon: androidx.compose.ui.graphics.vector.ImageVector) {
    Row(
        modifier.clip(RoundedCornerShape(16.dp)).background(CaudalTheme.colors.card).padding(12.dp).semantics(mergeDescendants = true) {},
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.size(26.dp).clip(CircleShape).background(c.copy(alpha = 0.18f)), contentAlignment = Alignment.Center) {
            Icon(icon, null, tint = c, modifier = Modifier.size(16.dp))
        }
        Spacer(Modifier.width(8.dp))
        Column {
            Text(label, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            AmountText(v, weight = FontWeight.Bold, style = MaterialTheme.typography.bodyMedium)
        }
    }
}

@Composable
private fun DayHeader(label: String, total: Long) {
    Row(Modifier.fillMaxWidth().padding(top = 16.dp, bottom = 4.dp, start = 4.dp, end = 4.dp).semantics(mergeDescendants = true) { heading() }, verticalAlignment = Alignment.CenterVertically) {
        Text(label, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.weight(1f))
        if (total != 0L) AmountText(Money.fromCents(total), signed = true, style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun SwipeTx(t: Tx, l: Ledger, onOpen: () -> Unit, onDuplicate: () -> Unit, onDelete: () -> Unit) {
    val scope = rememberCoroutineScope()
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
                Modifier.fillMaxSize().clip(RoundedCornerShape(14.dp)).background(if (toDelete) CaudalTheme.colors.negative else CaudalTheme.colors.transfer).padding(horizontal = 20.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = if (toDelete) Arrangement.End else Arrangement.Start,
            ) { Icon(if (toDelete) Icons.Filled.Delete else Icons.Filled.ContentCopy, null, tint = Color.White) }
        },
    ) {
        Box(
            Modifier
                .background(MaterialTheme.colorScheme.background)
                .combinedClickable(onClick = onOpen, onLongClick = { menu = true })
                .semantics { customActions = listOf(CustomAccessibilityAction(dup) { onDuplicate(); true }, CustomAccessibilityAction(del) { onDelete(); true }) },
        ) {
            TxRow(t, l)
            DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                DropdownMenuItem(text = { Text(stringResource(R.string.edit)) }, onClick = { menu = false; onOpen() })
                DropdownMenuItem(text = { Text(dup) }, onClick = { menu = false; onDuplicate() })
                DropdownMenuItem(text = { Text(del, color = MaterialTheme.colorScheme.error) }, onClick = { menu = false; onDelete() })
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
    DropdownMenu(expanded = expanded, onDismissRequest = onDismiss) {
        Text(stringResource(R.string.filter_type), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(horizontal = 16.dp, vertical = 6.dp))
        DropdownMenuItem(text = { Text(stringResource(R.string.all), fontWeight = if (type == null) FontWeight.Bold else null) }, onClick = { setType(null) })
        TxType.entries.forEach { t ->
            DropdownMenuItem(text = { Text(stringResource(txTypeLabel(t)), fontWeight = if (type == t) FontWeight.Bold else null) }, onClick = { setType(t) })
        }
        HorizontalDivider()
        Text(stringResource(R.string.filter_account), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(horizontal = 16.dp, vertical = 6.dp))
        DropdownMenuItem(text = { Text(stringResource(R.string.all_accounts), fontWeight = if (account == null) FontWeight.Bold else null) }, onClick = { setAccount(null) })
        l.accounts.forEach { a ->
            DropdownMenuItem(text = { Text("${a.icon} ${a.name}", fontWeight = if (account == a.id) FontWeight.Bold else null) }, onClick = { setAccount(a.id) })
        }
    }
}
