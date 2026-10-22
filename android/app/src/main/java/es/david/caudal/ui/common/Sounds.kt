package es.david.caudal.ui.common

import android.content.Context
import android.media.AudioAttributes
import android.media.SoundPool
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import es.david.caudal.R
import es.david.caudal.ui.theme.LocalUiStyle

/** sonidos suaves de la app (se pueden quitar en Personalizar); hechos a mano, sin archivos de terceros */
class Sounds private constructor(context: Context) {
    private val pool = SoundPool.Builder().setMaxStreams(3)
        .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION).setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build())
        .build()
    private val plop = pool.load(context, R.raw.plop, 1)
    private val chime = pool.load(context, R.raw.chime, 1)
    private val pop = pool.load(context, R.raw.pop, 1)
    var enabled = true

    private fun play(id: Int, vol: Float) { if (enabled) pool.play(id, vol, vol, 1, 0, 1f) }
    /** al guardar un movimiento */
    fun plop() = play(plop, 0.5f)
    /** logros, objetivos cumplidos, deudas saldadas */
    fun chime() = play(chime, 0.45f)
    /** interruptores y elecciones */
    fun pop() = play(pop, 0.3f)

    companion object {
        @Volatile private var instance: Sounds? = null
        fun get(context: Context): Sounds = instance ?: synchronized(this) { instance ?: Sounds(context.applicationContext).also { instance = it } }
    }
}

@Composable
fun rememberSounds(): Sounds {
    val ctx = LocalContext.current
    val on = LocalUiStyle.current.sounds
    return remember(on) { Sounds.get(ctx).also { it.enabled = on } }
}
