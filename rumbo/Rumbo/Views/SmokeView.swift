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
    /// cigarros apuntados mientras aún fumas, para saber cuánto fumas
    var log: [Date] = []
    var measuring = false
    /// horas que pasas despierto (para calcular cada cuánto fumas)
    var awake: Int = 16
    /// logros ya celebrados
    var seen: [String] = []
    /// días en que has prometido no fumar (yyyy-MM-dd)
    var pledges: [String] = []

    init() {}
    enum CodingKeys: String, CodingKey { case start, perDay, perPack, packPrice, minutesEach, reasons, cravings, slips, attempts, wish, wishPrice, log, measuring, awake, seen, pledges }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        let x = Smoke()
        func v<T: Decodable>(_ k: CodingKeys, _ def: T) -> T { (try? c.decodeIfPresent(T.self, forKey: k)) ?? def }
        start = (try? c.decodeIfPresent(Date.self, forKey: .start)) ?? nil
        perDay = v(.perDay, x.perDay); perPack = v(.perPack, x.perPack); packPrice = v(.packPrice, x.packPrice)
        minutesEach = v(.minutesEach, x.minutesEach); reasons = v(.reasons, x.reasons); cravings = v(.cravings, x.cravings)
        slips = v(.slips, x.slips); attempts = v(.attempts, x.attempts); wish = v(.wish, x.wish); wishPrice = v(.wishPrice, x.wishPrice)
        log = v(.log, x.log); measuring = v(.measuring, x.measuring); awake = v(.awake, x.awake)
        seen = v(.seen, x.seen); pledges = v(.pledges, x.pledges)
    }

    func seconds(_ now: Date) -> TimeInterval { start.map { max(0, now.timeIntervalSince($0)) } ?? 0 }
    func cigarettes(_ now: Date) -> Double { seconds(now) / 86400 * Double(perDay) }
    func money(_ now: Date) -> Double { perPack > 0 ? cigarettes(now) / Double(perPack) * packPrice : 0 }
    func packs(_ now: Date) -> Double { perPack > 0 ? cigarettes(now) / Double(perPack) : 0 }
    /// unos 11 minutos de vida por cigarro (estudio del BMJ)
    func lifeMinutes(_ now: Date) -> Double { cigarettes(now) * 11 }
    func timeMinutes(_ now: Date) -> Double { cigarettes(now) * Double(minutesEach) }
    var dailySaving: Double { perPack > 0 ? Double(perDay) / Double(perPack) * packPrice : 0 }
    var best: TimeInterval { attempts.map { $0.end.timeIntervalSince($0.start) }.max() ?? 0 }
    /// minutos entre cigarro y cigarro
    var interval: Int { max(1, Int((Double(awake * 60) / Double(max(1, perDay))).rounded())) }
    var cravingsNow: Int { cravings.filter { $0 >= (start ?? .distantFuture) }.count }
    var pledgesNow: Int { let d = start.map { Day.str($0) } ?? "9999"; return pledges.filter { $0 >= d }.count }
    var pledgedToday: Bool { pledges.contains(Day.today) }
    var pledgeStreak: Int {
        var d = pledgedToday ? Day.today : Day.add(Day.today, days: -1)
        var n = 0
        while pledges.contains(d) { n += 1; d = Day.add(d, days: -1) }
        return n
    }

    /// lo que sale de lo apuntado: cuántos al día y cada cuántos minutos
    func measured(_ now: Date) -> (perDay: Int, interval: Int)? {
        guard log.count >= 3, let first = log.min() else { return nil }
        let today = Day.str(now)
        let past = Dictionary(grouping: log, by: { Day.str($0) }).filter { $0.key != today }
        let perDay: Double
        if !past.isEmpty {
            perDay = Double(past.values.map(\.count).reduce(0, +)) / Double(past.count)
        } else {
            let hours = now.timeIntervalSince(first) / 3600
            guard hours >= 2 else { return nil }
            perDay = Double(log.count) / hours * Double(awake)
        }
        let sorted = log.sorted()
        var gaps: [Double] = []
        for (a, b) in zip(sorted, sorted.dropFirst()) where Day.str(a) == Day.str(b) {
            let g = b.timeIntervalSince(a) / 60
            if g > 0 && g < 360 { gaps.append(g) }
        }
        let interval = gaps.count >= 2 ? gaps.sorted()[gaps.count / 2] : Double(awake * 60) / max(1, perDay)
        return (max(1, Int(perDay.rounded())), max(1, Int(interval.rounded())))
    }
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

// MARK: - Logros

struct SmokeBadge: Identifiable {
    enum Kind: String, CaseIterable { case time, money, cigs, packs, cravings, life, free, pledges }
    var id: String { "\(kind.rawValue)-\(Int(goal))" }
    var kind: Kind
    var goal: Double
    var title: String
    var icon: String
    var text: String
    var color: String { SmokeBadge.color(kind) }

