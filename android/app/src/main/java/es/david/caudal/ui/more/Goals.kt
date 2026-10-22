package es.david.caudal.ui.more

import androidx.compose.foundation.clickable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.semantics.contentDescription
import es.david.caudal.ui.common.CircleIconButton
import es.david.caudal.ui.common.Confetti
import es.david.caudal.ui.common.EmptyState
import es.david.caudal.ui.common.Gotita
import es.david.caudal.ui.common.LocalMascot
import es.david.caudal.ui.common.Mood
import es.david.caudal.ui.common.appear
import es.david.caudal.ui.theme.ACCENTS
import es.david.caudal.ui.theme.CaudalTheme
import es.david.caudal.ui.theme.LocalMotion
import kotlin.math.PI
import kotlin.math.sin
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import es.david.caudal.R
import es.david.caudal.core.Day
import es.david.caudal.core.Money
import es.david.caudal.domain.model.Goal
import es.david.caudal.domain.model.PALETTE
import es.david.caudal.ui.common.AmountText
import es.david.caudal.ui.common.Card
import es.david.caudal.ui.common.ColorRow
import es.david.caudal.ui.common.ConfirmDialog
import es.david.caudal.ui.common.EditorScaffold
import es.david.caudal.ui.common.EmptyText
import es.david.caudal.ui.common.Emojis
import es.david.caudal.ui.common.FinanceViewModel
import es.david.caudal.ui.common.LocalFmt
import es.david.caudal.ui.common.ProgressBar
import es.david.caudal.ui.common.ScreenScaffold
import es.david.caudal.ui.common.rememberHaptics
import es.david.caudal.ui.nav.GoalEditorRoute
import es.david.caudal.ui.theme.hexColor
import java.time.temporal.ChronoUnit
import kotlin.math.max
import kotlin.math.roundToInt

// MARK: lista de objetivos

@Composable
fun GoalsScreen(nav: NavController) {
    val vm: FinanceViewModel = hiltViewModel()
    val ledger by vm.ledger.collectAsStateWithLifecycle()
    val l = ledger ?: return
    val f = LocalFmt.current
    val h = rememberHaptics()
    ScreenScaffold(
        stringResource(R.string.goals_title),
        onBack = { nav.popBackStack() },
        actions = { CircleIconButton(Icons.Filled.Add, stringResource(R.string.goals_new)) { nav.navigate(GoalEditorRoute()) } },
    ) { pad ->
        LazyColumn(contentPadding = listPadding(pad), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            if (l.data.goals.isEmpty()) item { EmptyState(stringResource(R.string.goals_empty), mood = Mood.HAPPY) }
            itemsIndexed(l.data.goals, key = { _, g -> g.id }) { i, g ->
                val saved = l.saved(g)
                val target = max(Money.fromCents(g.target), 0.01)
                val pct = saved / target
                val col = hexColor(g.color)
                val reached = pct >= 1
                Box(Modifier.animateItem().appear(i)) {
                    Card(onClick = { h.tap(); nav.navigate(GoalEditorRoute(g.id)) }, modifier = Modifier.semantics(mergeDescendants = true) {}) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Jar(pct, col, g.icon, Modifier.size(width = 92.dp, height = 112.dp))
                            Spacer(Modifier.width(16.dp))
                            Column(Modifier.weight(1f)) {
                                Text(g.name, style = MaterialTheme.typography.titleMedium, maxLines = 2)
                                if (g.deadline.isNotEmpty()) Text(stringResource(R.string.goals_for, f.header(g.deadline)), style = MaterialTheme.typography.bodySmall, color = CaudalTheme.colors.textDim)
                                Spacer(Modifier.height(8.dp))
                                Text(stringResource(R.string.goals_pct, (pct * 100).roundToInt()), style = MaterialTheme.typography.headlineSmall, color = col)
                                AmountText(saved, style = MaterialTheme.typography.bodyMedium, weight = FontWeight.Bold)
                                Text(stringResource(R.string.goals_of, f.money(Money.fromCents(g.target))), style = MaterialTheme.typography.bodySmall, color = CaudalTheme.colors.textDim)
                            }
                            if (reached && LocalMascot.current) Gotita(Mood.LOVE, 52.dp)
                        }
                        Spacer(Modifier.height(10.dp))
                        when {
                            reached -> Text(stringResource(R.string.goals_reached), style = MaterialTheme.typography.titleSmall, color = CaudalTheme.colors.income)
                            g.deadline.isNotEmpty() -> {
                                val months = max(1L, ChronoUnit.MONTHS.between(Day.date(Day.today), Day.date(g.deadline)))
                                Text(stringResource(R.string.goals_per_month, f.money((Money.fromCents(g.target) - saved) / months)), style = MaterialTheme.typography.labelLarge, color = col)
                            }
                            else -> Text(stringResource(R.string.goals_left, f.money(Money.fromCents(g.target) - saved)), style = MaterialTheme.typography.labelLarge, color = col)
                        }
                        l.account(g.accountId)?.let { a ->
                            Text(stringResource(R.string.goals_measured_with, a.name), style = MaterialTheme.typography.bodySmall, color = CaudalTheme.colors.textDim)
                        }
                    }
                    if (reached) Confetti(g.id, ACCENTS.map { hexColor(it.hex) }, Modifier.matchParentSize())
                }
            }
        }
    }
}

