package es.david.caudal.ui.more

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.border
import es.david.caudal.ui.common.CircleIconButton
import es.david.caudal.ui.common.pressable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import es.david.caudal.R
import es.david.caudal.core.Day
import es.david.caudal.core.Money
import es.david.caudal.domain.model.CatKind
import es.david.caudal.domain.model.Freq
import es.david.caudal.domain.model.Recurring
import es.david.caudal.ui.common.AmountText
import es.david.caudal.ui.common.ConfirmDialog
import es.david.caudal.ui.common.EditorScaffold
import es.david.caudal.ui.common.FinanceViewModel
import es.david.caudal.ui.common.LocalFmt
import es.david.caudal.ui.common.ScreenScaffold
import es.david.caudal.ui.common.rememberHaptics
import es.david.caudal.ui.nav.RecurringEditorRoute
import es.david.caudal.ui.theme.CaudalTheme

fun freqLabel(f: Freq): Int = when (f) {
    Freq.WEEKLY -> R.string.freq_weekly
    Freq.MONTHLY -> R.string.freq_monthly
    Freq.YEARLY -> R.string.freq_yearly
}

/** lo que supone al mes un recurrente (como en iPhone: semanal × 52 / 12, anual / 12) */
private fun monthlyOf(r: Recurring): Double {
    val a = Money.fromCents(r.amount)
    return when (r.freq) {
        Freq.MONTHLY -> a
        Freq.WEEKLY -> a * 52 / 12
        Freq.YEARLY -> a / 12
    }
}

// MARK: lista de recurrentes

@Composable
fun RecurringScreen(nav: NavController) {
    val vm: FinanceViewModel = hiltViewModel()
    val ledger by vm.ledger.collectAsStateWithLifecycle()
    val l = ledger ?: return
    val f = LocalFmt.current
    val h = rememberHaptics()
    var pendingDelete by remember { mutableStateOf<Recurring?>(null) }
    val monthly = l.data.recurring.filter { it.active }.sumOf { monthlyOf(it) }
    ScreenScaffold(
        stringResource(R.string.recurring_title),
        onBack = { nav.popBackStack() },
        actions = { CircleIconButton(Icons.Filled.Add, stringResource(R.string.recurring_new)) { nav.navigate(RecurringEditorRoute()) } },
    ) { pad ->
        LazyColumn(contentPadding = listPadding(pad), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            item {
                FormSection {
                    Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).semantics(mergeDescendants = true) {}, verticalAlignment = Alignment.CenterVertically) {
                        Text(stringResource(R.string.recurring_monthly), Modifier.weight(1f), style = MaterialTheme.typography.titleMedium)
                        AmountText(monthly, style = MaterialTheme.typography.titleMedium, weight = FontWeight.Bold)
                    }
                }
            }
            items(l.data.recurring.sortedBy { it.next }, key = { it.id }) { r ->
                Row(
                    Modifier.animateItem().fillMaxWidth().clip(RoundedCornerShape(22.dp)).background(CaudalTheme.colors.card).border(1.dp, CaudalTheme.colors.hairline, RoundedCornerShape(22.dp))
                        .pressable(0.98f) { nav.navigate(RecurringEditorRoute(r.id)) }
                        .heightIn(min = 64.dp).padding(start = 14.dp, top = 8.dp, bottom = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    val cat = l.category(r.categoryId)
                    es.david.caudal.ui.common.IconBubble(if (r.type == "invest") "📈" else cat?.icon ?: "🔁", cat?.color ?: "#b39cff", 42.dp)
                    Spacer(Modifier.width(12.dp))
                    Column(Modifier.weight(1f).semantics(mergeDescendants = true) {}) {
                        Text(r.name, fontWeight = FontWeight.Bold, color = if (r.active) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurfaceVariant)
                        val line = stringResource(R.string.recurring_line, stringResource(freqLabel(r.freq)), f.header(r.next))
                        Text(if (r.active) line else stringResource(R.string.recurring_paused), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        AmountText(Money.fromCents(r.amount), style = MaterialTheme.typography.bodyLarge, weight = FontWeight.ExtraBold)
                    }
                    IconButton(onClick = { h.select(); vm.run { save(r.copy(active = !r.active)) } }) {
                        Icon(if (r.active) Icons.Filled.Pause else Icons.Filled.PlayArrow, stringResource(if (r.active) R.string.recurring_pause else R.string.recurring_resume))
                    }
                    IconButton(onClick = { h.warning(); pendingDelete = r }) {
                        Icon(Icons.Filled.Delete, stringResource(R.string.recurring_delete), tint = MaterialTheme.colorScheme.error)
                    }
                }
            }
        }
    }
    pendingDelete?.let { r ->
        ConfirmDialog(
            title = stringResource(R.string.recurring_delete_title),
            message = stringResource(R.string.recurring_delete_msg, r.name),
            onConfirm = { h.heavy(); vm.run { deleteRecurring(r) } },
            onDismiss = { pendingDelete = null },
        )
    }
}

// MARK: editor de recurrente