    static func color(_ k: Kind) -> String {
        switch k {
        case .time: "#6fd49b"
        case .money: "#f0c46a"
        case .cigs: "#7ac8ff"
        case .packs: "#5fd3c8"
        case .cravings: "#ff9f7a"
        case .life: "#ff8686"
        case .free: "#b39cff"
        case .pledges: "#f59fc4"
        }
    }
    static func name(_ k: Kind) -> String {
        switch k {
        case .time: "Tiempo sin fumar"
        case .money: "Dinero ahorrado"
        case .cigs: "Cigarros sin fumar"
        case .packs: "Paquetes sin comprar"
        case .cravings: "Ganas superadas"
        case .life: "Vida ganada"
        case .free: "Tiempo libre"
        case .pledges: "Promesas cumplidas"
        }
    }
}

let smokeBadges: [SmokeBadge] = {
    var b: [SmokeBadge] = []
    func add(_ k: SmokeBadge.Kind, _ g: Double, _ t: String, _ i: String, _ x: String) { b.append(.init(kind: k, goal: g, title: t, icon: i, text: x)) }
    for (d, t, i) in [(0.25, "6 horas", "clock.fill"), (0.5, "12 horas", "moon.stars.fill"), (1, "Primer día", "sunrise.fill"), (2, "2 días", "2.circle.fill"),
                      (3, "3 días", "3.circle.fill"), (4, "4 días", "4.circle.fill"), (5, "5 días", "5.circle.fill"), (7, "1 semana", "7.circle.fill"),
                      (10, "10 días", "10.circle.fill"), (14, "2 semanas", "14.circle.fill"), (21, "3 semanas", "21.circle.fill"), (30, "1 mes", "calendar"),
                      (45, "45 días", "45.circle.fill"), (60, "2 meses", "calendar.badge.checkmark"), (90, "3 meses", "leaf.fill"), (100, "100 días", "seal.fill"),
                      (120, "4 meses", "sun.max.fill"), (150, "5 meses", "mountain.2.fill"), (180, "6 meses", "tree.fill"), (200, "200 días", "checkmark.seal.fill"),
                      (270, "9 meses", "figure.run"), (300, "300 días", "star.fill"), (365, "1 año", "trophy.fill"), (500, "500 días", "medal.fill"),
                      (547, "Año y medio", "rosette"), (730, "2 años", "crown.fill"), (1000, "1000 días", "sparkles"), (1095, "3 años", "star.circle.fill"),
                      (1825, "5 años", "flag.checkered"), (3650, "10 años", "infinity")] {
        add(.time, d * 86400, t, i, d == 1 ? "Tu primer día entero sin fumar." : d == 3 ? "3 días sin fumar: el peor momento del mono ya ha pasado." : "\(t) sin fumar.")
    }
    for m in [5.0, 10, 20, 50, 75, 100, 150, 200, 250, 365, 500, 750, 1000, 1500, 2000, 3000, 5000, 10000] {
        add(.money, m, "\(Int(m)) €", m >= 1000 ? "banknote.fill" : "eurosign.circle.fill", "Ahorrar \(Int(m)) € que antes se iban en humo.")
    }
    for c in [10.0, 50, 100, 200, 365, 500, 1000, 2000, 3000, 5000, 10000, 20000, 50000] {
        add(.cigs, c, "\(Int(c)) cigarros", "nosign", "\(Int(c)) cigarros que no han pasado por tus pulmones.")
    }
    for p in [1.0, 5, 10, 25, 50, 100, 250, 500, 1000] {
        add(.packs, p, p == 1 ? "1 paquete" : "\(Int(p)) paquetes", "shippingbox.fill", p == 1 ? "El primer paquete que no has tenido que comprar." : "\(Int(p)) paquetes que no has tenido que comprar.")
    }
    for c in [1.0, 3, 5, 10, 25, 50, 100, 250] {
        add(.cravings, c, c == 1 ? "Primeras ganas" : "\(Int(c)) ganas", "hand.raised.fill", c == 1 ? "Superar las ganas de fumar por primera vez." : "Superar las ganas de fumar \(Int(c)) veces.")
    }
    for (m, l) in [(60.0, "1 hora"), (600, "10 horas"), (1440, "1 día"), (4320, "3 días"), (10080, "1 semana"), (43200, "1 mes"), (129600, "3 meses"), (525600, "1 año")] {
        add(.life, m, "\(l) de vida", m >= 43200 ? "bolt.heart.fill" : "heart.fill", "Recuperar \(l) de vida que te quitaba el tabaco.")
    }
    for (m, l) in [(60.0, "1 hora libre"), (300, "5 horas libres"), (1440, "1 día libre"), (4320, "3 días libres"), (10080, "1 semana libre"), (43200, "1 mes libre")] {
        add(.free, m, l, "hourglass", "\(l) que antes se te iba en fumar.")
    }
    for p in [1.0, 3, 7, 14, 30, 60, 100, 365] {
        add(.pledges, p, p == 1 ? "Primera promesa" : "\(Int(p)) promesas", "hand.thumbsup.fill", p == 1 ? "Prometer por primera vez que hoy no fumas." : "Prometer \(Int(p)) días que no ibas a fumar.")
    }
    return b
}()

func badgeValue(_ k: SmokeBadge.Kind, _ s: Smoke, _ now: Date) -> Double {
    switch k {
    case .time: s.seconds(now)
    case .money: s.money(now)
    case .cigs: s.cigarettes(now)
    case .packs: s.packs(now)
    case .cravings: Double(s.cravingsNow)
    case .life: s.lifeMinutes(now)
    case .free: s.timeMinutes(now)
    case .pledges: Double(s.pledgesNow)
    }
}

