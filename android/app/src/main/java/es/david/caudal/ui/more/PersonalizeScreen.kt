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
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.heightIn
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.filled.ShowChart
import androidx.compose.material.icons.automirrored.filled.ViewList
import androidx.compose.material.icons.filled.Animation
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Euro
import androidx.compose.material.icons.filled.Group
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.MusicNote
import androidx.compose.material.icons.filled.PieChart
import androidx.compose.material.icons.filled.Savings
import androidx.compose.material3.IconButton
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.sp
import es.david.caudal.domain.model.ALL_TABS
import es.david.caudal.ui.common.Card
import es.david.caudal.ui.common.GlowBackground
import es.david.caudal.ui.common.IconTile
import es.david.caudal.ui.common.SegmentedPills
import es.david.caudal.ui.common.Sounds
import es.david.caudal.ui.common.rememberSounds
import es.david.caudal.ui.nav.GotitaRoute
import es.david.caudal.ui.theme.BackdropStyle
import es.david.caudal.ui.theme.CardStyle
import es.david.caudal.ui.theme.FONT_PAIRS
import es.david.caudal.ui.theme.FontPair
import es.david.caudal.ui.theme.LocalUiStyle

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

/**
 * Personalizar: todo el aspecto de Caudal, con una vista previa que cambia al momento.
 * Color, tema, letras, tarjetas, esquinas, densidad, fondo, barra de abajo, importes, Gotita, experiencia e icono.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun PersonalizeScreen(nav: NavController) {
    val vm: FinanceViewModel = hiltViewModel()
    val settings by vm.settings.collectAsStateWithLifecycle()
    val s = settings ?: return
    val ctx = LocalContext.current
    val h = rememberHaptics()
    val sounds = rememberSounds()
    ScreenScaffold(stringResource(R.string.pz_title), onBack = { nav.popBackStack() }) { pad ->
        LazyColumn(contentPadding = listPadding(pad), verticalArrangement = Arrangement.spacedBy(20.dp)) {
            item { Box(Modifier.appear(0)) { Preview(s) } }

            // color
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

            // tema
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

            // letras
            item {
                FormSection(stringResource(R.string.pz_fonts), Modifier.appear(3)) {
                    FlowRow(
                        Modifier.fillMaxWidth().padding(vertical = 12.dp),
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp),
                        maxItemsInEachRow = 2,
                    ) {
                        FONT_PAIRS.forEach { p ->
                            FontChoice(Modifier.weight(1f), p, p.id == s.font) { h.select(); vm.updateSettings { it.copy(font = p.id) } }
                        }
                    }
                }
            }

            // tarjetas, esquinas y densidad
            item {
                FormSection(stringResource(R.string.pz_cards), Modifier.appear(4)) {
                    Row(Modifier.fillMaxWidth().padding(vertical = 12.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        CardStyle.entries.forEach { cs ->
                            OptionTile(
                                Modifier.weight(1f), stringResource(cardName(cs)), s.cardStyle == cs.id,
                                onClick = { h.select(); vm.updateSettings { it.copy(cardStyle = cs.id) } },
                            ) {
                                val base = LocalUiStyle.current
                                CompositionLocalProvider(LocalUiStyle provides base.copy(card = cs)) {
                                    Box(Modifier.fillMaxSize().background(Brush.linearGradient(listOf(CaudalTheme.colors.accent.copy(alpha = 0.35f), CaudalTheme.colors.bg))).padding(10.dp), contentAlignment = Alignment.Center) {
                                        Card(padding = 8.dp) {
                                            Box(Modifier.fillMaxWidth(0.7f).height(6.dp).clip(CircleShape).background(CaudalTheme.colors.accent))
                                            Spacer(Modifier.height(5.dp))
                                            Box(Modifier.fillMaxWidth(0.45f).height(6.dp).clip(CircleShape).background(CaudalTheme.colors.textDim.copy(alpha = 0.4f)))
                                        }
                                    }
                                }
                            }
                        }
                    }
                    RowDivider()
                    Text(stringResource(R.string.pz_corners), style = MaterialTheme.typography.labelLarge, color = CaudalTheme.colors.textDim, modifier = Modifier.padding(top = 12.dp, bottom = 10.dp))
                    Row(Modifier.fillMaxWidth().padding(bottom = 12.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        listOf("suaves" to 8.dp, "redondas" to 16.dp, "muy" to 24.dp).forEach { (id, r) ->
                            OptionTile(
                                Modifier.weight(1f), stringResource(cornerName(id)), s.corners == id, height = 64.dp,
                                onClick = { h.select(); vm.updateSettings { it.copy(corners = id) } },
                            ) {
                                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                                    Box(Modifier.size(width = 52.dp, height = 36.dp).clip(RoundedCornerShape(r * 0.6f)).background(CaudalTheme.colors.accent.copy(alpha = 0.5f)))
                                }
                            }
                        }
                    }
                    RowDivider()
                    Text(stringResource(R.string.pz_density), style = MaterialTheme.typography.labelLarge, color = CaudalTheme.colors.textDim, modifier = Modifier.padding(top = 12.dp, bottom = 10.dp))
                    Box(Modifier.padding(bottom = 14.dp)) {
                        SegmentedPills(
                            listOf(stringResource(R.string.pz_density_comoda), stringResource(R.string.pz_density_compacta)),
                            if (s.density == "compacta") 1 else 0,
                            { i -> vm.updateSettings { it.copy(density = if (i == 1) "compacta" else "comoda") } },
                        )
                    }
                }
            }

            // fondo
            item {
                FormSection(stringResource(R.string.pz_background), Modifier.appear(5)) {
                    FlowRow(
                        Modifier.fillMaxWidth().padding(vertical = 12.dp),
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp),
                        maxItemsInEachRow = 2,
                    ) {
                        BackdropStyle.entries.forEach { b ->
                            OptionTile(
                                Modifier.weight(1f), stringResource(backdropName(b)), s.background == b.id, height = 96.dp,
                                onClick = { h.select(); vm.updateSettings { it.copy(background = b.id) } },
                            ) {
                                val base = LocalUiStyle.current
                                CompositionLocalProvider(LocalUiStyle provides base.copy(backdrop = b)) {
                                    Box(Modifier.fillMaxSize().background(CaudalTheme.colors.bg)) {
                                        GlowBackground(CaudalTheme.colors.accent, Modifier.fillMaxSize())
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // barra de abajo
            item {
                FormSection(stringResource(R.string.pz_tabbar), Modifier.appear(6)) {
                    Box(Modifier.padding(vertical = 12.dp)) { MiniTabBar(s) }
                    RowDivider()
                    val active = s.tabs
                    val ordered = active + ALL_TABS.filter { it !in active }
                    ordered.forEach { id ->
                        val on = id in active
                        val i = active.indexOf(id)
                        TabRow(
                            id = id,
                            on = on,
                            canEnable = on || active.size < 4,
                            canUp = on && i > 0,
                            canDown = on && i < active.lastIndex,
                            onToggle = {
                                h.select()
                                vm.updateSettings { st -> st.copy(tabs = if (on) st.tabs - id else (st.tabs + id).take(4)) }
                            },
                            onUp = { h.select(); vm.updateSettings { st -> st.copy(tabs = st.tabs.toMutableList().apply { add(i - 1, removeAt(i)) }) } },
                            onDown = { h.select(); vm.updateSettings { st -> st.copy(tabs = st.tabs.toMutableList().apply { add(i + 1, removeAt(i)) }) } },
                        )
                        RowDivider()
                    }
                    SwitchRow(stringResource(R.string.pz_tab_labels), s.tabLabels, icon = Icons.Filled.ShortText, iconColor = Color(0xFF8FB4FF)) { on -> vm.updateSettings { it.copy(tabLabels = on) } }
                }
            }

            // importes
            item {
                FormSection(stringResource(R.string.pz_amounts), Modifier.appear(7)) {
                    SwitchRow(stringResource(R.string.pz_hide_cents), s.hideCents, icon = Icons.Filled.Euro, iconColor = Color(0xFF6FD49B)) { on -> vm.updateSettings { it.copy(hideCents = on) } }
                    RowDivider()
                    PickerRow(
                        stringResource(R.string.pz_week_start),
                        listOf(1 to stringResource(R.string.pz_week_monday), 7 to stringResource(R.string.pz_week_sunday)),
                        s.weekStart,
                    ) { d -> vm.updateSettings { it.copy(weekStart = d) } }
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

            // Gotita
            item {
                FormSection(stringResource(R.string.pz_gotita), Modifier.appear(8)) {
                    Row(
                        Modifier.fillMaxWidth().heightIn(min = 72.dp).pressable(0.98f) { h.tap(); nav.navigate(GotitaRoute) }.semantics(mergeDescendants = true) {},
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Gotita(Mood.WINK, 48.dp)
                        Spacer(Modifier.width(14.dp))
                        Text(stringResource(R.string.pz_gotita_dress), Modifier.weight(1f), style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Bold)
                        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = CaudalTheme.colors.textDim.copy(alpha = 0.6f))
                    }
                    RowDivider()
                    SwitchRow(stringResource(R.string.pz_mascot), s.mascot, icon = Icons.Filled.Face, iconColor = Color(0xFFF59FC4)) { on ->
                        vm.updateSettings { it.copy(mascot = on) }
                    }
                }
            }

            // experiencia
            item {
                FormSection(stringResource(R.string.pz_experience), Modifier.appear(9)) {
                    SwitchRow(stringResource(R.string.pz_sounds), s.sounds, icon = Icons.Filled.MusicNote, iconColor = Color(0xFFFFB38A)) { on ->
                        vm.updateSettings { it.copy(sounds = on) }
                        if (on) Sounds.get(ctx).also { it.enabled = true }.pop() else sounds.enabled = false
                    }
                    RowDivider()
                    SwitchRow(stringResource(R.string.pz_haptics), s.haptics, icon = Icons.Filled.Vibration, iconColor = Color(0xFFB39CFF)) { on -> vm.updateSettings { it.copy(haptics = on) } }
                    RowDivider()
                    SwitchRow(stringResource(R.string.pz_reduced_motion), s.reducedMotion, icon = Icons.Filled.Animation, iconColor = Color(0xFF62CFD0)) { on -> vm.updateSettings { it.copy(reducedMotion = on) } }
                }
            }

            // icono de la app
            item {
                FormSection(stringResource(R.string.pz_icon), Modifier.appear(10)) {
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

private fun cardName(c: CardStyle) = when (c) {
    CardStyle.CRISTAL -> R.string.pz_card_cristal
    CardStyle.SOLIDA -> R.string.pz_card_solida
    CardStyle.CONTORNO -> R.string.pz_card_contorno
}

private fun cornerName(id: String) = when (id) {
    "suaves" -> R.string.pz_corners_suaves
    "muy" -> R.string.pz_corners_muy
    else -> R.string.pz_corners_redondas
}

private fun backdropName(b: BackdropStyle) = when (b) {
    BackdropStyle.AGUA -> R.string.pz_bg_agua
    BackdropStyle.BRILLO -> R.string.pz_bg_brillo
    BackdropStyle.PUNTOS -> R.string.pz_bg_puntos
    BackdropStyle.LISO -> R.string.pz_bg_liso
}

/** nombre e icono de cada pestaña posible de la barra de abajo */
private fun tabName(id: String) = when (id) {
    "movimientos" -> R.string.tab_txs
    "cuentas" -> R.string.tab_debts
    "inversiones" -> R.string.tab_invest
    "analisis" -> R.string.analysis
    "calendario" -> R.string.tab_calendar
    else -> R.string.tab_goals
}

