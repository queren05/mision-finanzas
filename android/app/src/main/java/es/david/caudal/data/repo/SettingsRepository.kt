package es.david.caudal.data.repo

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import dagger.hilt.android.qualifiers.ApplicationContext
import es.david.caudal.domain.model.AccountsStyle
import es.david.caudal.domain.model.AppSettings
import es.david.caudal.domain.model.HomeItem
import es.david.caudal.domain.model.ThemeMode
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import javax.inject.Inject
import javax.inject.Singleton

private val Context.settingsStore: DataStore<Preferences> by preferencesDataStore(name = "settings")

/** Ajustes en DataStore (no van en Room) */
@Singleton
class SettingsRepository @Inject constructor(@ApplicationContext context: Context) {
    private val store = context.settingsStore

    private object K {
        val name = stringPreferencesKey("name")
        val accent = stringPreferencesKey("accent")
        val hideOnLaunch = booleanPreferencesKey("hideAmountsOnLaunch")
        val lock = booleanPreferencesKey("lock")
        val monthStart = intPreferencesKey("monthStart")
        val currency = stringPreferencesKey("currency")
        val moduleWork = booleanPreferencesKey("moduleWork")
        val moduleDebts = booleanPreferencesKey("moduleDebts")
        val moduleInvest = booleanPreferencesKey("moduleInvest")
        val home = stringPreferencesKey("home")
        val accountsStyle = stringPreferencesKey("accountsStyle")
        val theme = stringPreferencesKey("theme")
        val dynamicColor = booleanPreferencesKey("dynamicColor")
        val amoled = booleanPreferencesKey("amoled")
        val tabLabels = booleanPreferencesKey("tabLabels")
        val mascot = booleanPreferencesKey("mascot")
        val haptics = booleanPreferencesKey("haptics")
        val appIcon = stringPreferencesKey("appIcon")
        val onboarded = booleanPreferencesKey("onboarded")
        val seed = intPreferencesKey("seed")
        /** campos de la copia de seguridad que esta versión no conoce (nivel superior y ajustes) */
        val backupExtra = stringPreferencesKey("backupExtra")
        val settingsExtra = stringPreferencesKey("settingsExtra")
        val snapshots = stringPreferencesKey("snapshots")
    }

    val settings: Flow<AppSettings> = store.data.map { readNow(it) }

    suspend fun current(): AppSettings = settings.first()

    suspend fun update(f: (AppSettings) -> AppSettings) {
        store.edit { p ->
            val s = f(readNow(p))
            p[K.name] = s.name
            p[K.accent] = s.accent
            p[K.hideOnLaunch] = s.hideAmountsOnLaunch
            p[K.lock] = s.lock
            p[K.monthStart] = s.monthStart.coerceIn(1, 28)
            p[K.currency] = s.currency
            p[K.moduleWork] = s.moduleWork
            p[K.moduleDebts] = s.moduleDebts
            p[K.moduleInvest] = s.moduleInvest
            p[K.home] = encodeHome(s.home)
            p[K.accountsStyle] = s.accountsStyle.raw
            p[K.theme] = s.theme.raw
            p[K.dynamicColor] = s.dynamicColor
            p[K.amoled] = s.amoled
            p[K.tabLabels] = s.tabLabels
            p[K.mascot] = s.mascot
            p[K.haptics] = s.haptics
            p[K.appIcon] = s.appIcon
            p[K.onboarded] = s.onboarded
            p[K.seed] = s.seed
        }
    }

    private fun readNow(p: Preferences) = AppSettings(
        name = p[K.name] ?: "", accent = p[K.accent] ?: "#e4b3cb", hideAmountsOnLaunch = p[K.hideOnLaunch] ?: false,
        lock = p[K.lock] ?: false, monthStart = p[K.monthStart] ?: 1, currency = p[K.currency] ?: "EUR",
        moduleWork = p[K.moduleWork] ?: false, moduleDebts = p[K.moduleDebts] ?: false, moduleInvest = p[K.moduleInvest] ?: false,
        home = HomeItem.normalized(p[K.home]?.let(::decodeHome)), accountsStyle = AccountsStyle.of(p[K.accountsStyle]),
        theme = ThemeMode.of(p[K.theme]), dynamicColor = p[K.dynamicColor] ?: false,
        amoled = p[K.amoled] ?: false, tabLabels = p[K.tabLabels] ?: true, mascot = p[K.mascot] ?: true,
        haptics = p[K.haptics] ?: true, appIcon = p[K.appIcon] ?: "default",
        onboarded = p[K.onboarded] ?: false, seed = p[K.seed] ?: 0,
    )

    // campos desconocidos de la copia de seguridad
    suspend fun backupExtra(): String = store.data.first()[K.backupExtra] ?: ""
    suspend fun settingsExtra(): String = store.data.first()[K.settingsExtra] ?: ""
    suspend fun snapshots(): String = store.data.first()[K.snapshots] ?: ""
    suspend fun setBackupExtras(top: String, settings: String, snapshots: String) {
        store.edit { it[K.backupExtra] = top; it[K.settingsExtra] = settings; it[K.snapshots] = snapshots }
    }

    companion object {
        fun encodeHome(list: List<HomeItem>): String = buildJsonArray {
            list.forEach { add(buildJsonObject { put("id", it.id); put("on", it.on) }) }
        }.toString()

        fun decodeHome(s: String): List<HomeItem>? = runCatching {
            (Json.parseToJsonElement(s) as JsonArray).map {
                val o = it.jsonObject
                HomeItem(o["id"]!!.jsonPrimitive.content, o["on"]?.jsonPrimitive?.boolean ?: true)
            }
        }.getOrNull()
    }
}
