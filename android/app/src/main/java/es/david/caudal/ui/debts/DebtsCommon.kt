package es.david.caudal.ui.debts

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.net.Uri
import android.widget.Toast
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TimeInput
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import es.david.caudal.R
import es.david.caudal.core.Day
import es.david.caudal.core.Money
import es.david.caudal.data.repo.FinanceRepository
import es.david.caudal.domain.calc.Debts
import es.david.caudal.domain.model.Account
import es.david.caudal.domain.model.DebtKind
import es.david.caudal.domain.model.DebtMove
import es.david.caudal.domain.model.Person
import es.david.caudal.ui.common.AmountText
import es.david.caudal.ui.common.Fmt
import es.david.caudal.ui.common.LocalFmt
import es.david.caudal.ui.common.LocalMascot
import es.david.caudal.ui.common.Confetti
import es.david.caudal.ui.common.Gotita
import es.david.caudal.ui.common.Mood
import es.david.caudal.ui.common.contentOn
import es.david.caudal.ui.common.pressable
import es.david.caudal.ui.theme.LocalMotion
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.foundation.layout.height
import androidx.compose.ui.semantics.contentDescription
import es.david.caudal.ui.theme.CaudalTheme
import es.david.caudal.ui.theme.hexColor
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.time.Instant
import java.time.ZoneOffset
import kotlin.math.abs

// MARK: textos de los tipos

fun debtKindLabel(k: DebtKind): Int = when (k) {
    DebtKind.OWE -> R.string.debt_kind_owe
    DebtKind.DEBT -> R.string.debt_kind_debt
    DebtKind.SPLIT -> R.string.debt_kind_split
    DebtKind.THEYPAID -> R.string.debt_kind_theypaid
    DebtKind.PAY -> R.string.debt_kind_pay
    DebtKind.IPAY -> R.string.debt_kind_ipay
}

// MARK: foto o emoji de la persona

@Composable
fun Avatar(person: Person, repo: FinanceRepository, size: Dp = 44.dp, photoOverride: ImageBitmap? = null) {
    val c = hexColor(person.color)
    val photo by produceState<ImageBitmap?>(null, person.photo) {
        value = person.photo?.let { name ->
            withContext(Dispatchers.IO) {
                runCatching { BitmapFactory.decodeFile(repo.photoFile(name).path)?.asImageBitmap() }.getOrNull()
            }
        }
    }
    val img = photoOverride ?: photo
    Box(
        Modifier
            .size(size)
            .clip(CircleShape)
            .background(Brush.linearGradient(listOf(c.copy(alpha = 0.55f), c.copy(alpha = 0.2f))))
            .border(2.dp, c.copy(alpha = 0.8f), CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        if (img != null) {
            Image(img, stringResource(R.string.debts_person_photo, person.name), Modifier.fillMaxSize().clip(CircleShape), contentScale = ContentScale.Crop)
        } else {
            Text(person.emoji, fontSize = (size.value * 0.5f).sp)
        }
    }
}

// MARK: fila de un movimiento de deuda

@Composable
fun DebtRow(move: DebtMove, person: Person?, repo: FinanceRepository, showName: Boolean = true) {
    val f = LocalFmt.current
    val isPay = move.kind == DebtKind.PAY || move.kind == DebtKind.IPAY
    val name = person?.name ?: ""
    val title = when (move.kind) {
        DebtKind.PAY -> stringResource(R.string.debts_paid_you, name)
        DebtKind.IPAY -> stringResource(R.string.debts_you_paid, name)
        else -> move.concept.ifEmpty { stringResource(debtKindLabel(move.kind)) }
    }
    val sub = listOfNotNull(if (showName && !isPay) name else null, stringResource(debtKindLabel(move.kind)), f.shortLabel(move.date)).joinToString(" · ")
    Row(Modifier.fillMaxWidth().heightIn(min = 64.dp).padding(horizontal = 14.dp, vertical = 8.dp).semantics(mergeDescendants = true) {}, verticalAlignment = Alignment.CenterVertically) {
        if (person != null) { Avatar(person, repo, 42.dp); Spacer(Modifier.width(12.dp)) }
        else {
            Box(Modifier.size(42.dp).clip(RoundedCornerShape(15.dp)).background(CaudalTheme.colors.cardAlt), contentAlignment = Alignment.Center) { Text(debtKindEmoji(move.kind), fontSize = 20.sp) }
            Spacer(Modifier.width(12.dp))
        }
        Column(Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.ExtraBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(sub, style = MaterialTheme.typography.bodySmall, color = CaudalTheme.colors.textDim, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        Spacer(Modifier.width(8.dp))
        if (isPay) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Filled.Check, null, tint = CaudalTheme.colors.income, modifier = Modifier.size(16.dp))
                Spacer(Modifier.width(2.dp))
                AmountText(abs(Money.fromCents(move.amount)), color = CaudalTheme.colors.textDim, weight = FontWeight.ExtraBold)
            }
        } else {
            AmountText(
                Money.fromCents(move.amount), signed = true, weight = FontWeight.ExtraBold,
                color = if (move.amount > 0) CaudalTheme.colors.income else CaudalTheme.colors.negative,
            )
        }
    }
}

