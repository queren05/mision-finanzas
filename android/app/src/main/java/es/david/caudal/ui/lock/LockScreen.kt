package es.david.caudal.ui.lock

import android.content.Context
import android.content.ContextWrapper
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_WEAK
import androidx.biometric.BiometricManager.Authenticators.DEVICE_CREDENTIAL
import androidx.biometric.BiometricPrompt
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Fingerprint
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import es.david.caudal.R
import es.david.caudal.ui.common.GlowBackground
import es.david.caudal.ui.common.Gotita
import es.david.caudal.ui.common.Mood
import es.david.caudal.ui.common.contentOn
import es.david.caudal.ui.common.pressable
import es.david.caudal.ui.theme.CaudalTheme

/** Caudal bloqueada: Gotita dormida y huella, cara o el código del móvil (BiometricPrompt) */
@Composable
fun LockScreen(onUnlocked: () -> Unit) {
    val ctx = LocalContext.current
    val c = CaudalTheme.colors
    val title = stringResource(R.string.unlock_reason)
    val ask = { prompt(ctx, title, onUnlocked) }
    LaunchedEffect(Unit) { ask() }
    Box(Modifier.fillMaxSize()) {
        GlowBackground(c.accent, Modifier.fillMaxWidth().height(420.dp))
        Column(
            Modifier.fillMaxSize().padding(32.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp, Alignment.CenterVertically),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Gotita(Mood.SLEEPY, 140.dp, description = stringResource(R.string.gotita))
            Text(stringResource(R.string.lock_title), style = MaterialTheme.typography.headlineSmall, textAlign = TextAlign.Center)
            Spacer(Modifier.height(4.dp))
            Row(
                Modifier.heightIn(min = 56.dp).clip(CircleShape).pressable(0.94f, onClick = ask).background(c.accent).padding(horizontal = 28.dp, vertical = 14.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Filled.Fingerprint, null, tint = contentOn(c.accent), modifier = Modifier.size(24.dp))
                Spacer(Modifier.width(10.dp))
                Text(stringResource(R.string.unlock), style = MaterialTheme.typography.titleMedium, color = contentOn(c.accent))
            }
        }
    }
}

private fun prompt(ctx: Context, title: String, onUnlocked: () -> Unit) {
    val activity = ctx.findActivity() ?: return
    // si el móvil no tiene huella ni código, no hay con qué bloquear: se abre directamente
    if (BiometricManager.from(activity).canAuthenticate(BIOMETRIC_WEAK or DEVICE_CREDENTIAL) != BiometricManager.BIOMETRIC_SUCCESS) { onUnlocked(); return }
    val prompt = BiometricPrompt(
        activity, ContextCompat.getMainExecutor(activity),
        object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) = onUnlocked()

            override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                if (errorCode in setOf(BiometricPrompt.ERROR_NO_DEVICE_CREDENTIAL, BiometricPrompt.ERROR_NO_BIOMETRICS, BiometricPrompt.ERROR_HW_NOT_PRESENT, BiometricPrompt.ERROR_HW_UNAVAILABLE)) onUnlocked()
            }
        },
    )
    val info = BiometricPrompt.PromptInfo.Builder()
        .setTitle(title)
        .setAllowedAuthenticators(BIOMETRIC_WEAK or DEVICE_CREDENTIAL)
        .build()
    runCatching { prompt.authenticate(info) }.onFailure { onUnlocked() }
}

private tailrec fun Context.findActivity(): FragmentActivity? = when (this) {
    is FragmentActivity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}
