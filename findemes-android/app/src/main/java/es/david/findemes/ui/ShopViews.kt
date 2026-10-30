package es.david.findemes.ui

import es.david.findemes.money.Ads
import es.david.findemes.money.Money
import es.david.findemes.money.Reward
import es.david.findemes.money.Shop
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.ColorMatrix
import androidx.compose.ui.graphics.FilterQuality
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.foundation.Image
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import es.david.findemes.logic.Game
import es.david.findemes.logic.Sound
import es.david.findemes.logic.bestHammer
import es.david.findemes.model.CoinDef
import es.david.findemes.model.Content
import es.david.findemes.model.HammerDef
import es.david.findemes.model.RingDef
import es.david.findemes.model.SkinDef
import es.david.findemes.model.perk
import es.david.findemes.model.perkName
import es.david.findemes.support.Fmt
import es.david.findemes.support.Ink
import es.david.findemes.support.hex

// MARK: - Cabecera común de las hojas

@Composable
fun SheetHeader(title: String, subtitle: String, onClose: () -> Unit) {
    Row(Modifier.fillMaxWidth().padding(horizontal = 18.dp).padding(top = 18.dp, bottom = 8.dp), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            T(title, chunky(30.0).hardShadow(2.0, 3.0), color = Ink.paper, maxLines = 1, minScale = 0.6f)
            T(subtitle, typewriter(13.0, true), color = Ink.paper.copy(alpha = 0.9f), maxLines = 2)
        }
        ChunkyButton({ Sound.click(); onClose() }, color = Ink.paper, size = 16.0, radius = 12.0) { SymIcon("xmark", 20.0, Ink.ink) }
    }
}

@Composable
fun CashPill(value: String, color: Color = Ink.paper, modifier: Modifier = Modifier) {
    Box(modifier.outlined(12.0, color, shadow = 3.0).padding(horizontal = 12.dp, vertical = 5.dp)) {
        T(value, chunky(20.0), maxLines = 1, minScale = 0.6f)
    }
}

// MARK: - El corcho: árbol de mejoras

@Composable
fun CorkBackground(modifier: Modifier = Modifier) {
    Canvas(modifier.fillMaxSize()) {
        drawRect(hex("#c48d58"))
        val a = hex("#a46f3e").copy(alpha = 0.7f); val b = hex("#dcaa75").copy(alpha = 0.7f)
        val d = 1.dp.toPx()
        for (i in 0 until 900) {
            val x = ((i * 7919) % 1000) / 1000f * size.width
            val y = ((i.toLong() * 104_729) % 1000) / 1000f * size.height
            val r = ((i * 31) % 3 + 1) * d
            drawOval(if (i % 2 == 0) a else b, Offset(x, y), androidx.compose.ui.geometry.Size(r, r))
        }
    }
}

// MARK: - La chincheta dorada: lo que más conviene comprar ahora

/** chincheta dorada para filas (martillos y sus mejoras), con un destello que late */
@Composable
fun GoldPin(modifier: Modifier = Modifier) {
    val t by rememberInfiniteTransition(label = "g").animateFloat(0f, 1f, infiniteRepeatable(tween(1100, easing = FastOutSlowInEasing), RepeatMode.Restart), label = "t")
    Box(modifier.size(20.dp), contentAlignment = Alignment.Center) {
        Canvas(Modifier.size(34.dp).scale(0.8f + 0.55f * t).alpha(0.9f * (1 - t))) {
            drawCircle(Ink.gold, size.minDimension / 2 - 1.5.dp.toPx(), style = Stroke(3.dp.toPx()))
        }
        Canvas(Modifier.size(20.dp)) {
            drawCircle(Ink.gold)
            drawCircle(Color.White.copy(alpha = 0.6f), 3.5.dp.toPx(), center.copy(center.x - 2.dp.toPx(), center.y - 2.dp.toPx()))
            drawCircle(Ink.ink, size.minDimension / 2 - 1.dp.toPx(), style = Stroke(2.dp.toPx()))
        }
    }
}

// MARK: - Ferretería: martillos y sus tres mejoras