private fun tabIcon(id: String): ImageVector = when (id) {
    "movimientos" -> Icons.AutoMirrored.Filled.ViewList
    "cuentas" -> Icons.Filled.Group
    "inversiones" -> Icons.AutoMirrored.Filled.ShowChart
    "analisis" -> Icons.Filled.PieChart
    "calendario" -> Icons.Filled.CalendarMonth
    else -> Icons.Filled.Savings
}

private val TAB_COLORS = mapOf(
    "movimientos" to Color(0xFF8FB4FF), "cuentas" to Color(0xFFFF9F7A), "inversiones" to Color(0xFF6FD49B),
    "analisis" to Color(0xFFB39CFF), "calendario" to Color(0xFF62CFD0), "objetivos" to Color(0xFFF59FC4),
)

/** fila de una pestaña: interruptor (máx. 4) y subir/bajar si está activa */
@Composable
private fun TabRow(id: String, on: Boolean, canEnable: Boolean, canUp: Boolean, canDown: Boolean, onToggle: () -> Unit, onUp: () -> Unit, onDown: () -> Unit) {
    val c = CaudalTheme.colors
    val name = stringResource(tabName(id))
    Row(Modifier.fillMaxWidth().heightIn(min = 58.dp), verticalAlignment = Alignment.CenterVertically) {
        IconTile(tabIcon(id), TAB_COLORS[id] ?: c.accent)
        Spacer(Modifier.width(14.dp))
        Text(name, Modifier.weight(1f), style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Bold, color = if (on || canEnable) c.text else c.textDim)
        if (on) {
            IconButton(onClick = onUp, enabled = canUp) { Icon(Icons.Filled.KeyboardArrowUp, stringResource(R.string.move_up)) }
            IconButton(onClick = onDown, enabled = canDown) { Icon(Icons.Filled.KeyboardArrowDown, stringResource(R.string.move_down)) }
        }
        Switch(
            checked = on, onCheckedChange = { onToggle() }, enabled = canEnable,
            modifier = Modifier.semantics { contentDescription = name },
            colors = SwitchDefaults.colors(
                checkedThumbColor = Color.White, checkedTrackColor = c.accent, checkedBorderColor = c.accent,
                uncheckedThumbColor = Color.White, uncheckedTrackColor = c.cardAlt, uncheckedBorderColor = c.cardAlt,
            ),
        )
    }
}

