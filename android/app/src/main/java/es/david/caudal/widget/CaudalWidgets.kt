package es.david.caudal.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.LocalSize
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.LinearProgressIndicator
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.updateAll
import androidx.glance.background
import androidx.glance.color.ColorProvider
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import dagger.hilt.EntryPoint
import dagger.hilt.InstallIn
import dagger.hilt.android.EntryPointAccessors
import dagger.hilt.components.SingletonComponent
import es.david.caudal.MainActivity
import es.david.caudal.R
import es.david.caudal.core.Day
import es.david.caudal.data.repo.FinanceRepository
import es.david.caudal.data.repo.SettingsRepository
import es.david.caudal.domain.calc.Ledger
import es.david.caudal.domain.model.AppSettings
import es.david.caudal.ui.theme.hexColor
import java.text.NumberFormat
import java.util.Currency
import java.util.Locale

/*
 * Widgets de la pantalla de inicio (Glance). Leen los datos de la propia app (Room): no hace falta
 * servidor ni red, a diferencia de iPhone.
 */

@EntryPoint
@InstallIn(SingletonComponent::class)
interface WidgetEntryPoint {
    fun finance(): FinanceRepository
    fun settings(): SettingsRepository
}

private data class WidgetModel(val ledger: Ledger, val settings: AppSettings, val fmt: (Double) -> String)

private suspend fun load(context: Context): WidgetModel {
    val ep = EntryPointAccessors.fromApplication(context.applicationContext, WidgetEntryPoint::class.java)
    val s = ep.settings().current()
    val l = Ledger(ep.finance().snapshot(), s.monthStart)
    val locale = Locale.forLanguageTag(context.getString(R.string.locale_tag))
    val nf = NumberFormat.getCurrencyInstance(locale).apply {
        runCatching { currency = Currency.getInstance(s.currency) }
        maximumFractionDigits = 2
        minimumFractionDigits = 2
    }
    return WidgetModel(l, s, { v -> nf.format(v + 0.0) })
}

private val BG = ColorProvider(day = Color(0xFFF7F7FA), night = Color(0xFF151519))
private val FG = ColorProvider(day = Color(0xFF111114), night = Color(0xFFFFFFFF))
private val DIM = ColorProvider(day = Color(0xFF6C6C72), night = Color(0xFFA1A1A8))

@Composable
private fun Frame(content: @Composable () -> Unit) {
    Column(
        GlanceModifier.fillMaxSize().background(BG).cornerRadius(22.dp).padding(14.dp).clickable(actionStartActivity<MainActivity>()),
    ) { content() }
}

// MARK: patrimonio y cuentas

class BalanceWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Responsive(setOf(DpSize(140.dp, 140.dp), DpSize(260.dp, 140.dp), DpSize(260.dp, 280.dp)))

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val m = load(context)
        val title = context.getString(R.string.net_worth)
        provideContent {
            GlanceTheme {
                Frame {
                    val l = m.ledger
                    Text(title, style = TextStyle(color = DIM, fontSize = 12.sp, fontWeight = FontWeight.Medium))
                    Text(m.fmt(l.netWorth), style = TextStyle(color = FG, fontSize = 22.sp, fontWeight = FontWeight.Bold), maxLines = 1)
                    val size = LocalSize.current
                    if (size.width >= 250.dp) {
                        Spacer(GlanceModifier.height(8.dp))
                        val rows = if (size.height >= 260.dp) 7 else 3
                        l.accounts.take(rows).forEach { a ->
                            Row(GlanceModifier.fillMaxWidth().padding(vertical = 3.dp), verticalAlignment = Alignment.CenterVertically) {
                                Text(a.icon, style = TextStyle(fontSize = 14.sp))
                                Spacer(GlanceModifier.width(6.dp))
                                Text(a.name, style = TextStyle(color = FG, fontSize = 13.sp), maxLines = 1, modifier = GlanceModifier.defaultWeight())
                                Text(m.fmt(l.value(a)), style = TextStyle(color = FG, fontSize = 13.sp, fontWeight = FontWeight.Medium), maxLines = 1)
                            }
                        }
                    }
                }
            }
        }
    }
}

