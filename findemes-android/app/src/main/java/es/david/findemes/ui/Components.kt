package es.david.findemes.ui

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.graphics.FilterQuality
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import es.david.findemes.support.Fonts
import es.david.findemes.support.Ink
import es.david.findemes.support.a

// MARK: - Letras (en puntos, como en el iPhone: no crecen con el tamaño de letra del sistema)

object Pt { var fontScale = 1f; var density = 3f }
fun pts(v: Double): TextUnit = (v / Pt.fontScale).sp
fun chunky(size: Double, color: Color = Color.Unspecified) = TextStyle(fontFamily = Fonts.chunky, fontSize = pts(size), color = color)
fun typewriter(size: Double, bold: Boolean = false, color: Color = Color.Unspecified) =
    TextStyle(fontFamily = Fonts.typewriter, fontWeight = if (bold) FontWeight.Bold else FontWeight.Normal, fontSize = pts(size), color = color)

/** texto que se encoge para caber en una línea (como minimumScaleFactor) y que pasa por el animal de ahora */
@Composable
fun T(text: String, style: TextStyle, modifier: Modifier = Modifier, color: Color = Color.Unspecified, maxLines: Int = Int.MAX_VALUE, minScale: Float = 1f, align: TextAlign? = null) {
    var scale by remember(text, style) { mutableFloatStateOf(1f) }
    val st = if (scale < 1f) style.copy(fontSize = style.fontSize * scale) else style
    androidx.compose.material3.Text(
        text.a.replace('\u2009', ' '), modifier, color = if (color == Color.Unspecified) (if (style.color == Color.Unspecified) Ink.ink else style.color) else color,
        style = st, maxLines = maxLines, softWrap = maxLines > 1, textAlign = align,
        overflow = TextOverflow.Ellipsis,
        onTextLayout = { r: TextLayoutResult ->
            if (minScale < 1f && (r.didOverflowWidth || (maxLines > 1 && r.didOverflowHeight) || (maxLines == 1 && r.isLineEllipsized(0))) && scale > minScale) scale = maxOf(minScale, scale * 0.92f)
        },
    )
}

/** sombra dura en el texto (como .shadow(radius: 0)) */
fun TextStyle.hardShadow(dx: Double, dy: Double, color: Color = Ink.ink) = copy(shadow = androidx.compose.ui.graphics.Shadow(color, Offset(dx.toFloat() * Pt.density, dy.toFloat() * Pt.density), 0.1f))

// MARK: - Piezas de estilo: papel, bordes gordos y sombras duras (sin desenfoques ni brillos)

/** tarjeta de papel con borde de tinta y sombra dura */
fun Modifier.paper(color: Color = Ink.paper, tilt: Double = 0.0, shadow: Double = 5.0): Modifier = this
    .rotate(tilt.toFloat())
    .drawBehind {
        val s = shadow.dp.toPx()
        drawRect(Ink.ink, topLeft = Offset(s * 0.6f, s), size = size)
        drawRect(color)
        val lw = 2.5.dp.toPx()
        drawRect(Ink.ink, topLeft = Offset(lw / 2, lw / 2), size = Size(size.width - lw, size.height - lw), style = Stroke(lw))
    }

fun Modifier.outlined(radius: Double = 12.0, color: Color, line: Double = 2.5, shadow: Double = 4.0): Modifier = this.drawBehind {
    val r = CornerRadius(radius.dp.toPx())
    val s = shadow.dp.toPx()
    drawRoundRect(Ink.ink, topLeft = Offset(0f, s), size = size, cornerRadius = r)
    drawRoundRect(color, cornerRadius = r)
    val lw = line.dp.toPx()
    drawRoundRect(Ink.ink, topLeft = Offset(lw / 2, lw / 2), size = Size(size.width - lw, size.height - lw), cornerRadius = CornerRadius(r.x - lw / 2), style = Stroke(lw))
}

/** botón gordo que se hunde de verdad al pulsarlo (la sombra desaparece) */
@Composable
fun ChunkyButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    color: Color = Ink.gold,
    text: Color = Ink.ink,
    size: Double = 20.0,
    radius: Double = 14.0,
    enabled: Boolean = true,
    padH: Double = 16.0,
    padV: Double = 11.0,
    content: @Composable RowScope.(TextStyle) -> Unit,
) {
    val src = remember { MutableInteractionSource() }
    val down by src.collectIsPressedAsState()
    val off by animateDpAsState(if (down && enabled) 5.dp else 0.dp, spring(dampingRatio = 0.6f, stiffness = Spring.StiffnessHigh), label = "press")
    val style = chunky(size, if (enabled) text else Ink.soft)
    Box(modifier
        .drawBehind {
            val r = CornerRadius(radius.dp.toPx())
            drawRoundRect(Ink.ink, topLeft = Offset(0f, 5.dp.toPx()), size = this.size, cornerRadius = r)
        }
        .clickable(interactionSource = src, indication = null, enabled = enabled, onClick = onClick)) {
        Row(
            Modifier
                .offset(y = off)
                .drawBehind {
                    val r = CornerRadius(radius.dp.toPx())
                    drawRoundRect(if (enabled) color else Ink.paperDark, cornerRadius = r)
                    val lw = 3.dp.toPx()
                    drawRoundRect(Ink.ink, topLeft = Offset(lw / 2, lw / 2), size = Size(this.size.width - lw, this.size.height - lw), cornerRadius = CornerRadius(r.x - lw / 2), style = Stroke(lw))
                }
                .padding(horizontal = padH.dp, vertical = padV.dp),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically,
        ) { content(style) }
    }
}

