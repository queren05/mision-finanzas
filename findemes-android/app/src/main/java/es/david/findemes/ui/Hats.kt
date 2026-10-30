package es.david.findemes.ui

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.DashPathEffect
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import androidx.compose.ui.graphics.toArgb
import es.david.findemes.model.PigKind
import es.david.findemes.support.Ink
import es.david.findemes.support.hex
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

/** lo que lleva puesto cada tipo de hucha encima de la cabeza (sombreros, antenas, lazos…) */
object Hat {
    class Spec(
        val w: Double, val h: Double,   // tamaño del lienzo
        val width: Double,              // ancho en pantalla (× tamaño de la hucha)
        val ax: Double = 0.5, val ay: Double = 0.9,   // punto que va sobre la cabeza (0…1, desde arriba a la izquierda)
        val dx: Double = 0.0, val dy: Double = 0.04,  // desplazamiento desde la cabeza (× tamaño, hacia abajo)
        val onBody: Boolean = false,    // va alrededor del cuerpo, no en la cabeza
    )

    fun spec(k: PigKind): Spec? = when (k) {
        PigKind.rey -> Spec(90.0, 50.0, 0.42, ay = 0.85)
        PigKind.reina -> Spec(90.0, 50.0, 0.36, ay = 0.85)
        PigKind.millonaria -> Spec(80.0, 74.0, 0.36)
        PigKind.pirata -> Spec(100.0, 60.0, 0.5, ay = 0.85, dy = 0.05)
        PigKind.ninja -> Spec(110.0, 40.0, 0.5, ax = 0.55, ay = 0.5, dy = 0.12)
        PigKind.payaso -> Spec(60.0, 84.0, 0.24, ay = 0.92)
        PigKind.titan -> Spec(110.0, 64.0, 0.52, dy = 0.06)
        PigKind.alien -> Spec(70.0, 70.0, 0.3, ay = 0.97, dy = 0.03)
        PigKind.robot -> Spec(40.0, 74.0, 0.14, ay = 0.97, dy = 0.03)
        PigKind.madre -> Spec(70.0, 44.0, 0.3, ay = 0.7, dx = -0.06, dy = 0.02)
        PigKind.suerte -> Spec(50.0, 64.0, 0.2, ay = 0.95, dy = 0.02)
        PigKind.cosmica -> Spec(100.0, 50.0, 0.5, ay = 1.0, dy = -0.04)
        PigKind.hielo -> Spec(90.0, 46.0, 0.4)
        PigKind.fenix -> Spec(80.0, 70.0, 0.34, ay = 0.95)
        PigKind.lava -> Spec(80.0, 60.0, 0.34, ay = 0.95, dy = 0.05)
        PigKind.nube -> Spec(110.0, 70.0, 0.55, ay = 1.0, dy = -0.08)
        PigKind.vampiro -> Spec(100.0, 46.0, 0.42, dy = -0.02)
        PigKind.momia -> Spec(90.0, 40.0, 0.42, ay = 0.5, dy = 0.1)
        PigKind.zombi -> Spec(50.0, 50.0, 0.18, ay = 0.5, dx = -0.08, dy = 0.1)
        PigKind.agujero -> Spec(200.0, 80.0, 1.5, ay = 0.5, dy = 0.0, onBody = true)
        else -> null
    }

    private val cache = HashMap<PigKind, Bitmap>()
    fun image(k: PigKind): Bitmap? {
        cache[k]?.let { return it }
        val s = spec(k) ?: return null
        val sc = 3f
        val bmp = Bitmap.createBitmap((s.w * sc).toInt(), (s.h * sc).toInt(), Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        c.scale(sc, sc)
        draw(k, c)
        cache[k] = bmp
        return bmp
    }

    private val ink = Ink.ink.toArgb()
    private fun ui(h: String) = hex(h).toArgb()
    private val fillP = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private val strokeP = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeJoin = Paint.Join.ROUND; strokeCap = Paint.Cap.ROUND }

