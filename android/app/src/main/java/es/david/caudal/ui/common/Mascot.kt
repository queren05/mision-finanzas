package es.david.caudal.ui.common

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import es.david.caudal.ui.theme.CaudalTheme
import es.david.caudal.ui.theme.LocalMotion
import kotlin.math.PI
import kotlin.math.sin

/** cómo va vestida Gotita (Personalizar): complemento y color propio ("" = el de la app) */
data class MascotLook(val hat: String = "nada", val color: String = "")

val LocalMascotLook = androidx.compose.runtime.staticCompositionLocalOf { MascotLook() }

/** complementos que se pueden poner a Gotita */
val MASCOT_HATS = listOf("nada", "gorro", "gafas", "lazo", "corona", "auriculares", "flor")

/** cómo está Gotita */
enum class Mood { HAPPY, WOW, SLEEPY, SAD, LOVE, WINK }

/**
 * Gotita: la mascota de Caudal, una gota de agua con cara. Flota, parpadea y cambia de cara según el momento
 * (contenta si ahorras, sorprendida al apuntar, triste si te pasas del presupuesto…).
 */
@Composable
fun Gotita(mood: Mood = Mood.HAPPY, size: Dp = 96.dp, color: Color = Color.Unspecified, modifier: Modifier = Modifier, description: String = "", hat: String? = null) {
    val look = LocalMascotLook.current
    val body = if (color != Color.Unspecified) color else if (look.color.isNotEmpty()) es.david.caudal.ui.theme.hexColor(look.color) else CaudalTheme.colors.accent
    val wear = hat ?: look.hat
    val motion = LocalMotion.current
    var t by remember { mutableStateOf(0f) }
    var blinking by remember { mutableStateOf(false) }
    // flota unos segundos al aparecer y luego se queda quieta (para no gastar batería);
    // después solo parpadea de vez en cuando
    LaunchedEffect(motion) {
        if (!motion) return@LaunchedEffect
        val start = withFrameNanos { it }
        var now = start
        while ((now - start) < 6_000_000_000L) withFrameNanos { n -> now = n; t = (n - start) / 1_000_000_000f }
        t = 0f
        while (true) {
            kotlinx.coroutines.delay(3600)
            blinking = true
            kotlinx.coroutines.delay(130)
            blinking = false
        }
    }
    Canvas(modifier.size(size).semantics { if (description.isNotEmpty()) contentDescription = description }) {
        val w = this.size.width
        val h = this.size.height
        val bob = if (motion) sin(t * 2.2f) * h * 0.025f else 0f
        // parpadeo: cerrado 0,12 s cada 3,6 s
        val blink = blinking || (motion && t > 0f && (t % 3.6f) > 3.48f)
        translate(top = bob) {
            drop(w, h, body)
            face(w, h, mood, blink)
            accessory(w, h, wear)
        }
        // sombra en el suelo
        val sh = 1f - (bob / (h * 0.025f + 0.001f)) * 0.08f
        drawOval(Color.Black.copy(alpha = 0.12f), Offset(w * (0.5f - 0.2f * sh), h * 0.95f), Size(w * 0.4f * sh, h * 0.04f))
    }
}

private fun DrawScope.drop(w: Float, h: Float, c: Color) {
    val p = Path().apply {
        moveTo(w * 0.5f, h * 0.04f)
        cubicTo(w * 0.62f, h * 0.22f, w * 0.88f, h * 0.42f, w * 0.88f, h * 0.62f)
        cubicTo(w * 0.88f, h * 0.82f, w * 0.71f, h * 0.93f, w * 0.5f, h * 0.93f)
        cubicTo(w * 0.29f, h * 0.93f, w * 0.12f, h * 0.82f, w * 0.12f, h * 0.62f)
        cubicTo(w * 0.12f, h * 0.42f, w * 0.38f, h * 0.22f, w * 0.5f, h * 0.04f)
        close()
    }
    drawPath(p, Brush.verticalGradient(listOf(lerp(c, Color.White, 0.35f), c, lerp(c, Color.Black, 0.12f)), startY = 0f, endY = h))
    // brillo
    drawOval(Color.White.copy(alpha = 0.55f), Offset(w * 0.25f, h * 0.48f), Size(w * 0.1f, h * 0.17f))
    drawCircle(Color.White.copy(alpha = 0.55f), w * 0.03f, Offset(w * 0.31f, h * 0.7f))
}

