package es.david.caudal.ui.work

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
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.AddCircle
import androidx.compose.material.icons.filled.Business
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.NightsStay
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material.icons.filled.WbSunny
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.FilledIconButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.IconButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import es.david.caudal.R
import es.david.caudal.core.Day
import es.david.caudal.core.Money
import es.david.caudal.domain.calc.Hours
import es.david.caudal.domain.calc.WorkSummary
import es.david.caudal.domain.model.Company
import es.david.caudal.domain.model.PayStatus
import es.david.caudal.domain.model.Shift
import es.david.caudal.domain.model.newId
import es.david.caudal.ui.common.AmountText
import es.david.caudal.ui.common.Card
import es.david.caudal.ui.common.ConfirmDialog
import es.david.caudal.ui.common.FinanceViewModel
import es.david.caudal.ui.common.LocalFmt
import es.david.caudal.ui.common.Pill
import es.david.caudal.ui.common.ScreenScaffold
import es.david.caudal.ui.common.SectionHeader
import es.david.caudal.ui.common.rememberHaptics
import es.david.caudal.ui.debts.AccountPicker
import es.david.caudal.ui.debts.Legend
import es.david.caudal.ui.debts.SplitBar
import es.david.caudal.ui.debts.SwipeAction
import es.david.caudal.ui.debts.SwipeRow
import es.david.caudal.ui.debts.SwitchRow
import es.david.caudal.ui.nav.CompanyEditorRoute
import es.david.caudal.ui.nav.ShiftEditorRoute
import es.david.caudal.ui.theme.CaudalTheme
import es.david.caudal.ui.theme.hexColor
import java.time.format.TextStyle

private val SUN = Color(0xFFF0C46A)
private val MOON = Color(0xFF8FB4FF)

