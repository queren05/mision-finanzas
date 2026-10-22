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
import es.david.caudal.ui.debts.Celebration
import es.david.caudal.ui.common.CircleIconButton
import es.david.caudal.ui.common.EmptyState
import es.david.caudal.ui.common.GroupCard
import es.david.caudal.ui.common.Mood
import es.david.caudal.ui.common.RowDivider
import es.david.caudal.ui.common.appear
import es.david.caudal.ui.common.contentOn
import es.david.caudal.ui.common.pressable
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.ui.graphics.Brush
import androidx.compose.material.icons.filled.Add
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
    var celebrate by remember { mutableStateOf<Long?>(null) }
    var celebrateText by remember { mutableStateOf("") }

    val companies = data?.companies.orEmpty()
    // si la empresa filtrada ya no existe, se quita el filtro
    LaunchedEffect(companies.map { it.id }) { if (company != null && companies.none { it.id == company }) company = null }

    Box(Modifier.fillMaxSize()) {
    ScreenScaffold(
        title = stringResource(R.string.work_title),
        onBack = { nav.popBackStack() },
        actions = {
            Box {
                CircleIconButton(Icons.Filled.Business, stringResource(R.string.work_more_menu)) { menu = true }
                DropdownMenu(menu, { menu = false }, shape = RoundedCornerShape(20.dp), containerColor = CaudalTheme.colors.card) {
                    DropdownMenuItem(text = { Text(stringResource(R.string.work_new_company)) }, leadingIcon = { Icon(Icons.Filled.Business, null) },
                        onClick = { menu = false; nav.navigate(CompanyEditorRoute()) })
                    companies.forEach { c ->
                        DropdownMenuItem(text = { Text(c.name) }, leadingIcon = { Icon(Icons.Filled.Edit, null) }, onClick = { menu = false; nav.navigate(CompanyEditorRoute(c.id)) })
                    }
                }
            }
            CircleIconButton(Icons.Filled.Add, stringResource(R.string.work_add_shift), tint = CaudalTheme.colors.accent) {
                h.tap(); nav.navigate(ShiftEditorRoute(null, company ?: companies.firstOrNull()?.id))
            }
        },
    ) { pad ->
        if (data == null) return@ScreenScaffold
        val list = Hours.shifts(data.shifts, month, company)
        val sum = Hours.summary(list, companies)
        LazyColumn(
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = pad.calculateTopPadding() + 4.dp, bottom = 60.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
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
            item { Box(Modifier.appear(0)) { WorkHero(sum) } }
            item { Box(Modifier.appear(1).padding(start = 4.dp, top = 4.dp)) { SectionHeader(stringResource(R.string.work_companies), emoji = "🏢") } }
            item {
                GroupCard(Modifier.appear(2)) {
                    companies.filter { company == null || it.id == company }.forEach { c ->
                        CompanyRow(c, Hours.summary(Hours.shifts(data.shifts, month, c.id), companies), onClick = { h.tap(); nav.navigate(CompanyEditorRoute(c.id)) }, onPay = { h.tap(); paying = c })
                        RowDivider(16.dp)
                    }
                    Row(
                        Modifier.fillMaxWidth().pressable(0.985f) { h.tap(); nav.navigate(CompanyEditorRoute()) }.heightIn(min = 56.dp).padding(horizontal = 16.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(Icons.Filled.AddCircle, null, tint = CaudalTheme.colors.accent)
                        Spacer(Modifier.width(10.dp))
                        Text(stringResource(R.string.work_add_company), color = CaudalTheme.colors.accent, style = MaterialTheme.typography.labelLarge)
                    }
                }
            }
            item { Box(Modifier.appear(3).padding(start = 4.dp, top = 4.dp)) { SectionHeader(stringResource(R.string.work_shifts), emoji = "⏱️") } }
            item {
                if (list.isEmpty()) EmptyState(stringResource(R.string.work_no_shifts), stringResource(R.string.work_empty_text), mood = Mood.SLEEPY)
                else GroupCard(Modifier.appear(4)) {
                    list.forEachIndexed { i, s ->
                        val c = companies.firstOrNull { it.id == s.companyId }
                        val paid = s.status == PayStatus.PAGADO
                        val toggle = { h.success(); vm.run { setPaid(listOf(s.id), !paid) }; Unit }
                        val duplicate = { h.tap(); vm.run { save(s.copy(id = newId(), date = Day.addDays(s.date, 1), status = PayStatus.PENDIENTE, paidDate = "")) }; Unit }
                        SwipeRow(
                            start = SwipeAction(stringResource(if (paid) R.string.work_mark_pending else R.string.work_mark_paid), if (paid) Icons.Filled.Schedule else Icons.Filled.CheckCircle,
                                if (paid) CaudalTheme.colors.warning else CaudalTheme.colors.income, toggle),
                            end = SwipeAction(stringResource(R.string.work_delete_shift), Icons.Filled.Delete, CaudalTheme.colors.negative) { h.warning(); deleting = s },
                        ) {
                            ShiftRow(s, c, onClick = { nav.navigate(ShiftEditorRoute(s.id, s.companyId)) }, onToggle = toggle, onDuplicate = duplicate, onDelete = { h.warning(); deleting = s })
                        }
                        if (i < list.lastIndex) RowDivider(72.dp)
                    }
                }
            }
        }
    }
    Celebration(celebrate, celebrateText)
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
        if (data != null) PayMonthDialog(vm, c, month, data.shifts, companies, ledger?.accounts.orEmpty(), onDismiss = { paying = null }, onPaid = { name ->
            celebrateText = name; celebrate = System.nanoTime()
        })
    }
}

