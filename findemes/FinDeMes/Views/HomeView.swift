import SwiftUI

enum HomeSheet: String, Identifiable {
    case tree, hammers, herencia, album, bar, settings
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
                    MortgageCard()
                    playButton
                    if game.unlocked(.encargos) && !game.s.quests.isEmpty { QuestsCard() }
                    doors
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
            case .herencia: HeritageView()
            case .album: AlbumDoor()
            case .bar: BarView()
            case .settings: SettingsView()
            }
        }
        .onAppear {
            // capturas automáticas
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-tree") { sheet = .tree }
            if args.contains("-hammers") { sheet = .hammers }
            if args.contains("-herencia") { sheet = .herencia }
            if args.contains("-album") { sheet = .album }
            if args.contains("-bar") { sheet = .bar }
            if args.contains("-ajustes") { sheet = .settings }
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
                if game.inspection {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass").font(.system(size: 12, weight: .black))
                        Text("INSPECCIÓN DE HACIENDA · ×2").font(.typewriter(13, bold: true))
                    }
                    .foregroundStyle(Ink.red)
                } else if game.twist != .none {
                    HStack(spacing: 6) {
                        Image(systemName: game.twist.icon).font(.system(size: 12, weight: .black))
                        Text(game.twist.title.a).font(.typewriter(13, bold: true))
                    }
                    .foregroundStyle(Ink.purple)
                }
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
                else if game.inspection { Stamp(text: "HACIENDA").offset(x: -12, y: 36) }
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
                SkinIcon(id: Content.playing(game.s.skin).id, size: 52)
                VStack(alignment: .leading, spacing: 0) {
                    Text("A ROMPER {HUCHAS}".a).font(.chunky(26))
                    Text("con \(Content.hammers[game.s.hammer].name.lowercased())").font(.typewriter(13, bold: true)).opacity(0.75)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(ChunkyButton(color: Ink.gold, size: 24, radius: 18))
    }

    // MARK: las puertas (aparecen poco a poco)

    private var doors: some View {
        let grid = [Door.mejoras, .martillo, .album, .herencia].filter { game.doorOpen($0) }
        let kinds = PigKind.allCases.filter { game.s.bestTier >= $0.minTier }.count
        let legacyBuy = Content.rings.contains { game.ringLevel($0) < $0.maxLevel && game.s.legacy >= $0.cost(game.ringLevel($0)) }
        return VStack(spacing: 14) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                ForEach(grid, id: \.rawValue) { d in
                    switch d {
                    case .mejoras:
                        DoorCard(door: d, subtitle: "Árbol de mejoras", badge: game.bestSkill(Content.skills) != nil) { sheet = .tree }
                    case .martillo:
                        DoorCard(door: d, subtitle: Content.hammers[game.s.hammer].name, badge: game.bestHammer != nil || ((game.s.stats.billsPaid >= 3 || game.s.stats.bankruptcies > 0) && game.bestPart != nil)) { sheet = .hammers }
                    case .album:
                        DoorCard(door: d, subtitle: "\(kinds) {huchas} · \(game.s.achievements.count) logros", badge: game.achievementsReady > 0 || !game.s.pendingChests.isEmpty) { sheet = .album }
                    case .herencia:
                        DoorCard(door: d, subtitle: "\(Fmt.num(game.s.legacy)) puntos", badge: legacyBuy) { sheet = .herencia }
                    case .bar: EmptyView()
                    }
                }
            }
            if game.doorOpen(.bar) {
                DoorCard(door: .bar, subtitle: "Tragaperras y rasca", badge: game.freeSpins > 0 || game.freeScratch) { sheet = .bar }
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: grid.count)
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
