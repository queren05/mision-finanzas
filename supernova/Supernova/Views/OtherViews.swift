import SwiftUI

// MARK: - Logros

struct AchievementsView: View {
    @Environment(GameEngine.self) private var game
    @Environment(\.dismiss) private var dismiss
    @State private var picked: AchievementDef? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                SpaceBackground(active: true)
                ScrollView {
                    VStack(spacing: 16) {
                        let got = game.s.achievements.count
                        VStack(spacing: 6) {
                            Text("\(got) de \(Content.achievements.count)").font(.system(.title, design: .rounded).weight(.heavy))
                            Text("Cada logro: +\(Fmt.dec(game.mods.achievementPct * 100, 0)) % de producción · ahora +\(Fmt.num(Double(got) * game.mods.achievementPct * 100)) %")
                                .font(.caption).foregroundStyle(.white.opacity(0.6))
                            GlowBar(value: Double(got) / Double(Content.achievements.count), color: Palette.good, height: 8)
                        }
                        .padding(16).glass(22, tint: Palette.good)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 14) {
                            ForEach(Content.achievements) { a in
                                let done = game.s.achievements.contains(a.id)
                                let p = game.progress(a)
                                Button { Feedback.shared.tick(); picked = a } label: {
                                    VStack(spacing: 4) {
                                        ZStack {
                                            Circle().fill(done ? Palette.good.opacity(0.22) : .white.opacity(0.05))
                                            Circle().trim(from: 0, to: done ? 1 : p).stroke(done ? Palette.good : Palette.energy.opacity(0.6), style: StrokeStyle(lineWidth: 3, lineCap: .round)).rotationEffect(.degrees(-90))
                                            Image(systemName: a.icon).font(.system(size: 19, weight: .bold)).foregroundStyle(done ? Palette.good : .white.opacity(0.3))
                                        }
                                        .frame(width: 56, height: 56)
                                        .shadow(color: done ? Palette.good.opacity(0.5) : .clear, radius: 8)
                                        Text(a.name).font(.system(size: 9.5, weight: .bold, design: .rounded)).lineLimit(2, reservesSpace: true)
                                            .multilineTextAlignment(.center).foregroundStyle(done ? .white : .white.opacity(0.45))
                                    }
                                }
                                .buttonStyle(PressStyle())
                            }
                        }
                    }
                    .padding(16)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Logros").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Cerrar") { dismiss() } } }
            .sheet(item: $picked) { a in
                let done = game.s.achievements.contains(a.id)
                VStack(spacing: 12) {
                    IconTile(icon: a.icon, color: done ? Palette.good : .gray, size: 64)
                    Text(a.name).font(.system(.title3, design: .rounded).weight(.heavy))
                    Text(a.desc).foregroundStyle(.white.opacity(0.7))
                    if done { Label("Conseguido", systemImage: "checkmark.seal.fill").foregroundStyle(Palette.good).font(.headline) }
                    else { GlowBar(value: game.progress(a), color: Palette.energy, height: 8).padding(.horizontal, 30); Text("\(Fmt.dec(game.progress(a) * 100, 0)) %").font(.caption.weight(.bold)) }
                }
                .padding(24)
                .presentationDetents([.height(270)])
                .preferredColorScheme(.dark)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Ajustes y estadísticas

struct SettingsView: View {
    @Environment(GameEngine.self) private var game
    @Environment(\.dismiss) private var dismiss
    @State private var askErase = false

    var body: some View {
        @Bindable var game = game
        NavigationStack {
            Form {
                Section {
                    Toggle("Sonido", isOn: $game.s.settings.sound)
                    Toggle("Vibración", isOn: $game.s.settings.haptics)
                    Toggle("Notación científica", isOn: $game.s.settings.scientific)
                }
                Section("Estadísticas") {
                    row("Tiempo jugado", Fmt.time(game.s.stats.playSeconds))
                    row("Energía total", Fmt.num(game.s.stats.earnedAll))
                    row("Récord por segundo", Fmt.num(game.s.stats.bestRps))
                    row("Toques", Fmt.num(game.s.stats.taps))
                    row("Generadores comprados", Fmt.num(game.s.stats.bought))
                    row("Mejoras compradas", Fmt.num(game.s.stats.upgrades))
                    row("Estrellas atrapadas", Fmt.num(game.s.stats.stars))
                    row("Misiones", Fmt.num(game.s.stats.missions))
                    row("Big Bangs", Fmt.num(game.s.stats.bigBangs))
                    row("Singularidades en total", Fmt.num(game.s.stats.singAll))
                    row("Mejor combo", "×" + Fmt.dec(game.s.stats.bestCombo, 2))
                    row("Producción sin conexión", "\(Fmt.num(game.mods.offlineHours)) h al \(Fmt.dec(game.mods.offlineRate * 100, 0)) %")
                }
                Section {
                    Button("Borrar la partida", role: .destructive) { askErase = true }
                }
            }
            .scrollContentBackground(.hidden)
            .background(LinearGradient(colors: [Palette.bgTop, Palette.bgBottom], startPoint: .top, endPoint: .bottom))
            .navigationTitle("Ajustes").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Listo") { game.applySettings(); game.save(); dismiss() } } }
            .onChange(of: game.s.settings) { _, _ in game.applySettings() }
            .confirmationDialog("¿Borrar toda la partida?", isPresented: $askErase, titleVisibility: .visible) {
                Button("Borrar todo y empezar de cero", role: .destructive) { game.eraseGame(); dismiss() }
                Button("Cancelar", role: .cancel) {}
            } message: { Text("Se pierde todo: energía, singularidades, universos y logros. No se puede deshacer.") }
        }
        .preferredColorScheme(.dark)
    }

    private func row(_ l: String, _ v: String) -> some View {
        LabeledContent(l) { Text(v).monospacedDigit() }
    }
}

// MARK: - Mientras no estabas

struct OfflineView: View {
    @Environment(\.dismiss) private var dismiss
    let report: OfflineReport
    @State private var shown = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.stars.fill").font(.system(size: 46)).foregroundStyle(Palette.energy)
                .shadow(color: Palette.energy, radius: 14)
                .symbolEffect(.bounce, value: shown)
            Text("Mientras no estabas").font(.system(.title2, design: .rounded).weight(.heavy))
            Text("Has estado fuera \(Fmt.time(report.away))" + (report.counted < report.away ? " (cuentan \(Fmt.time(report.counted)))" : ""))
                .font(.subheadline).foregroundStyle(.white.opacity(0.6)).multilineTextAlignment(.center)
            HStack(spacing: 12) {
                gain("bolt.fill", report.energy, "energía", Palette.energy)
                if report.dark > 0 { gain("aqi.medium", report.dark, "materia oscura", Palette.dark) }
            }
            Button { Feedback.shared.upgrade(); dismiss() } label: {
                Text("Recoger").font(.system(.headline, design: .rounded).weight(.heavy)).foregroundStyle(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Palette.energy, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: Palette.energy.opacity(0.6), radius: 12)
            }
            .buttonStyle(PressStyle())
        }
        .padding(24)
        .presentationDetents([.height(380)])
        .preferredColorScheme(.dark)
        .onAppear { shown = true }
    }

    private func gain(_ icon: String, _ v: Double, _ l: String, _ c: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundStyle(c)
            Text("+" + Fmt.num(v)).font(.system(.title3, design: .rounded).weight(.heavy)).monospacedDigit()
            Text(l).font(.caption).foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .glass(18, tint: c)
    }
}
