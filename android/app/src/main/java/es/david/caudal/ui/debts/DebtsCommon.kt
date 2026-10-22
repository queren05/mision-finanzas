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
            .background(Brush.radialGradient(listOf(c.copy(alpha = 0.55f), c.copy(alpha = 0.15f))))
            .border(2.dp, c, CircleShape),
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
    Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).padding(vertical = 6.dp).semantics(mergeDescendants = true) {}, verticalAlignment = Alignment.CenterVertically) {
        if (person != null) { Avatar(person, repo, 40.dp); Spacer(Modifier.width(12.dp)) }
        Column(Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(sub, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        Spacer(Modifier.width(8.dp))
        if (isPay) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Filled.Check, null, tint = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.size(16.dp))
                AmountText(abs(Money.fromCents(move.amount)), color = MaterialTheme.colorScheme.onSurfaceVariant, weight = FontWeight.SemiBold)
            }
        } else {
            AmountText(
                Money.fromCents(move.amount), signed = true, weight = FontWeight.Bold,
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
                    Modifier.fillMaxSize().clip(RoundedCornerShape(14.dp)).background(a.color).padding(horizontal = 20.dp),
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
        Text(text, Modifier.weight(1f), style = MaterialTheme.typography.bodyLarge)
        IconButton(onClick = onMinus, enabled = minusEnabled) { Icon(Icons.Filled.Remove, minusDesc) }
        IconButton(onClick = onPlus, enabled = plusEnabled) { Icon(Icons.Filled.Add, plusDesc) }
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
        Text(label, Modifier.weight(1f), style = MaterialTheme.typography.bodyLarge, color = if (icon != null) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurface)
        Text(value, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.primary)
    }
}

/** elegir una cuenta (con «Ninguna» si se quiere) */
@Composable
fun AccountPicker(label: String, accounts: List<Account>, selected: String?, onSelect: (String?) -> Unit, allowNone: Boolean = false) {
    var open by remember { mutableStateOf(false) }
    val current = accounts.firstOrNull { it.id == selected }
    Box {
        ValueRow(label, current?.let { "${it.icon} ${it.name}" } ?: stringResource(R.string.none), { open = true })
        DropdownMenu(open, { open = false }) {
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
            Text(label, Modifier.weight(1f), style = MaterialTheme.typography.bodyLarge)
            Text(selected?.let(text) ?: "", fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.primary)
            Icon(Icons.Filled.ArrowDropDown, null, tint = MaterialTheme.colorScheme.primary)
        }
        DropdownMenu(open, { open = false }) {
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

