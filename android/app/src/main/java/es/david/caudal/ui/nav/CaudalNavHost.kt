package es.david.caudal.ui.nav

import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.runtime.Composable
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.toRoute
import es.david.caudal.ui.debts.DebtEditorScreen
import es.david.caudal.ui.debts.DebtsScreen
import es.david.caudal.ui.debts.PersonDetailScreen
import es.david.caudal.ui.debts.PersonEditorScreen
import es.david.caudal.ui.home.HomeCustomizeScreen
import es.david.caudal.ui.home.HomeScreen
import es.david.caudal.ui.invest.AssetDetailScreen
import es.david.caudal.ui.invest.AssetEditorScreen
import es.david.caudal.ui.invest.InvestScreen
import es.david.caudal.ui.invest.OpEditorScreen
import es.david.caudal.ui.more.AccountDetailScreen
import es.david.caudal.ui.more.AccountEditorScreen
import es.david.caudal.ui.more.AccountsScreen
import es.david.caudal.ui.more.CategoriesScreen
import es.david.caudal.ui.more.CategoryEditorScreen
import es.david.caudal.ui.more.DataScreen
import es.david.caudal.ui.more.GoalEditorScreen
import es.david.caudal.ui.more.GoalsScreen
import es.david.caudal.ui.more.MoreScreen
import es.david.caudal.ui.more.RecurringEditorScreen
import es.david.caudal.ui.more.RecurringScreen
import es.david.caudal.ui.more.SettingsScreen
import es.david.caudal.ui.stats.StatsScreen
import es.david.caudal.ui.txs.TransactionsScreen
import es.david.caudal.ui.txs.TxEditorScreen
import es.david.caudal.ui.work.CompanyEditorScreen
import es.david.caudal.ui.work.ShiftEditorScreen
import es.david.caudal.ui.work.WorkScreen

/** pantalla con su ámbito de animación disponible (para las transiciones compartidas) */
inline fun <reified T : Any> androidx.navigation.NavGraphBuilder.screen(noinline content: @Composable (androidx.navigation.NavBackStackEntry) -> Unit) {
    composable<T> { e -> androidx.compose.runtime.CompositionLocalProvider(es.david.caudal.ui.common.LocalNavScope provides this) { content(e) } }
}

@OptIn(androidx.compose.animation.ExperimentalSharedTransitionApi::class)
@Composable
fun CaudalNavHost(nav: NavHostController, onToggleHidden: () -> Unit) {
    androidx.compose.animation.SharedTransitionLayout {
    androidx.compose.runtime.CompositionLocalProvider(es.david.caudal.ui.common.LocalSharedScope provides this) {
    NavHost(
        navController = nav,
        startDestination = HomeRoute,
        enterTransition = { slideInHorizontally { it / 4 } + fadeIn() },
        exitTransition = { fadeOut() },
        popEnterTransition = { fadeIn() },
        popExitTransition = { slideOutHorizontally { it / 4 } + fadeOut() },
    ) {
        // pestañas
        screen<HomeRoute> { HomeScreen(nav, onToggleHidden) }
        screen<TxsRoute> { TransactionsScreen(nav) }
        screen<DebtsRoute> { DebtsScreen(nav) }
        screen<InvestRoute> { InvestScreen(nav) }
        screen<MoreRoute> { MoreScreen(nav) }

        // movimientos
        screen<TxEditorRoute> { TxEditorScreen(it.toRoute<TxEditorRoute>(), onDone = { nav.popBackStack() }) }
        screen<StatsRoute> { StatsScreen(nav) }
        screen<HomeCustomizeRoute> { HomeCustomizeScreen(nav) }
        screen<CalendarRoute> { es.david.caudal.ui.txs.CalendarScreen(it.toRoute<CalendarRoute>().month, nav) }
        screen<WrappedRoute> { es.david.caudal.ui.stats.WrappedScreen(it.toRoute<WrappedRoute>().month, nav) }
        screen<PersonalizeRoute> { es.david.caudal.ui.more.PersonalizeScreen(nav) }
        screen<GotitaRoute> { es.david.caudal.ui.gotita.GotitaScreen(nav) }
        screen<AchievementsRoute> { es.david.caudal.ui.gotita.AchievementsScreen(nav) }

        // gestión
        screen<AccountsRoute> { AccountsScreen(nav) }
        screen<AccountDetailRoute> { AccountDetailScreen(it.toRoute<AccountDetailRoute>().id, nav) }
        screen<AccountEditorRoute> { AccountEditorScreen(it.toRoute<AccountEditorRoute>().id, nav) }
        screen<CategoriesRoute> { CategoriesScreen(nav) }
        screen<CategoryEditorRoute> { val r = it.toRoute<CategoryEditorRoute>(); CategoryEditorScreen(r.id, r.kind, nav) }
        screen<RecurringRoute> { RecurringScreen(nav) }
        screen<RecurringEditorRoute> { RecurringEditorScreen(it.toRoute<RecurringEditorRoute>().id, nav) }
        screen<GoalsRoute> { GoalsScreen(nav) }
        screen<GoalEditorRoute> { GoalEditorScreen(it.toRoute<GoalEditorRoute>().id, nav) }
        screen<SettingsRoute> { SettingsScreen(nav) }
        screen<DataRoute> { DataScreen(nav) }

        // horas trabajadas
        screen<WorkRoute> { WorkScreen(nav) }
        screen<ShiftEditorRoute> { val r = it.toRoute<ShiftEditorRoute>(); ShiftEditorScreen(r.id, r.companyId, nav) }
        screen<CompanyEditorRoute> { CompanyEditorScreen(it.toRoute<CompanyEditorRoute>().id, nav) }

        // cuentas claras
        screen<PersonDetailRoute> { PersonDetailScreen(it.toRoute<PersonDetailRoute>().id, nav) }
        screen<PersonEditorRoute> { PersonEditorScreen(it.toRoute<PersonEditorRoute>().id, nav) }
        screen<DebtEditorRoute> { val r = it.toRoute<DebtEditorRoute>(); DebtEditorScreen(r.kind, r.personId, nav) }

        // inversiones
        screen<AssetDetailRoute> { AssetDetailScreen(it.toRoute<AssetDetailRoute>().id, nav) }
        screen<AssetEditorRoute> { AssetEditorScreen(it.toRoute<AssetEditorRoute>().id, nav) }
        screen<OpEditorRoute> { val r = it.toRoute<OpEditorRoute>(); OpEditorScreen(r.assetId, r.opId, nav) }
    }
    }
    }
}