func badgeProgress(_ b: SmokeBadge, _ s: Smoke, _ now: Date) -> Double {
    min(1, badgeValue(b.kind, s, now) / b.goal)
}

/// cuánto falta para un logro, si depende solo del tiempo
func badgeETA(_ b: SmokeBadge, _ s: Smoke, _ now: Date) -> TimeInterval? {
    let perSecond: Double
    switch b.kind {
    case .time: perSecond = 1
    case .money: perSecond = s.dailySaving / 86400
    case .cigs: perSecond = Double(s.perDay) / 86400
    case .packs: perSecond = s.perPack > 0 ? Double(s.perDay) / Double(s.perPack) / 86400 : 0
    case .life: perSecond = Double(s.perDay) * 11 / 86400
    case .free: perSecond = Double(s.perDay * s.minutesEach) / 86400
    case .cravings, .pledges: return nil
    }
    guard perSecond > 0 else { return nil }
    return max(0, (b.goal - badgeValue(b.kind, s, now)) / perSecond)
}

/// niveles según los logros conseguidos
let smokeLevels: [(from: Int, name: String)] = [(0, "Principiante"), (3, "Decidido"), (8, "Valiente"), (15, "Fuerte"), (25, "Constante"),
                                                 (35, "Imparable"), (50, "Héroe"), (65, "Leyenda"), (85, "Libre")]
func smokeLevel(_ got: Int) -> (n: Int, name: String, next: Int?, from: Int) {
    let i = smokeLevels.lastIndex { got >= $0.from } ?? 0
    return (i + 1, smokeLevels[i].name, i + 1 < smokeLevels.count ? smokeLevels[i + 1].from : nil, smokeLevels[i].from)
}

/// en qué te podrías gastar lo ahorrado
let smokeTreats: [(name: String, icon: String, price: Double)] = [
    ("cafés", "cup.and.saucer.fill", 1.5), ("entradas de cine", "film.fill", 9), ("menús del día", "fork.knife", 13), ("cenas fuera", "wineglass.fill", 35),
    ("conciertos", "music.mic", 60), ("zapatillas buenas", "shoeprints.fill", 90), ("findes fuera", "suitcase.fill", 250), ("consolas", "gamecontroller.fill", 500),
]

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
    "No eres un fumador que no fuma: eres alguien que ya no fuma.",
    "Cada vez que aguantas, las ganas siguientes son un poco más flojas.",
    "El primer cigarro nunca es el último. Por eso no merece la pena.",
    "Hoy huele mejor tu ropa, tu casa y tu pelo.",
    "Estás enseñando a tu cerebro a vivir sin nicotina. Y está aprendiendo.",
    "Tu yo de dentro de un año te lo va a agradecer muchísimo.",
    "Los malos días también se pasan sin fumar.",
    "No cuentes los días: haz que los días cuenten.",
    "Tu cuerpo empezó a curarse 20 minutos después del último cigarro.",
    "Fumar no te relajaba: te quitaba un mono que el propio tabaco te daba.",
    "Cada paquete que no compras es un regalo que te haces.",
    "Más aire, más energía, más vida. Eso es lo que estás ganando.",
    "Si has llegado hasta aquí, puedes llegar mucho más lejos.",
    "Las ganas no son órdenes. Puedes notarlas y dejarlas pasar.",
    "Ser libre es no depender de un mechero.",
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
    "Ocupa las manos: un boli, una pelota, el móvil.",
    "Cómete unos frutos secos o una zanahoria.",
    "Date una ducha o lávate la cara con agua fría.",
    "Pon tu canción favorita y cántala entera.",
    "Respira hondo diez veces, contando cada una.",
    "Si es después de comer, levántate de la mesa ya.",
    "Si estás con café o alcohol, cámbialo por agua un rato.",
    "Piensa en el olor del tabaco en la ropa y en las manos.",
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
        if mi >= 60 && mi < 1440 && mi % 60 == 0 { return "\(mi / 60) h" }
        if mi >= 1440 { return "\(mi / 1440) d \(mi % 1440 / 60) h" }
        if mi >= 60 { return "\(mi / 60) h \(mi % 60) min" }
        return "\(mi) min"
    }
}

// MARK: - Avisos de logros

