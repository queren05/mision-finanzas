import SwiftUI

// MARK: - Cabecera común de las hojas

struct SheetHeader: View {
    var title: String
    var subtitle: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.chunky(30)).foregroundStyle(Ink.paper).shadow(color: Ink.ink, radius: 0, x: 2, y: 3)
                Text(subtitle).font(.typewriter(13, bold: true)).foregroundStyle(Ink.paper.opacity(0.9))
            }
            Spacer()
            Button { Sound.shared.click(); dismiss() } label: { Image(systemName: "xmark").font(.system(size: 16, weight: .black)) }
                .buttonStyle(ChunkyButton(color: Ink.paper, size: 16, radius: 12))
        }
        .padding(.horizontal, 18).padding(.top, 18).padding(.bottom, 8)
    }
}

struct CashPill: View {
    var value: String
    var color: Color = Ink.paper
    var body: some View {
        Text(value).font(.chunky(20)).foregroundStyle(Ink.ink)
            .padding(.horizontal, 12).padding(.vertical, 5)
            .outlined(12, color: color, shadow: 3)
    }
}

// MARK: - El corcho: árbol de mejoras

struct CorkBackground: View {
    var family = false
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: family ? "#8a6a4a" : "#c48d58")))
            for i in 0..<900 {
                let x = Double((i * 7919) % 1000) / 1000 * size.width
                let y = Double((i * 104_729) % 1000) / 1000 * size.height
                let r = Double((i * 31) % 3) + 1
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)), with: .color(Color(hex: i % 2 == 0 ? "#a46f3e" : "#dcaa75").opacity(0.7)))
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Ferretería: martillos

struct HammersView: View {
    @Environment(Game.self) private var game
    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: "#3f74b0").ignoresSafeArea()
            VStack(spacing: 0) {
                SheetHeader(title: "Ferretería Paco", subtitle: "Se pierden si te declaras en bancarrota")
                CashPill(value: Fmt.money(game.s.cash)).padding(.bottom, 8)
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(Content.hammers) { h in HammerRow(def: h) }
                    }
                    .padding(.horizontal, 18).padding(.vertical, 10)
                }
                .scrollIndicators(.hidden)
            }
        }
    }
}

struct HammerRow: View {
    @Environment(Game.self) private var game
    let def: HammerDef
    var body: some View {
        let owned = game.s.hammersOwned.contains(def.id)
        let equipped = game.s.hammer == def.id
        let can = game.s.cash >= game.hammerCost(def)
        HStack(spacing: 14) {
            ItemImage(name: HammerArt.meta[def.style]!.file)
                .rotationEffect(.degrees(-25))
                .padding(6)
                .frame(width: 74, height: 84)
            .background(Ink.paperDark.opacity(0.6))
            .overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 2))
            VStack(alignment: .leading, spacing: 3) {
                Text(def.name).font(.chunky(20)).foregroundStyle(Ink.ink)
                Text(def.line).font(.typewriter(12)).foregroundStyle(Ink.soft)
                HStack(alignment: .top, spacing: 5) {
                    Image(systemName: "star.fill").font(.system(size: 11, weight: .black)).foregroundStyle(Ink.gold)
                    Text("\(def.style.perkName): \(def.style.perk)").font(.typewriter(11, bold: true)).foregroundStyle(Ink.ink)
                }
                HStack(spacing: 10) {
                    stat("DAÑO", Fmt.num(def.damage))
                    stat("GOLPES/S", Fmt.dec(def.speed, 1))
                    stat("ALCANCE", "\(Int(def.radius))")
                }
                .padding(.top, 2)
                Button { game.buyHammer(def) } label: {
                    Text(equipped ? "EN LA MANO" : (owned ? "USAR" : (def.id == 0 ? "GRATIS" : Fmt.money(game.hammerCost(def))))).frame(maxWidth: .infinity)
                }
                .buttonStyle(ChunkyButton(color: equipped ? Ink.paperDark : (owned ? Ink.paper : Ink.gold), size: 17, radius: 10))
                .disabled(equipped || (!owned && !can))
                .padding(.top, 4)
            }
        }
        .padding(12)
        .paper(equipped ? Color(hex: "#fff6c8") : Ink.paper, tilt: def.id % 2 == 0 ? -0.6 : 0.6)
        .overlay(alignment: .topLeading) { if game.bestHammer == def.id { GoldPin().offset(x: -6, y: -8) } }
    }
    private func stat(_ l: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(l).font(.typewriter(9, bold: true)).foregroundStyle(Ink.soft)
            Text(v).font(.chunky(16)).foregroundStyle(Ink.ink)
        }
    }
}

// MARK: - Joyero: lo que se queda para siempre

