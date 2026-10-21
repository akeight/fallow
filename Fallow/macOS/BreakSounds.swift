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

    /// The return hold ended early. The exit tone fades instead of finishing.
    func cancelReturn() {
        fadeOut(outOfBreak)
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
        prepareSession()
        let player = try? AVAudioPlayer(contentsOf: url)
        player?.volume = volume(named: name)
        player?.prepareToPlay()
        return player
    }

    /// Playback follows the media volume and mixes with other audio. Ambient stays silent under
    /// the phone's ringer switch, which the simulator does not have. Voice capture also leaves
    /// the session record-only, and that category cannot play until it is switched back.
    private func prepareSession() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        let ready = session.category == .playback
            && session.mode == .default
            && session.categoryOptions.contains(.mixWithOthers)
        if !ready {
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        }
        try? session.setActive(true)
        #endif
    }

    /// Relative to full playback. Shared level is a quarter of full, then another tenth quieter.
    /// The hold and return files are louder, so they sit lower still.
    private func volume(named name: String) -> Float {
        let shared: Float = 0.25 * 0.9
        switch name {
        case "AuraTransition": return shared * 0.3
        case "MagicalAura": return shared * 0.35
        default: return shared
        }
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
            if outOfBreak === player { outOfBreak = nil }
        }
    }
}