extension Store {
    /// avisa cuando llegues a cada cambio de tu cuerpo y a cada logro, y cada mañana te recuerda cuánto llevas
    func scheduleSmoke() {
        let c = UNUserNotificationCenter.current()
        c.removePendingNotificationRequests(withIdentifiers: (0..<20).map { "smoke-\($0)" } + (0..<7).map { "smoke-m\($0)" })
        guard s.settings.notifySmoke, let start = s.smoke.start else { return }
        let sm = s.smoke
        var items: [(Date, String, String)] = []
        for h in healthSteps { items.append((start.addingTimeInterval(h.seconds), "\(h.when) sin fumar 💪", h.text)) }
        for b in smokeBadges {
            guard let eta = badgeETA(b, sm, start) else { continue }
            items.append((start.addingTimeInterval(eta), "🏆 Nuevo logro: \(b.title)", b.text + " Sigue así."))
        }
        let next = items.filter { $0.0 > Date() }.sorted { $0.0 < $1.0 }.prefix(20)
        for (i, it) in next.enumerated() { smokeNoti(c, "smoke-\(i)", it.0, it.1, it.2) }
        // un empujón cada mañana
        let cal = Calendar.current
        for i in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: i + 1, to: cal.startOfDay(for: Date())),
                  let at = cal.date(bySettingHour: 9, minute: 30, second: 0, of: day), at > start else { continue }
            let d = Int(at.timeIntervalSince(start) / 86400)
            let saved = Money.eur(sm.money(at))
            let title = d < 1 ? "Hoy tampoco fumas 💪" : "Llevas \(d) día\(d == 1 ? "" : "s") sin fumar 💪"
            smokeNoti(c, "smoke-m\(i)", at, title, "\(saved) ahorrados. \(smokeQuotes[(d + i) % smokeQuotes.count])")
        }
    }
    private func smokeNoti(_ c: UNUserNotificationCenter, _ id: String, _ at: Date, _ title: String, _ body: String) {
        let n = UNMutableNotificationContent()
        n.title = title; n.body = body; n.sound = .default; n.userInfo = ["smoke": true]
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: at)
        c.add(UNNotificationRequest(identifier: id, content: n, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
    }
}

// MARK: - Página

