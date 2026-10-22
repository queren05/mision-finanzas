package es.david.caudal

import android.content.Intent
import android.os.Bundle
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import dagger.hilt.android.AndroidEntryPoint
import es.david.caudal.ui.AppViewModel
import es.david.caudal.ui.RootScreen

/** FragmentActivity porque el desbloqueo con huella (BiometricPrompt) lo necesita */
@AndroidEntryPoint
class MainActivity : FragmentActivity() {
    private val app: AppViewModel by viewModels()
    /** acción con la que se abrió (acceso directo «Apuntar gasto», mosaico…) */
    private var action by mutableStateOf<String?>(null)
    /** copia de seguridad abierta con Caudal */
    private var backupUri by mutableStateOf<android.net.Uri?>(null)

    private val processObserver = object : DefaultLifecycleObserver {
        override fun onStart(owner: LifecycleOwner) { app.onForeground() }
        override fun onStop(owner: LifecycleOwner) { app.onBackground() }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        val splash = installSplashScreen()
        super.onCreate(savedInstanceState)
        splash.setKeepOnScreenCondition { app.settings.value == null }
        enableEdgeToEdge()
        ProcessLifecycleOwner.get().lifecycle.addObserver(processObserver)
        handle(intent)
        setContent { RootScreen(app, action, backupUri, onBackupHandled = { backupUri = null }) { action = null } }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handle(intent)
    }

    private fun handle(intent: Intent?) {
        action = intent?.action
        backupUri = when (intent?.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> androidx.core.content.IntentCompat.getParcelableExtra(intent, Intent.EXTRA_STREAM, android.net.Uri::class.java)
            else -> null
        }
    }

    override fun onDestroy() {
        ProcessLifecycleOwner.get().lifecycle.removeObserver(processObserver)
        super.onDestroy()
    }
}
