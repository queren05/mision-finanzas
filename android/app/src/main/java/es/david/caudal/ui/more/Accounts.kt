package es.david.caudal.ui.more

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import es.david.caudal.ui.common.appear
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.border
import es.david.caudal.ui.common.CircleIconButton
import es.david.caudal.ui.common.pressable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.navigation.NavController
import androidx.navigation.toRoute
import androidx.paging.cachedIn
import androidx.paging.compose.collectAsLazyPagingItems
import androidx.paging.compose.itemKey
import dagger.hilt.android.lifecycle.HiltViewModel
import es.david.caudal.R
import es.david.caudal.core.Money
import es.david.caudal.data.repo.FinanceRepository
import es.david.caudal.domain.model.Account
import es.david.caudal.domain.model.AccountType
import es.david.caudal.domain.model.PALETTE
import es.david.caudal.domain.model.Tx
import es.david.caudal.ui.common.AmountText
import es.david.caudal.ui.common.ColorRow
import es.david.caudal.ui.common.ConfirmDialog
import es.david.caudal.ui.common.EditorScaffold
import es.david.caudal.ui.common.EmptyText
import es.david.caudal.ui.common.FinanceViewModel
import es.david.caudal.ui.common.IconBubble
import es.david.caudal.ui.common.LocalFmt
import es.david.caudal.ui.common.ScreenScaffold
import es.david.caudal.ui.common.TxRow
import es.david.caudal.ui.common.rememberHaptics
import es.david.caudal.ui.common.txTypeLabel
import es.david.caudal.ui.nav.AccountDetailRoute
import es.david.caudal.ui.nav.AccountEditorRoute
import es.david.caudal.ui.nav.AccountsRoute
import es.david.caudal.ui.nav.TxEditorRoute
import es.david.caudal.ui.theme.CaudalTheme
import es.david.caudal.ui.theme.hexColor
import kotlinx.coroutines.launch
import javax.inject.Inject
import kotlin.math.abs

