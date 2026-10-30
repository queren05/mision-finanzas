package es.david.findemes.ui

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.DashPathEffect
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Typeface
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.core.content.res.ResourcesCompat
import es.david.findemes.R
import es.david.findemes.model.PigKind
import es.david.findemes.model.SkinDef
import es.david.findemes.support.Ink
import es.david.findemes.support.a
import es.david.findemes.support.hex
import kotlin.math.PI
import kotlin.math.ceil
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin

/** texturas hechas una sola vez (texto con borde, pedazos, sombras, anillos…), a la escala de la pantalla */
object Tex {
    var scale = 3f
    private val cache = HashMap<String, Bitmap>()
    private var texts = 0
    var chunky: Typeface = Typeface.DEFAULT_BOLD
        private set

    fun init(context: android.content.Context) {
        scale = context.resources.displayMetrics.density
        chunky = ResourcesCompat.getFont(context, R.font.lilita_one) ?: Typeface.DEFAULT_BOLD
    }

    private fun cached(key: String, make: () -> Bitmap?): Bitmap? {
        cache[key]?.let { return it }
        val b = make() ?: return null
        cache[key] = b
        return b
    }

    /** lienzo en puntos (se dibuja a la escala de la pantalla) */
    private fun draw(w: Double, h: Double, body: (Canvas) -> Unit): Bitmap {
        val bmp = Bitmap.createBitmap(ceil(w * scale).toInt().coerceAtLeast(1), ceil(h * scale).toInt().coerceAtLeast(1), Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        c.scale(scale, scale)
        body(c)
        return bmp
    }

    private fun key(c: Color) = c.toArgb().toString()
    private val ink = Ink.ink.toArgb()
    private fun paint(color: Int, stroke: Float = 0f) = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        this.color = color
        if (stroke > 0) { style = Paint.Style.STROKE; strokeWidth = stroke; strokeJoin = Paint.Join.ROUND }
    }

    /** texto gordo con borde de tinta (el tamaño del dibujo, en puntos, va en width/height / scale) */
    fun text(s0: String, size: Double, color: Color): Bitmap {
        val s = s0.a
        val k = "t|$s|${size.toInt()}|${key(color)}"
        cache[k]?.let { return it }
        texts += 1
        if (texts > 300) {
            // que no crezca sin fin con tantos importes distintos
            cache.keys.filter { it.startsWith("t|") }.forEach { cache.remove(it) }
            texts = 0
        }
        val p = Paint(Paint.ANTI_ALIAS_FLAG).apply { typeface = chunky; textSize = size.toFloat() }
        val fm = p.fontMetrics
        val tw = p.measureText(s)
        val th = fm.descent - fm.ascent
        val pad = 5.0
        val img = draw(ceil(tw.toDouble()) + pad * 2, ceil(th.toDouble()) + pad * 2 + 2) { c ->
            val base = (pad - fm.ascent).toFloat()
            p.color = ink
            for ((dx, dy) in listOf(-2.5f to 0f, 2.5f to 0f, 0f to -2.5f, 0f to 2.5f, -1.8f to -1.8f, 1.8f to -1.8f, -1.8f to 1.8f, 1.8f to 1.8f, 2f to 3.5f)) {
                c.drawText(s, pad.toFloat() + dx, base + dy, p)
            }
            p.color = color.toArgb()
            c.drawText(s, pad.toFloat(), base, p)
        }
        cache[k] = img
        return img
    }

    /** un cachito del propio animal: un trozo recortado del dibujo con borde de tinta */
    fun chunk(skin: SkinDef, look: String, variant: Int): Bitmap? = cached("ch|${skin.id}|$look|$variant") {
        val img = Assets.skin(skin.id, look) ?: return@cached null
        // las imágenes de iPhone están a 3×: el tamaño en puntos es el de la imagen / 3… da igual, se usa en proporción
        val w = img.width.toDouble(); val h = img.height.toDouble()
        // de la parte del cuerpo (el centro del dibujo), cada variante de un sitio distinto
        val cx = w * (0.3 + 0.4 * ((variant * 37) % 10) / 10.0)
        val cy = h * (0.35 + 0.35 * ((variant * 53) % 10) / 10.0)
        val side = min(w, h) * 0.34
        val k = 64 / side
        val base = hex(skin.shards.firstOrNull() ?: "#ffffff").toArgb()
        draw(64.0, 64.0) { c ->
            val path = Path()
            val n = 7
            for (i in 0 until n) {
                val a = i.toDouble() / n * 2 * PI + variant * 0.5
                val r = 27 * (0.55 + 0.45 * ((variant * 7 + i * 13) % 10) / 10.0)
                val x = (32 + cos(a) * r).toFloat(); val y = (32 + sin(a) * r).toFloat()
                if (i == 0) path.moveTo(x, y) else path.lineTo(x, y)
            }
            path.close()
            c.save()
            c.clipPath(path)
            c.drawRect(0f, 0f, 64f, 64f, paint(base))
            c.drawBitmap(img, null, RectF((32 - cx * k).toFloat(), (32 - cy * k).toFloat(), (32 - cx * k + w * k).toFloat(), (32 - cy * k + h * k).toFloat()), Paint(Paint.FILTER_BITMAP_FLAG))
            c.restore()
            c.drawPath(path, paint(ink, 3.5f))
        }
    }

