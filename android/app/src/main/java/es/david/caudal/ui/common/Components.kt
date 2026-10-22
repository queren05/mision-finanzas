package es.david.caudal.ui.common

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
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
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
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
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
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
import es.david.caudal.ui.theme.LocalMotion
import es.david.caudal.ui.theme.hexColor

// MARK: vibración

/** si la vibración está activada en Ajustes */
val LocalHapticsOn = staticCompositionLocalOf { true }

/** si se enseña la mascota (ajuste) */
val LocalMascot = staticCompositionLocalOf { true }

class Haptics(private val h: androidx.compose.ui.hapticfeedback.HapticFeedback, private val on: Boolean) {
    private fun go(t: HapticFeedbackType) { if (on) h.performHapticFeedback(t) }
    fun tap() = go(HapticFeedbackType.ContextClick)
    fun select() = go(HapticFeedbackType.SegmentTick)
    fun success() = go(HapticFeedbackType.Confirm)
    fun warning() = go(HapticFeedbackType.Reject)
    fun heavy() = go(HapticFeedbackType.LongPress)
}

@Composable
fun rememberHaptics(): Haptics {
    val h = LocalHapticFeedback.current
    val on = LocalHapticsOn.current
    return remember(h, on) { Haptics(h, on) }
}

/** texto oscuro o claro según el fondo */
fun contentOn(bg: Color): Color = if (bg.luminance() > 0.42f) Color(0xFF1A1320) else Color.White

// MARK: tarjetas

/**
 * Tarjeta: cristal (translúcida con brillo), sólida o con contorno, según Personalizar.
 * En claro lleva una sombra suave del color de la app.
 */
@Composable
fun Card(modifier: Modifier = Modifier, padding: Dp = 18.dp, onClick: (() -> Unit)? = null, content: @Composable ColumnScope.() -> Unit) {
    val c = CaudalTheme.colors
    val st = es.david.caudal.ui.theme.LocalUiStyle.current
    val shape = RoundedCornerShape(st.r(26.dp))
    val glass = st.card == es.david.caudal.ui.theme.CardStyle.CRISTAL
    val outline = st.card == es.david.caudal.ui.theme.CardStyle.CONTORNO
    Column(
        modifier
            .fillMaxWidth()
            .then(if (onClick != null) Modifier.pressable(0.98f, onClick = onClick) else Modifier)
            .then(if (!c.dark && !outline) Modifier.shadow(12.dp, shape, ambientColor = c.accent.copy(alpha = 0.3f), spotColor = c.accent.copy(alpha = 0.22f)) else Modifier)
            .clip(shape)
            .then(
                when {
                    outline -> Modifier.border(1.5.dp, c.accent.copy(alpha = 0.45f), shape)
                    glass -> Modifier
                        .background(Brush.verticalGradient(listOf(lerp(c.card, Color.White, if (c.dark) 0.05f else 0.4f).copy(alpha = if (c.dark) 0.78f else 0.86f), c.card.copy(alpha = if (c.dark) 0.66f else 0.8f))))
                        .border(1.dp, Brush.verticalGradient(listOf(Color.White.copy(alpha = if (c.dark) 0.16f else 0.7f), Color.White.copy(alpha = if (c.dark) 0.03f else 0.2f))), shape)
                    else -> Modifier.background(c.card).then(if (c.dark) Modifier.border(1.dp, c.hairline, shape) else Modifier)
                },
            )
            .padding(st.s(padding))
            .animateContentSize(spring(dampingRatio = 0.85f, stiffness = Spring.StiffnessMediumLow)),
        content = content,
    )
}

/** grupo de filas dentro de una tarjeta, con separadores finos (como las listas de iPhone) */
@Composable
fun GroupCard(modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    Card(modifier, padding = 0.dp) { Column(Modifier.padding(vertical = 4.dp), content = content) }
}

/** separador fino con sangría para las filas de un grupo */
@Composable
fun RowDivider(start: Dp = 64.dp) {
    Box(Modifier.padding(start = start).fillMaxWidth().height(1.dp).background(CaudalTheme.colors.hairline))
}

/** cuadradito redondeado de color con un icono (las filas de Más, como Ajustes de iPhone) */
@Composable
fun IconTile(icon: ImageVector, color: Color, size: Dp = 34.dp) {
    Box(
        Modifier.size(size).clip(RoundedCornerShape(size * 0.32f)).background(Brush.verticalGradient(listOf(lerp(color, Color.White, 0.18f), color))),
        contentAlignment = Alignment.Center,
    ) { Icon(icon, null, tint = Color.White, modifier = Modifier.size(size * 0.58f)) }
}

