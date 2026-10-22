package es.david.caudal.data.db

import androidx.room.Database
import androidx.room.RoomDatabase

@Database(
    entities = [
        AccountEntity::class, CategoryEntity::class, TxEntity::class, RecurringEntity::class,
        AssetEntity::class, AssetOpEntity::class, GoalEntity::class, QuoteEntity::class,
        PersonEntity::class, DebtEntity::class, CompanyEntity::class, ShiftEntity::class,
    ],
    version = 3,
    exportSchema = true,
)
abstract class CaudalDatabase : RoomDatabase() {
    abstract fun finance(): FinanceDao

    companion object {
        /** 1 → 2: «¿valió la pena?» en los movimientos */
        val MIGRATION_1_2 = object : androidx.room.migration.Migration(1, 2) {
            override fun migrate(db: androidx.sqlite.db.SupportSQLiteDatabase) {
                db.execSQL("ALTER TABLE txs ADD COLUMN mood TEXT NOT NULL DEFAULT ''")
            }
        }

        /** 2 → 3: etiquetas en los movimientos */
        val MIGRATION_2_3 = object : androidx.room.migration.Migration(2, 3) {
            override fun migrate(db: androidx.sqlite.db.SupportSQLiteDatabase) {
                db.execSQL("ALTER TABLE txs ADD COLUMN tags TEXT NOT NULL DEFAULT ''")
            }
        }
    }
}