@Composable
fun RecurringEditorScreen(id: String?, nav: NavController) {
    val vm: FinanceViewModel = hiltViewModel()
    val ledger by vm.ledger.collectAsStateWithLifecycle()
    val l = ledger ?: return
    val h = rememberHaptics()
    val original = id?.let { i -> l.data.recurring.firstOrNull { it.id == i } }
    var loaded by rememberSaveable { mutableStateOf(false) }
    var name by rememberSaveable { mutableStateOf("") }
    var amount by rememberSaveable { mutableStateOf("") }
    var type by rememberSaveable { mutableStateOf("expense") }
    var accountId by rememberSaveable { mutableStateOf(l.accounts.firstOrNull()?.id ?: "") }
    var toAccountId by rememberSaveable { mutableStateOf(l.accounts.getOrNull(1)?.id ?: "") }
    var categoryId by rememberSaveable { mutableStateOf("") }
    var assetId by rememberSaveable { mutableStateOf("") }
    var freq by rememberSaveable { mutableStateOf(Freq.MONTHLY) }
    var next by rememberSaveable { mutableStateOf(Day.today) }
    var active by rememberSaveable { mutableStateOf(true) }
    var askDelete by remember { mutableStateOf(false) }
    if (!loaded) {
        original?.let {
            name = it.name; amount = Money.editText(it.amount); type = it.type; accountId = it.accountId
            toAccountId = it.toAccountId ?: toAccountId; categoryId = it.categoryId ?: ""; assetId = it.assetId ?: ""
            freq = it.freq; next = it.next; active = it.active
        }
        loaded = true
    }
    val parsed = Money.parse(amount) ?: 0.0
    val assets = l.data.assets.filter { !it.archived }
    val types = buildList {
        add("expense" to stringResource(R.string.tx_expense))
        add("income" to stringResource(R.string.tx_income))
        add("transfer" to stringResource(R.string.tx_transfer))
        if (assets.isNotEmpty() || type == "invest") add("invest" to stringResource(R.string.recurring_invest))
    }
    val accounts = l.accounts.map { it.id to "${it.icon} ${it.name}" }
    EditorScaffold(
        title = stringResource(if (original == null) R.string.recurring_new else R.string.recurring_edit),
        onCancel = { nav.popBackStack() },
        saveEnabled = name.isNotBlank() && parsed > 0 && accountId.isNotEmpty() && (type != "invest" || assetId.isNotEmpty()),
        onSave = {
            val r = (original ?: Recurring(name = "", amount = 0, accountId = "", next = next)).copy(
                name = name.trim(), type = type, amount = Money.toCents(parsed), accountId = accountId,
                toAccountId = if (type == "transfer") toAccountId else null,
                categoryId = if (type == "expense" || type == "income") categoryId.ifEmpty { null } else null,
                assetId = if (type == "invest") assetId.ifEmpty { null } else null,
                freq = freq, next = next, day = Day.date(next).dayOfMonth, active = active,
            )
            vm.run { save(r) }
            h.success(); nav.popBackStack()
        },
    ) { pad ->
        LazyColumn(contentPadding = listPadding(pad), verticalArrangement = Arrangement.spacedBy(18.dp)) {
            item {
                FormSection {
                    FieldRow(stringResource(R.string.recurring_name), name, { name = it })
                    FieldRow(stringResource(R.string.amount), amount, { amount = Money.cleanInput(it) }, numeric = true)
                    PickerRow(stringResource(R.string.recurring_type), types, type) { type = it }
                }
            }
            item {
                FormSection {
                    PickerRow(stringResource(R.string.account), accounts, accountId) { accountId = it }
                    RowDivider()
                    when (type) {
                        "transfer" -> PickerRow(stringResource(R.string.to), accounts, toAccountId) { toAccountId = it }
                        "invest" -> PickerRow(stringResource(R.string.recurring_asset), listOf("" to stringResource(R.string.recurring_pick)) + assets.map { it.id to it.name }, assetId) { assetId = it }
                        else -> {
                            val kind = if (type == "income") CatKind.INCOME else CatKind.EXPENSE
                            PickerRow(
                                stringResource(R.string.category),
                                listOf("" to stringResource(R.string.no_category)) + l.categories(kind).map { it.id to "${it.icon} ${it.name}" },
                                categoryId,
                            ) { categoryId = it }
                        }
                    }
                }
            }
            item {
                FormSection {
                    PickerRow(stringResource(R.string.recurring_freq), Freq.entries.map { it to stringResource(freqLabel(it)) }, freq) { freq = it }
                    RowDivider()
                    DateRow(stringResource(R.string.recurring_next), next) { next = it }
                    RowDivider()
                    SwitchRow(stringResource(R.string.recurring_active), active) { active = it }
                }
            }
            if (original != null) item {
                Box(Modifier.fillMaxWidth()) {
                    TextButton(onClick = { h.warning(); askDelete = true }, modifier = Modifier.fillMaxWidth()) {
                        Text(stringResource(R.string.recurring_delete), color = MaterialTheme.colorScheme.error)
                    }
                }
            }
        }
    }
    if (askDelete && original != null) {
        ConfirmDialog(
            title = stringResource(R.string.recurring_delete_title),
            message = stringResource(R.string.recurring_delete_msg, original.name),
            onConfirm = { vm.run { deleteRecurring(original) }; h.heavy(); nav.popBackStack() },
            onDismiss = { askDelete = false },
        )
    }
}
