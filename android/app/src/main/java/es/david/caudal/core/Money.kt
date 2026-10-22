package es.david.caudal.core

import kotlin.math.abs
import kotlin.math.roundToLong

/**
 * Los importes se guardan en céntimos (Long) junto a su moneda: sin errores de redondeo y
 * listos para multimoneda. En la copia de seguridad van como número decimal, igual que en iPhone.
 */
object Money {
    fun toCents(v: Double): Long = (v * 100).roundToLong()
    fun fromCents(c: Long): Double = c / 100.0

    /** redondeo a céntimos como en iPhone: (x * 100).rounded() / 100 */
    fun round2(v: Double): Double = (v * 100).roundToLong() / 100.0

    /**
     * «12,50 €», «€12.50», «1.234,56», «1,234.56» → número.
     * El último separador seguido de 2 cifras o menos es el decimal (igual que AutoInbox.parse en iPhone).
     */
    fun parseLoose(s: String): Double? {
        var t = s.filter { it.isDigit() || it == ',' || it == '.' }
        if (t.isEmpty()) return null
        val last = t.indexOfLast { it == ',' || it == '.' }
        if (last >= 0) {
            val decimals = t.substring(last + 1)
            t = if (decimals.length <= 2) t.substring(0, last).filter { it.isDigit() } + "." + decimals
            else t.filter { it.isDigit() }
        }
        return t.toDoubleOrNull()
    }

    /** «12,5» o «12.5» → 12.5 (lo que se teclea en los campos de importe) */
    fun parse(s: String): Double? {
        val t = s.replace("€", "").replace(" ", "").replace(" ", "")
            .replace(".", "").replace(",", ".")
        return t.toDoubleOrNull()
    }

    /**
     * Limpia lo que se teclea en el importe: solo números y una coma, 2 decimales como mucho
     * y 9 cifras enteras como mucho (igual que el editor de iPhone).
     */
    fun cleanInput(v: String): String {
        val out = StringBuilder()
        var comma = false
        var dec = 0
        for (ch in v.replace('.', ',')) {
            if (ch == ',') {
                if (!comma) { comma = true; if (out.isEmpty()) out.append("0"); out.append(',') }
                continue
            }
            if (!ch.isDigit()) continue
            if (comma) { if (dec >= 2) continue; dec++ }
            if (!comma && out.toString() == "0") out.setLength(0)
            if (!comma && out.length >= 9) continue
            out.append(ch)
        }
        return out.toString()
    }

    /** texto para volver a editar un importe: 12.5 → «12,5», 12.0 → «12» */
    fun editText(cents: Long): String {
        val a = abs(cents)
        val ent = a / 100
        val dec = a % 100
        return when {
            dec == 0L -> "$ent"
            dec % 10 == 0L -> "$ent,${dec / 10}"
            else -> "$ent,${dec.toString().padStart(2, '0')}"
        }
    }
}
