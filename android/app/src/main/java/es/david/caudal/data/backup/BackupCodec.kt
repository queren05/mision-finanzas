package es.david.caudal.data.backup

import es.david.caudal.core.Money
import es.david.caudal.domain.model.Account
import es.david.caudal.domain.model.AccountType
import es.david.caudal.domain.model.AccountsStyle
import es.david.caudal.domain.model.AppSettings
import es.david.caudal.domain.model.Asset
import es.david.caudal.domain.model.AssetOp
import es.david.caudal.domain.model.CatKind
import es.david.caudal.domain.model.Category
import es.david.caudal.domain.model.Company
import es.david.caudal.domain.model.DebtKind
import es.david.caudal.domain.model.DebtMove
import es.david.caudal.domain.model.FinanceData
import es.david.caudal.domain.model.Freq
import es.david.caudal.domain.model.Goal
import es.david.caudal.domain.model.HomeItem
import es.david.caudal.domain.model.OpSide
import es.david.caudal.domain.model.PayStatus
import es.david.caudal.domain.model.Person
import es.david.caudal.domain.model.Quote
import es.david.caudal.domain.model.Recurring
import es.david.caudal.domain.model.Shift
import es.david.caudal.domain.model.ThemeMode
import es.david.caudal.domain.model.Tx
import es.david.caudal.domain.model.TxType
import es.david.caudal.domain.model.newId
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.util.Base64

/** lo que trae una copia de seguridad */
data class Backup(
    val data: FinanceData,
    val settings: AppSettings,
    /** fotos de personas: nombre de archivo → bytes */
    val photos: Map<String, ByteArray> = emptyMap(),
    /** campos desconocidos del nivel superior y de los ajustes, y el histórico de patrimonio (JSON) */
    val topExtra: String = "",
    val settingsExtra: String = "",
    val snapshots: String = "",
    val formatVersion: Int = 0,
    val source: Source = Source.CAUDAL,
) {
    enum class Source { CAUDAL, WEB }
}

class BackupException(message: String) : Exception(message)

/**
 * Copia de seguridad de Caudal: el mismo JSON que la app de iPhone (AppState), con número de versión.
 * Lee también la copia de la versión web (Misión Finanzas / Caudal 2.x). Ver BACKUP_FORMAT.md.
 */
object BackupCodec {
    const val FORMAT = "caudal-backup"
    const val FORMAT_VERSION = 1

    /** segundos entre 1970 y 2001: Swift guarda las fechas como segundos desde el 1 de enero de 2001 */
    private const val APPLE_EPOCH = 978_307_200L

    private val json = Json { prettyPrint = true; prettyPrintIndent = "  " }

    // MARK: leer

    fun decode(text: String, fallbackSettings: AppSettings = AppSettings()): Backup {
        val root = runCatching { Json.parseToJsonElement(text.trim()).jsonObject }.getOrNull()
            ?: throw BackupException("not_backup")
        if (root["accounts"] !is JsonArray) throw BackupException("not_backup")
        return if (isWeb(root)) WebImport.convert(root, fallbackSettings) else decodeNative(root, fallbackSettings)
    }

    /** la copia web usa «excl», «recId», «tags» y no tiene la hora del movimiento */
    private fun isWeb(root: JsonObject): Boolean {
        if (root.str("format") == FORMAT) return false
        val txs = root["txs"] as? JsonArray ?: return false
        return txs.any { val o = it as? JsonObject; o != null && ("excl" in o || "recId" in o || "tags" in o || "time" !in o) }
    }

