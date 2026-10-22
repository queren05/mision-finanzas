package es.david.caudal.ui.common

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.material3.Text
import androidx.compose.material3.ripple
import es.david.caudal.ui.theme.LocalMotion
import kotlinx.coroutines.delay
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin
import kotlin.random.Random

/**
 * Se encoge un poco al pulsar y rebota al soltar (como los botones de iPhone).
 * Sustituye a `clickable`.
 */
fun Modifier.pressable(
    scale: Float = 0.96f,
    role: Role? = Role.Button,
    onLongClick: (() -> Unit)? = null,
    enabled: Boolean = true,
    onClick: () -> Unit,
): Modifier = composed {
    val source = remember { MutableInteractionSource() }
    val pressed by source.collectIsPressedAsState()
    val motion = LocalMotion.current
    val s by animateFloatAsState(
        if (pressed && motion) scale else 1f,
        spring(dampingRatio = 0.55f, stiffness = Spring.StiffnessMediumLow),
        label = "press",
    )
    this
        .graphicsLayer { scaleX = s; scaleY = s }
        .then(
            if (onLongClick != null) {
                Modifier.combinedClickable(source, ripple(), enabled = enabled, role = role, onLongClick = onLongClick, onClick = onClick)
            } else {
                Modifier.clickable(source, ripple(), enabled = enabled, role = role, onClick = onClick)
            },
        )
}

/**
 * Aparece desde abajo con un pequeño retraso según su posición (las tarjetas del inicio, filas…).
 * Solo la primera vez que se compone.
 */
fun Modifier.appear(index: Int = 0, distance: Float = 40f): Modifier = composed {
    val motion = LocalMotion.current
    val a = remember { Animatable(if (motion) 0f else 1f) }
    LaunchedEffect(Unit) {
        if (motion && a.value < 1f) {
            delay((index.coerceAtMost(8) * 45).toLong())
            a.animateTo(1f, spring(dampingRatio = 0.78f, stiffness = Spring.StiffnessLow))
        }
    }
    graphicsLayer {
        alpha = a.value.coerceIn(0f, 1f)
        translationY = (1f - a.value) * distance
        val sc = 0.96f + 0.04f * a.value
        scaleX = sc
        scaleY = sc
    }
}

/** un latido suave infinito (la mascota, el botón de apuntar vacío…) */
fun Modifier.breathe(amount: Float = 0.04f, periodMs: Int = 2400): Modifier = composed {
    val motion = LocalMotion.current
    var t by remember { mutableStateOf(0f) }
    LaunchedEffect(motion) {
        if (!motion) return@LaunchedEffect
        // late unos ciclos y se para (sin animaciones infinitas que gasten batería)
        val start = withFrameNanos { it }
        var now = start
        while ((now - start) / 1_000_000L < periodMs * 3L) withFrameNanos { n -> now = n; t = ((n - start) / 1_000_000f) / periodMs }
        t = 0f
    }
    graphicsLayer {
        val k = 1f + amount * sin(t * 2 * PI.toFloat())
        scaleX = k
        scaleY = k
    }
}

/**
 * Texto que cambia carácter a carácter rodando hacia arriba o hacia abajo (como los importes de iPhone).
 * `up`: si el número ha subido.
 */
@Composable
fun RollingText(text: String, style: TextStyle, color: Color = Color.Unspecified, weight: FontWeight? = null, modifier: Modifier = Modifier) {
    val motion = LocalMotion.current
    var prev by remember { mutableStateOf(text) }
    val up = (text.filter { it.isDigit() }.toLongOrNull() ?: 0L) >= (prev.filter { it.isDigit() }.toLongOrNull() ?: 0L)
    LaunchedEffect(text) { prev = text }
    if (!motion) {
        Text(text, style = style, color = color, fontWeight = weight, modifier = modifier, maxLines = 1)
        return
    }
    Row(modifier.clearAndSetSemantics { contentDescription = text }) {
        // se alinea por la derecha: así las cifras que no cambian no se mueven
        val chars = text.toList()
        chars.forEachIndexed { i, ch ->
            AnimatedContent(
                targetState = ch,
                transitionSpec = {
                    val dir = if (up) 1 else -1
                    (slideInVertically(spring(dampingRatio = 0.8f, stiffness = Spring.StiffnessMediumLow)) { it * dir } + fadeIn(tween(150)))
                        .togetherWith(slideOutVertically(spring(dampingRatio = 0.8f, stiffness = Spring.StiffnessMediumLow)) { -it * dir } + fadeOut(tween(120)))
                },
                label = "cifra$i",
            ) { c -> Text(c.toString(), style = style, color = color, fontWeight = weight, maxLines = 1) }
        }
    }
}

/** confeti al cumplir un objetivo o un presupuesto (se lanza al cambiar `key`) */
@Composable
fun Confetti(key: Any?, colors: List<Color>, modifier: Modifier = Modifier.fillMaxSize(), count: Int = 90) {
    val motion = LocalMotion.current
    if (key == null || !motion) return
    data class Bit(val x: Float, val vx: Float, val vy: Float, val rot: Float, val vr: Float, val c: Color, val w: Float, val h: Float)
    val bits = remember(key) {
        val r = Random(key.hashCode())
        List(count) {
            val ang = (r.nextFloat() * 0.8f + 0.1f) * PI.toFloat()
            val sp = 900f + r.nextFloat() * 900f
            Bit(0.5f + (r.nextFloat() - 0.5f) * 0.2f, cos(ang) * sp * 0.6f, -sin(ang) * sp, r.nextFloat() * 360f, (r.nextFloat() - 0.5f) * 720f,
                colors[it % colors.size], 7f + r.nextFloat() * 7f, 10f + r.nextFloat() * 10f)
        }
    }
    val time = remember(key) { Animatable(0f) }
    LaunchedEffect(key) { time.snapTo(0f); time.animateTo(2.6f, tween(2600)) }
    if (time.value >= 2.6f) return
    Canvas(modifier) {
        val t = time.value
        bits.forEach { b ->
            val x = b.x * size.width + b.vx * t
            val y = size.height * 0.55f + b.vy * t + 1400f * t * t
            if (y > size.height + 40) return@forEach
            rotate(b.rot + b.vr * t, Offset(x, y)) {
                drawRect(b.c.copy(alpha = (1f - (t / 2.6f)).coerceIn(0f, 1f)), Offset(x - b.w / 2, y - b.h / 2), Size(b.w, b.h))
            }
        }
    }
}
