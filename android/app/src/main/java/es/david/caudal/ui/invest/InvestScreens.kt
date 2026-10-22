package es.david.caudal.ui.invest

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import es.david.caudal.R
import es.david.caudal.core.Day
import es.david.caudal.core.Money
import es.david.caudal.domain.calc.Ledger
import es.david.caudal.domain.model.AccountType
import es.david.caudal.domain.model.Asset
import es.david.caudal.domain.model.AssetOp
import es.david.caudal.domain.model.OpSide
import es.david.caudal.domain.model.PALETTE
import es.david.caudal.ui.charts.LineChart
import es.david.caudal.ui.common.AmountText
import es.david.caudal.ui.common.Card
import es.david.caudal.ui.common.ColorRow
import es.david.caudal.ui.common.ConfirmDialog
import es.david.caudal.ui.common.EditorScaffold
import es.david.caudal.ui.common.EmptyText
import es.david.caudal.ui.common.FinanceViewModel
import es.david.caudal.ui.common.LocalFmt
import es.david.caudal.ui.common.ScreenScaffold
import es.david.caudal.ui.common.SegmentedPills
import es.david.caudal.ui.common.rememberHaptics
import es.david.caudal.ui.more.DateRow
import es.david.caudal.ui.more.FieldRow
import es.david.caudal.ui.more.FormSection
import es.david.caudal.ui.more.PickerRow
import es.david.caudal.ui.more.RowDivider
import es.david.caudal.ui.more.SwitchRow
import es.david.caudal.ui.nav.AssetDetailRoute
import es.david.caudal.ui.nav.AssetEditorRoute
import es.david.caudal.ui.nav.InvestRoute
import es.david.caudal.ui.nav.OpEditorRoute
import es.david.caudal.ui.theme.CaudalTheme
import es.david.caudal.ui.theme.hexColor
import kotlin.math.max

/*
 * Inversiones con precio a mano. Hoy no hay red: PriceProvider es ManualPriceProvider (isLive = false).
 * Cuando haya un proveedor con licencia, se conecta en di/AppModule (BindingsModule.prices) y las cotizaciones
 * llegan a la tabla quotes; Ledger.price() ya usa la cotización si existe y si no el precio manual.
 */

private fun listPadding(pad: androidx.compose.foundation.layout.PaddingValues) =
    androidx.compose.foundation.layout.PaddingValues(start = 16.dp, end = 16.dp, top = pad.calculateTopPadding() + 8.dp, bottom = pad.calculateBottomPadding() + 32.dp)

fun opSideLabel(s: OpSide): Int = when (s) {
    OpSide.BUY -> R.string.invest_side_buy
    OpSide.SELL -> R.string.invest_side_sell
    OpSide.REWARD -> R.string.invest_side_reward
}

// MARK: cartera

