import SwiftUI

// MARK: - Generadores

struct GeneratorsPanel: View {
    @Environment(GameEngine.self) private var game

    var body: some View {
        @Bindable var game = game
        VStack(spacing: 8) {
            Picker("", selection: $game.s.settings.buyAmount) {
                Text("×1").tag(1); Text("×10").tag(10); Text("×100").tag(100); Text("Máx.").tag(0)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .onChange(of: game.s.settings.buyAmount) { _, _ in Feedback.shared.tick() }

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Content.generators) { g in
                        if game.isRevealed(g.id) {
                            GeneratorRow(def: g)
                        } else if game.isRevealed(max(0, g.id - 1)) && g.id > 0 {
                            LockedRow(def: g)
                        }
                    }
                }
                .padding(.horizontal, 10).padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
        }
    }
}

struct GeneratorRow: View {
    @Environment(GameEngine.self) private var game
    let def: GeneratorDef
    @State private var bought = 0

    var body: some View {
        let owned = game.s.owned[def.id]
        let n = game.buyCount(def.id)
        let cost = game.cost(def.id, n)
        let can = game.s.energy >= cost
        let color = Color(hex: def.color)
        let rate = game.generatorRate(def.id) * game.globalMult
        let next = Content.milestones.first { $0 > owned }
        let prev = Content.milestones.last { $0 <= owned } ?? 0

        HStack(spacing: 12) {
            IconTile(icon: def.icon, color: color, size: 46)
                .keyframeAnimator(initialValue: 1.0, trigger: bought) { c, v in c.scaleEffect(v) } keyframes: { _ in
                    SpringKeyframe(1.25, duration: 0.08)
                    SpringKeyframe(1.0, duration: 0.4, spring: .bouncy)
                }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(def.name).font(.system(.subheadline, design: .rounded).weight(.bold)).lineLimit(1)
                    if owned > 0 {
                        Text("\(owned)").font(.system(.caption, design: .rounded).weight(.heavy)).monospacedDigit()
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(color.opacity(0.3), in: Capsule())
                            .contentTransition(.numericText(value: Double(owned)))
                    }
                }
                Text(owned > 0 ? "\(Fmt.num(rate))/s · \(Fmt.pct(game.rps > 0 ? rate / game.rps : 0))" : "+\(Fmt.num(def.baseProd * game.generatorMult(def.id) * game.globalMult))/s cada uno")
                    .font(.system(size: 11.5, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                if let next {
                    GlowBar(value: Double(owned - prev) / Double(next - prev), color: color, height: 4)
                        .overlay(alignment: .trailing) {
                            Text("×2 en \(next)").font(.system(size: 9, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.5)).offset(y: 9)
                        }
                        .padding(.bottom, 6)
                }
            }
            Spacer(minLength: 4)
            Button {
                if game.buy(def.id) { bought += 1 }
            } label: {
                VStack(spacing: 1) {
                    Text(n > 1 ? "×\(n)" : "Comprar").font(.system(size: 11, weight: .heavy, design: .rounded))
                    HStack(spacing: 2) {
                        Image(systemName: "bolt.fill").font(.system(size: 9, weight: .black))
                        Text(Fmt.num(cost)).font(.system(size: 13, weight: .heavy, design: .rounded)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
                .foregroundStyle(can ? .black : .white.opacity(0.4))
                .frame(width: 86, height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(can ? AnyShapeStyle(LinearGradient(colors: [Palette.energy, Palette.energy.opacity(0.7)], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Color.white.opacity(0.07)))
                )
                .shadow(color: can ? Palette.energy.opacity(0.5) : .clear, radius: 8)
            }
            .buttonStyle(PressStyle())
        }
        .padding(10)
        .glass(18, tint: owned > 0 ? color : .white)
    }
}

struct LockedRow: View {
    let def: GeneratorDef
    var body: some View {
        HStack(spacing: 12) {
            IconTile(icon: "questionmark", color: .gray, size: 46, dim: true)
            VStack(alignment: .leading, spacing: 2) {
                Text("???").font(.system(.subheadline, design: .rounded).weight(.bold)).foregroundStyle(.white.opacity(0.4))
                Text("Se descubre con \(Fmt.num(def.baseCost * 0.4)) de energía").font(.caption2).foregroundStyle(.white.opacity(0.35))
            }
            Spacer()
        }
        .padding(10)
        .glass(18)
        .opacity(0.7)
    }
}

// MARK: - Mejoras

struct UpgradesPanel: View {
    @Environment(GameEngine.self) private var game

    var body: some View {
        let list = game.availableUpgrades
        ScrollView {
            VStack(spacing: 10) {
                if list.contains(where: { game.s.energy >= $0.cost }) {
                    Button { game.buyAllUpgrades() } label: {
                        Label("Comprar todas las que puedo", systemImage: "cart.fill.badge.plus")
                            .font(.system(.subheadline, design: .rounded).weight(.bold)).foregroundStyle(.black)
                            .frame(maxWidth: .infinity).padding(.vertical, 11)
                            .background(Palette.gold, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(color: Palette.gold.opacity(0.5), radius: 8)
                    }
                    .buttonStyle(PressStyle())
                }
                if list.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "wand.and.stars").font(.largeTitle).foregroundStyle(.white.opacity(0.3))
                        Text("Compra más generadores para desbloquear mejoras").font(.subheadline).foregroundStyle(.white.opacity(0.5)).multilineTextAlignment(.center)
                    }
                    .padding(.top, 30)
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(list.prefix(40)) { u in UpgradeCard(def: u) }
                }
                Text("\(game.s.upgrades.count) de \(Content.upgrades.count) mejoras compradas")
                    .font(.caption2).foregroundStyle(.white.opacity(0.4)).padding(.top, 4)
            }
            .padding(.horizontal, 10).padding(.bottom, 14)
        }
        .scrollIndicators(.hidden)
    }
}

struct UpgradeCard: View {
    @Environment(GameEngine.self) private var game
    let def: UpgradeDef
    var body: some View {
        let can = game.s.energy >= def.cost
        let color = Color(hex: def.color)
        Button { game.buyUpgrade(def) } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    IconTile(icon: def.icon, color: color, size: 32, dim: !can)
                    Spacer()
                    HStack(spacing: 2) {
                        Image(systemName: "bolt.fill").font(.system(size: 9, weight: .black))
                        Text(Fmt.num(def.cost)).font(.system(size: 12, weight: .heavy, design: .rounded)).monospacedDigit()
                    }
                    .foregroundStyle(can ? Palette.energy : .white.opacity(0.4))
                }
                Text(def.name).font(.system(size: 13, weight: .bold, design: .rounded)).lineLimit(2).multilineTextAlignment(.leading)
                Text(def.desc).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.6)).lineLimit(2).multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
            .padding(10)
            .glass(16, tint: can ? color : .white)
            .opacity(can ? 1 : 0.65)
        }
        .buttonStyle(PressStyle())
    }
}

