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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
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
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import es.david.caudal.R
import es.david.caudal.core.Money
import es.david.caudal.domain.calc.Hours
import es.david.caudal.domain.model.Company
import es.david.caudal.domain.model.PALETTE
import es.david.caudal.ui.common.Card
import es.david.caudal.ui.common.ColorRow
import es.david.caudal.ui.common.ConfirmDialog
import es.david.caudal.ui.common.EditorScaffold
import es.david.caudal.ui.common.FinanceViewModel
import es.david.caudal.ui.common.LocalFmt
import es.david.caudal.ui.common.rememberHaptics
import es.david.caudal.ui.debts.AccountPicker
import es.david.caudal.ui.debts.StepperRow
import es.david.caudal.ui.debts.TimeDialog
import es.david.caudal.ui.debts.ValueRow
import kotlin.math.round

@Composable
fun CompanyEditorScreen(id: String?, nav: NavController) {
    val vm: FinanceViewModel = hiltViewModel()
    val ledger by vm.ledger.collectAsStateWithLifecycle()
    val f = LocalFmt.current
    val h = rememberHaptics()
    val data = ledger?.data

    var c by remember { mutableStateOf<Company?>(null) }
    var normal by rememberSaveable { mutableStateOf("") }
    var night by rememberSaveable { mutableStateOf("") }
    var dialog by rememberSaveable { mutableStateOf("") }
    var askDelete by remember { mutableStateOf(false) }
    val original = data?.companies?.firstOrNull { it.id == id }

    LaunchedEffect(data != null) {
        if (data != null && c == null) {
            val co = original ?: Company(name = "", color = PALETTE[data.companies.size % PALETTE.size], accountId = ledger?.accounts?.firstOrNull()?.id)
            c = co
            normal = f.num(co.normalRate); night = f.num(co.nightRate)
        }
    }
    val co = c ?: return

    fun save() {
        val n = co.copy(
            name = co.name.trim(),
            normalRate = Money.parse(normal) ?: co.normalRate,
            nightRate = Money.parse(night) ?: co.nightRate,
        )
        vm.run { save(n) }
        h.success()
        // devuelve la empresa nueva al editor de turnos que la pidió
        if (original == null) nav.previousBackStackEntry?.savedStateHandle?.set(NEW_COMPANY_KEY, n.id)
        nav.popBackStack()
    }

    EditorScaffold(
        title = if (original == null) stringResource(R.string.work_new_company) else co.name,
        onCancel = { nav.popBackStack() },
        onSave = ::save,
        saveEnabled = co.name.isNotBlank(),
    ) { pad ->
        Column(Modifier.padding(pad).imePadding().verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Card(padding = 14.dp) {
                Text(stringResource(R.string.company_where), style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                OutlinedTextField(co.name, { c = co.copy(name = it) }, label = { Text(stringResource(R.string.company_name)) }, singleLine = true, modifier = Modifier.fillMaxWidth())
            }
            Card(padding = 14.dp) {
                Text(stringResource(R.string.company_rates), style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(Modifier.size(6.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    OutlinedTextField(normal, { normal = Money.cleanInput(it) }, label = { Text(stringResource(R.string.shift_normal_rate)) }, singleLine = true,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal), modifier = Modifier.weight(1f))
                    OutlinedTextField(night, { night = Money.cleanInput(it) }, label = { Text(stringResource(R.string.shift_night_rate)) }, singleLine = true,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal), modifier = Modifier.weight(1f))
                }
                ValueRow(stringResource(R.string.company_night_from), Hours.hm(co.nightStart), { dialog = "start" })
                ValueRow(stringResource(R.string.company_night_to), Hours.hm(co.nightEnd), { dialog = "end" })
            }
            Card(padding = 14.dp) {
                Text(stringResource(R.string.company_net), style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                StepperRow(
                    stringResource(R.string.company_ss, f.num(co.ssPct)),
                    { c = co.copy(ssPct = step(co.ssPct, -0.05, 0.0, 15.0)) }, { c = co.copy(ssPct = step(co.ssPct, 0.05, 0.0, 15.0)) },
                    stringResource(R.string.company_less), stringResource(R.string.company_more), co.ssPct > 0, co.ssPct < 15,
                )
                StepperRow(
                    stringResource(R.string.company_irpf, f.num(co.irpfPct)),
                    { c = co.copy(irpfPct = step(co.irpfPct, -0.5, 0.0, 40.0)) }, { c = co.copy(irpfPct = step(co.irpfPct, 0.5, 0.0, 40.0)) },
                    stringResource(R.string.company_less), stringResource(R.string.company_more), co.irpfPct > 0, co.irpfPct < 40,
                )
                AccountPicker(stringResource(R.string.company_account), ledger?.accounts.orEmpty(), co.accountId, { c = co.copy(accountId = it) }, allowNone = true)
            }
            Card(padding = 14.dp) {
                Text(stringResource(R.string.color), style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(Modifier.size(10.dp))
                ColorRow(co.color) { c = co.copy(color = it) }
            }
            if (original != null) {
                TextButton(onClick = { h.warning(); askDelete = true }, modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)) {
                    Text(stringResource(R.string.company_delete), color = MaterialTheme.colorScheme.error, fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }
    when (dialog) {
        "start" -> TimeDialog(stringResource(R.string.company_night_from), co.nightStart, { c = co.copy(nightStart = it) }, { dialog = "" })
        "end" -> TimeDialog(stringResource(R.string.company_night_to), co.nightEnd, { c = co.copy(nightEnd = it) }, { dialog = "" })
    }
    if (askDelete && original != null) {
        ConfirmDialog(
            title = stringResource(R.string.company_confirm_delete, original.name),
            message = stringResource(R.string.company_confirm_delete_msg),
            confirm = stringResource(R.string.company_delete),
            onConfirm = { h.heavy(); vm.run { deleteCompany(original) }; nav.popBackStack() },
            onDismiss = { askDelete = false },
        )
    }
}

/** sube o baja un porcentaje con su paso, sin salirse de los límites (y sin decimales raros) */
private fun step(v: Double, d: Double, lo: Double, hi: Double): Double = (round((v + d) * 100) / 100).coerceIn(lo, hi)

