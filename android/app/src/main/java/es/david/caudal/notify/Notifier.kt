package es.david.caudal.notify

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import dagger.hilt.android.qualifiers.ApplicationContext
import es.david.caudal.MainActivity
import es.david.caudal.R
import es.david.caudal.core.Day
import es.david.caudal.core.Money
import es.david.caudal.data.repo.FinanceRepository
import es.david.caudal.data.repo.SettingsRepository
import es.david.caudal.domain.calc.BudgetAlerts
import es.david.caudal.domain.calc.Ledger
import java.text.NumberFormat
import java.util.Currency
import java.util.Locale
import javax.inject.Inject
import javax.inject.Singleton

/** avisos de Caudal: presupuestos (80 % y 100 %) y cargos de mañana */
@Singleton
class Notifier @Inject constructor(
    @ApplicationContext private val context: Context,
    private val repo: FinanceRepository,
    private val settings: SettingsRepository,
    private val alerts: AlertsStore,
) {
    companion object {
        const val CH_BUDGETS = "presupuestos"
        const val CH_CHARGES = "cargos"
    }

    fun ensureChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(NotificationChannel(CH_BUDGETS, context.getString(R.string.f4_channel_budgets), NotificationManager.IMPORTANCE_DEFAULT))
        nm.createNotificationChannel(NotificationChannel(CH_CHARGES, context.getString(R.string.f4_channel_charges), NotificationManager.IMPORTANCE_DEFAULT))
    }

    fun allowed(): Boolean = Build.VERSION.SDK_INT < 33 ||
        ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    private fun money(currency: String): (Double) -> String {
        val nf = NumberFormat.getCurrencyInstance(Locale.forLanguageTag(context.getString(R.string.locale_tag)))
        runCatching { nf.currency = Currency.getInstance(currency) }
        return { nf.format(it) }
    }

    private fun open(): PendingIntent = PendingIntent.getActivity(
        context, 0, Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    @Suppress("MissingPermission")
    private fun post(id: Int, channel: String, title: String, text: String) {
        if (!allowed()) return
        ensureChannels()
        val n = NotificationCompat.Builder(context, channel)
            .setSmallIcon(R.drawable.ic_notification)
            .setColor(0xFFE4B3CB.toInt())
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setContentIntent(open())
            .setAutoCancel(true)
            .build()
        NotificationManagerCompat.from(context).notify(id, n)
    }

    /** avisos de presupuesto nuevos (cada uno una sola vez por mes) */
    suspend fun checkBudgets(today: String = Day.today) {
        if (!alerts.current().budgets) return
        val s = settings.current()
        val l = Ledger(repo.snapshot(), s.monthStart)
        val found = BudgetAlerts.check(l, today)
        if (found.isEmpty()) return
        val fresh = alerts.markNew(found.map { it.key }, Day.addMonths(l.periodStart(today), -2)).toSet()
        val fmt = money(s.currency)
        found.filter { it.key in fresh }.forEach { a ->
            val name = a.category?.let { "${it.icon} ${it.name}" } ?: context.getString(R.string.f4_budget_total)
            val title = context.getString(if (a.level >= 100) R.string.f4_budget_over_title else R.string.f4_budget_80_title, name)
            val text = context.getString(R.string.f4_budget_text, fmt(a.spent), fmt(a.budget))
            post(a.key.hashCode(), CH_BUDGETS, title, text)
        }
    }

    /** los cargos recurrentes de mañana */
    suspend fun checkCharges(today: String = Day.today) {
        if (!alerts.current().charges) return
        val s = settings.current()
        val list = BudgetAlerts.chargesTomorrow(Ledger(repo.snapshot(), s.monthStart), today)
        if (list.isEmpty()) return
        val fresh = alerts.markNew(list.map { "${it.date}:charge:${it.r.id}" }, Day.addMonths(today, -2)).toSet()
        val fmt = money(s.currency)
        list.filter { "${it.date}:charge:${it.r.id}" in fresh }.forEach { u ->
            post(("charge" + u.r.id + u.date).hashCode(), CH_CHARGES, context.getString(R.string.f4_charge_title, u.r.name),
                context.getString(R.string.f4_charge_text, fmt(Money.fromCents(u.r.amount))))
        }
    }
}
