package es.david.caudal.core

import java.time.Clock
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.YearMonth
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit

/**
 * Fechas como en Caudal para iPhone: se guardan como texto `yyyy-MM-dd` (y las horas `HH:mm`),
 * siempre en hora local. Así se comparan como texto y la copia de seguridad es la misma.
 */
object Day {
    /** reloj inyectable para los tests */
    var clock: Clock = Clock.systemDefaultZone()

    private val iso = DateTimeFormatter.ISO_LOCAL_DATE
    private val hm = DateTimeFormatter.ofPattern("HH:mm")

    val today: String get() = LocalDate.now(clock).format(iso)
    fun now(): LocalDateTime = LocalDateTime.now(clock)
    fun nowTime(): String = LocalTime.now(clock).format(hm)

    fun str(d: LocalDate): String = d.format(iso)
    fun date(s: String): LocalDate = runCatching { LocalDate.parse(s, iso) }.getOrElse { LocalDate.now(clock) }
    fun time(t: LocalTime): String = t.format(hm)
    fun parseTime(s: String): LocalTime = runCatching { LocalTime.parse(s, hm) }.getOrElse { LocalTime.NOON }

    fun addDays(s: String, days: Int): String = str(date(s).plusDays(days.toLong()))
    fun addMonths(s: String, months: Int): String = str(date(s).plusMonths(months.toLong()))

    /** primer día del mes de la fecha (yyyy-MM-01) */
    fun monthStart(s: String): String = s.take(7) + "-01"
    /** yyyy-MM */
    fun monthKey(s: String): String = s.take(7)
    fun daysInMonth(s: String): Int = YearMonth.from(date(s)).lengthOfMonth()
    fun daysBetween(a: String, b: String): Long = ChronoUnit.DAYS.between(date(a), date(b))
}
