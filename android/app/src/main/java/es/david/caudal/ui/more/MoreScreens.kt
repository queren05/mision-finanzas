package es.david.caudal.ui.more

import android.annotation.SuppressLint
import android.content.Context
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.biometric.BiometricManager
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountBalance
import androidx.compose.material.icons.filled.Backup
import androidx.compose.material.icons.filled.Category
import androidx.compose.material.icons.filled.DeleteForever
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.filled.PieChart
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.Repeat
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Upload
import androidx.compose.material.icons.filled.Work
import androidx.compose.material3.AlertDialog
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
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import es.david.caudal.BuildConfig
import es.david.caudal.R
import es.david.caudal.core.Day
import es.david.caudal.data.backup.Backup
import es.david.caudal.domain.calc.Hours
import es.david.caudal.domain.model.ThemeMode
import es.david.caudal.ui.common.AmountText
import es.david.caudal.ui.common.ColorRow
import es.david.caudal.ui.common.ConfirmDialog
import es.david.caudal.ui.common.FinanceViewModel
import es.david.caudal.ui.common.LocalFmt
import es.david.caudal.ui.common.ScreenScaffold
import es.david.caudal.ui.common.rememberHaptics
import es.david.caudal.ui.nav.AccountsRoute
import es.david.caudal.ui.nav.CategoriesRoute
import es.david.caudal.ui.nav.DataRoute
import es.david.caudal.ui.nav.GoalsRoute
import es.david.caudal.ui.nav.RecurringRoute
import es.david.caudal.ui.nav.SettingsRoute
import es.david.caudal.ui.nav.StatsRoute
import es.david.caudal.ui.nav.WorkRoute
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** margen de las listas: el de la barra de arriba y 16 dp a los lados */
internal fun listPadding(pad: PaddingValues) = PaddingValues(start = 16.dp, end = 16.dp, top = pad.calculateTopPadding() + 8.dp, bottom = pad.calculateBottomPadding() + 32.dp)

// MARK: Más

