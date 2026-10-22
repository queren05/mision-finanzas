package es.david.caudal.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import es.david.caudal.data.repo.FinanceRepository
import es.david.caudal.data.repo.SessionState
import es.david.caudal.data.repo.SettingsRepository
import es.david.caudal.domain.model.AppSettings
import es.david.caudal.domain.model.Tx
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

/** estado de toda la app: ajustes, importes ocultos, bloqueo y «deshacer» */
@HiltViewModel
class AppViewModel @Inject constructor(
    private val repo: FinanceRepository,
    private val settingsRepo: SettingsRepository,
    private val session: SessionState,
) : ViewModel() {
    val settings: StateFlow<AppSettings?> = settingsRepo.settings.stateIn(viewModelScope, SharingStarted.Eagerly, null)
    val hidden = session.hidden
    val locked = session.locked
    val lastDeleted: StateFlow<Tx?> = repo.lastDeleted

    init {
        viewModelScope.launch {
            val s = settingsRepo.settings.first()
            if (session.hidden.value == null) session.setHidden(s.hideAmountsOnLaunch)
            if (s.lock) session.setLocked(true)
            // si ya hay datos (por ejemplo, de una versión anterior) no hace falta la bienvenida
            if (!s.onboarded && !repo.isEmpty()) settingsRepo.update { it.copy(onboarded = true) }
            repo.runRecurring()
        }
    }

    fun toggleHidden() = session.toggleHidden()
    fun undo() = viewModelScope.launch { repo.undoDelete() }
    fun clearUndo() = repo.clearUndo()

    /** al volver a la app: recurrentes al día */
    fun onForeground() = viewModelScope.launch { repo.runRecurring() }

    /** al salir de la app: se bloquea si está activado */
    fun onBackground() {
        if (settings.value?.lock == true) session.setLocked(true)
    }

    fun unlocked() = session.setLocked(false)

    /**
     * resultado de importar una copia abierta con Caudal: nº de movimientos, -1 si no vale,
     * -2 si está cifrada y hace falta la contraseña, -3 si la contraseña no es correcta; null mientras no hay
     */
    val importResult = kotlinx.coroutines.flow.MutableStateFlow<Int?>(null)

    fun importFrom(context: android.content.Context, uri: android.net.Uri, password: String? = null) = viewModelScope.launch {
        importResult.value = runCatching {
            var text = kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) { context.contentResolver.openInputStream(uri)!!.use { it.readBytes().decodeToString() } }
            if (es.david.caudal.data.export.EncryptedBackup.isEncrypted(text)) {
                if (password == null) return@runCatching -2
                text = runCatching { es.david.caudal.data.export.EncryptedBackup.decrypt(text, password) }.getOrNull() ?: return@runCatching -3
            }
            repo.importBackup(text).data.txs.size
        }.getOrDefault(-1)
    }
}
