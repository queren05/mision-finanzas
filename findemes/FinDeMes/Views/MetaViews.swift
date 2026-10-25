import SwiftUI

// MARK: - Nivel y experiencia (arriba en la cocina)

struct LevelStrip: View {
    @Environment(Game.self) private var game
    var body: some View {
        let k = min(1, game.s.xp / max(1, game.xpNeeded))
        HStack(spacing: 10) {
            Text("\(game.s.level)")
                .font(.chunky(20)).foregroundStyle(Ink.paper)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Ink.purple))
                .overlay(Circle().strokeBorder(Ink.ink, lineWidth: 2.5))
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(Meta.title(game.s.level)).font(.chunky(16)).foregroundStyle(Ink.ink)
                    Spacer()
                    Text("\(Fmt.num(game.s.xp)) / \(Fmt.num(game.xpNeeded))").font(.typewriter(11, bold: true)).foregroundStyle(Ink.soft)
                }
                InkBar(value: k, color: Ink.purple, height: 10)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .outlined(14, color: Ink.paper, shadow: 3)
    }
}

// MARK: - Encargos

struct QuestsCard: View {
    @Environment(Game.self) private var game
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ENCARGOS").font(.chunky(22)).foregroundStyle(Ink.ink)
                Spacer()
                Text("\(Fmt.num(game.s.stats.missions)) hechos").font(.typewriter(12, bold: true)).foregroundStyle(Ink.soft)
            }
            ForEach(game.s.quests) { q in QuestRow(q: q) }
        }
        .padding(14)
        .paper(tilt: 0.4)
    }
}

struct QuestRow: View {
    @Environment(Game.self) private var game
    let q: Quest
    var body: some View {
        let target = q.kind.money ? Fmt.money(q.target) : Fmt.num(q.target)
        HStack(spacing: 10) {
            Image(systemName: q.kind.icon).font(.system(size: 17, weight: .black)).foregroundStyle(Ink.red)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(q.kind.text.filling(target)).font(.typewriter(13, bold: true)).foregroundStyle(Ink.ink).lineLimit(1).minimumScaleFactor(0.7)
                InkBar(value: q.progress / max(1, q.target), color: q.done ? Ink.green : Ink.gold, height: 9)
                Text("+\(Fmt.money(game.questReward(q))) · +\(Fmt.num(q.xp)) exp").font(.typewriter(11)).foregroundStyle(Ink.soft)
            }
            if q.done {
                Button { withAnimation(.spring) { game.claim(q) } } label: { Text("COBRAR") }
                    .buttonStyle(ChunkyButton(color: Ink.green, text: Ink.paper, size: 14, radius: 10))
                    .phaseAnimator([1.0, 1.08]) { v, s in v.scaleEffect(s) } animation: { _ in .easeInOut(duration: 0.5) }
            }
        }
    }
}

// MARK: - Hucha de casa: se llena sola

struct BankCard: View {
    @Environment(Game.self) private var game
    @State private var smash = 0
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { tl in
            let v = game.bankAmount(tl.date)
            let cap = game.bankCap
            HStack(spacing: 12) {
                SkinIcon(id: "cerdo", size: 58, look: v >= cap ? "oro" : "normal")
                    .keyframeAnimator(initialValue: 0.0, trigger: smash) { c, a in c.rotationEffect(.degrees(a)) } keyframes: { _ in
                        CubicKeyframe(-12, duration: 0.06); CubicKeyframe(12, duration: 0.08); CubicKeyframe(0, duration: 0.1)
                    }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Hucha de casa").font(.chunky(18)).foregroundStyle(Ink.ink)
                    Text(Fmt.money(v)).font(.chunky(22)).foregroundStyle(Ink.green)
                        .contentTransition(.numericText(value: v))
                    InkBar(value: v / max(1, cap), color: v >= cap ? Ink.red : Ink.green, height: 8)
                    if v >= cap { Text("¡Llena! Ya no cabe más").font(.typewriter(11, bold: true)).foregroundStyle(Ink.red) }
                }
                Spacer(minLength: 4)
                Button { smash += 1; withAnimation(.snappy) { game.collectBank() } } label: { Text("ROMPER") }
                    .buttonStyle(ChunkyButton(color: Ink.gold, size: 15, radius: 10))
                    .disabled(v < 1)
            }
            .padding(12)
            .paper(tilt: -0.5)
        }
    }
}

