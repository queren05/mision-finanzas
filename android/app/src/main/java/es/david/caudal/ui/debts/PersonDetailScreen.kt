package es.david.caudal.ui.debts

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
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
import androidx.compose.material.icons.automirrored.filled.Message
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.PieChart
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import es.david.caudal.R
import es.david.caudal.core.Money
import es.david.caudal.domain.calc.Debts
import es.david.caudal.domain.model.DebtKind
import es.david.caudal.domain.model.DebtMove
import es.david.caudal.ui.common.AmountText
import es.david.caudal.ui.common.Card
import es.david.caudal.ui.common.ConfirmDialog
import es.david.caudal.ui.common.EmptyText
import es.david.caudal.ui.common.FinanceViewModel
import es.david.caudal.ui.common.LocalFmt
import es.david.caudal.ui.common.ScreenScaffold
import es.david.caudal.ui.common.SectionHeader
import es.david.caudal.ui.common.rememberHaptics
import es.david.caudal.ui.nav.DebtEditorRoute
import es.david.caudal.ui.nav.PersonEditorRoute
import es.david.caudal.ui.theme.CaudalTheme
import kotlin.math.abs

@Composable
fun PersonDetailScreen(id: String, nav: NavController) {
    val vm: FinanceViewModel = hiltViewModel()
    val ledger by vm.ledger.collectAsStateWithLifecycle()
    val ctx = LocalContext.current
    val f = LocalFmt.current
    val h = rememberHaptics()
    val data = ledger?.data ?: return
    val p = data.people.firstOrNull { it.id == id }
    val colors = CaudalTheme.colors

    var askSettle by remember { mutableStateOf(false) }
    var partial by remember { mutableStateOf(false) }
    var deleting by remember { mutableStateOf<DebtMove?>(null) }

    ScreenScaffold(
        title = p?.name ?: stringResource(R.string.debts_person_deleted),
        onBack = { nav.popBackStack() },
        large = false,
        actions = { if (p != null) IconButton(onClick = { nav.navigate(PersonEditorRoute(p.id)) }) { Icon(Icons.Filled.Edit, stringResource(R.string.edit)) } },
    ) { pad ->
        if (p == null) {
            EmptyText(stringResource(R.string.debts_person_deleted), Modifier.padding(pad))
            return@ScreenScaffold
        }
        val b = Debts.balance(data.debts, p.id)
        val moves = data.debts.filter { it.personId == p.id }.sortedWith(compareByDescending<DebtMove> { it.date }.thenByDescending { it.createdMillis })
        LazyColumn(
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = pad.calculateTopPadding() + 4.dp, bottom = pad.calculateBottomPadding() + 32.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item {
                Column(Modifier.fillMaxWidth().padding(vertical = 8.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Avatar(p, vm.repo, 92.dp)
                    Text(p.name, style = MaterialTheme.typography.headlineSmall)
                    if (p.nick.isNotEmpty()) Text(p.nick, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    if (b == 0L) Text(stringResource(R.string.debts_at_peace), style = MaterialTheme.typography.displaySmall, fontWeight = FontWeight.Bold)
                    else AmountText(abs(Money.fromCents(b)), style = MaterialTheme.typography.displaySmall, weight = FontWeight.Bold, color = if (b > 0) colors.income else colors.negative)
                    Text(
                        stringResource(if (b > 0) R.string.debts_owes_you else if (b < 0) R.string.debts_you_owe else R.string.debts_nothing_owed),
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            if (b != 0L) {
                item {
                    Button(
                        onClick = { h.tap(); askSettle = true },
                        modifier = Modifier.fillMaxWidth().heightIn(min = 52.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = if (b > 0) colors.income else colors.warning, contentColor = Color.Black),
                    ) {
                        Icon(Icons.Filled.CheckCircle, null); Spacer(Modifier.width(8.dp))
                        Text(stringResource(if (b > 0) R.string.debts_settle_all_them else R.string.debts_settle_all_me), fontWeight = FontWeight.Bold)
                    }
                }
                item {
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        OutlinedButton(onClick = { partial = true }, modifier = Modifier.weight(1f).heightIn(min = 48.dp)) {
                            Icon(Icons.Filled.PieChart, null); Spacer(Modifier.width(6.dp)); Text(stringResource(R.string.debts_partial))
                        }
                        if (b > 0) {
                            OutlinedButton(onClick = { h.tap(); remind(ctx, f, p, data.debts) }, modifier = Modifier.weight(1f).heightIn(min = 48.dp)) {
                                Icon(Icons.AutoMirrored.Filled.Message, null, tint = Color(0xFF25B562)); Spacer(Modifier.width(6.dp)); Text(stringResource(R.string.debts_remind))
                            }
                        }
                    }
                }
            }
            item {
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    SmallKind(R.string.debt_action_owe, colors.income, Modifier.weight(1f)) { h.tap(); nav.navigate(DebtEditorRoute(DebtKind.OWE.raw, p.id)) }
                    SmallKind(R.string.debt_action_debt, colors.negative, Modifier.weight(1f)) { h.tap(); nav.navigate(DebtEditorRoute(DebtKind.DEBT.raw, p.id)) }
                    SmallKind(R.string.debt_action_split, MaterialTheme.colorScheme.primary, Modifier.weight(1f)) { h.tap(); nav.navigate(DebtEditorRoute(DebtKind.SPLIT.raw, p.id)) }
                }
            }
            item { SectionHeader(stringResource(R.string.debts_history)) }
            if (moves.isEmpty()) item { Card { Text(stringResource(R.string.debts_no_moves), color = MaterialTheme.colorScheme.onSurfaceVariant) } }
            items(moves, key = { it.id }) { m ->
                SwipeRow(start = null, end = SwipeAction(stringResource(R.string.debts_delete_move), Icons.Filled.Delete, MaterialTheme.colorScheme.error) { h.warning(); deleting = m }) {
                    Box(Modifier.padding(horizontal = 12.dp)) { DebtRow(m, p, vm.repo, showName = false) }
                }
            }
        }
    }

    if (p != null) {
        val b = Debts.balance(data.debts, p.id)
        if (askSettle) {
            ConfirmDialog(
                title = stringResource(if (b > 0) R.string.debts_settle_title_them else R.string.debts_settle_title_me, p.name),
                message = stringResource(R.string.debts_settle_msg, f.plain(abs(Money.fromCents(b)))),
                confirm = stringResource(if (b > 0) R.string.debts_settle_yes_them else R.string.debts_settle_yes_me),
                destructive = false,
                onConfirm = { h.success(); vm.run { settle(p.id) } },
                onDismiss = { askSettle = false },
            )
        }
        if (partial) {
            var text by remember { mutableStateOf("") }
            AlertDialog(
                onDismissRequest = { partial = false },
                title = { Text(stringResource(R.string.debts_partial)) },
                text = {
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Text(stringResource(if (b > 0) R.string.debts_partial_them else R.string.debts_partial_me, p.name))
                        OutlinedTextField(text, { text = Money.cleanInput(it) }, label = { Text(stringResource(R.string.amount)) }, singleLine = true,
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal), modifier = Modifier.fillMaxWidth())
                    }
                },
                confirmButton = {
                    TextButton(onClick = {
                        val v = Money.parse(text)
                        if (v != null && v > 0) { h.success(); vm.run { settle(p.id, Money.toCents(v)) } }
                        partial = false
                    }) { Text(stringResource(R.string.debts_partial_action), fontWeight = FontWeight.Bold) }
                },
                dismissButton = { TextButton(onClick = { partial = false }) { Text(stringResource(R.string.cancel)) } },
            )
        }
    }
    deleting?.let { m ->
        ConfirmDialog(
            title = stringResource(R.string.debts_confirm_delete_move),
            message = listOf(m.concept.ifEmpty { stringResource(debtKindLabel(m.kind)) }, f.plain(abs(Money.fromCents(m.amount)))).joinToString(" · "),
            confirm = stringResource(R.string.debts_delete_move),
            onConfirm = { h.heavy(); vm.run { deleteDebt(m) } },
            onDismiss = { deleting = null },
        )
    }
}

@Composable
private fun SmallKind(label: Int, color: Color, modifier: Modifier, onClick: () -> Unit) {
    Box(
        modifier.clip(RoundedCornerShape(14.dp)).background(color.copy(alpha = 0.18f)).clickable(role = Role.Button, onClick = onClick)
            .heightIn(min = 48.dp).padding(vertical = 12.dp),
        contentAlignment = Alignment.Center,
    ) { Text(stringResource(label), color = color, fontWeight = FontWeight.SemiBold, style = MaterialTheme.typography.labelLarge) }
}