@Composable
fun HammersView(onClose: () -> Unit) {
    val game = Game.shared
    Column(Modifier.fillMaxSize().background(hex("#3f74b0")), horizontalAlignment = Alignment.CenterHorizontally) {
        SheetHeader("Ferretería Paco", "Se pierden si te declaras en bancarrota", onClose)
        CashPill(Fmt.money(game.s.cash), modifier = Modifier.padding(bottom = 8.dp))
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 18.dp, vertical = 10.dp).navigationBarsPadding(), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            if (game.s.stats.billsPaid >= 3 || game.s.stats.bankruptcies > 0) {
                Column(Modifier.padding(bottom = 6.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    for (p in Content.parts) PartRow(p)
                }
            }
            for (h in Content.hammers) HammerRow(h)
        }
    }
}

@Composable
fun HammerRow(def: HammerDef) {
    val game = Game.shared
    val owned = def.id in game.s.hammersOwned
    val equipped = game.s.hammer == def.id
    val can = game.s.cash >= game.hammerCost(def)
    Box {
        Row(Modifier.fillMaxWidth().paper(if (equipped) hex("#fff6c8") else Ink.paper, tilt = if (def.id % 2 == 0) -0.6 else 0.6).padding(12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            Box(Modifier.width(74.dp).height(84.dp).background(Ink.paperDark.copy(alpha = 0.6f)).border(2.dp, Ink.ink).padding(6.dp), contentAlignment = Alignment.Center) {
                ItemImage(HammerArt.meta.getValue(def.style).file, Modifier.fillMaxSize().rotate(-25f))
            }
            Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                T(def.name, chunky(20.0))
                T(def.line, typewriter(12.0), color = Ink.soft)
                Row(horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                    SymIcon("star.fill", 13.0, Ink.gold, Modifier.padding(top = 1.dp))
                    T("${def.style.perkName}: ${def.style.perk}", typewriter(11.0, true))
                }
                Row(Modifier.padding(top = 2.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    HStat("DAÑO", Fmt.num(def.damage)); HStat("GOLPES/S", Fmt.dec(def.speed, 1)); HStat("ALCANCE", "${def.radius.toInt()}")
                }
                ChunkyText(if (equipped) "EN LA MANO" else if (owned) "USAR" else if (def.id == 0) "GRATIS" else Fmt.money(game.hammerCost(def)),
                    { game.buyHammer(def) }, Modifier.fillMaxWidth().padding(top = 4.dp),
                    color = if (equipped) Ink.paperDark else if (owned) Ink.paper else Ink.gold, size = 17.0, radius = 10.0,
                    enabled = !(equipped || (!owned && !can)), fill = true)
            }
        }
        if (game.bestHammer == def.id) GoldPin(Modifier.offset((-6).dp, (-8).dp))
    }
}

@Composable
private fun HStat(l: String, v: String) {
    Column {
        T(l, typewriter(9.0, true), color = Ink.soft)
        T(v, chunky(16.0))
    }
}

// MARK: - Herencia: los recuerdos del abuelo (se quedan para siempre)

@Composable
fun HeritageView(onClose: () -> Unit) {
    val game = Game.shared
    var askBankrupt by remember { mutableStateOf(false) }
    Box(Modifier.fillMaxSize()) {
        Column(Modifier.fillMaxSize().background(hex("#6b1f2e")), horizontalAlignment = Alignment.CenterHorizontally) {
            SheetHeader("Herencia", "Recuerdos del abuelo", onClose)
            CashPill("${Fmt.num(game.s.legacy)} puntos de herencia", hex("#f2d58a"), Modifier.padding(bottom = 8.dp))
            Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 18.dp, vertical = 10.dp).navigationBarsPadding(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                for (r in Content.rings) RingRow(r)
                Column(Modifier.padding(top = 10.dp).fillMaxWidth().paper().padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    T("BANCARROTA", chunky(24.0), color = Ink.red)
                    T("{Huchas} a nivel ${game.s.tier} · ${game.s.billsThisRun} facturas pagadas", typewriter(13.0))
                    ChunkyText("Declararme en bancarrota · +${Fmt.num(game.legacyGain)}", { askBankrupt = true }, Modifier.fillMaxWidth(),
                        color = Ink.red, text = Ink.paper, size = 17.0, enabled = game.legacyGain >= 1, fill = true)
                }
            }
        }
        ActionDialog(askBankrupt, "¿Declararte en bancarrota?", "Pierdes el dinero, los martillos y las mejoras. Tu dinero va a la hipoteca.",
            listOf(DialogAction("Sí, en bancarrota (+${Fmt.num(game.legacyGain)} puntos)", destructive = true) { game.bankruptcy() })) { askBankrupt = false }
    }
}