    private fun decodeNative(root: JsonObject, fallback: AppSettings): Backup {
        val photos = mutableMapOf<String, ByteArray>()
        val accounts = root.arr("accounts").mapIndexed { i, o ->
            Account(
                id = o.str("id") ?: newId(), name = o.str("name") ?: "", type = AccountType.of(o.str("type")),
                currency = o.str("currency") ?: "EUR", initial = o.cents("initial"), color = o.str("color") ?: "#8fb4ff",
                icon = o.str("icon") ?: "🏦", includeInTotal = o.bool("includeInTotal") ?: true, archived = o.bool("archived") ?: false,
                order = o.int("order") ?: i, note = o.str("note") ?: "", extra = o.extra(ACCOUNT_KEYS),
            )
        }
        val categories = root.arr("categories").mapIndexed { i, o ->
            Category(
                id = o.str("id") ?: newId(), kind = CatKind.of(o.str("kind")), name = o.str("name") ?: "", icon = o.str("icon") ?: "📦",
                color = o.str("color") ?: "#a9b3c2", budget = o.cents("budget"), keywords = o.str("keywords") ?: "",
                hidden = o.bool("hidden") ?: false, position = i, extra = o.extra(CATEGORY_KEYS),
            )
        }
        val txs = root.arr("txs").mapNotNull { o ->
            val type = TxType.of(o.str("type")) ?: return@mapNotNull null
            Tx(
                id = o.str("id") ?: newId(), type = type, amount = o.cents("amount"), currency = o.str("currency") ?: "EUR",
                accountId = o.str("accountId") ?: "", toAccountId = o.str("toAccountId"), categoryId = o.str("categoryId"),
                date = o.str("date") ?: "", time = o.str("time") ?: "12:00", title = o.str("title") ?: "", note = o.str("note") ?: "",
                excluded = o.bool("excluded") ?: false, recurringId = o.str("recurringId"), mood = o.str("mood") ?: "", extra = o.extra(TX_KEYS),
            )
        }
        val recurring = root.arr("recurring").map { o ->
            Recurring(
                id = o.str("id") ?: newId(), name = o.str("name") ?: "", type = o.str("type") ?: "expense", amount = o.cents("amount"),
                accountId = o.str("accountId") ?: "", toAccountId = o.str("toAccountId"), categoryId = o.str("categoryId"),
                assetId = o.str("assetId"), freq = Freq.of(o.str("freq")), day = o.int("day") ?: 1, next = o.str("next") ?: "",
                active = o.bool("active") ?: true, extra = o.extra(RECURRING_KEYS),
            )
        }
        val assets = root.arr("assets").map { o ->
            Asset(
                id = o.str("id") ?: newId(), kind = o.str("kind") ?: "stock", symbol = o.str("symbol") ?: "", ySymbol = o.str("ySymbol") ?: "",
                name = o.str("name") ?: "", isin = o.str("isin") ?: "", accountId = o.str("accountId"), manualPrice = o.dbl("manualPrice") ?: 0.0,
                color = o.str("color") ?: "#6fd49b", archived = o.bool("archived") ?: false,
                ops = (o["ops"] as? JsonArray).orEmpty().mapNotNull { it as? JsonObject }.map { p ->
                    AssetOp(
                        id = p.str("id") ?: newId(), side = OpSide.of(p.str("side")), qty = p.dbl("qty") ?: 0.0, price = p.dbl("price") ?: 0.0,
                        fee = p.dbl("fee") ?: 0.0, date = p.str("date") ?: "", cashAccountId = p.str("cashAccountId"), extra = p.extra(OP_KEYS),
                    )
                },
                extra = o.extra(ASSET_KEYS),
            )
        }
        val goals = root.arr("goals").map { o ->
            Goal(
                id = o.str("id") ?: newId(), name = o.str("name") ?: "", icon = o.str("icon") ?: "🎯", color = o.str("color") ?: "#f0c46a",
                target = o.cents("target"), saved = o.cents("saved"), deadline = o.str("deadline") ?: "", accountId = o.str("accountId"),
                extra = o.extra(GOAL_KEYS),
            )
        }
        val quotes = (root["quotes"] as? JsonObject).orEmpty().mapNotNull { (k, v) ->
            val o = v as? JsonObject ?: return@mapNotNull null
            k to Quote(k, o.dbl("price") ?: 0.0, o.dbl("previousClose") ?: 0.0, o.str("currency") ?: "EUR", appleDateToMillis(o.dbl("updated")))
        }.toMap()
        val people = root.arr("people").map { o ->
            val id = o.str("id") ?: newId()
            val photo = o.str("photo")?.let { b64 -> runCatching { Base64.getDecoder().decode(b64) }.getOrNull() }
            val file = photo?.let { "person_$id.jpg".also { f -> photos[f] = it } }
            Person(
                id = id, name = o.str("name") ?: "", emoji = o.str("emoji") ?: "😎", color = o.str("color") ?: "#b9a4ff",
                nick = o.str("nick") ?: "", phone = o.str("phone") ?: "", photo = file, extra = o.extra(PERSON_KEYS),
            )
        }
        val debts = root.arr("debts").map { o ->
            DebtMove(
                id = o.str("id") ?: newId(), personId = o.str("personId") ?: "", amount = o.cents("amount"), kind = DebtKind.of(o.str("kind")),
                concept = o.str("concept") ?: "", date = o.str("date") ?: "", createdMillis = appleDateToMillis(o.dbl("created")),
                group = o.str("group"), total = o.dbl("total")?.let { Money.toCents(it) }, extra = o.extra(DEBT_KEYS),
            )
        }
        val companies = root.arr("companies").map { o ->
            Company(
                id = o.str("id") ?: newId(), name = o.str("name") ?: "", color = o.str("color") ?: "#7ac8ff",
                normalRate = o.dbl("normalRate") ?: 13.59, nightRate = o.dbl("nightRate") ?: 16.07,
                nightStart = o.int("nightStart") ?: 1320, nightEnd = o.int("nightEnd") ?: 360,
                ssPct = o.dbl("ssPct") ?: 6.5, irpfPct = o.dbl("irpfPct") ?: 2.0, accountId = o.str("accountId"), extra = o.extra(COMPANY_KEYS),
            )
        }
        val shifts = root.arr("shifts").map { o ->
            Shift(
                id = o.str("id") ?: newId(), companyId = o.str("companyId") ?: "", date = o.str("date") ?: "", start = o.int("start") ?: 0,
                end = o.int("end") ?: 0, breakMin = o.int("breakMin") ?: 0, note = o.str("note") ?: "", status = PayStatus.of(o.str("status")),
                paidDate = o.str("paidDate") ?: "", normalRate = o.dbl("normalRate"), nightRate = o.dbl("nightRate"), extra = o.extra(SHIFT_KEYS),
            )
        }

        val s = root["settings"] as? JsonObject ?: JsonObject(emptyMap())
        val modules = s["modules"] as? JsonObject
        val settings = fallback.copy(
            name = s.str("name") ?: fallback.name,
            accent = s.str("accent") ?: fallback.accent,
            hideAmountsOnLaunch = s.bool("hideAmountsOnLaunch") ?: fallback.hideAmountsOnLaunch,
            lock = s.bool("faceID") ?: fallback.lock,
            monthStart = (s.int("monthStart") ?: fallback.monthStart).coerceIn(1, 28),
            currency = s.str("currency") ?: fallback.currency,
            // en las copias de iPhone no hay módulos: se encienden los que traen datos
            moduleWork = modules?.bool("work") ?: (companies.isNotEmpty() || fallback.moduleWork),
            moduleDebts = modules?.bool("debts") ?: (people.isNotEmpty() || fallback.moduleDebts),
            moduleInvest = modules?.bool("invest") ?: (assets.isNotEmpty() || fallback.moduleInvest),
            theme = s.str("theme")?.let { ThemeMode.of(it) } ?: fallback.theme,
            dynamicColor = s.bool("dynamicColor") ?: fallback.dynamicColor,
            amoled = s.bool("amoled") ?: fallback.amoled,
            tabLabels = s.bool("tabLabels") ?: fallback.tabLabels,
            mascot = s.bool("mascot") ?: fallback.mascot,
            haptics = s.bool("haptics") ?: fallback.haptics,
            font = s.str("font") ?: fallback.font,
            cardStyle = s.str("cardStyle") ?: fallback.cardStyle,
            corners = s.str("corners") ?: fallback.corners,
            background = s.str("background") ?: fallback.background,
            density = s.str("density") ?: fallback.density,
            hideCents = s.bool("hideCents") ?: fallback.hideCents,
            weekStart = s.int("weekStart") ?: fallback.weekStart,
            mascotHat = s.str("mascotHat") ?: fallback.mascotHat,
            mascotColor = s.str("mascotColor") ?: fallback.mascotColor,
            sounds = s.bool("sounds") ?: fallback.sounds,
            tabs = (s["tabs"] as? JsonArray)?.mapNotNull { (it as? JsonPrimitive)?.contentOrNull }?.filter { it in es.david.caudal.domain.model.ALL_TABS } ?: fallback.tabs,
            reducedMotion = s.bool("reducedMotion") ?: fallback.reducedMotion,
            appIcon = s.str("appIcon") ?: fallback.appIcon,
            home = HomeItem.normalized((root["home"] as? JsonArray)?.mapNotNull { (it as? JsonObject)?.let { h -> h.str("id")?.let { id -> HomeItem(id, h.bool("on") ?: true) } } }),
            accountsStyle = AccountsStyle.of(root.str("accountsStyle")),
            seed = root.int("seed") ?: fallback.seed,
            onboarded = true,
        )
        return Backup(
            data = FinanceData(accounts, categories, txs, recurring, assets, goals, quotes, people, debts, companies, shifts),
            settings = settings,
            photos = photos,
            topExtra = root.extra(TOP_KEYS),
            settingsExtra = s.extra(SETTINGS_KEYS),
            snapshots = (root["snapshots"] as? JsonArray)?.toString() ?: "",
            formatVersion = root.int("formatVersion") ?: 0,
        )
    }

