package es.david.caudal.domain.model

import java.util.UUID

/*
 * Modelo de datos de Caudal. Es el mismo que el de iPhone (AppState) para que la copia de seguridad
 * se pueda pasar de una app a otra. Los importes van en céntimos con su moneda.
 * `extra` guarda (como JSON) los campos de la copia que esta versión no conoce, para no perderlos.
 */

fun newId(): String = UUID.randomUUID().toString().uppercase()

enum class AccountType(val raw: String, val icon: String) {
    CORRIENTE("corriente", "🏦"), AHORRO("ahorro", "🐷"), EFECTIVO("efectivo", "💶"), TARJETA("tarjeta", "💳"),
    EXCHANGE("exchange", "🪙"), BROKER("broker", "📊"), ACTIVO("activo", "🏠"), DEUDA("deuda", "📉"), OTRO("otro", "💼");

    companion object { fun of(raw: String?) = entries.firstOrNull { it.raw == raw } ?: OTRO }
}

data class Account(
    val id: String = newId(),
    val name: String,
    val type: AccountType = AccountType.CORRIENTE,
    val currency: String = "EUR",
    val initial: Long = 0,
    val color: String = "#8fb4ff",
    val icon: String = "🏦",
    val includeInTotal: Boolean = true,
    val archived: Boolean = false,
    val order: Int = 0,
    val note: String = "",
    val extra: String = "",
)

enum class CatKind(val raw: String) {
    EXPENSE("expense"), INCOME("income");
    companion object { fun of(raw: String?) = if (raw == "income") INCOME else EXPENSE }
}

data class Category(
    val id: String = newId(),
    val kind: CatKind = CatKind.EXPENSE,
    val name: String,
    val icon: String = "📦",
    val color: String = "#a9b3c2",
    val budget: Long = 0,
    val keywords: String = "",
    val hidden: Boolean = false,
    /** orden dentro de la lista (en iPhone es la posición en el array) */
    val position: Int = 0,
    val extra: String = "",
)

enum class TxType(val raw: String) {
    EXPENSE("expense"), INCOME("income"), TRANSFER("transfer"), ADJUST("adjust");
    companion object { fun of(raw: String?) = entries.firstOrNull { it.raw == raw } }
}

data class Tx(
    val id: String = newId(),
    val type: TxType = TxType.EXPENSE,
    /** siempre positivo, salvo en los ajustes (llevan signo) */
    val amount: Long,
    val currency: String = "EUR",
    val accountId: String,
    val toAccountId: String? = null,
    val categoryId: String? = null,
    /** yyyy-MM-dd */
    val date: String,
    /** HH:mm */
    val time: String = "12:00",
    val title: String = "",
    val note: String = "",
    val excluded: Boolean = false,
    val recurringId: String? = null,
    /** «¿valió la pena?»: un emoji (😍 🙂 😐 😩) o vacío */
    val mood: String = "",
    val extra: String = "",
) {
    val sortKey: String get() = "$date $time"
}

enum class Freq(val raw: String) {
    WEEKLY("weekly"), MONTHLY("monthly"), YEARLY("yearly");
    companion object { fun of(raw: String?) = entries.firstOrNull { it.raw == raw } ?: MONTHLY }
}

data class Recurring(
    val id: String = newId(),
    val name: String,
    /** expense / income / transfer / invest */
    val type: String = "expense",
    val amount: Long,
    val accountId: String,
    val toAccountId: String? = null,
    val categoryId: String? = null,
    val assetId: String? = null,
    val freq: Freq = Freq.MONTHLY,
    val day: Int = 1,
    /** próxima fecha yyyy-MM-dd */
    val next: String,
    val active: Boolean = true,
    val extra: String = "",
)

enum class OpSide(val raw: String) {
    BUY("buy"), SELL("sell"), REWARD("reward");
    companion object { fun of(raw: String?) = entries.firstOrNull { it.raw == raw } ?: BUY }
}

data class AssetOp(
    val id: String = newId(),
    val side: OpSide = OpSide.BUY,
    val qty: Double,
    val price: Double,
    val fee: Double = 0.0,
    val date: String,
    val cashAccountId: String? = null,
    val extra: String = "",
)

data class Asset(
    val id: String = newId(),
    /** stock o crypto */
    val kind: String = "stock",
    val symbol: String,
    /** símbolo para un proveedor de precios (en iPhone, el de Yahoo Finance) */
    val ySymbol: String,
    val name: String,
    val isin: String = "",
    val accountId: String? = null,
    val manualPrice: Double = 0.0,
    val color: String = "#6fd49b",
    val archived: Boolean = false,
    val ops: List<AssetOp> = emptyList(),
    val extra: String = "",
)

data class Goal(
    val id: String = newId(),
    val name: String,
    val icon: String = "🎯",
    val color: String = "#f0c46a",
    val target: Long,
    val saved: Long = 0,
    /** yyyy-MM-dd o vacío */
    val deadline: String = "",
    /** si está puesta, lo ahorrado es el valor de esa cuenta */
    val accountId: String? = null,
    val extra: String = "",
)

data class Quote(val symbol: String, val price: Double, val previousClose: Double, val currency: String, val updatedMillis: Long)

data class Person(
    val id: String = newId(),
    val name: String,
    val emoji: String = "😎",
    val color: String = "#b9a4ff",
    val nick: String = "",
    val phone: String = "",
    /** nombre del archivo de la foto dentro de la app (en la copia va en base64) */
    val photo: String? = null,
    val extra: String = "",
)

enum class DebtKind(val raw: String) {
    OWE("owe"), DEBT("debt"), SPLIT("split"), THEYPAID("theypaid"), PAY("pay"), IPAY("ipay");
    companion object { fun of(raw: String?) = entries.firstOrNull { it.raw == raw } ?: OWE }
}

