import AVFoundation
import Foundation

/// Synthesises all game sounds in-memory — no audio files needed.
/// Uses AVAudioEngine with a mixer, reverb, and per-sound player nodes.
final class AudioManager {
    static let shared = AudioManager()

    private let engine   = AVAudioEngine()
    private let mixer    = AVAudioMixerNode()
    private let reverb   = AVAudioUnitReverb()

    // Dedicated player nodes so simultaneous playback never cuts each other
    private let flapNode  = AVAudioPlayerNode()
    private let scoreNode = AVAudioPlayerNode()
    private let crashNode = AVAudioPlayerNode()
    private let bgNode    = AVAudioPlayerNode()

    private let sampleRate: Double = 44_100
    private var isRunning = false

    /// Persisted mute state — when true, all playback is silenced.
    var isMuted: Bool {
        get { UserDefaults.standard.bool(forKey: "cd.audioMuted") }
        set { UserDefaults.standard.set(newValue, forKey: "cd.audioMuted") }
    }

    // MARK: - Init
    private init() {
        setupSession()
        setupEngine()
    }

    private func setupSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    private func setupEngine() {
        // Attach all nodes
        for node in [flapNode, scoreNode, crashNode, bgNode] as [AVAudioNode] {
            engine.attach(node)
        }
        engine.attach(mixer)
        engine.attach(reverb)

        reverb.loadFactoryPreset(.smallRoom)
        reverb.wetDryMix = 22

        let fmt = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

        // Connect players → mixer → reverb → main mixer
        for node in [flapNode, scoreNode, crashNode, bgNode] as [AVAudioNode] {
            engine.connect(node, to: mixer, format: fmt)
        }
        engine.connect(mixer, to: reverb, format: fmt)
        engine.connect(reverb, to: engine.mainMixerNode, format: fmt)

        engine.prepare()
        try? engine.start()
        isRunning = engine.isRunning
    }

    // MARK: - Public API

    func playFlap() {
        guard isRunning, !isMuted else { return }
        let buf = buildFlap()
        flapNode.stop()
        flapNode.scheduleBuffer(buf, completionHandler: nil)
        flapNode.play()
    }

    func playScore() {
        guard isRunning, !isMuted else { return }
        let buf = buildScore()
        scoreNode.stop()
        scoreNode.scheduleBuffer(buf, completionHandler: nil)
        scoreNode.play()
    }

    func playCrash() {
        guard isRunning, !isMuted else { return }
        let buf = buildCrash()
        crashNode.stop()
        crashNode.scheduleBuffer(buf, completionHandler: nil)
        crashNode.play()
    }

    // MARK: - Sound synthesis helpers

    /// Whoosh: short band-pass filtered white noise with quick attack/decay
    private func buildFlap() -> AVAudioPCMBuffer {
        let duration = 0.14
        let frames   = AVAudioFrameCount(sampleRate * duration)
        let format   = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buf      = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buf.frameLength = frames

        let data = buf.floatChannelData![0]
        let attackFrames  = Int(Double(frames) * 0.12)
        let decayFrames   = Int(Double(frames) * 0.88)

        // Band-pass centre ~900 Hz via simple IIR
        var y1: Float = 0, y2: Float = 0
        let fc: Float  = 900 / Float(sampleRate)
        let bw: Float  = 0.06
        let r: Float   = 1 - .pi * bw
        let k: Float   = r * r
        let cosW: Float = (1 + k) / 2 * cos(2 * .pi * fc) * 2
        let a0: Float  = 1 - k
        let b1: Float  = -cosW
        let b2: Float  = k

        for i in 0..<Int(frames) {
            let noise = Float.random(in: -1...1)
            // Envelope
            let env: Float
            if i < attackFrames {
                env = Float(i) / Float(attackFrames)
            } else {
                let t = Float(i - attackFrames) / Float(decayFrames)
                env = expf(-4.5 * t)
            }
            // Filter
            let x = noise * env * 0.55
            let y = a0 * x - b1 * y1 - b2 * y2
            y2 = y1; y1 = y
            data[i] = y
        }
        return buf
    }

    /// Ding: two sine partials (fundamental + octave) with gentle exponential decay
    private func buildScore() -> AVAudioPCMBuffer {
        let duration = 0.38
        let frames   = AVAudioFrameCount(sampleRate * duration)
        let format   = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buf      = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buf.frameLength = frames

        let data  = buf.floatChannelData![0]
        let f1: Double = 1046.5  // C6
        let f2: Double = 1318.5  // E6
        let f3: Double = 1568.0  // G6 (triad)
        let decay: Double = 6.5

        for i in 0..<Int(frames) {
            let t  = Double(i) / sampleRate
            let env = exp(-decay * t)
            let s1  = sin(2 * .pi * f1 * t)
            let s2  = sin(2 * .pi * f2 * t) * 0.65
            let s3  = sin(2 * .pi * f3 * t) * 0.40
            // Small click suppressor at very start
            let attack: Double = min(1.0, t / 0.006)
            data[i] = Float((s1 + s2 + s3) * env * attack * 0.42)
        }
        return buf
    }

    /// Crash: layered impact — low sine thud + high-freq noise burst + rumble tail
    private func buildCrash() -> AVAudioPCMBuffer {
        let duration = 0.70
        let frames   = AVAudioFrameCount(sampleRate * duration)
        let format   = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buf      = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buf.frameLength = frames

        let data = buf.floatChannelData![0]

        // Layer 1: low sine "thud" — exponential pitch drop 120→40 Hz
        // Layer 2: noise burst for impact transient
        // Layer 3: slow decay rumble noise

        var filterState: Float = 0

        for i in 0..<Int(frames) {
            let t  = Double(i) / sampleRate

            // Thud: sweeping sine from 140 → 48 Hz
            let freq  = 140.0 * exp(-8.0 * t) + 48.0
            let phase = 2 * Double.pi * freq * t
            let thud  = sin(phase) * exp(-5.0 * t) * 0.80

            // Impact noise burst (very short)
            let noiseBurst = Double(Float.random(in: -1...1)) * exp(-35.0 * t) * 0.55

            // Rumble: low-pass filtered noise
            let rawNoise  = Float.random(in: -1...1)
            let lpAlpha: Float = 0.04
            filterState += lpAlpha * (rawNoise - filterState)
            let rumble    = Double(filterState) * exp(-3.0 * t) * 0.38

            let attack = min(1.0, t / 0.003)
            data[i] = Float((thud + noiseBurst + rumble) * attack)
        }
        // Final clip guard
        for i in 0..<Int(frames) {
            data[i] = max(-1.0, min(1.0, data[i]))
        }
        return buf
    }
}
