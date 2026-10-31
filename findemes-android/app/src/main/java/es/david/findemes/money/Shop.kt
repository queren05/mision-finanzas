package es.david.findemes.money

import android.app.Activity
import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.android.billingclient.api.AcknowledgePurchaseParams
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.PendingPurchasesParams
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import es.david.findemes.logic.Game
import es.david.findemes.logic.Sound
import es.david.findemes.model.Content
import es.david.findemes.model.Rarity

/** Las compras de Google Play. Nada de lo que se vende hace ir más rápido. */
object Shop {
    const val NO_ADS = "sin_anuncios"
    const val STARTER = "paquete_inicio"
    val products: List<String> get() = listOf(NO_ADS, STARTER) + Content.skins.mapNotNull { it.product }.filter { it != STARTER }
    /** precios por si Google Play todavía no ha contestado */
    fun fallbackPrice(id: String): String {
        val v = when (id) { NO_ADS -> "3.99"; STARTER -> "1.99"; else -> "0.99" }
        return if (es.david.findemes.support.L10n.lang == es.david.findemes.support.Lang.en) "€$v" else v.replace(".", ",") + " €"
    }

    private lateinit var prefs: android.content.SharedPreferences
    private var client: BillingClient? = null
    private var details = mapOf<String, ProductDetails>()

    /** lo comprado (se guarda también aquí por si se juega sin conexión) */
    var owned by mutableStateOf(setOf<String>())
        private set
    var prices by mutableStateOf(mapOf<String, String>())
        private set

    val noAds: Boolean get() = NO_ADS in owned
    fun owns(id: String) = id in owned
    fun price(id: String): String = prices[id] ?: fallbackPrice(id)

    fun init(context: Context) {
        prefs = context.getSharedPreferences("compras", Context.MODE_PRIVATE)
        owned = prefs.getStringSet("owned", emptySet())!!.toSet()
        val c = BillingClient.newBuilder(context.applicationContext)
            .setListener { r, list -> if (r.responseCode == BillingClient.BillingResponseCode.OK) list?.forEach { handle(it) } else if (r.responseCode != BillingClient.BillingResponseCode.USER_CANCELED) Money.say("No se ha podido comprar") }
            .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
            .enableAutoServiceReconnection()
            .build()
        client = c
        c.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(r: BillingResult) {
                if (r.responseCode != BillingClient.BillingResponseCode.OK) return
                queryDetails(); restore(quiet = true)
            }
            override fun onBillingServiceDisconnected() {}
        })
    }

    private fun queryDetails() {
        val params = QueryProductDetailsParams.newBuilder().setProductList(products.map {
            QueryProductDetailsParams.Product.newBuilder().setProductId(it).setProductType(BillingClient.ProductType.INAPP).build()
        }).build()
        client?.queryProductDetailsAsync(params) { r, result ->
            if (r.responseCode != BillingClient.BillingResponseCode.OK) return@queryProductDetailsAsync
            val list = result.productDetailsList
            details = list.associateBy { it.productId }
            prices = list.mapNotNull { d -> d.oneTimePurchaseOfferDetails?.formattedPrice?.let { d.productId to it } }.toMap()
        }
    }

    /** vuelve a pedir a Google Play lo comprado (al abrir y con «Restaurar compras») */
    fun restore(quiet: Boolean = false) {
        val c = client
        if (c == null || !c.isReady) { if (!quiet) Money.say("Google Play no está disponible"); return }
        c.queryPurchasesAsync(QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.INAPP).build()) { r, list ->
            if (r.responseCode != BillingClient.BillingResponseCode.OK) return@queryPurchasesAsync
            list.forEach { handle(it) }
            if (!quiet) Money.say(if (list.any { it.purchaseState == Purchase.PurchaseState.PURCHASED }) "Compras recuperadas" else "No hay compras que recuperar")
        }
    }

    fun buy(activity: Activity, id: String) {
        val c = client
        val d = details[id]
        if (c == null || !c.isReady || d == null) { Money.say("La tienda abrirá cuando el juego esté en Google Play"); return }
        val p = BillingFlowParams.ProductDetailsParams.newBuilder().setProductDetails(d).build()
        c.launchBillingFlow(activity, BillingFlowParams.newBuilder().setProductDetailsParamsList(listOf(p)).build())
    }

    private fun handle(p: Purchase) {
        if (p.purchaseState != Purchase.PurchaseState.PURCHASED) return
        if (!p.isAcknowledged) {
            client?.acknowledgePurchase(AcknowledgePurchaseParams.newBuilder().setPurchaseToken(p.purchaseToken).build()) { }
        }
        val fresh = p.products.filter { it !in owned }
        if (fresh.isEmpty()) return
        // Google Play contesta en otro hilo: el estado del juego se cambia en el principal
        android.os.Handler(android.os.Looper.getMainLooper()).post { grant(fresh) }
    }

    private fun grant(ids: List<String>) {
        owned = owned + ids
        prefs.edit().putStringSet("owned", owned).apply()
        val game = Game.shared
        if (STARTER in ids && !game.s.starterClaimed) {
            // el paquete de inicio: la oveja y tres sobres épicos (una sola vez)
            game.s.starterClaimed = true
            game.s.pendingChests = game.s.pendingChests + List(3) { Rarity.epica }
        }
        game.s.skinsOwned = game.s.skinsOwned + Content.skins.filter { it.product in ids }.map { it.id }
        game.save()
        Sound.fanfare()
        Money.say("¡Gracias por tu compra!")
    }
}