    // MARK: escribir (todas las claves que necesita la app de iPhone, que las pide todas)

    fun encode(
        data: FinanceData,
        settings: AppSettings,
        photos: (String) -> ByteArray? = { null },
        topExtra: String = "",
        settingsExtra: String = "",
        snapshots: String = "",
        appVersion: String = "",
    ): String {
        val root = LinkedHashMap<String, JsonElement>()
        root.putAll(parseExtra(topExtra))
        root["format"] = JsonPrimitive(FORMAT)
        root["formatVersion"] = JsonPrimitive(FORMAT_VERSION)
        root["app"] = JsonPrimitive("android $appVersion".trim())
        root["version"] = JsonPrimitive(3)
        root["seed"] = JsonPrimitive(maxOf(settings.seed, 7))
        root["accounts"] = JsonArray(data.accounts.sortedBy { it.order }.map { a ->
            obj(a.extra, "id" to a.id, "name" to a.name, "type" to a.type.raw, "currency" to a.currency, "initial" to Money.fromCents(a.initial),
                "color" to a.color, "icon" to a.icon, "includeInTotal" to a.includeInTotal, "archived" to a.archived, "order" to a.order, "note" to a.note)
        })
        root["categories"] = JsonArray(data.categories.sortedBy { it.position }.map { c ->
            obj(c.extra, "id" to c.id, "kind" to c.kind.raw, "name" to c.name, "icon" to c.icon, "color" to c.color,
                "budget" to Money.fromCents(c.budget), "keywords" to c.keywords, "hidden" to c.hidden)
        })
        root["txs"] = JsonArray(data.txs.sortedBy { it.sortKey }.map { t ->
            obj(t.extra, "id" to t.id, "type" to t.type.raw, "amount" to Money.fromCents(t.amount), "currency" to t.currency,
                "accountId" to t.accountId, "toAccountId" to t.toAccountId, "categoryId" to t.categoryId, "date" to t.date, "time" to t.time,
                "title" to t.title, "note" to t.note, "excluded" to t.excluded, "recurringId" to t.recurringId, "mood" to t.mood.ifEmpty { null })
        })
        root["recurring"] = JsonArray(data.recurring.map { r ->
            obj(r.extra, "id" to r.id, "name" to r.name, "type" to r.type, "amount" to Money.fromCents(r.amount), "accountId" to r.accountId,
                "toAccountId" to r.toAccountId, "categoryId" to r.categoryId, "assetId" to r.assetId, "freq" to r.freq.raw, "day" to r.day,
                "next" to r.next, "active" to r.active)
        })
        root["assets"] = JsonArray(data.assets.map { a ->
            obj(a.extra, "id" to a.id, "kind" to a.kind, "symbol" to a.symbol, "ySymbol" to a.ySymbol, "name" to a.name, "isin" to a.isin,
                "accountId" to a.accountId, "manualPrice" to a.manualPrice, "color" to a.color, "archived" to a.archived,
                "ops" to JsonArray(a.ops.map { o ->
                    obj(o.extra, "id" to o.id, "side" to o.side.raw, "qty" to o.qty, "price" to o.price, "fee" to o.fee, "date" to o.date,
                        "cashAccountId" to o.cashAccountId)
                }))
        })
        root["goals"] = JsonArray(data.goals.map { g ->
            obj(g.extra, "id" to g.id, "name" to g.name, "icon" to g.icon, "color" to g.color, "target" to Money.fromCents(g.target),
                "saved" to Money.fromCents(g.saved), "deadline" to g.deadline, "accountId" to g.accountId)
        })
        root["settings"] = obj(
            settingsExtra,
            "name" to settings.name, "accent" to settings.accent, "hideAmountsOnLaunch" to settings.hideAmountsOnLaunch,
            "faceID" to settings.lock, "monthStart" to settings.monthStart, "currency" to settings.currency,
            "theme" to settings.theme.raw, "dynamicColor" to settings.dynamicColor,
            "amoled" to settings.amoled, "tabLabels" to settings.tabLabels, "mascot" to settings.mascot, "haptics" to settings.haptics,
            "font" to settings.font, "cardStyle" to settings.cardStyle, "corners" to settings.corners, "background" to settings.background,
            "density" to settings.density, "hideCents" to settings.hideCents, "weekStart" to settings.weekStart, "mascotHat" to settings.mascotHat,
            "mascotColor" to settings.mascotColor, "sounds" to settings.sounds, "tabs" to JsonArray(settings.tabs.map { JsonPrimitive(it) }),
            "reducedMotion" to settings.reducedMotion, "appIcon" to settings.appIcon,
            "modules" to JsonObject(mapOf("work" to JsonPrimitive(settings.moduleWork), "debts" to JsonPrimitive(settings.moduleDebts), "invest" to JsonPrimitive(settings.moduleInvest))),
        )
        root["quotes"] = JsonObject(data.quotes.mapValues { (_, q) ->
            obj("", "price" to q.price, "previousClose" to q.previousClose, "currency" to q.currency, "updated" to millisToAppleDate(q.updatedMillis))
        })
        root["snapshots"] = snapshots.takeIf { it.isNotBlank() }?.let { runCatching { Json.parseToJsonElement(it) }.getOrNull() } ?: JsonArray(emptyList())
        root["people"] = JsonArray(data.people.map { p ->
            obj(p.extra, "id" to p.id, "name" to p.name, "emoji" to p.emoji, "color" to p.color, "nick" to p.nick, "phone" to p.phone,
                "photo" to p.photo?.let(photos)?.let { Base64.getEncoder().encodeToString(it) })
        })
        root["debts"] = JsonArray(data.debts.map { d ->
            obj(d.extra, "id" to d.id, "personId" to d.personId, "amount" to Money.fromCents(d.amount), "kind" to d.kind.raw, "concept" to d.concept,
                "date" to d.date, "created" to millisToAppleDate(d.createdMillis), "group" to d.group, "total" to d.total?.let { Money.fromCents(it) })
        })
        root["companies"] = JsonArray(data.companies.map { c ->
            obj(c.extra, "id" to c.id, "name" to c.name, "color" to c.color, "normalRate" to c.normalRate, "nightRate" to c.nightRate,
                "nightStart" to c.nightStart, "nightEnd" to c.nightEnd, "ssPct" to c.ssPct, "irpfPct" to c.irpfPct, "accountId" to c.accountId)
        })
        root["shifts"] = JsonArray(data.shifts.map { s ->
            obj(s.extra, "id" to s.id, "companyId" to s.companyId, "date" to s.date, "start" to s.start, "end" to s.end, "breakMin" to s.breakMin,
                "note" to s.note, "status" to s.status.raw, "paidDate" to s.paidDate, "normalRate" to s.normalRate, "nightRate" to s.nightRate)
        })
        root["home"] = JsonArray(settings.home.map { JsonObject(mapOf("id" to JsonPrimitive(it.id), "on" to JsonPrimitive(it.on))) })
        root["accountsStyle"] = JsonPrimitive(settings.accountsStyle.raw)
        return json.encodeToString(JsonObject.serializer(), JsonObject(root))
    }

