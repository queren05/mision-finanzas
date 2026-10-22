package es.david.caudal.ui.work

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Business
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import es.david.caudal.R
import es.david.caudal.core.Day
import es.david.caudal.core.Money
import es.david.caudal.domain.calc.Hours
import es.david.caudal.domain.model.PayStatus
import es.david.caudal.domain.model.Shift
import es.david.caudal.domain.model.newId
import es.david.caudal.ui.common.Card
import es.david.caudal.ui.common.ConfirmDialog
import es.david.caudal.ui.common.EditorScaffold
import es.david.caudal.ui.common.FinanceViewModel
import es.david.caudal.ui.common.LocalFmt
import es.david.caudal.ui.common.SegmentedPills
import es.david.caudal.ui.common.rememberHaptics
import es.david.caudal.ui.debts.DateDialog
import es.david.caudal.ui.debts.OptionPicker
import es.david.caudal.ui.debts.StepperRow
import es.david.caudal.ui.debts.SwitchRow
import es.david.caudal.ui.debts.TimeDialog
import es.david.caudal.ui.debts.ValueRow
import es.david.caudal.ui.nav.CompanyEditorRoute
import kotlin.math.abs
import kotlin.math.max

/** clave con la que el editor de empresas devuelve la empresa recién creada */
const val NEW_COMPANY_KEY = "newCompanyId"

