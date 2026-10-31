package es.david.findemes.support

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import org.json.JSONObject
import java.util.Locale

/** Idiomas del juego. Los textos se escriben en español en el código; los demás idiomas salen de assets/i18n/<código>.json */
enum class Lang(val title: String) {
    es("Español"), en("English"), pt("Português");

    companion object {
        /** el del teléfono: español y portugués si lo es; si no, inglés */
        fun system(): Lang = when (Locale.getDefault().language) { "es", "ca", "gl", "eu" -> es; "pt" -> pt; else -> en }
    }
}

object L10n {
    private lateinit var app: Context
    var lang by mutableStateOf(Lang.es)
        private set
    private var dict: Map<String, String> = emptyMap()

    fun init(context: Context, setting: String) {
        app = context.applicationContext
        set(setting)
    }

    /** "auto" sigue al teléfono */
    fun set(setting: String) {
        val l = Lang.entries.firstOrNull { it.name == setting } ?: Lang.system()
        dict = if (l == Lang.es) emptyMap() else load(l)
        lang = l
    }

    private fun load(l: Lang): Map<String, String> = try {
        val o = JSONObject(app.assets.open("i18n/${l.name}.json").bufferedReader().readText())
        o.keys().asSequence().associateWith { o.getString(it) }
    } catch (_: Exception) { emptyMap() }

    /** el texto en el idioma de ahora (si no está traducido, se queda en español) */
    fun tr(s: String): String {
        if (dict.isEmpty() || s.isEmpty()) return s
        dict[s]?.let { return it }
        // las claves llevan espacios normales (en el código a veces hay espacios finos)
        if (s.contains('\u2009')) dict[s.replace('\u2009', ' ')]?.let { return it }
        // «rara» en minúscula: se busca «Rara» y se devuelve en minúscula
        val c = s.capitalizedFirst
        if (c != s) dict[c]?.let { return it.replaceFirstChar { ch -> ch.lowercaseChar() } }
        return s
    }
}

fun tr(s: String): String = L10n.tr(s)

/** plantilla con huecos %1, %2…: se traduce la plantilla y los textos que van dentro */
fun tf(template: String, vararg args: Any?): String {
    var out = L10n.tr(template)
    for (i in args.indices.reversed()) {
        val v = args[i]
        out = out.replace("%${i + 1}", if (v is String) L10n.tr(v) else v.toString())
    }
    return out
}

/** un nombre dentro de una frase: «a gym fit 24h», «con la chancla»; en inglés se deja como está */
fun nm(name: String): String {
    val t = L10n.tr(name)
    if (L10n.lang != Lang.en) return t.lowercase()
    // en inglés, los nombres de empresa (en mayúsculas) se quedan; lo demás, en minúscula: «with the flip-flop»
    return if (t == t.uppercase()) t else t.replaceFirstChar { it.lowercaseChar() }
}
