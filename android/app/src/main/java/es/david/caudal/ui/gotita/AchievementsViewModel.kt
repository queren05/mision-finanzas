package es.david.caudal.ui.gotita

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import es.david.caudal.data.gotita.GotitaStore
import es.david.caudal.data.repo.FinanceRepository
import es.david.caudal.data.repo.SettingsRepository
import es.david.caudal.domain.calc.Achievement
import es.david.caudal.domain.calc.Achievements
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

/** logros calculados al momento y el siguiente que toca celebrar */
@HiltViewModel
class AchievementsViewModel @Inject constructor(
    repo: FinanceRepository,
    settings: SettingsRepository,
    private val store: GotitaStore,
) : ViewModel() {
    val achievements: StateFlow<List<Achievement>?> = combine(repo.data.filterNotNull(), settings.settings) { d, s -> Achievements.all(d, s.monthStart) }
        .flowOn(kotlinx.coroutines.Dispatchers.Default)
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)

    val unlockedHats: StateFlow<Set<String>> = achievements.filterNotNull().map { Achievements.unlockedHats(it) }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), setOf("nada"))

    /** el primer logro conseguido que aún no se ha celebrado */
    val pending: StateFlow<Achievement?> = combine(achievements.filterNotNull(), store.state) { list, st ->
        if (!st.ready) {
            store.initialize(list.filter { it.done }.map { it.id })
            null
        } else list.firstOrNull { it.done && it.id !in st.celebrated }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)

    fun celebrated(id: String) = viewModelScope.launch { store.celebrate(listOf(id)) }
}
