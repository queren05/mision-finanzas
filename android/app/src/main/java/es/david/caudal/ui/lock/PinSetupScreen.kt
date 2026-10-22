package es.david.caudal.ui.lock

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.navigation.NavController
import dagger.hilt.android.lifecycle.HiltViewModel
import es.david.caudal.R
import es.david.caudal.data.repo.SettingsRepository
import es.david.caudal.data.security.Pin
import es.david.caudal.data.security.PinStore
import es.david.caudal.ui.common.ConfirmDialog
import es.david.caudal.ui.common.Gotita
import es.david.caudal.ui.common.Mood
import es.david.caudal.ui.common.Pill
import es.david.caudal.ui.common.ScreenScaffold
import es.david.caudal.ui.common.rememberHaptics
import es.david.caudal.ui.theme.CaudalTheme
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class PinSetupViewModel @Inject constructor(val pins: PinStore, private val settings: SettingsRepository) : ViewModel() {
    val pinLength = pins.pinLength.stateIn(viewModelScope, SharingStarted.Eagerly, -1)

    /** guarda el PIN y activa el bloqueo */
    suspend fun save(pin: String) { pins.setPin(pin); settings.update { it.copy(lock = true) } }

    suspend fun remove() { pins.clear() }
}

/**
 * Crear, cambiar o quitar el PIN. Si ya hay uno, primero se pide el actual.
 * Pasos: actual (si hay) → nuevo → repetir.
 */
@Composable
fun PinSetupScreen(nav: NavController) {
    val vm: PinSetupViewModel = hiltViewModel()
    val current by vm.pinLength.collectAsStateWithLifecycle()
    if (current < 0) return
    val ctx = LocalContext.current
    val h = rememberHaptics()
    val c = CaudalTheme.colors
    val scope = rememberCoroutineScope()
    var verified by remember { mutableStateOf(current == 0) }
    var length by remember { mutableIntStateOf(if (current > 0) current else 4) }
    var first by remember { mutableStateOf<String?>(null) }
    var typed by remember { mutableStateOf("") }
    var shake by remember { mutableIntStateOf(0) }
    var error by remember { mutableStateOf<String?>(null) }
    var askRemove by remember { mutableStateOf(false) }

    val need = if (!verified) current else length
    val title = stringResource(
        when {
            !verified -> R.string.f4_pin_current
            first == null -> R.string.f4_pin_create
            else -> R.string.f4_pin_repeat
        },
    )
    fun reset(msg: String?) { typed = ""; error = msg; if (msg != null) { shake++; h.warning() } }
    fun complete(pin: String) {
        scope.launch {
            when {
                !verified -> when (val r = vm.pins.verify(pin)) {
                    is PinStore.Result.Ok -> { verified = true; reset(null) }
                    is PinStore.Result.Wrong -> reset(ctx.getString(R.string.f4_pin_wrong, r.left))
                    is PinStore.Result.Wait -> reset(ctx.getString(R.string.f4_pin_wait, ((r.millis + 999) / 1000).toInt()))
                }
                first == null -> { first = pin; reset(null) }
                pin == first -> { vm.save(pin); h.success(); nav.popBackStack() }
                else -> { first = null; reset(ctx.getString(R.string.f4_pin_mismatch)) }
            }
        }
    }
    ScreenScaffold(stringResource(R.string.f4_pin), onBack = { nav.popBackStack() }, large = false) { pad ->
        Column(
            Modifier.fillMaxSize().padding(pad).padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp, Alignment.CenterVertically),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Gotita(if (error != null) Mood.WOW else Mood.WINK, 90.dp)
            Text(title, style = MaterialTheme.typography.headlineSmall, textAlign = TextAlign.Center)
            if (verified && first == null) {
                // 4, 5 o 6 cifras
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    listOf(4, 5, 6).forEach { n -> Pill(stringResource(R.string.f4_pin_length, n), n == length, { length = n; typed = "" }) }
                }
            }
            PinDots(typed.length, need, shake)
            Text(error ?: " ", style = MaterialTheme.typography.bodyMedium, color = c.negative, textAlign = TextAlign.Center)
            PinPad(
                onDigit = { d -> if (typed.length < need) { typed += d; error = null; if (typed.length == need && Pin.valid(typed)) complete(typed) } },
                onDelete = { typed = typed.dropLast(1) },
            )
            if (current > 0 && verified) {
                Pill(stringResource(R.string.f4_pin_remove), false, { h.warning(); askRemove = true })
            }
        }
    }
    if (askRemove) {
        ConfirmDialog(
            title = stringResource(R.string.f4_pin_remove_confirm),
            message = stringResource(R.string.f4_pin_remove_msg),
            confirm = stringResource(R.string.f4_pin_remove),
            onConfirm = { scope.launch { vm.remove(); h.heavy(); nav.popBackStack() } },
            onDismiss = { askRemove = false },
        )
    }
}
