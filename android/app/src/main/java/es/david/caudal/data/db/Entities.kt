package es.david.caudal.data.db

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import es.david.caudal.domain.model.Account
import es.david.caudal.domain.model.AccountType
import es.david.caudal.domain.model.Asset
import es.david.caudal.domain.model.AssetOp
import es.david.caudal.domain.model.CatKind
import es.david.caudal.domain.model.Category
import es.david.caudal.domain.model.Company
import es.david.caudal.domain.model.DebtKind
import es.david.caudal.domain.model.DebtMove
import es.david.caudal.domain.model.Freq
import es.david.caudal.domain.model.Goal
import es.david.caudal.domain.model.OpSide
import es.david.caudal.domain.model.PayStatus
import es.david.caudal.domain.model.Person
import es.david.caudal.domain.model.Quote
import es.david.caudal.domain.model.Recurring
import es.david.caudal.domain.model.Shift
import es.david.caudal.domain.model.Tx
import es.david.caudal.domain.model.TxType

// Importes en céntimos (Long) con su moneda; precios y cantidades de inversiones en Double.
// `extra`: campos de la copia de seguridad que esta versión no conoce (JSON), para no perderlos.

@Entity(tableName = "accounts")
data class AccountEntity(
    @PrimaryKey val id: String,
    val name: String,
    val type: String,
    val currency: String,
    val initial: Long,
    val color: String,
    val icon: String,
    val includeInTotal: Boolean,
    val archived: Boolean,
    val sortOrder: Int,
    val note: String,
    val extra: String,
)

@Entity(tableName = "categories")
data class CategoryEntity(
    @PrimaryKey val id: String,
    val kind: String,
    val name: String,
    val icon: String,
    val color: String,
    val budget: Long,
    val keywords: String,
    val hidden: Boolean,
    val position: Int,
    val extra: String,
)

@Entity(
    tableName = "txs",
    indices = [Index("date"), Index("accountId"), Index("toAccountId"), Index("categoryId")],
)
data class TxEntity(
    @PrimaryKey val id: String,
    val type: String,
    val amount: Long,
    val currency: String,
    val accountId: String,
    val toAccountId: String?,
    val categoryId: String?,
    val date: String,
    val time: String,
    val title: String,
    val note: String,
    val excluded: Boolean,
    val recurringId: String?,
    @androidx.room.ColumnInfo(defaultValue = "") val mood: String,
    val extra: String,
)

@Entity(tableName = "recurring")
data class RecurringEntity(
    @PrimaryKey val id: String,
    val name: String,
    val type: String,
    val amount: Long,
    val currency: String,
    val accountId: String,
    val toAccountId: String?,
    val categoryId: String?,
    val assetId: String?,
    val freq: String,
    val day: Int,
    val next: String,
    val active: Boolean,
    val extra: String,
)

@Entity(tableName = "assets")
data class AssetEntity(
    @PrimaryKey val id: String,
    val kind: String,
    val symbol: String,
    val ySymbol: String,
    val name: String,
    val isin: String,
    val accountId: String?,
    val manualPrice: Double,
    val color: String,
    val archived: Boolean,
    val extra: String,
)

@Entity(
    tableName = "asset_ops",
    foreignKeys = [ForeignKey(entity = AssetEntity::class, parentColumns = ["id"], childColumns = ["assetId"], onDelete = ForeignKey.CASCADE)],
    indices = [Index("assetId"), Index("cashAccountId")],
)
data class AssetOpEntity(
    @PrimaryKey val id: String,
    val assetId: String,
    val side: String,
    val qty: Double,
    val price: Double,
    val fee: Double,
    val date: String,
    val cashAccountId: String?,
    val extra: String,
)

@Entity(tableName = "goals")
data class GoalEntity(
    @PrimaryKey val id: String,
    val name: String,
    val icon: String,
    val color: String,
    val target: Long,
    val saved: Long,
    val deadline: String,
    val accountId: String?,
    val extra: String,
)

@Entity(tableName = "quotes")
data class QuoteEntity(
    @PrimaryKey val symbol: String,
    val price: Double,
    val previousClose: Double,
    val currency: String,
    val updatedMillis: Long,
)

@Entity(tableName = "people")
data class PersonEntity(
    @PrimaryKey val id: String,
    val name: String,
    val emoji: String,
    val color: String,
    val nick: String,
    val phone: String,
    val photo: String?,
    val extra: String,
)