class BalanceWidgetReceiver : GlanceAppWidgetReceiver() { override val glanceAppWidget: GlanceAppWidget = BalanceWidget() }

// MARK: gastos del mes

class SpentWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Responsive(setOf(DpSize(140.dp, 140.dp), DpSize(260.dp, 140.dp)))

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val m = load(context)
        val l = m.ledger
        val start = l.periodStart(Day.today)
        val r = l.periodRange(start)
        val spent = l.spent(r)
        val budget = l.totalBudget
        val month = Day.date(start).month.getDisplayName(java.time.format.TextStyle.FULL_STANDALONE, Locale.forLanguageTag(context.getString(R.string.locale_tag)))
            .replaceFirstChar { it.titlecase() }
        val left = if (budget > 0) context.getString(R.string.widget_budget_left, m.fmt(budget - spent)) else null
        val cats = l.byCategory(r).take(3)
        provideContent {
            GlanceTheme {
                Frame {
                    Text(month, style = TextStyle(color = DIM, fontSize = 12.sp, fontWeight = FontWeight.Medium))
                    Text(m.fmt(spent), style = TextStyle(color = FG, fontSize = 22.sp, fontWeight = FontWeight.Bold), maxLines = 1)
                    if (budget > 0) {
                        Spacer(GlanceModifier.height(6.dp))
                        LinearProgressIndicator(
                            progress = (spent / budget).toFloat().coerceIn(0f, 1f),
                            modifier = GlanceModifier.fillMaxWidth().height(6.dp),
                            color = androidx.glance.unit.ColorProvider(hexColor(if (spent > budget) "#ff6b6b" else m.settings.accent)),
                            backgroundColor = ColorProvider(day = Color(0x1A000000), night = Color(0x22FFFFFF)),
                        )
                        Spacer(GlanceModifier.height(4.dp))
                        Text(left ?: "", style = TextStyle(color = DIM, fontSize = 12.sp))
                    }
                    if (LocalSize.current.width >= 250.dp) {
                        Spacer(GlanceModifier.height(6.dp))
                        cats.forEach { c ->
                            Row(GlanceModifier.fillMaxWidth().padding(vertical = 2.dp), verticalAlignment = Alignment.CenterVertically) {
                                Text(c.cat.icon, style = TextStyle(fontSize = 13.sp))
                                Spacer(GlanceModifier.width(6.dp))
                                Text(c.cat.name, style = TextStyle(color = FG, fontSize = 13.sp), maxLines = 1, modifier = GlanceModifier.defaultWeight())
                                Text(m.fmt(c.total), style = TextStyle(color = FG, fontSize = 13.sp), maxLines = 1)
                            }
                        }
                    }
                }
            }
        }
    }
}

class SpentWidgetReceiver : GlanceAppWidgetReceiver() { override val glanceAppWidget: GlanceAppWidget = SpentWidget() }

// MARK: inversiones

class InvestWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Responsive(setOf(DpSize(140.dp, 140.dp), DpSize(260.dp, 140.dp)))

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val m = load(context)
        val l = m.ledger
        val title = context.getString(R.string.portfolio)
        val gain = l.investValue - l.investCost
        val assets = l.data.assets.filter { !it.archived }.sortedByDescending { l.assetValue(it) }.take(3)
        provideContent {
            GlanceTheme {
                Frame {
                    Text(title, style = TextStyle(color = DIM, fontSize = 12.sp, fontWeight = FontWeight.Medium))
                    Text(m.fmt(l.investValue), style = TextStyle(color = FG, fontSize = 22.sp, fontWeight = FontWeight.Bold), maxLines = 1)
                    Text(
                        (if (gain >= 0) "+" else "") + m.fmt(gain),
                        style = TextStyle(color = androidx.glance.unit.ColorProvider(if (gain >= 0) Color(0xFF4AD68F) else Color(0xFFFF6B6B)), fontSize = 13.sp, fontWeight = FontWeight.Medium),
                    )
                    if (LocalSize.current.width >= 250.dp) {
                        Spacer(GlanceModifier.height(6.dp))
                        assets.forEach { a ->
                            Row(GlanceModifier.fillMaxWidth().padding(vertical = 2.dp)) {
                                Text(a.name, style = TextStyle(color = FG, fontSize = 13.sp), maxLines = 1, modifier = GlanceModifier.defaultWeight())
                                Text(m.fmt(l.assetValue(a)), style = TextStyle(color = FG, fontSize = 13.sp), maxLines = 1)
                            }
                        }
                    }
                }
            }
        }
    }
}

