package es.david.caudal.data.security

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.withContext
import java.security.MessageDigest
import java.security.SecureRandom
import java.util.Base64
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.PBEKeySpec
import javax.inject.Inject
import javax.inject.Singleton

private val Context.securityStore: DataStore<Preferences> by preferencesDataStore(name = "security")

/** cálculo del PIN, aparte para poder probarlo */
object Pin {
    const val ITERATIONS = 60_000
    fun valid(pin: String) = pin.length in 4..6 && pin.all { it.isDigit() }
    fun hash(pin: String, salt: ByteArray, iterations: Int = ITERATIONS): ByteArray {
        val spec = PBEKeySpec(pin.toCharArray(), salt, iterations, 256)
        return SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).encoded.also { spec.clearPassword() }
    }
    fun matches(pin: String, salt: ByteArray, expected: ByteArray, iterations: Int = ITERATIONS) =
        MessageDigest.isEqual(hash(pin, salt, iterations), expected)
}

/**
 * PIN de la app (4–6 cifras). Solo se guarda su hash PBKDF2 con sal, en un almacén aparte de los ajustes
 * (no va en las copias de seguridad de Caudal). Tras 5 fallos seguidos espera 30 s.
 */
@Singleton
class PinStore @Inject constructor(@ApplicationContext context: Context) {
    private val store = context.securityStore
    private object K {
        val hash = stringPreferencesKey("pinHash")
        val salt = stringPreferencesKey("pinSalt")
        val length = intPreferencesKey("pinLength")
        val fails = intPreferencesKey("pinFails")
        val lockedUntil = longPreferencesKey("pinLockedUntil")
    }

    /** longitud del PIN, o 0 si no hay */
    val pinLength: Flow<Int> = store.data.map { if (it[K.hash] != null) it[K.length] ?: 4 else 0 }

    suspend fun hasPin(): Boolean = pinLength.first() > 0

    suspend fun setPin(pin: String) {
        require(Pin.valid(pin))
        val salt = ByteArray(16).also(SecureRandom()::nextBytes)
        val h = withContext(Dispatchers.Default) { Pin.hash(pin, salt) }
        val e = Base64.getEncoder()
        store.edit { it[K.hash] = e.encodeToString(h); it[K.salt] = e.encodeToString(salt); it[K.length] = pin.length; it[K.fails] = 0; it.remove(K.lockedUntil) }
    }

    suspend fun clear() = store.edit { it.remove(K.hash); it.remove(K.salt); it.remove(K.length); it.remove(K.fails); it.remove(K.lockedUntil) }

    /** milisegundos que faltan para poder volver a intentarlo (0 si ya se puede) */
    suspend fun waitMillis(now: Long = System.currentTimeMillis()): Long = ((store.data.first()[K.lockedUntil] ?: 0L) - now).coerceAtLeast(0L)

    sealed interface Result { data object Ok : Result; data class Wrong(val left: Int) : Result; data class Wait(val millis: Long) : Result }

    suspend fun verify(pin: String, now: Long = System.currentTimeMillis()): Result {
        val p = store.data.first()
        val wait = (p[K.lockedUntil] ?: 0L) - now
        if (wait > 0) return Result.Wait(wait)
        val d = Base64.getDecoder()
        val hash = p[K.hash] ?: return Result.Ok
        val ok = withContext(Dispatchers.Default) { Pin.matches(pin, d.decode(p[K.salt]), d.decode(hash)) }
        if (ok) { store.edit { it[K.fails] = 0; it.remove(K.lockedUntil) }; return Result.Ok }
        val fails = (p[K.fails] ?: 0) + 1
        return if (fails >= 5) {
            store.edit { it[K.fails] = 0; it[K.lockedUntil] = now + 30_000 }
            Result.Wait(30_000)
        } else {
            store.edit { it[K.fails] = fails }
            Result.Wrong(5 - fails)
        }
    }
}