// MARK: recordar por WhatsApp (o copiar el mensaje)

fun reminderText(ctx: Context, f: Fmt, p: Person, debts: List<DebtMove>): String {
    val b = Debts.balance(debts, p.id)
    val items = Debts.reminderItems(debts, p.id).joinToString("\n") { m ->
        ctx.getString(R.string.debts_reminder_item, m.concept.ifEmpty { ctx.getString(debtKindLabel(m.kind)) }, f.shortLabel(m.date), f.plain(Money.fromCents(m.amount)))
    }
    return ctx.getString(R.string.debts_reminder_msg, p.name, f.plain(Money.fromCents(b)), items)
}

/** abre WhatsApp con el mensaje; si no hay móvil (o no hay WhatsApp), lo copia */
fun remind(ctx: Context, f: Fmt, p: Person, debts: List<DebtMove>) {
    val text = reminderText(ctx, f, p, debts)
    val phone = Debts.whatsappPhone(p.phone)
    if (phone != null) {
        val i = Intent(Intent.ACTION_VIEW, Uri.parse("https://wa.me/$phone?text=" + Uri.encode(text)))
        if (runCatching { ctx.startActivity(i) }.isSuccess) return
    }
    val cm = ctx.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    cm.setPrimaryClip(ClipData.newPlainText(p.name, text))
    Toast.makeText(ctx, ctx.getString(R.string.debts_copied), Toast.LENGTH_LONG).show()
}

fun toast(ctx: Context, text: String) = Toast.makeText(ctx, text, Toast.LENGTH_SHORT).show()

// MARK: deslizar una fila (sin quitarla: solo lanza la acción)

class SwipeAction(val label: String, val icon: ImageVector, val color: Color, val run: () -> Unit)