/** fila de lista: icono, título (y subtítulo), valor a la derecha y flecha */
@Composable
fun ListRow(
    title: String,
    modifier: Modifier = Modifier,
    subtitle: String? = null,
    value: String? = null,
    leading: (@Composable () -> Unit)? = null,
    trailing: (@Composable () -> Unit)? = null,
    chevron: Boolean = true,
    titleColor: Color = Color.Unspecified,
    onClick: (() -> Unit)? = null,
) {
    Row(
        modifier
            .fillMaxWidth()
            .then(if (onClick != null) Modifier.pressable(0.985f, onClick = onClick) else Modifier)
            .heightIn(min = 56.dp)
            .padding(horizontal = 16.dp, vertical = 10.dp)
            .semantics(mergeDescendants = true) {},
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (leading != null) { leading(); Spacer(Modifier.width(14.dp)) }
        Column(Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Bold, color = titleColor, maxLines = 1, overflow = TextOverflow.Ellipsis)
            if (subtitle != null) Text(subtitle, style = MaterialTheme.typography.bodySmall, color = CaudalTheme.colors.textDim, maxLines = 2, overflow = TextOverflow.Ellipsis)
        }
        if (value != null) Text(value, style = MaterialTheme.typography.bodyMedium, color = CaudalTheme.colors.textDim, modifier = Modifier.padding(start = 8.dp))
        if (trailing != null) { Spacer(Modifier.width(8.dp)); trailing() }
        if (chevron && onClick != null) Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = CaudalTheme.colors.textDim.copy(alpha = 0.6f))
    }
}

/** cabecera de las tarjetas: título y, si hay, una acción a la derecha */
@Composable
fun SectionHeader(title: String, action: String? = null, onAction: (() -> Unit)? = null, emoji: String? = null) {
    val h = rememberHaptics()
    Row(Modifier.fillMaxWidth().heightIn(min = 36.dp), verticalAlignment = Alignment.CenterVertically) {
        if (emoji != null) { Text(emoji, fontSize = 20.sp); Spacer(Modifier.width(8.dp)) }
        Text(title, style = MaterialTheme.typography.titleLarge, modifier = Modifier.weight(1f).semantics { heading() })
        if (action != null && onAction != null) {
            Text(
                action, style = MaterialTheme.typography.labelLarge, color = CaudalTheme.colors.accent,
                modifier = Modifier.clip(CircleShape).pressable { h.tap(); onAction() }.background(CaudalTheme.colors.accent.copy(alpha = 0.14f)).padding(horizontal = 12.dp, vertical = 7.dp),
            )
        }
    }
}

/** título pequeño encima de un grupo («Gestión», «Ajustes»…) */
@Composable
fun GroupLabel(text: String, modifier: Modifier = Modifier) {
    Text(text, style = MaterialTheme.typography.labelLarge, color = CaudalTheme.colors.textDim, modifier = modifier.padding(start = 16.dp, top = 8.dp, bottom = 6.dp).semantics { heading() })
}

/** botón redondo de la barra de arriba (como los de iPhone) */
@Composable
fun CircleIconButton(icon: ImageVector, description: String, modifier: Modifier = Modifier, tint: Color = CaudalTheme.colors.text, onClick: () -> Unit) {
    val h = rememberHaptics()
    Box(
        modifier
            .padding(4.dp)
            .size(44.dp)
            .clip(CircleShape)
            .background(CaudalTheme.colors.card)
            .border(1.dp, CaudalTheme.colors.hairline, CircleShape)
            .pressable(0.88f) { h.tap(); onClick() }
            .semantics { contentDescription = description },
        contentAlignment = Alignment.Center,
    ) { Icon(icon, null, tint = tint, modifier = Modifier.size(22.dp)) }
}

// MARK: importes

/** importe que se oculta con el ojo; si `rolling`, las cifras ruedan al cambiar */
@Composable
fun AmountText(
    value: Double,
    modifier: Modifier = Modifier,
    signed: Boolean = false,
    style: TextStyle = MaterialTheme.typography.bodyLarge,
    color: Color = Color.Unspecified,
    weight: FontWeight? = null,
    rolling: Boolean = false,
) {
    val f = LocalFmt.current
    val text = if (signed) f.signed(value) else f.money(value)
    val st = style.copy(fontFeatureSettings = "tnum")
    if (rolling) RollingText(text, st, color, weight, modifier)
    else Text(text, modifier = modifier, style = st, color = color, fontWeight = weight, maxLines = 1, overflow = TextOverflow.Ellipsis)
}

