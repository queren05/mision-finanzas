package es.david.caudal

import android.app.Application
import androidx.hilt.work.HiltWorkerFactory
import androidx.work.Configuration
import dagger.hilt.android.HiltAndroidApp
import es.david.caudal.data.repo.FinanceRepository
import es.david.caudal.widget.updateAllWidgets
import es.david.caudal.work.RecurringWorker
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.launch
import javax.inject.Inject

@OptIn(FlowPreview::class)
@HiltAndroidApp
class CaudalApp : Application(), Configuration.Provider {
    @Inject lateinit var workerFactory: HiltWorkerFactory
    @Inject lateinit var repo: FinanceRepository
    @Inject lateinit var settings: es.david.caudal.data.repo.SettingsRepository
    @Inject lateinit var notifier: es.david.caudal.notify.Notifier

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    override val workManagerConfiguration: Configuration
        get() = Configuration.Builder().setWorkerFactory(workerFactory).build()

    override fun onCreate() {
        super.onCreate()
        RecurringWorker.schedule(this)
        // los widgets se refrescan un momento después de cada cambio
        scope.launch { repo.changes.debounce(800).collect { updateAllWidgets(this@CaudalApp) } }
        // avisos: presupuestos al cambiar los datos y cada mañana; cargos de mañana
        notifier.ensureChannels()
        es.david.caudal.notify.AlertsWorker.schedule(this)
        scope.launch { repo.changes.debounce(1500).collect { runCatching { notifier.checkBudgets() } } }
        // el icono elegido (por ejemplo, al restaurar una copia): se aplica si no es el que está activo
        scope.launch {
            val id = settings.current().appIcon
            val icon = es.david.caudal.ui.more.APP_ICONS.firstOrNull { it.id == id } ?: return@launch
            val state = packageManager.getComponentEnabledSetting(android.content.ComponentName(packageName, "es.david.caudal" + icon.alias))
            val enabled = state == android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_ENABLED ||
                (state == android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_DEFAULT && id == "default")
            if (!enabled) es.david.caudal.ui.more.applyAppIcon(this@CaudalApp, id)
        }
    }
}