/** hucha de cristal que se llena con agua ondulada según el % (con el emoji del objetivo dentro) */
@Composable
fun Jar(pct: Double, color: Color, emoji: String, modifier: Modifier = Modifier) {
    val motion = LocalMotion.current
    val level by animateFloatAsState(pct.coerceIn(0.0, 1.0).toFloat(), spring(dampingRatio = 0.6f, stiffness = Spring.StiffnessVeryLow), label = "nivel")
    val phase = if (motion) rememberInfiniteTransition(label = "ola").animateFloat(0f, (2 * PI).toFloat(), infiniteRepeatable(tween(2200, easing = LinearEasing)), label = "fase").value else 0f
    val glass = CaudalTheme.colors.text
    val desc = stringResource(R.string.goals_jar_desc, (pct * 100).roundToInt())
    Box(modifier.semantics { contentDescription = desc }, contentAlignment = Alignment.Center) {
        Canvas(Modifier.matchParentSize()) {
            val w = size.width
            val h = size.height
            val lidH = h * 0.12f
            val body = Path().apply { addRoundRect(RoundRect(w * 0.06f, lidH * 0.9f, w * 0.94f, h, CornerRadius(w * 0.24f))) }
            // cristal
            drawPath(body, glass.copy(alpha = 0.06f))
            clipPath(body) {
                val top = lidH + (h - lidH) * (1 - level)
                val amp = if (level in 0.01f..0.99f) h * 0.025f else 0f
                val wave = Path().apply {
                    moveTo(0f, h)
                    lineTo(0f, top)
                    var x = 0f
                    while (x <= w) { lineTo(x, top + amp * sin(x / w * 2 * PI.toFloat() * 1.5f + phase)); x += 4f }
                    lineTo(w, h)
                    close()
                }
                drawPath(wave, Brush.verticalGradient(listOf(lerp(color, Color.White, 0.3f), color), startY = top, endY = h))
                // burbujas
                drawCircle(Color.White.copy(alpha = 0.35f), w * 0.04f, Offset(w * 0.3f, h * 0.85f - (phase * 8 % (h * 0.3f))))
            }
            drawPath(body, glass.copy(alpha = 0.35f), style = Stroke(width = 2.5f))
            // brillo del cristal
            drawRoundRect(Color.White.copy(alpha = 0.25f), Offset(w * 0.16f, h * 0.24f), Size(w * 0.07f, h * 0.45f), CornerRadius(w * 0.04f))
            // tapa
            drawRoundRect(lerp(color, Color.Black, 0.15f), Offset(w * 0.18f, 0f), Size(w * 0.64f, lidH), CornerRadius(lidH / 2))
        }
        Text(emoji, fontSize = 30.sp, modifier = Modifier.padding(top = 10.dp))
    }
}

// MARK: editor de objetivo