// MARK: - Laboratorio (materia oscura)

struct ResearchPanel: View {
    @Environment(GameEngine.self) private var game
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "aqi.medium").foregroundStyle(Palette.dark)
                    Text("\(Fmt.num(game.darkRate)) de materia oscura por segundo")
                        .font(.system(.caption, design: .rounded).weight(.semibold)).foregroundStyle(.white.opacity(0.7))
                    Spacer()
                }
                .padding(.horizontal, 6)
                ForEach(Content.research) { r in ResearchRow(def: r) }
                Text("La materia oscura sale de tus generadores: cuantos más tengas, más produces.")
                    .font(.caption2).foregroundStyle(.white.opacity(0.4)).padding(.top, 4)
            }
            .padding(.horizontal, 10).padding(.bottom, 14)
        }
        .scrollIndicators(.hidden)
    }
}

struct ResearchRow: View {
    @Environment(GameEngine.self) private var game
    let def: ResearchDef
    var body: some View {
        let l = game.level(def)
        let maxed = l >= def.maxLevel
        let cost = def.cost(l)
        let can = !maxed && game.s.dark >= cost
        HStack(spacing: 12) {
            IconTile(icon: def.icon, color: Palette.dark, size: 42)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(def.name).font(.system(.subheadline, design: .rounded).weight(.bold))
                    Text("Nv. \(l)").font(.system(size: 11, weight: .heavy, design: .rounded)).foregroundStyle(Palette.dark)
                }
                Text(l > 0 ? def.describe(l) : "Nivel 1: " + def.describe(1)).font(.caption).foregroundStyle(.white.opacity(0.6)).lineLimit(2)
            }
            Spacer(minLength: 4)
            Button { game.buyResearch(def) } label: {
                Group {
                    if maxed { Text("Máx.").font(.system(size: 13, weight: .heavy, design: .rounded)) }
                    else {
                        HStack(spacing: 2) {
                            Image(systemName: "aqi.medium").font(.system(size: 10, weight: .black))
                            Text(Fmt.num(cost)).font(.system(size: 13, weight: .heavy, design: .rounded)).monospacedDigit()
                        }
                    }
                }
                .foregroundStyle(can ? .black : .white.opacity(0.4))
                .frame(width: 80, height: 40)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(can ? AnyShapeStyle(Palette.dark) : AnyShapeStyle(Color.white.opacity(0.07))))
                .shadow(color: can ? Palette.dark.opacity(0.6) : .clear, radius: 8)
            }
            .buttonStyle(PressStyle())
            .disabled(maxed)
        }
        .padding(10)
        .glass(18, tint: Palette.dark)
    }
}

