package es.david.caudal

import es.david.caudal.core.Day
import es.david.caudal.data.backup.BackupCodec
import es.david.caudal.data.db.Tags
import es.david.caudal.data.export.EncryptedBackup
import es.david.caudal.data.export.Exports
import es.david.caudal.data.export.WrongPasswordException
import es.david.caudal.data.security.Pin
import es.david.caudal.domain.calc.BudgetAlerts
import es.david.caudal.domain.calc.Ledger
import es.david.caudal.domain.calc.Subscriptions
import es.david.caudal.domain.model.Account
import es.david.caudal.domain.model.AppSettings
import es.david.caudal.domain.model.Category
import es.david.caudal.domain.model.FinanceData
import es.david.caudal.domain.model.Freq
import es.david.caudal.domain.model.Recurring
import es.david.caudal.domain.model.Tx
import es.david.caudal.domain.model.TxType
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.ByteArrayInputStream
import java.time.Clock
import java.time.LocalDate
import java.time.ZoneId
import java.util.zip.ZipInputStream

class Phase4Test {
    @Before fun setUp() {
        Day.clock = Clock.fixed(LocalDate.parse("2026-10-21").atTime(12, 0).atZone(ZoneId.systemDefault()).toInstant(), ZoneId.systemDefault())
    }

    private fun g(date: String, cents: Long, title: String, cat: String? = "c") = Tx(type = TxType.EXPENSE, amount = cents, accountId = "a", categoryId = cat, date = date, title = title)

    @Test fun suscripcionesMensualesYSemanales() {
        val txs = listOf(
            g("2026-07-05", 1099, "Spotify"), g("2026-08-05", 1099, "Spotify"), g("2026-09-05", 1099, "spotify "), g("2026-10-05", 1199, "Spotify"),
            g("2026-09-30", 300, "Café"), g("2026-10-07", 300, "Café"), g("2026-10-14", 310, "Café"),
            g("2026-08-01", 5000, "Mercadona"), g("2026-08-19", 4300, "Mercadona"), g("2026-10-02", 6100, "Mercadona"), // irregular
            g("2026-09-10", 2990, "Gimnasio"), g("2026-10-10", 2990, "Gimnasio"), // ya es recurrente
        )
        val rec = listOf(Recurring(name = "gimnasio", amount = 2990, accountId = "a", next = "2026-11-10"))
        val s = Subscriptions.detect(txs, rec, "2026-10-21")
        assertEquals(listOf("Café", "Spotify"), s.map { it.title })
        val spotify = s.first { it.title == "Spotify" }
        assertEquals(Freq.MONTHLY, spotify.freq)
        assertEquals(1199L, spotify.amount)
        assertEquals("2026-11-05", spotify.next)
        assertEquals(4, spotify.count)
        assertEquals(Freq.WEEKLY, s.first { it.title == "Café" }.freq)
        assertEquals(5, spotify.toRecurring().day)
    }

    @Test fun suscripcionAnualYMuerta() {
        val anual = listOf(g("2025-03-01", 4999, "Amazon Prime"), g("2026-03-02", 4999, "Amazon Prime"))
        assertEquals(Freq.YEARLY, Subscriptions.detect(anual, emptyList(), "2026-10-21").single().freq)
        // mensual que dejó de cobrarse hace meses: no
        val muerta = listOf(g("2026-03-05", 999, "HBO"), g("2026-04-05", 999, "HBO"), g("2026-05-05", 999, "HBO"))
        assertTrue(Subscriptions.detect(muerta, emptyList(), "2026-10-21").isEmpty())
    }

    @Test fun avisosDePresupuesto() {
        val cats = listOf(Category(id = "s", name = "Súper", budget = 10_000), Category(id = "r", name = "Rest", budget = 10_000), Category(id = "x", name = "Sin"))
        val txs = listOf(g("2026-10-02", 8_500, "M", "s"), g("2026-10-03", 12_000, "T", "r"), g("2026-10-04", 99_000, "Alquiler", "x"))
        val a = BudgetAlerts.check(Ledger(FinanceData(categories = cats, txs = txs), 1), "2026-10-21")
        assertEquals(setOf("2026-10-01:s:80", "2026-10-01:r:100", "2026-10-01:total:100"), a.map { it.key }.toSet())
        // cargo de mañana
        val rec = listOf(Recurring(name = "Netflix", amount = 1299, accountId = "a", next = "2026-10-22"))
        assertEquals(listOf("Netflix"), BudgetAlerts.chargesTomorrow(Ledger(FinanceData(recurring = rec)), "2026-10-21").map { it.r.name })
    }

