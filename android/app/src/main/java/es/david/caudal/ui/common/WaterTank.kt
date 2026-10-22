package es.david.caudal.ui.common

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import es.david.caudal.ui.theme.LocalMotion
import kotlinx.coroutines.launch
import kotlin.math.PI
import kotlin.math.sin

/**
 * El depósito de agua: el nivel es lo que te queda (0..1). Al aparecer se llena hasta su nivel con olas,
 * al tocarlo salpica; luego se calma (sin animación continua). Gotita flota en la superficie si `mascot`.
 */
@Composable
fun WaterTank(
    level: Float,
    color: Color,
    modifier: Modifier = Modifier,
    mascot: Mood? = Mood.HAPPY,
    description: String = "",
    content: @Composable BoxScope.() -> Unit = {},
) {
    val motion = LocalMotion.current
    val shown = remember { Animatable(if (motion) 0f else level.coerceIn(0f, 1f)) }
    // energía de las olas: alta al llenarse o al tocar, y se va calmando
    val energy = remember { Animatable(if (motion) 1f else 0.15f) }
    var t by remember { mutableStateOf(0f) }
    var pokes by remember { mutableIntStateOf(0) }
    val scope = rememberCoroutineScope()
    LaunchedEffect(level) { shown.animateTo(level.coerceIn(0f, 1f), spring(dampingRatio = 0.55f, stiffness = Spring.StiffnessVeryLow)) }
    LaunchedEffect(pokes, motion) {
        if (!motion) return@LaunchedEffect
        launch { energy.snapTo(1f); energy.animateTo(0.15f, tween(4500, easing = FastOutSlowInEasing)) }
        val start = withFrameNanos { it }
        var now = start
        while (now - start < 4_600_000_000L) withFrameNanos { n -> now = n; t = (n - start) / 1_000_000_000f }
    }
    var size by remember { mutableStateOf(IntSize.Zero) }
    val density = LocalDensity.current
    Box(
        modifier
            .onSizeChanged { size = it }
            .pressable(0.98f, role = null) { pokes++ }
            .semantics { if (description.isNotEmpty()) contentDescription = description },
    ) {
        Canvas(Modifier.fillMaxSize()) {
            val w = this.size.width
            val h = this.size.height
            val surface = h * (1f - shown.value)
            val amp = h * 0.035f * energy.value + h * 0.008f
            fun wave(phase: Float, k: Float, a: Float): Path = Path().apply {
                moveTo(0f, h)
                lineTo(0f, surface)
                var x = 0f
                while (x <= w + 8f) {
                    lineTo(x, surface + a * sin(x / w * 2f * PI.toFloat() * k + phase))
                    x += 6f
                }
                lineTo(w, h)
                close()
            }
            drawPath(wave(-t * 2.4f + 1.2f, 1.3f, amp * 0.8f), lerp(color, Color.White, 0.25f).copy(alpha = 0.45f))
            drawPath(wave(t * 3f, 1f, amp), Brush.verticalGradient(listOf(lerp(color, Color.White, 0.15f), color, lerp(color, Color.Black, 0.18f)), startY = surface - amp, endY = h))
            // burbujitas
            if (shown.value > 0.08f) {
                listOf(0.18f to 0.7f, 0.42f to 0.45f, 0.77f to 0.62f, 0.6f to 0.85f).forEachIndexed { i, (bx, by) ->
                    val rise = ((t * 0.25f + i * 0.27f) % 1f)
                    val y = h - (h - surface) * ((by + rise) % 1f)
                    if (y > surface + 6f) drawCircle(Color.White.copy(alpha = 0.35f), (3 + i % 2 * 2).dp.toPx(), Offset(w * bx, y))
                }
            }
        }
        if (mascot != null && LocalMascot.current && size.height > 0) {
            val surfacePx = size.height * (1f - shown.value)
            val bob = sin(t * 2.6f) * 6f * energy.value
            val gotSize: Dp = 54.dp
            val gotPx = with(density) { gotSize.toPx() }
            val y = (surfacePx - gotPx * 0.72f + bob).coerceIn(0f, size.height - gotPx)
            Box(Modifier.align(Alignment.TopEnd).offset(x = (-18).dp, y = with(density) { y.toDp() })) {
                Gotita(mascot, gotSize)
            }
        }
        content()
    }
}