@Composable
fun RingRow(def: RingDef) {
    val game = Game.shared
    val l = game.ringLevel(def)
    val maxed = l >= def.maxLevel
    val can = !maxed && game.s.legacy >= def.cost(l)
    Row(Modifier.fillMaxWidth().paper().padding(10.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Box(Modifier.size(56.dp), contentAlignment = Alignment.Center) {
            if (Assets.item(def.image) != null) ItemImage(def.image, Modifier.fillMaxSize()) else SymIcon(def.icon, 32.0, Ink.gold)
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                T(def.name, chunky(17.0), Modifier.weight(1f, fill = false), maxLines = 1, minScale = 0.7f)
                T("$l/${def.maxLevel}", typewriter(12.0, true), color = Ink.soft, maxLines = 1)
            }
            T(if (def.maxLevel == 1) def.desc else def.perText + " por nivel", typewriter(12.0), color = Ink.soft)
        }
        ChunkyText(if (maxed) "MÁX." else Fmt.num(def.cost(l)), { game.buyRing(def) }, color = hex("#f2d58a"), size = 16.0, radius = 10.0, enabled = can)
    }
}

// MARK: - Álbum de monedas

@Composable
fun CoinsView(onClose: () -> Unit) {
    val game = Game.shared
    var picked by remember { mutableStateOf<CoinDef?>(null) }
    /** se queda el resumen de los sobres recién abiertos */
    var opened by remember { mutableStateOf(false) }
    val found = Content.coins.filter { (game.s.coins[it.id] ?: 0) > 0 }
    val bonus = found.sumOf { it.rarity.bonus }
    Box(Modifier.fillMaxSize()) {
        Column(Modifier.fillMaxSize().background(hex("#2f5d3f"))) {
            SheetHeader("El álbum", "${found.size} de ${Content.coins.size} · +${Fmt.num(bonus * 100)} % de dinero para siempre", onClose)
            Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
                // los sobres sin abrir se abren aquí
                if (game.s.pendingChests.isNotEmpty() || opened) {
                    LaunchedEffect(Unit) { opened = true }
                    Box(Modifier.padding(horizontal = 18.dp).padding(top = 10.dp)) { ChestOpener() }
                }
                Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    RewardButton("Sobre de regalo · ${Money.usesLeft(Reward.sobre)}", Reward.sobre, Modifier.fillMaxWidth(), color = Ink.gold) {
                        game.s.pendingChests = game.s.pendingChests + game.rollChest()
                        Sound.coin()
                    }
                    for (row in Content.coins.chunked(3)) {
                        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            for (c in row) {
                                val n = game.s.coins[c.id] ?: 0
                                Column(Modifier.weight(1f).defaultMinSize(minHeight = 140.dp).paper(if (n > 0) Ink.paper else Ink.paperDark, shadow = 3.0)
                                    .clickable(remember { MutableInteractionSource() }, null) { if (n > 0) { Sound.coin(); picked = c } }.padding(8.dp),
                                    horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                    CoinArt(c, n > 0, Modifier.size(74.dp))
                                    T(if (n > 0) c.name else "???", chunky(13.0), maxLines = 2, align = TextAlign.Center)
                                    T(if (n > 1) "×$n" else c.rarity.title, typewriter(10.0, true), color = if (n > 0) c.rarity.color else Ink.soft)
                                }
                            }
                            repeat(3 - row.size) { Spacer(Modifier.weight(1f)) }
                        }
                    }
                }
            }
        }
        SheetHost(picked != null, { picked = null }, Ink.paper) {
            picked?.let { c ->
                Column(Modifier.fillMaxSize().padding(top = 40.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    CoinArt(c, true, Modifier.size(130.dp))
                    T(c.name, chunky(28.0))
                    T(c.line, typewriter(15.0), color = Ink.soft)
                    T("${c.rarity.title} · +${Fmt.num(c.rarity.bonus * 100)} % de dinero", typewriter(14.0, true), color = c.rarity.color)
                }
            }
        }
    }
}