@Composable
fun MonthBar(label: String, onPrev: () -> Unit, onNext: () -> Unit) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        CircleIconButton(Icons.AutoMirrored.Filled.KeyboardArrowLeft, stringResource(R.string.work_prev_month), onClick = onPrev)
        androidx.compose.animation.AnimatedContent(label, Modifier.weight(1f), label = "mes") { t ->
            Text(t, Modifier.fillMaxWidth().semantics { heading() }, style = MaterialTheme.typography.titleLarge, textAlign = TextAlign.Center)
        }
        CircleIconButton(Icons.AutoMirrored.Filled.KeyboardArrowRight, stringResource(R.string.work_next_month), onClick = onNext)
    }
}

@Composable
private fun WorkHero(w: WorkSummary) {
    val f = LocalFmt.current
    val colors = CaudalTheme.colors
    Card(padding = 20.dp) {
        Row(verticalAlignment = Alignment.Top) {
            Column(Modifier.weight(1f)) {
                Text(stringResource(R.string.work_net_estimated), style = MaterialTheme.typography.titleSmall, color = colors.textDim)
                AmountText(w.net, style = MaterialTheme.typography.displayMedium, rolling = true)
                Text(stringResource(R.string.work_gross_value, f.money(w.gross)), style = MaterialTheme.typography.bodyMedium, color = colors.textDim)
            }
            Column(
                Modifier.clip(RoundedCornerShape(18.dp)).background(colors.accent.copy(alpha = 0.14f)).padding(horizontal = 12.dp, vertical = 8.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(stringResource(R.string.work_hours_value, f.hoursDec(w.totalMin)), style = MaterialTheme.typography.headlineSmall, color = colors.accent)
                Text(pluralStringResource(R.plurals.work_days, w.days, w.days), style = MaterialTheme.typography.labelMedium, color = colors.textDim)
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
        modifier.clip(RoundedCornerShape(20.dp)).background(c.copy(alpha = 0.14f)).padding(12.dp).semantics(mergeDescendants = true) {},
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.size(38.dp).clip(CircleShape).background(c.copy(alpha = 0.28f)), contentAlignment = Alignment.Center) { Icon(icon, null, tint = c) }
        Spacer(Modifier.width(10.dp))
        Column {
            Text(label, style = MaterialTheme.typography.labelMedium, color = CaudalTheme.colors.textDim)
            Text(value, style = MaterialTheme.typography.titleMedium)
        }
    }
}

@Composable
private fun CompanyRow(c: Company, w: WorkSummary, onClick: () -> Unit, onPay: () -> Unit) {
    val f = LocalFmt.current
    val colors = CaudalTheme.colors
    Row(
        Modifier.fillMaxWidth().pressable(0.985f, onClick = onClick).heightIn(min = 70.dp).padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.size(40.dp).clip(RoundedCornerShape(14.dp)).background(hexColor(c.color).copy(alpha = 0.25f)), contentAlignment = Alignment.Center) {
            Icon(Icons.Filled.Business, null, tint = hexColor(c.color))
        }
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f).semantics(mergeDescendants = true) {}) {
            Text(c.name, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.ExtraBold)
            Text(stringResource(R.string.work_company_rates, f.money(c.normalRate), f.money(c.nightRate)), style = MaterialTheme.typography.bodySmall, color = colors.textDim)
            Text(stringResource(R.string.work_company_summary, f.hoursDec(w.totalMin), f.money(w.gross), f.money(w.net)), style = MaterialTheme.typography.bodySmall, color = colors.textDim)
        }
        if (w.pendingNet > 0) {
            Box(
                Modifier.pressable(0.9f, onClick = onPay).clip(CircleShape).background(Brush.horizontalGradient(listOf(colors.income.copy(alpha = 0.8f), colors.income))).heightIn(min = 40.dp).padding(horizontal = 16.dp, vertical = 9.dp),
                contentAlignment = Alignment.Center,
            ) { Text(stringResource(R.string.work_collect), color = contentOn(colors.income), style = MaterialTheme.typography.labelLarge) }
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
        Modifier.fillMaxWidth().background(colors.card).pressable(0.985f, onClick = onClick).heightIn(min = 70.dp).padding(start = 14.dp, top = 8.dp, bottom = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Row(Modifier.weight(1f).semantics(mergeDescendants = true) {}, verticalAlignment = Alignment.CenterVertically) {
            Column(
                Modifier.size(width = 46.dp, height = 52.dp).clip(RoundedCornerShape(15.dp))
                    .background(Brush.verticalGradient(listOf(hexColor(c?.color ?: "#7ac8ff").copy(alpha = 0.35f), hexColor(c?.color ?: "#7ac8ff").copy(alpha = 0.15f)))),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center,
            ) {
                Text("${d.dayOfMonth}", style = MaterialTheme.typography.titleLarge)
                Text(d.dayOfWeek.getDisplayName(TextStyle.SHORT, f.locale).uppercase(f.locale).trimEnd('.'), style = MaterialTheme.typography.labelSmall, color = colors.textDim)
            }
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(stringResource(R.string.work_shift_times, Hours.hm(s.start), Hours.hm(s.end), f.duration(r?.totalMin ?: 0)), style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.ExtraBold, maxLines = 1)
                Row(verticalAlignment = Alignment.CenterVertically) {
                    if ((r?.nightMin ?: 0) > 0) {
                        Icon(Icons.Filled.NightsStay, null, tint = MOON, modifier = Modifier.size(14.dp))
                        Text(" " + stringResource(R.string.work_night_hours, f.duration(r!!.nightMin)) + "  ", style = MaterialTheme.typography.bodySmall, color = MOON)
                    }
                    Text(c?.name ?: "", style = MaterialTheme.typography.bodySmall, color = colors.textDim, maxLines = 1)
                }
            }
            Column(horizontalAlignment = Alignment.End) {
                AmountText(r?.gross ?: 0.0, weight = FontWeight.ExtraBold)
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
            DropdownMenu(menu, { menu = false }, shape = RoundedCornerShape(20.dp), containerColor = colors.card) {
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
private fun PayMonthDialog(vm: FinanceViewModel, c: Company, month: String, shifts: List<Shift>, companies: List<Company>, accounts: List<es.david.caudal.domain.model.Account>, onDismiss: () -> Unit, onPaid: (String) -> Unit = {}) {
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
        shape = RoundedCornerShape(28.dp),
        containerColor = CaudalTheme.colors.card,
        title = { Text(stringResource(R.string.work_pay_title, monthName), style = MaterialTheme.typography.titleLarge) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                LabelValue(stringResource(R.string.work_pending_hours), f.duration(w.totalMin))
                LabelValue(stringResource(R.string.work_gross), f.money(w.gross))
                LabelValue(stringResource(R.string.work_net_estimated), f.money(w.net))
                Spacer(Modifier.height(6.dp))
                OutlinedTextField(amount, { amount = Money.cleanInput(it) }, label = { Text(stringResource(R.string.work_what_paid)) }, singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal), shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth())
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
                h.success(); onPaid(ctx.getString(R.string.work_celebrate_paid, c.name)); onDismiss()
            }) { Text(stringResource(R.string.work_mark_paid_action), fontWeight = FontWeight.ExtraBold, color = CaudalTheme.colors.income) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) } },
    )
}

@Composable
fun LabelValue(label: String, value: String) {
    Row(Modifier.fillMaxWidth().semantics(mergeDescendants = true) {}) {
        Text(label, Modifier.weight(1f), color = CaudalTheme.colors.textDim)
        Text(value, fontWeight = FontWeight.ExtraBold)
    }
}
