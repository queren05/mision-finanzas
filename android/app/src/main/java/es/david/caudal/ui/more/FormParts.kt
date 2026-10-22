package es.david.caudal.ui.more

import androidx.compose.foundation.background
import androidx.compose.animation.animateContentSize
import androidx.compose.foundation.border
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.SwitchDefaults
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.text.input.KeyboardCapitalization
import es.david.caudal.ui.common.IconTile
import es.david.caudal.ui.common.pressable
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import es.david.caudal.R
import es.david.caudal.core.Day
import es.david.caudal.ui.common.LocalFmt
import es.david.caudal.ui.common.rememberHaptics
import es.david.caudal.ui.theme.CaudalTheme
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset

// Piezas de formulario de las pantallas de Más e Inversiones (al estilo de los Form de iPhone)

/** grupo de filas dentro de una tarjeta redondeada (como los Form de iPhone), con título opcional encima */
@Composable
fun FormSection(title: String? = null, modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    val c = CaudalTheme.colors
    val shape = RoundedCornerShape(24.dp)
    Column(modifier.fillMaxWidth()) {
        if (title != null) {
            Text(
                title, style = MaterialTheme.typography.labelLarge, color = c.textDim,
                modifier = Modifier.padding(start = 16.dp, bottom = 8.dp).semantics { heading() },
            )
        }
        Column(
            Modifier.fillMaxWidth()
                .then(if (!c.dark) Modifier.shadow(10.dp, shape, ambientColor = c.accent.copy(alpha = 0.25f), spotColor = c.accent.copy(alpha = 0.18f)) else Modifier)
                .clip(shape).background(c.card)
                .then(if (c.dark) Modifier.border(1.dp, c.hairline, shape) else Modifier)
                .padding(horizontal = 16.dp, vertical = 4.dp)
                .animateContentSize(),
            content = content,
        )
    }
}

/** fila que lleva a otra pantalla: cuadradito de color con icono (como Ajustes de iPhone), texto y valor */
@Composable
fun NavRow(icon: ImageVector, color: Color, label: String, value: String = "", onClick: () -> Unit) {
    val h = rememberHaptics()
    Row(
        Modifier.fillMaxWidth().heightIn(min = 58.dp).pressable(0.98f) { h.tap(); onClick() }
            .semantics(mergeDescendants = true) {},
        verticalAlignment = Alignment.CenterVertically,
    ) {
        IconTile(icon, color)
        Spacer(Modifier.width(14.dp))
        Text(label, Modifier.weight(1f), style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
        if (value.isNotEmpty()) {
            Text(value, color = CaudalTheme.colors.textDim, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.padding(start = 8.dp))
        }
        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = CaudalTheme.colors.textDim.copy(alpha = 0.6f))
    }
}

/** fila con interruptor (todo el ancho se puede tocar); con icono de color opcional */
@Composable
fun SwitchRow(label: String, checked: Boolean, enabled: Boolean = true, icon: ImageVector? = null, iconColor: Color = CaudalTheme.colors.accent, subtitle: String? = null, onChange: (Boolean) -> Unit) {
    val h = rememberHaptics()
    val c = CaudalTheme.colors
    Row(
        Modifier.fillMaxWidth().heightIn(min = 58.dp)
            .clickable(enabled = enabled, role = Role.Switch) { h.select(); onChange(!checked) }
            .semantics(mergeDescendants = true) {},
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (icon != null) { IconTile(icon, iconColor); Spacer(Modifier.width(14.dp)) }
        Column(Modifier.weight(1f)) {
            Text(label, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Bold, color = if (enabled) c.text else c.textDim)
            if (subtitle != null) Text(subtitle, style = MaterialTheme.typography.bodySmall, color = c.textDim)
        }
        Spacer(Modifier.width(8.dp))
        Switch(
            checked = checked, onCheckedChange = null, enabled = enabled,
            colors = SwitchDefaults.colors(
                checkedThumbColor = Color.White, checkedTrackColor = c.accent, checkedBorderColor = c.accent,
                uncheckedThumbColor = Color.White, uncheckedTrackColor = c.cardAlt, uncheckedBorderColor = c.cardAlt,
            ),
        )
    }
}