fun accountTypeLabel(t: AccountType): Int = when (t) {
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

// MARK: lista de cuentas

@Composable
fun AccountsScreen(nav: NavController) {
    val vm: FinanceViewModel = hiltViewModel()
    val ledger by vm.ledger.collectAsStateWithLifecycle()
    val l = ledger ?: return
    val h = rememberHaptics()
    var sorting by rememberSaveable { mutableStateOf(false) }
    // orden local mientras se ordena (se guarda al momento)
    val order = remember { mutableStateListOf<String>() }
    LaunchedEffect(l.accounts.map { it.id }) { order.clear(); order.addAll(l.accounts.map { it.id }) }
    val byId = l.data.accounts.associateBy { it.id }
    val archived = l.data.accounts.filter { it.archived }
    ScreenScaffold(
        stringResource(R.string.accounts_title),
        onBack = { nav.popBackStack() },
        actions = {
            TextButton(onClick = { h.tap(); sorting = !sorting }) {
                Text(stringResource(if (sorting) R.string.accounts_sort_done else R.string.accounts_sort), fontWeight = if (sorting) FontWeight.Bold else null)
            }
            CircleIconButton(Icons.Filled.Add, stringResource(R.string.accounts_new)) { nav.navigate(AccountEditorRoute()) }
        },
    ) { pad ->
        LazyColumn(contentPadding = listPadding(pad), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            items(order.toList(), key = { it }) { id ->
                val a = byId[id] ?: return@items
                val i = order.indexOf(id)
                Row(
                    Modifier.animateItem().fillMaxWidth().clip(RoundedCornerShape(22.dp)).background(CaudalTheme.colors.card).border(1.dp, CaudalTheme.colors.hairline, RoundedCornerShape(22.dp))
                        .pressable(0.98f, enabled = !sorting) { nav.navigate(AccountDetailRoute(a.id)) }
                        .heightIn(min = 64.dp).padding(horizontal = 14.dp, vertical = 10.dp)
                        .semantics(mergeDescendants = !sorting) {},
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    IconBubble(a.icon, a.color, 40.dp)
                    Spacer(Modifier.width(12.dp))
                    Column(Modifier.weight(1f)) {
                        Text(a.name, fontWeight = FontWeight.Bold)
                        Text(stringResource(accountTypeLabel(a.type)), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    if (sorting) {
                        MoveButtons(i > 0, i < order.size - 1,
                            onUp = { h.select(); order.add(i - 1, order.removeAt(i)); vm.run { reorderAccounts(order.toList()) } },
                            onDown = { h.select(); order.add(i + 1, order.removeAt(i)); vm.run { reorderAccounts(order.toList()) } })
                    } else {
                        AmountText(l.value(a), weight = FontWeight.SemiBold)
                    }
                }
            }
            if (archived.isNotEmpty()) {
                item { Text(stringResource(R.string.accounts_archived), style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(start = 16.dp, top = 12.dp)) }
                items(archived, key = { "arch_" + it.id }) { a ->
                    Row(
                        Modifier.fillMaxWidth().clip(RoundedCornerShape(22.dp)).background(CaudalTheme.colors.card).border(1.dp, CaudalTheme.colors.hairline, RoundedCornerShape(22.dp))
                            .pressable(0.98f) { nav.navigate(AccountEditorRoute(a.id)) }
                            .heightIn(min = 56.dp).padding(horizontal = 14.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) { Text("${a.icon} ${a.name}", color = MaterialTheme.colorScheme.onSurfaceVariant) }
                }
            }
        }
    }
}

// MARK: detalle de una cuenta

@HiltViewModel
class AccountDetailViewModel @Inject constructor(val repo: FinanceRepository, saved: SavedStateHandle) : ViewModel() {
    val id = saved.toRoute<AccountDetailRoute>().id
    val txs = repo.pagedTxsOfAccount(id).cachedIn(viewModelScope)
    fun delete(t: Tx) = viewModelScope.launch { repo.delete(t) }
    fun adjust(a: Account, v: Double) = viewModelScope.launch { repo.adjust(a, v) }
}

@Composable
fun AccountDetailScreen(id: String, nav: NavController) {
    val fvm: FinanceViewModel = hiltViewModel()
    val vm: AccountDetailViewModel = hiltViewModel()
    val ledger by fvm.ledger.collectAsStateWithLifecycle()
    val l = ledger ?: return
    val f = LocalFmt.current
    val h = rememberHaptics()
    val txs = vm.txs.collectAsLazyPagingItems()
    var menu by remember { mutableStateOf(false) }
    var adjusting by remember { mutableStateOf(false) }
    var newBalance by remember { mutableStateOf("") }
    var pendingDelete by remember { mutableStateOf<Tx?>(null) }
    val a = l.data.accounts.firstOrNull { it.id == id }
    ScreenScaffold(
        a?.name ?: stringResource(R.string.accounts_deleted),
        onBack = { nav.popBackStack() },
        large = false,
        actions = {
            if (a != null) Box {
                IconButton(onClick = { menu = true }) { Icon(Icons.Filled.MoreVert, stringResource(R.string.more_options)) }
                DropdownMenu(menu, onDismissRequest = { menu = false }) {
                    DropdownMenuItem(text = { Text(stringResource(R.string.accounts_adjust)) }, onClick = {
                        menu = false; newBalance = Money.editText(Money.toCents(l.balance(a))); adjusting = true
                    })
                    DropdownMenuItem(text = { Text(stringResource(R.string.accounts_edit)) }, onClick = { menu = false; nav.navigate(AccountEditorRoute(a.id)) })
                }
            }
        },
    ) { pad ->
        if (a == null) { EmptyText(stringResource(R.string.accounts_deleted), Modifier.padding(pad)); return@ScreenScaffold }
        LazyColumn(contentPadding = listPadding(pad)) {
            item {
                val c = hexColor(a.color)
                Column(
                    Modifier.fillMaxWidth().appear(0).clip(RoundedCornerShape(30.dp))
                        .background(Brush.linearGradient(listOf(androidx.compose.ui.graphics.lerp(c, Color.White, 0.15f), androidx.compose.ui.graphics.lerp(c, Color.Black, 0.3f))))
                        .border(1.dp, Color.White.copy(alpha = 0.18f), RoundedCornerShape(30.dp))
                        .padding(22.dp).semantics(mergeDescendants = true) {},
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(a.icon, fontSize = 34.sp)
                        Spacer(Modifier.width(10.dp))
                        Text(a.name, style = MaterialTheme.typography.titleLarge, color = Color.White, modifier = Modifier.weight(1f))
                        Text(
                            stringResource(accountTypeLabel(a.type)), color = Color.White, style = MaterialTheme.typography.labelMedium,
                            modifier = Modifier.clip(CircleShape).background(Color.White.copy(alpha = 0.2f)).padding(horizontal = 10.dp, vertical = 5.dp),
                        )
                    }
                    Spacer(Modifier.height(18.dp))
                    AmountText(l.balance(a), style = MaterialTheme.typography.displayMedium, color = Color.White, rolling = true)
                    val inv = l.value(a) - l.balance(a)
                    if (inv > 0) Text(stringResource(R.string.accounts_in_invest, f.money(inv)), color = Color.White.copy(alpha = 0.8f), fontWeight = FontWeight.Bold)
                }
                Spacer(Modifier.height(18.dp))
                Text(stringResource(R.string.accounts_movements), style = MaterialTheme.typography.titleLarge, modifier = Modifier.padding(start = 4.dp, bottom = 10.dp))
            }
            if (txs.itemCount == 0) item { es.david.caudal.ui.common.EmptyState(stringResource(R.string.accounts_no_movements)) }
            items(txs.itemCount, key = txs.itemKey { it.id }) { i ->
                val t = txs[i] ?: return@items
                val top = if (i == 0) 24.dp else 0.dp
                val bottom = if (i == txs.itemCount - 1) 24.dp else 0.dp
                SwipeToDelete(onDelete = { h.warning(); pendingDelete = t }) {
                    Box(Modifier.fillMaxWidth().clip(RoundedCornerShape(top, top, bottom, bottom)).background(CaudalTheme.colors.card)) {
                        TxRow(t, l, showDate = true, onClick = { nav.navigate(TxEditorRoute(id = t.id)) })
                    }
                }
            }
        }
    }
    if (adjusting && a != null) {
        AlertDialog(
            onDismissRequest = { adjusting = false },
            title = { Text(stringResource(R.string.accounts_adjust)) },
            text = {
                OutlinedTextField(
                    newBalance, { newBalance = it }, label = { Text(stringResource(R.string.accounts_adjust_field)) }, singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    Money.parseSigned(newBalance)?.let { vm.adjust(a, it); h.success() }
                    adjusting = false
                }) { Text(stringResource(R.string.accounts_adjust_do), fontWeight = FontWeight.Bold) }
            },
            dismissButton = { TextButton(onClick = { adjusting = false }) { Text(stringResource(R.string.cancel)) } },
        )
    }
    pendingDelete?.let { t ->
        val label = t.title.ifEmpty { stringResource(txTypeLabel(t.type)) }
        ConfirmDialog(
            title = stringResource(R.string.confirm_delete_movement),
            message = "$label · ${f.plain(abs(Money.fromCents(t.amount)))}",
            onConfirm = { h.heavy(); vm.delete(t) },
            onDismiss = { pendingDelete = null },
        )
    }
}

/** «-12,5» → -12.5 (el saldo de un ajuste puede ser negativo, p. ej. en una tarjeta) */
private fun Money.parseSigned(s: String): Double? {
    val t = s.trim()
    val neg = t.startsWith("-") || t.startsWith("−")
    return parse(t.trimStart('-', '−'))?.let { if (neg) -it else it }
}

// MARK: editor de cuenta

@Composable
fun AccountEditorScreen(id: String?, nav: NavController) {
    val vm: FinanceViewModel = hiltViewModel()
    val ledger by vm.ledger.collectAsStateWithLifecycle()
    val settings by vm.settings.collectAsStateWithLifecycle()
    val l = ledger ?: return
    val h = rememberHaptics()
    val original = id?.let { i -> l.data.accounts.firstOrNull { it.id == i } }
    var loaded by rememberSaveable { mutableStateOf(false) }
    var name by rememberSaveable { mutableStateOf("") }
    var icon by rememberSaveable { mutableStateOf("") }
    var type by rememberSaveable { mutableStateOf(AccountType.CORRIENTE) }
    var color by rememberSaveable { mutableStateOf(PALETTE[l.data.accounts.size % PALETTE.size]) }
    var initial by rememberSaveable { mutableStateOf("") }
    var note by rememberSaveable { mutableStateOf("") }
    var inTotal by rememberSaveable { mutableStateOf(true) }
    var archived by rememberSaveable { mutableStateOf(false) }
    var askDelete by remember { mutableStateOf(false) }
    if (!loaded) {
        original?.let {
            name = it.name; icon = it.icon; type = it.type; color = it.color; note = it.note; inTotal = it.includeInTotal; archived = it.archived
            initial = Money.editText(it.initial).let { t -> if (it.initial < 0) "-$t" else t }
        }
        loaded = true
    }
    EditorScaffold(
        title = stringResource(if (original == null) R.string.accounts_new else R.string.accounts_edit),
        onCancel = { nav.popBackStack() },
        saveEnabled = name.isNotBlank(),
        onSave = {
            val cents = Money.toCents(Money.parseSigned(initial) ?: 0.0)
            val base = original ?: Account(name = "")
            val a = base.copy(
                name = name.trim(), icon = icon.ifBlank { type.icon }, type = type, color = color, initial = cents, note = note,
                includeInTotal = inTotal, archived = archived, currency = original?.currency ?: (settings?.currency ?: "EUR"),
            )
            vm.run { save(a) }
            h.success(); nav.popBackStack()
        },
    ) { pad ->
        LazyColumn(contentPadding = listPadding(pad), verticalArrangement = Arrangement.spacedBy(18.dp)) {
            item {
                FormSection {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        OutlinedTextField(icon, { v -> icon = es.david.caudal.ui.common.Emojis.split(v).lastOrNull() ?: "" }, label = { Text(stringResource(R.string.accounts_icon)) },
                            placeholder = { Text(type.icon) }, singleLine = true, modifier = Modifier.width(96.dp).padding(vertical = 6.dp))
                        Spacer(Modifier.width(10.dp))
                        OutlinedTextField(name, { name = it }, label = { Text(stringResource(R.string.name)) }, singleLine = true, modifier = Modifier.weight(1f).padding(vertical = 6.dp))
                    }
                    PickerRow(stringResource(R.string.accounts_type), AccountType.entries.map { it to "${it.icon} ${stringResource(accountTypeLabel(it))}" }, type) { type = it }
                    RowDivider()
                    FieldRow(stringResource(if (original == null) R.string.accounts_balance_now else R.string.accounts_initial), initial, { initial = it.filter { c -> c.isDigit() || c == ',' || c == '.' || c == '-' } }, numeric = true)
                }
            }
            item {
                FormSection(stringResource(R.string.color)) {
                    Box(Modifier.padding(vertical = 12.dp)) { ColorRow(color) { color = it } }
                }
            }
            item {
                FormSection {
                    SwitchRow(stringResource(R.string.accounts_in_total), inTotal) { inTotal = it }
                    RowDivider()
                    SwitchRow(stringResource(R.string.accounts_archived_toggle), archived) { archived = it }
                    RowDivider()
                    FieldRow(stringResource(R.string.note), note, { note = it })
                }
            }
            if (original != null) item {
                TextButton(onClick = { h.warning(); askDelete = true }, modifier = Modifier.fillMaxWidth()) {
                    Text(stringResource(R.string.accounts_delete), color = MaterialTheme.colorScheme.error)
                }
            }
        }
    }
    if (askDelete && original != null) {
        ConfirmDialog(
            title = stringResource(R.string.accounts_delete_title, original.name),
            message = stringResource(R.string.accounts_delete_msg),
            confirm = stringResource(R.string.accounts_delete_confirm),
            onConfirm = {
                vm.run { deleteAccount(original) }
                h.heavy()
                // vuelve a la lista (también si venía del detalle de la cuenta)
                if (!nav.popBackStack(AccountsRoute, inclusive = false)) nav.popBackStack()
            },
            onDismiss = { askDelete = false },
        )
    }
}
