package es.david.caudal.domain.calc

import es.david.caudal.core.Day
import es.david.caudal.core.Money
import es.david.caudal.domain.model.DebtKind
import es.david.caudal.domain.model.DebtMove
import es.david.caudal.domain.model.Person
import es.david.caudal.domain.model.newId
import java.text.Collator
import java.util.Locale
import kotlin.math.abs
import kotlin.math.min

/** Cuentas claras: igual que Debts.swift (importes en céntimos) */
object Debts {
    fun balance(debts: List<DebtMove>, pid: String): Long = debts.filter { it.personId == pid }.sumOf { it.amount }

    fun owedToMe(people: List<Person>, debts: List<DebtMove>): Long = people.map { balance(debts, it.id) }.filter { it > 0 }.sum()
    fun iOwe(people: List<Person>, debts: List<DebtMove>): Long = -people.map { balance(debts, it.id) }.filter { it < 0 }.sum()

    fun last(debts: List<DebtMove>, pid: String): DebtMove? =
        debts.filter { it.personId == pid }.maxWithOrNull(compareBy<DebtMove> { it.date }.thenBy { it.createdMillis })

    /** primero quien tiene cuentas pendientes (por importe) y luego el resto por nombre */
    fun sorted(people: List<Person>, debts: List<DebtMove>): List<Person> {
        val col = Collator.getInstance(Locale("es", "ES"))
        return people.sortedWith { a, b ->
            val x = abs(balance(debts, a.id))
            val y = abs(balance(debts, b.id))
            when {
                (x > 0) != (y > 0) -> if (x > 0) -1 else 1
                x != y -> y.compareTo(x)
                else -> col.compare(a.name, b.name)
            }
        }
    }

    /** gasto a medias: una parte por persona elegida (y otra tuya si participas) */
    fun split(amount: Long, people: List<String>, includeMe: Boolean, concept: String, date: String): List<DebtMove> {
        val n = people.size + if (includeMe) 1 else 0
        if (n == 0) return emptyList()
        val each = Money.toCents(Money.round2(Money.fromCents(amount) / n))
        val g = newId()
        return people.map { DebtMove(personId = it, amount = each, kind = DebtKind.SPLIT, concept = concept, date = date, group = g, total = amount) }
    }

    /** pagó otro por varios: te toca tu parte */
    fun theyPaid(amount: Long, personId: String, between: Int, concept: String, date: String): DebtMove =
        DebtMove(personId = personId, amount = -Money.toCents(Money.round2(Money.fromCents(amount) / between)), kind = DebtKind.THEYPAID, concept = concept, date = date, total = amount)

    /** deja la cuenta a cero o apunta un pago parcial */
    fun settle(debts: List<DebtMove>, pid: String, amount: Long? = null, date: String = Day.today): DebtMove? {
        val b = balance(debts, pid)
        if (b == 0L) return null
        val paid = min(abs(b), amount ?: abs(b))
        return DebtMove(personId = pid, amount = if (b > 0) -paid else paid, kind = if (b > 0) DebtKind.PAY else DebtKind.IPAY, date = date)
    }

    /** últimas deudas para el mensaje de recordatorio (como mucho 8) */
    fun reminderItems(debts: List<DebtMove>, pid: String): List<DebtMove> =
        debts.filter { it.personId == pid && it.amount > 0 && it.kind != DebtKind.IPAY }.sortedBy { it.date }.takeLast(8)

    /** número para WhatsApp: +34 delante si son 9 cifras sin prefijo */
    fun whatsappPhone(phone: String): String? {
        val digits = phone.filter { it.isDigit() }
        if (digits.isEmpty()) return null
        return if (phone.trim().startsWith("+")) digits else if (digits.length == 9) "34$digits" else digits
    }
}
