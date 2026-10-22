package es.david.caudal.ui.more

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Contrast
import androidx.compose.material.icons.filled.Dashboard
import androidx.compose.material.icons.filled.Face
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material.icons.filled.ShortText
import androidx.compose.material.icons.filled.Vibration
import androidx.compose.material.icons.filled.ViewCarousel
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.core.graphics.drawable.toBitmap
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import es.david.caudal.R
import es.david.caudal.domain.model.AccountsStyle
import es.david.caudal.domain.model.AppSettings
import es.david.caudal.domain.model.PALETTE
import es.david.caudal.domain.model.ThemeMode
import es.david.caudal.ui.common.ColorRow
import es.david.caudal.ui.common.FinanceViewModel
import es.david.caudal.ui.common.Gotita
import es.david.caudal.ui.common.LocalFmt
import es.david.caudal.ui.common.Mood
import es.david.caudal.ui.common.ProgressBar
import es.david.caudal.ui.common.ScreenScaffold
import es.david.caudal.ui.common.appear
import es.david.caudal.ui.common.contentOn
import es.david.caudal.ui.common.pressable
import es.david.caudal.ui.common.rememberHaptics
import es.david.caudal.ui.nav.HomeCustomizeRoute
import es.david.caudal.ui.theme.ACCENTS
import es.david.caudal.ui.theme.CaudalTheme
import es.david.caudal.ui.theme.hexColor

/** iconos de la app (alias de MainActivity en el manifiesto) */
data class AppIcon(val id: String, val alias: String, val mipmap: Int, val name: Int)

val APP_ICONS = listOf(
    AppIcon("default", ".IconDefault", R.mipmap.ic_launcher, R.string.pz_icon_default),
    AppIcon("algodon", ".IconAlgodon", R.mipmap.ic_launcher_algodon, R.string.pz_icon_algodon),
    AppIcon("menta", ".IconMenta", R.mipmap.ic_launcher_menta, R.string.pz_icon_menta),
    AppIcon("lavanda", ".IconLavanda", R.mipmap.ic_launcher_lavanda, R.string.pz_icon_lavanda),
    AppIcon("melocoton", ".IconMelocoton", R.mipmap.ic_launcher_melocoton, R.string.pz_icon_melocoton),
    AppIcon("cielo", ".IconCielo", R.mipmap.ic_launcher_cielo, R.string.pz_icon_cielo),
    AppIcon("noche", ".IconNoche", R.mipmap.ic_launcher_noche, R.string.pz_icon_noche),
)

/** activa el alias del icono elegido y apaga los demás (sin cerrar la app) */
fun applyAppIcon(context: Context, id: String) {
    val pm = context.packageManager
    // los alias se declaran con el paquete del código (es.david.caudal), aunque la app de prueba se instale como .debug
    val base = "es.david.caudal"
    APP_ICONS.forEach { icon ->
        val on = icon.id == id
        runCatching {
            pm.setComponentEnabledSetting(
                ComponentName(context.packageName, base + icon.alias),
                if (on) PackageManager.COMPONENT_ENABLED_STATE_ENABLED else PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP,
            )
        }
    }
}

