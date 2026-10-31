package es.david.findemes.ui

import es.david.findemes.support.tf
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import androidx.compose.ui.graphics.toArgb
import es.david.findemes.logic.Desk
import es.david.findemes.model.PigKind
import es.david.findemes.support.Fmt
import es.david.findemes.support.Ink
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.random.Random

/** los colores especiales de cada tipo en la mesa (el dibujo se mezcla con este color) */
fun PigKind.tint(t: Double, id: Int): Pair<Int, Float>? {
    fun rgb(r: Double, g: Double, b: Double) = android.graphics.Color.rgb((r * 255).toInt().coerceIn(0, 255), (g * 255).toInt().coerceIn(0, 255), (b * 255).toInt().coerceIn(0, 255))
    fun hsb(h: Double, s: Double, v: Double) = android.graphics.Color.HSVToColor(floatArrayOf((((h % 1) + 1) % 1 * 360).toFloat(), s.toFloat(), v.toFloat()))
    return when (this) {
        PigKind.arcoiris -> hsb(t * 0.45 + id * 0.1, 0.85, 1.0) to 0.5f
        PigKind.diamante -> rgb(0.55, 0.9, 1.0) to 0.3f
        PigKind.lava -> rgb(1.0, 0.35 + 0.15 * sin(t * 6 + id), 0.1) to 0.55f
        PigKind.cosmica -> hsb(0.72 + 0.08 * sin(t * 2 + id), 0.8, 0.9) to 0.55f
        PigKind.hielo -> rgb(0.7, 0.95, 1.0) to 0.45f
        PigKind.suerte -> rgb(0.35, 0.85, 0.4) to 0.5f
        PigKind.zombi -> rgb(0.55, 0.7, 0.45) to 0.55f
        PigKind.robot -> rgb(0.5, 0.75, 1.0) to 0.3f
        PigKind.ninja -> rgb(0.2, 0.19, 0.24) to 0.7f
        PigKind.payaso -> hsb(t * 0.8 + id * 0.2, 0.6, 1.0) to 0.4f
        PigKind.pirata -> rgb(0.8, 0.6, 0.38) to 0.45f
        PigKind.vampiro -> rgb(0.6, 0.12, 0.2) to 0.6f
        PigKind.momia -> rgb(0.93, 0.88, 0.74) to 0.6f
        PigKind.alien -> rgb(0.5, 0.9, 0.4) to 0.55f
        PigKind.nube -> android.graphics.Color.WHITE to 0.65f
        PigKind.reina -> rgb(1.0, 0.75, 0.85) to 0.3f
        PigKind.fenix -> rgb(1.0, 0.45 + 0.2 * sin(t * 5 + id), 0.15) to 0.55f
        PigKind.agujero -> hsb(0.75, 0.6, 0.3 + 0.1 * sin(t * 3)) to 0.7f
        else -> null
    }
}

/** mezcla el dibujo con un color (como colorBlendFactor de SpriteKit): se queda la transparencia */
fun blendFilter(color: Int, f: Float): ColorMatrixColorFilter {
    val r = android.graphics.Color.red(color) * f; val g = android.graphics.Color.green(color) * f; val b = android.graphics.Color.blue(color) * f
    val k = 1 - f
    return ColorMatrixColorFilter(ColorMatrix(floatArrayOf(
        k, 0f, 0f, 0f, r,
        0f, k, 0f, 0f, g,
        0f, 0f, k, 0f, b,
        0f, 0f, 0f, 1f, 0f,
    )))
}

