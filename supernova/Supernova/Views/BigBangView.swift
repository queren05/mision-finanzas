import SwiftUI

/// Prestigio: Big Bang (singularidades) con el árbol de constelaciones, y Multiverso (universos)
struct BigBangView: View {
    @Environment(GameEngine.self) private var game
    @Environment(\.dismiss) private var dismiss
    @State private var askBigBang = false
    @State private var askMultiverse = false
    @State private var selected: TalentDef? = nil
    @State private var boom = 0

    var body: some View {
        NavigationStack {
            ZStack {
                SpaceBackground(active: true)
                ScrollView {
                    VStack(spacing: 18) {
                        BlackHoleView(active: true)
                            .frame(height: 210)
                            .keyframeAnimator(initialValue: 1.0, trigger: boom) { c, v in c.scaleEffect(v) } keyframes: { _ in
                                SpringKeyframe(0.6, duration: 0.15)
                                SpringKeyframe(1.3, duration: 0.25)
                                SpringKeyframe(1.0, duration: 0.6, spring: .bouncy)
                            }
                        bigBangCard
                        tree
                        multiverseCard
                    }
                    .padding(.horizontal, 16).padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Big Bang").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Cerrar") { dismiss() } } }
            .confirmationDialog("¿Hacer Big Bang?", isPresented: $askBigBang, titleVisibility: .visible) {
                Button("Big Bang: +\(Fmt.num(game.singularityGain)) singularidades", role: .destructive) {
                    boom += 1
                    game.bigBang()
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Empiezas de cero: pierdes la energía, los generadores, las mejoras y la materia oscura. Te quedas con las singularidades, las constelaciones y los logros.")
            }
            .confirmationDialog("¿Crear un universo nuevo?", isPresented: $askMultiverse, titleVisibility: .visible) {
                Button("Multiverso: +\(Fmt.num(game.universeGain)) universos", role: .destructive) {
                    boom += 1
                    game.multiverse()
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Pierdes también las singularidades y las constelaciones. Cada universo multiplica por 3 toda la producción para siempre.")
            }
            .sheet(item: $selected) { t in TalentSheet(def: t).presentationDetents([.height(300)]) }
        }
        .preferredColorScheme(.dark)
    }

    private var bigBangCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 18) {
                stat(Fmt.num(game.s.singularities), "singularidades", Palette.singularity)
                stat("+\(Fmt.pct(game.s.singEver * game.mods.singularityPct))", "de producción", Palette.gold)
            }
            Button { askBigBang = true } label: {
                VStack(spacing: 2) {
                    Text("BIG BANG").font(.system(.title3, design: .rounded).weight(.black))
                    Text(game.singularityGain >= 1 ? "+\(Fmt.num(game.singularityGain)) singularidades" : "Te falta \(Fmt.num(game.nextSingularityAt)) de energía")
                        .font(.system(.caption, design: .rounded).weight(.bold)).opacity(0.85)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(LinearGradient(colors: game.singularityGain >= 1 ? [Palette.singularity, Palette.dark] : [.white.opacity(0.1), .white.opacity(0.05)], startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: game.singularityGain >= 1 ? Palette.singularity.opacity(0.6) : .clear, radius: 14)
            }
            .buttonStyle(PressStyle())
            .disabled(game.singularityGain < 1)
            Text("Cada singularidad que consigues da un \(Fmt.dec(game.mods.singularityPct * 100, 0)) % más de producción, aunque la gastes.")
                .font(.caption).foregroundStyle(.white.opacity(0.55)).multilineTextAlignment(.center)
        }
        .padding(16)
        .glass(22, tint: Palette.singularity)
    }