    fun shard(color: Color, variant: Int): Bitmap? = cached("sh|${key(color)}|$variant") {
        draw(48.0, 48.0) { c ->
            val r = 20.0
            val rots = listOf(0.0, 0.7, 1.9)
            val p = Path()
            for (k in 0 until 3) {
                val b = k / 3.0 * 2 * PI + rots[variant % 3] + (if (k == 1) 0.35 else -0.2)
                val x = (24 + cos(b) * r).toFloat(); val y = (24 + sin(b) * r).toFloat()
                if (k == 0) p.moveTo(x, y) else p.lineTo(x, y)
            }
            p.close()
            c.drawPath(p, paint(color.toArgb()))
            c.drawPath(p, paint(ink, 3f))
        }
    }

    val shadow: Bitmap? get() = cached("shadow") {
        draw(100.0, 24.0) { c -> c.drawOval(RectF(0f, 0f, 100f, 24f), paint(android.graphics.Color.argb((0.22 * 255).toInt(), 0, 0, 0))) }
    }

    fun ring(color: Color, width: Double): Bitmap? = cached("ring|${key(color)}|$width") {
        draw(220.0, 140.0) { c ->
            val p = paint(color.toArgb(), width.toFloat()).apply { pathEffect = DashPathEffect(floatArrayOf(12f, 14f), 0f) }
            c.drawOval(RectF(6f, 6f, 214f, 134f), p)
        }
    }

    val impact: Bitmap? get() = cached("impact") {
        draw(220.0, 140.0) { c ->
            val p = paint(ink, 5f).apply { strokeCap = Paint.Cap.ROUND }
            var a = 0.0
            while (a < 2 * PI - 1e-9) {
                c.drawLine((110 + cos(a) * 55).toFloat(), (70 + sin(a) * 38).toFloat(), (110 + cos(a) * 94).toFloat(), (70 + sin(a) * 60).toFloat(), p)
                a += PI / 4
            }
        }
    }

    val blast: Bitmap? get() = cached("blast") {
        draw(200.0, 200.0) { c ->
            c.drawOval(RectF(4f, 4f, 196f, 196f), paint(Ink.gold.copy(alpha = 0.5f).toArgb()))
            c.drawOval(RectF(4f, 4f, 196f, 196f), paint(ink, 6f))
        }
    }

    val fuse: Bitmap? get() = cached("fuse") {
        draw(50.0, 50.0) { c ->
            val path = Path().apply { moveTo(30f, 46f); quadTo(44f, 14f, 12f, 10f) }
            c.drawPath(path, paint(ink, 8f).apply { strokeCap = Paint.Cap.ROUND })
            c.drawPath(path, paint(hex("#c9a26b").toArgb(), 4f).apply { strokeCap = Paint.Cap.ROUND })
        }
    }

    val flame: Bitmap? get() = cached("flame") {
        draw(30.0, 30.0) { c ->
            c.drawOval(RectF(1f, 1f, 29f, 29f), paint(Ink.gold.toArgb()))
            c.drawOval(RectF(8f, 8f, 22f, 22f), paint(Ink.red.toArgb()))
        }
    }

    val skate: Bitmap? get() = cached("skate") {
        draw(120.0, 34.0) { c ->
            for (x in listOf(24f, 96f)) c.drawOval(RectF(x - 10, 12f, x + 10, 32f), paint(ink))
            for (x in listOf(24f, 96f)) c.drawOval(RectF(x - 5, 17f, x + 5, 27f), paint(android.graphics.Color.GRAY))
            val board = RectF(2f, 4f, 118f, 16f)
            c.drawRoundRect(board, 6f, 6f, paint(hex("#d9573b").toArgb()))
            c.drawRoundRect(board, 6f, 6f, paint(ink, 3f))
        }
    }

    fun hat(k: PigKind): Bitmap? = Hat.image(k)
}
