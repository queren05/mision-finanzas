import SwiftUI

enum HomeSheet: String, Identifiable {
    case tree, hammers, jewelry, coins, settings, skins, achievements, bestiary, chests, workshop, totems, bar, pets
    var id: String { rawValue }
}

/// La cocina entre día y día: la factura en la nevera, la cartera y los cajones
struct HomeView: View {
    @Environment(Game.self) private var game
    @State private var sheet: HomeSheet? = nil
    @State private var paidStamp = 0

    var body: some View {
        ZStack {
            KitchenBackground()
            ScrollView {
                VStack(spacing: 22) {
                    topBar
                    LevelStrip()
                    billCard
                    playButton
                    if !game.s.pendingChests.isEmpty {
                        ChestsButton(open: Binding(get: { sheet == .chests }, set: { sheet = $0 ? .chests : nil }))
                            .transition(.scale.combined(with: .opacity))
                    }
                    if game.unlocked(.encargos) && !game.s.quests.isEmpty { QuestsCard() }
                    if game.unlocked(.hucha) { BankCard() }
                    bestiaryCard
                    drawers
                    barCard
                    if let next = game.nextBill {
                        HStack(spacing: 6) {
                            Text("Después:").font(.typewriter(13, bold: true))
                            Text("\(next.company) · \(Fmt.money(game.billAmount(next)))").font(.typewriter(13))
                        }
                        .foregroundStyle(Ink.soft)
                    }
                }
                .padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(item: $sheet) { s in
            switch s {
            case .tree: TreeView()
            case .hammers: HammersView()
            case .jewelry: JewelryView()
            case .coins: CoinsView()
            case .settings: SettingsView()
            case .skins: SkinsView()
            case .achievements: AchievementsView()
            case .bestiary: BestiaryView()
            case .chests: ChestSheet()
            case .workshop: WorkshopView()
            case .totems: TotemsView()
            case .bar: BarView()
            case .pets: PetsView()
            }
        }
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-tree") { sheet = .tree }
            if args.contains("-hammers") { sheet = .hammers }
            if args.contains("-jewelry") { sheet = .jewelry }
            if args.contains("-coins") { sheet = .coins }
            if args.contains("-skins") { sheet = .skins }
            if args.contains("-logros") { sheet = .achievements }
            if args.contains("-huchario") { sheet = .bestiary }
            if args.contains("-taller") { sheet = .workshop }
            if args.contains("-totems") { sheet = .totems }
            if args.contains("-bar") { sheet = .bar }
            if args.contains("-mascotas") { sheet = .pets }
        }
    }

    private var topBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 0) {
                Text("FIN DE MES").font(.chunky(34)).foregroundStyle(Ink.red)
                    .shadow(color: Ink.ink, radius: 0, x: 3, y: 3)
                Text("Día \(game.s.day)" + (game.s.year > 0 ? " · año \(game.s.year + 1)" : "") + (game.s.stats.bankruptcies > 0 ? " · \(Int(game.s.stats.bankruptcies)) bancarrota\(game.s.stats.bankruptcies == 1 ? "" : "s")" : ""))
                    .font(.typewriter(13, bold: true)).foregroundStyle(Ink.soft)
            }
            Spacer()
            Button { sheet = .settings } label: { Image(systemName: "gearshape.fill").font(.system(size: 18, weight: .black)) }
                .buttonStyle(ChunkyButton(color: Ink.paper, size: 16, radius: 12))
        }
    }

    // MARK: la factura pegada en la nevera

    private var billCard: some View {
        let b = game.bill
        let amount = game.billAmount
        let left = game.daysLeft
        let can = game.s.cash >= amount
        return VStack(spacing: 0) {
            // imán
            Circle().fill(Ink.red).frame(width: 26, height: 26).overlay(Circle().strokeBorder(Ink.ink, lineWidth: 2.5))
                .offset(y: 13).zIndex(1)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(b.company).font(.typewriter(17, bold: true))
                    Spacer()
                    Text("Nº \(String(format: "%04d", Int(game.s.stats.billsPaid) + 1))").font(.typewriter(12))
                }
                Text(b.concept).font(.typewriter(14))
                Rectangle().fill(Ink.ink).frame(height: 1.5).opacity(0.6)
                    .overlay(Rectangle().stroke(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])).foregroundStyle(Ink.paper))
                HStack(alignment: .lastTextBaseline) {
                    Text("TOTAL").font(.typewriter(14, bold: true))
                    Spacer()
                    Text(Fmt.money(amount)).font(.chunky(34))
                }
                HStack {
                    Text(left == 0 ? "Vence HOY" : "Vence en \(left) día\(left == 1 ? "" : "s") (día \(game.s.billDue))")
                        .font(.typewriter(13, bold: true)).foregroundStyle(left == 0 ? Ink.red : Ink.ink)
                    Spacer()
                    Text("Tienes \(Fmt.money(game.s.cash))").font(.typewriter(13)).foregroundStyle(can ? Ink.green : Ink.soft)
                }
                Button {
                    game.payBill()
                    paidStamp += 1
                } label: {
                    Text(can ? "PAGAR" : "Te faltan \(Fmt.money(amount - game.s.cash))").frame(maxWidth: .infinity)
                }
                .buttonStyle(ChunkyButton(color: Ink.green, text: Ink.paper, size: 22))
                .disabled(!can)
                .padding(.top, 4)
            }
            .foregroundStyle(Ink.ink)
            .padding(16)
            .paper(tilt: -1.2)
            .overlay(alignment: .topTrailing) {
                if left == 0 { Stamp(text: "ÚLTIMO DÍA").offset(x: -12, y: 36) }
            }
            .keyframeAnimator(initialValue: 0.0, trigger: paidStamp) { v, x in
                v.offset(x: x)
            } keyframes: { _ in
                SpringKeyframe(-8, duration: 0.05); SpringKeyframe(8, duration: 0.05); SpringKeyframe(0, duration: 0.3)
            }
        }
        .overlay {
            if let name = game.autoPaid {
                VStack(spacing: 6) {
                    Stamp(text: "PAGADA", color: Ink.green)
                    Text("\(name) se pagó sola al vencer").font(.typewriter(12, bold: true)).foregroundStyle(Ink.ink)
                        .padding(4).background(Ink.paper)
                }
                .onTapGesture { game.autoPaid = nil }
                .task { try? await Task.sleep(nanoseconds: 2_500_000_000); game.autoPaid = nil }
            }
        }
    }

    private var playButton: some View {
        Button { game.startDay() } label: {
            HStack(spacing: 12) {
                SkinIcon(id: game.s.skin, size: 52)
                VStack(alignment: .leading, spacing: 0) {
                    Text("A ROMPER HUCHAS").font(.chunky(26))
                    Text("con \(Content.hammers[game.s.hammer].name.lowercased())").font(.typewriter(13, bold: true)).opacity(0.75)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(ChunkyButton(color: Ink.gold, size: 24, radius: 18))
    }

    private var bestiaryCard: some View {
        Button { Sound.shared.click(); sheet = .bestiary } label: {
            HStack(spacing: 12) {
                KindIcon(kind: PigKind.allCases.filter { game.s.bestTier >= $0.minTier }.max { $0.minTier < $1.minTier } ?? .normal, size: 52)
                VStack(alignment: .leading, spacing: 4) {
                    Text("El huchario").font(.chunky(20)).foregroundStyle(Ink.ink)
                    PigLevelStrip()
                }
                Image(systemName: "chevron.right").font(.system(size: 16, weight: .black)).foregroundStyle(Ink.ink)
            }
            .padding(.horizontal, 12).padding(.vertical, 4)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(ChunkyButton(color: Ink.paper, size: 18, radius: 16))
    }

    // MARK: cajones

    private var drawers: some View {
        let skillsAvailable = Content.skills.contains { game.canBuy($0) }
        let hammerAvailable = Content.hammers.contains { !game.s.hammersOwned.contains($0.id) && game.s.cash >= $0.cost }
        let found = Content.coins.filter { (game.s.coins[$0.id] ?? 0) > 0 }.count
        let skinAvailable = Content.skins.contains { !game.s.skinsOwned.contains($0.id) && game.s.legacy >= $0.cost }
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
            drawer("Mejoras", "El corcho", "pin.fill", Ink.red, badge: skillsAvailable, .mejoras) { sheet = .tree }
            drawer("Martillos", Content.hammers[game.s.hammer].name, "hammer.fill", Ink.blue, badge: hammerAvailable, .martillos) { sheet = .hammers }
            drawer("Taller", "Piezas para el martillo", "wrench.and.screwdriver.fill", Ink.wood, badge: Content.parts.contains { game.canBuyPart($0) }, .taller) { sheet = .workshop }
            drawer("Tótems", "\(game.s.totemsOn.count) de \(game.totemSlots) puestos", "pawprint.fill", Ink.green, badge: Content.totems.contains { game.totemLevel($0) < TotemDef.maxLevel && game.s.legacy >= $0.cost(game.totemLevel($0)) }, .totems) { sheet = .totems }
            drawer("Logros", "\(game.s.achievements.count) de \(Meta.achievements.count)", "rosette", Ink.gold, badge: game.achievementsReady > 0, .logros) { sheet = .achievements }
            drawer("Joyero", "\(Fmt.num(game.s.legacy)) puntos", "sparkles", Ink.purple, badge: Content.rings.contains { game.ringLevel($0) < $0.maxLevel && game.s.legacy >= $0.cost(game.ringLevel($0)) }, .joyero) { sheet = .jewelry }
            drawer("Mascotas", game.stats.pet?.name ?? "Ninguna", "pawprint.circle.fill", Ink.blue, badge: Content.pets.contains { game.petLevel($0) < PetDef.maxLevel && game.s.legacy >= $0.cost(game.petLevel($0)) }, .mascotas) { sheet = .pets }
            drawer("Monedas", "\(found) de \(Content.coins.count)", "circle.circle.fill", Ink.gold, badge: false, .monedas) { sheet = .coins }
            drawer("Personajes", Content.skin(game.s.skin).name, "theatermasks.fill", Ink.green, badge: skinAvailable, .personajes) { sheet = .skins }
        }
    }

    private var barCard: some View {
        let open = game.unlocked(.bar)
        return Button { Sound.shared.click(); if open { sheet = .bar } else { Sound.shared.denied() } } label: {
            HStack(spacing: 12) {
                Image(systemName: open ? "dice.fill" : "lock.fill").font(.system(size: 26, weight: .black)).foregroundStyle(open ? Ink.red : Ink.soft)
                VStack(alignment: .leading, spacing: 0) {
                    Text("El bar de Manolo").font(.chunky(22)).foregroundStyle(open ? Ink.ink : Ink.soft)
                    Text(open ? "Tragaperras y rasca" : Feature.bar.hint).font(.typewriter(12, bold: true)).foregroundStyle(Ink.soft)
                }
                Spacer()
                if open && game.freeScratch { Text("¡Rasca gratis!").font(.chunky(14)).foregroundStyle(Ink.paper).padding(.horizontal, 8).padding(.vertical, 2).background(Ink.red, in: Capsule()).overlay(Capsule().strokeBorder(Ink.ink, lineWidth: 2)) }
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(ChunkyButton(color: open ? Ink.paper : Ink.paperDark, size: 18, radius: 16))
    }

    private func drawer(_ title: String, _ sub: String, _ icon: String, _ color: Color, badge: Bool, _ feature: Feature, _ action: @escaping () -> Void) -> some View {
        let open = game.unlocked(feature)
        return Button { Sound.shared.click(); if open { action() } else { Sound.shared.denied() } } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: open ? icon : "lock.fill").font(.system(size: 20, weight: .black)).foregroundStyle(open ? color : Ink.soft)
                    Spacer()
                    if badge && open { Text("¡!").font(.chunky(15)).foregroundStyle(Ink.paper).padding(.horizontal, 7).background(Ink.red, in: Capsule()).overlay(Capsule().strokeBorder(Ink.ink, lineWidth: 2)) }
                }
                Text(title).font(.chunky(22)).foregroundStyle(open ? Ink.ink : Ink.soft)
                Text(open ? sub : feature.hint).font(.typewriter(12, bold: true)).foregroundStyle(Ink.soft).lineLimit(1).minimumScaleFactor(0.7)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(ChunkyButton(color: open ? Ink.paper : Ink.paperDark, size: 18, radius: 16))
    }
}

/// la hucha en pequeño (para botones e iconos)
struct PigIcon: View {
    var size: CGFloat = 40
    var kind: PigKind = .normal
    var body: some View {
        Canvas { ctx, sz in
            let s = Double(min(sz.width, sz.height)) * 0.82
            let ink = GraphicsContext.Shading.color(Ink.ink)
            ctx.translateBy(x: sz.width / 2 - s * 0.05, y: sz.height / 2)
            for lx in [-0.3, 0.25] {
                let r = CGRect(x: s * lx - s * 0.07, y: s * 0.18, width: s * 0.14, height: s * 0.2)
                ctx.fill(Path(roundedRect: r, cornerRadius: 3), with: .color(kind.dark)); ctx.stroke(Path(roundedRect: r, cornerRadius: 3), with: ink, lineWidth: 2)
            }
            let body = Path(ellipseIn: CGRect(x: -s * 0.5, y: -s * 0.36, width: s, height: s * 0.66))
            ctx.fill(body, with: .color(kind.color)); ctx.stroke(body, with: ink, lineWidth: 2.5)
            var ear = Path()
            ear.addLines([CGPoint(x: s * 0.05, y: -s * 0.3), CGPoint(x: s * 0.16, y: -s * 0.5), CGPoint(x: s * 0.26, y: -s * 0.28)])
            ear.closeSubpath()
            ctx.fill(ear, with: .color(kind.dark)); ctx.stroke(ear, with: ink, lineWidth: 2)
            let snout = Path(ellipseIn: CGRect(x: s * 0.38, y: -s * 0.1, width: s * 0.18, height: s * 0.22))
            ctx.fill(snout, with: .color(kind.dark)); ctx.stroke(snout, with: ink, lineWidth: 2)
            ctx.fill(Path(ellipseIn: CGRect(x: s * 0.12, y: -s * 0.22, width: s * 0.18, height: s * 0.18)), with: .color(.white))
            ctx.stroke(Path(ellipseIn: CGRect(x: s * 0.12, y: -s * 0.22, width: s * 0.18, height: s * 0.18)), with: ink, lineWidth: 1.8)
            ctx.fill(Path(ellipseIn: CGRect(x: s * 0.18, y: -s * 0.15, width: s * 0.08, height: s * 0.08)), with: ink)
            ctx.fill(Path(roundedRect: CGRect(x: -s * 0.14, y: -s * 0.39, width: s * 0.26, height: s * 0.06), cornerRadius: 2), with: ink)
        }
        .frame(width: size, height: size)
    }
}
