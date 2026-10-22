package es.david.caudal.data.backup

import es.david.caudal.core.Day
import es.david.caudal.data.backup.BackupCodec.arr
import es.david.caudal.data.backup.BackupCodec.bool
import es.david.caudal.data.backup.BackupCodec.cents
import es.david.caudal.data.backup.BackupCodec.dbl
import es.david.caudal.data.backup.BackupCodec.int
import es.david.caudal.data.backup.BackupCodec.str
import es.david.caudal.domain.model.Account
import es.david.caudal.domain.model.AccountType
import es.david.caudal.domain.model.AppSettings
import es.david.caudal.domain.model.Asset
import es.david.caudal.domain.model.AssetOp
import es.david.caudal.domain.model.CatKind
import es.david.caudal.domain.model.Category
import es.david.caudal.domain.model.DebtKind
import es.david.caudal.domain.model.DebtMove
import es.david.caudal.domain.model.FinanceData
import es.david.caudal.domain.model.Freq
import es.david.caudal.domain.model.Goal
import es.david.caudal.domain.model.OpSide
import es.david.caudal.domain.model.PALETTE
import es.david.caudal.domain.model.Person
import es.david.caudal.domain.model.Recurring
import es.david.caudal.domain.model.Tx
import es.david.caudal.domain.model.TxType
import es.david.caudal.domain.model.newId
import es.david.caudal.core.Money
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonObject
import java.util.Base64

/** Copia de seguridad de la versión web (Misión Finanzas / Caudal 2.x): igual que WebImport.swift */
object WebImport {
    fun convert(root: JsonObject, fallback: AppSettings): Backup {
        val accounts = root.arr("accounts").mapIndexed { i, a ->
            val type = AccountType.of(a.str("type") ?: "corriente")
            Account(
                id = a.str("id") ?: newId(), name = a.str("name") ?: "", type = type, currency = a.str("currency") ?: "EUR",
                initial = a.cents("initial"), color = a.str("color") ?: PALETTE[i % PALETTE.size], icon = a.str("icon") ?: type.icon,
                includeInTotal = a.bool("includeInTotal") ?: true, archived = a.bool("archived") ?: false, order = a.int("order") ?: i, note = a.str("note") ?: "",
            )
        }
        var categories = root.arr("categories").mapIndexed { i, c ->
            Category(
                id = c.str("id") ?: newId(), kind = if (c.str("kind") == "income") CatKind.INCOME else CatKind.EXPENSE, name = c.str("name") ?: "",
                icon = c.str("icon") ?: "📦", color = c.str("color") ?: "#a9b3c2", budget = c.cents("budget"), keywords = c.str("keywords") ?: "",
                hidden = c.bool("hidden") ?: false, position = i,
            )
        }
        if (categories.isEmpty()) categories = DefaultCategories.all()
        val txs = root.arr("txs").mapNotNull { t ->
            val type = TxType.of(t.str("type") ?: "expense") ?: return@mapNotNull null
            val tags = (t["tags"] as? JsonArray).orEmpty().mapNotNull { (it as? JsonPrimitive)?.contentOrNull }.joinToString(" ") { "#$it" }
            Tx(
                id = t.str("id") ?: newId(), type = type, amount = t.cents("amount"), accountId = t.str("accountId") ?: "",
                toAccountId = t.str("toAccountId"), categoryId = t.str("categoryId"), date = t.str("date") ?: Day.today, time = "12:00",
                title = t.str("note") ?: "", note = tags, excluded = t.bool("excl") ?: false, recurringId = t.str("recId"),
            )
        }
        val recurring = root.arr("recurring").map { r ->
            val tpl = r["tpl"] as? JsonObject ?: JsonObject(emptyMap())
            Recurring(
                id = r.str("id") ?: newId(), name = r.str("name") ?: "", type = tpl.str("type") ?: "expense", amount = tpl.cents("amount"),
                accountId = tpl.str("accountId") ?: "", toAccountId = tpl.str("toAccountId"), categoryId = tpl.str("categoryId"), assetId = tpl.str("assetId"),
                freq = when (r.str("freq")) { "weekly" -> Freq.WEEKLY; "yearly" -> Freq.YEARLY; else -> Freq.MONTHLY },
                day = r.int("day") ?: 1, next = r.str("next") ?: Day.today, active = r.bool("active") ?: true,
            )
        }
        val assets = root.arr("assets").filter { it.bool("watch") != true }.map { a ->
            val kind = a.str("kind") ?: "stock"
            val sym = a.str("symbol") ?: "?"
            val y = a.str("ySymbol").orEmpty().ifEmpty { if (kind == "crypto") sym.uppercase() + "-EUR" else sym }
            Asset(
                id = a.str("id") ?: newId(), kind = kind, symbol = sym, ySymbol = y, name = a.str("name") ?: sym, isin = a.str("isin") ?: "",
                accountId = a.str("accountId"), manualPrice = a.dbl("manualPrice") ?: 0.0, color = a.str("color") ?: "#6fd49b", archived = a.bool("archived") ?: false,
                ops = (a["ops"] as? JsonArray).orEmpty().mapNotNull { it as? JsonObject }.filter { it.str("side") != "out" }.map { o ->
                    AssetOp(
                        id = o.str("id") ?: newId(), side = when (o.str("side")) { "sell" -> OpSide.SELL; "reward" -> OpSide.REWARD; else -> OpSide.BUY },
                        qty = o.dbl("qty") ?: 0.0, price = o.dbl("price") ?: 0.0, fee = o.dbl("fee") ?: 0.0, date = o.str("date") ?: Day.today,
                        cashAccountId = o.str("cashAccountId"),
                    )
                },
            )
        }
        val goals = root.arr("goals").map { g ->
            val src = g["source"] as? JsonObject
            Goal(
                id = g.str("id") ?: newId(), name = g.str("name") ?: "", icon = g.str("icon") ?: "🎯", color = g.str("color") ?: "#f0c46a",
                target = g.cents("target"), saved = g.cents("manual"), deadline = g.str("deadline") ?: "",
                accountId = if (src?.str("t") == "account") src.str("id") else null,
            )
        }
        val set = root["settings"] as? JsonObject
        val settings = fallback.copy(
            name = set?.str("name")?.takeIf { it.isNotEmpty() } ?: fallback.name,
            monthStart = (set?.int("monthStart") ?: 1).coerceIn(1, 28),
            moduleInvest = assets.isNotEmpty() || fallback.moduleInvest,
            onboarded = true,
            seed = 7,
        )
        return Backup(FinanceData(accounts, categories, txs, recurring, assets, goals), settings, source = Backup.Source.WEB)
    }
}