private fun DrawScope.face(w: Float, h: Float, mood: Mood, blink: Boolean) {
    val ink = Color(0xFF2A2030)
    val eyeY = h * 0.6f
    val lx = w * 0.4f
    val rx = w * 0.6f
    val er = w * 0.045f
    val stroke = Stroke(width = w * 0.028f, cap = StrokeCap.Round)
    // mofletes
    drawOval(Color(0xFFFF7FA0).copy(alpha = 0.45f), Offset(w * 0.25f, h * 0.66f), Size(w * 0.1f, h * 0.05f))
    drawOval(Color(0xFFFF7FA0).copy(alpha = 0.45f), Offset(w * 0.65f, h * 0.66f), Size(w * 0.1f, h * 0.05f))
    fun closedEye(x: Float, happy: Boolean = true) {
        val p = Path().apply {
            moveTo(x - er, eyeY)
            if (happy) quadraticTo(x, eyeY - er * 1.6f, x + er, eyeY) else quadraticTo(x, eyeY + er * 1.2f, x + er, eyeY)
        }
        drawPath(p, ink, style = stroke)
    }
    fun openEye(x: Float, r: Float = er) {
        drawCircle(ink, r, Offset(x, eyeY))
        drawCircle(Color.White, r * 0.38f, Offset(x - r * 0.3f, eyeY - r * 0.35f))
    }
    fun heart(x: Float) {
        val s = er * 1.3f
        val p = Path().apply {
            moveTo(x, eyeY + s * 0.8f)
            cubicTo(x - s * 1.6f, eyeY - s * 0.2f, x - s * 0.6f, eyeY - s * 1.3f, x, eyeY - s * 0.3f)
            cubicTo(x + s * 0.6f, eyeY - s * 1.3f, x + s * 1.6f, eyeY - s * 0.2f, x, eyeY + s * 0.8f)
            close()
        }
        drawPath(p, Color(0xFFFF4F7B))
    }
    when {
        mood == Mood.LOVE -> { heart(lx); heart(rx) }
        blink || mood == Mood.SLEEPY -> { closedEye(lx, mood != Mood.SLEEPY); closedEye(rx, mood != Mood.SLEEPY) }
        mood == Mood.WINK -> { closedEye(lx); openEye(rx) }
        mood == Mood.WOW -> { openEye(lx, er * 1.2f); openEye(rx, er * 1.2f) }
        else -> { openEye(lx); openEye(rx) }
    }
    val my = h * 0.72f
    when (mood) {
        Mood.WOW -> drawOval(ink, Offset(w * 0.465f, my - h * 0.01f), Size(w * 0.07f, h * 0.06f))
        Mood.SAD -> drawPath(Path().apply { moveTo(w * 0.45f, my + h * 0.02f); quadraticTo(w * 0.5f, my - h * 0.025f, w * 0.55f, my + h * 0.02f) }, ink, style = stroke)
        Mood.SLEEPY -> drawLine(ink, Offset(w * 0.47f, my), Offset(w * 0.53f, my), stroke.width, StrokeCap.Round)
        else -> drawPath(Path().apply { moveTo(w * 0.44f, my - h * 0.005f); quadraticTo(w * 0.5f, my + h * 0.05f, w * 0.56f, my - h * 0.005f) }, ink, style = stroke)
    }
    if (mood == Mood.SLEEPY) {
        // zzz
        drawLine(ink.copy(alpha = 0.6f), Offset(w * 0.76f, h * 0.3f), Offset(w * 0.84f, h * 0.3f), stroke.width * 0.7f, StrokeCap.Round)
        drawLine(ink.copy(alpha = 0.6f), Offset(w * 0.84f, h * 0.3f), Offset(w * 0.76f, h * 0.38f), stroke.width * 0.7f, StrokeCap.Round)
        drawLine(ink.copy(alpha = 0.6f), Offset(w * 0.76f, h * 0.38f), Offset(w * 0.84f, h * 0.38f), stroke.width * 0.7f, StrokeCap.Round)
    }
    @Suppress("UNUSED_VARIABLE") val unused = PI
}

