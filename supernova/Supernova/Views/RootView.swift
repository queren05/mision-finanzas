import SwiftUI

enum PanelTab: String, CaseIterable, Identifiable {
    case generators, upgrades, research, missions
    var id: String { rawValue }
    var label: String {
        switch self {
        case .generators: "Generadores"
        case .upgrades: "Mejoras"
        case .research: "Laboratorio"
        case .missions: "Misiones"
        }
    }
    var icon: String {
        switch self {
        case .generators: "square.stack.3d.up.fill"
        case .upgrades: "wand.and.stars"
        case .research: "flask.fill"
        case .missions: "flag.checkered"
        }
    }
}

struct RootView: View {
    @Environment(GameEngine.self) private var game
    @Environment(\.scenePhase) private var phase
    @State private var tab: PanelTab = .generators
    @State private var showBigBang = false
    @State private var showAchievements = false
    @State private var showSettings = false

    private var active: Bool { phase == .active }

    var body: some View {
        @Bindable var game = game
        ZStack {
            SpaceBackground(active: active)

            VStack(spacing: 0) {
                header
                CoreView(active: active)
                    .frame(height: 300)
                panel
            }

            ShootingStarLayer(active: active)
            ToastStack()
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showBigBang) { BigBangView() }
        .sheet(isPresented: $showAchievements) { AchievementsView() }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(item: $game.offline) { r in OfflineView(report: r) }
        .onAppear {
            // (capturas automáticas del simulador)
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-tab"), i + 1 < args.count, let t = PanelTab(rawValue: args[i + 1]) { tab = t }
            if args.contains("-bigbang") { showBigBang = true }
            if args.contains("-logros") { showAchievements = true }
            if args.contains("-star") { game.star = ShootingStar(born: Date().addingTimeInterval(4), y: 0.3, fromLeft: true) }
        }
    }

    // MARK: marcador

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                CurrencyChip(icon: "aqi.medium", value: game.s.dark, color: Palette.dark)
                if game.s.singEver > 0 || game.singularityGain > 0 {
                    CurrencyChip(icon: "circle.dashed.inset.filled", value: game.s.singularities, color: Palette.singularity)
                }
                if game.s.universes > 0 {
                    CurrencyChip(icon: "infinity", value: game.s.universes, color: Palette.universe)
                }
                Spacer()
                topButton("trophy.fill", Palette.good) { showAchievements = true }
                topButton("gearshape.fill", .white) { showSettings = true }
            }
            VStack(spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "bolt.fill").font(.title2.weight(.black)).foregroundStyle(Palette.energy)
                        .shadow(color: Palette.energy, radius: 8)
                    Text(Fmt.num(game.s.energy))
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: game.s.energy))
                        .lineLimit(1).minimumScaleFactor(0.5)
                        .shadow(color: Palette.energy.opacity(0.5), radius: 12)
                }
                HStack(spacing: 6) {
                    Text("\(Fmt.num(game.rps)) por segundo").font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7)).monospacedDigit()
                    ForEach(Array(game.s.buffs.enumerated()), id: \.offset) { _, b in
                        BuffChip(buff: b)
                    }
                }
            }
            if game.singularityGain >= 1 || game.s.stats.bigBangs > 0 {
                Button { showBigBang = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "burst.fill")
                        Text(game.singularityGain >= 1 ? "Big Bang: +\(Fmt.num(game.singularityGain)) singularidades" : "Constelaciones y Big Bang")
                            .font(.system(.footnote, design: .rounded).weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(LinearGradient(colors: [Palette.singularity, Palette.dark], startPoint: .leading, endPoint: .trailing), in: Capsule())
                    .shadow(color: Palette.singularity.opacity(0.6), radius: 10)
                }
                .buttonStyle(PressStyle())
                .phaseAnimator([false, true], trigger: game.singularityGain >= 1) { v, on in
                    v.scaleEffect(on ? 1.04 : 1)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    private func topButton(_ icon: String, _ color: Color, _ action: @escaping () -> Void) -> some View {
        Button { Feedback.shared.tick(); action() } label: {
            Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundStyle(color)
                .frame(width: 38, height: 38).glass(19)
        }
        .buttonStyle(PressStyle())
    }

    // MARK: panel inferior

    private var panel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                ForEach(PanelTab.allCases) { t in
                    Button {
                        Feedback.shared.tick()
                        withAnimation(.snappy) { tab = t }
                    } label: {
                        VStack(spacing: 3) {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: t.icon).font(.system(size: 17, weight: .bold))
                                if badge(t) { Circle().fill(Palette.gold).frame(width: 8, height: 8).offset(x: 6, y: -3) }
                            }
                            Text(t.label).font(.system(size: 10.5, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(tab == t ? .white : .white.opacity(0.45))
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background {
                            if tab == t { RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.1)) }
                        }
                    }
                    .buttonStyle(PressStyle())
                }
            }
            .padding(6)

            Group {
                switch tab {
                case .generators: GeneratorsPanel()
                case .upgrades: UpgradesPanel()
                case .research: ResearchPanel()
                case .missions: MissionsPanel()
                }
            }
            .frame(maxHeight: .infinity)
        }
        .glass(26)
        .padding(.horizontal, 10)
        .padding(.bottom, 4)
    }

    /// punto dorado en la pestaña cuando hay algo que hacer
    private func badge(_ t: PanelTab) -> Bool {
        switch t {
        case .generators: return false
        case .upgrades: return game.availableUpgrades.contains { game.s.energy >= $0.cost }
        case .research: return Content.research.contains { game.level($0) < $0.maxLevel && game.s.dark >= $0.cost(game.level($0)) }
        case .missions: return game.s.missions.contains { game.missionProgress($0) >= 1 }
        }
    }
}

