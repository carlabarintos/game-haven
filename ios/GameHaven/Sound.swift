import AVFoundation

/// Soft chimes made in code, so there are no sound files to ship.
/// Ambient audio: the iPhone's silent switch mutes them, and the player's own music keeps playing.
enum Sound {
    /// A move that went in, a wrong try, and a finished game.
    case tap, miss, win

    fileprivate static let rate = 44_100.0
    fileprivate static let engine = AVAudioEngine()
    private static let player = AVAudioPlayerNode()
    fileprivate static let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)!
    private static let buffers: [Sound: AVAudioPCMBuffer] = [
        .tap: chime([(880, 0)], length: 0.18, decay: 22),
        .miss: chime([(330, 0), (262, 0.09)], length: 0.35, decay: 12),  // a low, gentle "uh-uh", not a buzzer
        .win: chime([(523, 0), (659, 0.12), (784, 0.24), (1047, 0.36)], length: 1.2, decay: 4),
    ]
    fileprivate static let ready: Bool = {
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        for node in [player, Music.player] {
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
        }
        Music.player.volume = 0.5
        return true
    }()

    /// Starts the engine if needed, e.g. after a phone call or Siri stopped it.
    fileprivate static func running() -> Bool {
        guard ready else { return false }
        return engine.isRunning || (try? engine.start()) != nil
    }

    /// Plays the sound unless the player turned sounds off. A new sound cuts off the one before.
    func play() {
        guard AppSettings.soundOn, let buffer = Self.buffers[self], Self.running() else { return }
        Self.player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        Self.player.play()
    }

    /// Sine notes (hertz, start in seconds) that fade out, with a tiny fade-in so they don't click.
    private static func chime(_ notes: [(Double, Double)], length: Double, decay: Double) -> AVAudioPCMBuffer {
        let count = AVAudioFrameCount(length * rate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count)!
        buffer.frameLength = count
        let out = buffer.floatChannelData![0]
        for n in 0..<Int(count) {
            let t = Double(n) / rate
            out[n] = Float(notes.reduce(0.0) { sum, note in
                let s = t - note.1
                guard s >= 0 else { return sum }
                return sum + sin(2 * .pi * note.0 * s) * exp(-decay * s) * min(1, s / 0.005)
            } * 0.2)
        }
        return buffer
    }
}

/// Quiet background music, also made in code: a slow loop of four chords with a few bell notes drifting over it.
/// The same seed every time, so the tune grows familiar instead of changing each launch.
enum Music {
    fileprivate static let player = AVAudioPlayerNode()
    private static var loop: AVAudioPCMBuffer?
    private static var rendering = false
    /// While a full-screen ad has its own sound.
    static var paused = false { didSet { paused ? player.pause() : start() } }

    /// Plays if music is on. Safe to call again, e.g. each time the app comes back to the front.
    static func start() {
        guard AppSettings.musicOn, !paused else { return }
        guard let loop else {
            guard !rendering else { return }
            rendering = true
            Task.detached(priority: .utility) {  // about a second of maths; keep it off the main thread
                let samples = render()
                await MainActor.run {
                    let buffer = AVAudioPCMBuffer(pcmFormat: Sound.format, frameCapacity: AVAudioFrameCount(samples.count))!
                    buffer.frameLength = buffer.frameCapacity
                    samples.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count) }
                    loop = buffer
                    start()
                }
            }
            return
        }
        guard !player.isPlaying, Sound.running() else { return }
        player.scheduleBuffer(loop, at: nil, options: .loops)
        player.play()
    }

    static func stop() { player.stop() }

    /// C, A minor, F, G, twice over, eight seconds each: a soft pad, plus bell notes from the chord on some beats.
    /// Notes that ring past the end wrap to the start, so the loop has no seam.
    nonisolated private static func render() -> [Float] {
        let rate = 44_100.0, chordLength = 8.0
        let chords: [[Int]] = [[48, 60, 64, 67], [45, 57, 60, 64], [41, 57, 60, 65], [43, 59, 62, 67]]
        let total = Int(rate * chordLength * Double(chords.count * 2))
        var out = [Float](repeating: 0, count: total)
        var random = SplitMix64(seed: 7)
        func hz(_ midi: Int) -> Double { 440 * pow(2, Double(midi - 69) / 12) }
        func add(_ f: Double, at start: Double, length: Double, _ level: (Double) -> Double) {
            let from = Int(start * rate)
            for n in 0..<Int(length * rate) {
                let t = Double(n) / rate
                out[((from + n) % total + total) % total] += Float(sin(2 * .pi * f * t) * level(t))
            }
        }
        for bar in 0..<chords.count * 2 {
            let chord = chords[bar % chords.count], start = Double(bar) * chordLength
            for midi in chord {  // swells in and out over ten seconds, overlapping the next chord; two slightly apart tones shimmer
                for detune in [-0.4, 0.4] {
                    add(hz(midi) + detune, at: start - 1, length: chordLength + 2) { 0.035 * pow(sin(.pi * $0 / (chordLength + 2)), 2) }
                }
            }
            for beat in 0..<Int(chordLength) where Double.random(in: 0..<1, using: &random) < 0.4 {
                let f = hz(chord[1...].randomElement(using: &random)! + 12)
                add(f, at: start + Double(beat), length: 3) { 0.1 * exp(-2 * $0) * min(1, $0 / 0.01) }
                add(f * 2, at: start + Double(beat), length: 1.5) { 0.02 * exp(-4 * $0) * min(1, $0 / 0.01) }  // a little ring on top, like a bell
            }
        }
        return out
    }
}
