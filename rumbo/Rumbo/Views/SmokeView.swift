import SwiftUI
import UserNotifications

// MARK: - Sin humo: contador para dejar de fumar

struct SmokeAttempt: Codable, Hashable {
    var start: Date
    var end: Date
}

struct Smoke: Codable, Hashable {
    /// cuándo lo dejaste (nil = aún sin empezar)
    var start: Date? = nil
    var perDay: Int = 15
    var perPack: Int = 20
    var packPrice: Double = 5.5
    /// minutos que tardabas en fumarte uno
    var minutesEach: Int = 6
    var reasons: [String] = []
    /// ganas superadas
    var cravings: [Date] = []
    /// caladas o cigarros sueltos sin empezar de cero
    var slips: [Date] = []
    var attempts: [SmokeAttempt] = []
    /// para qué ahorras
    var wish: String = ""
    var wishPrice: Double = 0

    init() {}
    enum CodingKeys: String, CodingKey { case start, perDay, perPack, packPrice, minutesEach, reasons, cravings, slips, attempts, wish, wishPrice }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        let x = Smoke()
        func v<T: Decodable>(_ k: CodingKeys, _ def: T) -> T { (try? c.decodeIfPresent(T.self, forKey: k)) ?? def }
        start = (try? c.decodeIfPresent(Date.self, forKey: .start)) ?? nil
        perDay = v(.perDay, x.perDay); perPack = v(.perPack, x.perPack); packPrice = v(.packPrice, x.packPrice)
        minutesEach = v(.minutesEach, x.minutesEach); reasons = v(.reasons, x.reasons); cravings = v(.cravings, x.cravings)
        slips = v(.slips, x.slips); attempts = v(.attempts, x.attempts); wish = v(.wish, x.wish); wishPrice = v(.wishPrice, x.wishPrice)
    }

    func seconds(_ now: Date) -> TimeInterval { start.map { max(0, now.timeIntervalSince($0)) } ?? 0 }
    func cigarettes(_ now: Date) -> Double { seconds(now) / 86400 * Double(perDay) }
    func money(_ now: Date) -> Double { perPack > 0 ? cigarettes(now) / Double(perPack) * packPrice : 0 }
    /// unos 11 minutos de vida por cigarro (estudio del BMJ)
    func lifeMinutes(_ now: Date) -> Double { cigarettes(now) * 11 }
    func timeMinutes(_ now: Date) -> Double { cigarettes(now) * Double(minutesEach) }
    var dailySaving: Double { perPack > 0 ? Double(perDay) / Double(perPack) * packPrice : 0 }
    var best: TimeInterval { attempts.map { $0.end.timeIntervalSince($0.start) }.max() ?? 0 }
}

/// lo que pasa en tu cuerpo desde el último cigarro (OMS y sociedades de neumología)
struct HealthStep: Identifiable {
    var id: Int { Int(seconds) }
    var seconds: TimeInterval
    var when: String
    var icon: String
    var title: String
    var text: String
}

