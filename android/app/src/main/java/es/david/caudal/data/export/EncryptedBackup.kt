package es.david.caudal.data.export

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.security.SecureRandom
import java.util.Base64
import javax.crypto.AEADBadTagException
import javax.crypto.Cipher
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.PBEKeySpec
import javax.crypto.spec.SecretKeySpec

class WrongPasswordException : Exception("wrong_password")

/**
 * Copia de seguridad cifrada: el JSON normal de la copia, cifrado con AES-256-GCM.
 * La clave sale de la contraseña con PBKDF2-HMAC-SHA256 (sal aleatoria de 16 bytes). IV aleatorio de 12 bytes.
 * Ver BACKUP_FORMAT.md («Copia cifrada»).
 */
object EncryptedBackup {
    const val FORMAT = "caudal-backup-encrypted"
    const val VERSION = 1
    const val ITERATIONS = 210_000

    private val rnd = SecureRandom()
    private val b64 = Base64.getEncoder()
    private val unb64 = Base64.getDecoder()

    fun isEncrypted(text: String): Boolean = runCatching {
        Json.parseToJsonElement(text.trim()).jsonObject["format"]?.jsonPrimitive?.contentOrNull == FORMAT
    }.getOrDefault(false)

    private fun key(password: CharArray, salt: ByteArray, iterations: Int): SecretKeySpec {
        val spec = PBEKeySpec(password, salt, iterations, 256)
        val bytes = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).encoded
        spec.clearPassword()
        return SecretKeySpec(bytes, "AES")
    }

    fun encrypt(plain: String, password: String, iterations: Int = ITERATIONS): String {
        require(password.isNotEmpty())
        val salt = ByteArray(16).also(rnd::nextBytes)
        val iv = ByteArray(12).also(rnd::nextBytes)
        val c = Cipher.getInstance("AES/GCM/NoPadding")
        c.init(Cipher.ENCRYPT_MODE, key(password.toCharArray(), salt, iterations), GCMParameterSpec(128, iv))
        c.updateAAD(FORMAT.toByteArray())
        val data = c.doFinal(plain.toByteArray(Charsets.UTF_8))
        return JsonObject(
            mapOf(
                "format" to JsonPrimitive(FORMAT), "formatVersion" to JsonPrimitive(VERSION),
                "kdf" to JsonPrimitive("PBKDF2WithHmacSHA256"), "iterations" to JsonPrimitive(iterations),
                "cipher" to JsonPrimitive("AES-256-GCM"),
                "salt" to JsonPrimitive(b64.encodeToString(salt)), "iv" to JsonPrimitive(b64.encodeToString(iv)),
                "data" to JsonPrimitive(b64.encodeToString(data)),
            ),
        ).toString()
    }

    /** devuelve el JSON normal de la copia; lanza [WrongPasswordException] si la contraseña no vale */
    fun decrypt(text: String, password: String): String {
        val o = Json.parseToJsonElement(text.trim()).jsonObject
        val salt = unb64.decode(o["salt"]!!.jsonPrimitive.content)
        val iv = unb64.decode(o["iv"]!!.jsonPrimitive.content)
        val data = unb64.decode(o["data"]!!.jsonPrimitive.content)
        val iterations = o["iterations"]?.jsonPrimitive?.intOrNull ?: ITERATIONS
        val c = Cipher.getInstance("AES/GCM/NoPadding")
        c.init(Cipher.DECRYPT_MODE, key(password.toCharArray(), salt, iterations), GCMParameterSpec(128, iv))
        c.updateAAD(FORMAT.toByteArray())
        return try { String(c.doFinal(data), Charsets.UTF_8) } catch (e: AEADBadTagException) { throw WrongPasswordException() }
    }
}
