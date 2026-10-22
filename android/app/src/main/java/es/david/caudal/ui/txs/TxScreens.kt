package es.david.caudal.ui.txs

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.SpeakerNotes
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.material3.TimePicker
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import es.david.caudal.R
import es.david.caudal.core.Day
import es.david.caudal.core.Money
import es.david.caudal.domain.calc.Ledger
import es.david.caudal.domain.model.CatKind
import es.david.caudal.domain.model.Tx
import es.david.caudal.domain.model.TxType
import es.david.caudal.ui.common.BigAmountField
import es.david.caudal.ui.common.Card
import es.david.caudal.ui.common.ConfirmDialog
import es.david.caudal.ui.common.EditorScaffold
import es.david.caudal.ui.common.FinanceViewModel
import es.david.caudal.ui.common.LocalFmt
import es.david.caudal.ui.common.Pill
import es.david.caudal.ui.common.SegmentedPills
import es.david.caudal.ui.common.rememberHaptics
import es.david.caudal.ui.common.txTypeLabel
import es.david.caudal.ui.nav.TxEditorRoute
import es.david.caudal.ui.theme.CaudalTheme
import es.david.caudal.ui.theme.hexColor
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneOffset

/** Apuntar o editar un movimiento: importe grande, tipo, categoría, cuenta, concepto, nota, fecha y hora */
@OptIn(ExperimentalLayoutApi::class, ExperimentalMaterial3Api::class)
@Composable
fun TxEditorScreen(route: TxEditorRoute, onDone: () -> Unit) {
    val vm: FinanceViewModel = hiltViewModel()
    val ledger by vm.ledger.collectAsStateWithLifecycle()
    val l = ledger ?: return
    val original = remember(l.data.txs.size) { route.id?.let { id -> l.data.txs.firstOrNull { it.id == id } } }
    if (route.id != null && original == null) return

    val f = LocalFmt.current
    val h = rememberHaptics()
    val colors = CaudalTheme.colors
    val scope = rememberCoroutineScope()
    val focus = LocalFocusManager.current
    val snackbar = remember { SnackbarHostState() }

    var type by rememberSaveable { mutableStateOf(original?.type ?: TxType.of(route.type) ?: TxType.EXPENSE) }
    var digits by rememberSaveable { mutableStateOf(original?.let { Money.editText(it.amount) } ?: "") }
    var title by rememberSaveable { mutableStateOf(original?.title ?: "") }
    var note by rememberSaveable { mutableStateOf(original?.note ?: "") }
    var categoryId by rememberSaveable { mutableStateOf(original?.categoryId) }
    var userPicked by rememberSaveable { mutableStateOf(original?.categoryId != null) }
    var accountId by rememberSaveable { mutableStateOf(original?.accountId ?: route.accountId ?: l.accounts.firstOrNull()?.id ?: "") }
    var toAccountId by rememberSaveable { mutableStateOf(original?.toAccountId ?: l.accounts.drop(1).firstOrNull()?.id ?: accountId) }
    var date by rememberSaveable { mutableStateOf(original?.date ?: Day.today) }
    var time by rememberSaveable { mutableStateOf(original?.time ?: Day.nowTime()) }
    var excluded by rememberSaveable { mutableStateOf(original?.excluded ?: false) }
    var titleFocused by remember { mutableStateOf(false) }
    var pickDate by remember { mutableStateOf(false) }
    var pickTime by remember { mutableStateOf(false) }
    var askDelete by remember { mutableStateOf(false) }
    var saved by remember { mutableStateOf(false) }

    val types = if (original?.type == TxType.ADJUST) listOf(TxType.ADJUST) else listOf(TxType.EXPENSE, TxType.INCOME, TxType.TRANSFER)
    fun typeColor(t: TxType) = when (t) {
        TxType.EXPENSE -> colors.expenseAccent
        TxType.INCOME -> colors.income
        TxType.TRANSFER -> colors.transfer
        TxType.ADJUST -> Color.Gray
    }
    fun autoCategory() {
        if (type == TxType.TRANSFER || userPicked) return
        l.guessCategory(title, if (type == TxType.INCOME) CatKind.INCOME else CatKind.EXPENSE)?.let { categoryId = it.id }
    }
    val amountMsg = stringResource(R.string.amount_needed)
    val sameMsg = stringResource(R.string.same_account)
    val noAccMsg = stringResource(R.string.no_accounts_yet)

    fun save() {
        val amount = Money.parse(digits) ?: 0.0
        when {
            l.accounts.isEmpty() && original == null -> { h.warning(); scope.launch { snackbar.showSnackbar(noAccMsg) }; return }
            amount <= 0 -> { h.warning(); scope.launch { snackbar.showSnackbar(amountMsg) }; return }
            type == TxType.TRANSFER && accountId == toAccountId -> { h.warning(); scope.launch { snackbar.showSnackbar(sameMsg) }; return }
        }
        val cents = Money.toCents(amount)
        val base = original ?: Tx(amount = 0, accountId = accountId, date = Day.today, currency = l.account(accountId)?.currency ?: "EUR")
        val t = base.copy(
            type = type,
            amount = if (type == TxType.ADJUST) (if ((original?.amount ?: 1) < 0) -cents else cents) else cents,
            accountId = accountId,
            toAccountId = if (type == TxType.TRANSFER) toAccountId else null,
            categoryId = if (type == TxType.TRANSFER) null else categoryId,
            title = title.trim(),
            note = note,
            date = date,
            time = time,
            excluded = excluded,
        )
        vm.run { save(t) }
        h.success()
        saved = true
        scope.launch { delay(550); onDone() }
    }

    EditorScaffold(
        title = stringResource(if (original == null) R.string.new_movement else R.string.edit_movement),
        onCancel = onDone,
        onSave = ::save,
        bottomBar = {
            if (original != null) {
                TextButton(onClick = { h.warning(); askDelete = true }, modifier = Modifier.fillMaxWidth().navigationBarsPadding().padding(8.dp)) {
                    Icon(Icons.Filled.Delete, null, tint = MaterialTheme.colorScheme.error)
                    Spacer(Modifier.width(6.dp))
                    Text(stringResource(R.string.delete_movement), color = MaterialTheme.colorScheme.error)
                }
            }
        },
    ) { pad ->
        Box(Modifier.fillMaxSize().padding(pad)) {
            Column(
                Modifier.fillMaxSize().verticalScroll(rememberScrollState()).imePadding().padding(horizontal = 16.dp, vertical = 6.dp),
                verticalArrangement = Arrangement.spacedBy(18.dp),
            ) {
                SegmentedPills(
                    types.map { stringResource(txTypeLabel(it)) }, types.indexOf(type).coerceAtLeast(0),
                    { i -> h.select(); type = types[i]; if (!userPicked) { categoryId = null; autoCategory() } },
                    colors = types.map(::typeColor),
                )
                BigAmountField(
                    digits, { digits = it }, typeColor(type),
                    prefix = when (type) { TxType.EXPENSE -> "−"; TxType.INCOME -> "+"; else -> "" },
                    autoFocus = original == null,
                )
                if (type == TxType.TRANSFER) {
                    Card(padding = 12.dp) {
                        AccountChips(stringResource(R.string.from), l, accountId) { accountId = it }
                        Spacer(Modifier.heightIn(min = 8.dp))
                        AccountChips(stringResource(R.string.to), l, toAccountId) { toAccountId = it }
                    }
                } else {
                    val cats = l.categories(if (type == TxType.INCOME) CatKind.INCOME else CatKind.EXPENSE)
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp), maxItemsInEachRow = 4) {
                        cats.forEach { c ->
                            val on = c.id == categoryId
                            Column(
                                Modifier
                                    .weight(1f)
                                    .clip(RoundedCornerShape(16.dp))
                                    .background(if (on) hexColor(c.color).copy(alpha = 0.3f) else CaudalTheme.colors.card)
                                    .clickable(role = Role.RadioButton) { h.select(); categoryId = if (on) null else c.id; userPicked = !on }
                                    .semantics { selected = on }
                                    .heightIn(min = 76.dp)
                                    .padding(6.dp),
                                horizontalAlignment = Alignment.CenterHorizontally,
                                verticalArrangement = Arrangement.Center,
                            ) {
                                Text(c.icon, fontSize = 24.sp)
                                Text(c.name, style = MaterialTheme.typography.labelSmall, maxLines = 1, overflow = TextOverflow.Ellipsis, textAlign = TextAlign.Center, fontWeight = if (on) FontWeight.Bold else null)
                            }
                        }
                    }
                    if (type != TxType.ADJUST || l.accounts.size > 1) {
                        Card(padding = 12.dp) { AccountChips(stringResource(R.string.account), l, accountId) { accountId = it } }
                    }
                }
                Card(padding = 14.dp) {
                    TextField(
                        value = title,
                        onValueChange = { title = it; if (!userPicked) autoCategory() },
                        placeholder = { Text(stringResource(R.string.concept)) },
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences, imeAction = ImeAction.Done),
                        keyboardActions = KeyboardActions(onDone = { focus.clearFocus() }),
                        colors = plainField(),
                        modifier = Modifier.fillMaxWidth().onFocusChanged { titleFocused = it.isFocused },
                    )
                    val suggestions = remember(title, l) {
                        val q = title.lowercase()
                        l.knownTitles.filter { q.isEmpty() || (it.lowercase().startsWith(q) && it.lowercase() != q) }.take(8)
                    }
                    AnimatedVisibility(titleFocused && suggestions.isNotEmpty()) {
                        LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.padding(vertical = 4.dp)) {
                            items(suggestions) { s ->
                                Pill(s, false, { h.tap(); title = s; autoCategory(); focus.clearFocus() })
                            }
                        }
                    }
                    HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
                    TextField(
                        value = note, onValueChange = { note = it }, placeholder = { Text(stringResource(R.string.note)) },
                        leadingIcon = { Icon(Icons.Filled.SpeakerNotes, null) }, singleLine = true, colors = plainField(), modifier = Modifier.fillMaxWidth(),
                        keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences),
                    )
                    HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
                    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                        TextButton(onClick = { pickDate = true }, modifier = Modifier.weight(1f).heightIn(min = 48.dp)) {
                            Icon(Icons.Filled.CalendarMonth, null); Spacer(Modifier.width(6.dp)); Text(f.header(date))
                        }
                        TextButton(onClick = { pickTime = true }, modifier = Modifier.heightIn(min = 48.dp)) {
                            Icon(Icons.Filled.Schedule, null); Spacer(Modifier.width(6.dp)); Text(time)
                        }
                    }
                    if (type == TxType.EXPENSE || type == TxType.INCOME) {
                        HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
                        Row(Modifier.fillMaxWidth().heightIn(min = 52.dp).clickable(role = Role.Switch) { excluded = !excluded }, verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Filled.VisibilityOff, null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
                            Spacer(Modifier.width(12.dp))
                            Text(stringResource(R.string.exclude_stats), color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.weight(1f))
                            Switch(checked = excluded, onCheckedChange = null)
                        }
                    }
                }
                Spacer(Modifier.heightIn(min = 24.dp))
            }
            AnimatedVisibility(saved, Modifier.align(Alignment.Center), enter = scaleIn() + fadeIn(), exit = fadeOut()) {
                Column(
                    Modifier.clip(RoundedCornerShape(26.dp)).background(MaterialTheme.colorScheme.surfaceContainerHigh).padding(28.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Icon(Icons.Filled.CheckCircle, null, tint = colors.income, modifier = Modifier.size(56.dp))
                    Text(stringResource(R.string.saved), fontWeight = FontWeight.Bold)
                }
            }
            SnackbarHost(snackbar, Modifier.align(Alignment.BottomCenter))
        }
    }

    if (pickDate) {
        val st = rememberDatePickerState(initialSelectedDateMillis = LocalDate.parse(date).atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli())
        DatePickerDialog(
            onDismissRequest = { pickDate = false },
            confirmButton = {
                TextButton(onClick = {
                    st.selectedDateMillis?.let { date = Instant.ofEpochMilli(it).atZone(ZoneOffset.UTC).toLocalDate().toString() }
                    pickDate = false
                }) { Text(stringResource(R.string.ok)) }
            },
            dismissButton = { TextButton(onClick = { pickDate = false }) { Text(stringResource(R.string.cancel)) } },
        ) { DatePicker(st) }
    }
    if (pickTime) {
        val t0 = Day.parseTime(time)
        val st = rememberTimePickerState(t0.hour, t0.minute, is24Hour = true)
        androidx.compose.material3.AlertDialog(
            onDismissRequest = { pickTime = false },
            confirmButton = { TextButton(onClick = { time = Day.time(LocalTime.of(st.hour, st.minute)); pickTime = false }) { Text(stringResource(R.string.ok)) } },
            dismissButton = { TextButton(onClick = { pickTime = false }) { Text(stringResource(R.string.cancel)) } },
            text = { TimePicker(st) },
        )
    }
    if (askDelete && original != null) {
        ConfirmDialog(
            title = stringResource(
                when (original.type) {
                    TxType.INCOME -> R.string.confirm_delete_income
                    TxType.TRANSFER -> R.string.confirm_delete_transfer
                    TxType.ADJUST -> R.string.confirm_delete_adjust
                    else -> R.string.confirm_delete_expense
                },
            ),
            onConfirm = { h.heavy(); vm.run { delete(original) }; onDone() },
            onDismiss = { askDelete = false },
        )
    }
    LaunchedEffect(Unit) { if (original == null && title.isNotEmpty()) autoCategory() }
}

@Composable
private fun AccountChips(label: String, l: Ledger, selected: String, onSelect: (String) -> Unit) {
    Column {
        Text(label, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(start = 4.dp, bottom = 6.dp))
        LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            items(l.accounts, key = { it.id }) { a ->
                Pill("${a.icon} ${a.name}", a.id == selected, { onSelect(a.id) })
            }
        }
    }
}

@Composable
private fun plainField() = TextFieldDefaults.colors(
    focusedContainerColor = Color.Transparent, unfocusedContainerColor = Color.Transparent,
    focusedIndicatorColor = Color.Transparent, unfocusedIndicatorColor = Color.Transparent,
)