@Composable
fun GoalEditorScreen(id: String?, nav: NavController) {
    val vm: FinanceViewModel = hiltViewModel()
    val ledger by vm.ledger.collectAsStateWithLifecycle()
    val l = ledger ?: return
    val f = LocalFmt.current
    val h = rememberHaptics()
    val original = id?.let { i -> l.data.goals.firstOrNull { it.id == i } }
    var loaded by rememberSaveable { mutableStateOf(false) }
    var name by rememberSaveable { mutableStateOf("") }
    var icon by rememberSaveable { mutableStateOf("🎯") }
    var color by rememberSaveable { mutableStateOf(PALETTE[l.data.goals.size % PALETTE.size]) }
    var target by rememberSaveable { mutableStateOf("") }
    var hasDeadline by rememberSaveable { mutableStateOf(false) }
    var deadline by rememberSaveable { mutableStateOf(Day.addMonths(Day.today, 12)) }
    var accountId by rememberSaveable { mutableStateOf("") }
    var saved by rememberSaveable { mutableLongStateOf(0L) }
    var add by rememberSaveable { mutableStateOf("") }
    var askDelete by remember { mutableStateOf(false) }
    if (!loaded) {
        original?.let {
            name = it.name; icon = it.icon; color = it.color; target = Money.editText(it.target)
            hasDeadline = it.deadline.isNotEmpty(); if (hasDeadline) deadline = it.deadline
            accountId = it.accountId ?: ""; saved = it.saved
        }
        loaded = true
    }
    val parsed = Money.parse(target) ?: 0.0
    EditorScaffold(
        title = stringResource(if (original == null) R.string.goals_new else R.string.goals_edit),
        onCancel = { nav.popBackStack() },
        saveEnabled = name.isNotBlank() && parsed > 0,
        onSave = {
            val g = (original ?: Goal(name = "", target = 0)).copy(
                name = name.trim(), icon = icon.ifEmpty { "🎯" }, color = color, target = Money.toCents(parsed),
                deadline = if (hasDeadline) deadline else "", accountId = accountId.ifEmpty { null }, saved = saved,
            )
            vm.run { save(g) }
            h.success(); nav.popBackStack()
        },
    ) { pad ->
        LazyColumn(contentPadding = listPadding(pad), verticalArrangement = Arrangement.spacedBy(18.dp)) {
            item {
                FormSection {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        OutlinedTextField(icon, { v -> icon = Emojis.split(v).lastOrNull() ?: "" }, label = { Text(stringResource(R.string.accounts_icon)) },
                            singleLine = true, modifier = Modifier.width(96.dp).padding(vertical = 6.dp))
                        Spacer(Modifier.width(10.dp))
                        OutlinedTextField(name, { name = it }, label = { Text(stringResource(R.string.name)) }, singleLine = true, modifier = Modifier.weight(1f).padding(vertical = 6.dp))
                    }
                    FieldRow(stringResource(R.string.goals_target), target, { target = Money.cleanInput(it) }, numeric = true)
                    SwitchRow(stringResource(R.string.goals_deadline), hasDeadline) { hasDeadline = it }
                    if (hasDeadline) { RowDivider(); DateRow(stringResource(R.string.date), deadline) { deadline = it } }
                }
            }
            item {
                FormSection(stringResource(R.string.goals_measured)) {
                    PickerRow(
                        stringResource(R.string.goals_measured),
                        listOf("" to stringResource(R.string.goals_manual)) + l.accounts.map { it.id to "${it.icon} ${it.name}" },
                        accountId,
                    ) { accountId = it }
                }
            }
            if (accountId.isEmpty()) item {
                FormSection(stringResource(R.string.goals_saved, f.plain(Money.fromCents(saved)))) {
                    Row(Modifier.padding(vertical = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedTextField(add, { add = Money.cleanInput(it) }, label = { Text(stringResource(R.string.amount)) }, singleLine = true,
                            keyboardOptions = androidx.compose.foundation.text.KeyboardOptions(keyboardType = androidx.compose.ui.text.input.KeyboardType.Decimal),
                            modifier = Modifier.weight(1f))
                        FilledTonalButton(onClick = { Money.parse(add)?.let { saved += Money.toCents(it); add = ""; h.success() } }) { Text(stringResource(R.string.goals_add)) }
                        FilledTonalButton(onClick = { Money.parse(add)?.let { saved = max(0L, saved - Money.toCents(it)); add = ""; h.tap() } }) { Text(stringResource(R.string.goals_remove)) }
                    }
                }
            }
            item { FormSection(stringResource(R.string.color)) { Box(Modifier.padding(vertical = 12.dp)) { ColorRow(color) { color = it } } } }
            if (original != null) item {
                TextButton(onClick = { h.warning(); askDelete = true }, modifier = Modifier.fillMaxWidth()) {
                    Text(stringResource(R.string.goals_delete), color = MaterialTheme.colorScheme.error)
                }
            }
        }
    }
    if (askDelete && original != null) {
        ConfirmDialog(
            title = stringResource(R.string.goals_delete_title),
            onConfirm = { vm.run { deleteGoal(original) }; h.heavy(); nav.popBackStack() },
            onDismiss = { askDelete = false },
        )
    }
}