// MARK: - Sobres sin abrir

struct ChestsButton: View {
    @Environment(Game.self) private var game
    @Binding var open: Bool
    var body: some View {
        let n = game.s.pendingChests.count
        Button { Sound.shared.click(); open = true } label: {
            HStack(spacing: 12) {
                EnvelopeArt(rarity: game.s.pendingChests.max { $0.order < $1.order } ?? .comun).frame(width: 64, height: 44)
                Text(n == 1 ? "1 sobre sin abrir" : "\(n) sobres sin abrir").font(.chunky(20))
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 16, weight: .black))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(ChunkyButton(color: Ink.paper, size: 18, radius: 16))
        .phaseAnimator([0.0, -2.0, 2.0, 0.0]) { v, a in v.rotationEffect(.degrees(a)) } animation: { _ in .easeInOut(duration: 0.12) }
    }
}

struct ChestSheet: View {
    @Environment(Game.self) private var game
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: "#3d2b5c").ignoresSafeArea()
            VStack(spacing: 0) {
                SheetHeader(title: "Sobres", subtitle: "Toca para abrir")
                ScrollView { ChestOpener().padding(20) }.scrollIndicators(.hidden)
            }
        }
    }
}

// MARK: - Logros

struct AchievementsView: View {
    @Environment(Game.self) private var game
    var body: some View {
        let list = Meta.achievements.sorted { order($0) < order($1) }
        ZStack(alignment: .top) {
            Color(hex: "#5c3a1e").ignoresSafeArea()
            VStack(spacing: 0) {
                SheetHeader(title: "Logros", subtitle: "\(game.s.achievements.count) de \(Meta.achievements.count) · +\(game.s.achievements.count * 3) % de dinero")
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(list) { a in AchRow(def: a) }
                    }
                    .padding(.horizontal, 18).padding(.vertical, 10)
                }
                .scrollIndicators(.hidden)
            }
        }
    }
    /// primero los que se pueden cobrar, luego los que van en camino, al final los conseguidos
    private func order(_ a: AchDef) -> Int {
        if game.s.achievements.contains(a.id) { return 2 }
        return game.metric(a.metric) >= a.target ? 0 : 1
    }
}

struct AchRow: View {
    @Environment(Game.self) private var game
    let def: AchDef
    var body: some View {
        let got = game.s.achievements.contains(def.id)
        let v = game.metric(def.metric)
        let ready = !got && v >= def.target
        HStack(spacing: 12) {
            Image(systemName: got ? "rosette" : (ready ? "gift.fill" : "lock.fill"))
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(got ? Ink.gold : (ready ? Ink.red : Ink.soft))
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(def.name).font(.chunky(17)).foregroundStyle(Ink.ink)
                Text(def.desc).font(.typewriter(12)).foregroundStyle(Ink.soft)
                if !got && !ready { InkBar(value: v / def.target, color: Ink.gold, height: 7) }
            }
            Spacer(minLength: 4)
            if ready {
                Button { withAnimation(.spring) { game.claim(def) } } label: { Text("+3 %") }
                    .buttonStyle(ChunkyButton(color: Ink.green, text: Ink.paper, size: 15, radius: 10))
            } else if got {
                Stamp(text: "HECHO", color: Ink.green).scaleEffect(0.7)
            }
        }
        .padding(10)
        .paper(got ? Ink.paperDark : Ink.paper, shadow: 3)
    }
}

// MARK: - Premio diario