class InvestWidgetReceiver : GlanceAppWidgetReceiver() { override val glanceAppWidget: GlanceAppWidget = InvestWidget() }

// MARK: disponible hoy

class AllowanceWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Single

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val m = load(context)
        val a = es.david.caudal.domain.calc.Insights.allowance(m.ledger)
        val title = "☀️ " + context.getString(R.string.home_disponible)
        val per = context.getString(R.string.per_day)
        val left = if (a.left > 0) context.getString(R.string.allowance_left, m.fmt(a.left), a.daysLeft) else context.getString(R.string.allowance_over, m.fmt(-a.left))
        provideContent {
            GlanceTheme {
                Frame {
                    Text(title, style = TextStyle(color = DIM, fontSize = 12.sp, fontWeight = FontWeight.Medium), maxLines = 1)
                    Text(m.fmt(a.perDay), style = TextStyle(color = if (a.left > 0) FG else androidx.glance.unit.ColorProvider(Color(0xFFFF6B6B)), fontSize = 24.sp, fontWeight = FontWeight.Bold), maxLines = 1)
                    Text(per, style = TextStyle(color = DIM, fontSize = 12.sp))
                    Spacer(GlanceModifier.height(6.dp))
                    Text(left, style = TextStyle(color = FG, fontSize = 12.sp), maxLines = 2)
                }
            }
        }
    }
}

class AllowanceWidgetReceiver : GlanceAppWidgetReceiver() { override val glanceAppWidget: GlanceAppWidget = AllowanceWidget() }

// MARK: apuntar un gasto a un toque

class QuickAddWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Single

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val s = EntryPointAccessors.fromApplication(context.applicationContext, WidgetEntryPoint::class.java).settings().current()
        val label = context.getString(R.string.shortcut_new_expense)
        val intent = android.content.Intent(context, MainActivity::class.java).setAction(es.david.caudal.ui.ACTION_NEW_EXPENSE)
            .addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK or android.content.Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val acc = hexColor(s.accent)
        provideContent {
            GlanceTheme {
                Column(
                    GlanceModifier.fillMaxSize().background(androidx.glance.unit.ColorProvider(acc)).cornerRadius(26.dp).padding(14.dp).clickable(androidx.glance.appwidget.action.actionStartActivity(intent)),
                    verticalAlignment = Alignment.CenterVertically, horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text("💧", style = TextStyle(fontSize = 30.sp))
                    Text("+ $label", style = TextStyle(color = androidx.glance.unit.ColorProvider(Color(0xFF1A1320)), fontSize = 15.sp, fontWeight = FontWeight.Bold), maxLines = 1)
                }
            }
        }
    }
}

class QuickAddWidgetReceiver : GlanceAppWidgetReceiver() { override val glanceAppWidget: GlanceAppWidget = QuickAddWidget() }

/** refresca todos los widgets (después de cada cambio) */
suspend fun updateAllWidgets(context: Context) {
    runCatching {
        BalanceWidget().updateAll(context)
        SpentWidget().updateAll(context)
        InvestWidget().updateAll(context)
        AllowanceWidget().updateAll(context)
        QuickAddWidget().updateAll(context)
    }
}
