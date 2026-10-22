package es.david.caudal.ui.theme

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.IndicationNodeFactory
import androidx.compose.foundation.interaction.InteractionSource
import androidx.compose.foundation.interaction.PressInteraction
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.isSpecified
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.ContentDrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.node.DelegatableNode
import androidx.compose.ui.node.DrawModifierNode
import androidx.compose.ui.node.invalidateDraw
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import dev.chrisbanes.haze.HazeState
import kotlinx.coroutines.launch
import kotlin.math.hypot
import kotlin.math.max

/** cómo se ven las tarjetas */
enum class CardStyle(val id: String) { CRISTAL("cristal"), SOLIDA("solida"), CONTORNO("contorno");
    companion object { fun of(id: String) = entries.firstOrNull { it.id == id } ?: CRISTAL } }

/** fondo de las pantallas */
enum class BackdropStyle(val id: String) { AGUA("agua"), BRILLO("brillo"), LISO("liso"), PUNTOS("puntos");
    companion object { fun of(id: String) = entries.firstOrNull { it.id == id } ?: AGUA } }

/** estilo elegido en Personalizar, para todos los componentes */
@Immutable
data class UiStyle(
    val card: CardStyle = CardStyle.CRISTAL,
    val backdrop: BackdropStyle = BackdropStyle.AGUA,
    /** multiplicador de las esquinas (0,6 suaves, 1 redondas, 1,35 muy redondas) */
    val corner: Float = 1f,
    /** multiplicador de márgenes (0,8 compacta) */
    val space: Float = 1f,
    val hideCents: Boolean = false,
    val sounds: Boolean = true,
    /** contenido detrás de la barra de abajo, para el cristal esmerilado */
    val haze: HazeState? = null,
) {
    fun r(base: Dp): Dp = base * corner
    fun s(base: Dp): Dp = base * space

    companion object {
        fun from(cardStyle: String, backdrop: String, corners: String, density: String, hideCents: Boolean, sounds: Boolean, haze: HazeState?) = UiStyle(
            card = CardStyle.of(cardStyle),
            backdrop = BackdropStyle.of(backdrop),
            corner = when (corners) { "suaves" -> 0.6f; "muy" -> 1.35f; else -> 1f },
            space = if (density == "compacta") 0.8f else 1f,
            hideCents = hideCents,
            sounds = sounds,
            haze = haze,
        )
    }
}

val LocalUiStyle = staticCompositionLocalOf { UiStyle() }

/**
 * Onda de agua al tocar: dos anillos que se abren desde el dedo y una mancha suave.
 * Sustituye al «ripple» de Material en toda la app.
 */
class WaterRipple(private val color: Color, private val motion: Boolean) : IndicationNodeFactory {
    override fun create(interactionSource: InteractionSource): DelegatableNode = WaterRippleNode(interactionSource, color, motion)
    override fun equals(other: Any?) = other is WaterRipple && other.color == color && other.motion == motion
    override fun hashCode() = color.hashCode() * 31 + motion.hashCode()
}

private class WaterRippleNode(
    private val source: InteractionSource,
    private val color: Color,
    private val motion: Boolean,
) : Modifier.Node(), DrawModifierNode {
    private val progress = Animatable(1f)
    private val pressed = Animatable(0f)
    private var center = Offset.Unspecified

    override fun onAttach() {
        coroutineScope.launch {
            source.interactions.collect { i ->
                when (i) {
                    is PressInteraction.Press -> {
                        center = i.pressPosition
                        launch { pressed.animateTo(1f, tween(120)) }
                        if (motion) launch { progress.snapTo(0f); progress.animateTo(1f, tween(650, easing = FastOutSlowInEasing)) }
                        invalidateDraw()
                    }
                    is PressInteraction.Release, is PressInteraction.Cancel -> launch { pressed.animateTo(0f, tween(260)) }
                }
            }
        }
        coroutineScope.launch { snapshotFlowDraw() }
    }

    private suspend fun snapshotFlowDraw() {
        androidx.compose.runtime.snapshotFlow { progress.value + pressed.value }.collect { invalidateDraw() }
    }

    override fun ContentDrawScope.draw() {
        drawContent()
        val c = if (center.isSpecified) center else Offset(size.width / 2, size.height / 2)
        if (pressed.value > 0f) drawRect(color.copy(alpha = 0.08f * pressed.value))
        val p = progress.value
        if (p < 1f) {
            val maxR = max(hypot(c.x, c.y), hypot(size.width - c.x, size.height - c.y))
            val a = (1f - p)
            drawCircle(color.copy(alpha = 0.18f * a), radius = maxR * p, center = c)
            drawCircle(color.copy(alpha = 0.35f * a), radius = maxR * p * 0.7f, center = c, style = Stroke(width = 2.dp.toPx()))
            drawCircle(color.copy(alpha = 0.25f * a), radius = maxR * p * 0.4f, center = c, style = Stroke(width = 1.5.dp.toPx()))
        }
    }
}
