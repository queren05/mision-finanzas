package es.david.caudal.ui.subs

import android.widget.Toast
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import es.david.caudal.R
import es.david.caudal.core.Money
import es.david.caudal.domain.calc.Subscriptions
import es.david.caudal.domain.model.Freq
import es.david.caudal.ui.common.AmountText
import es.david.caudal.ui.common.Card
import es.david.caudal.ui.common.EmptyState
import es.david.caudal.ui.common.FinanceViewModel
import es.david.caudal.ui.common.IconBubble
import es.david.caudal.ui.common.LocalFmt
import es.david.caudal.ui.common.Mood
import es.david.caudal.ui.common.Pill
import es.david.caudal.ui.common.ScreenScaffold
import es.david.caudal.ui.common.appear
import es.david.caudal.ui.common.rememberHaptics
import es.david.caudal.ui.theme.CaudalTheme

/** pagos que se repiten en tus gastos y aún no son recurrentes; se añaden con un toque */
@Composable
fun SubscriptionsScreen(nav: NavController) {
    val vm: FinanceViewModel = hiltViewModel()
    val ledger by vm.ledger.collectAsStateWithLifecycle()
    val l = ledger ?: return
    val f = LocalFmt.current
    val c = CaudalTheme.colors
    val h = rememberHaptics()
    val ctx = LocalContext.current
    val list = remember(l) { Subscriptions.detect(l.data.txs, l.data.recurring) }
    fun yearly(amount: Long, freq: Freq) = Money.fromCents(amount) * when (freq) { Freq.WEEKLY -> 52; Freq.MONTHLY -> 12; Freq.YEARLY -> 1 }
    ScreenScaffold(stringResource(R.string.f4_subs_title), onBack = { nav.popBackStack() }) { pad ->
        LazyColumn(
            Modifier.fillMaxSize(),
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = pad.calculateTopPadding() + 8.dp, bottom = 48.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            if (list.isEmpty()) {
                item { EmptyState(stringResource(R.string.f4_subs_none), mood = Mood.WINK) }
            } else {
                item {
                    Card(Modifier.appear(0)) {
                        Text(stringResource(R.string.f4_subs_total), style = MaterialTheme.typography.titleSmall, color = c.textDim)
                        AmountText(list.sumOf { yearly(it.amount, it.freq) }, style = MaterialTheme.typography.displaySmall, rolling = true)
                    }
                }
                item { Text(stringResource(R.string.f4_subs_detected), style = MaterialTheme.typography.titleLarge, modifier = Modifier.semantics { }) }
                itemsIndexed(list, key = { _, g -> g.title + g.freq }) { i, g ->
                    val cat = l.category(g.categoryId)
                    val freq = stringResource(when (g.freq) { Freq.WEEKLY -> R.string.f4_subs_weekly; Freq.MONTHLY -> R.string.f4_subs_monthly; Freq.YEARLY -> R.string.f4_subs_yearly })
                    Card(Modifier.appear(i + 1).semantics(mergeDescendants = true) {}) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            IconBubble(cat?.icon ?: "🔁", cat?.color ?: "#b39cff", 46.dp)
                            Spacer(Modifier.width(12.dp))
                            Column(Modifier.weight(1f)) {
                                Text(g.title, style = MaterialTheme.typography.bodyLarge, maxLines = 1, overflow = TextOverflow.Ellipsis)
                                Text(stringResource(R.string.f4_subs_row, f.money(g.amount), freq, g.count), style = MaterialTheme.typography.bodySmall, color = c.textDim)
                                Text(stringResource(R.string.f4_subs_next, f.header(g.next)), style = MaterialTheme.typography.bodySmall, color = c.textDim)
                            }
                            Column(horizontalAlignment = Alignment.End) {
                                Text(stringResource(R.string.f4_subs_yearly_cost, f.money(yearly(g.amount, g.freq))), style = MaterialTheme.typography.labelMedium, color = c.warning)
                            }
                        }
                        Spacer(Modifier.height(10.dp))
                        Pill(stringResource(R.string.f4_subs_add), false, {
                            h.success()
                            vm.run { save(g.toRecurring()) }
                            Toast.makeText(ctx, ctx.getString(R.string.f4_subs_added, g.title), Toast.LENGTH_SHORT).show()
                        })
                    }
                }
            }
        }
    }
}