struct DailyView: View {
    @Environment(Game.self) private var game
    var body: some View {
        let today = game.dailyIndex
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("PREMIO DEL DÍA").font(.chunky(30)).foregroundStyle(Ink.red)
                Text(game.s.streak > 0 && today > 0 ? "Llevas \(today) día\(today == 1 ? "" : "s") seguido\(today == 1 ? "" : "s")" : "Vuelve cada día: el premio crece")
                    .font(.typewriter(13, bold: true)).foregroundStyle(Ink.soft)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    ForEach(0..<7, id: \.self) { i in cell(i, today: today) }
                }
                Button {
                    withAnimation(.spring) { game.claimDaily() }
                } label: { Text("¡COGER!").frame(maxWidth: .infinity) }
                    .buttonStyle(ChunkyButton(color: Ink.gold, size: 22))
            }
            .foregroundStyle(Ink.ink)
            .padding(20)
            .paper(tilt: -0.5)
            .padding(22)
        }
    }

    private func cell(_ i: Int, today: Int) -> some View {
        let r = Meta.daily[i]
        let past = i < today
        let now = i == today
        return VStack(spacing: 4) {
            Text("Día \(i + 1)").font(.typewriter(11, bold: true))
            if let ch = r.chest {
                EnvelopeArt(rarity: ch).frame(width: 40, height: 28)
            } else {
                ItemImage(name: "c_loot").frame(width: 30, height: 30)
            }
            Text(r.chest != nil ? r.name : Fmt.money((r.pigs * game.pigWorth).rounded())).font(.typewriter(10, bold: true)).lineLimit(1).minimumScaleFactor(0.6)
        }
        .padding(6)
        .frame(maxWidth: .infinity, minHeight: 86)
        .background(now ? Ink.gold : (past ? Ink.paperDark : Ink.paper))
        .overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: now ? 3 : 1.5))
        .overlay { if past { Image(systemName: "checkmark").font(.system(size: 26, weight: .black)).foregroundStyle(Ink.green) } }
        .scaleEffect(now ? 1.06 : 1)
    }
}

// MARK: - Subida de nivel

struct LevelUpView: View {
    @Environment(Game.self) private var game
    let level: Int
    @State private var pop = false
    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea().onTapGesture { close() }
            VStack(spacing: 12) {
                Text("¡NIVEL \(level)!").font(.chunky(44)).foregroundStyle(Ink.purple)
                    .shadow(color: Ink.ink, radius: 0, x: 3, y: 3)
                    .scaleEffect(pop ? 1 : 0.3)
                Text(Meta.title(level)).font(.chunky(22)).foregroundStyle(Ink.ink)
                HStack(spacing: 10) {
                    EnvelopeArt(rarity: level % 10 == 0 ? .legendaria : (level % 5 == 0 ? .epica : .comun)).frame(width: 60, height: 42)
                    Text("+2 % de dinero para siempre").font(.typewriter(13, bold: true))
                }
                Button { close() } label: { Text("¡Seguimos!").frame(maxWidth: .infinity) }
                    .buttonStyle(ChunkyButton(color: Ink.gold, size: 20))
            }
            .foregroundStyle(Ink.ink)
            .padding(22)
            .paper(tilt: 0.6)
            .padding(30)
        }
        .onAppear {
            Sound.shared.fanfare()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.45)) { pop = true }
        }
    }
    private func close() {
        Sound.shared.click()
        withAnimation { game.levelUp = nil }
    }
}

// MARK: - La historia del principio (cuatro viñetas y a jugar)

struct IntroView: View {
    @Environment(Game.self) private var game
    @State private var page = 0