/** Personalizar: colores, tema, icono, Gotita y detalles, con una vista previa en vivo */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun PersonalizeScreen(nav: NavController) {
    val vm: FinanceViewModel = hiltViewModel()
    val settings by vm.settings.collectAsStateWithLifecycle()
    val s = settings ?: return
    val ctx = LocalContext.current
    val h = rememberHaptics()
    ScreenScaffold(stringResource(R.string.pz_title), onBack = { nav.popBackStack() }) { pad ->
        LazyColumn(contentPadding = listPadding(pad), verticalArrangement = Arrangement.spacedBy(20.dp)) {
            item { Box(Modifier.appear(0)) { Preview(s) } }

            item {
                FormSection(stringResource(R.string.pz_accent), Modifier.appear(1)) {
                    FlowRow(
                        Modifier.fillMaxWidth().padding(vertical = 12.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalArrangement = Arrangement.spacedBy(14.dp),
                        maxItemsInEachRow = 4,
                    ) {
                        ACCENTS.forEach { a ->
                            val on = !s.dynamicColor && a.hex.equals(s.accent, ignoreCase = true)
                            AccentChoice(a.hex, stringResource(a.name), on) { h.select(); vm.updateSettings { it.copy(accent = a.hex, dynamicColor = false) } }
                        }
                    }
                    RowDivider()
                    Text(stringResource(R.string.pz_more_colors), style = MaterialTheme.typography.labelLarge, color = CaudalTheme.colors.textDim, modifier = Modifier.padding(top = 12.dp, bottom = 10.dp))
                    Box(Modifier.padding(bottom = 14.dp)) {
                        ColorRow(s.accent, PALETTE) { c -> vm.updateSettings { it.copy(accent = c, dynamicColor = false) } }
                    }
                }
            }

            item {
                FormSection(stringResource(R.string.pz_theme), Modifier.appear(2)) {
                    Row(Modifier.fillMaxWidth().padding(vertical = 12.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        ThemeChoice(Modifier.weight(1f), ThemeMode.SYSTEM, stringResource(R.string.pz_theme_system), s) { vm.updateSettings { st -> st.copy(theme = it) } }
                        ThemeChoice(Modifier.weight(1f), ThemeMode.LIGHT, stringResource(R.string.pz_theme_light), s) { vm.updateSettings { st -> st.copy(theme = it) } }
                        ThemeChoice(Modifier.weight(1f), ThemeMode.DARK, stringResource(R.string.pz_theme_dark), s) { vm.updateSettings { st -> st.copy(theme = it) } }
                    }
                    RowDivider()
                    SwitchRow(stringResource(R.string.pz_amoled), s.amoled, enabled = s.theme != ThemeMode.LIGHT, icon = Icons.Filled.Contrast, iconColor = Color(0xFF3A3842)) { on ->
                        vm.updateSettings { it.copy(amoled = on) }
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        RowDivider()
                        SwitchRow(stringResource(R.string.pz_dynamic), s.dynamicColor, icon = Icons.Filled.Palette, iconColor = Color(0xFF62CFD0)) { on ->
                            vm.updateSettings { it.copy(dynamicColor = on) }
                        }
                    }
                }
            }

            item {
                FormSection(stringResource(R.string.pz_icon), Modifier.appear(3)) {
                    LazyRow(Modifier.padding(vertical = 14.dp), horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                        items(APP_ICONS, key = { it.id }) { icon ->
                            val on = icon.id == s.appIcon
                            IconChoice(icon, on) {
                                h.success()
                                applyAppIcon(ctx, icon.id)
                                vm.updateSettings { it.copy(appIcon = icon.id) }
                            }
                        }
                    }
                }
            }

            item {
                FormSection(stringResource(R.string.pz_details), Modifier.appear(4)) {
                    SwitchRow(stringResource(R.string.pz_mascot), s.mascot, icon = Icons.Filled.Face, iconColor = Color(0xFFF59FC4)) { on ->
                        vm.updateSettings { it.copy(mascot = on) }
                    }
                    RowDivider()
                    SwitchRow(stringResource(R.string.pz_tab_labels), s.tabLabels, icon = Icons.Filled.ShortText, iconColor = Color(0xFF8FB4FF)) { on -> vm.updateSettings { it.copy(tabLabels = on) } }
                    RowDivider()
                    SwitchRow(stringResource(R.string.pz_haptics), s.haptics, icon = Icons.Filled.Vibration, iconColor = Color(0xFFB39CFF)) { on -> vm.updateSettings { it.copy(haptics = on) } }
                    RowDivider()
                    PickerRow(
                        stringResource(R.string.pz_accounts_style),
                        AccountsStyle.entries.map { it to stringResource(styleName(it)) },
                        s.accountsStyle,
                    ) { st -> vm.updateSettings { it.copy(accountsStyle = st) } }
                    RowDivider()
                    NavRow(Icons.Filled.Dashboard, Color(0xFFFF9F7A), stringResource(R.string.pz_home)) { nav.navigate(HomeCustomizeRoute) }
                }
            }
        }
    }
}

private fun styleName(s: AccountsStyle) = when (s) {
    AccountsStyle.CUADRICULA -> R.string.style_cuadricula
    AccountsStyle.CARRUSEL -> R.string.style_carrusel
    AccountsStyle.LISTA -> R.string.style_lista
    AccountsStyle.PEQUENO -> R.string.style_pequeno
    AccountsStyle.GRANDE -> R.string.style_grande
}

/** mini tarjeta de inicio con los colores que se están eligiendo (cambia al momento) */
@Composable
private fun Preview(s: AppSettings) {
    val c = CaudalTheme.colors
    val f = LocalFmt.current
    val shape = RoundedCornerShape(28.dp)
    Column(
        Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(Brush.verticalGradient(listOf(lerp(c.bg, c.accent, 0.22f), c.bg)))
            .border(1.dp, c.hairline, shape)
            .padding(18.dp),
    ) {
        Text(stringResource(R.string.pz_preview), style = MaterialTheme.typography.labelLarge, color = c.textDim)
        Spacer(Modifier.height(10.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (s.mascot) {
                Gotita(Mood.LOVE, 54.dp)
                Spacer(Modifier.width(10.dp))
            }
            Column(Modifier.weight(1f)) {
                Text(
                    if (s.name.isBlank()) stringResource(R.string.pz_preview_greeting_anon) else stringResource(R.string.pz_preview_greeting, s.name),
                    style = MaterialTheme.typography.titleLarge,
                )
                Text(stringResource(R.string.pz_preview_msg), style = MaterialTheme.typography.bodyMedium, color = c.textDim)
            }
        }
        Spacer(Modifier.height(14.dp))
        Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(22.dp)).background(c.card).border(1.dp, c.hairline, RoundedCornerShape(22.dp)).padding(16.dp)) {
            Text(stringResource(R.string.pz_preview_amount), style = MaterialTheme.typography.labelMedium, color = c.textDim)
            Text(f.money(34.5), style = MaterialTheme.typography.headlineMedium)
            Spacer(Modifier.height(8.dp))
            ProgressBar(0.62, c.accent)
        }
        Spacer(Modifier.height(12.dp))
        // la barra de abajo en pequeño
        Row(
            Modifier.fillMaxWidth().clip(CircleShape).background(c.card).border(1.dp, c.hairline, CircleShape).padding(6.dp),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            repeat(4) { i ->
                Box(
                    Modifier.size(width = 46.dp, height = 26.dp).clip(CircleShape).background(if (i == 0) c.accent.copy(alpha = 0.25f) else Color.Transparent),
                    contentAlignment = Alignment.Center,
                ) { Box(Modifier.size(10.dp).clip(CircleShape).background(if (i == 0) c.accent else c.textDim.copy(alpha = 0.5f))) }
            }
            Box(Modifier.size(34.dp).clip(CircleShape).background(c.accent), contentAlignment = Alignment.Center) {
                Text("+", color = contentOn(c.accent), style = MaterialTheme.typography.titleLarge)
            }
        }
    }
}

@Composable
private fun AccentChoice(hex: String, name: String, on: Boolean, onClick: () -> Unit) {
    val col = hexColor(hex)
    val ring by animateDpAsState(if (on) 3.dp else 0.dp, spring(dampingRatio = 0.5f, stiffness = Spring.StiffnessMedium), label = "anillo")
    val sel = stringResource(R.string.pz_selected)
    Column(
        Modifier.width(72.dp).pressable(0.88f, role = Role.RadioButton, onClick = onClick).semantics(mergeDescendants = true) {
            selected = on
            contentDescription = if (on) "$name, $sel" else name
        },
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(
            Modifier.size(56.dp).clip(CircleShape).background(CaudalTheme.colors.bg).border(ring, CaudalTheme.colors.text, CircleShape).padding(5.dp)
                .clip(CircleShape).background(Brush.linearGradient(listOf(lerp(col, Color.White, 0.3f), col))),
            contentAlignment = Alignment.Center,
        ) { if (on) Icon(Icons.Filled.Check, null, tint = contentOn(col)) }
        Spacer(Modifier.height(6.dp))
        Text(name, style = MaterialTheme.typography.labelMedium, textAlign = TextAlign.Center, maxLines = 1, fontWeight = if (on) FontWeight.Black else null)
    }
}

/** mini pantalla de cada tema */
@Composable
private fun ThemeChoice(modifier: Modifier, mode: ThemeMode, label: String, s: AppSettings, onPick: (ThemeMode) -> Unit) {
    val c = CaudalTheme.colors
    val h = rememberHaptics()
    val on = s.theme == mode
    val acc = hexColor(s.accent)
    val darkBg = if (s.amoled) Color.Black else Color(0xFF15141A)
    val (bg, card) = when (mode) {
        ThemeMode.LIGHT -> Color(0xFFF6F4F8) to Color.White
        ThemeMode.DARK -> darkBg to Color(0xFF24232B)
        ThemeMode.SYSTEM -> Color(0xFFF6F4F8) to Color(0xFF24232B)
    }
    Column(
        modifier.pressable(0.93f, role = Role.RadioButton) { h.select(); onPick(mode) }.semantics(mergeDescendants = true) { selected = on },
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(
            Modifier.fillMaxWidth().height(96.dp).clip(RoundedCornerShape(18.dp))
                .background(if (mode == ThemeMode.SYSTEM) Brush.horizontalGradient(0.5f to bg, 0.5f to darkBg) else Brush.linearGradient(listOf(bg, bg)))
                .border(if (on) 3.dp else 1.dp, if (on) c.accent else c.hairline, RoundedCornerShape(18.dp))
                .padding(10.dp),
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Box(Modifier.fillMaxWidth(0.6f).height(8.dp).clip(CircleShape).background(acc))
                Box(Modifier.fillMaxWidth().height(26.dp).clip(RoundedCornerShape(8.dp)).background(card))
                Box(Modifier.fillMaxWidth().height(18.dp).clip(RoundedCornerShape(8.dp)).background(card))
            }
        }
        Spacer(Modifier.height(6.dp))
        Text(label, style = MaterialTheme.typography.labelLarge, color = if (on) c.text else c.textDim)
    }
}

@Composable
private fun IconChoice(icon: AppIcon, on: Boolean, onClick: () -> Unit) {
    val ctx = LocalContext.current
    val c = CaudalTheme.colors
    val bmp = remember(icon.id) { ContextCompat.getDrawable(ctx, icon.mipmap)?.toBitmap(160, 160)?.asImageBitmap() }
    val name = stringResource(icon.name)
    val desc = stringResource(R.string.pz_icon_desc, name)
    Column(
        Modifier.width(76.dp).pressable(0.88f, role = Role.RadioButton, onClick = onClick).semantics(mergeDescendants = true) { selected = on; contentDescription = desc },
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(
            Modifier.size(64.dp).clip(RoundedCornerShape(20.dp)).border(if (on) 3.dp else 0.dp, c.accent, RoundedCornerShape(20.dp)).padding(if (on) 4.dp else 0.dp),
            contentAlignment = Alignment.Center,
        ) {
            if (bmp != null) Image(bmp, null, Modifier.size(60.dp).clip(RoundedCornerShape(16.dp)))
        }
        Spacer(Modifier.height(6.dp))
        Text(name, style = MaterialTheme.typography.labelMedium, maxLines = 1, color = if (on) c.text else c.textDim)
    }
}
