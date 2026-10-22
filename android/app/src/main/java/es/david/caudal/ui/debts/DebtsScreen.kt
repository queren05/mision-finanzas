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
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.CallMade
import androidx.compose.material.icons.automirrored.filled.CallReceived
import androidx.compose.material.icons.automirrored.filled.Message
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.CreditCard
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.Group
import androidx.compose.material.icons.filled.PersonAdd
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import es.david.caudal.R
import es.david.caudal.core.Money
import es.david.caudal.data.repo.FinanceRepository
import es.david.caudal.domain.calc.Debts
import es.david.caudal.domain.model.DebtKind
import es.david.caudal.domain.model.DebtMove
import es.david.caudal.domain.model.Person
import es.david.caudal.ui.common.AmountText
import es.david.caudal.ui.common.Card
import es.david.caudal.ui.common.ConfirmDialog
import es.david.caudal.ui.common.FinanceViewModel
import es.david.caudal.ui.common.LocalFmt
import es.david.caudal.ui.common.ScreenScaffold
import es.david.caudal.ui.common.SectionHeader
import es.david.caudal.ui.common.rememberHaptics
import es.david.caudal.ui.nav.DebtEditorRoute
import es.david.caudal.ui.nav.PersonDetailRoute
import es.david.caudal.ui.nav.PersonEditorRoute
import es.david.caudal.ui.theme.CaudalTheme
import kotlinx.coroutines.launch
import kotlin.math.abs
import kotlin.math.max