/** Horas trabajadas: turnos por empresa, horas normales y nocturnas, bruto, neto, pagado y pendiente */
@Composable
fun WorkScreen(nav: NavController) {
    val vm: FinanceViewModel = hiltViewModel()
    val ledger by vm.ledger.collectAsStateWithLifecycle()
    val f = LocalFmt.current
    val h = rememberHaptics()
    val data = ledger?.data

    var month by rememberSaveable { mutableStateOf(Day.monthKey(Day.today)) }
    var company by rememberSaveable { mutableStateOf<String?>(null) }
    var menu by remember { mutableStateOf(false) }
    var deleting by remember { mutableStateOf<Shift?>(null) }
    var paying by remember { mutableStateOf<Company?>(null) }

    val companies = data?.companies.orEmpty()
    // si la empresa filtrada ya no existe, se quita el filtro
    LaunchedEffect(companies.map { it.id }) { if (company != null && companies.none { it.id == company }) company = null }

    ScreenScaffold(
        title = stringResource(R.string.work_title),
        onBack = { nav.popBackStack() },
        actions = {
            Box {
                IconButton(onClick = { menu = true }) { Icon(Icons.Filled.Business, stringResource(R.string.work_companies)) }
                DropdownMenu(menu, { menu = false }) {
                    DropdownMenuItem(text = { Text(stringResource(R.string.work_new_company)) }, leadingIcon = { Icon(Icons.Filled.Business, null) },
                        onClick = { menu = false; nav.navigate(CompanyEditorRoute()) })
                    companies.forEach { c ->
                        DropdownMenuItem(text = { Text(c.name) }, leadingIcon = { Icon(Icons.Filled.Edit, null) }, onClick = { menu = false; nav.navigate(CompanyEditorRoute(c.id)) })
                    }
                }
            }
            IconButton(onClick = { h.tap(); nav.navigate(ShiftEditorRoute(null, company ?: companies.firstOrNull()?.id)) }) {
                Icon(Icons.Filled.AddCircle, stringResource(R.string.work_add_shift), tint = MaterialTheme.colorScheme.primary)
            }
        },
    ) { pad ->
        if (data == null) return@ScreenScaffold
        val list = Hours.shifts(data.shifts, month, company)
        val sum = Hours.summary(list, companies)
        LazyColumn(
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = pad.calculateTopPadding() + 4.dp, bottom = pad.calculateBottomPadding() + 32.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item {
                MonthBar(f.monthYear("$month-01"), { h.select(); month = Day.monthKey(Day.addMonths("$month-01", -1)) }, { h.select(); month = Day.monthKey(Day.addMonths("$month-01", 1)) })
            }
            if (companies.size > 1) {
                item {
                    LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        item { Pill(stringResource(R.string.work_all_companies), company == null, { company = null }) }
                        items(companies, key = { it.id }) { c -> Pill(c.name, company == c.id, { company = c.id }, selectedColor = hexColor(c.color)) }
                    }
                }
            }
            item { WorkHero(sum) }
            item { SectionHeader(stringResource(R.string.work_companies)) }
            item {
                Card(padding = 6.dp) {
                    companies.filter { company == null || it.id == company }.forEachIndexed { i, c ->
                        if (i > 0) HorizontalDivider(Modifier.padding(horizontal = 10.dp))
                        CompanyRow(c, Hours.summary(Hours.shifts(data.shifts, month, c.id), companies), onClick = { h.tap(); nav.navigate(CompanyEditorRoute(c.id)) }, onPay = { h.tap(); paying = c })
                    }
                    if (companies.isNotEmpty()) HorizontalDivider(Modifier.padding(horizontal = 10.dp))
                    Row(
                        Modifier.fillMaxWidth().heightIn(min = 52.dp).clickable(role = Role.Button) { h.tap(); nav.navigate(CompanyEditorRoute()) }.padding(horizontal = 10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(Icons.Filled.AddCircle, null, tint = MaterialTheme.colorScheme.primary)
                        Spacer(Modifier.width(10.dp))
                        Text(stringResource(R.string.work_add_company), color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.SemiBold)
                    }
                }
            }
            item { SectionHeader(stringResource(R.string.work_shifts)) }
            if (list.isEmpty()) item { Card { Text(stringResource(R.string.work_no_shifts), color = MaterialTheme.colorScheme.onSurfaceVariant) } }
            items(list, key = { it.id }) { s ->
                val c = companies.firstOrNull { it.id == s.companyId }
                val paid = s.status == PayStatus.PAGADO
                val toggle = { h.success(); vm.run { setPaid(listOf(s.id), !paid) }; Unit }
                val duplicate = { h.tap(); vm.run { save(s.copy(id = newId(), date = Day.addDays(s.date, 1), status = PayStatus.PENDIENTE, paidDate = "")) }; Unit }
                SwipeRow(
                    start = SwipeAction(stringResource(if (paid) R.string.work_mark_pending else R.string.work_mark_paid), if (paid) Icons.Filled.Schedule else Icons.Filled.CheckCircle,
                        if (paid) CaudalTheme.colors.warning else CaudalTheme.colors.income, toggle),
                    end = SwipeAction(stringResource(R.string.work_delete_shift), Icons.Filled.Delete, MaterialTheme.colorScheme.error) { h.warning(); deleting = s },
                ) {
                    ShiftRow(s, c, onClick = { nav.navigate(ShiftEditorRoute(s.id, s.companyId)) }, onToggle = toggle, onDuplicate = duplicate, onDelete = { h.warning(); deleting = s })
                }
            }
        }
    }

    deleting?.let { s ->
        ConfirmDialog(
            title = stringResource(R.string.work_confirm_delete_shift),
            message = stringResource(R.string.work_shift_desc, f.header(s.date), Hours.hm(s.start), Hours.hm(s.end), companies.firstOrNull { it.id == s.companyId }?.name ?: ""),
            confirm = stringResource(R.string.work_delete_shift),
            onConfirm = { h.heavy(); vm.run { deleteShift(s) } },
            onDismiss = { deleting = null },
        )
    }
    paying?.let { c ->
        if (data != null) PayMonthDialog(vm, c, month, data.shifts, companies, ledger?.accounts.orEmpty(), onDismiss = { paying = null })
    }
}

@Composable
fun MonthBar(label: String, onPrev: () -> Unit, onNext: () -> Unit) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        FilledIconButton(onClick = onPrev, colors = IconButtonDefaults.filledIconButtonColors(containerColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.2f), contentColor = MaterialTheme.colorScheme.primary)) {
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowLeft, stringResource(R.string.work_prev_month))
        }
        Text(label, Modifier.weight(1f).semantics { heading() }, style = MaterialTheme.typography.titleLarge, textAlign = TextAlign.Center)
        FilledIconButton(onClick = onNext, colors = IconButtonDefaults.filledIconButtonColors(containerColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.2f), contentColor = MaterialTheme.colorScheme.primary)) {
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, stringResource(R.string.work_next_month))
        }
    }
}