/** amount > 0: esa persona te debe; amount < 0: tú le debes */
data class DebtMove(
    val id: String = newId(),
    val personId: String,
    val amount: Long,
    val kind: DebtKind,
    val concept: String = "",
    val date: String,
    val createdMillis: Long = System.currentTimeMillis(),
    val group: String? = null,
    val total: Long? = null,
    val extra: String = "",
)

data class Company(
    val id: String = newId(),
    val name: String,
    val color: String = "#7ac8ff",
    /** precios por hora en euros (con decimales: 13,59) */
    val normalRate: Double = 13.59,
    val nightRate: Double = 16.07,
    /** minutos desde las 00:00 */
    val nightStart: Int = 22 * 60,
    val nightEnd: Int = 6 * 60,
    val ssPct: Double = 6.5,
    val irpfPct: Double = 2.0,
    val accountId: String? = null,
    val extra: String = "",
)

enum class PayStatus(val raw: String) {
    PENDIENTE("pendiente"), PAGADO("pagado");
    companion object { fun of(raw: String?) = if (raw == "pagado") PAGADO else PENDIENTE }
}

data class Shift(
    val id: String = newId(),
    val companyId: String,
    val date: String,
    val start: Int,
    val end: Int,
    val breakMin: Int = 0,
    val note: String = "",
    val status: PayStatus = PayStatus.PENDIENTE,
    val paidDate: String = "",
    val normalRate: Double? = null,
    val nightRate: Double? = null,
    val extra: String = "",
)

/** tarjetas de la pantalla de inicio (orden y si se ven) */
data class HomeItem(val id: String, val on: Boolean = true) {
    companion object {
        val ALL = listOf("patrimonio", "disponible", "cuentas", "consejos", "horas", "mes", "calendario", "categorias", "proximos", "recientes", "inversiones", "deudas")
        val DEFAULTS = ALL.map { HomeItem(it, it !in setOf("inversiones", "deudas")) }
        /** tarjetas que solo existen en Android: si una copia de iPhone no las trae, se añaden encendidas */
        private val ANDROID_ONLY = setOf("disponible", "consejos", "calendario")

        /** quita lo desconocido y añade al final (apagado) lo que falte */
        fun normalized(list: List<HomeItem>?): List<HomeItem> {
            if (list.isNullOrEmpty()) return DEFAULTS
            val out = list.filter { it.id in ALL }.distinctBy { it.id }.toMutableList()
            for (d in DEFAULTS) if (out.none { it.id == d.id }) {
                if (d.id in ANDROID_ONLY) {
                    // detrás de su vecina de la lista por defecto
                    val prev = ALL.getOrNull(ALL.indexOf(d.id) - 1)
                    val at = out.indexOfFirst { it.id == prev }.let { if (it < 0) out.size else it + 1 }
                    out.add(at, HomeItem(d.id, true))
                } else out += HomeItem(d.id, false)
            }
            return out
        }
    }
}

enum class AccountsStyle(val raw: String) {
    CUADRICULA("cuadricula"), CARRUSEL("carrusel"), LISTA("lista"), PEQUENO("pequeno"), GRANDE("grande");
    companion object { fun of(raw: String?) = entries.firstOrNull { it.raw == raw } ?: CARRUSEL }
}

enum class ThemeMode(val raw: String) {
    SYSTEM("system"), LIGHT("light"), DARK("dark");
    companion object { fun of(raw: String?) = entries.firstOrNull { it.raw == raw } ?: DARK }
}

/** Ajustes (DataStore). Los cinco primeros son los de iPhone. */
data class AppSettings(
    val name: String = "",
    val accent: String = "#e4b3cb",
    val hideAmountsOnLaunch: Boolean = false,
    val lock: Boolean = false,
    val monthStart: Int = 1,
    val currency: String = "EUR",
    val moduleWork: Boolean = false,
    val moduleDebts: Boolean = false,
    val moduleInvest: Boolean = false,
    val home: List<HomeItem> = HomeItem.DEFAULTS,
    val accountsStyle: AccountsStyle = AccountsStyle.CARRUSEL,
    val theme: ThemeMode = ThemeMode.DARK,
    val dynamicColor: Boolean = false,
    /** negro puro en el tema oscuro (pantallas OLED) */
    val amoled: Boolean = false,
    /** textos debajo de los iconos de la barra de abajo */
    val tabLabels: Boolean = true,
    /** Gotita, la mascota, en los mensajes y celebraciones */
    val mascot: Boolean = true,
    /** vibración al tocar */
    val haptics: Boolean = true,
    /** icono de la app elegido (alias de la actividad) */
    val appIcon: String = "default",
    val onboarded: Boolean = false,
    val seed: Int = 0,
)

/** Todo lo guardado, de una vez (para los cálculos, que son los mismos que en iPhone). */
data class FinanceData(
    val accounts: List<Account> = emptyList(),
    val categories: List<Category> = emptyList(),
    val txs: List<Tx> = emptyList(),
    val recurring: List<Recurring> = emptyList(),
    val assets: List<Asset> = emptyList(),
    val goals: List<Goal> = emptyList(),
    val quotes: Map<String, Quote> = emptyMap(),
    val people: List<Person> = emptyList(),
    val debts: List<DebtMove> = emptyList(),
    val companies: List<Company> = emptyList(),
    val shifts: List<Shift> = emptyList(),
)

val PALETTE = listOf("#e4b3cb", "#8fb4ff", "#6fd49b", "#f0c46a", "#ff9f7a", "#b39cff", "#62cfd0", "#ff8686", "#c3d36a", "#d9a0f5", "#7ac8ff", "#f59fc4", "#a9b3c2")