/** Pestaña «Cuentas»: quién te debe y a quién debes */
@Composable
fun DebtsScreen(nav: NavController) {
    val vm: FinanceViewModel = hiltViewModel()
    val ledger by vm.ledger.collectAsStateWithLifecycle()
    val ctx = LocalContext.current
    val f = LocalFmt.current
    val h = rememberHaptics()
    val scope = rememberCoroutineScope()
    val data = ledger?.data
    val people = data?.people.orEmpty()
    val debts = data?.debts.orEmpty()

    var menu by remember { mutableStateOf(false) }
    var importing by remember { mutableStateOf(false) }
    var settling by remember { mutableStateOf<Person?>(null) }
    var deleting by remember { mutableStateOf<DebtMove?>(null) }

    ScreenScaffold(
        title = stringResource(R.string.debts_title),
        actions = {
            Box {
                IconButton(onClick = { menu = true }) { Icon(Icons.Filled.PersonAdd, stringResource(R.string.debts_add_person)) }
                DropdownMenu(menu, { menu = false }) {
                    DropdownMenuItem(text = { Text(stringResource(R.string.debts_add_person)) }, leadingIcon = { Icon(Icons.Filled.PersonAdd, null) },
                        onClick = { menu = false; nav.navigate(PersonEditorRoute()) })
                    DropdownMenuItem(text = { Text(stringResource(R.string.debts_import)) }, leadingIcon = { Icon(Icons.Filled.Download, null) },
                        onClick = { menu = false; importing = true })
                }
            }
        },
    ) { pad ->
        if (data == null) return@ScreenScaffold
        LazyColumn(
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = pad.calculateTopPadding() + 4.dp, bottom = pad.calculateBottomPadding() + 32.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            if (people.isEmpty()) {
                item { EmptyDebts(onAdd = { nav.navigate(PersonEditorRoute()) }, onImport = { importing = true }) }
                return@LazyColumn
            }
            item { DebtsHero(Debts.owedToMe(people, debts), Debts.iOwe(people, debts)) }
            item {
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    KindButton(R.string.debt_action_owe, Icons.AutoMirrored.Filled.CallReceived, CaudalTheme.colors.income, Modifier.weight(1f)) { h.tap(); nav.navigate(DebtEditorRoute(DebtKind.OWE.raw)) }
                    KindButton(R.string.debt_action_debt, Icons.AutoMirrored.Filled.CallMade, CaudalTheme.colors.negative, Modifier.weight(1f)) { h.tap(); nav.navigate(DebtEditorRoute(DebtKind.DEBT.raw)) }
                    KindButton(R.string.debt_action_split, Icons.Filled.Group, MaterialTheme.colorScheme.primary, Modifier.weight(1f)) { h.tap(); nav.navigate(DebtEditorRoute(DebtKind.SPLIT.raw)) }
                    KindButton(R.string.debt_action_theypaid, Icons.Filled.CreditCard, CaudalTheme.colors.warning, Modifier.weight(1f)) { h.tap(); nav.navigate(DebtEditorRoute(DebtKind.THEYPAID.raw)) }
                }
            }
            item { SectionHeader(stringResource(R.string.debts_people)) }
            items(Debts.sorted(people, debts), key = { "p" + it.id }) { p ->
                val b = Debts.balance(debts, p.id)
                SwipeRow(
                    start = if (b != 0L) SwipeAction(stringResource(if (b > 0) R.string.debts_paid_me else R.string.debts_i_paid), Icons.Filled.CheckCircle,
                        if (b > 0) CaudalTheme.colors.income else CaudalTheme.colors.warning) { settling = p } else null,
                    end = if (b > 0) SwipeAction(stringResource(R.string.debts_remind), Icons.AutoMirrored.Filled.Message, Color(0xFF25B562)) { h.tap(); remind(ctx, f, p, debts) } else null,
                ) {
                    PersonRow(p, b, Debts.last(debts, p.id), vm.repo) { nav.navigate(PersonDetailRoute(p.id)) }
                }
            }
            val recent = debts.sortedWith(compareByDescending<DebtMove> { it.date }.thenByDescending { it.createdMillis }).take(8)
            if (recent.isNotEmpty()) {
                item { SectionHeader(stringResource(R.string.debts_recent)) }
                items(recent, key = { "m" + it.id }) { m ->
                    SwipeRow(start = null, end = SwipeAction(stringResource(R.string.debts_delete_move), Icons.Filled.Delete, MaterialTheme.colorScheme.error) { h.warning(); deleting = m }) {
                        Box(Modifier.padding(horizontal = 12.dp)) { DebtRow(m, people.firstOrNull { it.id == m.personId }, vm.repo) }
                    }
                }
            }
        }
    }

    settling?.let { p ->
        val b = Debts.balance(debts, p.id)
        ConfirmDialog(
            title = stringResource(if (b > 0) R.string.debts_settle_title_them else R.string.debts_settle_title_me, p.name),
            message = stringResource(R.string.debts_settle_msg, f.plain(abs(Money.fromCents(b)))),
            confirm = stringResource(if (b > 0) R.string.debts_settle_yes_them else R.string.debts_settle_yes_me),
            destructive = false,
            onConfirm = {
                h.success(); vm.run { settle(p.id) }
                toast(ctx, ctx.getString(R.string.debts_settled, p.name))
            },
            onDismiss = { settling = null },
        )
    }
    deleting?.let { m ->
        ConfirmDialog(
            title = stringResource(R.string.debts_confirm_delete_move),
            message = listOf(m.concept.ifEmpty { stringResource(debtKindLabel(m.kind)) }, f.plain(abs(Money.fromCents(m.amount))), people.firstOrNull { it.id == m.personId }?.name ?: "").joinToString(" · "),
            confirm = stringResource(R.string.debts_delete_move),
            onConfirm = { h.heavy(); vm.run { deleteDebt(m) } },
            onDismiss = { deleting = null },
        )
    }
    if (importing) {
        ImportDialog(
            onImport = { text ->
                scope.launch {
                    runCatching { vm.repo.importCuentasClaras(text) }
                        .onSuccess { (a, b) -> h.success(); toast(ctx, ctx.getString(R.string.debts_import_done, a, b)) }
                        .onFailure { h.warning(); toast(ctx, ctx.getString(R.string.debts_import_invalid)) }
                }
            },
            onDismiss = { importing = false },
        )
    }
}

@Composable
private fun EmptyDebts(onAdd: () -> Unit, onImport: () -> Unit) {
    Column(Modifier.fillMaxWidth().padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Text("🤝", fontSize = 64.sp)
        Text(stringResource(R.string.debts_empty_title), style = MaterialTheme.typography.headlineSmall, textAlign = TextAlign.Center)
        Button(onClick = onAdd, modifier = Modifier.fillMaxWidth().heightIn(min = 52.dp)) {
            Icon(Icons.Filled.PersonAdd, null); Spacer(Modifier.width(8.dp)); Text(stringResource(R.string.debts_empty_add))
        }
        TextButton(onClick = onImport) { Text(stringResource(R.string.debts_import)) }
    }
}