/**
 * Fila que se desliza para lanzar acciones (como en iPhone). `start` al deslizar hacia la derecha,
 * `end` hacia la izquierda. Las acciones también están para TalkBack.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SwipeRow(start: SwipeAction?, end: SwipeAction?, content: @Composable () -> Unit) {
    val state = rememberSwipeToDismissBoxState(confirmValueChange = { v ->
        when (v) {
            SwipeToDismissBoxValue.StartToEnd -> start?.run?.invoke()
            SwipeToDismissBoxValue.EndToStart -> end?.run?.invoke()
            else -> Unit
        }
        false
    })
    SwipeToDismissBox(
        state = state,
        enableDismissFromStartToEnd = start != null,
        enableDismissFromEndToStart = end != null,
        modifier = Modifier.semantics {
            customActions = listOfNotNull(start, end).map { a -> CustomAccessibilityAction(a.label) { a.run(); true } }
        },
        backgroundContent = {
            val a = when (state.dismissDirection) {
                SwipeToDismissBoxValue.StartToEnd -> start
                SwipeToDismissBoxValue.EndToStart -> end
                else -> null
            }
            if (a != null) {
                Row(
                    Modifier.fillMaxSize().clip(RoundedCornerShape(20.dp)).background(a.color).padding(horizontal = 22.dp),
                    horizontalArrangement = if (state.dismissDirection == SwipeToDismissBoxValue.StartToEnd) Arrangement.Start else Arrangement.End,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(a.icon, null, tint = Color.White)
                    Spacer(Modifier.width(8.dp))
                    Text(a.label, color = Color.White, fontWeight = FontWeight.Bold)
                }
            }
        },
    ) {
        Box(Modifier.background(CaudalTheme.colors.card)) { content() }
    }
}

// MARK: pequeños controles de formulario

/** fila «etiqueta  − valor +» */
@Composable
fun StepperRow(text: String, onMinus: () -> Unit, onPlus: () -> Unit, minusDesc: String, plusDesc: String, minusEnabled: Boolean = true, plusEnabled: Boolean = true) {
    Row(Modifier.fillMaxWidth().heightIn(min = 48.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(text, Modifier.weight(1f), style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Bold)
        RoundStep(Icons.Filled.Remove, minusDesc, minusEnabled, onMinus)
        Spacer(Modifier.width(8.dp))
        RoundStep(Icons.Filled.Add, plusDesc, plusEnabled, onPlus)
    }
}

/** fila con etiqueta a la izquierda y valor a la derecha que abre algo al tocarla */
@Composable
fun ValueRow(label: String, value: String, onClick: () -> Unit, icon: ImageVector? = null) {
    Row(
        Modifier.fillMaxWidth().heightIn(min = 48.dp).clickable(role = Role.Button, onClick = onClick).padding(vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (icon != null) { Icon(icon, null, tint = MaterialTheme.colorScheme.onSurfaceVariant); Spacer(Modifier.width(12.dp)) }
        Text(label, Modifier.weight(1f), style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Bold, color = if (icon != null) CaudalTheme.colors.textDim else CaudalTheme.colors.text)
        Text(value, style = MaterialTheme.typography.labelLarge, color = CaudalTheme.colors.accent,
            modifier = Modifier.clip(CircleShape).background(CaudalTheme.colors.accent.copy(alpha = 0.14f)).padding(horizontal = 12.dp, vertical = 7.dp))
    }
}

/** elegir una cuenta (con «Ninguna» si se quiere) */
@Composable
fun AccountPicker(label: String, accounts: List<Account>, selected: String?, onSelect: (String?) -> Unit, allowNone: Boolean = false) {
    var open by remember { mutableStateOf(false) }
    val current = accounts.firstOrNull { it.id == selected }
    Box {
        ValueRow(label, current?.let { "${it.icon} ${it.name}" } ?: stringResource(R.string.none), { open = true })
        DropdownMenu(open, { open = false }, shape = RoundedCornerShape(20.dp), containerColor = CaudalTheme.colors.card) {
            if (allowNone) DropdownMenuItem(text = { Text(stringResource(R.string.none)) }, onClick = { onSelect(null); open = false })
            accounts.forEach { a ->
                DropdownMenuItem(text = { Text("${a.icon} ${a.name}") }, onClick = { onSelect(a.id); open = false },
                    trailingIcon = if (a.id == selected) ({ Icon(Icons.Filled.Check, null) }) else null)
            }
        }
    }
}

/** elegir una opción de una lista (desplegable) */
@Composable
fun <T> OptionPicker(label: String, options: List<T>, selected: T?, text: (T) -> String, onSelect: (T) -> Unit) {
    var open by remember { mutableStateOf(false) }
    Box {
        Row(
            Modifier.fillMaxWidth().heightIn(min = 48.dp).clickable(role = Role.DropdownList) { open = true },
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(label, Modifier.weight(1f), style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Bold)
            Text(selected?.let(text) ?: "", style = MaterialTheme.typography.labelLarge, color = CaudalTheme.colors.accent)
            Icon(Icons.Filled.ArrowDropDown, null, tint = CaudalTheme.colors.accent)
        }
        DropdownMenu(open, { open = false }, shape = RoundedCornerShape(20.dp), containerColor = CaudalTheme.colors.card) {
            options.forEach { o -> DropdownMenuItem(text = { Text(text(o)) }, onClick = { onSelect(o); open = false }) }
        }
    }
}

/** diálogo de fecha (yyyy-MM-dd) */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DateDialog(date: String, onPick: (String) -> Unit, onDismiss: () -> Unit) {
    val state = rememberDatePickerState(initialSelectedDateMillis = Day.date(date).atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli())
    DatePickerDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            TextButton(onClick = {
                state.selectedDateMillis?.let { onPick(Day.str(Instant.ofEpochMilli(it).atZone(ZoneOffset.UTC).toLocalDate())) }
                onDismiss()
            }) { Text(stringResource(R.string.ok)) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) } },
    ) { DatePicker(state) }
}