@Composable
fun CoinArt(def: CoinDef, found: Boolean, modifier: Modifier = Modifier) {
    BoxWithConstraints(modifier, contentAlignment = Alignment.Center) {
        val side = minOf(maxWidth.value, maxHeight.value).toDouble()
        val b = Assets.item("c_" + def.id)
        if (b != null) {
            Image(remember(b) { b.asImageBitmap() }, null, Modifier.fillMaxSize().alpha(if (found) 1f else 0.35f),
                colorFilter = if (found) null else ColorFilter.colorMatrix(ColorMatrix().apply { setToSaturation(0f) }), filterQuality = FilterQuality.High)
        }
        T(if (found) (if (def.id == "yen") "" else def.mark) else "?", chunky(side * (if (def.mark.length > 2) 0.26 else 0.34)), Modifier.offset(x = (-side * 0.02).dp),
            color = Ink.ink.copy(alpha = if (found) 0.6f else 0.4f), maxLines = 1)
    }
}

// MARK: - Ajustes

@Composable
fun SettingsView() {
    val game = Game.shared
    var askErase by remember { mutableStateOf(false) }
    val st = game.s.settings
    fun changed() { game.applySettings(); game.save() }
    Box(Modifier.fillMaxSize().background(Ink.paper)) {
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).navigationBarsPadding(), horizontalAlignment = Alignment.CenterHorizontally) {
            T("AJUSTES", chunky(30.0), Modifier.padding(top = 20.dp))
            Column(Modifier.padding(18.dp).fillMaxWidth().paper().padding(18.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                ToggleRow("Música", st.music) { st.music = it; changed() }
                ToggleRow("Sonido", st.sound) { st.sound = it; changed() }
                ToggleRow("Vibración", st.haptics) { st.haptics = it; changed() }
                T("Música: «Lobby Time», «Local Forecast - Elevator», «Bossa Antigua» y «Easy Lemon» de Kevin MacLeod (incompetech.com), licencia CC BY 4.0. Personajes: Quaternius (CC0).",
                    typewriter(11.0), color = Ink.soft)
            }
            ShopCard()
            // el animal que se rompe (los textos también cambian: vacas, cerdos, llamas…)
            Column(Modifier.padding(horizontal = 18.dp).padding(bottom = 18.dp).fillMaxWidth().paper(hex("#fffaf0")).padding(18.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                T("ANIMAL", typewriter(15.0, true))
                for (row in Content.skins.chunked(3)) {
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        for (k in row) Box(Modifier.weight(1f)) { SkinCard(k) }
                        repeat(3 - row.size) { Spacer(Modifier.weight(1f)) }
                    }
                }
            }
            Column(Modifier.padding(horizontal = 18.dp).fillMaxWidth().paper(hex("#fffaf0")).padding(18.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                T("ESTADÍSTICAS", typewriter(15.0, true))
                val s = game.s.stats
                SRow("{Huchas} rot{as}", Fmt.num(s.broken))
                SRow("Martillazos", Fmt.num(s.swings))
                SRow("Dinero ganado", Fmt.money(s.earned))
                SRow("Facturas pagadas", Fmt.num(s.billsPaid))
                SRow("Días", Fmt.num(s.days))
                SRow("Mejor {hucha} en un día", Fmt.money(s.bestDay))
                SRow("Reyes {Hucha}", Fmt.num(s.kings))
                SRow("Bancarrotas", Fmt.num(s.bankruptcies))
            }
            ChunkyText("Borrar la partida", { askErase = true }, Modifier.padding(vertical = 30.dp), color = Ink.red, text = Ink.paper, size = 17.0)
        }
        ActionDialog(askErase, "¿Borrar toda la partida?", "Se pierde todo, también la herencia y las monedas. No se puede deshacer.",
            listOf(DialogAction("Borrar todo", destructive = true) { game.erase() })) { askErase = false }
    }
}

@Composable
private fun SRow(l: String, v: String) {
    Row(Modifier.fillMaxWidth()) { T(l, typewriter(14.0)); Spacer(Modifier.weight(1f)); T(v, typewriter(14.0, true)) }
}