/** cuadradito redondeado con el emoji de la categoría o la cuenta */
@Composable
fun IconBubble(icon: String, color: String, size: Dp = 44.dp, modifier: Modifier = Modifier) {
    val c = hexColor(color)
    Box(
        modifier
            .size(size)
            .clip(RoundedCornerShape(size * 0.36f))
            .background(Brush.linearGradient(listOf(c.copy(alpha = 0.38f), c.copy(alpha = 0.16f)))),
        contentAlignment = Alignment.Center,
    ) { Text(icon, fontSize = (size.value * 0.46f).sp) }
}

/** barra de progreso redondeada con brillo, que se llena al aparecer */
@Composable
fun ProgressBar(value: Double, color: Color, modifier: Modifier = Modifier, height: Dp = 10.dp) {
    val motion = LocalMotion.current
    var started by remember { mutableStateOf(!motion) }
    LaunchedEffect(Unit) { started = true }
    val shown by animateFloatAsState(if (started) value.coerceIn(0.0, 1.0).toFloat() else 0f, spring(dampingRatio = 0.75f, stiffness = Spring.StiffnessVeryLow), label = "progreso")
    Box(modifier.fillMaxWidth().height(height).clip(CircleShape).background(CaudalTheme.colors.cardAlt)) {
        if (shown > 0.001f) {
            Box(
                Modifier.fillMaxWidth(shown.coerceAtLeast(0.03f)).fillMaxHeight().clip(CircleShape)
                    .background(Brush.horizontalGradient(listOf(lerp(color, Color.White, 0.25f), color))),
            ) {
                Box(Modifier.padding(horizontal = 4.dp, vertical = 2.dp).fillMaxWidth().height(height * 0.28f).clip(CircleShape).background(Color.White.copy(alpha = 0.28f)))
            }
        }
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
        TxType.ADJUST -> if (tx.amount >= 0) colors.income else colors.text
        TxType.TRANSFER -> colors.textDim
        else -> colors.text
    }
    Row(
        modifier
            .fillMaxWidth()
            .then(if (onClick != null) Modifier.pressable(0.985f, onClick = onClick) else Modifier)
            .heightIn(min = 64.dp)
            .padding(horizontal = 14.dp, vertical = 8.dp)
            .semantics(mergeDescendants = true) {},
        verticalAlignment = Alignment.CenterVertically,
    ) {
        when (tx.type) {
            TxType.TRANSFER -> SymbolBubble(Icons.AutoMirrored.Filled.CompareArrows, colors.transfer)
            TxType.ADJUST -> SymbolBubble(Icons.Filled.Tune, colors.textDim)
            else -> IconBubble(cat?.icon ?: "❔", cat?.color ?: "#a9b3c2")
        }
        Spacer(Modifier.width(14.dp))
        Column(Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.ExtraBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(parts.joinToString(" · "), style = MaterialTheme.typography.bodySmall, color = colors.textDim, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        Spacer(Modifier.width(8.dp))
        Column(horizontalAlignment = Alignment.End) {
            AmountText(shown, signed = tx.type == TxType.INCOME || (tx.type == TxType.ADJUST && shown > 0), color = amountColor, weight = FontWeight.ExtraBold)
            if (tx.excluded) Text(stringResource(R.string.tx_excluded_short), style = MaterialTheme.typography.labelSmall, color = colors.textDim)
        }
    }
}

@Composable
fun SymbolBubble(icon: ImageVector, color: Color, size: Dp = 44.dp) {
    Box(Modifier.size(size).clip(RoundedCornerShape(size * 0.36f)).background(color.copy(alpha = 0.2f)), contentAlignment = Alignment.Center) {
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
 * El importe se ve siempre grande; lo que se teclea va a un campo con el teclado numérico del sistema
 * (igual que en iPhone). El signo y la moneda van pegados al número.
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
        digits.length > 8 -> 46.sp
        digits.length > 6 -> 54.sp
        else -> 64.sp
    }
    val desc = stringResource(R.string.amount)
    LaunchedEffect(autoFocus) { if (autoFocus) runCatching { focusRequester.requestFocus() } }
    val style = MaterialTheme.typography.displayLarge.copy(fontSize = size, color = CaudalTheme.colors.text, fontFeatureSettings = "tnum")
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
                    if (digits.isEmpty()) Text("0", style = style.copy(color = CaudalTheme.colors.textDim.copy(alpha = 0.5f)))
                    inner()
                }
            },
        )
        Spacer(Modifier.width(6.dp))
        Text(f.symbol, style = style.copy(color = CaudalTheme.colors.textDim.copy(alpha = 0.7f)))
    }
}