/** Copia de la app web Cuentas Claras: {"people":[…],"moves":[…]}. Se añade a lo que ya hay (igual que en iPhone). */
object CuentasClarasImport {
    data class Result(val people: List<Person>, val debts: List<DebtMove>, val photos: Map<String, ByteArray>)

    fun parse(text: String, existingPeople: Set<String>, existingDebts: Set<String>): Result {
        val root = runCatching { Json.parseToJsonElement(text.trim()).jsonObject }.getOrNull() ?: throw BackupException("not_backup")
        val peopleArr = root["people"] as? JsonArray ?: throw BackupException("not_backup")
        val photos = mutableMapOf<String, ByteArray>()
        val people = peopleArr.mapNotNull { it as? JsonObject }.mapNotNull { p ->
            val id = p.str("id") ?: return@mapNotNull null
            if (id in existingPeople) return@mapNotNull null
            // la foto viene como «data:image/jpeg;base64,…»
            val photo = p.str("photo")?.substringAfter(",", "")?.takeIf { it.isNotEmpty() }
                ?.let { runCatching { Base64.getDecoder().decode(it) }.getOrNull() }
            val file = photo?.let { "person_$id.jpg".also { f -> photos[f] = it } }
            Person(id = id, name = p.str("name") ?: "Amigo", emoji = p.str("emoji") ?: "😎", color = p.str("color") ?: "#b9a4ff",
                nick = p.str("nick") ?: "", phone = p.str("phone") ?: "", photo = file)
        }
        val debts = root.arr("moves").mapNotNull { m ->
            val id = m.str("id") ?: return@mapNotNull null
            val pid = m.str("pid") ?: return@mapNotNull null
            if (id in existingDebts) return@mapNotNull null
            DebtMove(
                id = id, personId = pid, amount = Money.toCents(m.dbl("amt") ?: 0.0), kind = DebtKind.of(m.str("kind") ?: "owe"),
                concept = m.str("concept") ?: "", date = m.str("date") ?: Day.today,
                createdMillis = m.dbl("t")?.toLong() ?: System.currentTimeMillis(), group = m.str("group"), total = m.dbl("total")?.let { Money.toCents(it) },
            )
        }
        return Result(people, debts, photos)
    }
}
