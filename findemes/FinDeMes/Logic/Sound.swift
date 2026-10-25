import UIKit
import AVFoundation

/// Vibración y sonidos. Todo se sintetiza al arrancar (sin archivos) y respeta el modo silencio.
@MainActor
final class Sound {
    static let shared = Sound()
    var on = true
    var haptics = true

    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let notify = UINotificationFeedbackGenerator()

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var busyUntil: [Double] = []
    private var lastPlayed: [String: Double] = [:]
    /// cada sonido no se repite antes de esto (si no, con muchas huchas se amontonan y se rayan)
    private let gap: [String: Double] = ["smash": 0.07, "coin": 0.06, "crack": 0.045, "pop": 0.09, "boom": 0.15, "swing": 0.04, "thud": 0.05]
    private var b: [String: [AVAudioPCMBuffer]] = [:]
    private var started = false
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        light.prepare(); heavy.prepare()
        // varias versiones de cada sonido para que no suene siempre igual
        b["crack"] = (0..<4).map { _ in crack() }
        b["smash"] = (0..<4).map { _ in smash() }
        b["coin"] = [1, 1.12, 1.26, 1.5].map { coin($0) }
        // escala que sube con el combo: cada rotura suena un poco más aguda
        for (i, k) in [1.0, 1.12, 1.26, 1.335, 1.5, 1.68, 1.89, 2.0].enumerated() { b["up\(i)"] = [coin(k)] }
        b["swing"] = (0..<3).map { _ in whoosh() }
        b["thud"] = [thud(70, noise: 0.25)]
        b["stamp"] = [thud(95, noise: 0.6)]
        b["boom"] = [boom()]
        b["till"] = [till()]
        b["pop"] = [pop()]
        b["click"] = [click()]
        b["fanfare"] = [fanfare()]
        b["sad"] = [sad()]
        // todo pasa por un mezclador propio y un limitador para que nunca sature
        let mix = AVAudioMixerNode()
        engine.attach(mix)
        let limiter = AVAudioUnitEffect(audioComponentDescription: AudioComponentDescription(
            componentType: kAudioUnitType_Effect, componentSubType: kAudioUnitSubType_PeakLimiter,
            componentManufacturer: kAudioUnitManufacturer_Apple, componentFlags: 0, componentFlagsMask: 0))
        engine.attach(limiter)
        engine.connect(mix, to: limiter, format: format)
        engine.connect(limiter, to: engine.mainMixerNode, format: format)
        mix.outputVolume = 0.75
        for _ in 0..<12 {
            let p = AVAudioPlayerNode()
            engine.attach(p)
            engine.connect(p, to: mix, format: format)
            players.append(p)
            busyUntil.append(0)
        }
    }

    func stop() { if started { engine.pause(); started = false } }

    private func play(_ name: String, volume: Float = 1) {
        guard on, let list = b[name], let buf = list.randomElement() else { return }
        if !started {
            do { try AVAudioSession.sharedInstance().setActive(true); try engine.start(); started = true } catch { return }
        }
        let now = CACurrentMediaTime()
        if let g = gap[name], now - (lastPlayed[name] ?? 0) < g { return }
        // una voz libre; si están todas sonando, no se corta ninguna (cortar a medias es lo que hace «clic»)
        guard let i = busyUntil.indices.first(where: { busyUntil[$0] <= now }) else { return }
        lastPlayed[name] = now
        busyUntil[i] = now + Double(buf.frameLength) / format.sampleRate + 0.02
        let p = players[i]
        p.stop()
        p.volume = volume
        p.scheduleBuffer(buf, at: nil, options: [])
        p.play()
    }

    // MARK: eventos

    func swing() { play("swing", volume: 0.5) }
    func miss() { play("thud", volume: 0.6); if haptics { soft.impactOccurred(intensity: 0.5) } }
    func hit(crit: Bool) {
        play("crack")
        if haptics { crit ? heavy.impactOccurred() : rigid.impactOccurred(intensity: 0.8) }
    }
    func smash(big: Bool, combo: Int = 0) {
        play("smash")
        if combo > 1 { play("up\(min(7, combo / 4))", volume: 0.75) } else { play("coin", volume: 0.7) }
        if haptics { heavy.impactOccurred(intensity: big ? 1 : 0.85) }
    }
    func boom() { play("boom"); if haptics { heavy.impactOccurred(intensity: 1) } }
    func coin() { play("coin", volume: 0.6) }
    func till() { play("till"); if haptics { notify.notificationOccurred(.success) } }
    func stamp() { play("stamp"); if haptics { heavy.impactOccurred() } }
    func pop() { play("pop", volume: 0.5) }
    func click() { play("click", volume: 0.7); if haptics { light.impactOccurred() } }
    func fanfare() { play("fanfare"); if haptics { notify.notificationOccurred(.success) } }
    func sad() { play("sad"); if haptics { notify.notificationOccurred(.error) } }
    func denied() { play("thud", volume: 0.5); if haptics { notify.notificationOccurred(.warning) } }

    // MARK: síntesis

    private func make(_ dur: Double, _ f: (Double, inout Double) -> Double) -> AVAudioPCMBuffer {
        let sr = format.sampleRate
        let n = AVAudioFrameCount(sr * dur)
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: n)!
        buf.frameLength = n
        let p = buf.floatChannelData![0]
        var state = 0.0
        for i in 0..<Int(n) { p[i] = Float(max(-1, min(1, f(Double(i) / sr, &state)))) }
        return buf
    }
    private func noise() -> Double { Double.random(in: -1...1) }

    /// grieta: chasquido corto y seco
    private func crack() -> AVAudioPCMBuffer {
        let f1 = Double.random(in: 1800...2600)
        return make(0.09) { t, lp in
            let n = noise()
            lp += (n - lp) * 0.55
            let env = exp(-t * 60)
            return (n - lp) * env * 0.55 + sin(2 * .pi * f1 * t) * exp(-t * 80) * 0.25
        }
    }
    /// cerámica rompiéndose: ruido + muchos tintineos agudos
    private func smash() -> AVAudioPCMBuffer {
        let tinks = (0..<9).map { _ in (Double.random(in: 2200...6200), Double.random(in: 0...0.16)) }
        return make(0.55) { t, lp in
            let n = noise()
            lp += (n - lp) * 0.25
            var v = lp * exp(-t * 14) * 0.8
            for (f, t0) in tinks where t >= t0 {
                let u = t - t0
                v += sin(2 * .pi * f * u) * exp(-u * 30) * 0.16
            }
            return v
        }
    }
    private func coin(_ k: Double) -> AVAudioPCMBuffer {
        make(0.32) { t, _ in
            let a = sin(2 * .pi * 2093 * k * t) + 0.6 * sin(2 * .pi * 3136 * k * t)
            let b2 = t > 0.07 ? (sin(2 * .pi * 2637 * k * (t - 0.07)) * exp(-(t - 0.07) * 14)) : 0
            return (a * exp(-t * 16) + b2) * 0.18
        }
    }
    private func whoosh() -> AVAudioPCMBuffer {
        make(0.16) { t, lp in
            let n = noise()
            let cut = 0.05 + 0.4 * (t / 0.16)
            lp += (n - lp) * cut
            return lp * sin(.pi * t / 0.16) * 0.35
        }
    }
    private func thud(_ f: Double, noise amount: Double) -> AVAudioPCMBuffer {
        make(0.25) { t, lp in
            let n = noise()
            lp += (n - lp) * 0.08
            return (sin(2 * .pi * f * t * (1 - t)) * 0.8 + lp * amount) * exp(-t * 18)
        }
    }
    private func boom() -> AVAudioPCMBuffer {
        make(0.9) { t, lp in
            let n = noise()
            lp += (n - lp) * 0.04
            return (lp * 2.2 + sin(2 * .pi * 55 * t) * 0.6) * exp(-t * 5)
        }
    }
    private func till() -> AVAudioPCMBuffer {
        make(0.9) { t, _ in
            var v = 0.0
            for (i, f) in [1568.0, 2093, 2637].enumerated() {
                let u = t - Double(i) * 0.05
                if u > 0 { v += sin(2 * .pi * f * u) * exp(-u * 10) }
            }
            let bell = t > 0.22 ? sin(2 * .pi * 3520 * (t - 0.22)) * exp(-(t - 0.22) * 5) * 0.8 : 0
            return (v + bell) * 0.16
        }
    }
    private func pop() -> AVAudioPCMBuffer {
        make(0.08) { t, _ in sin(2 * .pi * (500 + 2500 * t) * t) * exp(-t * 40) * 0.3 }
    }
    private func click() -> AVAudioPCMBuffer {
        make(0.05) { t, _ in sin(2 * .pi * 1400 * t) * exp(-t * 120) * 0.35 }
    }
    private func fanfare() -> AVAudioPCMBuffer {
        let notes: [Double] = [523, 659, 784, 1047, 784, 1047]
        return make(1.1) { t, _ in
            var v = 0.0
            for (i, f) in notes.enumerated() {
                let u = t - Double(i) * 0.11
                guard u >= 0 else { continue }
                v += (sin(2 * .pi * f * u) + 0.3 * sin(4 * .pi * f * u)) * exp(-u * 6)
            }
            return v * 0.12
        }
    }
    private func sad() -> AVAudioPCMBuffer {
        let notes: [Double] = [392, 370, 349, 262]
        return make(1.3) { t, _ in
            var v = 0.0
            for (i, f) in notes.enumerated() {
                let u = t - Double(i) * 0.25
                guard u >= 0 else { continue }
                v += sin(2 * .pi * f * u + 2 * sin(2 * .pi * 5 * u)) * exp(-u * (i == 3 ? 2 : 5))
            }
            return v * 0.14
        }
    }
}

/// música de ascensor de fondo, en bucle infinito (cuatro temas de Kevin MacLeod, CC BY 4.0; el crédito va en Ajustes)
@MainActor
final class Music {
    static let shared = Music()
    private var player: AVAudioPlayer?
    var on = true { didSet { on ? resume() : pause() } }

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        guard let url = Bundle.main.url(forResource: "ascensor", withExtension: "m4a") else { return }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.numberOfLoops = -1
        player?.volume = 0.32
        player?.prepareToPlay()
    }

    func resume() {
        guard on, let p = player, !p.isPlaying else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        p.play()
    }
    func pause() { player?.pause() }
}
