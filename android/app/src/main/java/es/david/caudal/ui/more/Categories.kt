package es.david.caudal.ui.more

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
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
import androidx.compose.ui.unit.dp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavController
import es.david.caudal.R
import es.david.caudal.core.Money
import es.david.caudal.domain.model.CatKind
import es.david.caudal.domain.model.Category
import es.david.caudal.domain.model.PALETTE
import es.david.caudal.ui.common.ColorRow
import es.david.caudal.ui.common.ConfirmDialog
import es.david.caudal.ui.common.EditorScaffold
import es.david.caudal.ui.common.EmojiGrid
import es.david.caudal.ui.common.FinanceViewModel
import es.david.caudal.ui.common.IconBubble
import es.david.caudal.ui.common.LocalFmt
import es.david.caudal.ui.common.ScreenScaffold
import es.david.caudal.ui.common.SegmentedPills
import es.david.caudal.ui.common.rememberHaptics
import es.david.caudal.ui.nav.CategoryEditorRoute
import es.david.caudal.ui.theme.CaudalTheme

// MARK: lista de categorías

@Composable
fun CategoriesScreen(nav: NavController) {
    val vm: FinanceViewModel = hiltViewModel()
    val ledger by vm.ledger.collectAsStateWithLifecycle()
    val l = ledger ?: return
    val f = LocalFmt.current
    val h = rememberHaptics()
    var kind by rememberSaveable { mutableStateOf(CatKind.EXPENSE) }
    var sorting by rememberSaveable { mutableStateOf(false) }
    val list = l.data.categories.filter { it.kind == kind }.sortedBy { it.position }
    val order = remember { mutableStateListOf<String>() }
    LaunchedEffect(list.map { it.id }) { order.clear(); order.addAll(list.map { it.id }) }
    val byId = list.associateBy { it.id }
    ScreenScaffold(
        stringResource(R.string.categories_title),
        onBack = { nav.popBackStack() },
        actions = {
            TextButton(onClick = { h.tap(); sorting = !sorting }) {
                Text(stringResource(if (sorting) R.string.accounts_sort_done else R.string.accounts_sort), fontWeight = if (sorting) FontWeight.Bold else null)
            }
            IconButton(onClick = { nav.navigate(CategoryEditorRoute(kind = kind.raw)) }) { Icon(Icons.Filled.Add, stringResource(R.string.categories_new)) }
        },
    ) { pad ->
        LazyColumn(contentPadding = listPadding(pad), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            item {
                SegmentedPills(
                    listOf(stringResource(R.string.categories_expenses), stringResource(R.string.categories_incomes)),
                    if (kind == CatKind.EXPENSE) 0 else 1,
                    { kind = if (it == 0) CatKind.EXPENSE else CatKind.INCOME },
                    modifier = Modifier.padding(bottom = 8.dp),
                )
            }
            items(order.toList(), key = { it }) { id ->
                val c = byId[id] ?: return@items
                val i = order.indexOf(id)
                Row(
                    Modifier.animateItem().fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(CaudalTheme.colors.card)
                        .clickable(enabled = !sorting, role = Role.Button) { nav.navigate(CategoryEditorRoute(c.id, c.kind.raw)) }
                        .heightIn(min = 60.dp).padding(horizontal = 14.dp, vertical = 8.dp)
                        .semantics(mergeDescendants = !sorting) {},
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    IconBubble(c.icon, c.color, 38.dp)
                    Spacer(Modifier.width(12.dp))
                    Column(Modifier.weight(1f)) {
                        Text(c.name, color = if (c.hidden) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurface)
                        if (c.budget > 0) Text(stringResource(R.string.categories_budget_line, f.plain(Money.fromCents(c.budget))), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    if (sorting) {
                        MoveButtons(i > 0, i < order.size - 1,
                            onUp = { h.select(); order.add(i - 1, order.removeAt(i)); vm.run { reorderCategories(kind, order.toList()) } },
                            onDown = { h.select(); order.add(i + 1, order.removeAt(i)); vm.run { reorderCategories(kind, order.toList()) } })
                    } else if (c.hidden) {
                        Icon(Icons.Filled.VisibilityOff, stringResource(R.string.categories_hidden), tint = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
        }
    }
}

// MARK: editor de categoría

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CategoryEditorScreen(id: String?, kind: String, nav: NavController) {
    val vm: FinanceViewModel = hiltViewModel()
    val ledger by vm.ledger.collectAsStateWithLifecycle()
    val l = ledger ?: return
    val h = rememberHaptics()
    val original = id?.let { i -> l.data.categories.firstOrNull { it.id == i } }
    val catKind = original?.kind ?: CatKind.of(kind)
    var loaded by rememberSaveable { mutableStateOf(false) }
    var name by rememberSaveable { mutableStateOf("") }
    var icon by rememberSaveable { mutableStateOf("") }
    var color by rememberSaveable { mutableStateOf(PALETTE[l.data.categories.size % PALETTE.size]) }
    var budget by rememberSaveable { mutableStateOf("") }
    var keywords by rememberSaveable { mutableStateOf("") }
    var hidden by rememberSaveable { mutableStateOf(false) }
    var pickEmoji by remember { mutableStateOf(false) }
    var askDelete by remember { mutableStateOf(false) }
    if (!loaded) {
        original?.let {
            name = it.name; icon = it.icon; color = it.color; keywords = it.keywords; hidden = it.hidden
            budget = if (it.budget > 0) Money.editText(it.budget) else ""
        }
        loaded = true
    }
    EditorScaffold(
        title = stringResource(if (original == null) R.string.categories_new else R.string.categories_edit),
        onCancel = { nav.popBackStack() },
        saveEnabled = name.isNotBlank(),
        onSave = {
            val c = (original ?: Category(name = "")).copy(
                kind = catKind, name = name.trim(), icon = icon.ifEmpty { "📦" }, color = color,
                budget = if (catKind == CatKind.EXPENSE) Money.toCents(Money.parse(budget) ?: 0.0) else 0, keywords = keywords.trim(), hidden = hidden,
            )
            vm.run { save(c) }
            h.success(); nav.popBackStack()
        },
    ) { pad ->
        LazyColumn(contentPadding = listPadding(pad), verticalArrangement = Arrangement.spacedBy(18.dp)) {
            item {
                FormSection {
                    Row(Modifier.padding(vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                        Box(Modifier.clickable(role = Role.Button) { pickEmoji = true }) { IconBubble(icon.ifEmpty { "➕" }, color, 52.dp) }
                        Spacer(Modifier.width(12.dp))
                        OutlinedTextField(name, { name = it }, label = { Text(stringResource(R.string.name)) }, singleLine = true, modifier = Modifier.weight(1f))
                    }
                }
            }
            item {
                FormSection(stringResource(R.string.categories_emoji)) {
                    Box(Modifier.padding(vertical = 10.dp)) { EmojiGrid(icon, { icon = it }) }
                    TextButton(onClick = { pickEmoji = true }) { Text(stringResource(R.string.categories_all_emojis)) }
                }
            }
            item {
                FormSection {
                    if (catKind == CatKind.EXPENSE) {
                        FieldRow(stringResource(R.string.categories_budget), budget, { budget = it }, numeric = true, placeholder = stringResource(R.string.categories_no_limit))
                        RowDivider()
                    }
                    SwitchRow(stringResource(R.string.categories_hide), hidden) { hidden = it }
                }
            }
            item {
                FormSection(stringResource(R.string.categories_keywords)) {
                    FieldRow(stringResource(R.string.categories_keywords), keywords, { keywords = it }, singleLine = false, placeholder = stringResource(R.string.categories_keywords_hint))
                }
            }
            item { FormSection(stringResource(R.string.color)) { Box(Modifier.padding(vertical = 12.dp)) { ColorRow(color) { color = it } } } }
            if (original != null) item {
                TextButton(onClick = { h.warning(); askDelete = true }, modifier = Modifier.fillMaxWidth()) {
                    Text(stringResource(R.string.categories_delete), color = MaterialTheme.colorScheme.error)
                }
            }
        }
    }
    if (pickEmoji) {
        ModalBottomSheet(onDismissRequest = { pickEmoji = false }) {
            Column(Modifier.verticalScroll(rememberScrollState()).padding(16.dp).navigationBarsPadding()) {
                Text(stringResource(R.string.pick_emoji), style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(bottom = 12.dp))
                EmojiGrid(icon, { icon = it; pickEmoji = false }, compact = false)
            }
        }
    }
    if (askDelete && original != null) {
        ConfirmDialog(
            title = stringResource(R.string.categories_delete_title, original.name),
            message = stringResource(R.string.categories_delete_msg),
            onConfirm = { vm.run { deleteCategory(original) }; h.heavy(); nav.popBackStack() },
            onDismiss = { askDelete = false },
        )
    }
}
