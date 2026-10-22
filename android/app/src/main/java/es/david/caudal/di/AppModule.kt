package es.david.caudal.di

import android.content.Context
import androidx.room.Room
import dagger.Binds
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import es.david.caudal.data.billing.Entitlements
import es.david.caudal.data.billing.FreeEntitlements
import es.david.caudal.data.db.CaudalDatabase
import es.david.caudal.data.prices.ManualPriceProvider
import es.david.caudal.data.prices.PriceProvider
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object AppModule {
    @Provides
    @Singleton
    fun database(@ApplicationContext context: Context): CaudalDatabase =
        Room.databaseBuilder(context, CaudalDatabase::class.java, "caudal.db").addMigrations(CaudalDatabase.MIGRATION_1_2).build()
}

@Module
@InstallIn(SingletonComponent::class)
abstract class BindingsModule {
    @Binds abstract fun prices(p: ManualPriceProvider): PriceProvider
    @Binds abstract fun entitlements(e: FreeEntitlements): Entitlements
}
