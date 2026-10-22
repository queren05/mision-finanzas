package es.david.caudal.data.prices

import es.david.caudal.domain.model.Asset
import es.david.caudal.domain.model.Quote
import javax.inject.Inject
import javax.inject.Singleton

data class PricePoint(val epochMillis: Long, val close: Double)

/**
 * Origen de los precios de las inversiones. Hoy solo hay precio a mano (sin red); para conectar un
 * proveedor con licencia basta con otra implementación y cambiarla en el módulo de Hilt.
 */
interface PriceProvider {
    /** true si da precios de verdad (si no, la app pide el precio a mano) */
    val isLive: Boolean
    suspend fun quote(asset: Asset): Quote?
    suspend fun history(asset: Asset, range: String): List<PricePoint>
}

@Singleton
class ManualPriceProvider @Inject constructor() : PriceProvider {
    override val isLive = false
    override suspend fun quote(asset: Asset): Quote? = null
    override suspend fun history(asset: Asset, range: String): List<PricePoint> = emptyList()
}