    // MARK: ayudas

    fun appleDateToMillis(v: Double?): Long = if (v == null) System.currentTimeMillis() else ((v + APPLE_EPOCH) * 1000).toLong()
    fun millisToAppleDate(ms: Long): Double = ms / 1000.0 - APPLE_EPOCH

    private val TOP_KEYS = setOf("format", "formatVersion", "app", "version", "seed", "accounts", "categories", "txs", "recurring", "assets", "goals",
        "settings", "quotes", "snapshots", "people", "debts", "companies", "shifts", "home", "accountsStyle")
    private val SETTINGS_KEYS = setOf("name", "accent", "hideAmountsOnLaunch", "faceID", "monthStart", "currency", "theme", "dynamicColor", "modules", "amoled", "tabLabels", "mascot", "haptics", "font", "cardStyle", "corners", "background", "density", "hideCents", "weekStart", "mascotHat", "mascotColor", "sounds", "tabs", "reducedMotion", "appIcon")
    private val ACCOUNT_KEYS = setOf("id", "name", "type", "currency", "initial", "color", "icon", "includeInTotal", "archived", "order", "note")
    private val CATEGORY_KEYS = setOf("id", "kind", "name", "icon", "color", "budget", "keywords", "hidden")
    private val TX_KEYS = setOf("id", "type", "amount", "currency", "accountId", "toAccountId", "categoryId", "date", "time", "title", "note", "excluded", "recurringId", "mood")
    private val RECURRING_KEYS = setOf("id", "name", "type", "amount", "accountId", "toAccountId", "categoryId", "assetId", "freq", "day", "next", "active")
    private val ASSET_KEYS = setOf("id", "kind", "symbol", "ySymbol", "name", "isin", "accountId", "manualPrice", "color", "archived", "ops")
    private val OP_KEYS = setOf("id", "side", "qty", "price", "fee", "date", "cashAccountId")
    private val GOAL_KEYS = setOf("id", "name", "icon", "color", "target", "saved", "deadline", "accountId")
    private val PERSON_KEYS = setOf("id", "name", "emoji", "color", "nick", "phone", "photo")
    private val DEBT_KEYS = setOf("id", "personId", "amount", "kind", "concept", "date", "created", "group", "total")
    private val COMPANY_KEYS = setOf("id", "name", "color", "normalRate", "nightRate", "nightStart", "nightEnd", "ssPct", "irpfPct", "accountId")
    private val SHIFT_KEYS = setOf("id", "companyId", "date", "start", "end", "breakMin", "note", "status", "paidDate", "normalRate", "nightRate")

