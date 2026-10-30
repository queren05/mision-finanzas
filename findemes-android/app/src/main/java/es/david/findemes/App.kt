package es.david.findemes

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.spring
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.key
import androidx.compose.ui.Modifier
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.ProcessLifecycleOwner
import es.david.findemes.logic.AwayPrize
import es.david.findemes.logic.DayReport
import es.david.findemes.logic.Door
import es.david.findemes.logic.Game
import es.david.findemes.logic.GameEvent
import es.david.findemes.logic.Meta
import es.david.findemes.logic.Music
import es.david.findemes.logic.Quest
import es.david.findemes.logic.QuestKind
import es.david.findemes.logic.Sound
import es.david.findemes.logic.checkMilestone
import es.david.findemes.logic.dailyReady
import es.david.findemes.logic.wake
import es.david.findemes.model.Persistence
import es.david.findemes.model.PigKind
import es.david.findemes.model.Rarity
import es.david.findemes.model.SaveState
import es.david.findemes.ui.Assets
import es.david.findemes.ui.AwayView
import es.david.findemes.ui.DailyView
import es.david.findemes.ui.DeskView
import es.david.findemes.ui.EventView
import es.david.findemes.ui.FinaleView
import es.david.findemes.ui.HomeSheet
import es.david.findemes.ui.HomeView
import es.david.findemes.ui.IntroView
import es.david.findemes.ui.LevelUpView
import es.david.findemes.ui.MilestoneView
import es.david.findemes.ui.NewKindView
import es.david.findemes.ui.NoticeStrip
import es.david.findemes.money.Ads
import es.david.findemes.money.Money
import es.david.findemes.money.Shop
import es.david.findemes.ui.Pt
import es.david.findemes.ui.ReportView
import es.david.findemes.ui.Tex

class MainActivity : ComponentActivity() {
    override fun onResume() { super.onResume(); Money.attach(this) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge(statusBarStyle = SystemBarStyle.light(0, 0), navigationBarStyle = SystemBarStyle.light(0, 0))
        Persistence.init(this)
        Assets.init(this)
        Tex.init(this)
        Sound.init(this)
        Music.init(this)
        Pt.fontScale = resources.configuration.fontScale
        Pt.density = resources.displayMetrics.density
        // capturas automáticas: adb shell am start … --es args "-demo -tree"
        val args = (intent?.getStringExtra("args") ?: "").split(" ").filter { it.isNotBlank() }
        val game = Game.shared
        Demo.apply(game, args)
        Money.attach(this)
        Shop.init(this)
        // en las capturas automáticas no sale el aviso de privacidad
        if ("-demo" !in args || "-anuncios" in args) Ads.start(this)
        ProcessLifecycleOwner.get().lifecycle.addObserver(LifecycleEventObserver { _, e ->
            if (e == Lifecycle.Event.ON_STOP) { game.save(); Sound.stop(); Music.pause() }
            if (e == Lifecycle.Event.ON_START) { Music.resume(); game.wake() }
        })
        setContent { Root(args) }
    }
}

@Composable
fun Root(args: List<String>) {
    val game = Game.shared
    /** sin partida, ticket ni avisos encima */
    val calm = !game.inRun && game.report == null && game.event == null && game.s.seenIntro
    // la barra de estado se esconde mientras se juega
    val view = androidx.compose.ui.platform.LocalView.current
    LaunchedEffect(game.inRun) {
        val win = (view.context as? android.app.Activity)?.window ?: return@LaunchedEffect
        val c = WindowCompat.getInsetsController(win, view)
        c.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        if (game.inRun) c.hide(WindowInsetsCompat.Type.statusBars()) else c.show(WindowInsetsCompat.Type.statusBars())
    }
    LaunchedEffect(calm, game.s.cash) { if (calm) game.checkMilestone() }
    val start = when {
        "-tree" in args -> HomeSheet.tree
        "-hammers" in args -> HomeSheet.hammers
        "-herencia" in args -> HomeSheet.herencia
        "-album" in args -> HomeSheet.album
        "-bar" in args -> HomeSheet.bar
        "-ajustes" in args -> HomeSheet.settings
        else -> null
    }
    val tab = args.indexOf("-tab").let { if (it >= 0 && it + 1 < args.size) args[it + 1] else null }
    Box(Modifier.fillMaxSize()) {
        AnimatedContent(game.inRun, transitionSpec = {
            if (targetState) slideInVertically(spring(dampingRatio = 0.85f, stiffness = 300f)) { it } togetherWith fadeOut()
            else fadeIn() togetherWith fadeOut()
        }, label = "run") { run ->
            if (run) DeskView("-zoo" in args, "-desfile" in args) else HomeView(start, tab)
        }
        game.report?.let { r -> key(r.id) { ReportView(r) } }
        game.event?.let { e -> key(e.id) { EventView(e) } }
        if (!game.s.seenIntro && !game.inRun) IntroView()
        game.finale?.let { FinaleView(it) }
        val a = game.away
        val m = game.milestoneShow
        when {
            calm && game.finale == null && a != null -> AwayView(a)
            calm && game.finale == null && m != null -> key(m) { MilestoneView(m) }
            calm && game.newKinds.isNotEmpty() -> key(game.newKinds.first()) { NewKindView(game.newKinds.first()) }
            calm && game.levelUp != null -> LevelUpView(game.levelUp!!)
            calm && game.dailyReady -> DailyView()
        }
        NoticeStrip()
    }
}