    private fun fillStroke(c: Canvas, p: Path, fill: Int, lw: Float = 4f) {
        fillP.color = fill; c.drawPath(p, fillP)
        strokeP.color = ink; strokeP.strokeWidth = lw; c.drawPath(p, strokeP)
    }
    private fun ellipse(c: Canvas, x: Float, y: Float, r: Float, fill: Int, lw: Float = 3.5f) {
        fillStroke(c, Path().apply { addOval(RectF(x - r, y - r, x + r, y + r), Path.Direction.CW) }, fill, lw)
    }
    private fun roundRect(x: Float, y: Float, w: Float, h: Float, r: Float) = Path().apply { addRoundRect(RectF(x, y, x + w, y + h), r, r, Path.Direction.CW) }
    private fun fill(c: Canvas, color: Int, block: (Paint) -> Unit) { fillP.color = color; block(fillP) }
    private fun line(c: Canvas, color: Int, w: Float, vararg seg: Float) {
        strokeP.color = color; strokeP.strokeWidth = w
        var i = 0
        while (i + 3 < seg.size) { c.drawLine(seg[i], seg[i + 1], seg[i + 2], seg[i + 3], strokeP); i += 4 }
    }
    private fun star(c: Canvas, x: Float, y: Float, r: Float) {
        val p = Path()
        for (i in 0 until 10) {
            val a = i * PI / 5 - PI / 2
            val rr = if (i % 2 == 0) r else r * 0.45f
            val px = (x + cos(a) * rr).toFloat(); val py = (y + sin(a) * rr).toFloat()
            if (i == 0) p.moveTo(px, py) else p.lineTo(px, py)
        }
        p.close(); fillStroke(c, p, Ink.gold.toArgb(), 3f)
    }
    private fun flame(c: Canvas, x: Float, base: Float, w: Float, h: Float, fill: Int) {
        val p = Path()
        p.moveTo(x, base - h)
        p.cubicTo(x + w, base - h * 0.5f, x + w * 0.8f, base, x, base)
        p.cubicTo(x - w * 0.8f, base, x - w, base - h * 0.5f, x, base - h)
        fillStroke(c, p, fill, 3.5f)
    }
    private fun poly(vararg pts: Float) = Path().apply {
        moveTo(pts[0], pts[1]); var i = 2
        while (i + 1 < pts.size) { lineTo(pts[i], pts[i + 1]); i += 2 }
        close()
    }