let healthSteps: [HealthStep] = [
    .init(seconds: 20 * 60, when: "20 minutos", icon: "heart.fill", title: "Pulso y tensión", text: "Tu pulso y tu tensión arterial vuelven a la normalidad."),
    .init(seconds: 8 * 3600, when: "8 horas", icon: "lungs.fill", title: "Oxígeno", text: "El oxígeno en sangre se normaliza y el monóxido de carbono baja a la mitad."),
    .init(seconds: 12 * 3600, when: "12 horas", icon: "drop.fill", title: "Monóxido de carbono", text: "El monóxido de carbono de tu sangre vuelve a niveles normales."),
    .init(seconds: 24 * 3600, when: "1 día", icon: "heart.text.square.fill", title: "Corazón", text: "Empieza a bajar el riesgo de infarto."),
    .init(seconds: 48 * 3600, when: "2 días", icon: "nose.fill", title: "Olfato y gusto", text: "Las terminaciones nerviosas se regeneran: hueles y saboreas mejor. La nicotina ya ha salido de tu cuerpo."),
    .init(seconds: 72 * 3600, when: "3 días", icon: "wind", title: "Respiración", text: "Los bronquios se relajan, respiras mejor y tienes más energía. Es el pico del mono: a partir de aquí, cuesta menos."),
    .init(seconds: 14 * 86400, when: "2 semanas", icon: "figure.walk", title: "Circulación", text: "Mejora la circulación: caminar y subir escaleras te cuesta menos."),
    .init(seconds: 30 * 86400, when: "1 mes", icon: "face.smiling.inverse", title: "Piel y descanso", text: "La piel tiene mejor color y duermes mejor. Las ganas son cada vez más flojas."),
    .init(seconds: 90 * 86400, when: "3 meses", icon: "lungs", title: "Pulmones", text: "Tu capacidad pulmonar ha mejorado hasta un 30 %."),
    .init(seconds: 270 * 86400, when: "9 meses", icon: "allergens.fill", title: "Menos tos", text: "Los cilios de los pulmones se han recuperado: toses menos, te falta menos el aire y tienes menos infecciones."),
    .init(seconds: 365 * 86400, when: "1 año", icon: "heart.circle.fill", title: "Riesgo cardíaco", text: "El riesgo de enfermedad coronaria es la mitad que el de un fumador."),
    .init(seconds: 5 * 365 * 86400, when: "5 años", icon: "brain.head.profile", title: "Ictus", text: "El riesgo de ictus baja hasta el de alguien que nunca ha fumado."),
    .init(seconds: 10 * 365 * 86400, when: "10 años", icon: "cross.case.fill", title: "Cáncer de pulmón", text: "El riesgo de cáncer de pulmón es la mitad que el de un fumador."),
    .init(seconds: 15 * 365 * 86400, when: "15 años", icon: "star.circle.fill", title: "Como si nunca", text: "Tu riesgo de enfermedad del corazón es el de alguien que nunca ha fumado."),
]

struct SmokeBadge: Identifiable {
    enum Kind { case time, money, cigs, cravings }
    var id: String { title }
    var kind: Kind
    var goal: Double
    var title: String
    var icon: String
    var color: String
}

let smokeBadges: [SmokeBadge] = {
    var b: [SmokeBadge] = []
    for (d, t, i) in [(1.0, "Primer día", "sunrise.fill"), (3, "3 días", "flame.fill"), (7, "1 semana", "7.circle.fill"), (14, "2 semanas", "14.circle.fill"),
                      (30, "1 mes", "calendar"), (60, "2 meses", "calendar.badge.checkmark"), (90, "3 meses", "leaf.fill"), (180, "6 meses", "tree.fill"),
                      (365, "1 año", "trophy.fill"), (730, "2 años", "crown.fill")] {
        b.append(.init(kind: .time, goal: d * 86400, title: t, icon: i, color: "#6fd49b"))
    }
    for m in [10.0, 50, 100, 250, 500, 1000, 2000] {
        b.append(.init(kind: .money, goal: m, title: "\(Int(m)) € ahorrados", icon: "eurosign.circle.fill", color: "#f0c46a"))
    }
    for c in [50.0, 100, 500, 1000, 5000] {
        b.append(.init(kind: .cigs, goal: c, title: "\(Int(c)) sin fumar", icon: "nosign", color: "#7ac8ff"))
    }
    for c in [1.0, 10, 50] {
        b.append(.init(kind: .cravings, goal: c, title: c == 1 ? "Primeras ganas superadas" : "\(Int(c)) ganas superadas", icon: "hand.raised.fill", color: "#ff9f7a"))
    }
    return b
}()