/** botón con texto (lo más común) */
@Composable
fun ChunkyText(label: String, onClick: () -> Unit, modifier: Modifier = Modifier, color: Color = Ink.gold, text: Color = Ink.ink, size: Double = 20.0, radius: Double = 14.0, enabled: Boolean = true, fill: Boolean = false) {
    ChunkyButton(onClick, modifier, color, text, size, radius, enabled) { st ->
        T(label, st, if (fill) Modifier.weight(1f) else Modifier, maxLines = 1, minScale = 0.5f, align = TextAlign.Center)
    }
}

/** sello de goma (PAGADO, VENCIDA…) */
@Composable
fun Stamp(text: String, color: Color = Ink.red, modifier: Modifier = Modifier) {
    Box(modifier.rotate(-12f).alpha(0.88f).border(3.dp, color, RoundedCornerShape(4.dp)).padding(horizontal = 10.dp, vertical = 3.dp)) {
        T(text, typewriter(18.0, true), color = color, maxLines = 1)
    }
}

/** fondo de la cocina: azulejos */
@Composable
fun KitchenBackground() {
    Canvas(Modifier.fillMaxSize()) {
        drawRect(Ink.tile)
        val s = 46.dp.toPx()
        var y = 0f
        var row = 0
        val c = Ink.kitchen.copy(alpha = 0.35f)
        while (y < size.height) {
            var x = if (row % 2 == 0) 0f else -s / 2
            while (x < size.width) {
                drawRoundRect(c, Offset(x + 2.dp.toPx(), y + 2.dp.toPx()), Size(s - 4.dp.toPx(), s - 4.dp.toPx()), CornerRadius(4.dp.toPx()))
                x += s
            }
            y += s; row += 1
        }
    }
}

/** barra de vida / aguante con borde de tinta */
@Composable
fun InkBar(value: Double, color: Color, height: Double = 14.0, modifier: Modifier = Modifier) {
    Canvas(modifier.fillMaxWidth().height(height.dp)) {
        val r = CornerRadius(size.height / 2)
        drawRoundRect(Ink.paperDark, cornerRadius = r)
        val w = size.width * value.coerceIn(0.0, 1.0).toFloat()
        if (w > 0) drawRoundRect(color, size = Size(w, size.height), cornerRadius = r)
        val lw = 2.5.dp.toPx()
        drawRoundRect(Ink.ink, Offset(lw / 2, lw / 2), Size(size.width - lw, size.height - lw), CornerRadius(r.x - lw / 2), style = Stroke(lw))
    }
}

/** un icono (equivalente de SF Symbol) */
@Composable
fun SymIcon(name: String, size: Double, color: Color, modifier: Modifier = Modifier) {
    if (name == "eurosign.circle.fill") {
        Box(modifier.size(size.dp).clip(CircleShape).background(color), contentAlignment = Alignment.Center) {
            T("€", TextStyle(fontWeight = FontWeight.Black, fontSize = pts(size * 0.68)), color = if (color.luminance() < 0.3f) Ink.paper else Ink.ink, maxLines = 1)
        }
    } else Icon(Sym.of(name), null, modifier.size(size.dp), tint = color)
}

/** el personaje en pequeño (para botones) */
@Composable
fun SkinIcon(id: String, size: Double, look: String = "normal", modifier: Modifier = Modifier) {
    val b = Assets.skin(id, look)
    if (b != null) {
        Image(remember(b) { b.asImageBitmap() }, null, modifier.size(size.dp), filterQuality = FilterQuality.High)
    } else Spacer(modifier.size(size.dp))
}

/** una imagen de objeto (martillo, joya, moneda…) */
@Composable
fun ItemImage(name: String, modifier: Modifier = Modifier, ext: String = "png") {
    val b = Assets.item(name, ext) ?: return
    Image(remember(b) { b.asImageBitmap() }, null, modifier, filterQuality = FilterQuality.High)
}

// MARK: - Hojas que suben desde abajo (como las del iPhone)

@Composable
fun SheetHost(visible: Boolean, onDismiss: () -> Unit, background: Color = Ink.wood, content: @Composable BoxScope.() -> Unit) {
    AnimatedVisibility(visible, enter = fadeIn(), exit = fadeOut()) {
        Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.35f)).clickable(remember { MutableInteractionSource() }, null) { onDismiss() })
    }
    AnimatedVisibility(visible, enter = slideInVertically(spring(dampingRatio = 0.9f, stiffness = 400f)) { it }, exit = slideOutVertically { it }) {
        BackHandler { onDismiss() }
        Box(Modifier.fillMaxSize().statusBarsPadding().padding(top = 10.dp)
            .clip(RoundedCornerShape(topStart = 38.dp, topEnd = 38.dp))
            .background(background)
            .clickable(remember { MutableInteractionSource() }, null) { }, content = content)
    }
}

