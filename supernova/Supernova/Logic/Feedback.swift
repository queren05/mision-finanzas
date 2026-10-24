import UIKit
import AVFoundation

/// Vibración y sonidos. Los sonidos se sintetizan al arrancar (no hace falta ningún archivo de audio)
/// y respetan el interruptor de silencio del iPhone.
@MainActor
final class Feedback {
    static let shared = Feedback()

    var sound = true
    var haptics = true

    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let notify = UINotificationFeedbackGenerator()
    private let select = UISelectionFeedbackGenerator()

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var next = 0
    private var buffers: [String: AVAudioPCMBuffer] = [:]
    private var tapPitches: [AVAudioPCMBuffer] = []
    private var started = false
    private var lastTapSound = Date.distantPast
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!

    private init() {
        light.prepare(); medium.prepare()
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        // toques: una escala que sube con el combo
        let scale: [Double] = [523, 587, 659, 784, 880, 988, 1047, 1175]
        tapPitches = scale.map { tone([$0, $0 * 2], dur: 0.07, vol: 0.18) }
        buffers["crit"] = tone([880, 1320, 1760], dur: 0.22, vol: 0.22)
        buffers["buy"] = sweep(from: 420, to: 980, dur: 0.11, vol: 0.2)
        buffers["upgrade"] = seq([659, 880, 1319], step: 0.06, vol: 0.2)
        buffers["achievement"] = seq([523, 659, 784, 1047, 1319], step: 0.075, vol: 0.22)
        buffers["star"] = seq([1568, 2093, 2637, 3136], step: 0.045, vol: 0.16)
        buffers["bigbang"] = sweep(from: 1200, to: 60, dur: 0.9, vol: 0.3)
        buffers["error"] = tone([180], dur: 0.09, vol: 0.18)
        for _ in 0..<6 {
            let p = AVAudioPlayerNode()
            engine.attach(p)
            engine.connect(p, to: engine.mainMixerNode, format: format)
            players.append(p)
        }
    }

    private func ensureStarted() {
        guard !started else { return }
        do { try AVAudioSession.sharedInstance().setActive(true); try engine.start(); started = true } catch { started = false }
    }

    func stopAudio() {
        guard started else { return }
        engine.pause(); started = false
    }

    private func play(_ b: AVAudioPCMBuffer?) {
        guard sound, let b else { return }
        ensureStarted()
        guard started else { return }
        let p = players[next]; next = (next + 1) % players.count
        p.stop()
        p.scheduleBuffer(b, at: nil, options: [])
        p.play()
    }

    // MARK: eventos del juego

    func tap(combo: Double, crit: Bool) {
        if haptics {
            if crit { heavy.impactOccurred() } else { light.impactOccurred(intensity: min(1, 0.5 + (combo - 1) * 0.5)) }
        }
        if crit { play(buffers["crit"]); return }
        // no saturar si se toca muy rápido
        let now = Date()
        guard now.timeIntervalSince(lastTapSound) > 0.045 else { return }
        lastTapSound = now
        let i = min(tapPitches.count - 1, Int((combo - 1) / 0.13))
        play(tapPitches[i])
    }
    func buy() { if haptics { medium.impactOccurred() }; play(buffers["buy"]) }
    func upgrade() { if haptics { rigid.impactOccurred() }; play(buffers["upgrade"]) }
    func achievement() { if haptics { notify.notificationOccurred(.success) }; play(buffers["achievement"]) }
    func star() { if haptics { heavy.impactOccurred(); notify.notificationOccurred(.success) }; play(buffers["star"]) }
    func bigBang() { if haptics { heavy.impactOccurred(intensity: 1) }; play(buffers["bigbang"]) }
    func denied() { if haptics { notify.notificationOccurred(.warning) }; play(buffers["error"]) }
    func tick() { if haptics { select.selectionChanged() } }

    // MARK: síntesis

    private func makeBuffer(_ dur: Double, _ sample: (Double) -> Double) -> AVAudioPCMBuffer {
        let sr = format.sampleRate
        let n = AVAudioFrameCount(sr * dur)
        let b = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: n)!
        b.frameLength = n
        let p = b.floatChannelData![0]
        for i in 0..<Int(n) { p[i] = Float(sample(Double(i) / sr)) }
        return b
    }

    private func tone(_ freqs: [Double], dur: Double, vol: Double) -> AVAudioPCMBuffer {
        makeBuffer(dur) { t in
            let env = exp(-t * 7 / dur) * min(1, t * 600)
            var v = 0.0
            for (k, f) in freqs.enumerated() { v += sin(2 * .pi * f * t) / Double(k + 1) }
            return v * env * vol
        }
    }

    private func sweep(from a: Double, to b: Double, dur: Double, vol: Double) -> AVAudioPCMBuffer {
        makeBuffer(dur) { t in
            let k = (b - a) / dur
            let phase = 2 * .pi * (a * t + k * t * t / 2)
            let env = exp(-t * 4 / dur) * min(1, t * 400)
            return (sin(phase) + 0.3 * sin(phase * 2)) * env * vol
        }
    }

    private func seq(_ notes: [Double], step: Double, vol: Double) -> AVAudioPCMBuffer {
        let dur = step * Double(notes.count) + 0.25
        return makeBuffer(dur) { t in
            var v = 0.0
            for (i, f) in notes.enumerated() {
                let t0 = t - Double(i) * step
                guard t0 >= 0 else { continue }
                let env = exp(-t0 * 9) * min(1, t0 * 600)
                v += (sin(2 * .pi * f * t0) + 0.4 * sin(4 * .pi * f * t0)) * env
            }
            return v * vol * 0.6
        }
    }
}