@Composable
fun ShiftEditorScreen(id: String?, companyId: String?, nav: NavController) {
    val vm: FinanceViewModel = hiltViewModel()
    val ledger by vm.ledger.collectAsStateWithLifecycle()
    val f = LocalFmt.current
    val h = rememberHaptics()
    val data = ledger?.data

    var loaded by rememberSaveable { mutableStateOf(false) }
    var company by rememberSaveable { mutableStateOf(companyId ?: "") }
    var multi by rememberSaveable { mutableStateOf(false) }
    var days by rememberSaveable { mutableStateOf(emptyList<String>()) }
    var date by rememberSaveable { mutableStateOf(Day.today) }
    var start by rememberSaveable { mutableStateOf(16 * 60) }
    var end by rememberSaveable { mutableStateOf(23 * 60) }
    var breakMin by rememberSaveable { mutableStateOf(0) }
    var note by rememberSaveable { mutableStateOf("") }
    var status by rememberSaveable { mutableStateOf(PayStatus.PENDIENTE) }
    var normalText by rememberSaveable { mutableStateOf("") }
    var nightText by rememberSaveable { mutableStateOf("") }
    var saveRate by rememberSaveable { mutableStateOf(false) }
    var dialog by rememberSaveable { mutableStateOf("") }
    var askDelete by rememberSaveable { mutableStateOf(false) }

    val original = data?.shifts?.firstOrNull { it.id == id }
    val companies = data?.companies.orEmpty()
    val c = companies.firstOrNull { it.id == company }

    fun loadRates(cid: String) {
        val co = companies.firstOrNull { it.id == cid } ?: return
        normalText = f.num(co.normalRate); nightText = f.num(co.nightRate)
    }

    LaunchedEffect(data != null) {
        if (data == null || loaded) return@LaunchedEffect
        if (company.isEmpty()) company = companies.firstOrNull()?.id ?: ""
        if (original != null) {
            company = original.companyId
            date = original.date; start = original.start; end = original.end % 1440; breakMin = original.breakMin; note = original.note; status = original.status
            loadRates(company)
            original.normalRate?.let { normalText = f.num(it) }
            original.nightRate?.let { nightText = f.num(it) }
        } else {
            // el último horario de esa empresa, para no tener que escribirlo cada vez
            data.shifts.filter { it.companyId == company }.maxByOrNull { it.date }?.let { last ->
                start = last.start; end = last.end % 1440; breakMin = last.breakMin
            }
            loadRates(company)
        }
        loaded = true
    }

    // la empresa recién creada desde aquí
    val back = nav.currentBackStackEntry
    val newCompany by (back?.savedStateHandle?.getStateFlow<String?>(NEW_COMPANY_KEY, null)
        ?: kotlinx.coroutines.flow.MutableStateFlow<String?>(null)).collectAsStateWithLifecycle()
    LaunchedEffect(newCompany, companies.size) {
        val nc = newCompany ?: return@LaunchedEffect
        if (companies.any { it.id == nc }) {
            company = nc; loadRates(nc); saveRate = false
            back?.savedStateHandle?.set(NEW_COMPANY_KEY, null)
        }
    }

    val normalRate = Money.parse(normalText)
    val nightRate = Money.parse(nightText)
    val rateChanged = c != null && ((normalRate?.let { abs(it - c.normalRate) > 0.001 } ?: false) || (nightRate?.let { abs(it - c.nightRate) > 0.001 } ?: false))
    val canSave = company.isNotEmpty() && !(multi && days.isEmpty())

    fun save() {
        if (!canSave || c == null) { h.warning(); return }
        val newCompanyRates = if (rateChanged && saveRate) c.copy(normalRate = normalRate ?: c.normalRate, nightRate = nightRate ?: c.nightRate) else null
        val dates = if (multi) days.sorted() else listOf(date)
        val list = dates.mapIndexed { i, d ->
            var s = original ?: Shift(companyId = company, date = d, start = 0, end = 0)
            if (i > 0) s = s.copy(id = newId())
            s = s.copy(
                companyId = company, date = d, start = start, end = end, breakMin = breakMin, note = note,
                normalRate = if (rateChanged && !saveRate) normalRate else null,
                nightRate = if (rateChanged && !saveRate) nightRate else null,
            )
            if (s.status != status) s = s.copy(status = status, paidDate = if (status == PayStatus.PAGADO) Day.today else "")
            s
        }
        vm.run {
            newCompanyRates?.let { save(it) }
            saveShifts(list)
        }
        h.success()
        nav.popBackStack()
    }

    EditorScaffold(
        title = stringResource(if (original == null) R.string.shift_new else R.string.shift_edit),
        onCancel = { nav.popBackStack() },
        onSave = ::save,
        saveEnabled = canSave,
    ) { pad ->
        Column(Modifier.padding(pad).imePadding().verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            if (companies.isEmpty()) {
                Card(padding = 14.dp) {
                    ValueRow(stringResource(R.string.work_new_company), "", { nav.navigate(CompanyEditorRoute()) }, Icons.Filled.Business)
                }
                return@Column
            }
            Card(padding = 14.dp) {
                Text(stringResource(R.string.shift_company), style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                OptionPicker(stringResource(R.string.shift_which_company), companies, c, { it.name }) { co -> company = co.id; loadRates(co.id); saveRate = false }
                ValueRow(stringResource(R.string.work_new_company), "", { nav.navigate(CompanyEditorRoute()) }, Icons.Filled.Business)
            }
            Card(padding = 14.dp) {
                if (original == null) SwitchRow(stringResource(R.string.shift_multi), multi) { multi = it }
                if (multi) MultiDatePicker(days.toSet()) { days = it.toList() }
                else ValueRow(stringResource(R.string.shift_day), f.header(date), { dialog = "date" }, Icons.Filled.CalendarMonth)
            }
            Card(padding = 14.dp) {
                Text(stringResource(R.string.shift_schedule), style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                ValueRow(stringResource(R.string.shift_start), Hours.hm(start), { dialog = "start" })
                ValueRow(stringResource(R.string.shift_end), Hours.hm(end), { dialog = "end" })
                StepperRow(
                    stringResource(R.string.shift_break, breakMin), { breakMin = max(0, breakMin - 15) }, { breakMin = minOf(240, breakMin + 15) },
                    stringResource(R.string.shift_break_less), stringResource(R.string.shift_break_more), breakMin > 0, breakMin < 240,
                )
            }
            Card(padding = 14.dp) {
                Text(stringResource(R.string.shift_rates), style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(Modifier.size(6.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    OutlinedTextField(normalText, { normalText = Money.cleanInput(it) }, label = { Text(stringResource(R.string.shift_normal_rate)) }, singleLine = true,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal), modifier = Modifier.weight(1f))
                    OutlinedTextField(nightText, { nightText = Money.cleanInput(it) }, label = { Text(stringResource(R.string.shift_night_rate)) }, singleLine = true,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal), modifier = Modifier.weight(1f))
                }
                if (rateChanged && c != null) SwitchRow(stringResource(R.string.shift_save_rate, c.name), saveRate) { saveRate = it }
            }
            if (c != null) {
                val r = Hours.calc(Shift(companyId = company, date = date, start = start, end = end, breakMin = breakMin, normalRate = normalRate, nightRate = nightRate), c)
                val n = max(1, if (multi) days.size else 1)
                Card(padding = 14.dp) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text(f.duration(r.totalMin), style = MaterialTheme.typography.headlineSmall)
                            Text(stringResource(R.string.shift_split, f.duration(r.normalMin), f.duration(r.nightMin)), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        Column(horizontalAlignment = Alignment.End) {
                            Text(f.money(r.gross * n), style = MaterialTheme.typography.titleLarge)
                            val net = f.money(Hours.net(r.gross, c) * n)
                            Text(
                                if (multi && days.size > 1) stringResource(R.string.shift_gross_days, days.size, net) else stringResource(R.string.shift_gross, net),
                                style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                }
            }
            Card(padding = 14.dp) {
                Text(stringResource(R.string.shift_status), style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(Modifier.size(8.dp))
                SegmentedPills(listOf(stringResource(R.string.work_pending), stringResource(R.string.work_paid)), if (status == PayStatus.PAGADO) 1 else 0, { status = if (it == 1) PayStatus.PAGADO else PayStatus.PENDIENTE })
                Spacer(Modifier.size(8.dp))
                HorizontalDivider(color = es.david.caudal.ui.theme.CaudalTheme.colors.hairline)
                OutlinedTextField(note, { note = it }, label = { Text(stringResource(R.string.shift_note)) }, singleLine = true, modifier = Modifier.fillMaxWidth().padding(top = 8.dp))
            }
            if (original != null) {
                es.david.caudal.ui.debts.PillButton(stringResource(R.string.shift_delete), null, es.david.caudal.ui.theme.CaudalTheme.colors.negative, Modifier.fillMaxWidth(), filled = false) { h.warning(); askDelete = true }
            }
            Spacer(Modifier.width(1.dp))
        }
    }

    when (dialog) {
        "date" -> DateDialog(date, { date = it }, { dialog = "" })
        "start" -> TimeDialog(stringResource(R.string.shift_start), start, { start = it }, { dialog = "" })
        "end" -> TimeDialog(stringResource(R.string.shift_end), end, { end = it }, { dialog = "" })
    }
    if (askDelete && original != null) {
        ConfirmDialog(
            title = stringResource(R.string.work_confirm_delete_shift),
            confirm = stringResource(R.string.work_delete_shift),
            onConfirm = { h.heavy(); vm.run { deleteShift(original) }; nav.popBackStack() },
            onDismiss = { askDelete = false },
        )
    }
}
