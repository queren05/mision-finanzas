package es.david.caudal.data.billing

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import javax.inject.Inject
import javax.inject.Singleton

/** funciones que en el futuro podrían ser Premium */
enum class Feature { CSV_EXPORT, ENCRYPTED_BACKUP, BANK_TEMPLATES, WIDGETS_EXTRA }

/**
 * Acceso a Premium. La versión 1 es gratis y sin compras: todo desbloqueado.
 * Para añadir Premium: implementar esta interfaz con Google Play Billing y cambiarla en el módulo de Hilt.
 */
interface Entitlements {
    val isPremium: StateFlow<Boolean>
    fun has(feature: Feature): Boolean
}

@Singleton
class FreeEntitlements @Inject constructor() : Entitlements {
    override val isPremium: StateFlow<Boolean> = MutableStateFlow(true)
    override fun has(feature: Feature) = true
}