@Entity(tableName = "debts", indices = [Index("personId")])
data class DebtEntity(
    @PrimaryKey val id: String,
    val personId: String,
    val amount: Long,
    val kind: String,
    val concept: String,
    val date: String,
    val createdMillis: Long,
    val groupId: String?,
    val total: Long?,
    val extra: String,
)

@Entity(tableName = "companies")
data class CompanyEntity(
    @PrimaryKey val id: String,
    val name: String,
    val color: String,
    val normalRate: Double,
    val nightRate: Double,
    val nightStart: Int,
    val nightEnd: Int,
    val ssPct: Double,
    val irpfPct: Double,
    val accountId: String?,
    val extra: String,
)

@Entity(tableName = "shifts", indices = [Index("companyId"), Index("date")])
data class ShiftEntity(
    @PrimaryKey val id: String,
    val companyId: String,
    val date: String,
    val start: Int,
    val end: Int,
    val breakMin: Int,
    val note: String,
    val status: String,
    val paidDate: String,
    val normalRate: Double?,
    val nightRate: Double?,
    val extra: String,
)

// MARK: conversión a modelo y de vuelta

fun AccountEntity.toModel() = Account(id, name, AccountType.of(type), currency, initial, color, icon, includeInTotal, archived, sortOrder, note, extra)
fun Account.toEntity() = AccountEntity(id, name, type.raw, currency, initial, color, icon, includeInTotal, archived, order, note, extra)

fun CategoryEntity.toModel() = Category(id, CatKind.of(kind), name, icon, color, budget, keywords, hidden, position, extra)
fun Category.toEntity() = CategoryEntity(id, kind.raw, name, icon, color, budget, keywords, hidden, position, extra)

fun TxEntity.toModel() = Tx(id, TxType.of(type) ?: TxType.EXPENSE, amount, currency, accountId, toAccountId, categoryId, date, time, title, note, excluded, recurringId, mood, extra)
fun Tx.toEntity() = TxEntity(id, type.raw, amount, currency, accountId, toAccountId, categoryId, date, time, title, note, excluded, recurringId, mood, extra)

fun RecurringEntity.toModel() = Recurring(id, name, type, amount, accountId, toAccountId, categoryId, assetId, Freq.of(freq), day, next, active, extra)
fun Recurring.toEntity(currency: String = "EUR") = RecurringEntity(id, name, type, amount, currency, accountId, toAccountId, categoryId, assetId, freq.raw, day, next, active, extra)

fun AssetOpEntity.toModel() = AssetOp(id, OpSide.of(side), qty, price, fee, date, cashAccountId, extra)
fun AssetOp.toEntity(assetId: String) = AssetOpEntity(id, assetId, side.raw, qty, price, fee, date, cashAccountId, extra)
fun AssetEntity.toModel(ops: List<AssetOp>) = Asset(id, kind, symbol, ySymbol, name, isin, accountId, manualPrice, color, archived, ops, extra)
fun Asset.toEntity() = AssetEntity(id, kind, symbol, ySymbol, name, isin, accountId, manualPrice, color, archived, extra)

fun GoalEntity.toModel() = Goal(id, name, icon, color, target, saved, deadline, accountId, extra)
fun Goal.toEntity() = GoalEntity(id, name, icon, color, target, saved, deadline, accountId, extra)

fun QuoteEntity.toModel() = Quote(symbol, price, previousClose, currency, updatedMillis)
fun Quote.toEntity() = QuoteEntity(symbol, price, previousClose, currency, updatedMillis)

fun PersonEntity.toModel() = Person(id, name, emoji, color, nick, phone, photo, extra)
fun Person.toEntity() = PersonEntity(id, name, emoji, color, nick, phone, photo, extra)

fun DebtEntity.toModel() = DebtMove(id, personId, amount, DebtKind.of(kind), concept, date, createdMillis, groupId, total, extra)
fun DebtMove.toEntity() = DebtEntity(id, personId, amount, kind.raw, concept, date, createdMillis, group, total, extra)

fun CompanyEntity.toModel() = Company(id, name, color, normalRate, nightRate, nightStart, nightEnd, ssPct, irpfPct, accountId, extra)
fun Company.toEntity() = CompanyEntity(id, name, color, normalRate, nightRate, nightStart, nightEnd, ssPct, irpfPct, accountId, extra)

fun ShiftEntity.toModel() = Shift(id, companyId, date, start, end, breakMin, note, PayStatus.of(status), paidDate, normalRate, nightRate, extra)
fun Shift.toEntity() = ShiftEntity(id, companyId, date, start, end, breakMin, note, status.raw, paidDate, normalRate, nightRate, extra)