    private func stat(_ v: String, _ l: String, _ c: Color) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.system(.title2, design: .rounded).weight(.heavy)).foregroundStyle(c).monospacedDigit()
            Text(l).font(.caption).foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: árbol de constelaciones

    private var tree: some View {
        let cols = 5, rows = (Content.talents.map(\.row).max() ?? 0) + 1
        let cell: CGFloat = 66, gap: CGFloat = 12
        let w = CGFloat(cols) * cell + CGFloat(cols - 1) * gap
        let h = CGFloat(rows) * cell + CGFloat(rows - 1) * 22
        func center(_ t: TalentDef) -> CGPoint {
            CGPoint(x: CGFloat(t.col) * (cell + gap) + cell / 2, y: CGFloat(t.row) * (cell + 22) + cell / 2)
        }
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Constelaciones").font(.system(.headline, design: .rounded).weight(.heavy))
                Spacer()
                Text("\(game.s.talents.count) de \(Content.talents.count)").font(.caption.weight(.bold)).foregroundStyle(Palette.singularity)
            }
            ZStack(alignment: .topLeading) {
                Canvas { ctx, _ in
                    for t in Content.talents {
                        for r in t.requires {
                            guard let p = Content.talents.first(where: { $0.id == r }) else { continue }
                            var path = Path()
                            path.move(to: center(p)); path.addLine(to: center(t))
                            let lit = game.s.talents.contains(t.id)
                            ctx.stroke(path, with: .color(lit ? Palette.singularity.opacity(0.9) : .white.opacity(0.15)), style: StrokeStyle(lineWidth: lit ? 3 : 2, lineCap: .round, dash: lit ? [] : [4, 5]))
                        }
                    }
                }
                .frame(width: w, height: h)
                ForEach(Content.talents) { t in
                    TalentNode(def: t, size: cell)
                        .position(center(t))
                        .onTapGesture { Feedback.shared.tick(); selected = t }
                }
            }
            .frame(width: w, height: h)
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .glass(22)
    }

    // MARK: multiverso

    private var multiverseCard: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "infinity").font(.title2.weight(.black)).foregroundStyle(Palette.universe)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Multiverso").font(.system(.headline, design: .rounded).weight(.heavy))
                    Text("\(Fmt.num(game.s.universes)) universos · producción ×\(Fmt.num(pow(3, game.s.universes)))").font(.caption).foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
            }
            if game.universeGain >= 1 {
                Button { askMultiverse = true } label: {
                    Text("Crear \(Fmt.num(game.universeGain)) universo\(game.universeGain == 1 ? "" : "s")")
                        .font(.system(.subheadline, design: .rounded).weight(.heavy)).foregroundStyle(.black)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Palette.universe, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Palette.universe.opacity(0.6), radius: 12)
                }
                .buttonStyle(PressStyle())
            } else {
                let need = pow(sqrt(game.s.stats.singAll / 1e4).rounded(.down) + 1, 2) * 1e4
                GlowBar(value: game.s.stats.singAll / need, color: Palette.universe)
                Text("El próximo universo, al llegar a \(Fmt.num(need)) singularidades en total").font(.caption).foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(16)
        .glass(22, tint: Palette.universe)
    }
}

struct TalentNode: View {
    @Environment(GameEngine.self) private var game
    let def: TalentDef
    let size: CGFloat
    var body: some View {
        let owned = game.s.talents.contains(def.id)
        let reach = game.isTalentReachable(def)
        let can = game.canBuyTalent(def)
        VStack(spacing: 2) {
            Image(systemName: def.icon)
                .font(.system(size: size * 0.32, weight: .bold))
                .foregroundStyle(owned ? .white : (reach ? Palette.singularity : .white.opacity(0.25)))
                .frame(width: size * 0.78, height: size * 0.78)
                .background(Circle().fill(owned ? AnyShapeStyle(LinearGradient(colors: [Palette.singularity, Palette.dark], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Color.white.opacity(0.06))))
                .overlay(Circle().strokeBorder(can ? Palette.gold : (owned ? .white.opacity(0.5) : .white.opacity(0.12)), lineWidth: can ? 2.5 : 1))
                .shadow(color: owned ? Palette.singularity.opacity(0.8) : (can ? Palette.gold.opacity(0.6) : .clear), radius: 10)
                .phaseAnimator([1.0, can ? 1.08 : 1.0]) { v, s in v.scaleEffect(s) } animation: { _ in .easeInOut(duration: 0.8) }
            Text(owned ? def.name : Fmt.num(def.cost))
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(owned ? .white.opacity(0.8) : (can ? Palette.gold : .white.opacity(0.4)))
                .lineLimit(1).minimumScaleFactor(0.7)
                .frame(width: size + 8)
        }
        .frame(width: size, height: size + 8)
    }
}

struct TalentSheet: View {
    @Environment(GameEngine.self) private var game
    @Environment(\.dismiss) private var dismiss
    let def: TalentDef
    var body: some View {
        let owned = game.s.talents.contains(def.id)
        VStack(spacing: 12) {
            IconTile(icon: def.icon, color: Palette.singularity, size: 62)
            Text(def.name).font(.system(.title3, design: .rounded).weight(.heavy))
            Text(def.desc).font(.subheadline).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center)
            if owned {
                Label("Conseguida", systemImage: "checkmark.seal.fill").foregroundStyle(Palette.good).font(.headline)
            } else if !game.isTalentReachable(def) {
                Text("Antes necesitas: " + def.requires.compactMap { r in Content.talents.first { $0.id == r }?.name }.joined(separator: ", "))
                    .font(.caption).foregroundStyle(.white.opacity(0.5)).multilineTextAlignment(.center)
            } else {
                Button {
                    if game.buyTalent(def) { dismiss() }
                } label: {
                    Text("Desbloquear · \(Fmt.num(def.cost)) singularidades")
                        .font(.system(.subheadline, design: .rounded).weight(.heavy)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(game.canBuyTalent(def) ? AnyShapeStyle(LinearGradient(colors: [Palette.singularity, Palette.dark], startPoint: .leading, endPoint: .trailing)) : AnyShapeStyle(Color.white.opacity(0.08)),
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(PressStyle())
                .disabled(!game.canBuyTalent(def))
            }
        }
        .padding(24)
        .preferredColorScheme(.dark)
    }
}