struct SmokeView: View {
    @Environment(Store.self) private var store
    @State private var setup = false
    @State private var craving = false
    @State private var quote = Int.random(in: 0..<smokeQuotes.count)
    @State private var askRestart = false
    @State private var askStopMeasure = false
    @State private var askUndo = false
    @State private var newReason = ""
    @State private var badge: SmokeBadge? = nil
    @State private var allBadges = false
    @State private var celebrate: SmokeBadge? = nil
    private let tick = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if store.s.smoke.start == nil {
                        if store.s.smoke.measuring {
                            TimelineView(.periodic(from: .now, by: 30)) { tl in measure(tl.date) }
                        } else {
                            startCard.appear(0)
                        }
                    } else {
                        TimelineView(.periodic(from: .now, by: 1)) { tl in
                            VStack(spacing: 18) {
                                counter(tl.date).appear(0)
                                pledge.appear(0.02)
                                stats(tl.date).appear(0.04)
                                cravingButton.appear(0.06)
                                quoteCard.appear(0.08)
                                badges(tl.date).appear(0.1)
                                healthCard(tl.date).appear(0.12)
                                treats(tl.date).appear(0.14)
                                wish(tl.date).appear(0.16)
                                reasons.appear(0.18)
                                history.appear(0.2)
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
                            Button { allBadges = true } label: { Label("Todos los logros", systemImage: "trophy") }
                            Button(role: .destructive) { Haptic.warning(); askRestart = true } label: { Label("He vuelto a fumar", systemImage: "arrow.counterclockwise") }
                        } label: { Image(systemName: "ellipsis.circle") }
                    }
                } else if store.s.smoke.measuring {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button(role: .destructive) { askStopMeasure = true } label: { Label("Dejar de apuntar", systemImage: "xmark.circle") }
                        } label: { Image(systemName: "ellipsis.circle") }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) { SettingsButton() }
            }
            .sheet(isPresented: $setup) { SmokeSetup() }
            .sheet(isPresented: $craving, onDismiss: checkNew) { CravingSheet() }
            .sheet(item: $badge) { b in BadgeSheet(badge: b) }
            .sheet(isPresented: $allBadges) { AllBadgesSheet() }
            .sheet(item: $celebrate) { b in CelebrationSheet(badge: b) }
            .confirmationDialog("¿Empezar el contador de cero?", isPresented: $askRestart, titleVisibility: .visible) {
                Button("Empezar de cero ahora", role: .destructive) { restart() }
                Button("Solo ha sido uno, sigo") { store.s.smoke.slips.append(Date()); Haptic.tap() }
                Button("Cancelar", role: .cancel) {}
            } message: { Text("El intento de ahora se guarda en tu historial.") }
            .confirmationDialog("¿Borrar todo lo apuntado?", isPresented: $askStopMeasure, titleVisibility: .visible) {
                Button("Borrar y dejar de apuntar", role: .destructive) { withAnimation { store.s.smoke.log = []; store.s.smoke.measuring = false } }
                Button("Cancelar", role: .cancel) {}
            }
            .confirmationDialog("¿Quitar el último cigarro apuntado?", isPresented: $askUndo, titleVisibility: .visible) {
                Button("Quitar", role: .destructive) { _ = withAnimation { store.s.smoke.log.popLast() } }
                Button("Cancelar", role: .cancel) {}
            }
            .onAppear {
                checkNew()
                if ProcessInfo.processInfo.arguments.contains("-logros") { allBadges = true }
            }
            .onReceive(tick) { _ in checkNew() }
        }
    }

    /// celebra los logros nuevos (una vez cada uno)
    private func checkNew() {
        let s = store.s.smoke
        guard s.start != nil else { return }
        let new = smokeBadges.filter { !s.seen.contains($0.id) && badgeProgress($0, s, Date()) >= 1 }
        guard !new.isEmpty else { return }
        store.s.smoke.seen += new.map(\.id)
        if celebrate == nil && badge == nil && !allBadges && !craving && !setup {
            celebrate = new.max { ($0.kind == .time ? 1 : 0, $0.goal) < ($1.kind == .time ? 1 : 0, $1.goal) }
        }
    }

    private func restart() {
        guard let st = store.s.smoke.start else { return }
        store.s.smoke.attempts.append(SmokeAttempt(start: st, end: Date()))
        store.s.smoke.start = Date()
        store.s.smoke.seen = []
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
                Text("Ya lo he dejado").font(.headline).foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(smokeGreen, in: Capsule())
            }
            .buttonStyle(PressableStyle())
            Button { Haptic.tap(); withAnimation { store.s.smoke.measuring = true } } label: {
                Text("Aún fumo: apuntar lo que fumo").font(.headline).foregroundStyle(smokeGreen).frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(smokeGreen.opacity(0.14), in: Capsule())
            }
            .buttonStyle(PressableStyle())
        }
        .padding(8).card(20)
        .padding(.top, 30)
    }

    // MARK: apuntar lo que fumas (antes de dejarlo)

    private func logOne() {
        Haptic.heavy()
        withAnimation(.snappy) { store.s.smoke.log.append(Date()) }
    }

    @ViewBuilder private func measure(_ now: Date) -> some View {
        let s = store.s.smoke
        let today = s.log.filter { Day.str($0) == Day.str(now) }
        let m = s.measured(now)
        let each = s.perPack > 0 ? s.packPrice / Double(s.perPack) : 0
        VStack(spacing: 18) {
            Button(action: logOne) {
                VStack(spacing: 8) {
                    Image(systemName: "plus").font(.system(size: 34, weight: .bold))
                    Text("Me he fumado uno").font(.title3.weight(.bold))
                    if let last = s.log.last {
                        Text("El último, hace \(SmokeText.duration(now.timeIntervalSince(last)))").font(.caption.weight(.semibold)).opacity(0.7)
                    }
                }
                .foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 26)
                .background(LinearGradient(colors: [Color(hex: "#ff9f7a"), Color(hex: "#f0c46a")], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            .buttonStyle(PressableStyle())
            .appear(0)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                stat("\(today.count)", "hoy", "sun.max.fill", Color(hex: "#f0c46a"))
                stat(Money.eur(Double(today.count) * each), "gastados hoy", "eurosign.circle.fill", Color(hex: "#ff8686"))
                stat(m.map { "uno cada " + SmokeText.minutes(Double($0.interval)) } ?? "—", "de media", "timer", Color(hex: "#7ac8ff"))
                stat(m.map { "\($0.perDay) al día" } ?? "—", m.map { "\(Money.eur(Double($0.perDay) * each * 365)) al año" } ?? "de media", "calendar", Color(hex: "#b39cff"))
            }
            .appear(0.04)
            if !today.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    CardTitle(title: "Hoy", icon: "clock.fill", color: Color(hex: "#ff9f7a"), subtitle: today.count == 1 ? "1 cigarro" : "\(today.count) cigarros")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                        ForEach(today, id: \.self) { d in
                            Text(Day.time(d)).font(.caption.weight(.semibold).monospacedDigit())
                                .frame(maxWidth: .infinity).padding(.vertical, 7)
                                .background(Color.white.opacity(0.07), in: Capsule())
                        }
                    }
                    Button { askUndo = true } label: { Label("Quitar el último", systemImage: "arrow.uturn.backward").font(.subheadline) }
                        .buttonStyle(.borderless).foregroundStyle(.secondary)
                }
                .card()
                .appear(0.08)
            }
            VStack(spacing: 12) {
                Text(m == nil ? "Cuando quieras, déjalo" : "Ya sabes cuánto fumas").font(.headline)
                Button { setup = true } label: {
                    Text("Lo dejo ya").font(.headline).foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(smokeGreen, in: Capsule())
                }
                .buttonStyle(PressableStyle())
            }
            .card()
            .appear(0.12)
        }
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

    // promesa de cada día
    @ViewBuilder private var pledge: some View {
        let s = store.s.smoke
        if s.pledgedToday {
            HStack(spacing: 12) {
                Image(systemName: "hand.thumbsup.fill").font(.title3).foregroundStyle(Color(hex: "#f59fc4"))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Hoy has prometido no fumar").font(.subheadline.weight(.bold))
                    Text(s.pledgeStreak == 1 ? "Primer día de racha" : "\(s.pledgeStreak) días seguidos prometiéndolo").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(smokeGreen)
            }
            .card()
        } else {
            Button {
                Haptic.success()
                withAnimation(.spring) { store.s.smoke.pledges.append(Day.today) }
                checkNew()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "hand.thumbsup.fill").font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hoy no voy a fumar").font(.headline)
                        if s.pledgeStreak > 0 { Text("Racha de \(s.pledgeStreak) día\(s.pledgeStreak == 1 ? "" : "s"): no la rompas").font(.caption.weight(.semibold)).opacity(0.75) }
                    }
                    Spacer()
                    Image(systemName: "circle").font(.title2)
                }
                .foregroundStyle(.black).padding(16)
                .background(LinearGradient(colors: [Color(hex: "#f59fc4"), Color(hex: "#b39cff")], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(PressableStyle())
        }
    }

    private func stats(_ now: Date) -> some View {
        let s = store.s.smoke
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            stat(Money.eur(s.money(now)), "ahorrados", "eurosign.circle.fill", Color(hex: "#f0c46a"))
            stat("\(Int(s.cigarettes(now)))", "cigarros sin fumar", "nosign", Color(hex: "#7ac8ff"))
            stat(SmokeText.minutes(s.lifeMinutes(now)), "de vida ganada", "heart.fill", Color(hex: "#ff8686"))
            stat(SmokeText.minutes(s.timeMinutes(now)), "de tiempo libre", "clock.fill", Color(hex: "#b39cff"))
            stat(String(format: "%.1f", s.packs(now)).replacingOccurrences(of: ".", with: ","), "paquetes sin comprar", "shippingbox.fill", Color(hex: "#5fd3c8"))
            stat("\(s.cravingsNow)", s.cravingsNow == 1 ? "vez has vencido las ganas" : "veces has vencido las ganas", "hand.raised.fill", Color(hex: "#ff9f7a"))
        }
    }
    private func stat(_ v: String, _ l: String, _ icon: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).foregroundStyle(c)
            Text(v).font(.system(size: 22, weight: .bold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.6).contentTransition(.numericText())
            Text(l).font(.caption).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading).card(14)
    }

    private var cravingButton: some View {
        Button { Haptic.tap(); craving = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "hand.raised.fill").font(.title2)
                Text("Tengo ganas de fumar").font(.headline)
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

    // en qué te gastarías lo ahorrado y lo que ahorrarás
    private func treats(_ now: Date) -> some View {
        let s = store.s.smoke
        let money = s.money(now)
        let can = smokeTreats.filter { money >= $0.price }.suffix(3).reversed()
        let next = smokeTreats.first { money < $0.price }
        return VStack(alignment: .leading, spacing: 12) {
            CardTitle(title: "Con lo que has ahorrado", icon: "bag.fill", color: Color(hex: "#f0c46a"), subtitle: Money.eur(money))
            ForEach(Array(can), id: \.name) { t in
                HStack(spacing: 10) {
                    Image(systemName: t.icon).foregroundStyle(Color(hex: "#f0c46a")).frame(width: 24)
                    Text("\(Int(money / t.price)) \(t.name)").font(.subheadline.weight(.semibold))
                    Spacer()
                }
            }
            if let next {
                HStack(spacing: 10) {
                    Image(systemName: next.icon).foregroundStyle(.secondary).frame(width: 24)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("1 de \(next.name)").font(.subheadline).foregroundStyle(.secondary)
                        ProgressView(value: money / next.price).tint(Color(hex: "#f0c46a"))
                    }
                }
            }
            if s.dailySaving > 0 {
                Divider().opacity(0.3)
                HStack {
                    ForEach([(30.0, "En 1 mes"), (365, "En 1 año"), (1825, "En 5 años")], id: \.1) { d in
                        VStack(spacing: 2) {
                            Text(Money.eur(s.dailySaving * d.0).replacingOccurrences(of: ",00", with: "")).font(.subheadline.weight(.bold)).lineLimit(1).minimumScaleFactor(0.7)
                            Text(d.1).font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
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

    // nivel, últimos logros y los siguientes
    private func badges(_ now: Date) -> some View {
        let s = store.s.smoke
        let got = smokeBadges.filter { badgeProgress($0, s, now) >= 1 }
        let lastGot = Array(got.sorted { badgeProgressDate($0, s) > badgeProgressDate($1, s) }.prefix(2))
        let next = Array(smokeBadges.filter { badgeProgress($0, s, now) < 1 }
            .sorted { (badgeETA($0, s, now) ?? .infinity, -badgeProgress($0, s, now)) < (badgeETA($1, s, now) ?? .infinity, -badgeProgress($1, s, now)) }
            .prefix(6 - lastGot.count))
        return VStack(alignment: .leading, spacing: 14) {
            Button { Haptic.select(); allBadges = true } label: {
                HStack {
                    CardTitle(title: "Logros", icon: "trophy.fill", color: Color(hex: "#f0c46a"), subtitle: "\(got.count) de \(smokeBadges.count)")
                    Spacer()
                    Text("Ver todos").font(.subheadline.weight(.semibold)).foregroundStyle(Color(hex: "#f0c46a"))
                    Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            LevelBar(got: got.count)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 14) {
                ForEach(lastGot + next) { b in
                    Button { Haptic.select(); badge = b } label: { BadgeCell(badge: b, progress: badgeProgress(b, s, now)) }
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

/// cuándo se consiguió (o se conseguirá) un logro, para ordenarlos
func badgeProgressDate(_ b: SmokeBadge, _ s: Smoke) -> Double {
    guard let st = s.start else { return 0 }
    if let eta = badgeETA(b, s, st) { return eta }
    return b.kind == .cravings ? (s.cravings.filter { $0 >= st }.sorted().dropFirst(Int(b.goal) - 1).first?.timeIntervalSince(st) ?? 0)
        : Double(b.goal) * 86400
}

// MARK: - Piezas de logros

struct BadgeCell: View {
    var badge: SmokeBadge
    var progress: Double
    var size: CGFloat = 58
    var body: some View {
        let done = progress >= 1
        let c = Color(hex: badge.color)
        VStack(spacing: 6) {
            ZStack {
                Circle().fill(done ? AnyShapeStyle(LinearGradient(colors: [c.opacity(0.4), c.opacity(0.12)], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Color.white.opacity(0.05)))
                Circle().strokeBorder(done ? c.opacity(0.7) : .clear, lineWidth: 1.5)
                Circle().trim(from: 0, to: progress).stroke(c.opacity(done ? 0 : 0.75), style: StrokeStyle(lineWidth: 3, lineCap: .round)).rotationEffect(.degrees(-90))
                Image(systemName: badge.icon).font(.system(size: size * 0.36, weight: .semibold)).foregroundStyle(done ? c : .secondary)
            }
            .frame(width: size, height: size)
            Text(badge.title).font(.system(size: 11, weight: .semibold)).multilineTextAlignment(.center).lineLimit(2, reservesSpace: true)
                .foregroundStyle(done ? .primary : .secondary)
        }
        .grayscale(done ? 0 : 0.6)
    }
}

struct LevelBar: View {
    var got: Int
    var body: some View {
        let lv = smokeLevel(got)
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(LinearGradient(colors: [Color(hex: "#f0c46a"), Color(hex: "#ff9f7a")], startPoint: .topLeading, endPoint: .bottomTrailing))
                Text("\(lv.n)").font(.system(size: 18, weight: .heavy, design: .rounded)).foregroundStyle(.black)
            }
            .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("Nivel \(lv.n) · \(lv.name)").font(.subheadline.weight(.bold))
                    Spacer()
                    if let n = lv.next { Text("\(n - got) para subir").font(.caption).foregroundStyle(.secondary) }
                }
                ProgressView(value: lv.next.map { Double(got - lv.from) / Double($0 - lv.from) } ?? 1).tint(Color(hex: "#f0c46a"))
            }
        }
    }
}

struct AllBadgesSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var badge: SmokeBadge? = nil
    var body: some View {
        NavigationStack {
            let s = store.s.smoke
            let now = Date()
            let got = smokeBadges.filter { badgeProgress($0, s, now) >= 1 }.count
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    LevelBar(got: got).card()
                    ForEach(SmokeBadge.Kind.allCases, id: \.self) { k in
                        let list = smokeBadges.filter { $0.kind == k }
                        let n = list.filter { badgeProgress($0, s, now) >= 1 }.count
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(SmokeBadge.name(k)).font(.headline)
                                Spacer()
                                Text("\(n) de \(list.count)").font(.subheadline.weight(.semibold)).foregroundStyle(Color(hex: SmokeBadge.color(k)))
                            }
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 14) {
                                ForEach(list) { b in
                                    Button { Haptic.select(); badge = b } label: { BadgeCell(badge: b, progress: badgeProgress(b, s, now), size: 52) }
                                        .buttonStyle(PressableStyle())
                                }
                            }
                        }
                        .card()
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 30)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Logros · \(got) de \(smokeBadges.count)").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Cerrar") { dismiss() } } }
            .sheet(item: $badge) { b in BadgeSheet(badge: b) }
        }
    }
}

/// pantalla de fiesta al conseguir un logro
struct CelebrationSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    var badge: SmokeBadge
    @State private var pop = false
    var body: some View {
        let c = Color(hex: badge.color)
        let got = smokeBadges.filter { badgeProgress($0, store.s.smoke, Date()) >= 1 }.count
        ZStack {
            Confetti(colors: [c, Color(hex: "#f0c46a"), Color(hex: "#f59fc4"), Color(hex: "#7ac8ff"), smokeGreen])
            VStack(spacing: 18) {
                Spacer()
                Text("¡Nuevo logro!").font(.headline).foregroundStyle(c)
                ZStack {
                    Circle().fill(c.opacity(0.18)).frame(width: 170, height: 170).scaleEffect(pop ? 1 : 0.4)
                    Circle().fill(LinearGradient(colors: [c.opacity(0.55), c.opacity(0.2)], startPoint: .top, endPoint: .bottom)).frame(width: 128, height: 128)
                    Image(systemName: badge.icon).font(.system(size: 58, weight: .bold)).foregroundStyle(.white)
                        .symbolEffect(.bounce, value: pop)
                }
                .scaleEffect(pop ? 1 : 0.3).rotationEffect(.degrees(pop ? 0 : -25))
                Text(badge.title).font(.largeTitle.weight(.heavy)).multilineTextAlignment(.center)
                Text(badge.text).font(.headline).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 30)
                LevelBar(got: got).padding(.horizontal, 30).padding(.top, 6)
                Spacer()
                Button { dismiss() } label: {
                    Text("¡A por el siguiente!").font(.headline).foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 15)
                        .background(c, in: Capsule())
                }
                .buttonStyle(PressableStyle())
                .padding(.horizontal, 24).padding(.bottom, 20)
            }
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            Haptic.success()
            withAnimation(.spring(response: 0.55, dampingFraction: 0.55).delay(0.1)) { pop = true }
        }
    }
}

