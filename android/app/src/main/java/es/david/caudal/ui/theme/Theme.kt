package es.david.caudal.ui.theme

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import es.david.caudal.R
import es.david.caudal.domain.model.ThemeMode

/** colores propios de Caudal además de los de Material */
@Immutable
data class CaudalColors(
    val dark: Boolean,
    val accent: Color,
    val onAccent: Color,
    val income: Color,
    val negative: Color,
    val warning: Color,
    val transfer: Color,
    val expenseAccent: Color,
    /** fondo de la pantalla */
    val bg: Color,
    /** tarjetas */
    val card: Color,
    /** dentro de una tarjeta (cajitas, chips) */
    val cardAlt: Color,
    /** líneas finas */
    val hairline: Color,
    val text: Color,
    val textDim: Color,
)

val LocalCaudalColors = staticCompositionLocalOf {
    CaudalColors(true, Color(0xFFE4B3CB), Color.Black, Color(0xFF4AD68F), Color(0xFFFF6B6B), Color(0xFFFFA94D), Color(0xFF8FB4FF), Color(0xFFFF9F7A),
        Color(0xFF0E0D12), Color(0xFF1B1A21), Color(0xFF26252D), Color(0x1FFFFFFF), Color.White, Color(0xFFA6A3AE))
}

/** ¿animaciones y vibración activadas? (ajuste «Reducir movimiento» del sistema y de la app) */
val LocalMotion = staticCompositionLocalOf { true }

object CaudalTheme {
    val colors: CaudalColors @Composable get() = LocalCaudalColors.current
}

fun hexColor(hex: String, fallback: Color = Color(0xFFA9B3C2)): Color = runCatching {
    var s = hex.trim().removePrefix("#")
    if (s.length == 3) s = s.map { "$it$it" }.joinToString("")
    Color(("FF$s").toLong(16))
}.getOrDefault(fallback)

/** colores de acento para elegir (todos pastel) */
data class AccentPreset(val id: String, val hex: String, val name: Int)

val ACCENTS = listOf(
    AccentPreset("algodon", "#e4b3cb", R.string.accent_algodon),
    AccentPreset("cereza", "#ff8fa3", R.string.accent_cereza),
    AccentPreset("melocoton", "#ffb38a", R.string.accent_melocoton),
    AccentPreset("limon", "#f2d675", R.string.accent_limon),
    AccentPreset("menta", "#7eddb8", R.string.accent_menta),
    AccentPreset("cielo", "#8fc8ff", R.string.accent_cielo),
    AccentPreset("lavanda", "#b9a4ff", R.string.accent_lavanda),
    AccentPreset("chicle", "#f59fe0", R.string.accent_chicle),
)

// Nunito: letra redondeada (licencia OFL), con todos los grosores en un solo archivo
private fun nunito(w: Int) = Font(R.font.nunito, FontWeight(w), variationSettings = FontVariation.Settings(FontVariation.weight(w)))
val Nunito = FontFamily(nunito(400), nunito(500), nunito(600), nunito(700), nunito(800), nunito(900))

private fun t(size: Int, weight: Int, line: Int = (size * 1.3f).toInt(), spacing: Float = 0f) =
    TextStyle(fontFamily = Nunito, fontSize = size.sp, fontWeight = FontWeight(weight), lineHeight = line.sp, letterSpacing = spacing.sp)

val CaudalTypography = Typography(
    displayLarge = t(52, 900, 58, -1f),
    displayMedium = t(44, 900, 50, -0.8f),
    displaySmall = t(36, 800, 42, -0.5f),
    headlineLarge = t(32, 900, 38, -0.4f),
    headlineMedium = t(28, 800, 34, -0.3f),
    headlineSmall = t(24, 800, 30),
    titleLarge = t(21, 800, 26),
    titleMedium = t(17, 700, 22),
    titleSmall = t(15, 700, 20),
    bodyLarge = t(16, 600, 22),
    bodyMedium = t(14, 600, 19),
    bodySmall = t(12, 600, 16),
    labelLarge = t(14, 800, 18),
    labelMedium = t(12, 700, 16),
    labelSmall = t(11, 700, 14),
)

