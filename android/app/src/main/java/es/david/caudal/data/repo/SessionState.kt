package es.david.caudal.data.repo

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject
import javax.inject.Singleton

/** estado de la sesión (no se guarda): importes ocultos con el ojo y bloqueo */
@Singleton
class SessionState @Inject constructor() {
    private val _hidden = MutableStateFlow<Boolean?>(null)
    /** null hasta que se leen los ajustes al abrir */
    val hidden: StateFlow<Boolean?> = _hidden.asStateFlow()
    fun setHidden(v: Boolean) { _hidden.value = v }
    fun toggleHidden() { _hidden.value = !(_hidden.value ?: false) }

    private val _locked = MutableStateFlow(false)
    val locked: StateFlow<Boolean> = _locked.asStateFlow()
    fun setLocked(v: Boolean) { _locked.value = v }
}
