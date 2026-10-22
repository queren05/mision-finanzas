package es.david.caudal.notify

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringSetPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

private val Context.alertsStore: DataStore<Preferences> by preferencesDataStore(name = "alerts")

data class AlertPrefs(val budgets: Boolean = false, val charges: Boolean = false)

/** qué avisos están activados y cuáles se han enviado ya (para no repetirlos) */
@Singleton
class AlertsStore @Inject constructor(@ApplicationContext context: Context) {
    private val store = context.alertsStore
    private val budgets = booleanPreferencesKey("budgets")
    private val charges = booleanPreferencesKey("charges")
    private val sent = stringSetPreferencesKey("sent")

    val prefs: Flow<AlertPrefs> = store.data.map { AlertPrefs(it[budgets] ?: false, it[charges] ?: false) }
    suspend fun current() = prefs.first()
    suspend fun setBudgets(on: Boolean) = store.edit { it[budgets] = on }
    suspend fun setCharges(on: Boolean) = store.edit { it[charges] = on }

    /** marca como enviados; devuelve solo los que no lo estaban. Se queda con los de los últimos ~3 meses. */
    suspend fun markNew(keys: List<String>, keepFrom: String): List<String> {
        var fresh = emptyList<String>()
        store.edit { p ->
            val old = p[sent].orEmpty()
            fresh = keys.filter { it !in old }
            p[sent] = (old + fresh).filter { it.substringBefore(":") >= keepFrom }.toSet()
        }
        return fresh
    }
}