/** diálogo de hora (minutos desde las 00:00) */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TimeDialog(title: String, minutes: Int, onPick: (Int) -> Unit, onDismiss: () -> Unit) {
    val state = rememberTimePickerState(initialHour = (minutes / 60) % 24, initialMinute = minutes % 60, is24Hour = true)
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = { TimeInput(state) },
        confirmButton = { TextButton(onClick = { onPick(state.hour * 60 + state.minute); onDismiss() }) { Text(stringResource(R.string.ok)) } },
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) } },
    )
}



fun debtKindEmoji(k: DebtKind): String = when (k) {
    DebtKind.OWE -> "🫴"
    DebtKind.DEBT -> "🙈"
    DebtKind.SPLIT -> "🍕"
    DebtKind.THEYPAID -> "💳"
    DebtKind.PAY -> "✅"
    DebtKind.IPAY -> "💸"
}

@Composable
private fun RoundStep(icon: ImageVector, desc: String, enabled: Boolean, onClick: () -> Unit) {
    val c = CaudalTheme.colors
    Box(
        Modifier.size(44.dp).clip(CircleShape).background(if (enabled) c.accent.copy(alpha = 0.18f) else c.cardAlt)
            .pressable(0.85f, enabled = enabled, onClick = onClick).semantics { contentDescription = desc },
        contentAlignment = Alignment.Center,
    ) { Icon(icon, null, tint = if (enabled) c.accent else c.textDim) }
}