    @Test fun etiquetasYCopia() {
        assertEquals(listOf("viaje", "Trabajo"), Tags.split("#viaje, Trabajo,,viaje "))
        assertEquals("viaje,Trabajo", Tags.join(listOf("#viaje", " Trabajo", "VIAJE")))
        val d = FinanceData(accounts = listOf(Account(id = "a", name = "A")), txs = listOf(Tx(id = "t", amount = 100, accountId = "a", date = "2026-10-01", tags = listOf("viaje", "japón"))))
        val back = BackupCodec.decode(BackupCodec.encode(d, AppSettings()))
        assertEquals(listOf("viaje", "japón"), back.data.txs.single().tags)
    }

    @Test fun csvYExcel() {
        val d = FinanceData(
            accounts = listOf(Account(id = "a", name = "Banco"), Account(id = "b", name = "Ahorro")),
            categories = listOf(Category(id = "c", name = "Súper")),
            txs = listOf(
                Tx(amount = 1729, accountId = "a", categoryId = "c", date = "2026-10-03", time = "14:28", title = "Mercadona; centro", tags = listOf("casa")),
                Tx(type = TxType.TRANSFER, amount = 10_000, accountId = "a", toAccountId = "b", date = "2026-10-04", title = "Ahorro"),
            ),
        )
        val l = Exports.Labels(listOf("Fecha", "Hora", "Tipo", "Importe", "Cuenta", "Categoría", "Concepto", "Nota", "Etiquetas"), "Gasto", "Ingreso", "Transferencia", "Ajuste")
        val rows = Exports.rows(d, l)
        assertEquals("2026-10-04", rows.first().date)
        assertEquals("Banco → Ahorro", rows.first().account)
        val csv = Exports.csv(rows, l.headers).toString(Charsets.UTF_8)
        assertTrue(csv.startsWith("﻿Fecha;Hora;Tipo"))
        assertTrue(csv.contains("2026-10-03;14:28;Gasto;-17,29;Banco;Súper;\"Mercadona; centro\";;#casa"))
        val names = mutableListOf<String>()
        var sheet = ""
        ZipInputStream(ByteArrayInputStream(Exports.xlsx(rows, l.headers))).use { z ->
            var e = z.nextEntry
            while (e != null) { names += e.name; if (e.name == "xl/worksheets/sheet1.xml") sheet = z.readBytes().decodeToString(); e = z.nextEntry }
        }
        assertTrue(names.containsAll(listOf("[Content_Types].xml", "_rels/.rels", "xl/workbook.xml", "xl/styles.xml", "xl/worksheets/sheet1.xml")))
        assertTrue(sheet.contains("<v>-17.29</v>"))
        assertTrue(sheet.contains("Mercadona; centro"))
    }

    @Test fun copiaCifrada() {
        val plain = """{"accounts":[],"format":"caudal-backup"}"""
        val enc = EncryptedBackup.encrypt(plain, "secreto-123", iterations = 1000)
        assertTrue(EncryptedBackup.isEncrypted(enc))
        assertFalse(EncryptedBackup.isEncrypted(plain))
        assertFalse(enc.contains("accounts"))
        assertEquals(plain, EncryptedBackup.decrypt(enc, "secreto-123"))
        // dos cifrados del mismo texto no se parecen (sal e IV aleatorios)
        assertTrue(enc != EncryptedBackup.encrypt(plain, "secreto-123", iterations = 1000))
        try { EncryptedBackup.decrypt(enc, "otra"); throw AssertionError() } catch (_: WrongPasswordException) { }
    }

    @Test fun pin() {
        assertTrue(Pin.valid("1234") && Pin.valid("123456"))
        assertFalse(Pin.valid("123") || Pin.valid("1234567") || Pin.valid("12a4"))
        val salt = ByteArray(16) { it.toByte() }
        val h = Pin.hash("2468", salt, 1000)
        assertTrue(Pin.matches("2468", salt, h, 1000))
        assertFalse(Pin.matches("2469", salt, h, 1000))
        assertFalse(h.contentEquals(Pin.hash("2468", ByteArray(16), 1000)))
        assertArrayEquals(h, Pin.hash("2468", salt, 1000))
    }
}