@Composable
fun MoreScreen(nav: NavController) {
    val vm: FinanceViewModel = hiltViewModel()
    val ledger by vm.ledger.collectAsStateWithLifecycle()
    val settings by vm.settings.collectAsStateWithLifecycle()
    val l = ledger ?: return
    val s = settings ?: return
    val f = LocalFmt.current
    ScreenScaffold(stringResource(R.string.more_title)) { pad ->
        LazyColumn(contentPadding = listPadding(pad), verticalArrangement = Arrangement.spacedBy(18.dp)) {
            item {
                Row(Modifier.fillMaxWidth().semantics(mergeDescendants = true) {}, verticalAlignment = Alignment.CenterVertically) {
                    Box(Modifier.size(58.dp).clip(CircleShape).background(MaterialTheme.colorScheme.primary), contentAlignment = Alignment.Center) {
                        Text(s.name.take(1).uppercase(), style = MaterialTheme.typography.headlineSmall, color = MaterialTheme.colorScheme.onPrimary)
                    }
                    Spacer(Modifier.width(14.dp))
                    Column {
                        if (s.name.isNotEmpty()) Text(s.name, style = MaterialTheme.typography.titleLarge)
                        AmountText(l.netWorth, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
            item {
                FormSection(stringResource(R.string.more_management)) {
                    NavRow(Icons.Filled.PieChart, Color(0xFF4AD68F), stringResource(R.string.analysis)) { nav.navigate(StatsRoute) }
                    if (s.moduleWork) {
                        val month = Day.monthKey(Day.today)
                        val sum = Hours.summary(Hours.shifts(l.data.shifts, month), l.data.companies)
                        RowDivider()
                        NavRow(Icons.Filled.Work, Color(0xFF62CFD0), stringResource(R.string.more_work), stringResource(R.string.more_hours_value, f.hoursDec(sum.totalMin))) { nav.navigate(WorkRoute) }
                    }
                    RowDivider()
                    NavRow(Icons.Filled.AccountBalance, Color(0xFF8FB4FF), stringResource(R.string.more_accounts), "${l.accounts.size}") { nav.navigate(AccountsRoute) }
                    RowDivider()
                    NavRow(Icons.Filled.Category, Color(0xFFFF9F7A), stringResource(R.string.more_categories), "${l.data.categories.size}") { nav.navigate(CategoriesRoute) }
                    RowDivider()
                    NavRow(Icons.Filled.Repeat, Color(0xFFB39CFF), stringResource(R.string.more_recurring), "${l.data.recurring.count { it.active }}") { nav.navigate(RecurringRoute) }
                    RowDivider()
                    NavRow(Icons.Filled.Flag, Color(0xFFF59FC4), stringResource(R.string.more_goals), "${l.data.goals.size}") { nav.navigate(GoalsRoute) }
                }
            }
            item {
                FormSection {
                    NavRow(Icons.Filled.Settings, Color(0xFFA9B3C2), stringResource(R.string.more_settings)) { nav.navigate(SettingsRoute) }
                    RowDivider()
                    NavRow(Icons.Filled.Backup, Color(0xFFF0C46A), stringResource(R.string.more_data)) { nav.navigate(DataRoute) }
                }
            }
            item {
                FormSection {
                    Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).semantics(mergeDescendants = true) {}, verticalAlignment = Alignment.CenterVertically) {
                        Text(stringResource(R.string.more_version), Modifier.weight(1f))
                        Text(BuildConfig.VERSION_NAME, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
        }
    }
}

// MARK: Ajustes

private val CURRENCIES = listOf("EUR", "USD", "GBP", "MXN", "ARS", "COP", "CLP", "CHF")

@Composable
fun SettingsScreen(nav: NavController) {
    val vm: FinanceViewModel = hiltViewModel()
    val settings by vm.settings.collectAsStateWithLifecycle()
    val s = settings ?: return
    val ctx = LocalContext.current
    val h = rememberHaptics()
    var name by rememberSaveable { mutableStateOf<String?>(null) }
    var noLock by remember { mutableStateOf(false) }
    val shownName = name ?: s.name
    ScreenScaffold(stringResource(R.string.settings_title), onBack = { nav.popBackStack() }) { pad ->
        LazyColumn(contentPadding = listPadding(pad), verticalArrangement = Arrangement.spacedBy(18.dp)) {
            item {
                FormSection(stringResource(R.string.settings_profile)) {
                    OutlinedTextField(
                        value = shownName,
                        onValueChange = { v -> name = v; vm.updateSettings { it.copy(name = v.trim()) } },
                        label = { Text(stringResource(R.string.settings_your_name)) },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
                    )
                }
            }
            item {
                FormSection(stringResource(R.string.settings_security)) {
                    SwitchRow(stringResource(R.string.settings_lock), s.lock) { on ->
                        if (on && !canLock(ctx)) { noLock = true; h.warning() } else vm.updateSettings { it.copy(lock = on) }
                    }
                    RowDivider()
                    SwitchRow(stringResource(R.string.settings_hide_on_launch), s.hideAmountsOnLaunch) { on -> vm.updateSettings { it.copy(hideAmountsOnLaunch = on) } }
                }
            }
            item {
                FormSection(stringResource(R.string.settings_month)) {
                    Row(Modifier.fillMaxWidth().heightIn(min = 56.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text(stringResource(R.string.settings_month_start, s.monthStart), Modifier.weight(1f))
                        IconButton(onClick = { h.select(); vm.updateSettings { it.copy(monthStart = (it.monthStart - 1).coerceIn(1, 28)) } }, enabled = s.monthStart > 1) {
                            Icon(Icons.Filled.Remove, stringResource(R.string.settings_month_minus))
                        }
                        IconButton(onClick = { h.select(); vm.updateSettings { it.copy(monthStart = (it.monthStart + 1).coerceIn(1, 28)) } }, enabled = s.monthStart < 28) {
                            Icon(Icons.Filled.Add, stringResource(R.string.settings_month_plus))
                        }
                    }
                    RowDivider()
                    PickerRow(stringResource(R.string.settings_currency), CURRENCIES.map { it to currencyLabel(ctx, it) }, s.currency) { c -> vm.updateSettings { it.copy(currency = c) } }
                }
            }
            item {
                FormSection(stringResource(R.string.settings_look)) {
                    PickerRow(
                        stringResource(R.string.settings_theme),
                        listOf(
                            ThemeMode.SYSTEM to stringResource(R.string.settings_theme_system),
                            ThemeMode.LIGHT to stringResource(R.string.settings_theme_light),
                            ThemeMode.DARK to stringResource(R.string.settings_theme_dark),
                        ),
                        s.theme,
                    ) { t -> vm.updateSettings { it.copy(theme = t) } }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        RowDivider()
                        SwitchRow(stringResource(R.string.settings_dynamic), s.dynamicColor) { on -> vm.updateSettings { it.copy(dynamicColor = on) } }
                    }
                    if (!s.dynamicColor) {
                        RowDivider()
                        Text(stringResource(R.string.settings_accent), Modifier.padding(top = 12.dp, bottom = 10.dp), style = MaterialTheme.typography.bodyLarge)
                        Box(Modifier.padding(bottom = 12.dp)) { ColorRow(s.accent) { c -> vm.updateSettings { it.copy(accent = c) } } }
                    }
                }
            }
            item {
                FormSection(stringResource(R.string.settings_modules)) {
                    SwitchRow(stringResource(R.string.settings_module_work), s.moduleWork) { on -> vm.updateSettings { it.copy(moduleWork = on) } }
                    RowDivider()
                    SwitchRow(stringResource(R.string.settings_module_debts), s.moduleDebts) { on -> vm.updateSettings { it.copy(moduleDebts = on) } }
                    RowDivider()
                    SwitchRow(stringResource(R.string.settings_module_invest), s.moduleInvest) { on -> vm.updateSettings { it.copy(moduleInvest = on) } }
                }
            }
        }
    }
    if (noLock) {
        AlertDialog(
            onDismissRequest = { noLock = false },
            text = { Text(stringResource(R.string.settings_lock_unavailable)) },
            confirmButton = { TextButton(onClick = { noLock = false }) { Text(stringResource(R.string.ok)) } },
        )
    }
}

private fun canLock(ctx: Context): Boolean =
    BiometricManager.from(ctx).canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_WEAK or BiometricManager.Authenticators.DEVICE_CREDENTIAL) == BiometricManager.BIOMETRIC_SUCCESS

@SuppressLint("DiscouragedApi")
private fun currencyLabel(ctx: Context, code: String): String {
    val id = ctx.resources.getIdentifier("currency_$code", "string", ctx.packageName)
    return if (id != 0) ctx.getString(id) else code
}

/** nombre traducido de las categorías de partida (R.string.cat_<id>) */
@SuppressLint("DiscouragedApi")
internal fun defaultCategoryName(ctx: Context, id: String): String? {
    val res = ctx.resources.getIdentifier("cat_$id", "string", ctx.packageName)
    return if (res != 0) ctx.getString(res) else null
}

// MARK: Datos y copias

@Composable
fun DataScreen(nav: NavController) {
    val vm: FinanceViewModel = hiltViewModel()
    val ctx = LocalContext.current
    val h = rememberHaptics()
    val scope = rememberCoroutineScope()
    var pendingImport by remember { mutableStateOf<String?>(null) }
    var askErase by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }
    val failed = stringResource(R.string.import_failed)
    val exportedMsg = stringResource(R.string.data_exported)
    val erasedMsg = stringResource(R.string.data_erased)

    val export = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/json")) { uri ->
        if (uri != null) scope.launch {
            val ok = runCatching {
                val text = vm.repo.exportBackup()
                withContext(Dispatchers.IO) { ctx.contentResolver.openOutputStream(uri)?.use { it.write(text.toByteArray()) } }
            }.isSuccess
            if (ok) h.success() else h.warning()
            message = if (ok) exportedMsg else ctx.getString(R.string.error_generic)
        }
    }
    val import = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) scope.launch {
            val text = runCatching { withContext(Dispatchers.IO) { ctx.contentResolver.openInputStream(uri)?.use { it.readBytes().decodeToString() } } }.getOrNull()
            if (text.isNullOrBlank()) message = failed else pendingImport = text
        }
    }

    ScreenScaffold(stringResource(R.string.data_title), onBack = { nav.popBackStack() }) { pad ->
        LazyColumn(contentPadding = listPadding(pad), verticalArrangement = Arrangement.spacedBy(18.dp)) {
            item {
                FormSection(stringResource(R.string.data_backup)) {
                    NavRow(Icons.Filled.Upload, Color(0xFF6FD49B), stringResource(R.string.data_export)) {
                        export.launch(ctx.getString(R.string.data_file_name, Day.today))
                    }
                    RowDivider()
                    NavRow(Icons.Filled.Download, Color(0xFF8FB4FF), stringResource(R.string.data_import)) {
                        import.launch(arrayOf("application/json", "text/plain", "application/octet-stream"))
                    }
                }
            }
            item {
                FormSection {
                    NavRow(Icons.Filled.DeleteForever, MaterialTheme.colorScheme.error, stringResource(R.string.data_erase)) { h.warning(); askErase = true }
                }
            }
        }
    }

    pendingImport?.let { text ->
        ConfirmDialog(
            title = stringResource(R.string.data_import_confirm_title),
            message = stringResource(R.string.data_import_confirm_msg),
            confirm = stringResource(R.string.data_import_confirm),
            onConfirm = {
                scope.launch {
                    message = runCatching { vm.repo.importBackup(text) }.fold(
                        onSuccess = { b ->
                            h.success()
                            if (b.source == Backup.Source.WEB) ctx.getString(R.string.import_done_web, b.data.accounts.size, b.data.txs.size)
                            else ctx.getString(R.string.import_done, b.data.txs.size)
                        },
                        onFailure = { h.warning(); failed },
                    )
                }
            },
            onDismiss = { pendingImport = null },
        )
    }
    if (askErase) {
        ConfirmDialog(
            title = stringResource(R.string.data_erase_confirm_title),
            message = stringResource(R.string.data_erase_confirm_msg),
            confirm = stringResource(R.string.data_erase_confirm),
            onConfirm = {
                scope.launch {
                    vm.repo.eraseAll { id -> defaultCategoryName(ctx, id) }
                    h.heavy()
                    message = erasedMsg
                }
            },
            onDismiss = { askErase = false },
        )
    }
    message?.let { m ->
        AlertDialog(
            onDismissRequest = { message = null },
            text = { Text(m) },
            confirmButton = { TextButton(onClick = { message = null }) { Text(stringResource(R.string.ok), fontWeight = FontWeight.Bold) } },
        )
    }
}
