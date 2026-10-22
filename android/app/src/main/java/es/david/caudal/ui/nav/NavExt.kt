package es.david.caudal.ui.nav

import androidx.navigation.NavController
import androidx.navigation.NavGraph.Companion.findStartDestination

/** ir a una pestaña como si se tocara en la barra de abajo */
fun NavController.navigateTab(route: Any) = navigate(route) {
    popUpTo(graph.findStartDestination().id) { saveState = true }
    launchSingleTop = true
    restoreState = true
}