// MARK: elegir color y emoji

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun ColorRow(selected: String, palette: List<String> = PALETTE, onSelect: (String) -> Unit) {
    val h = rememberHaptics()
    FlowRow(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        palette.forEach { hex ->
            val on = hex.equals(selected, ignoreCase = true)
            val desc = stringResource(R.string.color_option, hex)
            val ring by animateDpAsState(if (on) 3.dp else 0.dp, spring(dampingRatio = 0.5f), label = "anillo")
            Box(
                Modifier
                    .size(44.dp)
                    .clip(CircleShape)
                    .background(hexColor(hex))
                    .border(BorderStroke(ring, CaudalTheme.colors.text), CircleShape)
                    .pressable(0.85f, role = Role.RadioButton) { h.select(); onSelect(hex) }
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
            if (!compact) Text(stringResource(label), style = MaterialTheme.typography.labelLarge, color = CaudalTheme.colors.textDim)
            FlowRow(horizontalArrangement = Arrangement.spacedBy(4.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Emojis.split(chars).let { if (compact) it.take(8) else it }.forEach { e ->
                    val on = e == selected
                    Box(
                        Modifier
                            .size(46.dp)
                            .clip(RoundedCornerShape(14.dp))
                            .background(if (on) CaudalTheme.colors.accent.copy(alpha = 0.3f) else Color.Transparent)
                            .pressable(0.8f, role = Role.RadioButton) { h.select(); onSelect(e) }
                            .semantics { this.selected = on },
                        contentAlignment = Alignment.Center,
                    ) { Text(e, fontSize = 26.sp) }
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
            shape = RoundedCornerShape(16.dp),
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
        shape = RoundedCornerShape(28.dp),
        containerColor = CaudalTheme.colors.card,
        title = { Text(title, style = MaterialTheme.typography.titleLarge) },
        text = message?.let { { Text(it, color = CaudalTheme.colors.textDim) } },
        confirmButton = {
            TextButton(onClick = { onConfirm(); onDismiss() }) {
                Text(confirm, color = if (destructive) CaudalTheme.colors.negative else CaudalTheme.colors.accent, fontWeight = FontWeight.ExtraBold)
            }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel), color = CaudalTheme.colors.text) } },
    )
}

/** chip seleccionable redondo (filtros, meses…) */
@Composable
fun Pill(text: String, selected: Boolean, onClick: () -> Unit, modifier: Modifier = Modifier, selectedColor: Color = CaudalTheme.colors.accent) {
    val h = rememberHaptics()
    val bg by animateColorAsState(if (selected) selectedColor else CaudalTheme.colors.card, spring(stiffness = Spring.StiffnessMediumLow), label = "pill")
    Box(
        modifier
            .clip(CircleShape)
            .background(bg)
            .then(if (!selected) Modifier.border(1.dp, CaudalTheme.colors.hairline, CircleShape) else Modifier)
            .pressable(0.92f, role = Role.Tab) { h.select(); onClick() }
            .semantics { this.selected = selected }
            .heightIn(min = 40.dp)
            .padding(horizontal = 16.dp, vertical = 10.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(text, style = MaterialTheme.typography.labelLarge, color = if (selected) contentOn(selectedColor) else CaudalTheme.colors.text, maxLines = 1)
    }
}

/** selector en cápsula con un indicador que se desliza (gasto / ingreso / transferencia…) */
@Composable
fun SegmentedPills(options: List<String>, selected: Int, onSelect: (Int) -> Unit, colors: List<Color>? = null, modifier: Modifier = Modifier) {
    val h = rememberHaptics()
    val c = CaudalTheme.colors
    val selColor by animateColorAsState(colors?.getOrNull(selected) ?: c.accent, label = "segmento")
    BoxWithConstraints(modifier.fillMaxWidth().clip(CircleShape).background(c.card).border(1.dp, c.hairline, CircleShape).padding(4.dp)) {
        val w = maxWidth / options.size.coerceAtLeast(1)
        val x by animateDpAsState(w * selected, spring(dampingRatio = 0.72f, stiffness = Spring.StiffnessMediumLow), label = "deslizar")
        Box(Modifier.offset(x = x).width(w).height(44.dp).clip(CircleShape).background(selColor))
        Row(Modifier.fillMaxWidth()) {
            options.forEachIndexed { i, label ->
                val on = i == selected
                Box(
                    Modifier.weight(1f).height(44.dp).clip(CircleShape)
                        .clickable(remember { MutableInteractionSource() }, null, role = Role.Tab) { h.select(); onSelect(i) }
                        .semantics { this.selected = on },
                    contentAlignment = Alignment.Center,
                ) { Text(label, style = MaterialTheme.typography.labelLarge, color = if (on) contentOn(selColor) else c.text, maxLines = 1) }
            }
        }
    }
}

/** estado vacío con Gotita y un mensaje cariñoso */
@Composable
fun EmptyState(title: String, text: String? = null, mood: Mood = Mood.SLEEPY, modifier: Modifier = Modifier, action: (@Composable () -> Unit)? = null) {
    Column(modifier.fillMaxWidth().padding(vertical = 28.dp, horizontal = 16.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
        if (LocalMascot.current) Gotita(mood, 92.dp)
        Text(title, style = MaterialTheme.typography.titleMedium, textAlign = TextAlign.Center)
        if (text != null) Text(text, style = MaterialTheme.typography.bodyMedium, color = CaudalTheme.colors.textDim, textAlign = TextAlign.Center)
        action?.invoke()
    }
}

/** texto vacío centrado */
@Composable
fun EmptyText(text: String, modifier: Modifier = Modifier) {
    Text(text, modifier = modifier.fillMaxWidth().padding(16.dp), color = CaudalTheme.colors.textDim, textAlign = TextAlign.Center)
}

/**
 * Fondo de la cabecera de las pantallas según Personalizar: agua (olas suaves y brillo),
 * brillo, puntos o liso.
 */
@Composable
fun GlowBackground(color: Color, modifier: Modifier = Modifier) {
    val st = es.david.caudal.ui.theme.LocalUiStyle.current
    val motion = es.david.caudal.ui.theme.LocalMotion.current
    val phase = remember { androidx.compose.animation.core.Animatable(0f) }
    if (st.backdrop == es.david.caudal.ui.theme.BackdropStyle.AGUA && motion) {
        // las olas se mecen unos segundos al entrar y se quedan quietas
        LaunchedEffect(Unit) { phase.animateTo(1f, androidx.compose.animation.core.tween(5000, easing = androidx.compose.animation.core.LinearOutSlowInEasing)) }
    }
    Canvas(modifier) {
        val w = size.width
        val h = size.height
        if (st.backdrop != es.david.caudal.ui.theme.BackdropStyle.LISO && st.backdrop != es.david.caudal.ui.theme.BackdropStyle.PUNTOS) {
            val r1 = w * 0.9f
            drawCircle(Brush.radialGradient(listOf(color.copy(alpha = 0.30f), Color.Transparent), center = Offset(w * 0.12f, 0f), radius = r1), r1, Offset(w * 0.12f, 0f))
            val r2 = w * 0.7f
            val c2 = Offset(w * 0.98f, h * 0.12f)
            drawCircle(Brush.radialGradient(listOf(color.copy(alpha = 0.16f), Color.Transparent), center = c2, radius = r2), r2, c2)
        }
        when (st.backdrop) {
            es.david.caudal.ui.theme.BackdropStyle.AGUA -> {
                // dos capas de olas en la parte de arriba
                listOf(Triple(0.42f, 0.10f, 1.0f), Triple(0.5f, 0.07f, 1.6f)).forEachIndexed { i, (yk, a, k) ->
                    val path = androidx.compose.ui.graphics.Path()
                    val base = h * yk
                    val amp = h * 0.035f
                    val shift = phase.value * 2f * kotlin.math.PI.toFloat() * (if (i == 0) 1 else -1)
                    path.moveTo(0f, 0f)
                    path.lineTo(0f, base)
                    var x = 0f
                    while (x <= w) {
                        path.lineTo(x, base + amp * kotlin.math.sin(x / w * 2f * kotlin.math.PI.toFloat() * k + shift))
                        x += 8f
                    }
                    path.lineTo(w, 0f)
                    path.close()
                    drawPath(path, Brush.verticalGradient(listOf(color.copy(alpha = a), color.copy(alpha = a * 0.4f)), startY = 0f, endY = base + amp))
                }
            }
            es.david.caudal.ui.theme.BackdropStyle.PUNTOS -> {
                val step = 22.dp.toPx()
                var y = step / 2
                while (y < h) {
                    val fade = (1f - y / h).coerceIn(0f, 1f)
                    var x = step / 2 + (if (((y / step).toInt()) % 2 == 0) 0f else step / 2)
                    while (x < w) { drawCircle(color.copy(alpha = 0.22f * fade), 1.6.dp.toPx(), Offset(x, y)); x += step }
                    y += step
                }
            }
            else -> Unit
        }
    }
}