    private let pages: [(String, String)] = [
        ("DÍA 1 DEL MES", "La nevera, vacía.\nEl buzón, lleno de facturas."),
        ("LA HERENCIA", "Pero la abuela te dejó algo: un trastero lleno de huchas."),
        ("Y SU CHANCLA", "La de toda la vida. Nunca falla."),
        ("EL PLAN", "Rompe huchas, paga las facturas antes de que venzan… y que no venga el cobrador."),
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 16) {
                art.frame(height: 150)
                    .id(page)
                    .transition(.asymmetric(insertion: .scale(scale: 0.6).combined(with: .opacity), removal: .opacity))
                Text(pages[page].0).font(.chunky(32)).foregroundStyle(Ink.red)
                    .id("t\(page)")
                Text(pages[page].1).font(.typewriter(16)).multilineTextAlignment(.center)
                    .id("b\(page)")
                    .frame(minHeight: 66)
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Circle().fill(i == page ? Ink.ink : Ink.paperDark).frame(width: 9, height: 9)
                    }
                }
                Button { next() } label: { Text(page == pages.count - 1 ? "¡A ROMPER!" : "Sigue").frame(maxWidth: .infinity) }
                    .buttonStyle(ChunkyButton(color: Ink.gold, size: 22))
            }
            .foregroundStyle(Ink.ink)
            .padding(22)
            .paper(tilt: page % 2 == 0 ? -0.6 : 0.6)
            .padding(24)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: page)
        }
        .onTapGesture { next() }
    }

    @ViewBuilder private var art: some View {
        switch page {
        case 0:
            VStack(spacing: 4) {
                Text("FACTURA").font(.typewriter(18, bold: true))
                Text("TOTAL: 15 €").font(.typewriter(14))
                Stamp(text: "VENCE PRONTO")
            }
            .padding(14)
            .paper(tilt: -4)
        case 1:
            HStack(spacing: -30) {
                SkinIcon(id: "cerdo", size: 90)
                SkinIcon(id: "cerdo", size: 120, look: "oro")
                SkinIcon(id: "cerdo", size: 90)
            }
        case 2:
            ItemImage(name: "m_chancla").rotationEffect(.degrees(-20))
        default:
            HStack(spacing: 0) {
                ItemImage(name: "m_chancla").frame(width: 70).rotationEffect(.degrees(-35))
                SkinIcon(id: "cerdo", size: 120)
            }
        }
    }

    private func next() {
        Sound.shared.click()
        if page < pages.count - 1 { page += 1; return }
        game.s.seenIntro = true
        game.s.tutorial = 1
        game.save()
        withAnimation { game.startDay() }
    }
}

// MARK: - El huchario: las huchas que has descubierto

/// la hucha de un tipo con el personaje que llevas puesto
struct KindIcon: View {
    @Environment(Game.self) private var game
    let kind: PigKind
    var size: CGFloat
    var body: some View {
        let skin = Content.skin(game.s.skin)
        Group {
            if skin.drawn {
                PigIcon(size: size, kind: kind)
            } else {
                SkinIcon(id: skin.id, size: size, look: kind.look)
            }
        }
        .colorMultiply(kindTint)
        .opacity(kind == .fantasma ? 0.55 : 1)
        .hueRotation(.degrees(kind == .arcoiris ? 120 : 0))
        .saturation(kind == .diamante || kind == .arcoiris ? 1.7 : 1)
        .overlay(alignment: .top) {
            if kind == .rey { Image(systemName: "crown.fill").font(.system(size: size * 0.28)).foregroundStyle(Ink.gold).offset(y: -size * 0.12) }
        }
    }
}

extension KindIcon {
    var kindTint: Color {
        switch kind {
        case .lava: Color(hex: "#ff7a3a")
        case .cosmica: Color(hex: "#a98bff")
        case .robot: Color(hex: "#b8d8ff")
        case .hielo: Color(hex: "#c8f2ff")
        case .suerte: Color(hex: "#8fe39a")
        case .zombi: Color(hex: "#a9c08f")
        case .ninja: Color(hex: "#6a6474")
        case .payaso: Color(hex: "#ffd9a0")
        case .pirata: Color(hex: "#e0b88a")
        case .vampiro: Color(hex: "#c05060")
        default: .white
        }
    }
}

struct PigLevelStrip: View {
    @Environment(Game.self) private var game
    var body: some View {
        HStack(spacing: 8) {
            Text("Huchas nivel \(game.s.tier)").font(.typewriter(12, bold: true)).foregroundStyle(Ink.ink)
            InkBar(value: game.s.pigXP / max(1, game.pigNeeded), color: Ink.pink, height: 8)
            Text("\(Fmt.num(game.s.pigXP))/\(Fmt.num(game.pigNeeded))").font(.typewriter(11)).foregroundStyle(Ink.soft)
        }
    }
}