/// confeti que cae
struct Confetti: View {
    var colors: [Color]
    @State private var start = Date()
    private let pieces: [(x: Double, speed: Double, spin: Double, size: Double, delay: Double, c: Int)] = (0..<70).map { i in
        (Double.random(in: 0...1), Double.random(in: 140...320), Double.random(in: -360...360), Double.random(in: 6...11), Double.random(in: 0...1.2), i)
    }
    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSince(start)
                for p in pieces {
                    let tt = t - p.delay
                    guard tt > 0 else { continue }
                    let y = -20 + tt * p.speed
                    guard y < size.height + 20 else { continue }
                    let x = p.x * size.width + sin(tt * 2 + p.x * 10) * 18
                    var c = ctx
                    c.translateBy(x: x, y: y)
                    c.rotate(by: .degrees(tt * p.spin))
                    c.opacity = max(0, 1 - tt / 5)
                    c.fill(Path(CGRect(x: -p.size / 2, y: -p.size / 4, width: p.size, height: p.size / 2)), with: .color(colors[p.c % colors.count]))
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
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
    @State private var byInterval = false
    @State private var every = 60
    private static let everyOptions = [5, 10, 15, 20, 30, 40, 45, 60, 75, 90, 120, 150, 180, 240, 300, 360, 480]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Dejé de fumar el", selection: $start, in: ...Date())
                }
                Section("Cuánto fumabas") {
                    Picker("", selection: $byInterval) {
                        Text("Al día").tag(false)
                        Text("Cada cuánto").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    if let m = store.s.smoke.measured(Date()) {
                        Button {
                            Haptic.tap()
                            s.perDay = m.perDay; every = Self.nearest(m.interval); byInterval = false
                        } label: {
                            Label("Lo que has apuntado: \(m.perDay) al día", systemImage: "chart.bar.fill")
                        }
                    }
                    if byInterval {
                        Stepper("Uno cada \(SmokeText.minutes(Double(every)))", onIncrement: { step(1) }, onDecrement: { step(-1) })
                        Stepper("\(s.awake) horas despierto", value: $s.awake, in: 6...22)
                        LabeledContent("Salen", value: "\(s.perDay) al día")
                    } else {
                        Stepper("\(s.perDay) cigarros al día", value: $s.perDay, in: 1...80)
                        LabeledContent("Uno cada", value: SmokeText.minutes(Double(s.interval)))
                    }
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
            .onChange(of: s.awake) { _, _ in if byInterval { recompute() } }
            .onChange(of: byInterval) { _, on in if on { every = Self.nearest(s.interval); recompute() } }
            .navigationTitle("Sin humo").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        var n = s
                        n.start = start
                        n.measuring = false
                        n.log = store.s.smoke.log
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
                if s.start == nil, let m = s.measured(Date()) { s.perDay = m.perDay }
                start = s.start ?? Date()
                price = Money.num(s.packPrice)
                wishPrice = s.wishPrice > 0 ? Money.num(s.wishPrice) : ""
                every = Self.nearest(s.interval)
            }
        }
    }

    private static func nearest(_ m: Int) -> Int { everyOptions.min { abs($0 - m) < abs($1 - m) } ?? 60 }
    private func step(_ d: Int) {
        let i = Self.everyOptions.firstIndex(of: every) ?? 7
        every = Self.everyOptions[min(Self.everyOptions.count - 1, max(0, i + d))]
        Haptic.select()
        recompute()
    }
    private func recompute() { s.perDay = max(1, min(80, Int((Double(s.awake * 60) / Double(every)).rounded()))) }
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
        let sm = store.s.smoke
        let p = badgeProgress(badge, sm, Date())
        let eta = badgeETA(badge, sm, Date())
        VStack(spacing: 14) {
            BadgeCell(badge: badge, progress: p, size: 96)
                .symbolEffect(.bounce, value: p)
            Text(badge.text).font(.headline).multilineTextAlignment(.center).foregroundStyle(.secondary)
            if p >= 1 {
                Label("¡Conseguido!", systemImage: "checkmark.seal.fill").font(.headline).foregroundStyle(Color(hex: badge.color))
            } else {
                ProgressView(value: p).tint(Color(hex: badge.color)).padding(.horizontal, 40)
                Text(sm.start == nil ? "Empieza el contador para ir a por él" : eta.map { "Lo consigues en \(SmokeText.duration($0))" } ?? "Llevas el \(Int(p * 100)) %")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(30)
        .presentationDetents([.height(340)])
    }
}