struct JewelryView: View {
    @Environment(Game.self) private var game
    @State private var askBankrupt = false
    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: "#6b1f2e").ignoresSafeArea()
            VStack(spacing: 0) {
                SheetHeader(title: "El joyero", subtitle: "Se quedan aunque te arruines")
                CashPill(value: "\(Fmt.num(game.s.legacy)) puntos de herencia", color: Color(hex: "#f2d58a")).padding(.bottom, 8)
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Content.rings) { r in RingRow(def: r) }
                        bankruptCard.padding(.top, 10)
                    }
                    .padding(.horizontal, 18).padding(.vertical, 10)
                }
                .scrollIndicators(.hidden)
            }
        }
        .confirmationDialog("¿Declararte en bancarrota?", isPresented: $askBankrupt, titleVisibility: .visible) {
            Button("Sí, en bancarrota (+\(Fmt.num(game.legacyGain)) puntos)", role: .destructive) { game.bankruptcy() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Pierdes el dinero, los martillos, el taller y las mejoras. Tu dinero va a la hipoteca.")
        }
    }

    private var bankruptCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BANCARROTA").font(.chunky(24)).foregroundStyle(Ink.red)
            Text("{Huchas} a nivel \(game.s.tier) · \(game.s.billsThisRun) facturas pagadas".a)
                .font(.typewriter(13)).foregroundStyle(Ink.ink)
            Button { askBankrupt = true } label: { Text("Declararme en bancarrota · +\(Fmt.num(game.legacyGain))").frame(maxWidth: .infinity) }
                .buttonStyle(ChunkyButton(color: Ink.red, text: Ink.paper, size: 17))
                .disabled(game.legacyGain < 1)
        }
        .padding(14)
        .paper()
    }
}

struct RingRow: View {
    @Environment(Game.self) private var game
    let def: RingDef
    var body: some View {
        let l = game.ringLevel(def)
        let maxed = l >= def.maxLevel
        let can = !maxed && game.s.legacy >= def.cost(l)
        HStack(spacing: 12) {
            ItemImage(name: "j_" + def.id).frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(def.name).font(.chunky(17)).foregroundStyle(Ink.ink)
                    Text("\(l)/\(def.maxLevel)").font(.typewriter(12, bold: true)).foregroundStyle(Ink.soft)
                }
                Text(def.desc.filling(Fmt.num(def.per)) + " por nivel").font(.typewriter(12)).foregroundStyle(Ink.soft)
            }
            Spacer(minLength: 4)
            Button { game.buyRing(def) } label: { Text(maxed ? "MÁX." : Fmt.num(def.cost(l))) }
                .buttonStyle(ChunkyButton(color: Color(hex: "#f2d58a"), size: 16, radius: 10))
                .disabled(!can)
        }
        .padding(10)
        .paper()
    }
}

struct JewelIcon: View {
    var color: Color
    var bracelet: Bool
    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2 + (bracelet ? 0 : 4))
            let ink = GraphicsContext.Shading.color(Ink.ink)
            if bracelet {
                let r = CGRect(x: c.x - 22, y: c.y - 14, width: 44, height: 28)
                ctx.stroke(Path(ellipseIn: r), with: ink, lineWidth: 9)
                ctx.stroke(Path(ellipseIn: r), with: .color(color), lineWidth: 5)
                for a in stride(from: 0.0, to: 2 * .pi, by: .pi / 3) {
                    let p = CGPoint(x: c.x + cos(a) * 22, y: c.y + sin(a) * 14)
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)), with: .color(Ink.paper))
                    ctx.stroke(Path(ellipseIn: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)), with: ink, lineWidth: 1.5)
                }
            } else {
                let r = CGRect(x: c.x - 16, y: c.y - 12, width: 32, height: 28)
                ctx.stroke(Path(ellipseIn: r), with: ink, lineWidth: 8)
                ctx.stroke(Path(ellipseIn: r), with: .color(Ink.gold), lineWidth: 4)
                var gem = Path()
                gem.addLines([CGPoint(x: c.x - 9, y: c.y - 16), CGPoint(x: c.x + 9, y: c.y - 16), CGPoint(x: c.x + 13, y: c.y - 22), CGPoint(x: c.x, y: c.y - 30), CGPoint(x: c.x - 13, y: c.y - 22)])
                gem.closeSubpath()
                ctx.fill(gem, with: .color(color)); ctx.stroke(gem, with: ink, lineWidth: 2)
            }
        }
    }
}

// MARK: - Álbum de monedas

