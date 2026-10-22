package es.david.caudal.ui.lock

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Backspace
import androidx.compose.material.icons.filled.Fingerprint
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import es.david.caudal.R
import es.david.caudal.ui.common.pressable
import es.david.caudal.ui.common.rememberHaptics
import es.david.caudal.ui.theme.CaudalTheme
import es.david.caudal.ui.theme.LocalMotion

/** puntos del PIN que se rellenan; `shake` cambia para que tiemblen al fallar */
@Composable
fun PinDots(filled: Int, total: Int, shake: Int) {
    val c = CaudalTheme.colors
    val motion = LocalMotion.current
    val dx = remember { Animatable(0f) }
    LaunchedEffect(shake) {
        if (shake > 0 && motion) for (x in listOf(18f, -16f, 12f, -8f, 4f, 0f)) dx.animateTo(x, tween(45))
    }
    val desc = stringResource(R.string.f4_pin_dots, filled, total)
    Row(
        Modifier.graphicsLayer { translationX = dx.value }.clearAndSetSemantics { contentDescription = desc; liveRegion = LiveRegionMode.Polite },
        horizontalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        repeat(total) { i ->
            val on = i < filled
            val sc by animateFloatAsState(if (on) 1.15f else 1f, spring(dampingRatio = 0.4f, stiffness = Spring.StiffnessMedium), label = "punto")
            val col by animateColorAsState(if (on) c.accent else c.cardAlt, label = "relleno")
            Box(Modifier.size(16.dp).graphicsLayer { scaleX = sc; scaleY = sc }.clip(CircleShape).background(col).border(1.5.dp, c.accent.copy(alpha = 0.6f), CircleShape))
        }
    }
}

/** teclado numérico redondo; `onBiometric` añade el botón de huella abajo a la izquierda */
@Composable
fun PinPad(onDigit: (Char) -> Unit, onDelete: () -> Unit, onBiometric: (() -> Unit)? = null) {
    val c = CaudalTheme.colors
    val h = rememberHaptics()
    val rows = listOf("123", "456", "789")
    Column(verticalArrangement = Arrangement.spacedBy(14.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        rows.forEach { r ->
            Row(horizontalArrangement = Arrangement.spacedBy(22.dp)) { r.forEach { d -> Key(d.toString(), stringResource(R.string.f4_pin_digit, d.toString())) { h.tap(); onDigit(d) } } }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(22.dp), verticalAlignment = Alignment.CenterVertically) {
            if (onBiometric != null) {
                val d = stringResource(R.string.f4_pin_biometric)
                Box(Modifier.size(76.dp).clip(CircleShape).pressable(0.88f) { h.tap(); onBiometric() }.semantics { contentDescription = d }, contentAlignment = Alignment.Center) {
                    Icon(Icons.Filled.Fingerprint, null, tint = c.accent, modifier = Modifier.size(34.dp))
                }
            } else Spacer(Modifier.width(76.dp))
            Key("0", stringResource(R.string.f4_pin_digit, "0")) { h.tap(); onDigit('0') }
            val del = stringResource(R.string.f4_pin_delete)
            Box(Modifier.size(76.dp).clip(CircleShape).pressable(0.88f) { h.select(); onDelete() }.semantics { contentDescription = del }, contentAlignment = Alignment.Center) {
                Icon(Icons.AutoMirrored.Filled.Backspace, null, tint = c.textDim, modifier = Modifier.size(28.dp))
            }
        }
    }
}

@Composable
private fun Key(label: String, desc: String, onClick: () -> Unit) {
    val c = CaudalTheme.colors
    Box(
        Modifier.size(76.dp).clip(CircleShape).pressable(0.88f, onClick = onClick).background(c.card).border(1.dp, c.hairline, CircleShape)
            .semantics { contentDescription = desc },
        contentAlignment = Alignment.Center,
    ) { Text(label, style = MaterialTheme.typography.headlineMedium, color = c.text) }
}
