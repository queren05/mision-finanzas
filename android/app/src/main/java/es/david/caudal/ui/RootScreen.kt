package es.david.caudal.ui

import android.provider.Settings
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ShowChart
import androidx.compose.material.icons.automirrored.filled.ViewList
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Group
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SnackbarDuration
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.SnackbarResult
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavDestination.Companion.hasRoute
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import es.david.caudal.R
import es.david.caudal.ui.common.LocalFmt
import es.david.caudal.ui.common.LocalHapticsOn
import es.david.caudal.ui.common.LocalMascot
import es.david.caudal.ui.common.contentOn
import es.david.caudal.ui.common.pressable
import es.david.caudal.ui.common.rememberFmt
import es.david.caudal.ui.common.rememberHaptics
import es.david.caudal.ui.lock.LockScreen
import es.david.caudal.ui.nav.CaudalNavHost
import es.david.caudal.ui.nav.DebtsRoute
import es.david.caudal.ui.nav.HomeRoute
import es.david.caudal.ui.nav.InvestRoute
import es.david.caudal.ui.nav.MoreRoute
import es.david.caudal.ui.nav.TxEditorRoute
import es.david.caudal.ui.nav.TxsRoute
import es.david.caudal.ui.onboarding.OnboardingScreen
import es.david.caudal.ui.theme.CaudalTheme
import es.david.caudal.ui.theme.LocalMotion

/** acción del acceso directo «Apuntar gasto» */
const val ACTION_NEW_EXPENSE = "es.david.caudal.NEW_EXPENSE"

private data class Tab(val route: Any, val label: Int, val icon: ImageVector)

@Composable
fun RootScreen(app: AppViewModel, launchAction: String?, backupUri: android.net.Uri? = null, onBackupHandled: () -> Unit = {}, onActionHandled: () -> Unit = {}) {
    val settings by app.settings.collectAsStateWithLifecycle()
    val s = settings ?: return
    val hidden by app.hidden.collectAsStateWithLifecycle()
    val locked by app.locked.collectAsStateWithLifecycle()
    // «Quitar animaciones» del sistema: también aquí
    val ctx = LocalContext.current
    val systemMotion = remember { runCatching { Settings.Global.getFloat(ctx.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) }.getOrDefault(1f) > 0f }
    CaudalTheme(s.theme, s.accent, s.dynamicColor, amoled = s.amoled, motion = systemMotion) {
        CompositionLocalProvider(
            LocalFmt provides rememberFmt(s.currency, hidden ?: false),
            LocalHapticsOn provides s.haptics,
            LocalMascot provides s.mascot,
        ) {
            Surface(Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
                if (backupUri != null && !locked) ImportBackupDialog(app, backupUri, onBackupHandled)
                when {
                    !s.onboarded -> OnboardingScreen()
                    locked -> LockScreen(onUnlocked = app::unlocked)
                    else -> MainShell(app, launchAction, onActionHandled, s.moduleDebts, s.moduleInvest, s.tabLabels)
                }
            }
        }
    }
}

@Composable
private fun MainShell(app: AppViewModel, launchAction: String?, onActionHandled: () -> Unit, debts: Boolean, invest: Boolean, labels: Boolean) {
    val nav = rememberNavController()
    val h = rememberHaptics()
    val snackbar = remember { SnackbarHostState() }
    val back by nav.currentBackStackEntryAsState()
    val dest = back?.destination
    val tabs = buildList {
        add(Tab(HomeRoute, R.string.tab_home, Icons.Filled.Home))
        add(Tab(TxsRoute, R.string.tab_txs, Icons.AutoMirrored.Filled.ViewList))
        if (debts) add(Tab(DebtsRoute, R.string.tab_debts, Icons.Filled.Group))
        if (invest) add(Tab(InvestRoute, R.string.tab_invest, Icons.AutoMirrored.Filled.ShowChart))
        add(Tab(MoreRoute, R.string.tab_more, Icons.Filled.MoreHoriz))
    }
    val current = tabs.indexOfFirst { t -> dest?.hasRoute(t.route::class) == true }
    val onTab = current >= 0
    val fab = dest?.hasRoute(HomeRoute::class) == true || dest?.hasRoute(TxsRoute::class) == true

    // acceso directo «Apuntar gasto»
    LaunchedEffect(launchAction) { if (launchAction == ACTION_NEW_EXPENSE) { nav.navigate(TxEditorRoute(type = "expense")); onActionHandled() } }

    // «Deshacer» del último borrado
    val lastDeleted by app.lastDeleted.collectAsStateWithLifecycle()
    val deletedText = lastDeleted?.let { stringResource(R.string.tx_deleted, it.title.ifEmpty { stringResource(es.david.caudal.ui.common.txTypeLabel(it.type)) }) }
    val undoLabel = stringResource(R.string.undo)
    LaunchedEffect(lastDeleted) {
        if (lastDeleted != null && deletedText != null) {
            val r = snackbar.showSnackbar(deletedText, undoLabel, withDismissAction = false, duration = SnackbarDuration.Short)
            if (r == SnackbarResult.ActionPerformed) { h.success(); app.undo() } else app.clearUndo()
        }
    }

    Box(Modifier.fillMaxSize()) {
        CaudalNavHost(nav, onToggleHidden = app::toggleHidden)

        // botón + redondo, siempre a mano (gira al pulsarlo)
        var spins by remember { mutableIntStateOf(0) }
        val rot by animateFloatAsState(spins * 90f, spring(dampingRatio = 0.5f, stiffness = Spring.StiffnessLow), label = "giro")
        AnimatedVisibility(
            fab && onTab,
            Modifier.align(Alignment.BottomEnd).navigationBarsPadding().padding(end = 20.dp, bottom = 96.dp),
            enter = scaleIn(spring(dampingRatio = 0.5f)) + fadeIn(), exit = scaleOut() + fadeOut(),
        ) {
            val c = CaudalTheme.colors
            val desc = stringResource(R.string.new_tx)
            Box(
                Modifier
                    .size(64.dp)
                    .shadow(18.dp, CircleShape, ambientColor = c.accent, spotColor = c.accent)
                    .clip(CircleShape)
                    .background(Brush.linearGradient(listOf(lerp(c.accent, androidx.compose.ui.graphics.Color.White, 0.2f), c.accent)))
                    .pressable(0.86f) { h.heavy(); spins++; nav.navigate(TxEditorRoute()) }
                    .semantics { contentDescription = desc },
                contentAlignment = Alignment.Center,
            ) { Icon(Icons.Filled.Add, null, tint = contentOn(c.accent), modifier = Modifier.size(32.dp).graphicsLayer { rotationZ = rot }) }
        }

        // barra de abajo flotante con una píldora que se desliza
        AnimatedVisibility(
            onTab,
            Modifier.align(Alignment.BottomCenter),
            enter = slideInVertically { it } + fadeIn(), exit = slideOutVertically { it } + fadeOut(),
        ) {
            FloatingTabBar(tabs, current.coerceAtLeast(0), labels) { i ->
                h.select()
                nav.navigate(tabs[i].route) {
                    popUpTo(nav.graph.findStartDestination().id) { saveState = true }
                    launchSingleTop = true
                    restoreState = true
                }
            }
        }

        SnackbarHost(snackbar, Modifier.align(Alignment.BottomCenter).navigationBarsPadding().padding(bottom = if (onTab) 96.dp else 16.dp))
    }
}

