package es.david.caudal.ui.subs

import android.Manifest
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.EventRepeat
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Password
import androidx.compose.material.icons.filled.Savings
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.navigation.NavController
import dagger.hilt.android.lifecycle.HiltViewModel
import es.david.caudal.R
import es.david.caudal.data.security.PinStore
import es.david.caudal.notify.AlertPrefs
import es.david.caudal.notify.AlertsStore
import es.david.caudal.notify.Notifier
import es.david.caudal.ui.more.FormSection
import es.david.caudal.ui.more.NavRow
import es.david.caudal.ui.more.RowDivider
import es.david.caudal.ui.more.SwitchRow
import es.david.caudal.ui.nav.PinSetupRoute
import es.david.caudal.ui.nav.SubscriptionsRoute
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class SettingsExtrasViewModel @Inject constructor(
    pins: PinStore,
    private val alerts: AlertsStore,
    private val notifier: Notifier,
) : ViewModel() {
    val pinLength = pins.pinLength.stateIn(viewModelScope, SharingStarted.Eagerly, 0)
    val prefs = alerts.prefs.stateIn(viewModelScope, SharingStarted.Eagerly, AlertPrefs())
    fun setBudgets(on: Boolean) = viewModelScope.launch { alerts.setBudgets(on); if (on) notifier.checkBudgets() }
    fun setCharges(on: Boolean) = viewModelScope.launch { alerts.setCharges(on) }
    fun notificationsAllowed() = notifier.allowed()
}

/** fila del PIN para la sección de seguridad de Ajustes */
@Composable
fun PinRow(nav: NavController) {
    val vm: SettingsExtrasViewModel = hiltViewModel()
    val len by vm.pinLength.collectAsStateWithLifecycle()
    NavRow(Icons.Filled.Password, Color(0xFF9B7BFF), stringResource(R.string.f4_pin), if (len > 0) stringResource(R.string.f4_pin_on) else stringResource(R.string.f4_pin_off)) {
        nav.navigate(PinSetupRoute)
    }
}

/** sección «Avisos» de Ajustes: presupuestos, cargos y suscripciones (con el permiso de notificaciones) */
@Composable
fun AlertsSection(nav: NavController) {
    val vm: SettingsExtrasViewModel = hiltViewModel()
    val prefs by vm.prefs.collectAsStateWithLifecycle()
    var explain by remember { mutableStateOf<((Boolean) -> Unit)?>(null) }
    var denied by remember { mutableStateOf(false) }
    var pending by remember { mutableStateOf<((Boolean) -> Unit)?>(null) }
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { ok ->
        if (ok) pending?.invoke(true) else denied = true
        pending = null
    }
    fun withPermission(apply: (Boolean) -> Unit): (Boolean) -> Unit = { on ->
        if (on && !vm.notificationsAllowed() && Build.VERSION.SDK_INT >= 33) explain = apply else apply(on)
    }
    FormSection(stringResource(R.string.f4_alerts)) {
        SwitchRow(stringResource(R.string.f4_alert_budgets), prefs.budgets, icon = Icons.Filled.Notifications, iconColor = Color(0xFFFF9F43), onChange = withPermission { vm.setBudgets(it) })
        RowDivider()
        SwitchRow(stringResource(R.string.f4_alert_charges), prefs.charges, icon = Icons.Filled.EventRepeat, iconColor = Color(0xFF3FBFD0), onChange = withPermission { vm.setCharges(it) })
        RowDivider()
        NavRow(Icons.Filled.Savings, Color(0xFFB57BFF), stringResource(R.string.f4_subs_title)) { nav.navigate(SubscriptionsRoute) }
    }
    explain?.let { apply ->
        AlertDialog(
            onDismissRequest = { explain = null },
            title = { Text(stringResource(R.string.f4_permission_title)) },
            text = { Text(stringResource(R.string.f4_permission_text)) },
            confirmButton = {
                TextButton(onClick = {
                    explain = null
                    pending = apply
                    if (Build.VERSION.SDK_INT >= 33) launcher.launch(Manifest.permission.POST_NOTIFICATIONS)
                }) { Text(stringResource(R.string.f4_permission_ok), fontWeight = FontWeight.Bold) }
            },
            dismissButton = { TextButton(onClick = { explain = null }) { Text(stringResource(R.string.cancel)) } },
        )
    }
    if (denied) {
        AlertDialog(
            onDismissRequest = { denied = false },
            text = { Text(stringResource(R.string.f4_permission_denied)) },
            confirmButton = { TextButton(onClick = { denied = false }) { Text(stringResource(R.string.ok)) } },
        )
    }
}

/** ¿hay PIN? (para permitir activar el bloqueo aunque el móvil no tenga huella ni código) */
@Composable
fun hasPin(): Boolean {
    val vm: SettingsExtrasViewModel = hiltViewModel()
    val len by vm.pinLength.collectAsStateWithLifecycle()
    return len > 0
}