func badgeProgress(_ b: SmokeBadge, _ s: Smoke, _ now: Date) -> Double {
    let v: Double
    switch b.kind {
    case .time: v = s.seconds(now)
    case .money: v = s.money(now)
    case .cigs: v = s.cigarettes(now)
    case .cravings: v = Double(s.cravings.filter { $0 >= (s.start ?? .distantFuture) }.count)
    }
    return min(1, v / b.goal)
}

let smokeQuotes = [
    "Cada cigarro que no fumas es una victoria. Hoy ya llevas unas cuantas.",
    "Las ganas duran unos minutos. Tu salud, toda la vida.",
    "No estás dejando algo: estás ganando aire, tiempo y dinero.",
    "El mono es la señal de que tu cuerpo se está curando.",
    "Un día más es un día más. No hace falta pensar en «nunca», solo en hoy.",
    "Respira hondo: ese aire limpio es tuyo.",
    "Lo difícil no es dejarlo, es volver a empezar. Tú ya has empezado.",
    "El dinero que no se va en humo se queda contigo.",
    "Tu corazón ya está más tranquilo que cuando fumabas.",
    "Tus pulmones se están limpiando ahora mismo, mientras lees esto.",
    "Quien lo deja no es más fuerte: es más terco que las ganas.",
    "No hay cigarro que te quite el estrés: solo te quita el mono que él mismo crea.",
    "Las ganas son como olas: suben, rompen y se van.",
    "Piensa en cómo te sentirás mañana si hoy aguantas.",
    "Cada día sin fumar, tu cuerpo te da las gracias.",
    "Ya has hecho lo más difícil: decidirlo.",
    "Saborear la comida, oler el café, subir escaleras sin ahogarte. Todo eso vuelve.",
    "No fumas porque te apetezca: fumabas porque la nicotina te lo pedía. Ya no manda ella.",
    "Un cigarro no vale lo que te ha costado llegar hasta aquí.",
    "Bebe agua, da un paseo, mastica chicle. En 5 minutos se pasa.",
]

let cravingTips = [
    "Bebe un vaso de agua fría despacio.",
    "Sal a dar un paseo de cinco minutos.",
    "Mastica chicle sin azúcar o come una fruta.",
    "Lávate los dientes: el sabor a limpio quita las ganas.",
    "Escribe a alguien y cuéntale que estás aguantando.",
    "Cambia de sitio: las ganas van ligadas a lugares y momentos.",
    "Haz diez sentadillas o estira los brazos.",
    "Mira cuánto llevas ahorrado y piensa en qué te lo vas a gastar.",
    "Lee tus razones para dejarlo.",
    "Espera cinco minutos: la mayoría de las ganas se van solas.",
]

private let smokeGreen = Color(hex: "#6fd49b")

// MARK: - Textos

enum SmokeText {
    static func duration(_ s: TimeInterval) -> String {
        let m = Int(s) / 60, h = m / 60, d = h / 24
        if d >= 365 { let y = d / 365; let r = d % 365 / 30; return "\(y) año\(y == 1 ? "" : "s")" + (r > 0 ? " y \(r) mes\(r == 1 ? "" : "es")" : "") }
        if d >= 30 { let mo = d / 30; let r = d % 30; return "\(mo) mes\(mo == 1 ? "" : "es")" + (r > 0 ? " y \(r) día\(r == 1 ? "" : "s")" : "") }
        if d >= 1 { return "\(d) día\(d == 1 ? "" : "s")" + (h % 24 > 0 ? " y \(h % 24) h" : "") }
        if h >= 1 { return "\(h) h y \(m % 60) min" }
        return "\(m) min"
    }
    static func minutes(_ m: Double) -> String {
        let mi = Int(m)
        if mi >= 1440 { return "\(mi / 1440) d \(mi % 1440 / 60) h" }
        if mi >= 60 { return "\(mi / 60) h \(mi % 60) min" }
        return "\(mi) min"
    }
}

// MARK: - Avisos de logros

