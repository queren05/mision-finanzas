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
import es.david.caudal.ui.common.CircleIconButton
import es.david.caudal.ui.common.EmptyState
import es.david.caudal.ui.common.GroupCard
import es.david.caudal.ui.common.Mood
import es.david.caudal.ui.common.RowDivider
import es.david.caudal.ui.common.appear
import es.david.caudal.ui.common.breathe
import es.david.caudal.ui.theme.hexColor
import androidx.compose.ui.graphics.Brush
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material.icons.automirrored.filled.CallMade
import androidx.compose.material.icons.automirrored.filled.CallReceived
import androidx.compose.material.icons.filled.Group
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
    var celebrate by remember { mutableStateOf<Long?>(null) }
    var celebrateText by remember { mutableStateOf("") }

    Box(Modifier.fillMaxSize()) {
    ScreenScaffold(
        title = p?.name ?: stringResource(R.string.debts_person_deleted),
        onBack = { nav.popBackStack() },
        large = false,
        actions = { if (p != null) CircleIconButton(Icons.Filled.Edit, stringResource(R.string.edit)) { nav.navigate(PersonEditorRoute(p.id)) } },
    ) { pad ->
        if (p == null) {
            EmptyText(stringResource(R.string.debts_person_deleted), Modifier.padding(pad))
            return@ScreenScaffold
        }
        val b = Debts.balance(data.debts, p.id)
        val moves = data.debts.filter { it.personId == p.id }.sortedWith(compareByDescending<DebtMove> { it.date }.thenByDescending { it.createdMillis })
        LazyColumn(
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = pad.calculateTopPadding() + 4.dp, bottom = 48.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            item {
                val pc = hexColor(p.color)
                Column(
                    Modifier.fillMaxWidth().appear(0).clip(RoundedCornerShape(30.dp))
                        .background(Brush.verticalGradient(listOf(pc.copy(alpha = 0.32f), colors.card)))
                        .border(1.dp, colors.hairline, RoundedCornerShape(30.dp))
                        .padding(vertical = 22.dp, horizontal = 16.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Box(Modifier.breathe(0.03f)) { Avatar(p, vm.repo, 104.dp) }
                    Text(p.name, style = MaterialTheme.typography.headlineMedium)
                    if (p.nick.isNotEmpty()) Text(p.nick, color = colors.textDim)
                    if (b == 0L) Text(stringResource(R.string.debts_at_peace), style = MaterialTheme.typography.displaySmall)
                    else AmountText(abs(Money.fromCents(b)), style = MaterialTheme.typography.displayMedium, rolling = true, color = if (b > 0) colors.income else colors.negative)
                    Text(
                        stringResource(if (b > 0) R.string.debts_owes_you else if (b < 0) R.string.debts_you_owe else R.string.debts_nothing_owed),
                        style = MaterialTheme.typography.labelLarge, color = colors.textDim,
                    )
                }
            }
            if (b != 0L) {
                item {
                    PillButton(
                        stringResource(if (b > 0) R.string.debts_settle_all_them else R.string.debts_settle_all_me), Icons.Filled.CheckCircle,
                        if (b > 0) colors.income else colors.warning, Modifier.fillMaxWidth().appear(1),
                    ) { h.tap(); askSettle = true }
                }
                item {
                    Row(Modifier.appear(2), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        PillButton(stringResource(R.string.debts_partial), Icons.Filled.PieChart, colors.accent, Modifier.weight(1f), filled = false) { partial = true }
                        if (b > 0) PillButton(stringResource(R.string.debts_remind), Icons.AutoMirrored.Filled.Message, Color(0xFF25B562), Modifier.weight(1f), filled = false) { h.tap(); remind(ctx, f, p, data.debts) }
                    }
                }
            }
            item {
                Row(Modifier.appear(3), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    ActionTile(stringResource(R.string.debt_action_owe), Icons.AutoMirrored.Filled.CallReceived, colors.income, Modifier.weight(1f)) { h.tap(); nav.navigate(DebtEditorRoute(DebtKind.OWE.raw, p.id)) }
                    ActionTile(stringResource(R.string.debt_action_debt), Icons.AutoMirrored.Filled.CallMade, colors.negative, Modifier.weight(1f)) { h.tap(); nav.navigate(DebtEditorRoute(DebtKind.DEBT.raw, p.id)) }
                    ActionTile(stringResource(R.string.debt_action_split), Icons.Filled.Group, colors.accent, Modifier.weight(1f)) { h.tap(); nav.navigate(DebtEditorRoute(DebtKind.SPLIT.raw, p.id)) }
                }
            }
            item { Box(Modifier.appear(4).padding(start = 4.dp, top = 6.dp)) { SectionHeader(stringResource(R.string.debts_history), emoji = "📜") } }
            item {
                if (moves.isEmpty()) EmptyState(stringResource(R.string.debts_no_moves), mood = Mood.SLEEPY)
                else GroupCard(Modifier.appear(5)) {
                    moves.forEachIndexed { i, m ->
                        SwipeRow(start = null, end = SwipeAction(stringResource(R.string.debts_delete_move), Icons.Filled.Delete, colors.negative) { h.warning(); deleting = m }) {
                            DebtRow(m, null, vm.repo, showName = false)
                        }
                        if (i < moves.lastIndex) RowDivider(70.dp)
                    }
                }
            }
        }
    }
    Celebration(celebrate, celebrateText)
    }

    if (p != null) {
        val b = Debts.balance(data.debts, p.id)
        if (askSettle) {
            ConfirmDialog(
                title = stringResource(if (b > 0) R.string.debts_settle_title_them else R.string.debts_settle_title_me, p.name),
                message = stringResource(R.string.debts_settle_msg, f.plain(abs(Money.fromCents(b)))),
                confirm = stringResource(if (b > 0) R.string.debts_settle_yes_them else R.string.debts_settle_yes_me),
                destructive = false,
                onConfirm = { h.success(); vm.run { settle(p.id) }; celebrateText = ctx.getString(R.string.debts_settled, p.name); celebrate = System.nanoTime() },
                onDismiss = { askSettle = false },
            )
        }
        if (partial) {
            var text by remember { mutableStateOf("") }
            AlertDialog(
                onDismissRequest = { partial = false },
                shape = RoundedCornerShape(28.dp),
                containerColor = colors.card,
                title = { Text(stringResource(R.string.debts_partial), style = MaterialTheme.typography.titleLarge) },
                text = {
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Text(stringResource(if (b > 0) R.string.debts_partial_them else R.string.debts_partial_me, p.name))
                        OutlinedTextField(text, { text = Money.cleanInput(it) }, label = { Text(stringResource(R.string.amount)) }, singleLine = true,
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal), shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth())
                    }
                },
                confirmButton = {
                    TextButton(onClick = {
                        val v = Money.parse(text)
                        if (v != null && v > 0) {
                            h.success(); vm.run { settle(p.id, Money.toCents(v)) }
                            if (Money.toCents(v) >= abs(b)) { celebrateText = ctx.getString(R.string.debts_settled, p.name); celebrate = System.nanoTime() }
                        }
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

