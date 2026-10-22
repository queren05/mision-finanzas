package es.david.caudal.ui.common

import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.CompareArrows
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import es.david.caudal.R
import es.david.caudal.core.Money
import es.david.caudal.domain.calc.Ledger
import es.david.caudal.domain.model.PALETTE
import es.david.caudal.domain.model.Tx
import es.david.caudal.domain.model.TxType
import es.david.caudal.ui.theme.CaudalTheme
import es.david.caudal.ui.theme.hexColor

// MARK: vibración

class Haptics(private val h: androidx.compose.ui.hapticfeedback.HapticFeedback) {
    fun tap() = h.performHapticFeedback(HapticFeedbackType.ContextClick)
    fun select() = h.performHapticFeedback(HapticFeedbackType.SegmentTick)
    fun success() = h.performHapticFeedback(HapticFeedbackType.Confirm)
    fun warning() = h.performHapticFeedback(HapticFeedbackType.Reject)
    fun heavy() = h.performHapticFeedback(HapticFeedbackType.LongPress)
}

@Composable
fun rememberHaptics(): Haptics {
    val h = LocalHapticFeedback.current
    return remember(h) { Haptics(h) }
}

// MARK: tarjetas

@Composable
fun Card(modifier: Modifier = Modifier, padding: Dp = 16.dp, content: @Composable ColumnScope.() -> Unit) {
    Column(
        modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(22.dp))
            .background(CaudalTheme.colors.card)
            .padding(padding)
            .animateContentSize(),
        content = content,
    )
}