/** fila con un desplegable de opciones (clave → texto) */
@Composable
fun <T> PickerRow(label: String, options: List<Pair<T, String>>, selected: T, onSelect: (T) -> Unit) {
    val h = rememberHaptics()
    var open by remember { mutableStateOf(false) }
    Box {
        Row(
            Modifier.fillMaxWidth().heightIn(min = 56.dp).clickable(role = Role.DropdownList) { open = true }
                .semantics(mergeDescendants = true) {},
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(label, Modifier.weight(1f), style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Bold)
            Text(
                options.firstOrNull { it.first == selected }?.second ?: "", color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold,
                maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false),
            )
            Icon(Icons.Filled.ArrowDropDown, null, tint = MaterialTheme.colorScheme.primary)
        }
        DropdownMenu(open, onDismissRequest = { open = false }, shape = RoundedCornerShape(20.dp), containerColor = CaudalTheme.colors.card) {
            options.forEach { (k, v) ->
                DropdownMenuItem(text = { Text(v, fontWeight = if (k == selected) FontWeight.Bold else null) }, onClick = { h.select(); onSelect(k); open = false })
            }
        }
    }
}

/** campo de texto de un formulario */
@Composable
fun FieldRow(label: String, value: String, onChange: (String) -> Unit, numeric: Boolean = false, singleLine: Boolean = true, placeholder: String? = null) {
    OutlinedTextField(
        value = value,
        onValueChange = onChange,
        label = { Text(label) },
        placeholder = placeholder?.let { { Text(it) } },
        singleLine = singleLine,
        keyboardOptions = if (numeric) KeyboardOptions(keyboardType = KeyboardType.Decimal) else KeyboardOptions(capitalization = KeyboardCapitalization.Sentences),
        shape = RoundedCornerShape(16.dp),
        colors = OutlinedTextFieldDefaults.colors(
            focusedBorderColor = CaudalTheme.colors.accent, unfocusedBorderColor = CaudalTheme.colors.hairline,
            focusedContainerColor = CaudalTheme.colors.cardAlt.copy(alpha = 0.5f), unfocusedContainerColor = CaudalTheme.colors.cardAlt.copy(alpha = 0.5f),
            focusedLabelColor = CaudalTheme.colors.accent,
        ),
        modifier = Modifier.fillMaxWidth().padding(vertical = 6.dp),
    )
}

/** separador fino entre filas */
@Composable
fun RowDivider() = HorizontalDivider(color = CaudalTheme.colors.hairline)

/** fila con una fecha (yyyy-MM-dd) que abre el calendario */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DateRow(label: String, date: String, onChange: (String) -> Unit) {
    val f = LocalFmt.current
    var open by remember { mutableStateOf(false) }
    Row(
        Modifier.fillMaxWidth().heightIn(min = 56.dp).clickable(role = Role.Button) { open = true }.semantics(mergeDescendants = true) {},
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, Modifier.weight(1f), style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Bold)
        Text(f.header(date), color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold)
    }
    if (open) {
        val state = rememberDatePickerState(initialSelectedDateMillis = Day.date(date).atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli())
        DatePickerDialog(
            onDismissRequest = { open = false },
            confirmButton = {
                TextButton(onClick = {
                    state.selectedDateMillis?.let { onChange(Day.str(Instant.ofEpochMilli(it).atZone(ZoneOffset.UTC).toLocalDate())) }
                    open = false
                }) { Text(stringResource(R.string.ok)) }
            },
            dismissButton = { TextButton(onClick = { open = false }) { Text(stringResource(R.string.cancel)) } },
        ) { DatePicker(state) }
    }
}

/** botones accesibles para subir o bajar una fila (modo «Ordenar») */
@Composable
fun MoveButtons(canUp: Boolean, canDown: Boolean, onUp: () -> Unit, onDown: () -> Unit) {
    Row {
        IconButton(onClick = onUp, enabled = canUp) { Icon(Icons.Filled.KeyboardArrowUp, stringResource(R.string.move_up)) }
        IconButton(onClick = onDown, enabled = canDown) { Icon(Icons.Filled.KeyboardArrowDown, stringResource(R.string.move_down)) }
    }
}

/** deslizar a la izquierda para borrar: no borra, pide confirmación (y la fila vuelve a su sitio) */
@Composable
fun SwipeToDelete(onDelete: () -> Unit, content: @Composable () -> Unit) {
    val scope = rememberCoroutineScope()
    val state = rememberSwipeToDismissBoxState()
    SwipeToDismissBox(
        state = state,
        enableDismissFromStartToEnd = false,
        onDismiss = { v ->
            if (v == SwipeToDismissBoxValue.EndToStart) onDelete()
            scope.launch { state.reset() }
        },
        backgroundContent = {
            Row(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(20.dp)).background(CaudalTheme.colors.negative).padding(horizontal = 20.dp),
                horizontalArrangement = Arrangement.End, verticalAlignment = Alignment.CenterVertically,
            ) { Icon(Icons.Filled.Delete, stringResource(R.string.delete), tint = MaterialTheme.colorScheme.onError, modifier = Modifier.size(24.dp)) }
        },
    ) { content() }
}

/** la fecha de hoy como LocalDate (para los selectores) */
fun todayDate(): LocalDate = Day.date(Day.today)