// MARK: - Misiones

struct MissionsPanel: View {
    @Environment(GameEngine.self) private var game
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(game.s.missions) { m in MissionCard(mission: m) }
                HStack(spacing: 10) {
                    statTile("flag.checkered", Fmt.num(game.s.stats.missions), "misiones")
                    statTile("trophy.fill", "\(game.s.achievements.count)", "logros")
                    statTile("star.fill", Fmt.num(game.s.stats.stars), "estrellas")
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 10).padding(.bottom, 14)
        }
        .scrollIndicators(.hidden)
    }

    private func statTile(_ icon: String, _ v: String, _ l: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon).foregroundStyle(Palette.gold)
            Text(v).font(.system(.headline, design: .rounded).weight(.heavy))
            Text(l).font(.caption2).foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .glass(16)
    }
}

struct MissionCard: View {
    @Environment(GameEngine.self) private var game
    let mission: Mission
    var body: some View {
        let p = game.missionProgress(mission)
        let done = p >= 1
        HStack(spacing: 12) {
            IconTile(icon: game.missionIcon(mission.kind), color: done ? Palette.good : Palette.energy, size: 42)
            VStack(alignment: .leading, spacing: 5) {
                Text(game.missionText(mission)).font(.system(.subheadline, design: .rounded).weight(.bold)).lineLimit(2)
                GlowBar(value: p, color: done ? Palette.good : Palette.energy, height: 6)
                Text("Premio: \(Fmt.num(game.missionRewardEnergy)) energía · \(Fmt.num(game.missionRewardDark)) materia oscura")
                    .font(.system(size: 10.5, weight: .medium)).foregroundStyle(.white.opacity(0.5)).lineLimit(1).minimumScaleFactor(0.8)
            }
            if done {
                Button { game.claim(mission) } label: {
                    Text("Cobrar").font(.system(size: 13, weight: .heavy, design: .rounded)).foregroundStyle(.black)
                        .padding(.horizontal, 12).frame(height: 38)
                        .background(Palette.good, in: Capsule())
                        .shadow(color: Palette.good.opacity(0.7), radius: 10)
                }
                .buttonStyle(PressStyle())
                .phaseAnimator([1.0, 1.08]) { v, s in v.scaleEffect(s) } animation: { _ in .easeInOut(duration: 0.6) }
            }
        }
        .padding(12)
        .glass(18, tint: done ? Palette.good : .white)
    }
}
