package es.david.caudal.ui.charts

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Línea con degradado; se puede tocar o arrastrar para ver cada punto (`onSelect` con el índice, null al soltar).
 * Gráficos dibujados a mano: sin librerías externas.
 */
@Composable
fun LineChart(
    values: List<Double>,
    color: Color,
    modifier: Modifier = Modifier,
    height: Dp = 140.dp,
    selected: Int? = null,
    description: String = "",
    onSelect: (Int?) -> Unit = {},
) {
    val progress = remember { Animatable(0f) }
    LaunchedEffect(values.size) { progress.animateTo(1f, tween(900)) }
    Canvas(
        modifier
            .fillMaxWidth()
            .height(height)
            .semantics { contentDescription = description }
            .pointerInput(values.size) {
                fun idx(x: Float) = if (values.size < 2) 0 else ((x / size.width) * (values.size - 1)).roundToInt().coerceIn(0, values.size - 1)
                // solo arrastres horizontales: así deslizar en vertical sigue moviendo la pantalla
                detectHorizontalDragGestures(
                    onDragStart = { onSelect(idx(it.x)) },
                    onDragEnd = { onSelect(null) },
                    onDragCancel = { onSelect(null) },
                ) { change, _ -> onSelect(idx(change.position.x)) }
            }
            .pointerInput(values.size) {
                detectTapGestures(onPress = {
                    if (values.size >= 2) onSelect(((it.x / size.width) * (values.size - 1)).roundToInt().coerceIn(0, values.size - 1))
                    tryAwaitRelease(); onSelect(null)
                })
            },
    ) {
        if (values.size < 2) return@Canvas
        val lo = values.min()
        val hi = values.max()
        val flat = hi - lo < 1e-9
        val span = if (flat) 1.0 else hi - lo
        val pad = 6.dp.toPx()
        // si no cambia, la línea va por el medio
        fun pt(i: Int) = Offset(
            i * size.width / (values.size - 1),
            if (flat) size.height / 2 else (pad + (1 - (values[i] - lo) / span) * (size.height - 2 * pad)).toFloat(),
        )
        val shownCount = max(2, (values.size * progress.value).roundToInt())
        val line = Path().apply {
            moveTo(pt(0).x, pt(0).y)
            for (i in 1 until shownCount) lineTo(pt(i).x, pt(i).y)
        }
        val area = Path().apply {
            addPath(line)
            lineTo(pt(shownCount - 1).x, size.height)
            lineTo(0f, size.height)
            close()
        }
        drawPath(area, Brush.verticalGradient(listOf(color.copy(alpha = 0.35f), color.copy(alpha = 0f))))
        drawPath(line, color, style = Stroke(width = 3.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round))
        selected?.let { i ->
            val p = pt(i.coerceIn(0, values.size - 1))
            drawLine(color.copy(alpha = 0.5f), Offset(p.x, 0f), Offset(p.x, size.height), 1.5.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(8f, 8f)))
            drawCircle(Color.White, 6.dp.toPx(), p)
            drawCircle(color, 4.dp.toPx(), p)
        }
    }
}

/** porciones del donut */
data class Slice(val value: Double, val color: Color)

@Composable
fun Donut(slices: List<Slice>, modifier: Modifier = Modifier, size: Dp = 180.dp, thickness: Dp = 26.dp, highlighted: Int? = null, description: String = "", onTap: (Int?) -> Unit = {}) {
    val progress = remember { Animatable(0f) }
    LaunchedEffect(slices.size) { progress.snapTo(0f); progress.animateTo(1f, tween(900)) }
    val total = slices.sumOf { it.value }.takeIf { it > 0 } ?: 1.0
    Canvas(
        modifier
            .size(size)
            .semantics { contentDescription = description }
            .pointerInput(slices) {
                detectTapGestures { o ->
                    val c = Offset(this.size.width / 2f, this.size.height / 2f)
                    var ang = Math.toDegrees(kotlin.math.atan2((o.y - c.y).toDouble(), (o.x - c.x).toDouble())) + 90
                    if (ang < 0) ang += 360
                    var acc = 0.0
                    var hit: Int? = null
                    slices.forEachIndexed { i, s -> val sweep = s.value / total * 360; if (hit == null && ang >= acc && ang < acc + sweep) hit = i; acc += sweep }
                    onTap(if (hit == highlighted) null else hit)
                }
            },
    ) {
        val stroke = thickness.toPx()
        val d = min(this.size.width, this.size.height) - stroke
        val topLeft = Offset((this.size.width - d) / 2, (this.size.height - d) / 2)
        var start = -90f
        val gap = if (slices.size > 1) 1.5f else 0f
        slices.forEachIndexed { i, s ->
            val sweep = (s.value / total * 360).toFloat() * progress.value
            val dim = highlighted != null && highlighted != i
            drawArc(
                s.color.copy(alpha = if (dim) 0.3f else 1f), start + gap / 2, max(0f, sweep - gap), false,
                topLeft, Size(d, d), style = Stroke(if (highlighted == i) stroke * 1.25f else stroke, cap = StrokeCap.Butt),
            )
            start += sweep
        }
    }
}

/** barras verticales (gastado por meses) */
@Composable
fun Bars(values: List<Double>, colors: List<Color>, modifier: Modifier = Modifier, height: Dp = 140.dp, description: String = "") {
    val progress = remember { Animatable(0f) }
    LaunchedEffect(values) { progress.snapTo(0f); progress.animateTo(1f, tween(800)) }
    Canvas(modifier.fillMaxWidth().height(height).semantics { contentDescription = description }) {
        if (values.isEmpty()) return@Canvas
        val hi = values.max().takeIf { it > 0 } ?: 1.0
        val slot = size.width / values.size
        val w = slot * 0.56f
        values.forEachIndexed { i, v ->
            val h = (v / hi * size.height * progress.value).toFloat().coerceAtLeast(if (v > 0) 3f else 0f)
            drawRoundRect(
                colors.getOrElse(i) { colors.last() },
                Offset(i * slot + (slot - w) / 2, size.height - h),
                Size(w, h),
                androidx.compose.ui.geometry.CornerRadius(8.dp.toPx(), 8.dp.toPx()),
            )
        }
    }
}
