package es.david.caudal.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ShowChart
import androidx.compose.material.icons.automirrored.filled.ViewList
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Group
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
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
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavDestination.Companion.hasRoute
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import es.david.caudal.R
import es.david.caudal.ui.common.LocalFmt
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

/** acción del acceso directo «Apuntar gasto» */
const val ACTION_NEW_EXPENSE = "es.david.caudal.NEW_EXPENSE"

private data class Tab(val route: Any, val label: Int, val icon: ImageVector)

@Composable
fun RootScreen(app: AppViewModel, launchAction: String?) {
    val settings by app.settings.collectAsStateWithLifecycle()
    val s = settings ?: return
    val hidden by app.hidden.collectAsStateWithLifecycle()
    val locked by app.locked.collectAsStateWithLifecycle()
    CaudalTheme(s.theme, s.accent, s.dynamicColor) {
        CompositionLocalProvider(LocalFmt provides rememberFmt(s.currency, hidden ?: false)) {
            Surface(Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
                when {
                    !s.onboarded -> OnboardingScreen()
                    locked -> LockScreen(onUnlocked = app::unlocked)
                    else -> MainShell(app, launchAction, s.moduleDebts, s.moduleInvest)
                }
            }
        }
    }
}

@Composable
private fun MainShell(app: AppViewModel, launchAction: String?, debts: Boolean, invest: Boolean) {
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
    val onTab = tabs.any { t -> dest?.hasRoute(t.route::class) == true }
    val fab = dest?.hasRoute(HomeRoute::class) == true || dest?.hasRoute(TxsRoute::class) == true

    // acceso directo «Apuntar gasto»
    LaunchedEffect(launchAction) { if (launchAction == ACTION_NEW_EXPENSE) nav.navigate(TxEditorRoute(type = "expense")) }

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

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        snackbarHost = { SnackbarHost(snackbar) },
        floatingActionButton = {
            AnimatedVisibility(fab, enter = scaleIn() + fadeIn(), exit = scaleOut() + fadeOut()) {
                FloatingActionButton(
                    onClick = { h.heavy(); nav.navigate(TxEditorRoute()) },
                    containerColor = MaterialTheme.colorScheme.primary,
                    contentColor = MaterialTheme.colorScheme.onPrimary,
                ) { Icon(Icons.Filled.Add, stringResource(R.string.new_tx), Modifier.padding(4.dp)) }
            }
        },
        bottomBar = {
            if (onTab) {
                NavigationBar(containerColor = MaterialTheme.colorScheme.surfaceContainerLow) {
                    tabs.forEach { t ->
                        NavigationBarItem(
                            selected = dest?.hasRoute(t.route::class) == true,
                            onClick = {
                                h.select()
                                nav.navigate(t.route) {
                                    popUpTo(nav.graph.findStartDestination().id) { saveState = true }
                                    launchSingleTop = true
                                    restoreState = true
                                }
                            },
                            icon = { Icon(t.icon, null) },
                            label = { Text(stringResource(t.label)) },
                        )
                    }
                }
            }
        },
    ) { pad ->
        Box(Modifier.fillMaxSize().padding(bottom = pad.calculateBottomPadding())) {
            CaudalNavHost(nav, onToggleHidden = app::toggleHidden)
        }
    }
}
