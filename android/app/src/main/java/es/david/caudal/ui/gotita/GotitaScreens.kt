package es.david.caudal.ui.gotita

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Checkroom
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import es.david.caudal.R
import es.david.caudal.domain.calc.Achievement
import es.david.caudal.domain.model.PALETTE
import es.david.caudal.ui.common.Card
import es.david.caudal.ui.common.CircleIconButton
import es.david.caudal.ui.common.ColorRow
import es.david.caudal.ui.common.Confetti
import es.david.caudal.ui.common.FinanceViewModel
import es.david.caudal.ui.common.Gotita
import es.david.caudal.ui.common.GroupLabel
import es.david.caudal.ui.common.IconTile
import es.david.caudal.ui.common.ListRow
import es.david.caudal.ui.common.LocalFmt
import es.david.caudal.ui.common.MASCOT_HATS
import es.david.caudal.ui.common.Mood
import es.david.caudal.ui.common.Pill
import es.david.caudal.ui.common.ProgressBar
import es.david.caudal.ui.common.ScreenScaffold
import es.david.caudal.ui.common.SectionHeader
import es.david.caudal.ui.common.appear
import es.david.caudal.ui.common.contentOn
import es.david.caudal.ui.common.pressable
import es.david.caudal.ui.common.rememberHaptics
import es.david.caudal.ui.common.rememberSounds
import es.david.caudal.ui.nav.AchievementsRoute
import es.david.caudal.ui.nav.GotitaRoute
import es.david.caudal.ui.theme.ACCENTS
import es.david.caudal.ui.theme.CaudalTheme
import es.david.caudal.ui.theme.hexColor

// MARK: nombres

fun hatName(id: String): Int = when (id) {
    "gorro" -> R.string.hat_gorro
    "gafas" -> R.string.hat_gafas
    "lazo" -> R.string.hat_lazo
    "corona" -> R.string.hat_corona
    "auriculares" -> R.string.hat_auriculares
    "flor" -> R.string.hat_flor
    else -> R.string.hat_nada
}

fun achName(id: String): Int = when (id) {
    "primer_gasto" -> R.string.ach_primer_gasto_name
    "diez" -> R.string.ach_diez_name
    "cincuenta" -> R.string.ach_cincuenta_name
    "cien" -> R.string.ach_cien_name
    "quinientos" -> R.string.ach_quinientos_name
    "racha3" -> R.string.ach_racha3_name
    "racha7" -> R.string.ach_racha7_name
    "racha30" -> R.string.ach_racha30_name
    "presupuesto" -> R.string.ach_presupuesto_name
    "mes_presupuesto" -> R.string.ach_mes_presupuesto_name
    "objetivo_creado" -> R.string.ach_objetivo_creado_name
    "objetivo_cumplido" -> R.string.ach_objetivo_cumplido_name
    "cuenta_extra" -> R.string.ach_cuenta_extra_name
    "mes_ahorro" -> R.string.ach_mes_ahorro_name
    "tres_meses_ahorro" -> R.string.ach_tres_meses_ahorro_name
    "deuda_saldada" -> R.string.ach_deuda_saldada_name
    "valio_pena" -> R.string.ach_valio_pena_name
    else -> R.string.ach_categoria_propia_name
}

fun achDesc(id: String): Int = when (id) {
    "primer_gasto" -> R.string.ach_primer_gasto_desc
    "diez" -> R.string.ach_diez_desc
    "cincuenta" -> R.string.ach_cincuenta_desc
    "cien" -> R.string.ach_cien_desc
    "quinientos" -> R.string.ach_quinientos_desc
    "racha3" -> R.string.ach_racha3_desc
    "racha7" -> R.string.ach_racha7_desc
    "racha30" -> R.string.ach_racha30_desc
    "presupuesto" -> R.string.ach_presupuesto_desc
    "mes_presupuesto" -> R.string.ach_mes_presupuesto_desc
    "objetivo_creado" -> R.string.ach_objetivo_creado_desc
    "objetivo_cumplido" -> R.string.ach_objetivo_cumplido_desc
    "cuenta_extra" -> R.string.ach_cuenta_extra_desc
    "mes_ahorro" -> R.string.ach_mes_ahorro_desc
    "tres_meses_ahorro" -> R.string.ach_tres_meses_ahorro_desc
    "deuda_saldada" -> R.string.ach_deuda_saldada_desc
    "valio_pena" -> R.string.ach_valio_pena_desc
    else -> R.string.ach_categoria_propia_desc
}

