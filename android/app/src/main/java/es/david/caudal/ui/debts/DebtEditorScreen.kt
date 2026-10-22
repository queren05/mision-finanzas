package es.david.caudal.ui.debts

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import es.david.caudal.R
import es.david.caudal.core.Day
import es.david.caudal.core.Money
import es.david.caudal.domain.calc.Debts
import es.david.caudal.domain.model.DebtKind
import es.david.caudal.domain.model.DebtMove
import es.david.caudal.domain.model.Tx
import es.david.caudal.domain.model.TxType
import es.david.caudal.ui.common.BigAmountField
import es.david.caudal.ui.common.Card
import es.david.caudal.ui.common.pressable
import androidx.compose.foundation.border
import androidx.compose.ui.graphics.graphicsLayer
import es.david.caudal.ui.common.EditorScaffold
import es.david.caudal.ui.common.FinanceViewModel
import es.david.caudal.ui.common.LocalFmt
import es.david.caudal.ui.common.SegmentedPills
import es.david.caudal.ui.common.rememberHaptics
import es.david.caudal.ui.nav.PersonEditorRoute
import es.david.caudal.ui.theme.CaudalTheme

/** clave con la que el editor de personas devuelve la persona recién creada */
const val NEW_PERSON_KEY = "newPersonId"