/// tarjeta pequeña para Hoy
struct SmokeMini: View {
    @Environment(Store.self) private var store
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { tl in
            let s = store.s.smoke
            HStack(spacing: 12) {
                Image(systemName: "wind").font(.system(size: 16, weight: .bold)).foregroundStyle(smokeGreen)
                    .frame(width: 34, height: 34).background(smokeGreen.opacity(0.18), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                if s.start == nil && s.measuring {
                    let today = s.log.filter { Day.str($0) == Day.str(tl.date) }.count
                    VStack(alignment: .leading, spacing: 1) {
                        Text(today == 1 ? "Hoy, 1 cigarro" : "Hoy, \(today) cigarros").font(.headline)
                        if let last = s.log.last {
                            Text("El último, hace \(SmokeText.duration(tl.date.timeIntervalSince(last)))").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button { Haptic.heavy(); withAnimation { store.s.smoke.log.append(Date()) } } label: {
                        Image(systemName: "plus").font(.headline.weight(.bold)).foregroundStyle(.black)
                            .frame(width: 38, height: 38).background(Color(hex: "#ff9f7a"), in: Circle())
                    }
                    .buttonStyle(PressableStyle())
                } else if s.start == nil {
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
            .contentShape(Rectangle())
            .onTapGesture { Haptic.tap(); Router.shared.open("humo") }
        }
        .card()
    }
}