extension Store {
    /// avisa cuando llegues a cada cambio de tu cuerpo y a cada logro de tiempo
    func scheduleSmoke() {
        let c = UNUserNotificationCenter.current()
        c.removePendingNotificationRequests(withIdentifiers: (0..<20).map { "smoke-\($0)" })
        guard s.settings.notifySmoke, let start = s.smoke.start else { return }
        var items: [(Date, String, String)] = []
        for h in healthSteps { items.append((start.addingTimeInterval(h.seconds), "\(h.when) sin fumar 💪", h.text)) }
        for b in smokeBadges where b.kind == .time { items.append((start.addingTimeInterval(b.goal), "¡Logro: \(b.title)!", "Llevas \(b.title.lowercased()) sin fumar. Sigue así.")) }
        if s.smoke.dailySaving > 0 {
            for b in smokeBadges where b.kind == .money {
                items.append((start.addingTimeInterval(b.goal / s.smoke.dailySaving * 86400), "¡Has ahorrado \(Int(b.goal)) €!", "Todo eso no se ha ido en humo."))
            }
        }
        let next = items.filter { $0.0 > Date() }.sorted { $0.0 < $1.0 }.prefix(20)
        for (i, it) in next.enumerated() {
            let n = UNMutableNotificationContent()
            n.title = it.1; n.body = it.2; n.sound = .default; n.userInfo = ["smoke": true]
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: it.0)
            c.add(UNNotificationRequest(identifier: "smoke-\(i)", content: n, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
        }
    }
}

// MARK: - Página

struct SmokeView: View {
    @Environment(Store.self) private var store
    @State private var setup = false
    @State private var craving = false
    @State private var quote = Int.random(in: 0..<smokeQuotes.count)
    @State private var askRestart = false
    @State private var newReason = ""
    @State private var badge: SmokeBadge? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if store.s.smoke.start == nil {
                        startCard.appear(0)
                    } else {
                        TimelineView(.periodic(from: .now, by: 1)) { tl in
                            VStack(spacing: 18) {
                                counter(tl.date).appear(0)
                                stats(tl.date).appear(0.04)
                                cravingButton.appear(0.06)
                                quoteCard.appear(0.08)
                                healthCard(tl.date).appear(0.1)
                                wish(tl.date).appear(0.12)
                                badges(tl.date).appear(0.14)
                                reasons.appear(0.16)
                                history.appear(0.18)
                            }
                        }
                    }
                    Color.clear.frame(height: 30)
                }
                .padding(.horizontal, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Sin humo")
            .toolbar {
                if store.s.smoke.start != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button { setup = true } label: { Label("Mis datos", systemImage: "slider.horizontal.3") }
                            Button(role: .destructive) { Haptic.warning(); askRestart = true } label: { Label("He vuelto a fumar", systemImage: "arrow.counterclockwise") }
                        } label: { Image(systemName: "ellipsis.circle") }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) { SettingsButton() }
            }
            .sheet(isPresented: $setup) { SmokeSetup() }
            .sheet(isPresented: $craving) { CravingSheet() }
            .sheet(item: $badge) { b in BadgeSheet(badge: b) }
            .confirmationDialog("¿Empezar el contador de cero?", isPresented: $askRestart, titleVisibility: .visible) {
                Button("Empezar de cero ahora", role: .destructive) { restart() }
                Button("Solo ha sido uno, sigo") { store.s.smoke.slips.append(Date()); Haptic.tap() }
                Button("Cancelar", role: .cancel) {}
            } message: { Text("El intento de ahora se guarda en tu historial.") }
        }
    }

    private func restart() {
        guard let st = store.s.smoke.start else { return }
        store.s.smoke.attempts.append(SmokeAttempt(start: st, end: Date()))
        store.s.smoke.start = Date()
        store.scheduleSmoke()
        Haptic.heavy()
    }

    private var startCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "wind").font(.system(size: 54, weight: .light)).foregroundStyle(smokeGreen)
                .symbolEffect(.pulse, options: .repeating)
            Text("Deja de fumar").font(.title2.weight(.bold))
            Text(smokeQuotes[2]).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button { setup = true } label: {
                Text("Empezar").font(.headline).foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(smokeGreen, in: Capsule())
            }
            .buttonStyle(PressableStyle())
        }
        .padding(8).card(20)
        .padding(.top, 30)
    }

    private func since(_ d: Date) -> String {
        let day = Day.str(d)
        let h = day == Day.today || day == Day.add(Day.today, days: -1) ? Day.header(day).lowercased() : "el " + Day.header(day)
        return "Desde \(h) a las \(Day.time(d))"
    }

    // contador grande
    private func counter(_ now: Date) -> some View {
        let sec = Int(store.s.smoke.seconds(now))
        let parts = [(sec / 86400, "días"), (sec % 86400 / 3600, "horas"), (sec % 3600 / 60, "min"), (sec % 60, "seg")]
        return VStack(spacing: 14) {
            Text("Llevas sin fumar").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(parts, id: \.1) { part in
                    VStack(spacing: 2) {
                        Text("\(part.0)").font(.system(size: 34, weight: .bold, design: .rounded)).monospacedDigit().contentTransition(.numericText())
                        Text(part.1).font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(smokeGreen.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .animation(.snappy, value: sec)
            if let st = store.s.smoke.start {
                Text(since(st)).font(.caption).foregroundStyle(.secondary)
            }
        }
        .card()
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(LinearGradient(colors: [smokeGreen.opacity(0.6), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5))
    }

    private func stats(_ now: Date) -> some View {
        let s = store.s.smoke
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            stat(Money.eur(s.money(now)), "ahorrados", "eurosign.circle.fill", Color(hex: "#f0c46a"))
            stat("\(Int(s.cigarettes(now)))", "cigarros sin fumar", "nosign", Color(hex: "#7ac8ff"))
            stat(SmokeText.minutes(s.lifeMinutes(now)), "de vida ganada", "heart.fill", Color(hex: "#ff8686"))
            stat(SmokeText.minutes(s.timeMinutes(now)), "de tiempo libre", "clock.fill", Color(hex: "#b39cff"))
        }
    }
    private func stat(_ v: String, _ l: String, _ icon: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).foregroundStyle(c)
            Text(v).font(.system(size: 22, weight: .bold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.6).contentTransition(.numericText())
            Text(l).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading).card(14)
    }

    private var cravingButton: some View {
        let n = store.s.smoke.cravings.filter { $0 >= (store.s.smoke.start ?? .distantFuture) }.count
        return Button { Haptic.tap(); craving = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "hand.raised.fill").font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tengo ganas de fumar").font(.headline)
                    if n > 0 { Text(n == 1 ? "Has superado 1 vez" : "Has superado \(n) veces").font(.caption.weight(.semibold)).opacity(0.75) }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.subheadline.weight(.bold))
            }
            .foregroundStyle(.black).padding(16)
            .background(LinearGradient(colors: [Color(hex: "#ff9f7a"), Color(hex: "#f0c46a")], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }

    private var quoteCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "quote.opening").font(.title3).foregroundStyle(smokeGreen)
            Text(smokeQuotes[quote % smokeQuotes.count]).font(.subheadline.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
            Spacer(minLength: 0)
        }
        .card()
        .onTapGesture { Haptic.select(); withAnimation { quote += 1 } }
    }

    // cambios en el cuerpo
    private func healthCard(_ now: Date) -> some View {
        let t = store.s.smoke.seconds(now)
        let nextIndex = healthSteps.firstIndex { $0.seconds > t }
        return VStack(alignment: .leading, spacing: 14) {
            CardTitle(title: "Tu cuerpo se recupera", icon: "heart.text.square.fill", color: Color(hex: "#ff8686"))
            ForEach(Array(healthSteps.enumerated()), id: \.offset) { i, h in
                let prev = i == 0 ? 0 : healthSteps[i - 1].seconds
                let p = min(1, max(0, (t - prev) / (h.seconds - prev)))
                let done = t >= h.seconds
                if done || i == nextIndex || i == (nextIndex ?? 0) + 1 {
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle().stroke(Color.white.opacity(0.08), lineWidth: 4)
                            Circle().trim(from: 0, to: done ? 1 : p).stroke(done ? smokeGreen : Color(hex: "#f0c46a"), style: StrokeStyle(lineWidth: 4, lineCap: .round)).rotationEffect(.degrees(-90))
                            Image(systemName: done ? "checkmark" : h.icon).font(.system(size: 13, weight: .bold)).foregroundStyle(done ? smokeGreen : .primary)
                        }
                        .frame(width: 38, height: 38)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(h.title).font(.subheadline.weight(.bold))
                                Spacer()
                                Text(done ? h.when : "en " + SmokeText.duration(h.seconds - t)).font(.caption.weight(.semibold)).foregroundStyle(done ? smokeGreen : .secondary)
                            }
                            Text(h.text).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .opacity(done || i == nextIndex ? 1 : 0.5)
                }
            }
        }
        .card()
    }

    @ViewBuilder private func wish(_ now: Date) -> some View {
        let s = store.s.smoke
        if !s.wish.isEmpty && s.wishPrice > 0 {
            let p = min(1, s.money(now) / s.wishPrice)
            VStack(alignment: .leading, spacing: 10) {
                CardTitle(title: s.wish, icon: "gift.fill", color: Color(hex: "#f0c46a"), subtitle: p >= 1 ? "¡Ya te lo puedes comprar!" : "\(Money.eur(s.money(now))) de \(Money.eur(s.wishPrice))")
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule().fill(LinearGradient(colors: [Color(hex: "#f0c46a"), smokeGreen], startPoint: .leading, endPoint: .trailing)).frame(width: max(10, g.size.width * p))
                    }
                }
                .frame(height: 12)
                if p < 1, s.dailySaving > 0 {
                    Text("Te faltan \(Int(ceil((s.wishPrice - s.money(now)) / s.dailySaving))) días").font(.caption).foregroundStyle(.secondary)
                }
            }
            .card()
        }
    }

    private func badges(_ now: Date) -> some View {
        let s = store.s.smoke
        let got = smokeBadges.filter { badgeProgress($0, s, now) >= 1 }.count
        return VStack(alignment: .leading, spacing: 12) {
            CardTitle(title: "Logros", icon: "trophy.fill", color: Color(hex: "#f0c46a"), subtitle: "\(got) de \(smokeBadges.count)")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 12) {
                ForEach(smokeBadges) { b in
                    let p = badgeProgress(b, s, now)
                    Button { Haptic.select(); badge = b } label: {
                        VStack(spacing: 5) {
                            ZStack {
                                Circle().fill(p >= 1 ? Color(hex: b.color).opacity(0.22) : Color.white.opacity(0.05))
                                Circle().trim(from: 0, to: p).stroke(Color(hex: b.color).opacity(p >= 1 ? 0 : 0.7), style: StrokeStyle(lineWidth: 3, lineCap: .round)).rotationEffect(.degrees(-90))
                                Image(systemName: b.icon).font(.system(size: 20, weight: .semibold)).foregroundStyle(p >= 1 ? Color(hex: b.color) : .secondary)
                            }
                            .frame(width: 54, height: 54)
                            Text(b.title).font(.system(size: 10, weight: .semibold)).multilineTextAlignment(.center).lineLimit(2, reservesSpace: true)
                                .foregroundStyle(p >= 1 ? .primary : .secondary)
                        }
                        .grayscale(p >= 1 ? 0 : 0.6)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
        .card()
    }

    private var reasons: some View {
        VStack(alignment: .leading, spacing: 10) {
            CardTitle(title: "Mis razones", icon: "heart.circle.fill", color: Color(hex: "#f59fc4"))
            ForEach(Array(store.s.smoke.reasons.enumerated()), id: \.offset) { i, r in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Circle().fill(Color(hex: "#f59fc4")).frame(width: 7, height: 7).offset(y: -2)
                    Text(r).font(.subheadline)
                    Spacer()
                    Button { Haptic.tap(); _ = withAnimation { store.s.smoke.reasons.remove(at: i) } } label: { Image(systemName: "xmark").font(.caption).foregroundStyle(.secondary) }
                }
            }
            HStack {
                Image(systemName: "plus.circle.fill").foregroundStyle(Color(hex: "#f59fc4")).font(.title3)
                TextField("Por mi salud, por mis hijos…", text: $newReason).submitLabel(.done).onSubmit {
                    let t = newReason.trimmingCharacters(in: .whitespaces)
                    guard !t.isEmpty else { return }
                    withAnimation { store.s.smoke.reasons.append(t) }; newReason = ""; Haptic.success()
                }
            }
            .padding(10).background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .card()
    }

    @ViewBuilder private var history: some View {
        let s = store.s.smoke
        if !s.attempts.isEmpty || !s.slips.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                CardTitle(title: "Tu historial", icon: "clock.arrow.circlepath", color: .secondary)
                if s.best > 0 { LabeledContent("Tu mejor racha", value: SmokeText.duration(max(s.best, s.seconds(Date())))).font(.subheadline) }
                LabeledContent("Intentos", value: "\(s.attempts.count + 1)").font(.subheadline)
                if !s.slips.isEmpty { LabeledContent("Cigarros sueltos", value: "\(s.slips.count)").font(.subheadline) }
            }
            .card()
        }
    }
}