@Composable
fun InvestScreen(nav: NavController) {
    val vm: FinanceViewModel = hiltViewModel()
    val ledger by vm.ledger.collectAsStateWithLifecycle()
    val l = ledger ?: return
    val f = LocalFmt.current
    val colors = CaudalTheme.colors
    val assets = l.data.assets.filter { !it.archived }.sortedByDescending { l.assetValue(it) }
    ScreenScaffold(
        stringResource(R.string.invest_title),
        actions = { IconButton(onClick = { nav.navigate(AssetEditorRoute()) }) { Icon(Icons.Filled.Add, stringResource(R.string.invest_new)) } },
    ) { pad ->
        LazyColumn(contentPadding = listPadding(pad), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            item {
                val value = l.investValue
                val cost = l.investCost
                val gain = value - cost
                val pct = if (cost > 0) gain / cost * 100 else 0.0
                val today = l.investToday
                Card(Modifier.semantics(mergeDescendants = true) {}, padding = 20.dp) {
                    Text(stringResource(R.string.invest_portfolio), style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    AmountText(value, style = MaterialTheme.typography.displaySmall, weight = FontWeight.Bold)
                    Spacer(Modifier.height(8.dp))
                    Row {
                        Column(Modifier.weight(1f)) {
                            Text(stringResource(R.string.invest_return), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                AmountText(gain, signed = true, style = MaterialTheme.typography.titleMedium, color = if (gain >= 0) colors.income else colors.negative)
                                Spacer(Modifier.width(6.dp))
                                Text(f.pct(pct), style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Bold, color = if (gain >= 0) colors.income else colors.negative)
                            }
                        }
                        Column(horizontalAlignment = Alignment.End) {
                            Text(stringResource(R.string.invest_today), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            AmountText(today, signed = true, style = MaterialTheme.typography.titleMedium, color = if (today >= 0) colors.income else colors.negative)
                        }
                    }
                    Spacer(Modifier.height(6.dp))
                    Text(stringResource(R.string.invest_invested, f.money(cost)), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            if (assets.isNotEmpty()) item { Allocation(assets, l) }
            items(assets, key = { it.id }) { a -> AssetRow(a, l) { nav.navigate(AssetDetailRoute(a.id)) } }
            if (assets.isEmpty()) item { EmptyText(stringResource(R.string.invest_empty)) }
        }
    }
}

@Composable
private fun Allocation(assets: List<Asset>, l: Ledger) {
    val f = LocalFmt.current
    val total = max(l.investValue, 0.01)
    Card {
        Text(stringResource(R.string.invest_allocation), style = MaterialTheme.typography.titleMedium)
        Spacer(Modifier.height(10.dp))
        Row(Modifier.fillMaxWidth().height(14.dp).clip(CircleShape), horizontalArrangement = Arrangement.spacedBy(3.dp)) {
            assets.forEach { a ->
                val w = (l.assetValue(a) / total).toFloat()
                if (w > 0f) Box(Modifier.weight(w).height(14.dp).background(hexColor(a.color)))
            }
        }
        Spacer(Modifier.height(10.dp))
        assets.forEach { a ->
            Row(Modifier.fillMaxWidth().padding(vertical = 4.dp).semantics(mergeDescendants = true) {}, verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.size(10.dp).clip(CircleShape).background(hexColor(a.color)))
                Spacer(Modifier.width(8.dp))
                Text(a.name, Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text("${f.num(l.assetValue(a) / total * 100)} %", fontWeight = FontWeight.SemiBold)
            }
        }
    }
}

@Composable
private fun AssetRow(a: Asset, l: Ledger, onClick: () -> Unit) {
    val f = LocalFmt.current
    val colors = CaudalTheme.colors
    val pos = l.position(a)
    val value = l.assetValue(a)
    val gain = value - pos.cost
    val c = hexColor(a.color)
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(20.dp)).background(colors.card)
            .clickable(role = Role.Button, onClick = onClick).padding(14.dp).semantics(mergeDescendants = true) {},
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.size(48.dp).clip(RoundedCornerShape(14.dp)).background(c.copy(alpha = 0.25f)), contentAlignment = Alignment.Center) {
            Text(a.symbol.take(4), style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Black, color = c)
        }
        Spacer(Modifier.width(14.dp))
        Column(Modifier.weight(1f)) {
            Text(a.name, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Row {
                Text(f.money(l.price(a)), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                l.dayChange(a)?.let { ch ->
                    Spacer(Modifier.width(6.dp))
                    Text(f.pct(ch), style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.SemiBold, color = if (ch >= 0) colors.income else colors.negative)
                }
            }
        }
        Column(horizontalAlignment = Alignment.End) {
            AmountText(value, weight = FontWeight.Bold)
            AmountText(gain, signed = true, style = MaterialTheme.typography.bodySmall, color = if (gain >= 0) colors.income else colors.negative, weight = FontWeight.SemiBold)
        }
    }
}

// MARK: detalle de un activo

@Composable
fun AssetDetailScreen(id: String, nav: NavController) {
    val vm: FinanceViewModel = hiltViewModel()
    val ledger by vm.ledger.collectAsStateWithLifecycle()
    val l = ledger ?: return
    val f = LocalFmt.current
    val h = rememberHaptics()
    val colors = CaudalTheme.colors
    var updating by remember { mutableStateOf(false) }
    var newPrice by remember { mutableStateOf("") }
    var pendingDelete by remember { mutableStateOf<AssetOp?>(null) }
    var selected by remember { mutableStateOf<Int?>(null) }
    val a = l.asset(id)
    ScreenScaffold(
        a?.symbol ?: stringResource(R.string.invest_deleted),
        onBack = { nav.popBackStack() },
        large = false,
        actions = { if (a != null) IconButton(onClick = { nav.navigate(AssetEditorRoute(a.id)) }) { Icon(Icons.Filled.Edit, stringResource(R.string.invest_edit)) } },
    ) { pad ->
        if (a == null) { EmptyText(stringResource(R.string.invest_deleted), Modifier.padding(pad)); return@ScreenScaffold }
        val pos = l.position(a)
        val value = l.assetValue(a)
        // precios conocidos: los de las operaciones y el actual (sin proveedor de precios no hay histórico)
        val points = (a.ops.sortedBy { it.date }.filter { it.price > 0 }.map { it.date to it.price } + (Day.today to l.price(a)))
        val shown = selected?.let { points.getOrNull(it) }
        val first = points.firstOrNull()?.second ?: l.price(a)
        val last = shown?.second ?: l.price(a)
        val ch = (last / max(first, 0.0001) - 1) * 100
        val c = hexColor(a.color)
        LazyColumn(contentPadding = listPadding(pad), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            item {
                Card {
                    Text(a.name, style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text(f.money(last), style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
                    Text(
                        (shown?.let { f.header(it.first) + " · " } ?: "") + f.pct(ch),
                        fontWeight = FontWeight.SemiBold, color = if (ch >= 0) colors.income else colors.negative,
                    )
                    Spacer(Modifier.height(10.dp))
                    if (points.size >= 2) {
                        LineChart(points.map { it.second }, c, selected = selected, description = stringResource(R.string.invest_chart, a.name)) { selected = it }
                    }
                    Spacer(Modifier.height(10.dp))
                    FilledTonalButton(onClick = { newPrice = Money.editText(Money.toCents(l.price(a))); updating = true }, modifier = Modifier.fillMaxWidth()) {
                        Text(stringResource(R.string.invest_update_price))
                    }
                }
            }
            item {
                FormSection {
                    DataRow(stringResource(R.string.invest_value), f.money(value))
                    RowDivider()
                    DataRow(stringResource(R.string.invest_units), f.numFree(pos.qty))
                    RowDivider()
                    DataRow(stringResource(R.string.invest_avg_price), f.money(if (pos.qty > 0) pos.cost / pos.qty else 0.0))
                    RowDivider()
                    DataRow(stringResource(R.string.invest_cost), f.money(pos.cost))
                    RowDivider()
                    DataRow(stringResource(R.string.invest_gain), "${f.signed(value - pos.cost)} (${f.pct(if (pos.cost > 0) (value / pos.cost - 1) * 100 else 0.0)})")
                    if (pos.realized != 0.0) { RowDivider(); DataRow(stringResource(R.string.invest_realized), f.signed(pos.realized)) }
                    if (a.isin.isNotEmpty()) { RowDivider(); DataRow(stringResource(R.string.invest_isin), a.isin) }
                    RowDivider()
                    DataRow(stringResource(R.string.invest_symbol), a.symbol)
                }
            }
            item {
                Row(Modifier.fillMaxWidth().padding(top = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(stringResource(R.string.invest_ops), style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
                    IconButton(onClick = { nav.navigate(OpEditorRoute(a.id)) }) { Icon(Icons.Filled.Add, stringResource(R.string.invest_new_op)) }
                }
            }
            items(a.ops.sortedByDescending { it.date }, key = { it.id }) { op ->
                Row(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(colors.card)
                        .clickable(role = Role.Button) { nav.navigate(OpEditorRoute(a.id, op.id)) }
                        .heightIn(min = 60.dp).padding(start = 14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(Modifier.weight(1f).semantics(mergeDescendants = true) {}) {
                        Text(stringResource(R.string.invest_op_line, stringResource(opSideLabel(op.side)), f.numFree(op.qty)), fontWeight = FontWeight.SemiBold)
                        Text(stringResource(R.string.invest_op_sub, f.header(op.date), f.money(op.price)), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    IconButton(onClick = { h.warning(); pendingDelete = op }) {
                        Icon(Icons.Filled.Delete, stringResource(R.string.invest_op_delete), tint = MaterialTheme.colorScheme.error)
                    }
                }
            }
        }
    }
    if (updating && a != null) {
        AlertDialog(
            onDismissRequest = { updating = false },
            title = { Text(stringResource(R.string.invest_update_price)) },
            text = {
                OutlinedTextField(newPrice, { newPrice = it.filter { c -> c.isDigit() || c == ',' || c == '.' } }, label = { Text(stringResource(R.string.invest_price_now)) },
                    singleLine = true, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal))
            },
            confirmButton = {
                TextButton(onClick = {
                    parseDecimal(newPrice)?.takeIf { it > 0 }?.let { p -> vm.run { setManualPrice(a, p) }; h.success() }
                    updating = false
                }) { Text(stringResource(R.string.save), fontWeight = FontWeight.Bold) }
            },
            dismissButton = { TextButton(onClick = { updating = false }) { Text(stringResource(R.string.cancel)) } },
        )
    }
    pendingDelete?.let { op ->
        ConfirmDialog(
            title = stringResource(R.string.invest_op_delete_title),
            message = stringResource(R.string.invest_op_line, stringResource(opSideLabel(op.side)), f.numFree(op.qty)),
            onConfirm = { h.heavy(); vm.run { deleteOp(op) } },
            onDismiss = { pendingDelete = null },
        )
    }
}

@Composable
private fun DataRow(k: String, v: String) {
    Row(Modifier.fillMaxWidth().heightIn(min = 48.dp).semantics(mergeDescendants = true) {}, verticalAlignment = Alignment.CenterVertically) {
        Text(k, Modifier.weight(1f), color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(v, fontWeight = FontWeight.SemiBold)
    }
}

/** «108,46» o «108.46» → 108.46; admite más de dos decimales (precios y cantidades) */
private fun parseDecimal(s: String): Double? {
    val t = s.trim().replace(" ", "")
    if (t.isEmpty()) return null
    // si hay coma, es el decimal y los puntos son de miles
    return if (t.contains(',')) t.replace(".", "").replace(',', '.').toDoubleOrNull() else t.toDoubleOrNull()
}

private fun editDecimal(v: Double): String =
    if (v == 0.0) "" else java.math.BigDecimal.valueOf(v).stripTrailingZeros().toPlainString().replace('.', ',')

// MARK: editor de activo

@Composable
fun AssetEditorScreen(id: String?, nav: NavController) {
    val vm: FinanceViewModel = hiltViewModel()
    val ledger by vm.ledger.collectAsStateWithLifecycle()
    val l = ledger ?: return
    val h = rememberHaptics()
    val original = id?.let { l.asset(it) }
    var loaded by rememberSaveable { mutableStateOf(false) }
    var kind by rememberSaveable { mutableStateOf("stock") }
    var name by rememberSaveable { mutableStateOf("") }
    var symbol by rememberSaveable { mutableStateOf("") }
    var isin by rememberSaveable { mutableStateOf("") }
    var accountId by rememberSaveable { mutableStateOf(l.accounts.firstOrNull { it.type == AccountType.BROKER }?.id ?: "") }
    var price by rememberSaveable { mutableStateOf("") }
    var color by rememberSaveable { mutableStateOf(PALETTE[(l.data.assets.size + 2) % PALETTE.size]) }
    var archived by rememberSaveable { mutableStateOf(false) }
    var askDelete by remember { mutableStateOf(false) }
    if (!loaded) {
        original?.let {
            kind = it.kind; name = it.name; symbol = it.symbol; isin = it.isin; accountId = it.accountId ?: ""
            price = editDecimal(it.manualPrice); color = it.color; archived = it.archived
        }
        loaded = true
    }
    EditorScaffold(
        title = stringResource(if (original == null) R.string.invest_new else R.string.invest_edit),
        onCancel = { nav.popBackStack() },
        saveEnabled = name.isNotBlank() && symbol.isNotBlank(),
        onSave = {
            val sym = symbol.trim().uppercase()
            // símbolo para un futuro proveedor de precios (el mismo formato que en iPhone)
            val y = original?.ySymbol?.takeIf { it.isNotEmpty() && original.symbol == sym } ?: if (kind == "crypto") "$sym-EUR" else sym
            val a = (original ?: Asset(symbol = "", ySymbol = "", name = "")).copy(
                kind = kind, name = name.trim(), symbol = sym, ySymbol = y, isin = isin.trim().uppercase(),
                accountId = accountId.ifEmpty { null }, manualPrice = parseDecimal(price) ?: (original?.manualPrice ?: 0.0), color = color, archived = archived,
            )
            vm.run { save(a) }
            h.success(); nav.popBackStack()
        },
    ) { pad ->
        LazyColumn(contentPadding = listPadding(pad), verticalArrangement = Arrangement.spacedBy(18.dp)) {
            item {
                SegmentedPills(
                    listOf(stringResource(R.string.invest_kind_stock), stringResource(R.string.invest_kind_crypto)),
                    if (kind == "crypto") 1 else 0, { kind = if (it == 1) "crypto" else "stock" },
                )
            }
            item {
                FormSection {
                    FieldRow(stringResource(R.string.invest_name), name, { name = it })
                    FieldRow(stringResource(if (kind == "crypto") R.string.invest_symbol_crypto else R.string.invest_symbol_short), symbol, { symbol = it })
                    if (kind == "stock") FieldRow(stringResource(R.string.invest_isin_opt), isin, { isin = it })
                    FieldRow(stringResource(R.string.invest_price_now), price, { price = it.filter { c -> c.isDigit() || c == ',' || c == '.' } }, numeric = true)
                }
            }
            item {
                FormSection {
                    PickerRow(stringResource(R.string.account), listOf("" to stringResource(R.string.none)) + l.accounts.map { it.id to "${it.icon} ${it.name}" }, accountId) { accountId = it }
                    if (original != null) { RowDivider(); SwitchRow(stringResource(R.string.invest_archived), archived) { archived = it } }
                }
            }
            item { FormSection(stringResource(R.string.color)) { Box(Modifier.padding(vertical = 12.dp)) { ColorRow(color) { color = it } } } }
            if (original != null) item {
                TextButton(onClick = { h.warning(); askDelete = true }, modifier = Modifier.fillMaxWidth()) {
                    Text(stringResource(R.string.invest_delete), color = MaterialTheme.colorScheme.error)
                }
            }
        }
    }
    if (askDelete && original != null) {
        ConfirmDialog(
            title = stringResource(R.string.invest_delete_title),
            message = stringResource(R.string.invest_delete_msg),
            onConfirm = {
                vm.run { deleteAsset(original) }
                h.heavy()
                if (!nav.popBackStack(InvestRoute, inclusive = false)) nav.popBackStack()
            },
            onDismiss = { askDelete = false },
        )
    }
}

// MARK: editor de operación

@Composable
fun OpEditorScreen(assetId: String, opId: String?, nav: NavController) {
    val vm: FinanceViewModel = hiltViewModel()
    val ledger by vm.ledger.collectAsStateWithLifecycle()
    val l = ledger ?: return
    val f = LocalFmt.current
    val h = rememberHaptics()
    val asset = l.asset(assetId)
    val original = opId?.let { o -> asset?.ops?.firstOrNull { it.id == o } }
    var loaded by rememberSaveable { mutableStateOf(false) }
    var side by rememberSaveable { mutableStateOf(OpSide.BUY) }
    var qty by rememberSaveable { mutableStateOf("") }
    var price by rememberSaveable { mutableStateOf("") }
    var fee by rememberSaveable { mutableStateOf("") }
    var date by rememberSaveable { mutableStateOf(Day.today) }
    var cash by rememberSaveable { mutableStateOf("") }
    var askDelete by remember { mutableStateOf(false) }
    if (!loaded) {
        if (original != null) {
            side = original.side; qty = editDecimal(original.qty); price = editDecimal(original.price); fee = editDecimal(original.fee)
            date = original.date; cash = original.cashAccountId ?: ""
        } else if (asset != null) {
            price = editDecimal(l.price(asset))
        }
        loaded = true
    }
    val q = parseDecimal(qty) ?: 0.0
    val p = parseDecimal(price) ?: 0.0
    val valid = asset != null && q > 0 && (side == OpSide.REWARD || p > 0)
    EditorScaffold(
        title = stringResource(R.string.invest_op_title),
        onCancel = { nav.popBackStack() },
        saveEnabled = valid,
        onSave = {
            val op = (original ?: AssetOp(qty = 0.0, price = 0.0, date = date)).copy(
                side = side, qty = q, price = p, fee = parseDecimal(fee) ?: 0.0, date = date, cashAccountId = cash.ifEmpty { null },
            )
            vm.run { saveOp(assetId, op) }
            h.success(); nav.popBackStack()
        },
    ) { pad ->
        LazyColumn(contentPadding = listPadding(pad), verticalArrangement = Arrangement.spacedBy(18.dp)) {
            item {
                SegmentedPills(OpSide.entries.map { stringResource(opSideLabel(it)) }, OpSide.entries.indexOf(side), { side = OpSide.entries[it] })
            }
            item {
                FormSection {
                    FieldRow(stringResource(R.string.invest_op_qty), qty, { qty = it.filter { c -> c.isDigit() || c == ',' || c == '.' } }, numeric = true)
                    FieldRow(stringResource(R.string.invest_op_price), price, { price = it.filter { c -> c.isDigit() || c == ',' || c == '.' } }, numeric = true)
                    FieldRow(stringResource(R.string.invest_op_fee), fee, { fee = it.filter { c -> c.isDigit() || c == ',' || c == '.' } }, numeric = true)
                    if (q > 0 && p > 0) {
                        Row(Modifier.fillMaxWidth().heightIn(min = 48.dp).semantics(mergeDescendants = true) {}, verticalAlignment = Alignment.CenterVertically) {
                            Text(stringResource(R.string.invest_op_amount), Modifier.weight(1f), color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text(f.money(q * p), fontWeight = FontWeight.SemiBold)
                        }
                    }
                    RowDivider()
                    DateRow(stringResource(R.string.date), date) { date = it }
                }
            }
            item {
                FormSection(stringResource(R.string.invest_op_money)) {
                    PickerRow(
                        stringResource(R.string.account),
                        listOf("" to stringResource(R.string.invest_op_no_cash)) + l.accounts.map { it.id to "${it.icon} ${it.name}" },
                        cash,
                    ) { cash = it }
                }
            }
            if (original != null) item {
                TextButton(onClick = { h.warning(); askDelete = true }, modifier = Modifier.fillMaxWidth()) {
                    Text(stringResource(R.string.invest_op_delete), color = MaterialTheme.colorScheme.error)
                }
            }
        }
    }
    if (askDelete && original != null) {
        ConfirmDialog(
            title = stringResource(R.string.invest_op_delete_title),
            onConfirm = { vm.run { deleteOp(original) }; h.heavy(); nav.popBackStack() },
            onDismiss = { askDelete = false },
        )
    }
}
