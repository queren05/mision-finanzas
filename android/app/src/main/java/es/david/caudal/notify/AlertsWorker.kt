package es.david.caudal.notify

import android.content.Context
import androidx.hilt.work.HiltWorker
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import java.time.Duration
import java.time.LocalDateTime
import java.util.concurrent.TimeUnit

/** cada día por la mañana: cargos de mañana y presupuestos */
@HiltWorker
class AlertsWorker @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted params: WorkerParameters,
    private val notifier: Notifier,
) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result = runCatching {
        notifier.checkCharges()
        notifier.checkBudgets()
    }.fold({ Result.success() }, { Result.retry() })

    companion object {
        fun schedule(context: Context) {
            // la primera vuelta hacia las 10:00 y después cada día
            val now = LocalDateTime.now()
            var first = now.withHour(10).withMinute(0).withSecond(0)
            if (!first.isAfter(now)) first = first.plusDays(1)
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                "avisos", ExistingPeriodicWorkPolicy.KEEP,
                PeriodicWorkRequestBuilder<AlertsWorker>(1, TimeUnit.DAYS)
                    .setInitialDelay(Duration.between(now, first).toMinutes(), TimeUnit.MINUTES).build(),
            )
        }
    }
}
