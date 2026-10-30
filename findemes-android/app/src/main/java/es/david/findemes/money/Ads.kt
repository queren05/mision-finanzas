package es.david.findemes.money

import android.app.Activity
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.google.android.gms.ads.AdError
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.FullScreenContentCallback
import com.google.android.gms.ads.LoadAdError
import com.google.android.gms.ads.MobileAds
import com.google.android.gms.ads.rewarded.RewardedAd
import com.google.android.gms.ads.rewarded.RewardedAdLoadCallback
import com.google.android.ump.ConsentInformation
import com.google.android.ump.ConsentRequestParameters
import com.google.android.ump.UserMessagingPlatform
import es.david.findemes.BuildConfig
import es.david.findemes.logic.Music
import java.util.concurrent.atomic.AtomicBoolean

/** Anuncios con premio (solo cuando el jugador quiere) y el aviso de privacidad de la UE */
object Ads {
    private var consent: ConsentInformation? = null
    private val started = AtomicBoolean(false)
    private var ad: RewardedAd? = null
    private var loading = false
    /** hay un anuncio cargado y listo */
    var ready by mutableStateOf(false)
        private set
    /** en la UE hay que poder cambiar el consentimiento desde Ajustes */
    var privacyButton by mutableStateOf(false)
        private set

    /** al abrir el juego: primero el consentimiento (si hace falta) y luego los anuncios */
    fun start(activity: Activity) {
        val ci = UserMessagingPlatform.getConsentInformation(activity)
        consent = ci
        ci.requestConsentInfoUpdate(activity, ConsentRequestParameters.Builder().build(), {
            UserMessagingPlatform.loadAndShowConsentFormIfRequired(activity) {
                privacyButton = ci.privacyOptionsRequirementStatus == ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED
                if (ci.canRequestAds()) initAds(activity)
            }
        }, {
            if (ci.canRequestAds()) initAds(activity)
        })
        // si ya se dio el consentimiento otra vez, no hay que esperar
        if (ci.canRequestAds()) initAds(activity)
    }

    private fun initAds(activity: Activity) {
        if (!started.compareAndSet(false, true)) return
        val ctx = activity.applicationContext
        Thread { MobileAds.initialize(ctx) { activity.runOnUiThread { load(activity) } } }.start()
    }

    fun load(activity: Activity) {
        if (!started.get() || loading || ad != null || Shop.noAds) return
        loading = true
        RewardedAd.load(activity, BuildConfig.ADMOB_REWARDED, AdRequest.Builder().build(), object : RewardedAdLoadCallback() {
            override fun onAdLoaded(a: RewardedAd) { ad = a; loading = false; ready = true }
            override fun onAdFailedToLoad(e: LoadAdError) { ad = null; loading = false; ready = false }
        })
    }

    /** enseña el anuncio; `done(true)` solo si se ha visto entero */
    fun show(activity: Activity, done: (Boolean) -> Unit) {
        val a = ad
        if (a == null) { load(activity); done(false); return }
        var earned = false
        ad = null; ready = false
        Music.pause()
        a.fullScreenContentCallback = object : FullScreenContentCallback() {
            override fun onAdDismissedFullScreenContent() { Music.resume(); done(earned); load(activity) }
            override fun onAdFailedToShowFullScreenContent(e: AdError) { Music.resume(); done(false); load(activity) }
        }
        a.show(activity) { earned = true }
    }

    fun showPrivacy(activity: Activity) {
        UserMessagingPlatform.showPrivacyOptionsForm(activity) { }
    }
}