@Composable
private fun FloatingTabBar(tabs: List<Tab>, selected: Int, labels: Boolean, onSelect: (Int) -> Unit) {
    val c = CaudalTheme.colors
    val motion = LocalMotion.current
    Box(
        Modifier
            .navigationBarsPadding()
            .padding(horizontal = 18.dp, vertical = 10.dp)
            .fillMaxWidth()
            .height(if (labels) 68.dp else 60.dp)
            .shadow(24.dp, CircleShape, ambientColor = c.accent.copy(alpha = 0.4f), spotColor = c.accent.copy(alpha = 0.3f))
            .clip(CircleShape)
            .background(c.card.copy(alpha = 0.97f))
            .border(1.dp, c.hairline, CircleShape)
            .padding(5.dp),
    ) {
        BoxWithConstraints(Modifier.fillMaxSize()) {
            val w = maxWidth / tabs.size
            val x by animateDpAsState(w * selected, if (motion) spring(dampingRatio = 0.68f, stiffness = Spring.StiffnessMediumLow) else spring(), label = "píldora")
            // la «gota» que marca la pestaña
            Box(Modifier.offset(x = x).width(w).fillMaxHeight().clip(CircleShape).background(c.accent.copy(alpha = 0.22f)))
            Row(Modifier.fillMaxSize(), horizontalArrangement = Arrangement.SpaceEvenly) {
                tabs.forEachIndexed { i, t ->
                    val on = i == selected
                    val scale by animateFloatAsState(if (on) 1.12f else 1f, spring(dampingRatio = 0.45f, stiffness = Spring.StiffnessMedium), label = "icono")
                    val label = stringResource(t.label)
                    Column(
                        Modifier
                            .weight(1f)
                            .fillMaxHeight()
                            .clip(CircleShape)
                            .pressable(0.88f, role = Role.Tab) { onSelect(i) }
                            .semantics { this.selected = on; contentDescription = label },
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Center,
                    ) {
                        Icon(t.icon, null, tint = if (on) c.accent else c.textDim, modifier = Modifier.size(24.dp).graphicsLayer { scaleX = scale; scaleY = scale })
                        if (labels) Text(label, style = MaterialTheme.typography.labelSmall, color = if (on) c.text else c.textDim, maxLines = 1)
                    }
                }
            }
        }
    }
}

/** «¿Seguro que quieres importar esta copia?» al abrir un .json con Caudal */
@Composable
private fun ImportBackupDialog(app: AppViewModel, uri: android.net.Uri, onDone: () -> Unit) {
    val ctx = LocalContext.current
    var asked by remember(uri) { androidx.compose.runtime.mutableStateOf(true) }
    val result by app.importResult.collectAsStateWithLifecycle()
    val finish = { app.importResult.value = null; onDone() }
    if (result != null) {
        androidx.compose.material3.AlertDialog(
            onDismissRequest = finish,
            confirmButton = { androidx.compose.material3.TextButton(onClick = finish) { Text(stringResource(R.string.ok)) } },
            text = { Text(if (result!! >= 0) stringResource(R.string.import_done, result!!) else stringResource(R.string.import_failed)) },
        )
    } else if (asked) {
        es.david.caudal.ui.common.ConfirmDialog(
            title = stringResource(R.string.import_confirm_title),
            message = stringResource(R.string.import_confirm_text),
            confirm = stringResource(R.string.import_confirm),
            destructive = true,
            onConfirm = { asked = false; app.importFrom(ctx, uri) },
            onDismiss = { if (asked) { asked = false; onDone() } },
        )
    }
}