/** cabecera de las tarjetas: título y, si hay, una acción a la derecha */
@Composable
fun SectionHeader(title: String, action: String? = null, onAction: (() -> Unit)? = null) {
    val h = rememberHaptics()
    Row(Modifier.fillMaxWidth().padding(horizontal = 4.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(title, style = MaterialTheme.typography.titleLarge, modifier = Modifier.weight(1f).semantics { heading() })
        if (action != null && onAction != null) {
            TextButton(onClick = { h.tap(); onAction() }) { Text(action, fontWeight = FontWeight.SemiBold) }
        }
    }
}

// MARK: importes

/** importe que se oculta con el ojo */
@Composable
fun AmountText(
    value: Double,
    modifier: Modifier = Modifier,
    signed: Boolean = false,
    style: TextStyle = MaterialTheme.typography.bodyLarge,
    color: Color = Color.Unspecified,
    weight: FontWeight? = null,
) {
    val f = LocalFmt.current
    Text(
        if (signed) f.signed(value) else f.money(value),
        modifier = modifier,
        style = style.copy(fontFeatureSettings = "tnum"),
        color = color,
        fontWeight = weight,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
    )
}

/** círculo con el emoji de la categoría o la cuenta */
@Composable
fun IconBubble(icon: String, color: String, size: Dp = 44.dp, modifier: Modifier = Modifier) {
    val c = hexColor(color)
    Box(
        modifier
            .size(size)
            .clip(CircleShape)
            .background(c.copy(alpha = 0.22f))
            .border(1.dp, c.copy(alpha = 0.35f), CircleShape),
        contentAlignment = Alignment.Center,
    ) { Text(icon, fontSize = (size.value * 0.46f).sp) }
}

/** barra de progreso redondeada (naranja al 80 %, roja al pasarse) */
@Composable
fun ProgressBar(value: Double, color: Color, modifier: Modifier = Modifier, height: Dp = 8.dp) {
    val shown by animateFloatAsState(value.coerceIn(0.0, 1.0).toFloat(), spring(dampingRatio = 0.8f, stiffness = Spring.StiffnessLow), label = "progress")
    Box(modifier.fillMaxWidth().height(height).clip(CircleShape).background(CaudalTheme.colors.cardAlt.copy(alpha = 0.12f))) {
        Box(Modifier.fillMaxWidth(shown.coerceAtLeast(0.02f)).height(height).clip(CircleShape).background(color))
    }
}

fun budgetColor(spent: Double, budget: Double, normal: Color, warn: Color, over: Color): Color =
    if (spent > budget) over else if (spent > budget * 0.8) warn else normal

// MARK: movimientos

/** fila de un movimiento, como en la app del banco */
@Composable
fun TxRow(tx: Tx, ledger: Ledger, modifier: Modifier = Modifier, showDate: Boolean = false, onClick: (() -> Unit)? = null) {
    val f = LocalFmt.current
    val cat = ledger.category(tx.categoryId)
    val colors = CaudalTheme.colors
    val title = when {
        tx.title.isNotEmpty() -> tx.title
        tx.type == TxType.TRANSFER -> "${ledger.account(tx.accountId)?.name ?: "?"} → ${ledger.account(tx.toAccountId)?.name ?: "?"}"
        else -> cat?.name ?: stringResource(txTypeLabel(tx.type))
    }
    val parts = buildList {
        if (showDate) add(f.shortLabel(tx.date))
        add(tx.time)
        when {
            tx.note.isNotEmpty() -> add(tx.note)
            tx.type == TxType.TRANSFER -> add(stringResource(R.string.tx_transfer))
            else -> ledger.account(tx.accountId)?.let { add(it.name) }
        }
    }
    val amount = Money.fromCents(tx.amount)
    val shown = when (tx.type) {
        TxType.EXPENSE, TxType.TRANSFER -> -amount
        TxType.INCOME, TxType.ADJUST -> amount
    }
    val amountColor = when (tx.type) {
        TxType.INCOME -> colors.income
        TxType.ADJUST -> if (tx.amount >= 0) colors.income else MaterialTheme.colorScheme.onSurface
        TxType.TRANSFER -> MaterialTheme.colorScheme.onSurfaceVariant
        else -> MaterialTheme.colorScheme.onSurface
    }
    Row(
        modifier
            .fillMaxWidth()
            .heightIn(min = 56.dp)
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
            .padding(vertical = 6.dp)
            .semantics(mergeDescendants = true) {},
        verticalAlignment = Alignment.CenterVertically,
    ) {
        when (tx.type) {
            TxType.TRANSFER -> SymbolBubble(Icons.AutoMirrored.Filled.CompareArrows, colors.transfer)
            TxType.ADJUST -> SymbolBubble(Icons.Filled.Tune, MaterialTheme.colorScheme.onSurfaceVariant)
            else -> IconBubble(cat?.icon ?: "❔", cat?.color ?: "#a9b3c2")
        }
        Spacer(Modifier.width(14.dp))
        Column(Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(parts.joinToString(" · "), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        Spacer(Modifier.width(8.dp))
        Column(horizontalAlignment = Alignment.End) {
            AmountText(shown, signed = tx.type == TxType.INCOME || (tx.type == TxType.ADJUST && shown > 0), color = amountColor, weight = FontWeight.SemiBold)
            if (tx.excluded) Text(stringResource(R.string.tx_excluded_short), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
fun SymbolBubble(icon: androidx.compose.ui.graphics.vector.ImageVector, color: Color, size: Dp = 44.dp) {
    Box(Modifier.size(size).clip(CircleShape).background(color.copy(alpha = 0.22f)), contentAlignment = Alignment.Center) {
        Icon(icon, contentDescription = null, tint = color, modifier = Modifier.size(size * 0.45f))
    }
}

fun txTypeLabel(t: TxType): Int = when (t) {
    TxType.EXPENSE -> R.string.tx_expense
    TxType.INCOME -> R.string.tx_income
    TxType.TRANSFER -> R.string.tx_transfer
    TxType.ADJUST -> R.string.tx_adjust
}

// MARK: importe grande con el teclado numérico

/**
 * El importe se ve siempre grande y al mismo tamaño; lo que se teclea va a un campo con el teclado
 * numérico del sistema (igual que en iPhone).
 */
@Composable
fun BigAmountField(
    digits: String,
    onChange: (String) -> Unit,
    color: Color,
    prefix: String = "",
    focusRequester: FocusRequester = remember { FocusRequester() },
    autoFocus: Boolean = false,
    modifier: Modifier = Modifier,
) {
    val f = LocalFmt.current
    val size = when {
        digits.length > 8 -> 44.sp
        digits.length > 6 -> 52.sp
        else -> 60.sp
    }
    val desc = stringResource(R.string.amount)
    LaunchedEffect(autoFocus) { if (autoFocus) runCatching { focusRequester.requestFocus() } }
    val style = TextStyle(fontSize = size, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurface, fontFeatureSettings = "tnum")
    Row(
        modifier.fillMaxWidth().clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) { runCatching { focusRequester.requestFocus() } }.padding(vertical = 8.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (prefix.isNotEmpty()) Text(prefix, style = style.copy(color = color))
        BasicTextField(
            value = digits,
            onValueChange = { onChange(Money.cleanInput(it)) },
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
            keyboardActions = KeyboardActions.Default,
            cursorBrush = SolidColor(color),
            textStyle = style,
            modifier = Modifier.width(IntrinsicSize.Min).focusRequester(focusRequester).semantics { contentDescription = desc },
            decorationBox = { inner ->
                Box(contentAlignment = Alignment.CenterStart) {
                    if (digits.isEmpty()) Text("0", style = style.copy(color = MaterialTheme.colorScheme.onSurfaceVariant))
                    inner()
                }
            },
        )
        Spacer(Modifier.width(6.dp))
        Text(f.symbol, style = style.copy(color = MaterialTheme.colorScheme.onSurfaceVariant))
    }
}

// MARK: elegir color y emoji

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun ColorRow(selected: String, onSelect: (String) -> Unit) {
    val h = rememberHaptics()
    FlowRow(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        PALETTE.forEach { hex ->
            val on = hex.equals(selected, ignoreCase = true)
            val desc = stringResource(R.string.color_option, hex)
            Box(
                Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .background(hexColor(hex))
                    .border(if (on) BorderStroke(3.dp, MaterialTheme.colorScheme.onSurface) else BorderStroke(0.dp, Color.Transparent), CircleShape)
                    .clickable(role = Role.RadioButton) { h.select(); onSelect(hex) }
                    .semantics { contentDescription = desc; this.selected = on },
                contentAlignment = Alignment.Center,
            ) { if (on) Icon(Icons.Filled.Check, null, tint = Color.Black.copy(alpha = 0.7f)) }
        }
    }
}

object Emojis {
    val groups: List<Pair<Int, String>> = listOf(
        R.string.emoji_food to "🛒🍎🥦🥖🧀🥩🍗🍔🍟🍕🌮🥗🍣🍜🍝🥐🍩🍪🍫🍦☕🧋🍺🍷🥂🍾🥤🧃",
        R.string.emoji_home to "🏠🏡🛋️🛏️🧹🧺🧼🪴💡🔌🔥💧🚿🧻🔑🛠️🔨🧰",
        R.string.emoji_transport to "🚗⛽🚕🚌🚇🚆✈️🛵🚲🛴🅿️🚙🏍️🚦🛞🧾",
        R.string.emoji_leisure to "🎮🎬🍿🎵🎧🎤🎟️🎳🎯🎲📚📖🎨📷🏖️🏕️🎉🎁🎂🎄",
        R.string.emoji_health to "💊🩺🦷👓💇💅🧴🪒🏋️🧘⚽🏀🎾🏊🚴",
        R.string.emoji_shopping to "👕👖👗👟👠🧥👜🎒💍⌚🕶️🛍️📦",
        R.string.emoji_tech to "📱💻🖥️⌨️📺🔋🖨️📡🌐☁️",
        R.string.emoji_money to "💶💰💳🏦📈📉🪙💸📊💼🏧",
        R.string.emoji_people to "👨‍👩‍👧👶🧒👫❤️🐶🐱🐾🎓🏫✏️",
        R.string.emoji_other to "⭐✅❗❓🔔📌📎🗂️🗓️⏰🚬🍀🎰🙏🚫",
    )

    /** separa una cadena en emojis sueltos (respetando los compuestos) */
    fun split(s: String): List<String> {
        val it = java.text.BreakIterator.getCharacterInstance()
        it.setText(s)
        val out = mutableListOf<String>()
        var start = it.first()
        var end = it.next()
        while (end != java.text.BreakIterator.DONE) { out += s.substring(start, end); start = end; end = it.next() }
        return out
    }
}

/** rejilla de emojis (con un campo para poner cualquier otro) */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun EmojiGrid(selected: String, onSelect: (String) -> Unit, compact: Boolean = true) {
    val h = rememberHaptics()
    var custom by remember { mutableStateOf("") }
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        val groups = if (compact) Emojis.groups.take(4) else Emojis.groups
        groups.forEach { (label, chars) ->
            if (!compact) Text(stringResource(label), style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
            FlowRow(horizontalArrangement = Arrangement.spacedBy(4.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Emojis.split(chars).let { if (compact) it.take(8) else it }.forEach { e ->
                    val on = e == selected
                    Box(
                        Modifier
                            .size(44.dp)
                            .clip(RoundedCornerShape(10.dp))
                            .background(if (on) MaterialTheme.colorScheme.primary.copy(alpha = 0.3f) else Color.Transparent)
                            .clickable(role = Role.RadioButton) { h.select(); onSelect(e) }
                            .semantics { this.selected = on },
                        contentAlignment = Alignment.Center,
                    ) { Text(e, fontSize = 24.sp) }
                }
            }
        }
        OutlinedTextField(
            value = custom,
            onValueChange = { v ->
                val last = Emojis.split(v).lastOrNull()
                if (last != null && last.codePointAt(0) > 0xFF) { onSelect(last); h.select() }
                custom = last ?: ""
            },
            label = { Text(stringResource(R.string.emoji_other_field)) },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

// MARK: confirmaciones

/** «¿Seguro que quieres…?»: todo lo que borra pasa por aquí */
@Composable
fun ConfirmDialog(
    title: String,
    message: String? = null,
    confirm: String = stringResource(R.string.delete),
    destructive: Boolean = true,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = message?.let { { Text(it) } },
        confirmButton = {
            TextButton(onClick = { onConfirm(); onDismiss() }) {
                Text(confirm, color = if (destructive) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold)
            }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) } },
    )
}

/** chip seleccionable redondo (filtros, tipos…) */
@Composable
fun Pill(text: String, selected: Boolean, onClick: () -> Unit, modifier: Modifier = Modifier, selectedColor: Color = MaterialTheme.colorScheme.primary) {
    val h = rememberHaptics()
    Box(
        modifier
            .clip(CircleShape)
            .background(if (selected) selectedColor else CaudalTheme.colors.card)
            .clickable(interactionSource = remember { MutableInteractionSource() }, indication = androidx.compose.material3.ripple(), role = Role.Tab) { h.select(); onClick() }
            .semantics { this.selected = selected }
            .heightIn(min = 40.dp)
            .padding(horizontal = 16.dp, vertical = 10.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text,
            style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.SemiBold,
            color = if (selected) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurface,
            maxLines = 1,
        )
    }
}

/** selector de opciones en una cápsula (gasto / ingreso / transferencia…) */
@Composable
fun SegmentedPills(options: List<String>, selected: Int, onSelect: (Int) -> Unit, colors: List<Color>? = null, modifier: Modifier = Modifier) {
    Row(
        modifier.fillMaxWidth().clip(CircleShape).background(CaudalTheme.colors.card).padding(4.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        options.forEachIndexed { i, label ->
            Pill(label, i == selected, { onSelect(i) }, Modifier.weight(1f), selectedColor = colors?.getOrNull(i) ?: MaterialTheme.colorScheme.primary)
        }
    }
}

/** texto vacío centrado */
@Composable
fun EmptyText(text: String, modifier: Modifier = Modifier) {
    Text(text, modifier = modifier.fillMaxWidth().padding(16.dp), color = MaterialTheme.colorScheme.onSurfaceVariant, textAlign = TextAlign.Center)
}
