package es.david.findemes.support

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import es.david.findemes.R
import java.util.Locale
import kotlin.math.abs
import kotlin.math.floor
import kotlin.math.log10
import kotlin.math.pow

// MARK: - Colores: papel, tinta y madera

object Ink {
    val paper = hex("#f6eedb")
    val paperDark = hex("#e7d8b4")
    val ink = hex("#2a2018")
    val soft = hex("#6b5a48")
    val wood = hex("#9a6438")
    val woodDark = hex("#6e4126")
    val woodLight = hex("#b47a48")
    val red = hex("#d2462e")
    val green = hex("#3d8b4f")
    val money = hex("#5ba566")
    val pink = hex("#f5a7b8")
    val pinkDark = hex("#de7f98")
    val gold = hex("#f2b632")
    val blue = hex("#3f74b0")
    val purple = hex("#8a5cc2")
    val kitchen = hex("#e9c97a")
    val tile = hex("#f1dfa9")
}

fun hex(h: String): Color {
    var s = h.trim().removePrefix("#")
    if (s.length == 3) s = s.map { "$it$it" }.joinToString("")
    val v = s.toLong(16)
    return Color(((v shr 16) and 0xff).toInt(), ((v shr 8) and 0xff).toInt(), (v and 0xff).toInt())
}

// MARK: - Letras: Lilita One para títulos y cifras, Courier Prime para las facturas

object Fonts {
    val chunky = FontFamily(Font(R.font.lilita_one))
    val typewriter = FontFamily(Font(R.font.courier_prime, FontWeight.Normal), Font(R.font.courier_prime_bold, FontWeight.Bold))
}

// MARK: - Números

object Fmt {
    private val suffixes = listOf("", " mil", " M", " mil M", " B", " mil B", " T", " mil T", " Cu", " mil Cu", " Qi")

    /** dinero: 1.234 € · 12,5 mil € · 3,2 M € */
    fun money(v: Double): String = num(v) + " €"

    fun num(v: Double): String {
        if (!v.isFinite()) return "∞"
        val a = abs(v)
        if (a < 10_000) {
            if (a < 100 && floor(a) != a) return dec(v, 1)
            // como en iOS (es_ES): los números de cuatro cifras van sin punto
            return floor(v).toLong().toString()
        }
        val e3 = floor(log10(a) / 3).toInt()
        if (e3 >= suffixes.size) {
            val e = floor(log10(a)).toInt()
            return dec(v / 10.0.pow(e), 2) + "e" + e
        }
        val m = v / 10.0.pow(e3 * 3)
        return dec(m, if (m < 10) 2 else if (m < 100) 1 else 0) + suffixes[e3]
    }

    fun num(v: Int): String = num(v.toDouble())

    fun dec(v: Double, d: Int): String = String.format(Locale.US, "%.${d}f", v).replace(".", ",")
}

/** redondeo como en Swift (`.rounded()`: los medios se alejan del cero); kotlin.math.round redondea al par */
fun rnd(x: Double): Double = if (!x.isFinite()) x else if (x >= 0) kotlin.math.floor(x + 0.5) else kotlin.math.ceil(x - 0.5)