/** partidas de ejemplo para las capturas */
object Demo {
    fun apply(game: Game, args: List<String>) {
        if ("-demo" !in args) return
        val s = SaveState()
        s.seenIntro = true
        s.milestone = 9
        s.seenDoors = Door.entries.map { it.name }.toSet()
        s.cash = 2_340.0
        s.day = 9
        s.billIndex = 6
        s.billDue = 10
        s.paidThisCycle = 1_620.0
        s.hammer = 2
        s.hammersOwned = setOf(0, 1, 2)
        s.skills = mapOf("golpe" to 4, "muneca" to 5, "certero" to 2, "desayuno" to 9, "sofa" to 5, "mas" to 3, "brazo" to 3, "repartidor" to 4, "reflejos" to 2, "mesa" to 1)
        s.legacy = 86.0
        s.rings = mapOf("cartera" to 3, "chancla" to 2, "cuero" to 4)
        s.coins = mapOf("peseta" to 2, "duro" to 1, "yen" to 1, "reala8" to 1, "doblon" to 1)
        s.stats.bankruptcies = 2.0; s.stats.billsPaid = 30.0; s.stats.broken = 1_830.0; s.stats.days = 41.0
        s.skinsOwned = setOf("cerdo", "vaca")
        s.tutorial = 9; s.level = 12; s.xp = 410.0; s.tier = 13; s.pigXP = 260.0
        s.lastDaily = if ("-daily" in args) "" else Meta.dayKey(System.currentTimeMillis())
        s.streak = 3
        s.achievements = setOf("rotas-10", "rotas-100", "rotas-1000", "ganado-1000", "facturas-1", "facturas-12", "dias-7", "dias-30", "doradas-1", "combo-10")
        s.brokenByKind = mapOf("normal" to 1420.0, "gorda" to 260.0, "ruedas" to 90.0, "cristal" to 51.0, "acorazada" to 38.0, "bomba" to 12.0, "dorada" to 9.0)
        s.stats.bestCombo = 22.0; s.stats.missions = 14.0; s.stats.chests = 6.0
        s.quests = listOf(Quest(kind = QuestKind.romper, target = 160.0, progress = 160.0, reward = 70.0, xp = 160.0),
            Quest(kind = QuestKind.combo, target = 28.0, progress = 22.0, reward = 60.0, xp = 160.0),
            Quest(kind = QuestKind.ganar, target = 9_000.0, progress = 3_100.0, reward = 80.0, xp = 160.0))
        if ("-sobres" in args) s.pendingChests = listOf(Rarity.comun, Rarity.rara, Rarity.epica)
        if ("-inspeccion" in args) { s.billIndex = 4; s.billDue = 11 }
        args.indexOf("-skin").let { if (it >= 0 && it + 1 < args.size) s.skin = args[it + 1] }
        game.s = s
        game.away = null
        game.recompute()
        if ("-play" in args) game.startDay()
        if ("-report" in args) {
            val r = DayReport(8)
            r.earned = 1_284.0; r.broken = 37; r.swings = 52; r.crits = 6; r.golden = 1; r.best = 212.0
            r.chests = mutableListOf(Rarity.rara, Rarity.comun)
            game.s.pendingChests = r.chests.toList()
            game.report = r
        }
        if ("-collector" in args) game.event = GameEvent.Collector(32.0)
        if ("-sintiradas" in args) { s.lastSpin = es.david.findemes.logic.todayKey; s.spinsToday = 3 }
        if ("-cobrador" in args) game.event = GameEvent.Warning
        if ("-tienda" in args) Money.say("¡Gracias por tu compra!")
        if ("-nivel" in args) game.levelUp = 13
        if ("-nueva" in args) game.newKinds = listOf(PigKind.bomba)
        if ("-intro" in args) game.s.seenIntro = false
        if ("-final" in args) game.finale = 0
        if ("-fuera" in args) game.away = AwayPrize(95.0, 18_400.0, 2_350.0)
        if ("-hito" in args) game.milestoneShow = 2
        if ("-hipoteca" in args) game.s.mortgage = 3.4e17
    }
}
