package es.david.caudal

import es.david.caudal.core.Money
import es.david.caudal.domain.calc.Debts
import es.david.caudal.domain.model.DebtKind
import es.david.caudal.domain.model.DebtMove
import es.david.caudal.domain.model.Person
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class MoneyAndDebtsTest {
    @Test fun importesComoEnIphone() {
        assertEquals(12.5, Money.parseLoose("12,50 €")!!, 1e-9)
        assertEquals(12.5, Money.parseLoose("€12.50")!!, 1e-9)
        assertEquals(1234.56, Money.parseLoose("1.234,56")!!, 1e-9)
        assertEquals(1234.56, Money.parseLoose("1,234.56")!!, 1e-9)
        assertEquals(1234.0, Money.parseLoose("1.234")!!, 1e-9)
        assertNull(Money.parseLoose("gratis"))
        assertEquals(12.5, Money.parse("12,5")!!, 1e-9)
    }

    @Test fun tecladoDeImportes() {
        assertEquals("12,5", Money.cleanInput("12.5"))
        assertEquals("0,", Money.cleanInput(","))
        assertEquals("12,34", Money.cleanInput("12,345"))
        assertEquals("5", Money.cleanInput("05"))
        assertEquals("123456789", Money.cleanInput("1234567890"))
        assertEquals("12,5", Money.editText(1250))
        assertEquals("12", Money.editText(1200))
        assertEquals("0,05", Money.editText(5))
    }

    @Test fun gastoAMedias() {
        val m = Debts.split(3750, listOf("a", "b"), includeMe = true, concept = "Cena", date = "2026-10-15")
        assertEquals(listOf(1250L, 1250L), m.map { it.amount })
        assertEquals(1, m.map { it.group }.toSet().size)
        assertEquals(-1667L, Debts.theyPaid(5000, "a", 3, "", "2026-10-15").amount) // 50 / 3 = 16,67
    }

    @Test fun saldarYOrdenar() {
        val debts = listOf(
            DebtMove(personId = "a", amount = 1250, kind = DebtKind.SPLIT, date = "2026-10-15"),
            DebtMove(personId = "b", amount = -800, kind = DebtKind.DEBT, date = "2026-10-15"),
        )
        assertEquals(-1250L, Debts.settle(debts, "a")!!.amount)
        assertEquals(DebtKind.PAY, Debts.settle(debts, "a")!!.kind)
        assertEquals(-500L, Debts.settle(debts, "a", 500)!!.amount)
        assertEquals(800L, Debts.settle(debts, "b")!!.amount)
        assertNull(Debts.settle(debts, "c"))
        val people = listOf(Person(id = "c", name = "Álvaro"), Person(id = "b", name = "Bea"), Person(id = "a", name = "Zoe"))
        assertEquals(listOf("a", "b", "c"), Debts.sorted(people, debts).map { it.id })
        assertEquals(1250L, Debts.owedToMe(people, debts))
        assertEquals(800L, Debts.iOwe(people, debts))
    }

    @Test fun telefonoDeWhatsapp() {
        assertEquals("34600111222", Debts.whatsappPhone("600 111 222"))
        assertEquals("447700900", Debts.whatsappPhone("+44 7700 900"))
        assertNull(Debts.whatsappPhone(""))
    }
}