struct BuffChip: View {
    var buff: Buff
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { tl in
            let left = max(0, buff.until.timeIntervalSince(tl.date))
            HStack(spacing: 3) {
                Image(systemName: buff.kind == .frenzy ? "sparkles" : "hand.tap.fill")
                Text("×\(Fmt.num(buff.mult)) \(Int(left)) s")
            }
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .foregroundStyle(.black)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Palette.gold, in: Capsule())
        }
    }
}

// MARK: - Estrella fugaz que cruza la pantalla

struct ShootingStarLayer: View {
    @Environment(GameEngine.self) private var game
    var active: Bool

    var body: some View {
        GeometryReader { geo in
            if let st = game.star {
                TimelineView(.animation(minimumInterval: 1 / 60, paused: !active)) { tl in
                    let age = tl.date.timeIntervalSince(st.born)
                    let p = min(1, max(0, age / st.life))
                    let w = geo.size.width + 120
                    let x = st.fromLeft ? -60 + p * w : geo.size.width + 60 - p * w
                    let y = st.y * geo.size.height + sin(p * 9) * 22
                    let dir: Double = st.fromLeft ? -1 : 1
                    ZStack {
                        Canvas { ctx, _ in
                            for k in 0..<14 {
                                let q = Double(k)
                                let tx = x + dir * q * 9
                                let ty = y - sin((p - q * 0.004) * 9) * 22 + sin(q * 0.9) * 2
                                let r = 7 - q * 0.45
                                ctx.fill(Path(ellipseIn: CGRect(x: tx - r, y: ty - r, width: r * 2, height: r * 2)),
                                         with: .color(Palette.gold.opacity(0.55 - q * 0.035)))
                            }
                        }
                        .allowsHitTesting(false)
                        Button { game.catchStar() } label: {
                            Image(systemName: "star.fill")
                                .font(.system(size: 30, weight: .black))
                                .foregroundStyle(LinearGradient(colors: [.white, Palette.gold], startPoint: .top, endPoint: .bottom))
                                .rotationEffect(.degrees(age * 160))
                                .shadow(color: Palette.gold, radius: 14)
                                .frame(width: 76, height: 76)
                                .contentShape(Circle())
                        }
                        .buttonStyle(PressStyle())
                        .position(x: x, y: y)
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}