// MARK: - Datos

struct SmokeSetup: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var s = Smoke()
    @State private var start = Date()
    @State private var price = ""
    @State private var wishPrice = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Dejé de fumar el", selection: $start, in: ...Date())
                }
                Section("Cuánto fumabas") {
                    Stepper("\(s.perDay) cigarros al día", value: $s.perDay, in: 1...80)
                    Stepper("\(s.perPack) por paquete", value: $s.perPack, in: 1...50)
                    LabeledContent("Precio del paquete") {
                        TextField("5,50 €", text: $price).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    Stepper("\(s.minutesEach) min cada cigarro", value: $s.minutesEach, in: 1...20)
                }
                Section("Para qué ahorras") {
                    TextField("Un viaje, unas zapatillas…", text: $s.wish)
                    LabeledContent("Cuesta") {
                        TextField("0 €", text: $wishPrice).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle("Sin humo").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        var n = s
                        n.start = start
                        n.packPrice = Money.parse(price) ?? n.packPrice
                        n.wishPrice = Money.parse(wishPrice) ?? 0
                        store.s.smoke = n
                        store.scheduleSmoke()
                        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
                        Haptic.success(); dismiss()
                    }.bold()
                }
            }
            .onAppear {
                s = store.s.smoke
                start = s.start ?? Date()
                price = Money.num(s.packPrice)
                wishPrice = s.wishPrice > 0 ? Money.num(s.wishPrice) : ""
            }
        }
    }
}

