package es.david.findemes.money

import android.app.Activity
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import es.david.findemes.logic.Game
import es.david.findemes.logic.todayKey
import java.lang.ref.WeakReference

/** lo que se puede conseguir viendo un anuncio (o gratis con «Sin anuncios»), y cuántas veces al día */
enum class Reward(val perDay: Int) {
    doblar(3),      // doblar lo ganado mientras no jugabas
    tirada(3),      // una tirada más en la feria
    sobre(2),       // un sobre de regalo
    prorroga(1),    // el cobrador te da un día más
}

/** El punto de unión entre el juego, los anuncios y la tienda */
object Money {
    private var activityRef = WeakReference<Activity>(null)
    val activity: Activity? get() = activityRef.get()
    fun attach(a: Activity) { activityRef = WeakReference(a) }

    /** aviso corto en papel abajo de la pantalla */
    var notice by mutableStateOf<String?>(null)
    fun say(text: String) { notice = text }

    fun usesLeft(r: Reward): Int {
        val s = Game.shared.s
        val used = if (s.adDay == todayKey) s.adUses[r.name] ?: 0 else 0
        return (r.perDay - used).coerceAtLeast(0)
    }
    fun canUse(r: Reward) = usesLeft(r) > 0

    private fun spend(r: Reward) {
        val s = Game.shared.s
        if (s.adDay != todayKey) { s.adDay = todayKey; s.adUses = emptyMap() }
        s.adUses = s.adUses + (r.name to (s.adUses[r.name] ?: 0) + 1)
    }

    /** con «Sin anuncios» se cobra al momento; si no, después de ver el anuncio entero */
    fun claim(r: Reward, grant: () -> Unit) {
        if (!canUse(r)) return
        if (Shop.noAds) { spend(r); grant(); Game.shared.save(); return }
        val a = activity ?: return
        if (!Ads.ready) { Ads.load(a); say("Ahora no hay anuncios. Prueba en un rato"); return }
        Ads.show(a) { ok ->
            if (ok) { spend(r); grant(); Game.shared.save() }
        }
    }
}
