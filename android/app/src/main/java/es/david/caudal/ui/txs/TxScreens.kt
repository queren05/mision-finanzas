package es.david.caudal.ui.txs

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.SpeakerNotes
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
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
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
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
import es.david.caudal.domain.calc.Insights
import es.david.caudal.domain.calc.Ledger
import es.david.caudal.domain.model.CatKind
import es.david.caudal.domain.model.Category
import es.david.caudal.domain.model.Tx
import es.david.caudal.domain.model.TxType
import es.david.caudal.ui.common.BigAmountField
import es.david.caudal.ui.common.Card
import es.david.caudal.ui.common.ConfirmDialog
import es.david.caudal.ui.common.Confetti
import es.david.caudal.ui.common.EditorScaffold
import es.david.caudal.ui.common.FinanceViewModel
import es.david.caudal.ui.common.GroupLabel
import es.david.caudal.ui.common.Gotita
import es.david.caudal.ui.common.LocalFmt
import es.david.caudal.ui.common.LocalMascot
import es.david.caudal.ui.common.Mood
import es.david.caudal.ui.common.Pill
import es.david.caudal.ui.common.RowDivider
import es.david.caudal.ui.common.SegmentedPills
import es.david.caudal.ui.common.pressable
import es.david.caudal.ui.common.rememberHaptics
import es.david.caudal.ui.common.txTypeLabel
import es.david.caudal.ui.nav.TxEditorRoute
import es.david.caudal.ui.theme.CaudalTheme
import es.david.caudal.ui.theme.LocalMotion
import es.david.caudal.ui.theme.hexColor
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneOffset

/** emojis de «¿valió la pena?» y su texto para lectores de pantalla */
private val MOODS = listOf("😍" to R.string.tx_mood_love, "🙂" to R.string.tx_mood_ok, "😐" to R.string.tx_mood_meh, "😩" to R.string.tx_mood_bad)

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
    val sounds = es.david.caudal.ui.common.rememberSounds()
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
    var mood by rememberSaveable { mutableStateOf(original?.mood ?: "") }
    var tags by rememberSaveable { mutableStateOf(original?.tags ?: emptyList()) }
    var tagText by rememberSaveable { mutableStateOf("") }
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
        TxType.ADJUST -> colors.textDim
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
            tags = (tags + listOfNotNull(tagText.trim().removePrefix("#").takeIf { it.isNotEmpty() })).distinct(),
            date = date,
            time = time,
            excluded = excluded,
            mood = if (type == TxType.EXPENSE) mood else "",
        )
        focus.clearFocus()
        vm.run { save(t) }
        h.success()
        sounds.plop()
        saved = true
        scope.launch { delay(900); onDone() }
    }

    EditorScaffold(
        title = stringResource(if (original == null) R.string.new_movement else R.string.edit_movement),
        onCancel = onDone,
        onSave = ::save,
        bottomBar = {
            if (original != null) {
                TextButton(onClick = { h.warning(); askDelete = true }, modifier = Modifier.fillMaxWidth().navigationBarsPadding().padding(8.dp).heightIn(min = 48.dp)) {
                    Icon(Icons.Filled.Delete, null, tint = colors.negative)
                    Spacer(Modifier.width(6.dp))
                    Text(stringResource(R.string.delete_movement), color = colors.negative, style = MaterialTheme.typography.labelLarge)
                }
            }
        },
    ) { pad ->
        Box(Modifier.fillMaxSize().padding(pad)) {
            Column(
                Modifier.fillMaxSize().verticalScroll(rememberScrollState()).imePadding().padding(horizontal = 16.dp, vertical = 6.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                SegmentedPills(
                    types.map { stringResource(txTypeLabel(it)) }, types.indexOf(type).coerceAtLeast(0),
                    { i -> type = types[i]; if (!userPicked) { categoryId = null; autoCategory() } },
                    colors = types.map(::typeColor),
                )
                Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
                    BigAmountField(
                        digits, { digits = it }, typeColor(type),
                        prefix = when (type) { TxType.EXPENSE -> "−"; TxType.INCOME -> "+"; else -> "" },
                        autoFocus = original == null,
                    )
                    l.account(accountId)?.let { a ->
                        Text(
                            stringResource(R.string.tx_balance_of, a.name, f.money(l.balance(a))),
                            style = MaterialTheme.typography.labelMedium, color = colors.textDim,
                        )
                    }
                }

                // frecuentes: a un toque
                val frequent = remember(l) { if (original == null) Insights.frequent(l.data.txs) else emptyList() }
                if (frequent.isNotEmpty() && type == TxType.EXPENSE) {
                    Column {
                        GroupLabel(stringResource(R.string.tx_frequent))
                        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            items(frequent) { fr ->
                                val cat = l.category(fr.categoryId)
                                val desc = stringResource(R.string.tx_frequent_desc, fr.title, f.money(fr.amount))
                                Row(
                                    Modifier
                                        .pressable(0.92f) {
                                            h.select()
                                            digits = Money.editText(fr.amount); title = fr.title; categoryId = fr.categoryId; userPicked = fr.categoryId != null
                                            if (l.account(fr.accountId) != null) accountId = fr.accountId
                                        }
                                        .clip(CircleShape)
                                        .background(colors.card)
                                        .border(1.dp, colors.hairline, CircleShape)
                                        .heightIn(min = 44.dp)
                                        .padding(horizontal = 12.dp, vertical = 8.dp)
                                        .semantics(mergeDescendants = true) { contentDescription = desc },
                                    verticalAlignment = Alignment.CenterVertically,
                                ) {
                                    Text(cat?.icon ?: "⭐", fontSize = 18.sp)
                                    Spacer(Modifier.width(6.dp))
                                    Text(fr.title, style = MaterialTheme.typography.labelLarge, maxLines = 1)
                                    Spacer(Modifier.width(6.dp))
                                    Text(f.money(fr.amount), style = MaterialTheme.typography.labelMedium, color = colors.textDim)
                                }
                            }
                        }
                    }
                }

                if (type == TxType.TRANSFER) {
                    Card(padding = 14.dp) {
                        AccountChips(stringResource(R.string.from), l, accountId) { accountId = it }
                        Spacer(Modifier.height(10.dp))
                        AccountChips(stringResource(R.string.to), l, toAccountId) { toAccountId = it }
                    }
                } else if (type != TxType.ADJUST) {
                    val cats = l.categories(if (type == TxType.INCOME) CatKind.INCOME else CatKind.EXPENSE)
                    Column {
                        GroupLabel(stringResource(R.string.tx_category_title))
                        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp), maxItemsInEachRow = 4) {
                            cats.forEach { c ->
                                CategoryTile(c, c.id == categoryId, Modifier.weight(1f)) {
                                    h.select(); val on = c.id == categoryId
                                    categoryId = if (on) null else c.id; userPicked = !on
                                }
                            }
                            repeat((4 - cats.size % 4) % 4) { Spacer(Modifier.weight(1f)) }
                        }
                    }
                    if (l.accounts.size > 1) Card(padding = 14.dp) { AccountChips(stringResource(R.string.account), l, accountId) { accountId = it } }
                }

                if (type == TxType.EXPENSE) {
                    Column {
                        GroupLabel(stringResource(R.string.tx_worth_it))
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            MOODS.forEach { (e, label) ->
                                MoodButton(e, stringResource(label), e == mood, Modifier.weight(1f)) { h.select(); mood = if (mood == e) "" else e }
                            }
                        }
                    }
                }

                Card(padding = 6.dp) {
                    TextField(
                        value = title,
                        onValueChange = { title = it; if (!userPicked) autoCategory() },
                        placeholder = { Text(stringResource(R.string.concept)) },
                        singleLine = true,
                        textStyle = MaterialTheme.typography.bodyLarge,
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
                        LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp)) {
                            items(suggestions) { s -> Pill(s, false, { h.tap(); title = s; autoCategory(); focus.clearFocus() }) }
                        }
                    }
                    RowDivider(16.dp)
                    TextField(
                        value = note, onValueChange = { note = it }, placeholder = { Text(stringResource(R.string.note)) },
                        leadingIcon = { Icon(Icons.Filled.SpeakerNotes, null, tint = colors.textDim) }, singleLine = true, colors = plainField(),
                        textStyle = MaterialTheme.typography.bodyLarge, modifier = Modifier.fillMaxWidth(),
                        keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences),
                    )
                    RowDivider(16.dp)
                    // etiquetas: las puestas (tocar para quitar), un campo para añadir y las ya usadas
                    val known = remember(l) { l.data.txs.flatMap { it.tags }.groupingBy { it }.eachCount().entries.sortedByDescending { it.value }.map { it.key } }
                    fun addTag(t: String) { val v = t.trim().removePrefix("#"); if (v.isNotEmpty() && v !in tags) { h.select(); tags = tags + v }; tagText = "" }
                    TextField(
                        value = tagText, onValueChange = { v -> if (v.endsWith(" ") || v.endsWith(",")) addTag(v.dropLast(1)) else tagText = v },
                        placeholder = { Text(stringResource(R.string.tags_add)) },
                        leadingIcon = { Text("#", style = MaterialTheme.typography.titleMedium, color = colors.textDim) }, singleLine = true, colors = plainField(),
                        textStyle = MaterialTheme.typography.bodyLarge, modifier = Modifier.fillMaxWidth(),
                        keyboardOptions = KeyboardOptions(imeAction = androidx.compose.ui.text.input.ImeAction.Done),
                        keyboardActions = androidx.compose.foundation.text.KeyboardActions(onDone = { addTag(tagText) }),
                    )
                    val sugg = known.filter { it !in tags && (tagText.isEmpty() || it.startsWith(tagText.removePrefix("#"), ignoreCase = true)) }.take(8)
                    if (tags.isNotEmpty() || sugg.isNotEmpty()) {
                        LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp)) {
                            items(tags) { t -> Pill("#$t ✕", true, { h.tap(); tags = tags - t }) }
                            items(sugg) { t -> Pill("#$t", false, { addTag(t) }) }
                        }
                    }
                    RowDivider(16.dp)
                    Row(Modifier.fillMaxWidth().padding(horizontal = 10.dp, vertical = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        ChipButton(Icons.Filled.CalendarMonth, f.header(date), Modifier.weight(1f)) { pickDate = true }
                        ChipButton(Icons.Filled.Schedule, time) { pickTime = true }
                    }
                    if (type == TxType.EXPENSE || type == TxType.INCOME) {
                        RowDivider(16.dp)
                        Row(
                            Modifier.fillMaxWidth().pressable(0.98f, role = Role.Switch) { excluded = !excluded }.heightIn(min = 52.dp).padding(horizontal = 16.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Icon(Icons.Filled.VisibilityOff, null, tint = colors.textDim)
                            Spacer(Modifier.width(12.dp))
                            Text(stringResource(R.string.exclude_stats), color = colors.textDim, modifier = Modifier.weight(1f))
                            Switch(checked = excluded, onCheckedChange = null)
                        }
                    }
                }
                Spacer(Modifier.height(24.dp))
            }

            // guardado: Gotita contenta y un poco de confeti
            AnimatedVisibility(saved, Modifier.fillMaxSize(), enter = fadeIn(), exit = fadeOut()) {
                Box(Modifier.fillMaxSize().background(colors.bg.copy(alpha = 0.55f)), contentAlignment = Alignment.Center) {
                    Confetti(saved, listOf(colors.accent, colors.income, colors.warning, colors.transfer), count = 50)
                    AnimatedVisibility(saved, enter = scaleIn(spring(dampingRatio = 0.45f, stiffness = Spring.StiffnessMediumLow))) {
                        Column(
                            Modifier.clip(RoundedCornerShape(32.dp)).background(colors.card).border(1.dp, colors.hairline, RoundedCornerShape(32.dp)).padding(horizontal = 36.dp, vertical = 24.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                        ) {
                            if (LocalMascot.current) Gotita(if (type == TxType.INCOME) Mood.LOVE else Mood.HAPPY, 96.dp) else Text("✅", fontSize = 56.sp)
                            Spacer(Modifier.height(6.dp))
                            Text(stringResource(R.string.tx_saved_great), style = MaterialTheme.typography.titleLarge)
                        }
                    }
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
            shape = RoundedCornerShape(28.dp),
            containerColor = colors.card,
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

/** tarjetita de categoría: emoji grande; la elegida con su color y un rebote */
@Composable
private fun CategoryTile(c: Category, on: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val colors = CaudalTheme.colors
    val col = hexColor(c.color)
    val motion = LocalMotion.current
    val scale by animateFloatAsState(if (on && motion) 1.06f else 1f, spring(dampingRatio = 0.4f, stiffness = Spring.StiffnessMedium), label = "categoría")
    Column(
        modifier
            .graphicsLayer { scaleX = scale; scaleY = scale }
            .pressable(0.9f, role = Role.RadioButton, onClick = onClick)
            .clip(RoundedCornerShape(20.dp))
            .background(if (on) Brush.verticalGradient(listOf(col.copy(alpha = 0.55f), col.copy(alpha = 0.3f))) else Brush.verticalGradient(listOf(colors.card, colors.card)))
            .border(if (on) 2.dp else 1.dp, if (on) col else colors.hairline, RoundedCornerShape(20.dp))
            .semantics { selected = on }
            .heightIn(min = 82.dp)
            .padding(6.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(c.icon, fontSize = 28.sp)
        Spacer(Modifier.height(2.dp))
        Text(c.name, style = MaterialTheme.typography.labelSmall, maxLines = 1, overflow = TextOverflow.Ellipsis, textAlign = TextAlign.Center, color = colors.text)
    }
}

@Composable
private fun MoodButton(emoji: String, label: String, on: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val colors = CaudalTheme.colors
    val motion = LocalMotion.current
    val scale by animateFloatAsState(if (on && motion) 1.18f else 1f, spring(dampingRatio = 0.35f, stiffness = Spring.StiffnessMedium), label = "emoji")
    Box(
        modifier
            .heightIn(min = 56.dp)
            .pressable(0.85f, role = Role.RadioButton, onClick = onClick)
            .clip(RoundedCornerShape(18.dp))
            .background(if (on) colors.accent.copy(alpha = 0.28f) else colors.card)
            .border(if (on) 2.dp else 1.dp, if (on) colors.accent else colors.hairline, RoundedCornerShape(18.dp))
            .semantics { selected = on; contentDescription = label },
        contentAlignment = Alignment.Center,
    ) { Text(emoji, fontSize = 26.sp, modifier = Modifier.graphicsLayer { scaleX = scale; scaleY = scale; alpha = if (on) 1f else 0.75f }) }
}

@Composable
private fun ChipButton(icon: ImageVector, text: String, modifier: Modifier = Modifier, onClick: () -> Unit) {
    val colors = CaudalTheme.colors
    Row(
        modifier
            .pressable(0.94f, onClick = onClick)
            .clip(CircleShape)
            .background(colors.cardAlt)
            .heightIn(min = 46.dp)
            .padding(horizontal = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center,
    ) {
        Icon(icon, null, tint = colors.accent, modifier = Modifier.size(20.dp))
        Spacer(Modifier.width(8.dp))
        Text(text, style = MaterialTheme.typography.labelLarge, maxLines = 1)
    }
}

@Composable
private fun AccountChips(label: String, l: Ledger, selected: String, onSelect: (String) -> Unit) {
    Column {
        Text(label, style = MaterialTheme.typography.labelMedium, color = CaudalTheme.colors.textDim, modifier = Modifier.padding(start = 4.dp, bottom = 8.dp))
        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            items(l.accounts, key = { it.id }) { a ->
                val on = a.id == selected
                Pill("${a.icon} ${a.name}", on, { onSelect(a.id) }, selectedColor = hexColor(a.color))
            }
        }
    }
}

@Composable
private fun plainField() = TextFieldDefaults.colors(
    focusedContainerColor = Color.Transparent, unfocusedContainerColor = Color.Transparent,
    focusedIndicatorColor = Color.Transparent, unfocusedIndicatorColor = Color.Transparent,
)