/** menú de opciones abajo (como confirmationDialog del iPhone) */
class DialogAction(val label: String, val destructive: Boolean = false, val action: () -> Unit)

@Composable
fun ActionDialog(visible: Boolean, title: String, message: String? = null, actions: List<DialogAction>, cancel: String = "Cancelar", onDismiss: () -> Unit) {
    AnimatedVisibility(visible, enter = fadeIn(), exit = fadeOut()) {
        BackHandler { onDismiss() }
        Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.3f)).clickable(remember { MutableInteractionSource() }, null) { onDismiss() }, contentAlignment = Alignment.BottomCenter) {
            Column(Modifier.navigationBarsPadding().padding(10.dp)) {
                Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(Color(0xF2F2F2F2.toInt()))) {
                    Column(Modifier.fillMaxWidth().padding(14.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                        androidx.compose.material3.Text(title.a, style = TextStyle(fontSize = pts(13.0), fontWeight = FontWeight.SemiBold, color = Color(0xFF8A8A8E), textAlign = TextAlign.Center))
                        if (message != null) androidx.compose.material3.Text(message.a, style = TextStyle(fontSize = pts(13.0), color = Color(0xFF8A8A8E), textAlign = TextAlign.Center))
                    }
                    for (a in actions) {
                        Box(Modifier.fillMaxWidth().height(0.5.dp).background(Color(0x33000000)))
                        Box(Modifier.fillMaxWidth().clickable { onDismiss(); a.action() }.padding(vertical = 16.dp), contentAlignment = Alignment.Center) {
                            androidx.compose.material3.Text(a.label.a, style = TextStyle(fontSize = pts(19.0), color = if (a.destructive) Color(0xFFFF3B30) else Color(0xFF007AFF)))
                        }
                    }
                }
                Spacer(Modifier.height(8.dp))
                Box(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(Color.White).clickable { onDismiss() }.padding(vertical = 16.dp), contentAlignment = Alignment.Center) {
                    androidx.compose.material3.Text(cancel, style = TextStyle(fontSize = pts(19.0), fontWeight = FontWeight.SemiBold, color = Color(0xFF007AFF)))
                }
            }
        }
    }
}

/** cuadro de confirmación centrado (como .alert del iPhone) */
@Composable
fun AlertDialog(visible: Boolean, title: String, message: String?, actions: List<DialogAction>, cancel: String = "Cancelar", onDismiss: () -> Unit) {
    AnimatedVisibility(visible, enter = fadeIn(), exit = fadeOut()) {
        BackHandler { onDismiss() }
        Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.3f)).clickable(remember { MutableInteractionSource() }, null) { }, contentAlignment = Alignment.Center) {
            Column(Modifier.width(270.dp).clip(RoundedCornerShape(14.dp)).background(Color(0xF7F7F7F7.toInt()))) {
                Column(Modifier.fillMaxWidth().padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    androidx.compose.material3.Text(title.a, style = TextStyle(fontSize = pts(17.0), fontWeight = FontWeight.SemiBold, color = Color.Black, textAlign = TextAlign.Center))
                    if (message != null) androidx.compose.material3.Text(message.a, style = TextStyle(fontSize = pts(13.0), color = Color.Black, textAlign = TextAlign.Center), modifier = Modifier.padding(top = 4.dp))
                }
                Box(Modifier.fillMaxWidth().height(0.5.dp).background(Color(0x33000000)))
                for (a in actions) {
                    Box(Modifier.fillMaxWidth().clickable { onDismiss(); a.action() }.padding(vertical = 12.dp), contentAlignment = Alignment.Center) {
                        androidx.compose.material3.Text(a.label.a, style = TextStyle(fontSize = pts(17.0), color = if (a.destructive) Color(0xFFFF3B30) else Color(0xFF007AFF)))
                    }
                    Box(Modifier.fillMaxWidth().height(0.5.dp).background(Color(0x33000000)))
                }
                Box(Modifier.fillMaxWidth().clickable { onDismiss() }.padding(vertical = 12.dp), contentAlignment = Alignment.Center) {
                    androidx.compose.material3.Text(cancel, style = TextStyle(fontSize = pts(17.0), fontWeight = FontWeight.SemiBold, color = Color(0xFF007AFF)))
                }
            }
        }
    }
}

/** capa oscura con una tarjeta en medio (avisos, celebraciones…) */
@Composable
fun Overlay(dim: Double = 0.5, onTap: (() -> Unit)? = null, content: @Composable BoxScope.() -> Unit) {
    Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = dim.toFloat()))
        .clickable(remember { MutableInteractionSource() }, null) { onTap?.invoke() }, contentAlignment = Alignment.Center, content = content)
}
