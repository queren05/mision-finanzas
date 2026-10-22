package es.david.caudal.domain.calc

import es.david.caudal.core.Day
import es.david.caudal.core.Money
import es.david.caudal.domain.model.AssetOp
import es.david.caudal.domain.model.FinanceData
import es.david.caudal.domain.model.OpSide
import es.david.caudal.domain.model.Recurring
import es.david.caudal.domain.model.Tx
import es.david.caudal.domain.model.TxType

/** lo que hay que apuntar por los recurrentes vencidos */
data class RecurringRun(
    val txs: List<Tx>,
    /** compras de inversión: id del activo → operación */
    val ops: List<Pair<String, AssetOp>>,
    val updated: List<Recurring>,
) {
    val isEmpty get() = txs.isEmpty() && ops.isEmpty() && updated.isEmpty()
}

object Recurrences {
    /**
     * Apunta los cargos pendientes hasta hoy (como mucho 60 seguidos por recurrente), a las 08:00.
     * Si es una inversión, compra importe / precio participaciones del activo.
     */
    fun run(data: FinanceData, today: String = Day.today): RecurringRun {
        val ledger = Ledger(data)
        val txs = mutableListOf<Tx>()
        val ops = mutableListOf<Pair<String, AssetOp>>()
        val updated = mutableListOf<Recurring>()
        for (r0 in data.recurring) {
            if (!r0.active) continue
            var r = r0
            var n = 0
            while (r.next <= today && n < 60) {
                n++
                val asset = ledger.asset(r.assetId)
                if (r.type == "invest") {
                    if (asset != null) {
                        val p = ledger.price(asset)
                        if (p > 0) ops += asset.id to AssetOp(side = OpSide.BUY, qty = Money.fromCents(r.amount) / p, price = p, date = r.next, cashAccountId = r.accountId)
                    }
                } else {
                    txs += Tx(
                        type = TxType.of(r.type) ?: TxType.EXPENSE, amount = r.amount, accountId = r.accountId,
                        toAccountId = r.toAccountId, categoryId = r.categoryId, date = r.next, time = "08:00",
                        title = r.name, recurringId = r.id,
                    )
                }
                r = r.copy(next = Ledger.nextDate(r, r.next))
            }
            if (r != r0) updated += r
        }
        return RecurringRun(txs, ops, updated)
    }
}