    private fun draw(k: PigKind, c: Canvas) {
        val gold = Ink.gold.toArgb(); val red = Ink.red.toArgb(); val white = android.graphics.Color.WHITE
        when (k) {
            PigKind.rey -> {
                val p = Path(); p.moveTo(5f, 45f)
                for (i in 0 until 7) p.lineTo(5f + i * 80f / 6, if (i % 2 == 1) 32f else 5f)
                p.lineTo(85f, 45f); p.close(); fillStroke(c, p, gold)
                fillP.color = red
                for (i in listOf(1, 3, 5)) c.drawOval(RectF(5f + i * 80f / 6 - 5, 30f, 5f + i * 80f / 6 + 5, 40f), fillP)
            }
            PigKind.reina -> {
                // diadema: un arco fino con picos y un corazón
                val p = Path(); p.moveTo(6f, 46f)
                p.quadTo(45f, 26f, 84f, 46f)
                p.lineTo(72f, 30f); p.lineTo(62f, 36f); p.lineTo(45f, 8f)
                p.lineTo(28f, 36f); p.lineTo(18f, 30f); p.close()
                fillStroke(c, p, gold)
                ellipse(c, 45f, 26f, 7f, ui("#ff6f9a"), 3f)
            }
            PigKind.millonaria -> {
                fillStroke(c, roundRect(18f, 6f, 44f, 54f, 4f), ui("#2f2a36"))
                fillP.color = gold; c.drawRect(20f, 44f, 60f, 53f, fillP)
                fillStroke(c, roundRect(4f, 56f, 72f, 12f, 6f), ui("#2f2a36"))
            }
            PigKind.pirata -> {
                val p = Path(); p.moveTo(4f, 48f)
                p.quadTo(10f, 20f, 30f, 14f)
                p.quadTo(50f, 2f, 70f, 14f)
                p.quadTo(90f, 20f, 96f, 48f)
                p.quadTo(50f, 34f, 4f, 48f)
                fillStroke(c, p, ui("#2b2730"))
                line(c, white, 3.5f, 40f, 38f, 60f, 22f, 40f, 22f, 60f, 38f)
                fillP.color = white; c.drawOval(RectF(43f, 18f, 57f, 31f), fillP)
                fillP.color = ui("#2b2730")
                c.drawOval(RectF(46f, 22f, 49.5f, 25.5f), fillP); c.drawOval(RectF(51f, 22f, 54.5f, 25.5f), fillP)
            }
            PigKind.ninja -> {
                // la cinta y sus dos colas hacia atrás
                fillStroke(c, poly(22f, 18f, 2f, 30f, 8f, 36f, 24f, 24f), red, 3f)
                fillStroke(c, poly(22f, 20f, 6f, 16f, 6f, 24f), red, 3f)
                fillStroke(c, roundRect(18f, 10f, 86f, 18f, 6f), red)
                fillP.color = ui("#d9d6dc"); c.drawRect(72f, 13f, 90f, 25f, fillP)
            }
            PigKind.payaso -> {
                val p = Path(); p.moveTo(6f, 78f); p.lineTo(30f, 16f); p.lineTo(54f, 78f)
                p.quadTo(30f, 86f, 6f, 78f)
                fillStroke(c, p, ui("#ffd23a"))
                fillP.color = red
                for ((x, y) in listOf(24f to 44f, 36f to 58f, 22f to 68f, 40f to 72f, 30f to 32f)) c.drawOval(RectF(x - 4, y - 4, x + 4, y + 4), fillP)
                ellipse(c, 30f, 12f, 9f, red)
            }
            PigKind.titan -> {
                // casco con cuernos
                val l = Path(); l.moveTo(28f, 44f); l.quadTo(6f, 34f, 6f, 4f); l.quadTo(22f, 30f, 36f, 34f)
                fillStroke(c, l, ui("#efe3c4"))
                val r = Path(); r.moveTo(82f, 44f); r.quadTo(104f, 34f, 104f, 4f); r.quadTo(88f, 30f, 74f, 34f)
                fillStroke(c, r, ui("#efe3c4"))
                val d = Path(); d.moveTo(22f, 58f); d.arcTo(RectF(22f, 25f, 88f, 91f), 180f, 180f); d.close()
                fillStroke(c, d, ui("#9aa1a9"))
                fillP.color = ink
                for (x in listOf(38f, 55f, 72f)) c.drawOval(RectF(x - 3, 48f, x + 3, 54f), fillP)
            }
            PigKind.alien -> {
                strokeP.color = ink; strokeP.strokeWidth = 5f
                c.drawPath(Path().apply { moveTo(26f, 68f); quadTo(26f, 30f, 14f, 14f); moveTo(44f, 68f); quadTo(44f, 30f, 56f, 14f) }, strokeP)
                ellipse(c, 14f, 12f, 9f, ui("#8fe36a")); ellipse(c, 56f, 12f, 9f, ui("#8fe36a"))
            }
            PigKind.robot -> {
                line(c, ink, 6f, 20f, 72f, 20f, 20f)
                line(c, ui("#8fa3b8"), 3f, 20f, 70f, 20f, 22f)
                ellipse(c, 20f, 14f, 10f, red)
            }
            PigKind.madre -> {
                fillStroke(c, poly(35f, 22f, 4f, 6f, 6f, 40f), ui("#ff8fb1"))
                fillStroke(c, poly(35f, 22f, 66f, 6f, 64f, 40f), ui("#ff8fb1"))
                ellipse(c, 35f, 22f, 8f, ui("#ff6f9a"))
            }
            PigKind.suerte -> {
                strokeP.color = ink; strokeP.strokeWidth = 5f
                c.drawPath(Path().apply { moveTo(25f, 30f); quadTo(22f, 50f, 30f, 62f) }, strokeP)
                for ((x, y) in listOf(15f to 14f, 35f to 14f, 15f to 32f, 35f to 32f)) ellipse(c, x, y, 10f, ui("#4fc25c"))
                fillP.color = ui("#4fc25c"); c.drawOval(RectF(17f, 15f, 33f, 31f), fillP)
            }
            PigKind.cosmica -> { star(c, 20f, 30f, 14f); star(c, 52f, 16f, 12f); star(c, 82f, 32f, 13f) }
            PigKind.hielo -> {
                val p = Path(); p.moveTo(6f, 42f)
                for ((i, x) in listOf(6f, 18f, 30f, 45f, 60f, 72f, 84f).withIndex()) p.lineTo(x, if (i % 2 == 0) 10f + (i % 3) * 3f else 30f)
                p.lineTo(84f, 42f); p.close(); fillStroke(c, p, ui("#bfefff"))
                line(c, white, 3f, 14f, 36f, 76f, 36f)
            }
            PigKind.fenix -> {
                flame(c, 20f, 66f, 16f, 46f, ui("#f0642a"))
                flame(c, 60f, 66f, 16f, 46f, ui("#f0642a"))
                flame(c, 40f, 66f, 18f, 62f, gold)
            }
            PigKind.lava -> {
                flame(c, 22f, 56f, 14f, 34f, red)
                flame(c, 58f, 56f, 14f, 38f, red)
                flame(c, 40f, 56f, 16f, 50f, ui("#ff9a2a"))
            }
            PigKind.nube -> {
                val puffs = listOf(Triple(30f, 32f, 18f), Triple(55f, 22f, 22f), Triple(80f, 32f, 18f))
                val outline = Path()
                for ((x, y, r) in puffs) outline.addOval(RectF(x - r, y - r, x + r, y + r), Path.Direction.CW)
                outline.addRoundRect(RectF(12f, 30f, 98f, 50f), 10f, 10f, Path.Direction.CW)
                strokeP.color = ink; strokeP.strokeWidth = 8f; c.drawPath(outline, strokeP)
                fillP.color = white
                for ((x, y, r) in puffs) c.drawOval(RectF(x - r, y - r, x + r, y + r), fillP)
                c.drawRect(12f, 30f, 98f, 50f, fillP)
                strokeP.color = ui("#5aa8e6"); strokeP.strokeWidth = 4f
                for (x in listOf(36f, 56f, 76f)) c.drawLine(x, 58f, x - 3, 67f, strokeP)
            }
            PigKind.vampiro -> {
                // un murciélago
                val p = Path(); p.moveTo(50f, 18f)
                p.quadTo(26f, 2f, 4f, 10f)
                p.quadTo(6f, 26f, 18f, 30f)
                p.quadTo(24f, 26f, 32f, 32f)
                p.quadTo(40f, 30f, 50f, 40f)
                p.quadTo(60f, 30f, 68f, 32f)
                p.quadTo(76f, 26f, 82f, 30f)
                p.quadTo(94f, 26f, 96f, 10f)
                p.quadTo(74f, 2f, 50f, 18f)
                fillStroke(c, p, ui("#2b2730"))
                fillP.color = red
                c.drawOval(RectF(43f, 20f, 48f, 25f), fillP); c.drawOval(RectF(52f, 20f, 57f, 25f), fillP)
            }
            PigKind.momia -> {
                fillStroke(c, roundRect(4f, 8f, 82f, 14f, 4f), ui("#efe4c4"), 3.5f)
                c.save(); c.translate(45f, 22f); c.rotate((-0.25 * 180 / PI).toFloat())
                fillStroke(c, roundRect(-40f, 0f, 80f, 13f, 4f), ui("#e2d4ac"), 3.5f)
                c.restore()
            }
            PigKind.zombi -> {
                // tirita en cruz
                for (a in listOf(0.6, -0.6)) {
                    c.save(); c.translate(25f, 25f); c.rotate((a * 180 / PI).toFloat())
                    fillStroke(c, roundRect(-22f, -7f, 44f, 14f, 5f), ui("#f2c9a0"), 3f)
                    c.restore()
                }
            }
            PigKind.agujero -> {
                strokeP.color = ink; strokeP.strokeWidth = 9f
                c.drawOval(RectF(8f, 14f, 192f, 66f), strokeP)
                val dash = Paint(strokeP).apply { color = ui("#9b7bff"); strokeWidth = 4f; strokeCap = Paint.Cap.BUTT; pathEffect = DashPathEffect(floatArrayOf(16f, 10f), 0f) }
                c.drawOval(RectF(8f, 14f, 192f, 66f), dash)
            }
            else -> {}
        }
    }
}
