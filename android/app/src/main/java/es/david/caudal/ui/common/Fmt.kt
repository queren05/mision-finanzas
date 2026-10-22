package es.david.caudal.ui.common

import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.platform.LocalContext
import es.david.caudal.R
import es.david.caudal.core.Day
import java.text.NumberFormat
import java.time.format.DateTimeFormatter
import java.time.format.TextStyle
import java.util.Currency
import java.util.Locale

/**
 * Cómo se enseñan importes y fechas: la moneda elegida en Ajustes y el idioma de la app
 * (`locale_tag` en strings.xml, para que fechas y textos vayan en el mismo idioma).
 */
@Immutable
class Fmt(
    val locale: Locale,
    val currency: String,
    /** importes ocultos con el ojo («•••• €») */
    val hidden: Boolean,
    private val todayLabel: String,
    private val yesterdayLabel: String,
) {
    private val money = NumberFormat.getCurrencyInstance(locale).apply {
        runCatching { currency = Currency.getInstance(this@Fmt.currency) }
        minimumFractionDigits = 2
        maximumFractionDigits = 2
    }
    private val num2 = NumberFormat.getNumberInstance(locale).apply { minimumFractionDigits = 2; maximumFractionDigits = 2 }
    private val numFree = NumberFormat.getNumberInstance(locale).apply { maximumFractionDigits = 6 }
    val symbol: String = runCatching { Currency.getInstance(currency).getSymbol(locale) }.getOrDefault(currency)

    private val long = DateTimeFormatter.ofPattern("d 'de' MMMM", locale)
    private val longYear = DateTimeFormatter.ofPattern("d 'de' MMMM 'de' yyyy", locale)
    private val short = DateTimeFormatter.ofPattern("d MMM", locale)
    private val dayLong = DateTimeFormatter.ofPattern("EEEE d 'de' MMMM", locale)

    /** «1.234,56 €» (o «•••• €» si están ocultos) */
    fun money(v: Double): String = if (hidden) "•••• $symbol" else money.format(v + 0.0)
    fun money(cents: Long): String = money(cents / 100.0)
    /** «+12,00 €» */
    fun signed(v: Double): String = if (hidden) "•••• $symbol" else (if (v > 0.0049) "+" else "") + money.format(v + 0.0)
    /** sin ocultar (para escribir mensajes, por ejemplo) */
    fun plain(v: Double): String = money.format(v + 0.0)
    fun num(v: Double): String = num2.format(v + 0.0)
    fun numFree(v: Double): String = numFree.format(v + 0.0)
    fun pct(v: Double): String = (if (v >= 0) "+" else "") + num2.format(v) + " %"

    /** «Hoy», «Ayer» o «12 de octubre» (con el año si no es este) */
    fun header(s: String): String {
        if (s == Day.today) return todayLabel
        if (s == Day.addDays(Day.today, -1)) return yesterdayLabel
        val d = Day.date(s)
        return if (d.year != Day.date(Day.today).year) d.format(longYear) else d.format(long)
    }
    fun shortLabel(s: String): String = Day.date(s).format(short)
    fun dayLong(s: String): String = Day.date(s).format(dayLong).replaceFirstChar { it.titlecase(locale) }
    /** «Octubre» */
    fun month(s: String): String = Day.date(s).month.getDisplayName(TextStyle.FULL_STANDALONE, locale).replaceFirstChar { it.titlecase(locale) }
    /** «Octubre 2026» */
    fun monthYear(s: String): String = month(s) + " " + Day.date(s).year
    /** «7 h 30 min» */
    fun duration(m: Int): String {
        val h = m / 60
        val r = m % 60
        return if (r == 0) "$h h" else if (h == 0) "$r min" else "$h h $r min"
    }
    /** horas en decimal: «7,5» */
    fun hoursDec(m: Int): String = num(m / 60.0).let { if (it.endsWith(",00") || it.endsWith(".00")) it.dropLast(3) else it }
}

val LocalFmt = staticCompositionLocalOf<Fmt> { error("Fmt sin preparar") }

@Composable
fun rememberFmt(currency: String, hidden: Boolean): Fmt {
    val ctx = LocalContext.current
    val tag = ctx.getString(R.string.locale_tag)
    return Fmt(Locale.forLanguageTag(tag), currency, hidden, ctx.getString(R.string.today), ctx.getString(R.string.yesterday))
}