@Composable
private fun DebtsHero(them: Long, me: Long) {
    val net = them - me
    val colors = CaudalTheme.colors
    Card(padding = 20.dp) {
        Text(stringResource(R.string.debts_total_balance), style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        AmountText(
            Money.fromCents(net), signed = net != 0L, style = MaterialTheme.typography.displaySmall, weight = FontWeight.Bold,
            color = if (net > 0) colors.income else if (net < 0) colors.negative else MaterialTheme.colorScheme.onSurface,
        )
        Text(
            stringResource(if (net > 0) R.string.debts_in_favor else if (net < 0) R.string.debts_against else R.string.debts_all_square),
            style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        if (them + me > 0) {
            Spacer(Modifier.height(10.dp))
            SplitBar(them.toDouble(), me.toDouble(), colors.income, colors.negative)
            Spacer(Modifier.height(8.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Legend(colors.income, stringResource(R.string.debts_owed_to_me), Money.fromCents(them))
                Spacer(Modifier.weight(1f))
                Legend(colors.negative, stringResource(R.string.debts_i_owe), Money.fromCents(me))
            }
        }
    }
}

/** barra repartida en dos colores (te deben / debes, pagado / pendiente) */
@Composable
fun SplitBar(a: Double, b: Double, ca: Color, cb: Color) {
    val frac = if (a + b <= 0) 0f else (a / (a + b)).toFloat()
    Row(Modifier.fillMaxWidth().height(10.dp), horizontalArrangement = Arrangement.spacedBy(3.dp)) {
        if (frac > 0f) Box(Modifier.weight(max(frac, 0.02f)).height(10.dp).clip(CircleShape).background(ca))
        if (frac < 1f) Box(Modifier.weight(max(1f - frac, 0.02f)).height(10.dp).clip(CircleShape).background(cb))
    }
}

@Composable
fun Legend(color: Color, label: String, value: Double) {
    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.semantics(mergeDescendants = true) {}) {
        Box(Modifier.size(8.dp).clip(CircleShape).background(color))
        Spacer(Modifier.width(4.dp))
        Text(label, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.width(4.dp))
        AmountText(value, style = MaterialTheme.typography.bodySmall, weight = FontWeight.SemiBold)
    }
}

@Composable
private fun KindButton(label: Int, icon: ImageVector, color: Color, modifier: Modifier, onClick: () -> Unit) {
    Column(
        modifier
            .clip(RoundedCornerShape(18.dp))
            .background(CaudalTheme.colors.card)
            .clickable(role = Role.Button, onClick = onClick)
            .heightIn(min = 72.dp)
            .padding(vertical = 14.dp, horizontal = 4.dp)
            .semantics(mergeDescendants = true) {},
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Icon(icon, null, tint = color, modifier = Modifier.size(28.dp))
        Text(stringResource(label), style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Center, maxLines = 1)
    }
}

@Composable
private fun PersonRow(p: Person, b: Long, last: DebtMove?, repo: FinanceRepository, onClick: () -> Unit) {
    val f = LocalFmt.current
    val colors = CaudalTheme.colors
    Row(
        Modifier.fillMaxWidth().clickable(role = Role.Button, onClick = onClick).heightIn(min = 64.dp).padding(horizontal = 12.dp, vertical = 8.dp)
            .semantics(mergeDescendants = true) {},
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Avatar(p, repo, 46.dp)
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Row {
                Text(p.name, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold, maxLines = 1)
                if (p.nick.isNotEmpty()) Text(" · ${p.nick}", style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1)
            }
            Text(
                last?.let { stringResource(R.string.debts_last_move, f.header(it.date).lowercase(f.locale)) } ?: stringResource(R.string.debts_no_moves),
                style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1,
            )
        }
        Column(horizontalAlignment = Alignment.End) {
            if (b == 0L) {
                Text(stringResource(R.string.debts_at_peace), fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurfaceVariant)
            } else {
                AmountText(abs(Money.fromCents(b)), weight = FontWeight.Bold, color = if (b > 0) colors.income else colors.negative)
                Text(stringResource(if (b > 0) R.string.debts_owes_you else R.string.debts_you_owe), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable
private fun ImportDialog(onImport: (String) -> Unit, onDismiss: () -> Unit) {
    var text by remember { mutableStateOf("") }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.debts_import_title)) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(stringResource(R.string.debts_import_msg), style = MaterialTheme.typography.bodyMedium)
                OutlinedTextField(text, { text = it }, label = { Text(stringResource(R.string.debts_import_hint)) }, minLines = 3, maxLines = 6, modifier = Modifier.fillMaxWidth())
            }
        },
        confirmButton = { TextButton(onClick = { onImport(text); onDismiss() }, enabled = text.isNotBlank()) { Text(stringResource(R.string.debts_import_action), fontWeight = FontWeight.Bold) } },
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) } },
    )
}
