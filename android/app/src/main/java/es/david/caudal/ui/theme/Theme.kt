package es.david.caudal.ui.theme

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import es.david.caudal.domain.model.ThemeMode

/** colores propios de Caudal además de los de Material */
@Immutable
data class CaudalColors(
    val income: Color,
    val negative: Color,
    val warning: Color,
    val card: Color,
    val cardAlt: Color,
    val transfer: Color,
    val expenseAccent: Color,
)

val LocalCaudalColors = staticCompositionLocalOf {
    CaudalColors(Color(0xFF4AD68F), Color(0xFFFF6B6B), Color(0xFFFFA94D), Color(0xFF1C1C1E), Color(0x0DFFFFFF), Color(0xFF8FB4FF), Color(0xFFFF9F7A))
}

object CaudalTheme {
    val colors: CaudalColors @Composable get() = LocalCaudalColors.current
}

fun hexColor(hex: String, fallback: Color = Color(0xFFA9B3C2)): Color = runCatching {
    var s = hex.trim().removePrefix("#")
    if (s.length == 3) s = s.map { "$it$it" }.joinToString("")
    Color(("FF$s").toLong(16))
}.getOrDefault(fallback)

private val typography = Typography().run {
    copy(
        displaySmall = displaySmall.copy(fontWeight = FontWeight.Bold),
        headlineMedium = headlineMedium.copy(fontWeight = FontWeight.Bold),
        headlineSmall = headlineSmall.copy(fontWeight = FontWeight.Bold),
        titleLarge = titleLarge.copy(fontWeight = FontWeight.Bold),
        titleMedium = titleMedium.copy(fontWeight = FontWeight.SemiBold, fontSize = 17.sp),
    )
}

@Composable
fun CaudalTheme(theme: ThemeMode, accent: String, dynamicColor: Boolean, content: @Composable () -> Unit) {
    val dark = when (theme) {
        ThemeMode.SYSTEM -> isSystemInDarkTheme()
        ThemeMode.LIGHT -> false
        ThemeMode.DARK -> true
    }
    val acc = hexColor(accent, Color(0xFFE4B3CB))
    val onAcc = if (acc.luminance() > 0.45f) Color.Black else Color.White
    val scheme: ColorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S ->
            if (dark) dynamicDarkColorScheme(LocalContext.current) else dynamicLightColorScheme(LocalContext.current)
        dark -> darkColorScheme(
            primary = acc, onPrimary = onAcc, primaryContainer = acc.copy(alpha = 0.25f), onPrimaryContainer = Color.White,
            secondary = acc, onSecondary = onAcc, secondaryContainer = Color(0xFF2C2C2E), onSecondaryContainer = Color.White,
            background = Color(0xFF000000), onBackground = Color.White, surface = Color(0xFF000000), onSurface = Color.White,
            surfaceVariant = Color(0xFF1C1C1E), onSurfaceVariant = Color(0xFFA1A1A8), surfaceContainer = Color(0xFF1C1C1E),
            surfaceContainerHigh = Color(0xFF2C2C2E), surfaceContainerHighest = Color(0xFF3A3A3C), surfaceContainerLow = Color(0xFF111113),
            outline = Color(0xFF48484A), outlineVariant = Color(0xFF2C2C2E), error = Color(0xFFFF6B6B),
        )
        else -> lightColorScheme(
            primary = acc.darken(0.35f), onPrimary = Color.White, primaryContainer = acc.copy(alpha = 0.35f), onPrimaryContainer = Color.Black,
            secondary = acc.darken(0.35f), secondaryContainer = Color(0xFFE9E9EE),
            background = Color(0xFFF2F2F7), onBackground = Color.Black, surface = Color(0xFFF2F2F7), onSurface = Color.Black,
            surfaceVariant = Color.White, onSurfaceVariant = Color(0xFF6C6C72), surfaceContainer = Color.White,
            surfaceContainerHigh = Color(0xFFE9E9EE), surfaceContainerHighest = Color(0xFFDDDDE3), surfaceContainerLow = Color(0xFFF7F7FA),
            outline = Color(0xFFC6C6CC), outlineVariant = Color(0xFFE0E0E6), error = Color(0xFFD93B3B),
        )
    }
    val colors = if (dark) {
        CaudalColors(Color(0xFF4AD68F), Color(0xFFFF6B6B), Color(0xFFFFA94D), scheme.surfaceContainer, Color(0x0DFFFFFF), Color(0xFF8FB4FF), Color(0xFFFF9F7A))
    } else {
        CaudalColors(Color(0xFF1E9E5A), Color(0xFFD93B3B), Color(0xFFD97A10), scheme.surfaceContainer, Color(0x0D000000), Color(0xFF3D6FD9), Color(0xFFD9653B))
    }
    CompositionLocalProvider(LocalCaudalColors provides colors) {
        MaterialTheme(colorScheme = scheme, typography = typography, content = content)
    }
}

private fun Color.darken(f: Float) = Color(red * (1 - f), green * (1 - f), blue * (1 - f), alpha)
