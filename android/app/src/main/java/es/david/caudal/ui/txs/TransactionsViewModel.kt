package es.david.caudal.ui.txs

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.paging.PagingData
import androidx.paging.cachedIn
import dagger.hilt.android.lifecycle.HiltViewModel
import es.david.caudal.data.db.FilterSums
import es.david.caudal.data.repo.FinanceRepository
import es.david.caudal.data.repo.TxFilter
import es.david.caudal.domain.calc.Ledger
import es.david.caudal.domain.model.Tx
import es.david.caudal.domain.model.TxType
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@OptIn(ExperimentalCoroutinesApi::class, FlowPreview::class)
@HiltViewModel
class TransactionsViewModel @Inject constructor(private val repo: FinanceRepository) : ViewModel() {
    private val _filter = MutableStateFlow(TxFilter())
    val filter: StateFlow<TxFilter> = _filter.asStateFlow()

    /** lo que se busca va con un pequeño retraso para no consultar a cada letra */
    private val effective = _filter.debounce { if (it.query.isEmpty()) 0L else 250L }

    val pages: Flow<PagingData<Tx>> = effective.flatMapLatest { repo.pagedTxs(it) }.cachedIn(viewModelScope)
    val dayTotals: StateFlow<Map<String, Long>> = effective.flatMapLatest { f -> repo.dayTotals(f).map { l -> l.associate { it.date to it.total } } }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyMap())
    val sums: StateFlow<FilterSums> = effective.flatMapLatest { repo.filterSums(it) }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), FilterSums(0, 0))
    val months: StateFlow<List<String>> = repo.months.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())
    val ledger: StateFlow<Ledger?> = repo.ledger.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)

    fun setQuery(q: String) = _filter.update { it.copy(query = q) }
    fun setMonth(m: String) = _filter.update { it.copy(month = m) }
    fun setType(t: TxType?) = _filter.update { it.copy(type = t) }
    fun setAccount(id: String?) = _filter.update { it.copy(accountId = id) }

    fun delete(t: Tx) = viewModelScope.launch { repo.delete(t) }
    fun duplicate(t: Tx) = viewModelScope.launch { repo.duplicate(t) }
}
