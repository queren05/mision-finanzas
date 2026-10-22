package es.david.caudal.ui.more

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import es.david.caudal.R
import es.david.caudal.core.Day
import es.david.caudal.core.Money
import es.david.caudal.domain.model.Goal
import es.david.caudal.domain.model.PALETTE
import es.david.caudal.ui.common.AmountText
import es.david.caudal.ui.common.Card
import es.david.caudal.ui.common.ColorRow
import es.david.caudal.ui.common.ConfirmDialog
import es.david.caudal.ui.common.EditorScaffold
import es.david.caudal.ui.common.EmptyText
import es.david.caudal.ui.common.Emojis
import es.david.caudal.ui.common.FinanceViewModel
import es.david.caudal.ui.common.LocalFmt
import es.david.caudal.ui.common.ProgressBar
import es.david.caudal.ui.common.ScreenScaffold
import es.david.caudal.ui.common.rememberHaptics
import es.david.caudal.ui.nav.GoalEditorRoute
import es.david.caudal.ui.theme.hexColor
import java.time.temporal.ChronoUnit
import kotlin.math.max
import kotlin.math.roundToInt

// MARK: lista de objetivos

@Composable
fun GoalsScreen(nav: NavController) {
    val vm: FinanceViewModel = hiltViewModel()
    val ledger by vm.ledger.collectAsStateWithLifecycle()
    val l = ledger ?: return
    val f = LocalFmt.current
    val h = rememberHaptics()
    ScreenScaffold(
        stringResource(R.string.goals_title),
        onBack = { nav.popBackStack() },
        actions = { IconButton(onClick = { nav.navigate(GoalEditorRoute()) }) { Icon(Icons.Filled.Add, stringResource(R.string.goals_new)) } },
    ) { pad ->
        LazyColumn(contentPadding = listPadding(pad), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            if (l.data.goals.isEmpty()) item { EmptyText(stringResource(R.string.goals_empty)) }
            items(l.data.goals, key = { it.id }) { g ->
                val saved = l.saved(g)
                val target = max(Money.fromCents(g.target), 0.01)
                val c = hexColor(g.color)
                Card(Modifier.animateItem().clickable(role = Role.Button) { h.tap(); nav.navigate(GoalEditorRoute(g.id)) }.semantics(mergeDescendants = true) {}) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(g.icon, fontSize = 34.sp)
                        Spacer(Modifier.width(10.dp))
                        Column(Modifier.weight(1f)) {
                            Text(g.name, style = MaterialTheme.typography.titleMedium)
                            if (g.deadline.isNotEmpty()) Text(stringResource(R.string.goals_for, f.header(g.deadline)), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        Text(stringResource(R.string.goals_pct, (saved / target * 100).roundToInt()), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Black, color = c)
                    }
                    Spacer(Modifier.padding(5.dp))
                    ProgressBar(saved / target, c, height = 12.dp)
                    Spacer(Modifier.padding(5.dp))
                    Row {
                        AmountText(saved, style = MaterialTheme.typography.bodyMedium, weight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                        Text(stringResource(R.string.goals_of, f.money(Money.fromCents(g.target))), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    l.account(g.accountId)?.let { a ->
                        Text(stringResource(R.string.goals_measured_with, a.name), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    if (g.deadline.isNotEmpty() && saved < Money.fromCents(g.target)) {
                        val months = max(1L, ChronoUnit.MONTHS.between(Day.date(Day.today), Day.date(g.deadline)))
                        Text(
                            stringResource(R.string.goals_per_month, f.money((Money.fromCents(g.target) - saved) / months)),
                            style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.SemiBold, color = c,
                        )
                    }
                }
            }
        }
    }
}

// MARK: editor de objetivo

@Composable
fun GoalEditorScreen(id: String?, nav: NavController) {
    val vm: FinanceViewModel = hiltViewModel()
    val ledger by vm.ledger.collectAsStateWithLifecycle()
    val l = ledger ?: return
    val f = LocalFmt.current
    val h = rememberHaptics()
    val original = id?.let { i -> l.data.goals.firstOrNull { it.id == i } }
    var loaded by rememberSaveable { mutableStateOf(false) }
    var name by rememberSaveable { mutableStateOf("") }
    var icon by rememberSaveable { mutableStateOf("🎯") }
    var color by rememberSaveable { mutableStateOf(PALETTE[l.data.goals.size % PALETTE.size]) }
    var target by rememberSaveable { mutableStateOf("") }
    var hasDeadline by rememberSaveable { mutableStateOf(false) }
    var deadline by rememberSaveable { mutableStateOf(Day.addMonths(Day.today, 12)) }
    var accountId by rememberSaveable { mutableStateOf("") }
    var saved by rememberSaveable { mutableLongStateOf(0L) }
    var add by rememberSaveable { mutableStateOf("") }
    var askDelete by remember { mutableStateOf(false) }
    if (!loaded) {
        original?.let {
            name = it.name; icon = it.icon; color = it.color; target = Money.editText(it.target)
            hasDeadline = it.deadline.isNotEmpty(); if (hasDeadline) deadline = it.deadline
            accountId = it.accountId ?: ""; saved = it.saved
        }
        loaded = true
    }
    val parsed = Money.parse(target) ?: 0.0
    EditorScaffold(
        title = stringResource(if (original == null) R.string.goals_new else R.string.goals_edit),
        onCancel = { nav.popBackStack() },
        saveEnabled = name.isNotBlank() && parsed > 0,
        onSave = {
            val g = (original ?: Goal(name = "", target = 0)).copy(
                name = name.trim(), icon = icon.ifEmpty { "🎯" }, color = color, target = Money.toCents(parsed),
                deadline = if (hasDeadline) deadline else "", accountId = accountId.ifEmpty { null }, saved = saved,
            )
            vm.run { save(g) }
            h.success(); nav.popBackStack()
        },
    ) { pad ->
        LazyColumn(contentPadding = listPadding(pad), verticalArrangement = Arrangement.spacedBy(18.dp)) {
            item {
                FormSection {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        OutlinedTextField(icon, { v -> icon = Emojis.split(v).lastOrNull() ?: "" }, label = { Text(stringResource(R.string.accounts_icon)) },
                            singleLine = true, modifier = Modifier.width(96.dp).padding(vertical = 6.dp))
                        Spacer(Modifier.width(10.dp))
                        OutlinedTextField(name, { name = it }, label = { Text(stringResource(R.string.name)) }, singleLine = true, modifier = Modifier.weight(1f).padding(vertical = 6.dp))
                    }
                    FieldRow(stringResource(R.string.goals_target), target, { target = Money.cleanInput(it) }, numeric = true)
                    SwitchRow(stringResource(R.string.goals_deadline), hasDeadline) { hasDeadline = it }
                    if (hasDeadline) { RowDivider(); DateRow(stringResource(R.string.date), deadline) { deadline = it } }
                }
            }
            item {
                FormSection(stringResource(R.string.goals_measured)) {
                    PickerRow(
                        stringResource(R.string.goals_measured),
                        listOf("" to stringResource(R.string.goals_manual)) + l.accounts.map { it.id to "${it.icon} ${it.name}" },
                        accountId,
                    ) { accountId = it }
                }
            }
            if (accountId.isEmpty()) item {
                FormSection(stringResource(R.string.goals_saved, f.plain(Money.fromCents(saved)))) {
                    Row(Modifier.padding(vertical = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedTextField(add, { add = Money.cleanInput(it) }, label = { Text(stringResource(R.string.amount)) }, singleLine = true,
                            keyboardOptions = androidx.compose.foundation.text.KeyboardOptions(keyboardType = androidx.compose.ui.text.input.KeyboardType.Decimal),
                            modifier = Modifier.weight(1f))
                        FilledTonalButton(onClick = { Money.parse(add)?.let { saved += Money.toCents(it); add = ""; h.success() } }) { Text(stringResource(R.string.goals_add)) }
                        FilledTonalButton(onClick = { Money.parse(add)?.let { saved = max(0L, saved - Money.toCents(it)); add = ""; h.tap() } }) { Text(stringResource(R.string.goals_remove)) }
                    }
                }
            }
            item { FormSection(stringResource(R.string.color)) { Box(Modifier.padding(vertical = 12.dp)) { ColorRow(color) { color = it } } } }
            if (original != null) item {
                TextButton(onClick = { h.warning(); askDelete = true }, modifier = Modifier.fillMaxWidth()) {
                    Text(stringResource(R.string.goals_delete), color = MaterialTheme.colorScheme.error)
                }
            }
        }
    }
    if (askDelete && original != null) {
        ConfirmDialog(
            title = stringResource(R.string.goals_delete_title),
            onConfirm = { vm.run { deleteGoal(original) }; h.heavy(); nav.popBackStack() },
            onDismiss = { askDelete = false },
        )
    }
}