struct BestiaryView: View {
    @Environment(Game.self) private var game
    var body: some View {
        let kinds = PigKind.allCases.sorted { $0.minTier < $1.minTier }
        let found = kinds.filter { game.s.bestTier >= $0.minTier }.count
        ZStack(alignment: .top) {
            Color(hex: "#7a2f45").ignoresSafeArea()
            VStack(spacing: 0) {
                SheetHeader(title: "El huchario", subtitle: "\(found) de \(kinds.count) huchas descubiertas")
                VStack(spacing: 6) {
                    Text("NIVEL DE LAS HUCHAS: \(game.s.tier)").font(.chunky(18)).foregroundStyle(Ink.ink)
                    Text("Récord: nivel \(game.s.bestTier)").font(.typewriter(12, bold: true)).foregroundStyle(Ink.soft)
                    PigLevelStrip()
                    Text("Suben rompiéndolas y vuelven a empezar con cada bancarrota").font(.typewriter(11)).foregroundStyle(Ink.soft)
                }
                .padding(12).paper().padding(.horizontal, 18).padding(.bottom, 8)
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(kinds, id: \.self) { k in cell(k) }
                    }
                    .padding(.horizontal, 18).padding(.vertical, 10)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private func cell(_ k: PigKind) -> some View {
        let open = game.s.bestTier >= k.minTier
        let n = game.s.brokenByKind[k.rawValue] ?? 0
        return VStack(spacing: 6) {
            ZStack {
                KindIcon(kind: k, size: 92)
                    .brightness(open ? 0 : -1)
                    .opacity(open ? 1 : 0.35)
                if !open { Image(systemName: "lock.fill").font(.system(size: 26, weight: .black)).foregroundStyle(Ink.paper) }
            }
            .frame(height: 86)
            Text(open ? k.name : "???").font(.chunky(16)).foregroundStyle(Ink.ink).lineLimit(1).minimumScaleFactor(0.7)
            Text(open ? k.line : "Sale en el nivel \(k.minTier)").font(.typewriter(11)).foregroundStyle(Ink.soft)
                .multilineTextAlignment(.center).lineLimit(2).frame(minHeight: 28)
            if open {
                HStack(spacing: 10) {
                    Label(Fmt.num(n), systemImage: "hammer.fill")
                    Label("×" + Fmt.num(k.value), systemImage: "eurosign.circle.fill")
                }
                .font(.typewriter(11, bold: true)).foregroundStyle(Ink.ink)
            }
        }
        .padding(10)
        .paper(open ? Ink.paper : Ink.paperDark, shadow: 3)
    }
}

/// aviso de hucha nueva
struct NewKindView: View {
    @Environment(Game.self) private var game
    let kind: PigKind
    @State private var pop = false
    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea().onTapGesture { close() }
            VStack(spacing: 12) {
                Text("¡HUCHA NUEVA!").font(.chunky(36)).foregroundStyle(Ink.red)
                KindIcon(kind: kind, size: 150)
                    .scaleEffect(pop ? 1 : 0.2)
                    .rotationEffect(.degrees(pop ? 0 : -30))
                Text(kind.name).font(.chunky(24))
                Text(kind.line).font(.typewriter(14)).multilineTextAlignment(.center)
                Text("Huchas nivel \(game.s.tier): más vida y más dinero").font(.typewriter(12, bold: true)).foregroundStyle(Ink.soft)
                Button { close() } label: { Text("¡A por ella!").frame(maxWidth: .infinity) }
                    .buttonStyle(ChunkyButton(color: Ink.gold, size: 20))
            }
            .foregroundStyle(Ink.ink)
            .padding(22)
            .paper(tilt: -0.6)
            .padding(30)
        }
        .onAppear {
            Sound.shared.fanfare()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.5)) { pop = true }
        }
    }
    private func close() {
        Sound.shared.click()
        withAnimation { if !game.newKinds.isEmpty { game.newKinds.removeFirst() } }
    }
}