@Composable
fun DebtEditorScreen(kind: String, personId: String?, nav: NavController) {
    val vm: FinanceViewModel = hiltViewModel()
    val ledger by vm.ledger.collectAsStateWithLifecycle()
    val f = LocalFmt.current
    val h = rememberHaptics()
    val colors = CaudalTheme.colors
    val kinds = listOf(DebtKind.OWE, DebtKind.DEBT, DebtKind.SPLIT, DebtKind.THEYPAID)

    var k by rememberSaveable { mutableStateOf(DebtKind.of(kind).takeIf { it in kinds } ?: DebtKind.OWE) }
    var digits by rememberSaveable { mutableStateOf("") }
    var concept by rememberSaveable { mutableStateOf("") }
    var selected by rememberSaveable { mutableStateOf(listOfNotNull(personId)) }
    var includeMe by rememberSaveable { mutableStateOf(true) }
    var between by rememberSaveable { mutableStateOf(2) }
    var date by rememberSaveable { mutableStateOf(Day.today) }
    var alsoTx by rememberSaveable { mutableStateOf(false) }
    var accountId by rememberSaveable { mutableStateOf<String?>(null) }
    var pickDate by rememberSaveable { mutableStateOf(false) }

    // la persona recién creada desde aquí
    val back = nav.currentBackStackEntry
    val newPerson by (back?.savedStateHandle?.getStateFlow<String?>(NEW_PERSON_KEY, null)
        ?: kotlinx.coroutines.flow.MutableStateFlow<String?>(null)).collectAsStateWithLifecycle()
    LaunchedEffect(newPerson) {
        newPerson?.let { id ->
            selected = if (k == DebtKind.SPLIT) (selected + id).distinct() else listOf(id)
            back?.savedStateHandle?.set(NEW_PERSON_KEY, null)
        }
    }

    val data = ledger?.data
    val accounts = ledger?.accounts.orEmpty()
    LaunchedEffect(accounts.isNotEmpty()) { if (accountId == null) accountId = accounts.firstOrNull()?.id }

    val amount = Money.parse(digits) ?: 0.0
    val color = when (k) {
        DebtKind.OWE -> colors.income
        DebtKind.DEBT -> colors.negative
        DebtKind.SPLIT -> colors.accent
        else -> colors.warning
    }
    val valid = amount > 0 && selected.isNotEmpty()

    val shareText = when {
        amount <= 0 -> ""
        k == DebtKind.SPLIT -> {
            val n = selected.size + if (includeMe) 1 else 0
            if (selected.isEmpty() || n == 0) stringResource(R.string.debt_choose_people)
            else stringResource(R.string.debt_each, f.money(amount / n), f.money(amount / n * selected.size))
        }
        k == DebtKind.THEYPAID -> stringResource(R.string.debt_your_share, f.money(amount / between))
        else -> ""
    }
    val defSplit = stringResource(R.string.debt_default_split)
    val defTheyPaid = stringResource(R.string.debt_default_theypaid)
    val paidBy = stringResource(R.string.debt_tx_paid_by, "%s")
    val noteTpl = stringResource(R.string.debt_tx_note, "%s")

    fun save() {
        if (!valid || data == null) { h.warning(); return }
        val c = concept.trim()
        val cents = Money.toCents(amount)
        val moves: List<DebtMove> = when (k) {
            DebtKind.SPLIT -> Debts.split(cents, selected, includeMe, c.ifEmpty { defSplit }, date)
            DebtKind.THEYPAID -> listOf(Debts.theyPaid(cents, selected.first(), between, c.ifEmpty { defTheyPaid }, date))
            else -> listOf(DebtMove(personId = selected.first(), amount = if (k == DebtKind.OWE) cents else -cents, kind = k, concept = c, date = date))
        }
        val acc = accountId
        val tx = if (alsoTx && (k == DebtKind.SPLIT || k == DebtKind.OWE) && acc != null) {
            val names = selected.mapNotNull { id -> data.people.firstOrNull { it.id == id }?.name }.joinToString(", ")
            Tx(
                type = TxType.EXPENSE, amount = cents, accountId = acc, date = date, time = Day.nowTime(),
                title = c.ifEmpty { if (k == DebtKind.SPLIT) defSplit else paidBy.format(names) }, note = noteTpl.format(names),
            )
        } else null
        vm.run {
            add(moves)
            if (tx != null) save(tx)
        }
        h.success()
        nav.popBackStack()
    }

    EditorScaffold(title = stringResource(R.string.debt_editor_title), onCancel = { nav.popBackStack() }, onSave = ::save, saveEnabled = valid) { pad ->
        Column(
            Modifier.padding(pad).imePadding().verticalScroll(rememberScrollState()).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            SegmentedPills(
                options = listOf(R.string.debt_action_owe, R.string.debt_action_debt, R.string.debt_action_split, R.string.debt_action_theypaid).map { stringResource(it) },
                selected = kinds.indexOf(k),
                onSelect = { i -> k = kinds[i]; if (k != DebtKind.SPLIT && selected.size > 1) selected = listOf(selected.first()) },
                colors = listOf(colors.income, colors.negative, colors.accent, colors.warning),
            )
            BigAmountField(digits, { digits = it }, color, autoFocus = true)
            androidx.compose.animation.AnimatedVisibility(shareText.isNotEmpty()) {
                Text(shareText, style = MaterialTheme.typography.labelLarge, color = color, textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                    modifier = Modifier.fillMaxWidth().clip(CircleShape).background(color.copy(alpha = 0.14f)).padding(horizontal = 14.dp, vertical = 9.dp))
            }

            Card(padding = 14.dp) {
                Text(
                    stringResource(when (k) { DebtKind.SPLIT -> R.string.debt_between_whom; DebtKind.THEYPAID -> R.string.debt_who_paid; else -> R.string.debt_with_whom }),
                    style = MaterialTheme.typography.titleSmall, color = colors.textDim,
                )
                Spacer(Modifier.size(12.dp))
                val people = data?.let { Debts.sorted(it.people, it.debts) }.orEmpty()
                LazyRow(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    items(people, key = { it.id }) { p ->
                        val on = p.id in selected
                        val selDesc = stringResource(R.string.debt_selected)
                        val sc by androidx.compose.animation.core.animateFloatAsState(if (on) 1.1f else 1f, androidx.compose.animation.core.spring(dampingRatio = 0.45f), label = "elegida")
                        Column(
                            Modifier
                                .clip(RoundedCornerShape(18.dp))
                                .pressable(0.88f, role = Role.Checkbox) {
                                    h.select()
                                    selected = if (k == DebtKind.SPLIT) { if (on) selected - p.id else selected + p.id } else listOf(p.id)
                                }
                                .background(if (on) color.copy(alpha = 0.14f) else Color.Transparent)
                                .alpha(if (selected.isEmpty() || on) 1f else 0.55f)
                                .padding(4.dp)
                                .semantics(mergeDescendants = true) { this.selected = on; if (on) contentDescription = "${p.name}, $selDesc" },
                            horizontalAlignment = Alignment.CenterHorizontally,
                        ) {
                            Box(Modifier.graphicsLayer { scaleX = sc; scaleY = sc }, contentAlignment = Alignment.BottomEnd) {
                                Avatar(p, vm.repo, 54.dp)
                                if (on) Icon(Icons.Filled.CheckCircle, null, tint = color, modifier = Modifier.size(20.dp).clip(CircleShape).background(Color.White))
                            }
                            Spacer(Modifier.size(6.dp))
                            Text(p.name, style = MaterialTheme.typography.labelMedium, fontWeight = if (on) FontWeight.Black else FontWeight.SemiBold,
                                maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.width(64.dp), textAlign = androidx.compose.ui.text.style.TextAlign.Center)
                        }
                    }
                    item {
                        Column(
                            Modifier.clip(RoundedCornerShape(18.dp)).pressable(0.88f) { nav.navigate(PersonEditorRoute()) }.padding(4.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                        ) {
                            Box(Modifier.size(54.dp).clip(CircleShape).background(colors.accent.copy(alpha = 0.16f)).border(2.dp, colors.accent.copy(alpha = 0.5f), CircleShape), contentAlignment = Alignment.Center) {
                                Icon(Icons.Filled.Add, null, tint = colors.accent)
                            }
                            Spacer(Modifier.size(6.dp))
                            Text(stringResource(R.string.debt_new_person), style = MaterialTheme.typography.labelMedium)
                        }
                    }
                }
                if (k == DebtKind.SPLIT) {
                    SwitchRow(stringResource(R.string.debt_include_me), includeMe) { includeMe = it }
                }
                if (k == DebtKind.THEYPAID) {
                    StepperRow(
                        stringResource(R.string.debt_between_n, between), { between = (between - 1).coerceAtLeast(2) }, { between = (between + 1).coerceAtMost(20) },
                        stringResource(R.string.debt_fewer), stringResource(R.string.debt_more), between > 2, between < 20,
                    )
                }
            }

            Card(padding = 14.dp) {
                OutlinedTextField(
                    concept, { concept = it },
                    label = { Text(stringResource(R.string.concept)) },
                    placeholder = { Text(stringResource(when (k) { DebtKind.OWE -> R.string.debt_ph_owe; DebtKind.DEBT -> R.string.debt_ph_debt; DebtKind.SPLIT -> R.string.debt_ph_split; else -> R.string.debt_ph_theypaid })) },
                    singleLine = true, shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth(),
                )
                Spacer(Modifier.size(6.dp))
                ValueRow(stringResource(R.string.date), f.header(date), { pickDate = true }, Icons.Filled.CalendarMonth)
                if (k == DebtKind.SPLIT || k == DebtKind.OWE) {
                    HorizontalDivider(color = colors.hairline)
                    SwitchRow(stringResource(R.string.debt_also_tx), alsoTx) { alsoTx = it }
                    if (alsoTx) AccountPicker(stringResource(R.string.account), accounts, accountId, { accountId = it })
                }
            }

            PillButton(stringResource(R.string.save), Icons.Filled.Check, if (valid) color else colors.textDim, Modifier.fillMaxWidth()) { save() }
        }
    }
    if (pickDate) DateDialog(date, { date = it }, { pickDate = false })
}

@Composable
fun SwitchRow(label: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    Row(
        Modifier.fillMaxWidth().heightIn(min = 48.dp).clickable(role = Role.Switch) { onChange(!checked) },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, Modifier.weight(1f), style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Bold)
        Switch(checked, null, colors = androidx.compose.material3.SwitchDefaults.colors(checkedTrackColor = CaudalTheme.colors.accent, checkedThumbColor = es.david.caudal.ui.common.contentOn(CaudalTheme.colors.accent)))
    }
}
