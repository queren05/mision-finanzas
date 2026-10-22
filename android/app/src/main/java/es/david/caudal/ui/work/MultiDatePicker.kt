package es.david.caudal.ui.work

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.getValue
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import es.david.caudal.R
import es.david.caudal.core.Day
import es.david.caudal.ui.common.LocalFmt
import es.david.caudal.ui.common.rememberHaptics
import java.time.DayOfWeek
import java.time.YearMonth
import java.time.format.TextStyle

/**
 * Calendario para elegir varios días (Material 3 no tiene uno de selección múltiple).
 * Semanas que empiezan en lunes; `selected` son fechas yyyy-MM-dd.
 */
@Composable
fun MultiDatePicker(selected: Set<String>, onChange: (Set<String>) -> Unit) {
    val f = LocalFmt.current
    val h = rememberHaptics()
    var month by rememberSaveable { mutableStateOf(Day.monthKey(Day.today)) }
    val ym = YearMonth.parse(month)
    val first = ym.atDay(1)
    val lead = (first.dayOfWeek.value - DayOfWeek.MONDAY.value)
    val cells = List(lead) { null } + (1..ym.lengthOfMonth()).map { ym.atDay(it) }
    val today = Day.today
    val accent = MaterialTheme.colorScheme.primary

    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        MonthBar(f.monthYear("$month-01"), { h.select(); month = Day.monthKey(Day.addMonths("$month-01", -1)) }, { h.select(); month = Day.monthKey(Day.addMonths("$month-01", 1)) })
        Row(Modifier.fillMaxWidth()) {
            DayOfWeek.entries.forEach { d ->
                Text(
                    d.getDisplayName(TextStyle.NARROW, f.locale).uppercase(f.locale),
                    Modifier.weight(1f), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                )
            }
        }
        cells.chunked(7).forEach { week ->
            Row(Modifier.fillMaxWidth()) {
                week.forEach { d ->
                    Box(Modifier.weight(1f).aspectRatio(1f).padding(2.dp), contentAlignment = Alignment.Center) {
                        if (d != null) {
                            val s = Day.str(d)
                            val on = s in selected
                            val desc = if (on) stringResource(R.string.shift_day_selected, f.header(s)) else f.header(s)
                            val sc by androidx.compose.animation.core.animateFloatAsState(if (on) 1f else 0.86f, androidx.compose.animation.core.spring(dampingRatio = 0.45f), label = "día")
                            Box(
                                Modifier.fillMaxWidth().aspectRatio(1f).graphicsLayer { scaleX = sc; scaleY = sc }.clip(RoundedCornerShape(12.dp))
                                    .background(if (on) accent else es.david.caudal.ui.theme.CaudalTheme.colors.cardAlt)
                                    .then(if (s == today && !on) Modifier.border(2.dp, accent, RoundedCornerShape(12.dp)) else Modifier)
                                    .clickable(role = Role.Checkbox) { h.select(); onChange(if (on) selected - s else selected + s) }
                                    .semantics { this.selected = on; contentDescription = desc },
                                contentAlignment = Alignment.Center,
                            ) {
                                Text(
                                    "${d.dayOfMonth}",
                                    color = if (on) es.david.caudal.ui.common.contentOn(accent) else MaterialTheme.colorScheme.onSurface,
                                    fontWeight = if (on || s == today) FontWeight.Black else FontWeight.SemiBold,
                                )
                            }
                        }
                    }
                }
                repeat(7 - week.size) { Box(Modifier.weight(1f)) }
            }
        }
    }
}
