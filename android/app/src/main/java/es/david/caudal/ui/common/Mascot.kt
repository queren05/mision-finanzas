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

/** cómo está Gotita */
enum class Mood { HAPPY, WOW, SLEEPY, SAD, LOVE, WINK }

/**
 * Gotita: la mascota de Caudal, una gota de agua con cara. Flota, parpadea y cambia de cara según el momento
 * (contenta si ahorras, sorprendida al apuntar, triste si te pasas del presupuesto…).
 */
@Composable
fun Gotita(mood: Mood = Mood.HAPPY, size: Dp = 96.dp, color: Color = CaudalTheme.colors.accent, modifier: Modifier = Modifier, description: String = "") {
    val motion = LocalMotion.current
    var t by remember { mutableStateOf(0f) }
    LaunchedEffect(motion) {
        if (!motion) return@LaunchedEffect
        val start = withFrameNanos { it }
        while (true) withFrameNanos { now -> t = (now - start) / 1_000_000_000f }
    }
    Canvas(modifier.size(size).semantics { if (description.isNotEmpty()) contentDescription = description }) {
        val w = this.size.width
        val h = this.size.height
        val bob = if (motion) sin(t * 2.2f) * h * 0.025f else 0f
        // parpadeo: cerrado 0,12 s cada 3,6 s
        val blink = motion && (t % 3.6f) > 3.48f
        translate(top = bob) {
            drop(w, h, color)
            face(w, h, mood, blink)
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
