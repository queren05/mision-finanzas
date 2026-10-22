package es.david.caudal.ui.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AddCircle
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material.icons.filled.RemoveCircle
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import es.david.caudal.R
import es.david.caudal.domain.model.AccountsStyle
import es.david.caudal.domain.model.HomeItem
import es.david.caudal.ui.common.Card
import es.david.caudal.ui.common.FinanceViewModel
import es.david.caudal.ui.common.Pill
import es.david.caudal.ui.common.ScreenScaffold
import es.david.caudal.ui.common.rememberHaptics
import es.david.caudal.ui.theme.CaudalTheme

/** elige qué tarjetas salen en Inicio y en qué orden, el estilo de las cuentas y su orden */
@Composable
fun HomeCustomizeScreen(nav: NavController) {
    val vm: FinanceViewModel = hiltViewModel()
    val settings by vm.settings.collectAsStateWithLifecycle()
    val ledger by vm.ledger.collectAsStateWithLifecycle()
    val s = settings ?: return
    val l = ledger ?: return
    val h = rememberHaptics()
    val home = s.home
    val on = home.filter { it.on }
    val off = home.filter { !it.on }

    fun setHome(list: List<HomeItem>) = vm.updateSettings { it.copy(home = list) }
    fun toggle(item: HomeItem) {
        h.select()
        val list = home.toMutableList()
        val i = list.indexOfFirst { it.id == item.id }
        val it = list.removeAt(i).copy(on = !item.on)
        // al añadir, va al final de lo que se ve
        if (it.on) list.add(list.indexOfLast { x -> x.on } + 1, it) else list.add(it)
        setHome(list)
    }
    fun moveOn(item: HomeItem, by: Int) {
        val visible = on.toMutableList()
        val i = visible.indexOf(item)
        val j = (i + by).coerceIn(0, visible.lastIndex)
        if (i == j) return
        h.select()
        visible.add(j, visible.removeAt(i))
        setHome(visible + off)
    }

    ScreenScaffold(title = stringResource(R.string.customize_home), onBack = { nav.popBackStack() }, large = false, actions = {
        TextButton(onClick = { h.success(); nav.popBackStack() }) { Text(stringResource(R.string.done), fontWeight = FontWeight.Bold) }
    }) { pad ->
        LazyColumn(contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = pad.calculateTopPadding(), bottom = 32.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            item {
                Card(padding = 8.dp) {
                    Header(stringResource(R.string.home_on))
                    on.forEachIndexed { i, item ->
                        HomeRow(item, onToggle = { toggle(item) }, onUp = if (i > 0) ({ moveOn(item, -1) }) else null, onDown = if (i < on.lastIndex) ({ moveOn(item, 1) }) else null)
                    }
                }
            }
            item {
                Card(padding = 8.dp) {
                    Header(stringResource(R.string.home_add))
                    if (off.isEmpty()) Text(stringResource(R.string.all_on_home), color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(12.dp))
                    off.forEach { item -> HomeRow(item, onToggle = { toggle(item) }) }
                }
            }
            item {
                Card(padding = 12.dp) {
                    Header(stringResource(R.string.accounts_style))
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        AccountsStyle.entries.forEach { st ->
                            Pill(stringResource(styleName(st)), st == s.accountsStyle, { vm.updateSettings { it.copy(accountsStyle = st) } }, Modifier.weight(1f))
                        }
                    }
                }
            }
            item {
                Card(padding = 8.dp) {
                    Header(stringResource(R.string.sort_accounts))
                    val accounts = l.accounts
                    accounts.forEachIndexed { i, a ->
                        Row(Modifier.fillMaxWidth().heightIn(min = 52.dp).semantics(mergeDescendants = true) {}, verticalAlignment = Alignment.CenterVertically) {
                            Spacer(Modifier.width(12.dp))
                            Text(a.icon)
                            Spacer(Modifier.width(12.dp))
                            Text(a.name, modifier = Modifier.weight(1f))
                            IconButton(onClick = { h.select(); vm.run { reorderAccounts(accounts.map { it.id }.toMutableList().apply { add(i - 1, removeAt(i)) }) } }, enabled = i > 0) {
                                Icon(Icons.Filled.KeyboardArrowUp, stringResource(R.string.move_up))
                            }
                            IconButton(onClick = { h.select(); vm.run { reorderAccounts(accounts.map { it.id }.toMutableList().apply { add(i + 1, removeAt(i)) }) } }, enabled = i < accounts.lastIndex) {
                                Icon(Icons.Filled.KeyboardArrowDown, stringResource(R.string.move_down))
                            }
                        }
                    }
                }
            }
            item {
                TextButton(onClick = { h.warning(); setHome(HomeItem.DEFAULTS) }, modifier = Modifier.fillMaxWidth()) { Text(stringResource(R.string.reset)) }
            }
        }
    }
}

@Composable
private fun Header(text: String) {
    Text(text, style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp))
}

@Composable
private fun HomeRow(item: HomeItem, onToggle: () -> Unit, onUp: (() -> Unit)? = null, onDown: (() -> Unit)? = null) {
    val colors = CaudalTheme.colors
    Row(Modifier.fillMaxWidth().heightIn(min = 52.dp), verticalAlignment = Alignment.CenterVertically) {
        IconButton(onClick = onToggle) {
            Icon(
                if (item.on) Icons.Filled.RemoveCircle else Icons.Filled.AddCircle,
                stringResource(if (item.on) R.string.remove_from_home else R.string.add_to_home),
                tint = if (item.on) colors.negative else colors.income,
            )
        }
        Text(stringResource(homeName(item.id)), modifier = Modifier.weight(1f))
        if (item.on) {
            IconButton(onClick = { onUp?.invoke() }, enabled = onUp != null) { Icon(Icons.Filled.KeyboardArrowUp, stringResource(R.string.move_up)) }
            IconButton(onClick = { onDown?.invoke() }, enabled = onDown != null) { Icon(Icons.Filled.KeyboardArrowDown, stringResource(R.string.move_down)) }
        }
    }
}

private fun homeName(id: String) = when (id) {
    "patrimonio" -> R.string.home_patrimonio
    "cuentas" -> R.string.home_cuentas
    "horas" -> R.string.home_horas
    "mes" -> R.string.home_mes
    "categorias" -> R.string.home_categorias
    "proximos" -> R.string.home_proximos
    "recientes" -> R.string.home_recientes
    "inversiones" -> R.string.home_inversiones
    else -> R.string.home_deudas
}

private fun styleName(s: AccountsStyle) = when (s) {
    AccountsStyle.CUADRICULA -> R.string.style_cuadricula
    AccountsStyle.CARRUSEL -> R.string.style_carrusel
    AccountsStyle.LISTA -> R.string.style_lista
    AccountsStyle.PEQUENO -> R.string.style_pequeno
    AccountsStyle.GRANDE -> R.string.style_grande
}
