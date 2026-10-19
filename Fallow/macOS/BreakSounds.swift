import AVFoundation

/// The two transition tones. Into the break starts with the hold and keeps
/// playing as rest opens. Out of the break starts as the screen returns.
@MainActor
final class BreakSounds {
    private var opening: AVAudioPlayer?
    private var intoBreak: AVAudioPlayer?
    private var outOfBreak: AVAudioPlayer?
    private var holding = false
    private var fade: Task<Void, Never>?

    func open() {
        opening?.stop()
        opening = player(named: "AuraWoosh")
        opening?.play()
    }

    func beginHold() {
        guard !holding else { return }
        holding = true
        fade?.cancel()
        opening?.stop()
        opening = nil
        intoBreak?.stop()
        outOfBreak?.stop()
        outOfBreak = nil
        intoBreak = player(named: "AuraTransition")
        intoBreak?.play()
    }

    func cancelHold() {
        guard holding else { return }
        holding = false
        fadeOut(intoBreak)
    }

    func returnFromBreak() {
        holding = false
        fade?.cancel()
        intoBreak?.stop()
        intoBreak = nil
        guard outOfBreak?.isPlaying != true else { return }
        outOfBreak = player(named: "MagicalAura")
        outOfBreak?.play()
    }

    func stopAll() {
        holding = false
        fade?.cancel()
        opening?.stop()
        opening = nil
        intoBreak?.stop()
        intoBreak = nil
        outOfBreak?.stop()
        outOfBreak = nil
    }

    private func player(named name: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return nil }
        #if os(iOS)
        // Voice capture leaves the session record-only. Ambient mixes with other audio and follows the silent switch.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient)
        try? session.setActive(true)
        #endif
        let player = try? AVAudioPlayer(contentsOf: url)
        player?.volume = 1
        player?.prepareToPlay()
        return player
    }

    private func fadeOut(_ player: AVAudioPlayer?) {
        fade?.cancel()
        fade = Task { @MainActor in
            let start = player?.volume ?? 0
            for step in 1...8 {
                if Task.isCancelled { return }
                player?.volume = start * (1 - Float(step) / 8)
                try? await Task.sleep(nanoseconds: 24_000_000)
            }
            player?.stop()
            if intoBreak === player { intoBreak = nil }
        }
    }
}