// MARK: - Ganas de fumar: respirar y aguantar

struct CravingSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var startAt = Date()
    @State private var tip = cravingTips.randomElement() ?? ""
    @State private var done = false
    private let total: TimeInterval = 180

    var body: some View {
        NavigationStack {
            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSince(startAt)
                // 4 s coger aire, 4 s aguantar, 6 s soltar
                let cycle = t.truncatingRemainder(dividingBy: 14)
                let (phase, scale): (String, CGFloat) = cycle < 4 ? ("Coge aire", 0.55 + 0.45 * CGFloat(cycle / 4))
                    : cycle < 8 ? ("Aguanta", 1) : ("Suéltalo despacio", 1 - 0.45 * CGFloat((cycle - 8) / 6))
                let left = max(0, total - t)
                VStack(spacing: 22) {
                    Spacer()
                    ZStack {
                        Circle().fill(smokeGreen.opacity(0.12)).frame(width: 260, height: 260)
                        Circle().fill(RadialGradient(colors: [smokeGreen.opacity(0.75), smokeGreen.opacity(0.25)], center: .center, startRadius: 10, endRadius: 140))
                            .frame(width: 250 * scale, height: 250 * scale)
                        VStack(spacing: 4) {
                            Text(done ? "¡Superado!" : phase).font(.title2.weight(.bold))
                            if !done { Text(String(format: "%d:%02d", Int(left) / 60, Int(left) % 60)).font(.headline.monospacedDigit()).opacity(0.8) }
                        }
                        .foregroundStyle(.white)
                    }
                    Text(tip).font(.headline).multilineTextAlignment(.center).padding(.horizontal, 30)
                        .onTapGesture { Haptic.select(); tip = cravingTips.randomElement() ?? tip }
                    if let r = store.s.smoke.reasons.randomElement() {
                        Label(r, systemImage: "heart.fill").font(.subheadline).foregroundStyle(Color(hex: "#f59fc4"))
                    }
                    Spacer()
                    Button {
                        store.s.smoke.cravings.append(Date()); Haptic.success()
                        withAnimation(.spring) { done = true }
                        Task { try? await Task.sleep(nanoseconds: 1_100_000_000); dismiss() }
                    } label: {
                        Text("Se me han pasado").font(.headline).foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 15)
                            .background(smokeGreen, in: Capsule())
                    }
                    .buttonStyle(PressableStyle())
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 20)
                .onChange(of: phase) { _, _ in Haptic.soft() }
            }
            .background(Color(.systemGroupedBackground))
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { dismiss() } } }
        }
    }
}