/** el complemento, dibujado encima de la gota */
private fun DrawScope.accessory(w: Float, h: Float, hat: String) {
    val ink = Color(0xFF2A2030)
    when (hat) {
        "gorro" -> {
            // gorro de lana con pompón
            val p = Path().apply {
                moveTo(w * 0.3f, h * 0.3f)
                cubicTo(w * 0.32f, h * 0.02f, w * 0.68f, h * 0.02f, w * 0.7f, h * 0.3f)
                close()
            }
            drawPath(p, Color(0xFFFF8FA3))
            drawRoundRect(Color(0xFFFFD1DA), Offset(w * 0.27f, h * 0.27f), Size(w * 0.46f, h * 0.08f), androidx.compose.ui.geometry.CornerRadius(w * 0.04f))
            drawCircle(Color.White, w * 0.06f, Offset(w * 0.5f, h * 0.06f))
        }
        "gafas" -> {
            val st = Stroke(width = w * 0.022f)
            drawCircle(ink, w * 0.085f, Offset(w * 0.4f, h * 0.6f), style = st)
            drawCircle(ink, w * 0.085f, Offset(w * 0.6f, h * 0.6f), style = st)
            drawLine(ink, Offset(w * 0.485f, h * 0.6f), Offset(w * 0.515f, h * 0.6f), st.width)
            drawCircle(Color.White.copy(alpha = 0.25f), w * 0.07f, Offset(w * 0.4f, h * 0.6f))
            drawCircle(Color.White.copy(alpha = 0.25f), w * 0.07f, Offset(w * 0.6f, h * 0.6f))
        }
        "lazo" -> {
            val c = Color(0xFFFF6B9A)
            val l = Path().apply { moveTo(w * 0.5f, h * 0.2f); lineTo(w * 0.36f, h * 0.12f); lineTo(w * 0.37f, h * 0.3f); close() }
            val r = Path().apply { moveTo(w * 0.5f, h * 0.2f); lineTo(w * 0.64f, h * 0.12f); lineTo(w * 0.63f, h * 0.3f); close() }
            drawPath(l, c); drawPath(r, c)
            drawCircle(Color(0xFFFF3D7F), w * 0.035f, Offset(w * 0.5f, h * 0.2f))
        }
        "corona" -> {
            val gold = Color(0xFFFFC94D)
            val p = Path().apply {
                moveTo(w * 0.34f, h * 0.24f); lineTo(w * 0.34f, h * 0.1f); lineTo(w * 0.42f, h * 0.17f)
                lineTo(w * 0.5f, h * 0.05f); lineTo(w * 0.58f, h * 0.17f); lineTo(w * 0.66f, h * 0.1f); lineTo(w * 0.66f, h * 0.24f); close()
            }
            drawPath(p, gold)
            drawCircle(Color(0xFFFF6B6B), w * 0.022f, Offset(w * 0.5f, h * 0.17f))
        }
        "auriculares" -> {
            val c = Color(0xFF8FC8FF)
            drawArc(c, 200f, 140f, false, Offset(w * 0.18f, h * 0.22f), Size(w * 0.64f, h * 0.6f), style = Stroke(width = w * 0.04f))
            drawRoundRect(c, Offset(w * 0.11f, h * 0.48f), Size(w * 0.1f, h * 0.18f), androidx.compose.ui.geometry.CornerRadius(w * 0.05f))
            drawRoundRect(c, Offset(w * 0.79f, h * 0.48f), Size(w * 0.1f, h * 0.18f), androidx.compose.ui.geometry.CornerRadius(w * 0.05f))
        }
        "flor" -> {
            val center = Offset(w * 0.68f, h * 0.36f)
            repeat(5) { i ->
                val a = i * 72.0 * kotlin.math.PI / 180
                drawCircle(Color(0xFFFFB3C7), w * 0.045f, Offset(center.x + (kotlin.math.cos(a) * w * 0.05f).toFloat(), center.y + (kotlin.math.sin(a) * w * 0.05f).toFloat()))
            }
            drawCircle(Color(0xFFFFD166), w * 0.03f, center)
        }
    }
}