/** interruptor como el del iPhone, en verde */
@Composable
fun ToggleRow(label: String, on: Boolean, set: (Boolean) -> Unit) {
    Row(Modifier.fillMaxWidth().clickable(remember { MutableInteractionSource() }, null) { set(!on) }, verticalAlignment = Alignment.CenterVertically) {
        T(label, chunky(20.0), Modifier.weight(1f))
        val x by androidx.compose.animation.core.animateFloatAsState(if (on) 1f else 0f, label = "sw")
        Box(Modifier.width(51.dp).height(31.dp).background(androidx.compose.ui.graphics.lerp(Color(0xFFE9E9EA), Ink.green, x), RoundedCornerShape(16.dp))) {
            Box(Modifier.offset(x = (2 + 20 * x).dp, y = 2.dp).size(27.dp).background(Color.White, CircleShape).border(0.5.dp, Color(0x22000000), CircleShape))
        }
    }
}

// MARK: - La tienda (nada que haga ir más rápido)

@Composable
private fun ShopCard() {
    Column(Modifier.padding(horizontal = 18.dp).padding(bottom = 18.dp).fillMaxWidth().paper(hex("#fffaf0")).padding(18.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        T("TIENDA", typewriter(15.0, true))
        ShopRow(Shop.NO_ADS, "Sin anuncios", "Los premios, sin ver vídeos") { SymIcon("hand.raised.slash.fill", 34.0, Ink.red) }
        ShopRow(Shop.STARTER, "Paquete de inicio", "La oveja y 3 sobres épicos") { SkinIcon("oveja", 48.0) }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            ChunkyText("Restaurar compras", { Shop.restore() }, Modifier.weight(1f), color = Ink.paper, size = 13.0, radius = 10.0, fill = true)
            if (Ads.privacyButton) ChunkyText("Privacidad", { Money.activity?.let { Ads.showPrivacy(it) } }, Modifier.weight(1f), color = Ink.paper, size = 13.0, radius = 10.0, fill = true)
        }
    }
}

@Composable
private fun ShopRow(id: String, title: String, line: String, icon: @Composable () -> Unit) {
    val owned = Shop.owns(id)
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Box(Modifier.size(52.dp), contentAlignment = Alignment.Center) { icon() }
        Column(Modifier.weight(1f)) {
            T(title, chunky(19.0), maxLines = 1, minScale = 0.7f)
            T(line, typewriter(12.0), color = Ink.soft, maxLines = 2)
        }
        ChunkyText(if (owned) "TUYO" else Shop.price(id), { Money.activity?.let { Shop.buy(it, id) } }, Modifier.width(96.dp),
            color = if (owned) Ink.green else Ink.gold, text = if (owned) Ink.paper else Ink.ink, size = 15.0, radius = 10.0, enabled = !owned, fill = true)
    }
}

// MARK: - Animales (se ganan pagando facturas o se compran)

@Composable
fun SkinCard(def: SkinDef) {
    val game = Game.shared
    val owned = game.hasSkin(def)
    val using = game.s.skin == def.id
    val paid = def.product != null
    Column(Modifier.fillMaxWidth().paper().padding(8.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Box(Modifier.height(66.dp), contentAlignment = Alignment.Center) {
            val b = Assets.skin(def.id)
            // los de pago se ven enteros (los que se ganan, en sombra hasta tenerlos)
            val shown = owned || paid
            if (b != null) Image(remember(b) { b.asImageBitmap() }, null, Modifier.size(76.dp).alpha(if (shown) 1f else 0.3f),
                colorFilter = if (shown) null else ColorFilter.tint(Color.Black, androidx.compose.ui.graphics.BlendMode.SrcIn), filterQuality = FilterQuality.High)
            if (!shown) SymIcon("lock.fill", 24.0, Ink.ink)
        }
        T(if (owned || paid) def.name else "???", chunky(15.0), maxLines = 1, minScale = 0.7f)
        if (paid && !owned) {
            ChunkyText(Shop.price(def.product!!), { Money.activity?.let { Shop.buy(it, def.product) } }, Modifier.fillMaxWidth(),
                color = Ink.gold, size = 13.0, radius = 10.0, fill = true)
        } else ChunkyText(if (using) "EN USO" else if (owned) "USAR" else "${def.bills.toInt()} facturas", { game.pickSkin(def) }, Modifier.fillMaxWidth(),
            color = if (using) Ink.green else if (owned) Ink.paper else Ink.paperDark, text = if (using) Ink.paper else Ink.ink, size = 13.0, radius = 10.0,
            enabled = !(using || !owned), fill = true)
    }
}
