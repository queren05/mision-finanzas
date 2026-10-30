package es.david.findemes.logic

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.media.MediaPlayer
import android.os.Build
import android.os.SystemClock
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import es.david.findemes.R
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.exp
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.random.Random

/** Vibración y sonidos. Todo se sintetiza al arrancar (sin archivos), como en el iPhone.
 *  Un hilo mezcla hasta 12 voces y pasa por un limitador para que nunca sature. */
object Sound {
    @Volatile var on = true
    var haptics = true

    private const val SR = 44_100
    private var vibrator: Vibrator? = null
    private val b = HashMap<String, List<FloatArray>>()
    private val lastPlayed = HashMap<String, Double>()
    /** cada sonido no se repite antes de esto (si no, con muchas huchas se amontonan y se rayan) */
    private val gap = mapOf("smash" to 0.07, "coin" to 0.06, "crack" to 0.045, "pop" to 0.09, "boom" to 0.15, "swing" to 0.04, "thud" to 0.05)

    private class Voice(val data: FloatArray, val volume: Float) { var pos = 0 }
    private val voices = ArrayList<Voice>()
    private var track: AudioTrack? = null
    private var thread: Thread? = null
    @Volatile private var running = false

    fun init(context: Context) {
        vibrator = if (Build.VERSION.SDK_INT >= 31) (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
            else @Suppress("DEPRECATION") (context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator)
        // varias versiones de cada sonido para que no suene siempre igual
        b["crack"] = List(4) { sCrack() }
        b["smash"] = List(4) { sSmash() }
        b["coin"] = listOf(1.0, 1.12, 1.26, 1.5).map { sCoin(it) }
        // escala que sube con el combo: cada rotura suena un poco más aguda
        for ((i, k) in listOf(1.0, 1.12, 1.26, 1.335, 1.5, 1.68, 1.89, 2.0).withIndex()) b["up$i"] = listOf(sCoin(k))
        b["swing"] = List(3) { sWhoosh() }
        b["thud"] = listOf(sThud(70.0, 0.25))
        b["stamp"] = listOf(sThud(95.0, 0.6))
        b["boom"] = listOf(sBoom())
        b["till"] = listOf(sTill())
        b["pop"] = listOf(sPop())
        b["click"] = listOf(sClick())
        b["fanfare"] = listOf(sFanfare())
        b["sad"] = listOf(sSad())
    }

    private fun start() {
        if (running) return
        val min = AudioTrack.getMinBufferSize(SR, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_FLOAT)
        val t = AudioTrack.Builder()
            .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_GAME).setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build())
            .setAudioFormat(AudioFormat.Builder().setEncoding(AudioFormat.ENCODING_PCM_FLOAT).setSampleRate(SR).setChannelMask(AudioFormat.CHANNEL_OUT_MONO).build())
            .setBufferSizeInBytes(max(min, 1024 * 4))
            .setTransferMode(AudioTrack.MODE_STREAM)
            .apply { if (Build.VERSION.SDK_INT >= 26) setPerformanceMode(AudioTrack.PERFORMANCE_MODE_LOW_LATENCY) }
            .build()
        track = t
        running = true
        t.play()
        thread = Thread {
            val n = 256
            val out = FloatArray(n)
            var gain = 1f
            while (running) {
                java.util.Arrays.fill(out, 0f)
                synchronized(voices) {
                    val it = voices.iterator()
                    while (it.hasNext()) {
                        val v = it.next()
                        val k = min(n, v.data.size - v.pos)
                        for (i in 0 until k) out[i] += v.data[v.pos + i] * v.volume
                        v.pos += k
                        if (v.pos >= v.data.size) it.remove()
                    }
                }
                // limitador: baja rápido si se pasa y sube despacio
                for (i in 0 until n) {
                    val x = out[i] * 0.75f
                    val peak = abs(x) * gain
                    if (peak > 0.95f) gain = 0.95f / abs(x)
                    out[i] = x * gain
                    gain = min(1f, gain + 0.00002f)
                }
                t.write(out, 0, n, AudioTrack.WRITE_BLOCKING)
            }
        }.apply { priority = Thread.MAX_PRIORITY; start() }
    }

    fun stop() {
        running = false
        thread?.join(200); thread = null
        track?.let { it.pause(); it.flush(); it.release() }
        track = null
        synchronized(voices) { voices.clear() }
    }

    private fun play(name: String, volume: Float = 1f) {
        if (!on) return
        val buf = b[name]?.random() ?: return
        start()
        val now = SystemClock.elapsedRealtime() / 1000.0
        val g = gap[name]
        if (g != null && now - (lastPlayed[name] ?: 0.0) < g) return
        synchronized(voices) {
            // si están todas sonando, no se corta ninguna (cortar a medias es lo que hace «clic»)
            if (voices.size >= 12) return
            lastPlayed[name] = now
            voices.add(Voice(buf, volume))
        }
    }

    private fun buzz(ms: Long, amp: Int) {
        if (!haptics) return
        val v = vibrator ?: return
        try { v.vibrate(VibrationEffect.createOneShot(ms, amp.coerceIn(1, 255))) } catch (_: Exception) { }
    }
    private fun pattern(times: LongArray, amps: IntArray) {
        if (!haptics) return
        try { vibrator?.vibrate(VibrationEffect.createWaveform(times, amps, -1)) } catch (_: Exception) { }
    }
    private fun success() = pattern(longArrayOf(0, 18, 60, 22), intArrayOf(0, 150, 0, 220))
    private fun error() = pattern(longArrayOf(0, 20, 50, 20, 50, 30), intArrayOf(0, 200, 0, 200, 0, 255))
    private fun warning() = pattern(longArrayOf(0, 20, 70, 20), intArrayOf(0, 220, 0, 160))

    // MARK: eventos

    fun swing() = play("swing", 0.5f)
    fun miss() { play("thud", 0.6f); buzz(8, 60) }
    fun hit(crit: Boolean) {
        play("crack")
        if (crit) buzz(22, 255) else buzz(10, 180)
    }
    fun smash(big: Boolean, combo: Int = 0) {
        play("smash")
        if (combo > 1) play("up${min(7, combo / 4)}", 0.75f) else play("coin", 0.7f)
        buzz(18, if (big) 255 else 210)
    }
    fun boom() { play("boom"); buzz(30, 255) }
    fun coin() = play("coin", 0.6f)
    fun till() { play("till"); success() }
    fun stamp() { play("stamp"); buzz(25, 255) }
    fun pop() = play("pop", 0.5f)
    fun click() { play("click", 0.7f); buzz(6, 90) }
    fun fanfare() { play("fanfare"); success() }
    fun sad() { play("sad"); error() }
    fun denied() { play("thud", 0.5f); warning() }

    // MARK: síntesis

    private fun make(dur: Double, f: (Double, DoubleArray) -> Double): FloatArray {
        val n = (SR * dur).toInt()
        val p = FloatArray(n)
        val state = DoubleArray(1)
        for (i in 0 until n) p[i] = max(-1.0, min(1.0, f(i.toDouble() / SR, state))).toFloat()
        return p
    }
    private fun noise() = Random.nextDouble(-1.0, 1.0)
    private const val TAU = 2 * PI

    /** grieta: chasquido corto y seco */
    private fun sCrack(): FloatArray {
        val f1 = Random.nextDouble(1800.0, 2600.0)
        return make(0.09) { t, lp ->
            val n = noise()
            lp[0] += (n - lp[0]) * 0.55
            val env = exp(-t * 60)
            (n - lp[0]) * env * 0.55 + sin(TAU * f1 * t) * exp(-t * 80) * 0.25
        }
    }
    /** cerámica rompiéndose: ruido + muchos tintineos agudos */
    private fun sSmash(): FloatArray {
        val tinks = List(9) { Random.nextDouble(2200.0, 6200.0) to Random.nextDouble(0.0, 0.16) }
        return make(0.55) { t, lp ->
            val n = noise()
            lp[0] += (n - lp[0]) * 0.25
            var v = lp[0] * exp(-t * 14) * 0.8
            for ((f, t0) in tinks) if (t >= t0) {
                val u = t - t0
                v += sin(TAU * f * u) * exp(-u * 30) * 0.16
            }
            v
        }
    }
    private fun sCoin(k: Double): FloatArray = make(0.32) { t, _ ->
        val a = sin(TAU * 2093 * k * t) + 0.6 * sin(TAU * 3136 * k * t)
        val b2 = if (t > 0.07) sin(TAU * 2637 * k * (t - 0.07)) * exp(-(t - 0.07) * 14) else 0.0
        (a * exp(-t * 16) + b2) * 0.18
    }
    private fun sWhoosh(): FloatArray = make(0.16) { t, lp ->
        val n = noise()
        val cut = 0.05 + 0.4 * (t / 0.16)
        lp[0] += (n - lp[0]) * cut
        lp[0] * sin(PI * t / 0.16) * 0.35
    }
    private fun sThud(f: Double, amount: Double): FloatArray = make(0.25) { t, lp ->
        val n = noise()
        lp[0] += (n - lp[0]) * 0.08
        (sin(TAU * f * t * (1 - t)) * 0.8 + lp[0] * amount) * exp(-t * 18)
    }
    private fun sBoom(): FloatArray = make(0.9) { t, lp ->
        val n = noise()
        lp[0] += (n - lp[0]) * 0.04
        (lp[0] * 2.2 + sin(TAU * 55 * t) * 0.6) * exp(-t * 5)
    }
    private fun sTill(): FloatArray = make(0.9) { t, _ ->
        var v = 0.0
        for ((i, f) in listOf(1568.0, 2093.0, 2637.0).withIndex()) {
            val u = t - i * 0.05
            if (u > 0) v += sin(TAU * f * u) * exp(-u * 10)
        }
        val bell = if (t > 0.22) sin(TAU * 3520 * (t - 0.22)) * exp(-(t - 0.22) * 5) * 0.8 else 0.0
        (v + bell) * 0.16
    }
    private fun sPop(): FloatArray = make(0.08) { t, _ -> sin(TAU * (500 + 2500 * t) * t) * exp(-t * 40) * 0.3 }
    private fun sClick(): FloatArray = make(0.05) { t, _ -> sin(TAU * 1400 * t) * exp(-t * 120) * 0.35 }
    private fun sFanfare(): FloatArray {
        val notes = listOf(523.0, 659.0, 784.0, 1047.0, 784.0, 1047.0)
        return make(1.1) { t, _ ->
            var v = 0.0
            for ((i, f) in notes.withIndex()) {
                val u = t - i * 0.11
                if (u < 0) continue
                v += (sin(TAU * f * u) + 0.3 * sin(2 * TAU * f * u)) * exp(-u * 6)
            }
            v * 0.12
        }
    }
    private fun sSad(): FloatArray {
        val notes = listOf(392.0, 370.0, 349.0, 262.0)
        return make(1.3) { t, _ ->
            var v = 0.0
            for ((i, f) in notes.withIndex()) {
                val u = t - i * 0.25
                if (u < 0) continue
                v += sin(TAU * f * u + 2 * sin(TAU * 5 * u)) * exp(-u * (if (i == 3) 2 else 5))
            }
            v * 0.14
        }
    }
}

/** música de ascensor de fondo, en bucle infinito (Kevin MacLeod, CC BY 4.0; el crédito va en Ajustes) */
object Music {
    private var player: MediaPlayer? = null
    private var ctx: Context? = null
    var on = true
        set(v) { field = v; if (v) resume() else pause() }

    fun init(context: Context) { ctx = context.applicationContext }

    fun resume() {
        if (!on) return
        val p = player ?: ctx?.let { c ->
            MediaPlayer.create(c, R.raw.ascensor)?.also { it.isLooping = true; it.setVolume(0.32f, 0.32f); player = it }
        } ?: return
        if (!p.isPlaying) p.start()
    }
    fun pause() { player?.let { if (it.isPlaying) it.pause() } }
}
