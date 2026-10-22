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

@Composable
fun CaudalNavHost(nav: NavHostController, onToggleHidden: () -> Unit) {
    NavHost(
        navController = nav,
        startDestination = HomeRoute,
        enterTransition = { slideInHorizontally { it / 4 } + fadeIn() },
        exitTransition = { fadeOut() },
        popEnterTransition = { fadeIn() },
        popExitTransition = { slideOutHorizontally { it / 4 } + fadeOut() },
    ) {
        // pestañas
        composable<HomeRoute> { HomeScreen(nav, onToggleHidden) }
        composable<TxsRoute> { TransactionsScreen(nav) }
        composable<DebtsRoute> { DebtsScreen(nav) }
        composable<InvestRoute> { InvestScreen(nav) }
        composable<MoreRoute> { MoreScreen(nav) }

        // movimientos
        composable<TxEditorRoute> { TxEditorScreen(it.toRoute<TxEditorRoute>(), onDone = { nav.popBackStack() }) }
        composable<StatsRoute> { StatsScreen(nav) }
        composable<HomeCustomizeRoute> { HomeCustomizeScreen(nav) }

        // gestión
        composable<AccountsRoute> { AccountsScreen(nav) }
        composable<AccountDetailRoute> { AccountDetailScreen(it.toRoute<AccountDetailRoute>().id, nav) }
        composable<AccountEditorRoute> { AccountEditorScreen(it.toRoute<AccountEditorRoute>().id, nav) }
        composable<CategoriesRoute> { CategoriesScreen(nav) }
        composable<CategoryEditorRoute> { val r = it.toRoute<CategoryEditorRoute>(); CategoryEditorScreen(r.id, r.kind, nav) }
        composable<RecurringRoute> { RecurringScreen(nav) }
        composable<RecurringEditorRoute> { RecurringEditorScreen(it.toRoute<RecurringEditorRoute>().id, nav) }
        composable<GoalsRoute> { GoalsScreen(nav) }
        composable<GoalEditorRoute> { GoalEditorScreen(it.toRoute<GoalEditorRoute>().id, nav) }
        composable<SettingsRoute> { SettingsScreen(nav) }
        composable<DataRoute> { DataScreen(nav) }

        // horas trabajadas
        composable<WorkRoute> { WorkScreen(nav) }
        composable<ShiftEditorRoute> { val r = it.toRoute<ShiftEditorRoute>(); ShiftEditorScreen(r.id, r.companyId, nav) }
        composable<CompanyEditorRoute> { CompanyEditorScreen(it.toRoute<CompanyEditorRoute>().id, nav) }

        // cuentas claras
        composable<PersonDetailRoute> { PersonDetailScreen(it.toRoute<PersonDetailRoute>().id, nav) }
        composable<PersonEditorRoute> { PersonEditorScreen(it.toRoute<PersonEditorRoute>().id, nav) }
        composable<DebtEditorRoute> { val r = it.toRoute<DebtEditorRoute>(); DebtEditorScreen(r.kind, r.personId, nav) }

        // inversiones
        composable<AssetDetailRoute> { AssetDetailScreen(it.toRoute<AssetDetailRoute>().id, nav) }
        composable<AssetEditorRoute> { AssetEditorScreen(it.toRoute<AssetEditorRoute>().id, nav) }
        composable<OpEditorRoute> { val r = it.toRoute<OpEditorRoute>(); OpEditorScreen(r.assetId, r.opId, nav) }
    }
}