// MARK: vestir a Gotita

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun GotitaScreen(nav: NavController) {
    val vm: FinanceViewModel = hiltViewModel()
    val ach: AchievementsViewModel = hiltViewModel()
    val settings by vm.settings.collectAsStateWithLifecycle()
    val list by ach.achievements.collectAsStateWithLifecycle()
    val unlocked by ach.unlockedHats.collectAsStateWithLifecycle()
    val s = settings ?: return
    val c = CaudalTheme.colors
    val h = rememberHaptics()
    val sounds = rememberSounds()
    var mood by remember { mutableIntStateOf(0) }
    val moods = listOf(Mood.HAPPY, Mood.WINK, Mood.LOVE, Mood.WOW, Mood.SLEEPY)
    val requirement = es.david.caudal.domain.calc.Achievements.HAT_REQUIREMENTS

    ScreenScaffold(title = stringResource(R.string.gt_title), onBack = { nav.popBackStack() }, actions = {
        CircleIconButton(Icons.Filled.EmojiEvents, stringResource(R.string.ach_title)) { nav.navigate(AchievementsRoute) }
    }) { pad ->
        LazyColumn(contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = pad.calculateTopPadding(), bottom = 140.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            item {
                // escaparate
                val body = if (s.mascotColor.isNotEmpty()) hexColor(s.mascotColor) else c.accent
                Box(
                    Modifier.fillMaxWidth().height(250.dp).clip(RoundedCornerShape(32.dp))
                        .background(Brush.radialGradient(listOf(body.copy(alpha = 0.35f), c.card)))
                        .border(1.dp, c.hairline, RoundedCornerShape(32.dp)).appear(0),
                    contentAlignment = Alignment.Center,
                ) {
                    val tapDesc = stringResource(R.string.gt_tap_desc)
                    Box(Modifier.clip(CircleShape).pressable(0.9f) { h.select(); sounds.pop(); mood = (mood + 1) % moods.size }.semantics { contentDescription = tapDesc }) {
                        Gotita(moods[mood], 170.dp, hat = s.mascotHat)
                    }
                }
            }
            item { GroupLabel(stringResource(R.string.gt_accessories)) }
            item {
                FlowRow(Modifier.fillMaxWidth().appear(1), horizontalArrangement = Arrangement.spacedBy(10.dp), verticalArrangement = Arrangement.spacedBy(10.dp), maxItemsInEachRow = 3) {
                    MASCOT_HATS.forEach { hat ->
                        val open = hat in unlocked
                        val on = hat == s.mascotHat
                        val name = stringResource(hatName(hat))
                        val needs = requirement[hat]?.let { stringResource(achName(it)) }
                        val desc = if (!open) stringResource(R.string.gt_locked_desc, name) else if (on) stringResource(R.string.gt_selected_desc, name) else name
                        val scale by animateFloatAsState(if (on) 1.04f else 1f, spring(dampingRatio = 0.5f, stiffness = Spring.StiffnessMedium), label = "complemento")
                        Column(
                            Modifier.weight(1f).graphicsLayer { scaleX = scale; scaleY = scale }
                                .clip(RoundedCornerShape(22.dp))
                                .background(if (on) c.accent.copy(alpha = 0.22f) else c.card)
                                .border(if (on) 2.dp else 1.dp, if (on) c.accent else c.hairline, RoundedCornerShape(22.dp))
                                .pressable(0.93f, role = Role.RadioButton, enabled = open) { h.select(); sounds.pop(); vm.updateSettings { it.copy(mascotHat = hat) } }
                                .semantics(mergeDescendants = true) { contentDescription = desc; selected = on }
                                .padding(vertical = 12.dp, horizontal = 6.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                        ) {
                            Box(contentAlignment = Alignment.Center) {
                                Box(Modifier.graphicsLayer { alpha = if (open) 1f else 0.35f }) { Gotita(Mood.HAPPY, 64.dp, hat = hat) }
                                if (!open) Icon(Icons.Filled.Lock, null, tint = c.text, modifier = Modifier.size(22.dp).clip(CircleShape).background(c.card).padding(3.dp))
                            }
                            Spacer(Modifier.height(6.dp))
                            Text(name, style = MaterialTheme.typography.labelLarge, maxLines = 1)
                            if (!open && needs != null) Text(stringResource(R.string.gt_locked_by, needs), style = MaterialTheme.typography.labelSmall, color = c.textDim, textAlign = TextAlign.Center, maxLines = 2)
                        }
                    }
                }
            }
            item { GroupLabel(stringResource(R.string.gt_color)) }
            item {
                Card(Modifier.appear(2)) {
                    Pill(stringResource(R.string.gt_color_app), s.mascotColor.isEmpty(), { vm.updateSettings { it.copy(mascotColor = "") } })
                    Spacer(Modifier.height(12.dp))
                    ColorRow(s.mascotColor, (ACCENTS.map { it.hex } + PALETTE).distinct()) { hex -> vm.updateSettings { it.copy(mascotColor = hex) } }
                }
            }
            item {
                Card(Modifier.appear(3), padding = 6.dp) {
                    Row(
                        Modifier.fillMaxWidth().heightIn(min = 58.dp).clip(RoundedCornerShape(20.dp))
                            .pressable(0.98f, role = Role.Switch) { h.select(); vm.updateSettings { it.copy(mascot = !s.mascot) } }
                            .semantics(mergeDescendants = true) {}.padding(horizontal = 12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        IconTile(Icons.Filled.Checkroom, Color(0xFFF59FC4))
                        Spacer(Modifier.width(14.dp))
                        Text(stringResource(R.string.gt_show), style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
                        Switch(s.mascot, null, colors = SwitchDefaults.colors(checkedTrackColor = c.accent, checkedThumbColor = contentOn(c.accent)))
                    }
                    val l = list
                    if (l != null) {
                        ListRow(
                            stringResource(R.string.gt_achievements_row),
                            value = stringResource(R.string.gt_achievements_count, l.count { it.done }, l.size),
                            leading = { IconTile(Icons.Filled.EmojiEvents, Color(0xFFFFC94D)) },
                            onClick = { nav.navigate(AchievementsRoute) },
                        )
                    }
                }
            }
        }
    }
}

// MARK: logros

@Composable
fun AchievementsScreen(nav: NavController) {
    val ach: AchievementsViewModel = hiltViewModel()
    val list by ach.achievements.collectAsStateWithLifecycle()
    val l = list ?: return
    val c = CaudalTheme.colors
    val h = rememberHaptics()
    var open by remember { mutableStateOf<Achievement?>(null) }
    val done = l.count { it.done }
    ScreenScaffold(title = stringResource(R.string.ach_title), onBack = { nav.popBackStack() }, actions = {
        CircleIconButton(Icons.Filled.Checkroom, stringResource(R.string.ach_dress)) { nav.navigate(GotitaRoute) }
    }) { pad ->
        LazyColumn(contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = pad.calculateTopPadding(), bottom = 140.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            item {
                Card(Modifier.appear(0)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Gotita(if (done == l.size) Mood.LOVE else Mood.HAPPY, 62.dp)
                        Spacer(Modifier.width(14.dp))
                        Column(Modifier.weight(1f)) {
                            Text("$done / ${l.size}", style = MaterialTheme.typography.headlineMedium)
                            Text(stringResource(R.string.ach_done_of, done, l.size), style = MaterialTheme.typography.bodyMedium, color = c.textDim)
                        }
                    }
                    Spacer(Modifier.height(12.dp))
                    ProgressBar(done.toDouble() / l.size, c.accent)
                }
            }
            items(l.chunked(3).size) { row ->
                Row(Modifier.fillMaxWidth().appear(row + 1), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    l.chunked(3)[row].forEach { a -> Medal(a, Modifier.weight(1f)) { h.select(); open = a } }
                    repeat(3 - l.chunked(3)[row].size) { Spacer(Modifier.weight(1f)) }
                }
            }
        }
    }
    open?.let { a -> AchievementDialog(a) { open = null } }
}

@Composable
private fun Medal(a: Achievement, modifier: Modifier, onClick: () -> Unit) {
    val c = CaudalTheme.colors
    val name = stringResource(achName(a.id))
    val state = if (a.done) stringResource(R.string.ach_state_done) else stringResource(R.string.ach_state_progress, a.current, a.goal)
    val desc = stringResource(R.string.ach_medal_desc, name, state)
    Column(
        modifier.clip(RoundedCornerShape(24.dp)).background(c.card).border(1.dp, if (a.done) c.accent.copy(alpha = 0.5f) else c.hairline, RoundedCornerShape(24.dp))
            .pressable(0.94f) { onClick() }.semantics(mergeDescendants = true) { contentDescription = desc }
            .padding(vertical = 14.dp, horizontal = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(
            Modifier.size(64.dp).clip(CircleShape)
                .background(
                    if (a.done) Brush.radialGradient(listOf(lerp(Color(0xFFFFE08A), Color.White, 0.3f), c.accent))
                    else Brush.radialGradient(listOf(c.cardAlt, c.cardAlt)),
                )
                .then(if (a.done) Modifier.border(2.dp, Color.White.copy(alpha = 0.6f), CircleShape) else Modifier),
            contentAlignment = Alignment.Center,
        ) {
            Text(a.emoji, fontSize = 30.sp, modifier = Modifier.graphicsLayer { alpha = if (a.done) 1f else 0.35f })
        }
        Spacer(Modifier.height(8.dp))
        Text(name, style = MaterialTheme.typography.labelMedium, textAlign = TextAlign.Center, maxLines = 2, overflow = TextOverflow.Ellipsis)
        if (!a.done) {
            Spacer(Modifier.height(6.dp))
            ProgressBar(a.progress.toDouble(), c.accent, Modifier.padding(horizontal = 8.dp), height = 6.dp)
        }
    }
}

@Composable
private fun AchievementDialog(a: Achievement, onDismiss: () -> Unit) {
    val c = CaudalTheme.colors
    val f = LocalFmt.current
    AlertDialog(
        onDismissRequest = onDismiss,
        shape = RoundedCornerShape(30.dp),
        containerColor = c.card,
        confirmButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.ok), color = c.accent) } },
        text = {
            Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                Text(a.emoji, fontSize = 56.sp, modifier = Modifier.graphicsLayer { alpha = if (a.done) 1f else 0.4f })
                Spacer(Modifier.height(8.dp))
                Text(stringResource(achName(a.id)), style = MaterialTheme.typography.titleLarge, textAlign = TextAlign.Center)
                Text(stringResource(achDesc(a.id)), style = MaterialTheme.typography.bodyMedium, color = c.textDim, textAlign = TextAlign.Center)
                Spacer(Modifier.height(12.dp))
                if (a.done) {
                    Text(a.date?.let { stringResource(R.string.ach_got_on, f.header(it)) } ?: stringResource(R.string.ach_got), style = MaterialTheme.typography.labelLarge, color = c.income)
                } else {
                    Text(stringResource(R.string.ach_progress, a.current, a.goal), style = MaterialTheme.typography.labelLarge)
                    Spacer(Modifier.height(6.dp))
                    ProgressBar(a.progress.toDouble(), c.accent)
                }
                a.unlocks?.let {
                    Spacer(Modifier.height(10.dp))
                    Text(stringResource(R.string.ach_unlocks, stringResource(hatName(it))), style = MaterialTheme.typography.labelMedium, color = c.accent)
                    Gotita(Mood.HAPPY, 56.dp, hat = it)
                }
            }
        },
    )
}