struct CoinsView: View {
    @Environment(Game.self) private var game
    @State private var picked: CoinDef? = nil
    var body: some View {
        let found = Content.coins.filter { (game.s.coins[$0.id] ?? 0) > 0 }
        let bonus = found.reduce(0) { $0 + $1.rarity.bonus }
        ZStack(alignment: .top) {
            Color(hex: "#2f5d3f").ignoresSafeArea()
            VStack(spacing: 0) {
                SheetHeader(title: "El álbum", subtitle: "\(found.count) de \(Content.coins.count) · +\(Fmt.num(bonus * 100)) % de dinero para siempre")
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 16) {
                        ForEach(Content.coins) { c in
                            let n = game.s.coins[c.id] ?? 0
                            VStack(spacing: 4) {
                                CoinArt(def: c, found: n > 0).frame(width: 74, height: 74)
                                Text(n > 0 ? c.name : "???").font(.chunky(13)).foregroundStyle(Ink.ink).lineLimit(2).multilineTextAlignment(.center)
                                Text(n > 1 ? "×\(n)" : c.rarity.name).font(.typewriter(10, bold: true)).foregroundStyle(n > 0 ? c.rarity.color : Ink.soft)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, minHeight: 140)
                            .paper(n > 0 ? Ink.paper : Ink.paperDark, shadow: 3)
                            .onTapGesture { if n > 0 { Sound.shared.coin(); picked = c } }
                        }
                    }
                    .padding(18)
                    Text("Salen de {las} {huchas} dorad{as} y de los sobres sorpresa. Las repetidas se cambian por dinero.".a)
                        .font(.typewriter(12)).foregroundStyle(Ink.paper.opacity(0.85)).multilineTextAlignment(.center).padding(.horizontal, 24).padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
        }
        .sheet(item: $picked) { c in
            VStack(spacing: 10) {
                CoinArt(def: c, found: true).frame(width: 130, height: 130)
                Text(c.name).font(.chunky(28)).foregroundStyle(Ink.ink)
                Text(c.line).font(.typewriter(15)).foregroundStyle(Ink.soft)
                Text("\(c.rarity.name) · +\(Fmt.num(c.rarity.bonus * 100)) % de dinero").font(.typewriter(14, bold: true)).foregroundStyle(c.rarity.color)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Ink.paper)
            .presentationDetents([.height(320)])
        }
    }
}

struct CoinArt: View {
    let def: CoinDef
    var found: Bool
    var body: some View {
        GeometryReader { g in
            let side = min(g.size.width, g.size.height)
            ZStack {
                ItemImage(name: "c_" + def.id)
                    .saturation(found ? 1 : 0)
                    .opacity(found ? 1 : 0.35)
                Text(found ? (def.id == "yen" ? "" : def.mark) : "?")
                    .font(.chunky(side * (def.mark.count > 2 ? 0.26 : 0.34)))
                    .foregroundStyle(Ink.ink.opacity(found ? 0.6 : 0.4))
                    .offset(x: -side * 0.02)
            }
            .frame(width: g.size.width, height: g.size.height)
        }
    }
}

/// imagen de un objeto 3D (martillo, joya o moneda)
struct ItemImage: View {
    let name: String
    var body: some View {
        if let ui = ItemArt.uiImage(name) {
            Image(uiImage: ui).resizable().interpolation(.high).scaledToFit()
        } else {
            Color.clear
        }
    }
}

// MARK: - Ajustes

