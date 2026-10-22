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

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    override val workManagerConfiguration: Configuration
        get() = Configuration.Builder().setWorkerFactory(workerFactory).build()

    override fun onCreate() {
        super.onCreate()
        RecurringWorker.schedule(this)
        // los widgets se refrescan un momento después de cada cambio
        scope.launch { repo.changes.debounce(800).collect { updateAllWidgets(this@CaudalApp) } }
    }
}