val CaudalShapes = Shapes(
    extraSmall = RoundedCornerShape(10.dp),
    small = RoundedCornerShape(14.dp),
    medium = RoundedCornerShape(20.dp),
    large = RoundedCornerShape(26.dp),
    extraLarge = RoundedCornerShape(32.dp),
)

@Composable
fun CaudalTheme(
    theme: ThemeMode,
    accent: String,
    dynamicColor: Boolean,
    amoled: Boolean = false,
    motion: Boolean = true,
    content: @Composable () -> Unit,
) {
    val dark = when (theme) {
        ThemeMode.SYSTEM -> isSystemInDarkTheme()
        ThemeMode.LIGHT -> false
        ThemeMode.DARK -> true
    }
    val dyn = dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
    val dynScheme = if (dyn) (if (dark) dynamicDarkColorScheme(LocalContext.current) else dynamicLightColorScheme(LocalContext.current)) else null
    val acc = dynScheme?.primary ?: hexColor(accent, Color(0xFFE4B3CB)).let { if (dark) it else lerp(it, Color.Black, 0.12f) }
    val onAcc = if (acc.luminance() > 0.42f) Color(0xFF1A1320) else Color.White

    // fondo con un toque del color de acento (o negro puro si AMOLED)
    val colors = if (dark) {
        val bg = if (amoled) Color.Black else lerp(Color(0xFF0D0C11), acc, 0.025f)
        val card = if (amoled) Color(0xFF121216) else lerp(Color(0xFF1A1920), acc, 0.04f)
        CaudalColors(
            true, acc, onAcc, Color(0xFF5FDB9B), Color(0xFFFF7A7A), Color(0xFFFFB25C), Color(0xFF94B8FF), Color(0xFFFFA184),
            bg, card, lerp(card, Color.White, 0.06f), Color.White.copy(alpha = 0.08f), Color(0xFFF7F5FA), Color(0xFFA7A3B0),
        )
    } else {
        val bg = lerp(Color(0xFFF6F4F8), acc, 0.06f)
        CaudalColors(
            false, acc, onAcc, Color(0xFF169A5A), Color(0xFFDB3D4E), Color(0xFFD9780F), Color(0xFF3B6FE0), Color(0xFFDB6A3E),
            bg, Color.White, lerp(Color(0xFFF3F1F6), acc, 0.08f), Color.Black.copy(alpha = 0.07f), Color(0xFF1C1822), Color(0xFF6E6877),
        )
    }
    val scheme: ColorScheme = (dynScheme ?: if (dark) darkColorScheme() else lightColorScheme()).copy(
        primary = acc, onPrimary = onAcc, primaryContainer = acc.copy(alpha = 0.22f), onPrimaryContainer = colors.text,
        secondary = acc, onSecondary = onAcc, secondaryContainer = colors.cardAlt, onSecondaryContainer = colors.text,
        tertiary = colors.income,
        background = colors.bg, onBackground = colors.text, surface = colors.bg, onSurface = colors.text,
        surfaceVariant = colors.card, onSurfaceVariant = colors.textDim,
        surfaceContainerLowest = colors.bg, surfaceContainerLow = colors.card, surfaceContainer = colors.card,
        surfaceContainerHigh = colors.cardAlt, surfaceContainerHighest = lerp(colors.cardAlt, colors.text, 0.06f),
        outline = colors.textDim.copy(alpha = 0.5f), outlineVariant = colors.hairline, error = colors.negative,
        inverseSurface = colors.text, inverseOnSurface = colors.bg,
    )
    CompositionLocalProvider(LocalCaudalColors provides colors, LocalMotion provides motion) {
        MaterialTheme(colorScheme = scheme, typography = CaudalTypography, shapes = CaudalShapes, content = content)
    }
}