// MARK: celebración

/**
 * Celebra UNA vez cada logro nuevo: Gotita enamorada, confeti y un «tilín».
 * Se pone una sola vez en la raíz de la app.
 */
@Composable
fun AchievementCelebration() {
    val vm: AchievementsViewModel = hiltViewModel()
    val pending by vm.pending.collectAsStateWithLifecycle()
    val a = pending ?: return
    val c = CaudalTheme.colors
    val sounds = rememberSounds()
    val h = rememberHaptics()
    androidx.compose.runtime.LaunchedEffect(a.id) { sounds.chime(); h.success() }
    androidx.compose.ui.window.Dialog(
        onDismissRequest = { vm.celebrated(a.id) },
        properties = androidx.compose.ui.window.DialogProperties(usePlatformDefaultWidth = false),
    ) {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Column(
                Modifier.padding(28.dp).fillMaxWidth().clip(RoundedCornerShape(34.dp)).background(c.card)
                    .border(1.dp, c.hairline, RoundedCornerShape(34.dp)).padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(stringResource(R.string.ach_new), style = MaterialTheme.typography.labelLarge, color = c.accent)
                Spacer(Modifier.height(6.dp))
                Gotita(Mood.LOVE, 120.dp, hat = a.unlocks)
                Text(a.emoji, fontSize = 40.sp)
                Text(stringResource(achName(a.id)), style = MaterialTheme.typography.headlineSmall, textAlign = TextAlign.Center)
                Text(stringResource(achDesc(a.id)), style = MaterialTheme.typography.bodyMedium, color = c.textDim, textAlign = TextAlign.Center)
                a.unlocks?.let {
                    Spacer(Modifier.height(8.dp))
                    Text(stringResource(R.string.ach_unlocked, stringResource(hatName(it))), style = MaterialTheme.typography.labelLarge, color = c.income)
                }
                Spacer(Modifier.height(18.dp))
                Text(
                    stringResource(R.string.ach_nice), style = MaterialTheme.typography.titleMedium, color = contentOn(c.accent), textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth().heightIn(min = 52.dp).clip(CircleShape).pressable(0.94f) { vm.celebrated(a.id) }.background(c.accent).padding(vertical = 14.dp),
                )
            }
            Confetti(a.id, listOf(c.accent, c.income, c.warning, Color(0xFF8FC8FF), Color(0xFFB9A4FF)))
        }
    }
}
