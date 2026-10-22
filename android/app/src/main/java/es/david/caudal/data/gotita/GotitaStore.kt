package es.david.caudal.data.gotita

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringSetPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

private val Context.gotitaStore: DataStore<Preferences> by preferencesDataStore(name = "gotita")

/** qué logros ya se han celebrado (para enseñar una sola celebración por logro nuevo) */
@Singleton
class GotitaStore @Inject constructor(@ApplicationContext context: Context) {
    private val store = context.gotitaStore
    private val celebratedKey = stringSetPreferencesKey("celebrated")
    private val readyKey = booleanPreferencesKey("ready")

    data class State(val ready: Boolean, val celebrated: Set<String>)

    val state: Flow<State> = store.data.map { State(it[readyKey] ?: false, it[celebratedKey] ?: emptySet()) }

    suspend fun celebrate(ids: Collection<String>) {
        store.edit { it[celebratedKey] = (it[celebratedKey] ?: emptySet()) + ids }
    }

    /** la primera vez: lo que ya estaba conseguido se da por celebrado, sin avalancha de avisos */
    suspend fun initialize(alreadyDone: Collection<String>) {
        store.edit {
            if (it[readyKey] != true) {
                it[celebratedKey] = (it[celebratedKey] ?: emptySet()) + alreadyDone
                it[readyKey] = true
            }
        }
    }
}
