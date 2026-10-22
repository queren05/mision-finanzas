package es.david.caudal

import es.david.caudal.data.backup.BackupCodec
import es.david.caudal.data.backup.BackupException
import es.david.caudal.data.backup.CuentasClarasImport
import es.david.caudal.domain.model.AccountsStyle
import es.david.caudal.domain.model.DebtKind
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class BackupCodecTest {
    private val ios = javaClass.classLoader!!.getResource("ios-backup.json")!!.readText()

    @Test fun leeLaCopiaDeIphone() {
        val b = BackupCodec.decode(ios)
        assertEquals(4, b.data.accounts.size)
        assertEquals(10050L, b.data.accounts.first { it.id == "a_main" }.initial)
        assertEquals(-321L, b.data.txs.first { it.id == "t4" }.amount)
        assertEquals("Ana", b.settings.name)
        assertEquals(25, b.settings.monthStart)
        assertTrue(b.settings.lock) // faceID
        assertEquals(AccountsStyle.LISTA, b.settings.accountsStyle)
        // módulos: se encienden los que traen datos
        assertTrue(b.settings.moduleWork && b.settings.moduleDebts && b.settings.moduleInvest)
        // inicio: quita lo desconocido y añade al final lo que falta
        // las tarjetas que solo tiene Android se añaden encendidas, detrás de su vecina
        assertEquals(listOf("mes", "calendario", "patrimonio", "disponible"), b.settings.home.take(4).map { it.id })
        assertEquals(12, b.settings.home.size)
        // fechas de Swift (segundos desde 2001)
        assertEquals((782000000L + 978307200L) * 1000, b.data.debts.first().createdMillis)
        assertEquals(DebtKind.SPLIT, b.data.debts.first().kind)
        assertEquals(3750L, b.data.debts.first().total)
        // la foto viene en base64
        assertArrayEquals(byteArrayOf(0, 1, 2, 3), b.photos.values.single())
        assertEquals(109.5, b.data.quotes["IUSQ.DE"]!!.price, 1e-9)
    }

    @Test fun guardaLoQueNoConoce() {
        val b = BackupCodec.decode(ios)
        assertTrue(b.data.txs.first { it.id == "t5" }.extra.contains("futuroCampo"))
        assertTrue(b.topExtra.contains("campoNuevoDeIphone"))
        val out = BackupCodec.encode(b.data, b.settings, photos = { byteArrayOf(0, 1, 2, 3) }, topExtra = b.topExtra, settingsExtra = b.settingsExtra, snapshots = b.snapshots)
        val root = Json.parseToJsonElement(out).jsonObject
        assertTrue("campoNuevoDeIphone" in root)
        val t5 = (root["txs"] as JsonArray).map { it.jsonObject }.first { it["id"]!!.jsonPrimitive.content == "t5" }
        assertEquals("se conserva", t5["futuroCampo"]!!.jsonPrimitive.content)
        assertEquals(1, (root["snapshots"] as JsonArray).size)
    }

    @Test fun idaYVueltaSinPerderNada() {
        val b = BackupCodec.decode(ios)
        val again = BackupCodec.decode(BackupCodec.encode(b.data, b.settings, photos = { byteArrayOf(0, 1, 2, 3) }, topExtra = b.topExtra, settingsExtra = b.settingsExtra, snapshots = b.snapshots))
        assertEquals(b.data.copy(txs = b.data.txs.sortedBy { it.sortKey }), again.data)
        assertEquals(b.settings.copy(seed = 7), again.settings.copy(seed = 7))
    }

    @Test fun escribeTodasLasClavesQuePideIphone() {
        val b = BackupCodec.decode(ios)
        val root = Json.parseToJsonElement(BackupCodec.encode(b.data, b.settings)).jsonObject
        assertEquals(BackupCodec.FORMAT, root["format"]!!.jsonPrimitive.content)
        assertEquals(BackupCodec.FORMAT_VERSION, root["formatVersion"]!!.jsonPrimitive.content.toInt())
        fun keys(arr: String) = ((root[arr] as JsonArray).first() as JsonObject).keys
        assertTrue(keys("accounts").containsAll(listOf("id", "name", "type", "currency", "initial", "color", "icon", "includeInTotal", "archived", "order", "note")))
        assertTrue(keys("categories").containsAll(listOf("id", "kind", "name", "icon", "color", "budget", "keywords", "hidden")))
        assertTrue(keys("txs").containsAll(listOf("id", "type", "amount", "accountId", "date", "time", "title", "note", "excluded")))
        assertTrue(keys("debts").containsAll(listOf("id", "personId", "amount", "kind", "concept", "date", "created")))
        assertTrue(keys("shifts").containsAll(listOf("id", "companyId", "date", "start", "end", "breakMin", "note", "status", "paidDate")))
        val s = root["settings"]!!.jsonObject
        assertTrue(s.keys.containsAll(listOf("name", "accent", "hideAmountsOnLaunch", "faceID", "monthStart")))
    }

    @Test fun leeLaCopiaWeb() {
        val web = """{"accounts":[{"id":"a1","name":"Banco","type":"corriente","initial":10}],
            "txs":[{"id":"x","type":"expense","amount":5.5,"accountId":"a1","date":"2026-01-02","note":"Café","tags":["viaje","ocio"],"excl":true}],
            "recurring":[{"id":"r","name":"Luz","freq":"yearly","day":3,"next":"2026-02-03","tpl":{"type":"expense","amount":40,"accountId":"a1"}}],
            "assets":[{"id":"s","kind":"crypto","symbol":"btc","ops":[{"side":"out","qty":1,"price":1},{"side":"buy","qty":2,"price":3}]},{"id":"w","watch":true}],
            "goals":[{"id":"g","name":"Coche","target":1000,"manual":50,"source":{"t":"account","id":"a1"}}],
            "settings":{"name":"Luis","monthStart":5}}"""
        val b = BackupCodec.decode(web)
        val t = b.data.txs.single()
        assertEquals("Café", t.title)
        assertEquals("#viaje #ocio", t.note)
        assertTrue(t.excluded)
        assertEquals(550L, t.amount)
        assertEquals("BTC-EUR", b.data.assets.single().ySymbol)
        assertEquals(1, b.data.assets.single().ops.size)
        assertEquals("a1", b.data.goals.single().accountId)
        assertEquals(5000L, b.data.goals.single().saved)
        assertEquals(28, b.data.categories.size) // sin categorías: las de partida
        assertEquals("Luis", b.settings.name)
    }

    @Test(expected = BackupException::class) fun rechazaLoQueNoEsUnaCopia() {
        BackupCodec.decode("""{"hola":1}""")
    }

    @Test fun cuentasClarasSeAnade() {
        val text = """{"people":[{"id":"p1","name":"Ya estaba"},{"id":"p2","name":"Lucía","photo":"data:image/jpeg;base64,AAE="}],
            "moves":[{"id":"m1","pid":"p2","amt":7.5,"kind":"owe","concept":"Pizza","date":"2026-10-01","t":1760000000000}]}"""
        val r = CuentasClarasImport.parse(text, setOf("p1"), emptySet())
        assertEquals(listOf("p2"), r.people.map { it.id })
        assertEquals(750L, r.debts.single().amount)
        assertEquals(1760000000000L, r.debts.single().createdMillis)
        assertFalse(r.photos.isEmpty())
    }
}