@Composable
private fun WorkHero(w: WorkSummary) {
    val f = LocalFmt.current
    val colors = CaudalTheme.colors
    Card(padding = 20.dp) {
        Row(verticalAlignment = Alignment.Top) {
            Column(Modifier.weight(1f)) {
                Text(stringResource(R.string.work_net_estimated), style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                AmountText(w.net, style = MaterialTheme.typography.displaySmall, weight = FontWeight.Bold)
                Text(stringResource(R.string.work_gross_value, f.money(w.gross)), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Column(horizontalAlignment = Alignment.End) {
                Text(stringResource(R.string.work_hours_value, f.hoursDec(w.totalMin)), style = MaterialTheme.typography.headlineMedium)
                Text(pluralStringResource(R.plurals.work_days, w.days, w.days), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        Spacer(Modifier.height(14.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            HourPill(Icons.Filled.WbSunny, stringResource(R.string.work_normal), f.duration(w.normalMin), SUN, Modifier.weight(1f))
            HourPill(Icons.Filled.NightsStay, stringResource(R.string.work_night), f.duration(w.nightMin), MOON, Modifier.weight(1f))
        }
        if (w.net > 0) {
            Spacer(Modifier.height(14.dp))
            SplitBar(w.paidNet, w.pendingNet, colors.income, colors.warning)
            Spacer(Modifier.height(8.dp))
            Row {
                Legend(colors.income, stringResource(R.string.work_paid), w.paidNet)
                Spacer(Modifier.weight(1f))
                Legend(colors.warning, stringResource(R.string.work_pending), w.pendingNet)
            }
        }
    }
}

@Composable
private fun HourPill(icon: ImageVector, label: String, value: String, c: Color, modifier: Modifier) {
    Row(
        modifier.clip(RoundedCornerShape(14.dp)).background(c.copy(alpha = 0.12f)).padding(12.dp).semantics(mergeDescendants = true) {},
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(icon, null, tint = c)
        Spacer(Modifier.width(8.dp))
        Column {
            Text(label, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(value, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
private fun CompanyRow(c: Company, w: WorkSummary, onClick: () -> Unit, onPay: () -> Unit) {
    val f = LocalFmt.current
    val colors = CaudalTheme.colors
    Row(
        Modifier.fillMaxWidth().clickable(role = Role.Button, onClick = onClick).heightIn(min = 64.dp).padding(horizontal = 10.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.size(12.dp).clip(CircleShape).background(hexColor(c.color)))
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f).semantics(mergeDescendants = true) {}) {
            Text(c.name, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold)
            Text(stringResource(R.string.work_company_rates, f.money(c.normalRate), f.money(c.nightRate)), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(stringResource(R.string.work_company_summary, f.hoursDec(w.totalMin), f.money(w.gross), f.money(w.net)), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        if (w.pendingNet > 0) {
            Box(
                Modifier.clip(CircleShape).background(colors.income).clickable(role = Role.Button, onClick = onPay).heightIn(min = 40.dp).padding(horizontal = 14.dp, vertical = 8.dp),
                contentAlignment = Alignment.Center,
            ) { Text(stringResource(R.string.work_collect), color = Color.Black, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.labelLarge) }
        } else if (w.totalMin > 0) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Filled.Verified, null, tint = colors.income, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(4.dp))
                Text(stringResource(R.string.work_paid), color = colors.income, fontWeight = FontWeight.Bold, style = MaterialTheme.typography.labelLarge)
            }
        }
    }
}

@Composable
private fun ShiftRow(s: Shift, c: Company?, onClick: () -> Unit, onToggle: () -> Unit, onDuplicate: () -> Unit, onDelete: () -> Unit) {
    val f = LocalFmt.current
    val colors = CaudalTheme.colors
    val r = c?.let { Hours.calc(s, it) }
    val d = Day.date(s.date)
    var menu by remember { mutableStateOf(false) }
    val paid = s.status == PayStatus.PAGADO
    Row(
        Modifier.fillMaxWidth().clickable(role = Role.Button, onClick = onClick).heightIn(min = 64.dp).padding(start = 12.dp, top = 8.dp, bottom = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Row(Modifier.weight(1f).semantics(mergeDescendants = true) {}, verticalAlignment = Alignment.CenterVertically) {
            Column(
                Modifier.size(width = 44.dp, height = 48.dp).clip(RoundedCornerShape(12.dp)).background(hexColor(c?.color ?: "#7ac8ff").copy(alpha = 0.18f)),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center,
            ) {
                Text("${d.dayOfMonth}", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                Text(d.dayOfWeek.getDisplayName(TextStyle.SHORT, f.locale).uppercase(f.locale).trimEnd('.'), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(stringResource(R.string.work_shift_times, Hours.hm(s.start), Hours.hm(s.end), f.duration(r?.totalMin ?: 0)), style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold, maxLines = 1)
                Row(verticalAlignment = Alignment.CenterVertically) {
                    if ((r?.nightMin ?: 0) > 0) {
                        Icon(Icons.Filled.NightsStay, null, tint = MOON, modifier = Modifier.size(14.dp))
                        Text(" " + stringResource(R.string.work_night_hours, f.duration(r!!.nightMin)) + "  ", style = MaterialTheme.typography.bodySmall, color = MOON)
                    }
                    Text(c?.name ?: "", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1)
                }
            }
            Column(horizontalAlignment = Alignment.End) {
                AmountText(r?.gross ?: 0.0, weight = FontWeight.Bold)
                val sc = if (paid) colors.income else colors.warning
                Text(
                    stringResource(if (paid) R.string.work_paid else R.string.work_pending),
                    Modifier.clip(CircleShape).background(sc.copy(alpha = 0.2f)).padding(horizontal = 8.dp, vertical = 3.dp),
                    color = sc, style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Bold,
                )
            }
        }
        Box {
            IconButton(onClick = { menu = true }) { Icon(Icons.Filled.MoreVert, stringResource(R.string.more_options)) }
            DropdownMenu(menu, { menu = false }) {
                DropdownMenuItem(text = { Text(stringResource(if (paid) R.string.work_mark_pending else R.string.work_mark_paid)) },
                    leadingIcon = { Icon(if (paid) Icons.Filled.Schedule else Icons.Filled.CheckCircle, null) }, onClick = { menu = false; onToggle() })
                DropdownMenuItem(text = { Text(stringResource(R.string.duplicate)) }, leadingIcon = { Icon(Icons.Filled.ContentCopy, null) }, onClick = { menu = false; onDuplicate() })
                DropdownMenuItem(text = { Text(stringResource(R.string.work_delete_shift), color = MaterialTheme.colorScheme.error) },
                    leadingIcon = { Icon(Icons.Filled.Delete, null, tint = MaterialTheme.colorScheme.error) }, onClick = { menu = false; onDelete() })
            }
        }
    }
}

/** cobrar lo pendiente del mes de una empresa */
@Composable
private fun PayMonthDialog(vm: FinanceViewModel, c: Company, month: String, shifts: List<Shift>, companies: List<Company>, accounts: List<es.david.caudal.domain.model.Account>, onDismiss: () -> Unit) {
    val f = LocalFmt.current
    val h = rememberHaptics()
    val ctx = LocalContext.current
    val w = Hours.summary(Hours.shifts(shifts, month, c.id).filter { it.status == PayStatus.PENDIENTE }, companies)
    var amount by remember { mutableStateOf(Money.editText(Money.toCents(w.net))) }
    var addIncome by remember { mutableStateOf(true) }
    var accountId by remember { mutableStateOf(c.accountId ?: accounts.firstOrNull()?.id) }
    val monthName = f.month("$month-01").lowercase(f.locale)
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.work_pay_title, monthName)) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                LabelValue(stringResource(R.string.work_pending_hours), f.duration(w.totalMin))
                LabelValue(stringResource(R.string.work_gross), f.money(w.gross))
                LabelValue(stringResource(R.string.work_net_estimated), f.money(w.net))
                Spacer(Modifier.height(6.dp))
                OutlinedTextField(amount, { amount = Money.cleanInput(it) }, label = { Text(stringResource(R.string.work_what_paid)) }, singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal), modifier = Modifier.fillMaxWidth())
                SwitchRow(stringResource(R.string.work_add_income), addIncome) { addIncome = it }
                if (addIncome) AccountPicker(stringResource(R.string.account), accounts, accountId, { accountId = it })
            }
        },
        confirmButton = {
            TextButton(onClick = {
                val cents = Money.parse(amount)?.let { Money.toCents(it) } ?: Money.toCents(w.net)
                val title = ctx.getString(R.string.work_payroll_title, c.name)
                val note = ctx.getString(R.string.work_payroll_note, f.monthYear("$month-01").lowercase(f.locale))
                vm.run { payMonth(c, month, cents, if (addIncome) accountId else null, title, note) }
                h.success(); onDismiss()
            }) { Text(stringResource(R.string.work_mark_paid_action), fontWeight = FontWeight.Bold) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) } },
    )
}

@Composable
fun LabelValue(label: String, value: String) {
    Row(Modifier.fillMaxWidth().semantics(mergeDescendants = true) {}) {
        Text(label, Modifier.weight(1f), color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(value, fontWeight = FontWeight.SemiBold)
    }
}