struct BadgeSheet: View {
    @Environment(Store.self) private var store
    var badge: SmokeBadge
    var body: some View {
        let p = badgeProgress(badge, store.s.smoke, Date())
        VStack(spacing: 14) {
            Image(systemName: badge.icon).font(.system(size: 54, weight: .semibold)).foregroundStyle(p >= 1 ? Color(hex: badge.color) : .secondary)
                .symbolEffect(.bounce, value: p)
            Text(badge.title).font(.title2.weight(.bold))
            Text(p >= 1 ? "¡Conseguido!" : "Llevas el \(Int(p * 100)) %").foregroundStyle(.secondary)
            ProgressView(value: p).tint(Color(hex: badge.color)).padding(.horizontal, 40)
        }
        .padding(30)
        .presentationDetents([.height(280)])
    }
}

/// tarjeta pequeña para Hoy
struct SmokeMini: View {
    @Environment(Store.self) private var store
    var body: some View {
        Button { Router.shared.open("humo") } label: {
            TimelineView(.periodic(from: .now, by: 60)) { tl in
                let s = store.s.smoke
                HStack(spacing: 12) {
                    Image(systemName: "wind").font(.system(size: 16, weight: .bold)).foregroundStyle(smokeGreen)
                        .frame(width: 34, height: 34).background(smokeGreen.opacity(0.18), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    if s.start == nil {
                        Text("Sin humo").font(.headline)
                        Spacer()
                        Text("Empezar").font(.subheadline.weight(.bold)).foregroundStyle(smokeGreen)
                    } else {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(SmokeText.duration(s.seconds(tl.date)) + " sin fumar").font(.headline)
                            if let next = healthSteps.first(where: { $0.seconds > s.seconds(tl.date) }) {
                                Text("\(next.title) en \(SmokeText.duration(next.seconds - s.seconds(tl.date)))").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(Money.eur(s.money(tl.date))).font(.subheadline.weight(.bold)).foregroundStyle(Color(hex: "#f0c46a"))
                    }
                    Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
                }
            }
            .foregroundStyle(.primary)
        }
        .buttonStyle(PressableStyle())
        .card()
    }
}
