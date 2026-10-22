package es.david.caudal.work

import android.content.Context
import androidx.hilt.work.HiltWorker
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import es.david.caudal.data.repo.FinanceRepository
import java.util.concurrent.TimeUnit

/** una vez al día: apunta los recurrentes aunque no se abra la app (en iPhone solo se hacía al abrir) */
@HiltWorker
class RecurringWorker @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted params: WorkerParameters,
    private val repo: FinanceRepository,
) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result = runCatching { repo.runRecurring() }.fold({ Result.success() }, { Result.retry() })

    companion object {
        fun schedule(context: Context) {
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                "recurrentes", ExistingPeriodicWorkPolicy.KEEP,
                PeriodicWorkRequestBuilder<RecurringWorker>(1, TimeUnit.DAYS).build(),
            )
        }
    }
}