/** la barra de abajo en pequeño: Inicio, las elegidas y Más */
@Composable
private fun MiniTabBar(s: AppSettings) {
    val c = CaudalTheme.colors
    val ids = listOf("inicio") + s.tabs.take(4) + listOf("mas")
    Row(
        Modifier.fillMaxWidth().clip(CircleShape).background(c.cardAlt).border(1.dp, c.hairline, CircleShape).padding(5.dp),
        horizontalArrangement = Arrangement.SpaceEvenly,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        ids.forEachIndexed { i, id ->
            val icon = when (id) { "inicio" -> Icons.Filled.Home; "mas" -> Icons.Filled.MoreHoriz; else -> tabIcon(id) }
            val label = when (id) { "inicio" -> stringResource(R.string.tab_home); "mas" -> stringResource(R.string.tab_more); else -> stringResource(tabName(id)) }
            Column(
                Modifier.weight(1f).clip(CircleShape).background(if (i == 0) c.accent.copy(alpha = 0.22f) else Color.Transparent).padding(vertical = 6.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Icon(icon, label, tint = if (i == 0) c.accent else c.textDim, modifier = Modifier.size(20.dp))
                if (s.tabLabels) Text(label, style = MaterialTheme.typography.labelSmall, color = if (i == 0) c.text else c.textDim, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
    }
}

/** cajita de opción con previsualización arriba y nombre debajo */
@Composable
private fun OptionTile(
    modifier: Modifier,
    label: String,
    on: Boolean,
    height: androidx.compose.ui.unit.Dp = 84.dp,
    onClick: () -> Unit,
    preview: @Composable () -> Unit,
) {
    val c = CaudalTheme.colors
    val shape = RoundedCornerShape(18.dp)
    Column(
        modifier.pressable(0.93f, role = Role.RadioButton, onClick = onClick).semantics(mergeDescendants = true) { selected = on },
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(
            Modifier.fillMaxWidth().height(height).clip(shape).border(if (on) 3.dp else 1.dp, if (on) c.accent else c.hairline, shape),
        ) { preview() }
        Spacer(Modifier.height(6.dp))
        Text(label, style = MaterialTheme.typography.labelLarge, color = if (on) c.text else c.textDim, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

/** tarjeta de una pareja de letras: «Aa» y un importe con la letra de títulos, el nombre con la del texto */
@Composable
private fun FontChoice(modifier: Modifier, p: FontPair, on: Boolean, onClick: () -> Unit) {
    val c = CaudalTheme.colors
    val f = LocalFmt.current
    val shape = RoundedCornerShape(20.dp)
    val name = stringResource(p.name)
    Column(
        modifier
            .pressable(0.94f, role = Role.RadioButton, onClick = onClick)
            .clip(shape)
            .background(if (on) c.accent.copy(alpha = 0.16f) else c.cardAlt)
            .border(if (on) 3.dp else 1.dp, if (on) c.accent else c.hairline, shape)
            .padding(14.dp)
            .semantics(mergeDescendants = true) { selected = on },
    ) {
        Text("Aa", fontFamily = p.display, fontWeight = FontWeight.Bold, fontSize = 30.sp, lineHeight = 34.sp, color = c.text)
        Text(f.plain(1234.56), fontFamily = p.display, fontWeight = FontWeight.SemiBold, fontSize = 17.sp, color = c.text, maxLines = 1)
        Spacer(Modifier.height(4.dp))
        Text(name, fontFamily = p.body, fontWeight = FontWeight.Bold, fontSize = 13.sp, color = if (on) c.accent else c.textDim)
    }
}

/**
 * Vista previa en vivo: fondo, tarjeta (cristal/sólida/contorno, esquinas, densidad), letras, color y Gotita
 * con su complemento, tal como se verá la app.
 */
@Composable
private fun Preview(s: AppSettings) {
    val c = CaudalTheme.colors
    val f = LocalFmt.current
    val st = LocalUiStyle.current
    val shape = RoundedCornerShape(st.r(28.dp))
    Box(
        Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(c.bg)
            .border(1.dp, c.hairline, shape),
    ) {
        GlowBackground(c.accent, Modifier.matchParentSize())
        Column(Modifier.padding(st.s(18.dp))) {
            Text(stringResource(R.string.pz_preview), style = MaterialTheme.typography.labelLarge, color = c.textDim)
            Spacer(Modifier.height(10.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                if (s.mascot) {
                    Gotita(Mood.LOVE, 58.dp)
                    Spacer(Modifier.width(10.dp))
                }
                Column(Modifier.weight(1f)) {
                    Text(
                        if (s.name.isBlank()) stringResource(R.string.pz_preview_greeting_anon) else stringResource(R.string.pz_preview_greeting, s.name),
                        style = MaterialTheme.typography.headlineSmall,
                    )
                    Text(stringResource(R.string.pz_preview_msg), style = MaterialTheme.typography.bodyMedium, color = c.textDim)
                }
            }
            Spacer(Modifier.height(st.s(14.dp)))
            Card(padding = 16.dp) {
                Text(stringResource(R.string.pz_preview_amount), style = MaterialTheme.typography.labelMedium, color = c.textDim)
                Text(f.money(34.5), style = MaterialTheme.typography.headlineMedium)
                Spacer(Modifier.height(8.dp))
                ProgressBar(0.62, c.accent)
            }
            Spacer(Modifier.height(st.s(12.dp)))
            MiniTabBar(s)
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
