package es.david.findemes.support

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import es.david.findemes.MainActivity
import es.david.findemes.R
import es.david.findemes.logic.Game
import java.util.Calendar
import kotlin.math.max

/**
 * Avisos al teléfono, como mucho dos y siempre con algo que cobrar:
 * cuando el abuelo ha llenado lo que se gana sin jugar (4 horas) y el premio diario.
 * Los textos se escriben al salir del juego (con el idioma de ese momento) y van dentro de la alarma.
 */
object Reminders {
    private const val CHANNEL = "avisos"
    private const val AWAY = 1
    private const val DAILY = 2

    /** pide el permiso del sistema (lo pone MainActivity) */
    var ask: (() -> Unit)? = null

    fun allowed(c: Context): Boolean =
        Build.VERSION.SDK_INT < 33 || ContextCompat.checkSelfPermission(c, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    /** al salir del juego */
    fun schedule(c: Context, game: Game) {
        cancel(c)
        val s = game.s
        if (!s.settings.reminders || s.tutorial < 9 || !allowed(c)) return
        val now = System.currentTimeMillis()
        val daily = nextDaily(now)
        val (dt, db) = dailyText(game)
        set(c, DAILY, daily, dt, db)
        if (s.lastDayEarned > 0) {
            val full = awake(now + 4 * 3_600_000L)
            // si caen casi a la vez, basta con uno
            if (kotlin.math.abs(full - daily) > 2 * 3_600_000L)
                awayText(game).let { (t, b) -> set(c, AWAY, full, t, b) }
        }
    }

    private fun dailyText(game: Game) = "Premio diario listo".a to
        (if ("bar" in game.s.seenDoors) "Y tienes 3 tiradas gratis en la feria." else "Pasa a recogerlo y no pierdas la racha.").a

    private fun awayText(game: Game) = "El abuelo no ha parado".a to
        tf("Ha juntado %1 rompiendo {huchas}. Ven a cobrarlo antes de que se lo gaste.", Fmt.money(game.s.lastDayEarned * 1.2 * 4)).a

    /** para las capturas: los dos avisos ya mismo */
    fun demo(c: Context, game: Game) {
        val daily = dailyText(game); val away = awayText(game)
        // después de abrir, que al abrir se borran
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            post(c, DAILY, daily.first, daily.second); post(c, AWAY, away.first, away.second)
        }, 3_000)
    }

    /** al volver al juego: fuera alarmas y avisos que sigan en la barra */
    fun cancel(c: Context) {
        val am = c.getSystemService(AlarmManager::class.java)
        for (id in listOf(AWAY, DAILY)) am.cancel(pending(c, id, null, null))
        NotificationManagerCompat.from(c).cancelAll()
    }

    /** mañana, a la hora a la que se suele jugar (entre las 10 y las 21) */
    private fun nextDaily(now: Long): Long = Calendar.getInstance().run {
        timeInMillis = now
        val hour = get(Calendar.HOUR_OF_DAY).coerceIn(10, 21)
        add(Calendar.DAY_OF_YEAR, 1)
        set(Calendar.HOUR_OF_DAY, hour); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0)
        timeInMillis
    }

    /** de noche no se avisa: pasa a las 9 de la mañana */
    private fun awake(t: Long): Long = Calendar.getInstance().run {
        timeInMillis = t
        val h = get(Calendar.HOUR_OF_DAY)
        if (h >= 23 || h < 9) {
            if (h >= 23) add(Calendar.DAY_OF_YEAR, 1)
            set(Calendar.HOUR_OF_DAY, 9); set(Calendar.MINUTE, 0)
        }
        max(t, timeInMillis)
    }

    private fun set(c: Context, id: Int, at: Long, title: String, body: String) {
        // sin hora exacta: Android lo agrupa con otras alarmas y no gasta batería
        c.getSystemService(AlarmManager::class.java).set(AlarmManager.RTC, at, pending(c, id, title, body))
    }

    private fun pending(c: Context, id: Int, title: String?, body: String?): PendingIntent {
        val i = Intent(c, ReminderReceiver::class.java).putExtra("id", id).putExtra("title", title).putExtra("body", body)
        return PendingIntent.getBroadcast(c, id, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    fun post(c: Context, id: Int, title: String, body: String) {
        if (!allowed(c)) return
        val nm = c.getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(NotificationChannel(CHANNEL, "Avisos".a, NotificationManager.IMPORTANCE_DEFAULT))
        val open = PendingIntent.getActivity(c, 0, Intent(c, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val n = NotificationCompat.Builder(c, CHANNEL)
            .setSmallIcon(R.drawable.ic_aviso)
            .setColor(0xFFD2462E.toInt())
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        try { NotificationManagerCompat.from(c).notify(id, n) } catch (_: SecurityException) {}
    }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(c: Context, i: Intent) {
        val title = i.getStringExtra("title") ?: return
        Reminders.post(c, i.getIntExtra("id", 0), title, i.getStringExtra("body") ?: "")
    }
}
