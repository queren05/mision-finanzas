package es.david.caudal.ui.nav

import kotlinx.serialization.Serializable

// Rutas de la app (Navigation Compose con tipos)

// pestañas
@Serializable data object HomeRoute
@Serializable data object TxsRoute
@Serializable data object DebtsRoute
@Serializable data object InvestRoute
@Serializable data object MoreRoute

// movimientos
@Serializable data class TxEditorRoute(val id: String? = null, val type: String? = null, val accountId: String? = null)
@Serializable data object StatsRoute
@Serializable data object HomeCustomizeRoute
@Serializable data class CalendarRoute(val month: String? = null)
/** resumen del mes en historias (tipo Wrapped); month = yyyy-MM */
@Serializable data class WrappedRoute(val month: String? = null)
@Serializable data object PersonalizeRoute
@Serializable data object PinSetupRoute
@Serializable data object SubscriptionsRoute
/** vestir a Gotita (complementos y color) */
@Serializable data object GotitaRoute
@Serializable data object AchievementsRoute

// gestión (Más)
@Serializable data object AccountsRoute
@Serializable data class AccountDetailRoute(val id: String)
@Serializable data class AccountEditorRoute(val id: String? = null)
@Serializable data object CategoriesRoute
@Serializable data class CategoryEditorRoute(val id: String? = null, val kind: String = "expense")
@Serializable data object RecurringRoute
@Serializable data class RecurringEditorRoute(val id: String? = null)
@Serializable data object GoalsRoute
@Serializable data class GoalEditorRoute(val id: String? = null)
@Serializable data object SettingsRoute
@Serializable data object DataRoute

// horas trabajadas
@Serializable data object WorkRoute
@Serializable data class ShiftEditorRoute(val id: String? = null, val companyId: String? = null)
@Serializable data class CompanyEditorRoute(val id: String? = null)

// cuentas claras
@Serializable data class PersonDetailRoute(val id: String)
@Serializable data class PersonEditorRoute(val id: String? = null)
@Serializable data class DebtEditorRoute(val kind: String = "owe", val personId: String? = null)

// inversiones
@Serializable data class AssetDetailRoute(val id: String)
@Serializable data class AssetEditorRoute(val id: String? = null)
@Serializable data class OpEditorRoute(val assetId: String, val opId: String? = null)
