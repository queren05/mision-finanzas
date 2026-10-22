package es.david.caudal.ui.common

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import es.david.caudal.data.repo.FinanceRepository
import es.david.caudal.data.repo.SettingsRepository
import es.david.caudal.domain.calc.Ledger
import es.david.caudal.domain.model.AppSettings
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * ViewModel común: los datos con sus cálculos (Ledger), los ajustes y una forma de lanzar cambios.
 * Las pantallas sencillas lo usan tal cual; las que necesitan más (listas paginadas…) tienen el suyo.
 */
@HiltViewModel
class FinanceViewModel @Inject constructor(
    val repo: FinanceRepository,
    val settingsRepo: SettingsRepository,
) : ViewModel() {
    val ledger: StateFlow<Ledger?> = repo.ledger.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)
    val settings: StateFlow<AppSettings?> = settingsRepo.settings.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)

    /** lanza un cambio en segundo plano (sin bloquear la pantalla) */
    fun run(block: suspend FinanceRepository.() -> Unit): Job = viewModelScope.launch { repo.block() }

    fun updateSettings(f: (AppSettings) -> AppSettings): Job = viewModelScope.launch { settingsRepo.update(f) }
}