struct SettingsView: View {
    @Environment(Game.self) private var game
    @State private var askErase = false
    var body: some View {
        @Bindable var game = game
        ZStack(alignment: .top) {
            Ink.paper.ignoresSafeArea()
            ScrollView {
            VStack(spacing: 0) {
                HStack { Spacer() }
                Text("AJUSTES").font(.chunky(30)).foregroundStyle(Ink.ink).padding(.top, 20)
                VStack(spacing: 14) {
                    Toggle(isOn: $game.s.settings.music) { Text("Música").font(.chunky(20)) }
                    Toggle(isOn: $game.s.settings.sound) { Text("Sonido").font(.chunky(20)) }
                    Toggle(isOn: $game.s.settings.haptics) { Text("Vibración").font(.chunky(20)) }
                    Text("Música: «Lobby Time», «Local Forecast - Elevator», «Bossa Antigua» y «Easy Lemon» de Kevin MacLeod (incompetech.com), licencia CC BY 4.0. Personajes: Quaternius (CC0).")
                        .font(.typewriter(11)).foregroundStyle(Ink.soft)
                }
                .tint(Ink.green)
                .foregroundStyle(Ink.ink)
                .padding(18)
                .paper()
                .padding(18)
                // el animal que se rompe (los textos también cambian: vacas, cerdos, llamas…)
                VStack(alignment: .leading, spacing: 10) {
                    Text("ANIMAL").font(.typewriter(15, bold: true))
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(Content.skins) { k in SkinCard(def: k) }
                    }
                }
                .foregroundStyle(Ink.ink)
                .padding(18)
                .paper(Color(hex: "#fffaf0"))
                .padding(.horizontal, 18).padding(.bottom, 18)
                VStack(alignment: .leading, spacing: 10) {
                    Text("ÁRBOL DE MEJORAS").font(.typewriter(15, bold: true))
                    TreeStylePicker()
                }
                .foregroundStyle(Ink.ink)
                .padding(18)
                .paper(Color(hex: "#fffaf0"))
                .padding(.horizontal, 18).padding(.bottom, 18)
                VStack(alignment: .leading, spacing: 6) {
                    Text("ESTADÍSTICAS").font(.typewriter(15, bold: true))
                    stat("{Huchas} rot{as}", Fmt.num(game.s.stats.broken))
                    stat("Martillazos", Fmt.num(game.s.stats.swings))
                    stat("Dinero ganado", Fmt.money(game.s.stats.earned))
                    stat("Facturas pagadas", Fmt.num(game.s.stats.billsPaid))
                    stat("Días", Fmt.num(game.s.stats.days))
                    stat("Mejor {hucha} en un día", Fmt.money(game.s.stats.bestDay))
                    stat("Reyes Cerdito", Fmt.num(game.s.stats.kings))
                    stat("Bancarrotas", Fmt.num(game.s.stats.bankruptcies))
                }
                .foregroundStyle(Ink.ink)
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .paper(Color(hex: "#fffaf0"))
                .padding(.horizontal, 18)
                Button("Borrar la partida") { askErase = true }
                    .buttonStyle(ChunkyButton(color: Ink.red, text: Ink.paper, size: 17))
                    .padding(.vertical, 30)
            }
            }
            .scrollIndicators(.hidden)
        }
        .onChange(of: game.s.settings) { _, _ in game.applySettings(); game.save() }
        .confirmationDialog("¿Borrar toda la partida?", isPresented: $askErase, titleVisibility: .visible) {
            Button("Borrar todo", role: .destructive) { game.erase() }
            Button("Cancelar", role: .cancel) {}
        } message: { Text("Se pierde todo, también las joyas y las monedas. No se puede deshacer.") }
    }
    private func stat(_ l: String, _ v: String) -> some View {
        HStack { Text(l).font(.typewriter(14)); Spacer(); Text(v).font(.typewriter(14, bold: true)) }
    }
}

// MARK: - Personajes

struct SkinsView: View {
    @Environment(Game.self) private var game
    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: "#2f5d50").ignoresSafeArea()
            VStack(spacing: 0) {
                SheetHeader(title: "Personajes", subtitle: "Lo que rompes a martillazos")
                CashPill(value: "\(Fmt.num(game.s.legacy)) puntos de herencia", color: Color(hex: "#f2d58a")).padding(.bottom, 8)
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(Content.skins) { k in SkinCard(def: k) }
                    }
                    .padding(.horizontal, 18).padding(.vertical, 10)
                }
                .scrollIndicators(.hidden)
            }
        }
    }
}

struct SkinCard: View {
    @Environment(Game.self) private var game
    let def: SkinDef
    var body: some View {
        let owned = game.s.skinsOwned.contains(def.id) || def.cost == 0
        let using = game.s.skin == def.id
        let can = owned || game.s.legacy >= def.cost
        VStack(spacing: 8) {
            SkinIcon(id: def.id, size: 76)
                .frame(height: 66)
                .opacity(owned ? 1 : 0.85)
            Text(def.name).font(.chunky(15)).foregroundStyle(Ink.ink).lineLimit(1).minimumScaleFactor(0.7)
            Button { game.pickSkin(def) } label: {
                Text(using ? "EN USO" : (owned ? "USAR" : "\(Fmt.num(def.cost)) puntos")).frame(maxWidth: .infinity)
            }
            .buttonStyle(ChunkyButton(color: using ? Ink.green : (owned ? Ink.paper : Color(hex: "#f2d58a")), text: using ? Ink.paper : Ink.ink, size: 13, radius: 10))
            .disabled(using || !can)
        }
        .padding(8)
        .paper()
    }
}

/// el personaje en pequeño (para botones)
struct SkinIcon: View {
    var id: String
    var size: CGFloat
    var look = "normal"
    var body: some View {
        if let ui = SkinArt.uiImage(id, look) {
            Image(uiImage: ui).resizable().interpolation(.high).scaledToFit().frame(width: size, height: size)
        } else {
            PigIcon(size: size)
        }
    }
}