/** La mesa dibujada: la simulación sigue en `Desk` y aquí solo se pinta cada cosa en su sitio en cada fotograma. */
class DeskScene(val desk: Desk) {
    private val bmpPaint = Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG)
    private val fill = Paint(Paint.ANTI_ALIAS_FLAG)
    private val crackPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; color = Ink.ink.toArgb(); strokeCap = Paint.Cap.ROUND; strokeJoin = Paint.Join.ROUND }
    private val rect = RectF()
    private var shakeX = 0.0
    private var shakeY = 0.0

    /** dibuja un mapa de bits de `w`×`h` puntos con la esquina (x, y) */
    private fun img(c: Canvas, b: Bitmap?, x: Double, y: Double, w: Double, h: Double, alpha: Double = 1.0) {
        if (b == null || alpha <= 0) return
        rect.set(x.toFloat(), y.toFloat(), (x + w).toFloat(), (y + h).toFloat())
        bmpPaint.alpha = (min(1.0, alpha) * 255).toInt()
        c.drawBitmap(b, null, rect, bmpPaint)
        bmpPaint.alpha = 255
    }
    /** igual, centrado en (x, y) y con el tamaño natural del dibujo (en puntos) */
    private fun centered(c: Canvas, b: Bitmap, x: Double, y: Double, scale: Double = 1.0, alpha: Double = 1.0) {
        val w = b.width / Tex.scale * scale; val h = b.height / Tex.scale * scale
        img(c, b, x - w / 2, y - h / 2, w, h, alpha)
    }

    private fun dims(p: Desk.Pig): Pair<Double, Double> {
        val skin = desk.skin
        val s = p.size
        var dw = s * 1.5
        var dh = dw * skin.h / skin.w
        if (skin.drawn) { dw = s * 1.25; dh = dw }
        if (dh > s * 1.35) { dh = s * 1.35; dw = dh * skin.w / skin.h }
        return dw to dh
    }

    fun draw(c: Canvas, w: Double, h: Double) {
        val sh = desk.shake
        if (sh > 0.3) { shakeX = Random.nextDouble(-sh, sh); shakeY = Random.nextDouble(-sh, sh) } else { shakeX = 0.0; shakeY = 0.0 }
        // fondo
        c.drawColor(Ink.wood.toArgb())
        c.save()
        c.translate(shakeX.toFloat(), shakeY.toFloat())
        Assets.item("mesa", "jpg")?.let { bg ->
            val k = max((w + 40) / 1179, (h + 40) / 2556)
            img(c, bg, w / 2 - 1179 * k / 2, h / 2 - 2556 * k / 2, 1179 * k, 2556 * k)
        }
        val t = desk.time
        val pigs = desk.pigs.sortedBy { it.pos.y }
        // sombras
        for (p in pigs) {
            val (dw, _) = dims(p)
            val s = p.size
            val m = motion(p, t)
            val sw = dw * 0.62 * m.pop * (1 - m.hop / s * 1.6)
            val wheels = p.kind == PigKind.ruedas
            val sy = m.feet + (if (wheels) s * 0.12 else 0.0)
            img(c, Tex.shadow, p.pos.x - sw / 2, sy - max(1.0, sw * 0.22) / 2, max(1.0, sw), max(1.0, sw * 0.22))
        }
        for (p in pigs) drawPig(c, p, t)
        drawBlasts(c, t)
        drawShards(c, t)
        drawLoot(c, t)
        drawSwings(c, t)
        // barras de vida
        for (p in pigs) if (p.hp < p.maxHP) {
            val (_, dh) = dims(p)
            val m = motion(p, t)
            val bw = max(26.0, p.size * 0.8)
            val x = p.pos.x; val y = m.feet - m.hop - dh * m.pop - 16
            fill.color = Ink.ink.toArgb(); c.drawRect((x - bw / 2 - 2).toFloat(), (y - 5.5).toFloat(), (x + bw / 2 + 2).toFloat(), (y + 5.5).toFloat(), fill)
            fill.color = Ink.paper.toArgb(); c.drawRect((x - bw / 2).toFloat(), (y - 3.5).toFloat(), (x + bw / 2).toFloat(), (y + 3.5).toFloat(), fill)
            fill.color = Ink.red.toArgb()
            c.drawRect((x - bw / 2).toFloat(), (y - 3.5).toFloat(), (x - bw / 2 + max(0.5, bw * max(0.0, p.hp / p.maxHP))).toFloat(), (y + 3.5).toFloat(), fill)
        }
        drawFloaters(c, t)
        c.restore()
        drawHUD(c, t, w)
        drawTutorial(c, t, w, h)
    }

    private class Motion(val pop: Double, val sq: Double, val hop: Double, val land: Double, val breathe: Double, val tilt: Double, val feet: Double)

    private fun motion(p: Desk.Pig, t: Double): Motion {
        val s = p.size
        val age = t - p.born
        val pop = if (age < 0.3) max(0.01, 1 + 0.25 * sin(age / 0.3 * PI) - (1 - age / 0.3) * (1 - age / 0.3) * 0.9) else 1.0
        val h = t - p.hitAt
        val sq = if (h < 0.35) exp(-h * 12) * cos(h * 40) * 0.22 else 0.0
        val wheels = p.kind == PigKind.ruedas
        val moving = hypot(p.vel.dx, p.vel.dy) > 2 && h > 0.3
        val ph = t * (if (p.kind == PigKind.bomba) 11.0 else 8.5) + p.id * 1.7
        val up = abs(sin(ph))
        val hop = if (wheels || !moving) 0.0 else up * s * 0.14
        val land = if (!wheels && moving) max(0.0, 0.22 - up) * 0.4 else 0.0
        val breathe = if (moving) 0.0 else sin(t * 3 + p.id) * 0.025
        val tilt = if (wheels) -0.05 else if (moving) cos(ph) * 0.08 else 0.0
        return Motion(pop, sq, hop, land, breathe, tilt, p.pos.y + s * 0.42)
    }

    private fun drawPig(c: Canvas, p: Desk.Pig, t: Double) {
        val skin = desk.skin
        val s = p.size
        val m = motion(p, t)
        val (dw, dh) = dims(p)
        val h = t - p.hitAt
        c.save()
        c.translate(p.pos.x.toFloat(), (m.feet - m.hop).toFloat())
        c.rotate((m.tilt * p.facing * 180 / PI).toFloat())
        c.scale((p.facing * m.pop * (1 + m.sq + m.land)).toFloat(), (m.pop * (1 - m.sq - m.land + m.breathe)).toFloat())
        val bodyY = if (p.kind == PigKind.ruedas) 0.0 else s * 0.02
        // monopatín (detrás)
        if (p.kind == PigKind.ruedas) {
            val bw = dw * 0.9; val bh = bw * 34 / 120
            img(c, Tex.skate, -bw / 2, -bh * 0.25, bw, bh)
        }
        // el cuerpo, con su color especial o el destello del golpe
        val body = Assets.skin(skin.id, p.kind.look)
        if (body != null) {
            val tint = if (h < 0.08) android.graphics.Color.WHITE to 0.6f else p.kind.tint(t, p.id)
            bmpPaint.colorFilter = tint?.let { blendFilter(it.first, it.second) }
            img(c, body, -dw / 2, bodyY - dh, dw, dh, if (p.kind == PigKind.fantasma) 0.45 + 0.15 * sin(t * 4 + p.id) else 1.0)
            bmpPaint.colorFilter = null
        }
        // grietas
        if (p.cracks.isNotEmpty()) {
            crackPaint.strokeWidth = max(1.8, s * 0.034).toFloat()
            val path = Path()
            for (crack in p.cracks) for ((k, pt) in crack.withIndex()) {
                val x = (pt.x * s * 0.9).toFloat(); val y = (pt.y * s * 0.75 - s * 0.42).toFloat()
                if (k == 0) path.moveTo(x, y) else path.lineTo(x, y)
            }
            c.drawPath(path, crackPaint)
        }
        // cabeza (para la corona y la mecha)
        val hx = if (skin.drawn) dw * 0.12 else -dw / 2 + skin.head.x / skin.w * dw
        val hy = if (skin.drawn) -dh * 0.85 else -(dh - skin.head.y / skin.h * dh) + bodyY
        Hat.spec(p.kind)?.let { sp ->
            val hw = s * sp.width; val hh = hw * sp.h / sp.w
            val (x, y) = if (sp.onBody) 0.0 to (-dh * 0.45 + bodyY) else (hx + sp.dx * s) to (hy + sp.dy * s)
            img(c, Hat.image(p.kind), x - sp.ax * hw, y - sp.ay * hh, hw, hh)
        }
        if (p.kind == PigKind.bomba) {
            val fw = s * 0.3
            img(c, Tex.fuse, hx - 0.6 * fw, hy + s * 0.04 - 0.92 * fw, fw, fw)
            val fl = s * 0.16 * (0.8 + 0.3 * sin(t * 30))
            img(c, Tex.flame, hx - s * 0.13 - fl / 2, hy - s * 0.2 - fl / 2, fl, fl)
        }
        c.restore()
    }

    private fun drawShards(c: Canvas, t: Double) {
        for (s in desk.shards) {
            val r = s.pts.firstOrNull()?.let { hypot(it.x, it.y) } ?: 6.0
            val chunk = if (s.look.isNotEmpty()) Tex.chunk(desk.skin, s.look, s.id % 8) else null
            val (b, size) = if (chunk != null) chunk to r * 3.4 else Tex.shard(s.color, s.id % 3) to r * 2.4
            c.save()
            c.translate(s.pos.x.toFloat(), s.pos.y.toFloat())
            c.rotate((s.rot * 180 / PI).toFloat())
            img(c, b, -size / 2, -size / 2, size, size, max(0.0, 1 - max(0.0, (t - s.born) - 0.8) * 2))
            c.restore()
        }
    }

    private fun drawLoot(c: Canvas, t: Double) {
        for (l in desk.loot) {
            if (t < l.born) continue
            c.save()
            c.translate(l.pos.x.toFloat(), l.pos.y.toFloat())
            if (l.bill) {
                c.rotate((sin(l.rot) * 0.6 * 180 / PI).toFloat())
                img(c, Assets.item("billete"), -17.0, -9.0, 34.0, 18.0)
            } else {
                c.scale(max(0.15, abs(cos(l.rot))).toFloat(), 1f)
                img(c, Assets.item("c_loot"), -11.0, -11.0, 22.0, 22.0)
            }
            c.restore()
        }
    }

    private fun drawSwings(c: Canvas, t: Double) {
        val hammer = desk.hammer
        val m = HammerArt.meta.getValue(hammer.style)
        val hh = 92.0
        val k = hh / m.h
        val himg = Assets.item(m.file)
        for (sw in desk.swings) {
            val age = t - sw.born
            // polvo del golpe
            val kk = min(1.0, age / 0.3)
            val r = sw.radius * (0.6 + 0.5 * kk)
            val rw = r * 2.1; val rh = r * 1.33
            if (sw.hit || age < 0.25) img(c, Tex.ring(if (sw.crit) Ink.red else Ink.paper, if (sw.crit) 7.0 else 4.0), sw.pos.x - rw / 2, sw.pos.y - rh / 2, rw, rh, 1 - kk)
            if (sw.hit) img(c, Tex.impact, sw.pos.x - rw / 2, sw.pos.y - rh / 2, rw, rh, 1 - kk)
            // el martillo gira desde el mango y la cabeza cae donde has tocado
            val (vx, vy) = HammerArt.handle(hammer, hh)
            val final = -0.45
            val st = min(1.0, age / 0.07)
            val ang = final + (1 - st) * 1.25 + (if (sw.hit) 0.0 else 0.12)
            val px = sw.pos.x + vx * cos(final) - vy * sin(final)
            val py = sw.pos.y + vx * sin(final) + vy * cos(final)
            val headX = px - (vx * cos(ang) - vy * sin(ang))
            val headY = py - (vx * sin(ang) + vy * cos(ang))
            c.save()
            c.translate(headX.toFloat(), headY.toFloat())
            c.rotate((ang * 180 / PI).toFloat())
            img(c, himg, -m.ax * k, -m.ay * k, m.w * k, m.h * k, if (age > 0.3) max(0.0, 1 - (age - 0.3) / 0.15) else 1.0)
            c.restore()
        }
    }

    private fun drawBlasts(c: Canvas, t: Double) {
        for (b in desk.blasts) {
            val age = (t - b.born) / 0.6
            val r = b.radius * (0.3 + age * 0.9)
            img(c, Tex.blast, b.pos.x - r, b.pos.y - r, r * 2, r * 2, max(0.0, 1 - age))
        }
    }

    private fun drawFloaters(c: Canvas, t: Double) {
        for (f in desk.floaters) {
            if (t < f.born) continue
            val age = t - f.born
            val y = f.pos.y - 70 * age + 30 * age * age
            val pop = if (age < 0.12) 0.6 + age / 0.12 * 0.5 else if (age < 0.2) 1.1 - (age - 0.12) / 0.08 * 0.1 else 1.0
            val b = Tex.text(f.text, f.size, if (f.color == Ink.ink) Ink.paper else f.color)
            centered(c, b, f.pos.x, y, pop, min(1.0, (1.1 - age) * 3))
        }
    }

    private fun drawHUD(c: Canvas, t: Double, w: Double) {
        val top = desk.top
        if (desk.frenzy) {
            val left = (desk.frenzyUntil - t) / desk.frenzyLength
            fill.color = Ink.gold.copy(alpha = (0.12 + 0.06 * sin(t * 12)).toFloat()).toArgb()
            c.drawRect(-20f, -20f, (w + 20).toFloat(), 10_000f, fill)
            val bw = w * 0.6
            val y = top + 50
            fill.color = Ink.ink.toArgb()
            c.drawRect((w / 2 - bw / 2 - 2).toFloat(), (y - 8).toFloat(), (w / 2 + bw / 2 + 2).toFloat(), (y + 8).toFloat(), fill)
            fill.color = Ink.red.toArgb()
            c.drawRect(((w - bw) / 2).toFloat(), (y - 6).toFloat(), ((w - bw) / 2 + max(0.5, bw * min(1.0, max(0.0, left)))).toFloat(), (y + 6).toFloat(), fill)
        }
        // suceso en marcha (con los segundos que le quedan)
        desk.happening?.let { hp ->
            val name = when (hp) {
                Desk.Happening.lluvia -> "Lluvia de oro"
                Desk.Happening.horaFeliz -> "Hora feliz ×3"
                Desk.Happening.estampida -> "Estampida ×2"
                else -> ""
            }
            if (name.isNotEmpty()) {
                val left = ceil(desk.happeningUntilLeft).toInt()
                centered(c, Tex.text("$name · $left s", 18.0, if (hp == Desk.Happening.lluvia) Ink.gold else Ink.green), w / 2, top + 84)
            }
        }
        val combo = desk.combo
        if (combo < 3) return
        val since = t - desk.comboAt
        val color = if (combo >= 25) Ink.red else if (combo >= 10) Ink.gold else Ink.paper
        centered(c, Tex.text(tf("COMBO ×%1", combo), 26.0, color), w / 2, top + 22, 1 + 0.35 * exp(-since * 10))
        centered(c, Tex.text(tf("dinero ×%1", Fmt.dec(desk.comboMult * (if (desk.frenzy) desk.frenzyGain else 1.0), 2)), 15.0, Ink.paper), w / 2, top + 46)
        if (!desk.frenzy) {
            val k = max(0.0, 1 - since / Desk.COMBO_WINDOW)
            val bw = max(0.5, 90 * k)
            fill.color = Ink.paper.toArgb()
            c.drawRect((w / 2 - bw / 2).toFloat(), (top + 57.5).toFloat(), (w / 2 + bw / 2).toFloat(), (top + 62.5).toFloat(), fill)
        }
    }

    private fun drawTutorial(c: Canvas, t: Double, w: Double, h: Double) {
        if (!desk.tutorial) return
        if (desk.report.swings == 0) {
            desk.bestCluster()?.let { p ->
                val k = 0.5 + 0.5 * sin(t * 5)
                val r = 46 + 10 * k
                img(c, Tex.ring(Ink.paper, 5.0), p.x - r, p.y - r, r * 2, r * 2)
                centered(c, Tex.text("¡Toca aquí!", 28.0, Ink.paper), p.x, p.y - r - 24)
                centered(c, Tex.text("👆", 44.0, androidx.compose.ui.graphics.Color.White), p.x + 14, p.y + 40 - 8 * k)
            }
        }
        val showLow = desk.firstBreakAt?.let { t - it < 4 } ?: false
        if (showLow) {
            centered(c, Tex.text("Junta varias en cada golpe", 22.0, Ink.paper), w / 2, h - desk.bottom - 70)
            centered(c, Tex.text("Cada golpe gasta aguante ↓", 22.0, Ink.gold), w / 2, h - desk.bottom - 36)
        }
    }
}