    internal fun JsonObject.str(k: String): String? = (this[k] as? JsonPrimitive)?.takeIf { it !is JsonNull }?.contentOrNull
    internal fun JsonObject.dbl(k: String): Double? = (this[k] as? JsonPrimitive)?.takeIf { it !is JsonNull }?.doubleOrNull
    internal fun JsonObject.int(k: String): Int? = (this[k] as? JsonPrimitive)?.let { it.intOrNull ?: it.doubleOrNull?.toInt() }
    internal fun JsonObject.bool(k: String): Boolean? = (this[k] as? JsonPrimitive)?.booleanOrNull
    internal fun JsonObject.cents(k: String): Long = dbl(k)?.let { Money.toCents(it) } ?: 0L
    internal fun JsonObject.arr(k: String): List<JsonObject> = (this[k] as? JsonArray).orEmpty().mapNotNull { it as? JsonObject }

    /** los campos que no conocemos, como JSON (vacío si no hay) */
    internal fun JsonObject.extra(known: Set<String>): String {
        val rest = filterKeys { it !in known }
        return if (rest.isEmpty()) "" else JsonObject(rest).toString()
    }

    private fun parseExtra(s: String): Map<String, JsonElement> =
        if (s.isBlank()) emptyMap() else runCatching { Json.parseToJsonElement(s).jsonObject.toMap() }.getOrDefault(emptyMap())

    private fun toJson(v: Any?): JsonElement = when (v) {
        null -> JsonNull
        is JsonElement -> v
        is String -> JsonPrimitive(v)
        is Boolean -> JsonPrimitive(v)
        is Int -> JsonPrimitive(v)
        is Long -> JsonPrimitive(v)
        is Double -> JsonPrimitive(v)
        else -> JsonPrimitive(v.toString())
    }

    /** objeto con los campos desconocidos primero y luego los nuestros; los null no se escriben (opcionales en iPhone) */
    private fun obj(extra: String, vararg fields: Pair<String, Any?>): JsonObject {
        val m = LinkedHashMap<String, JsonElement>(parseExtra(extra))
        for ((k, v) in fields) if (v == null) m.remove(k) else m[k] = toJson(v)
        return JsonObject(m)
    }
}
