package es.david.findemes.ui

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import es.david.findemes.model.HammerDef
import es.david.findemes.model.HammerStyle

/** imágenes de objetos (martillos, joyas, monedas) y de los personajes, cargadas una vez */
object Assets {
    private lateinit var ctx: Context
    private val cache = HashMap<String, Bitmap?>()
    fun init(context: Context) { ctx = context.applicationContext }

    private fun load(path: String): Bitmap? = cache.getOrPut(path) {
        try { ctx.assets.open(path).use { BitmapFactory.decodeStream(it) } } catch (_: Exception) { null }
    }
    fun item(name: String, ext: String = "png"): Bitmap? = load("items/$name.$ext")
    fun skin(skin: String, look: String = "normal"): Bitmap? = load("skins/${skin}_$look.png")
}

/** los martillos son modelos 3D renderizados a imagen (items/m_*.png) */
object HammerArt {
    class Meta(val file: String, val w: Double, val h: Double, val ax: Double, val ay: Double)
    /** ancho, alto y centro de la cabeza (en píxeles de la imagen) */
    val meta: Map<HammerStyle, Meta> = mapOf(
        HammerStyle.chancla to Meta("m_chancla", 179.0, 328.0, 81.0, 151.0),
        HammerStyle.toy to Meta("m_toy", 238.0, 341.0, 119.0, 78.0),
        HammerStyle.claw to Meta("m_claw", 246.0, 342.0, 152.0, 45.0),
        HammerStyle.mallet to Meta("m_mallet", 208.0, 340.0, 104.0, 76.0),
        HammerStyle.mace to Meta("m_mace", 158.0, 324.0, 79.0, 82.0),
        HammerStyle.jack to Meta("m_jack", 252.0, 336.0, 126.0, 135.0),
        HammerStyle.sledge to Meta("m_sledge", 222.0, 348.0, 111.0, 68.0),
        HammerStyle.thunder to Meta("m_thunder", 250.0, 349.0, 125.0, 87.0),
        HammerStyle.thunderGold to Meta("m_trueno_oro", 292.0, 357.0, 146.0, 98.0),
        HammerStyle.diamond to Meta("m_diamante", 228.0, 350.0, 114.0, 71.0),
        HammerStyle.cosmic to Meta("m_cosmico", 186.0, 320.0, 93.0, 93.0),
        HammerStyle.goldFlop to Meta("m_chancla_oro", 179.0, 328.0, 81.0, 151.0),
        HammerStyle.fire to Meta("m_fuego", 174.0, 327.0, 87.0, 93.0),
        HammerStyle.ice to Meta("m_hielo", 192.0, 345.0, 96.0, 72.0),
        HammerStyle.viking to Meta("m_vikingo", 140.0, 319.0, 81.0, 81.0),
        HammerStyle.anvil to Meta("m_yunque", 244.0, 348.0, 126.0, 74.0),
        HammerStyle.plunger to Meta("m_desatascador", 168.0, 348.0, 84.0, 61.0),
        HammerStyle.swatter to Meta("m_matamoscas", 139.0, 324.0, 70.0, 95.0),
        HammerStyle.pan to Meta("m_sarten", 188.0, 328.0, 94.0, 97.0),
        HammerStyle.bat to Meta("m_bate", 98.0, 340.0, 49.0, 54.0),
        HammerStyle.choco to Meta("m_chocolate", 222.0, 341.0, 111.0, 79.0),
        HammerStyle.gavel to Meta("m_juez", 188.0, 338.0, 94.0, 67.0),
    )
    fun image(h: HammerDef): Bitmap? = Assets.item(meta.getValue(h.style).file)
    /** vector de la cabeza al final del mango (en puntos) */
    fun handle(h: HammerDef, height: Double): Pair<Double, Double> {
        val m = meta.getValue(h.style)
        val k = height / m.h
        return (m.w / 2 - m.ax) * k to (m.h - m.ay) * k
    }
}