/** tarjetita de acción con icono en un círculo de color (Me debe, Le debo…) que rebota al pulsar */
@Composable
fun ActionTile(label: String, icon: ImageVector, color: Color, modifier: Modifier = Modifier, onClick: () -> Unit) {
    val c = CaudalTheme.colors
    Column(
        modifier
            .pressable(0.9f, onClick = onClick)
            .clip(RoundedCornerShape(22.dp))
            .background(c.card)
            .border(1.dp, c.hairline, RoundedCornerShape(22.dp))
            .heightIn(min = 86.dp)
            .padding(vertical = 12.dp, horizontal = 4.dp)
            .semantics(mergeDescendants = true) {},
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(7.dp),
    ) {
        Box(Modifier.size(40.dp).clip(CircleShape).background(Brush.linearGradient(listOf(color.copy(alpha = 0.95f), color.copy(alpha = 0.65f)))), contentAlignment = Alignment.Center) {
            Icon(icon, null, tint = Color.White, modifier = Modifier.size(22.dp))
        }
        Text(label, style = MaterialTheme.typography.labelMedium, textAlign = androidx.compose.ui.text.style.TextAlign.Center, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

/** botón grande en cápsula con degradado */
@Composable
fun PillButton(text: String, icon: ImageVector?, color: Color, modifier: Modifier = Modifier, filled: Boolean = true, onClick: () -> Unit) {
    val fg = if (filled) contentOn(color) else color
    Row(
        modifier
            .heightIn(min = 54.dp)
            .pressable(0.95f, onClick = onClick)
            .clip(CircleShape)
            .then(if (filled) Modifier.background(Brush.horizontalGradient(listOf(color.copy(alpha = 0.85f), color))) else Modifier.background(color.copy(alpha = 0.14f)))
            .padding(horizontal = 18.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (icon != null) { Icon(icon, null, tint = fg, modifier = Modifier.size(20.dp)); Spacer(Modifier.width(8.dp)) }
        Text(text, style = MaterialTheme.typography.labelLarge, color = fg, maxLines = 1)
    }
}

/**
 * Celebración: confeti y Gotita enamorada un par de segundos (al saldar una deuda, cobrar el mes…).
 * Se lanza cambiando `key` a algo distinto de null.
 */
@Composable
fun Celebration(key: Any?, message: String = "") {
    if (key == null) return
    val c = CaudalTheme.colors
    var visible by remember(key) { mutableStateOf(true) }
    LaunchedEffect(key) { kotlinx.coroutines.delay(2400); visible = false }
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Confetti(key, listOf(c.accent, c.income, c.warning, c.transfer, Color(0xFFFF8FA3), Color(0xFFB9A4FF)))
        androidx.compose.animation.AnimatedVisibility(
            visible,
            enter = androidx.compose.animation.scaleIn(androidx.compose.animation.core.spring(dampingRatio = 0.45f)) + androidx.compose.animation.fadeIn(),
            exit = androidx.compose.animation.scaleOut() + androidx.compose.animation.fadeOut(),
        ) {
            Column(
                Modifier.clip(RoundedCornerShape(30.dp)).background(c.card).border(1.dp, c.hairline, RoundedCornerShape(30.dp)).padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                if (LocalMascot.current) Gotita(Mood.LOVE, 96.dp) else Text("🎉", fontSize = 56.sp)
                if (message.isNotEmpty()) {
                    Spacer(Modifier.size(8.dp))
                    Text(message, style = MaterialTheme.typography.titleMedium, textAlign = androidx.compose.ui.text.style.TextAlign.Center)
                }
            }
        }
    }
}

/** barra repartida en dos colores que crece al aparecer (te deben / debes, pagado / pendiente) */
@Composable
fun SplitBar(a: Double, b: Double, ca: Color, cb: Color, height: Dp = 12.dp) {
    val target = if (a + b <= 0) 0f else (a / (a + b)).toFloat()
    val motion = LocalMotion.current
    var started by remember { mutableStateOf(!motion) }
    LaunchedEffect(Unit) { started = true }
    val frac by androidx.compose.animation.core.animateFloatAsState(if (started) target else 0.5f, androidx.compose.animation.core.spring(dampingRatio = 0.75f, stiffness = androidx.compose.animation.core.Spring.StiffnessVeryLow), label = "reparto")
    Row(Modifier.fillMaxWidth().height(height), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        if (target > 0f) Box(Modifier.weight(frac.coerceAtLeast(0.03f)).height(height).clip(CircleShape).background(Brush.horizontalGradient(listOf(ca.copy(alpha = 0.75f), ca))))
        if (target < 1f) Box(Modifier.weight((1f - frac).coerceAtLeast(0.03f)).height(height).clip(CircleShape).background(Brush.horizontalGradient(listOf(cb, cb.copy(alpha = 0.75f)))))
    }
}

@Composable
fun Legend(color: Color, label: String, value: Double) {
    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.semantics(mergeDescendants = true) {}) {
        Box(Modifier.size(9.dp).clip(CircleShape).background(color))
        Spacer(Modifier.width(5.dp))
        Text(label, style = MaterialTheme.typography.bodySmall, color = CaudalTheme.colors.textDim)
        Spacer(Modifier.width(4.dp))
        AmountText(value, style = MaterialTheme.typography.labelLarge)
    }
}
