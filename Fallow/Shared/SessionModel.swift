import Foundation
import Observation

enum BreakCue {
    /// The quiet orb was tapped to begin.
    case open
    /// Press-and-hold begins the break.
    case into
    /// The hold was released before it completed.
    case cancel
    /// The screen is returning to normal.
    case out
    /// The return hold was let go before it finished, so the exit tone stops.
    case cancelOut
    /// The session was left before the return finished.
    case stop
}

@MainActor
@Observable
final class SessionModel {
    var phase: OrbPhase = .dormant
    /// The Mac's session record. The orb phase above is only how it is being shown.
    var current = FallowSession(originDevice: .mac, phase: .dormant) {
        didSet { persist() }
    }
    /// Raw recession, 0 through 1. The veil shapes this; it is not pre-curved.
    var softness: Double = 0
    var showsLens = false
    var holdDuration = 1.8
    var reentryDuration = 0.9
    /// How long the orb is held to leave a return, matching the iPhone.
    var returnHoldDuration = 2.5
    /// 0 until the return orb is held, then the fraction of that hold. Stays full through the way back.
    var returnHold = 0.0
    /// Smoothed microphone level, 0 through 1.
    var voiceLevel = 0.0
    /// The microphone is open. Under Reduce Motion the orb holds a still gather instead of following the level.
    var isListening = false
    /// Increments only when a hold completes, so an early release never settles.
    var settleID = 0
    /// Increments when the return entrance should play again.
    var returnID = 0
    /// The interpreter's last answer for this capture, or nil when it failed or has not run.
    var interpretation: FallowInterpretation?
    /// A typed thought is being read before the state choice.
    var isInterpreting = false
    /// Mac playback. Ignored by observation so assigning it does not refresh the UI.
    @ObservationIgnored var breakCue: ((BreakCue) -> Void)?
    @ObservationIgnored private let sync: (any FallowSyncing)?
    @ObservationIgnored private let interpreter: any FallowInterpreting
    /// Bumped on every new interpretation or exit, so a late answer never lands on the wrong capture.
    @ObservationIgnored private var interpretID = 0

    private var pressing = false
    private var returnPressing = false
    private var holdTask: Task<Void, Never>?
    private var returnHoldTask: Task<Void, Never>?
    private var lensTask: Task<Void, Never>?
    private var returnTask: Task<Void, Never>?
    private var releaseTask: Task<Void, Never>?

    /// Without a sync service the session stays on this device, as the iPhone's orb does.
    init(sync: (any FallowSyncing)? = nil, interpreter: any FallowInterpreting = FallowInterpreterFactory.make()) {
        self.sync = sync
        self.interpreter = interpreter
    }

    var thought: String {
        get { current.unresolvedThought }
        set { current.unresolvedThought = newValue }
    }

    var creativeState: CreativeState? { current.creativeState }
    var distance: FallowDistance? { current.distance }

    var reflection: String {
        get { current.returnedThought ?? "" }
        set { current.returnedThought = newValue.isEmpty ? nil : newValue }
    }

    /// What the rest offers, or nil when FALLOW should stay quiet.
    var restLine: String? { current.intervention?.line }

    var holdAmount: Double {
        if case .holding(let progress) = phase { return progress }
        if case .threshold = phase { return softness }
        return softness
    }

    func tapOrb() {
        switch phase {
        case .dormant:
            breakCue?(.open)
            current = FallowSession(originDevice: .mac)
            interpretation = nil
            phase = .capture
        case .resting where !showsLens:
            current.requestReturn()
            phase = .returnDoorway
        default:
            break
        }
    }

    /// Keeps the whole note and places its concise thought in the card for editing.
    func captureVoice(raw: String, distilled: String?) {
        current.captureVoice(raw: raw, distilled: distilled)
        current.phase = .capturing
    }

    /// Reads a spoken note, then keeps the whole note and carries the distilled thread,
    /// or the note itself if reading failed. Waits at least `minimum` so gathering never flickers.
    func carryVoice(_ raw: String, minimum: TimeInterval = 0.6) async {
        interpretID += 1
        let id = interpretID
        let started = Date()
        let result = try? await interpreter.interpret(text: raw)
        let elapsed = Date().timeIntervalSince(started)
        if elapsed < minimum {
            try? await Task.sleep(nanoseconds: UInt64((minimum - elapsed) * 1_000_000_000))
        }
        guard id == interpretID, phase == .capture else { return }
        interpretation = result
        captureVoice(raw: raw, distilled: result?.distilledThought)
    }

    /// Drops any answer still on its way, e.g. when listening is cancelled mid-gather.
    func cancelInterpretation() {
        interpretID += 1
        isInterpreting = false
    }

    func captureText(_ text: String) {
        current.captureText(text)
        current.phase = .capturing
    }

    /// A spoken note was already read while gathering. Typed words are kept exactly as written
    /// and only classified. If reading fails, the state choice opens with nothing suggested.
    func confirmThought() {
        let text = thought.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isInterpreting, phase == .capture else { return }
        guard current.captureMethod == .text else {
            classify(text, interpretation: interpretation)
            return
        }
        interpretID += 1
        let id = interpretID
        isInterpreting = true
        Task { @MainActor in
            let result = try? await interpreter.interpret(text: text)
            guard id == interpretID, phase == .capture else { return }
            isInterpreting = false
            classify(text, interpretation: result)
        }
    }

    private func classify(_ text: String, interpretation result: FallowInterpretation?) {
        current.confirmCapture(text)
        current.applyInterpretation(result)
        interpretation = result
        phase = .classifyStuck
    }

    func chooseState(_ state: CreativeState) {
        current.choose(state)
        phase = .chooseDistance
    }

    func chooseDistance(_ kind: FallowDistance) {
        current.choose(kind)
        softness = 0
        phase = .threshold
    }

    func pressHold() {
        guard !pressing else { return }
        switch phase {
        case .threshold, .holding:
            break
        default:
            return
        }
        pressing = true
        current.beginRelease()
        breakCue?(.into)
        releaseTask?.cancel()
        let duration = max(0.2, holdDuration)
        let start = Date()
        holdTask?.cancel()
        holdTask = Task { @MainActor in
            while !Task.isCancelled && pressing {
                let progress = min(1, Date().timeIntervalSince(start) / duration)
                phase = .holding(progress: progress)
                softness = progress
                if progress >= 1 {
                    finishHold()
                    break
                }
                try? await Task.sleep(nanoseconds: 16_000_000)
            }
        }
    }

    func releaseHold() {
        guard pressing || isHolding else { return }
        pressing = false
        holdTask?.cancel()
        holdTask = nil
        guard case .holding(let progress) = phase else { return }
        if progress >= 0.98 {
            finishHold()
        } else {
            breakCue?(.cancel)
            current.cancelRelease()
            let from = progress
            phase = .threshold
            releaseTask?.cancel()
            releaseTask = Task { @MainActor in
                let duration = 0.45
                let start = Date()
                while !Task.isCancelled {
                    guard case .threshold = phase else { return }
                    let t = min(1, Date().timeIntervalSince(start) / duration)
                    let eased = t * t * (3 - 2 * t)
                    softness = from * (1 - eased)
                    if t >= 1 {
                        softness = 0
                        return
                    }
                    try? await Task.sleep(nanoseconds: 16_000_000)
                }
            }
        }
    }

    func confirmReflection() {
        let text = reflection.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        current.recordShift(text)
        phase = .beforeAfter
    }

    /// Holding the return orb. Letting go early eases it back; finishing it leaves the return.
    func pressReturn() {
        guard phase == .beforeAfter, !returnPressing else { return }
        returnPressing = true
        breakCue?(.out)
        returnHoldTask?.cancel()
        let duration = max(0.2, returnHoldDuration)
        let start = Date()
        let from = returnHold
        returnHoldTask = Task { @MainActor in
            while !Task.isCancelled && returnPressing {
                let t = min(1, Date().timeIntervalSince(start) / duration)
                returnHold = from + (1 - from) * t
                if returnHold >= 0.995 {
                    finishReturn()
                    return
                }
                try? await Task.sleep(nanoseconds: 16_000_000)
            }
        }
    }

    func releaseReturn() {
        guard returnPressing else { return }
        returnPressing = false
        returnHoldTask?.cancel()
        returnHoldTask = nil
        guard phase == .beforeAfter else { return }
        if returnHold >= 0.98 {
            finishReturn()
        } else {
            breakCue?(.cancelOut)
            easeReturnHold(to: 0)
        }
    }

    /// The hold completed, or VoiceOver asked for it.
    func finishReturn() {
        guard phase == .beforeAfter else { return }
        returnPressing = false
        returnHoldTask?.cancel()
        returnHoldTask = nil
        returnHold = 1
        goBackIn()
    }

    func goBackIn() {
        guard phase == .beforeAfter else { return }
        current.beginReentry()
        phase = .reentering
        breakCue?(.out)
        returnTask?.cancel()
        let duration = max(0.2, reentryDuration)
        returnTask = Task { @MainActor in
            let steps = max(8, Int(duration / 0.016))
            for step in 0...steps {
                if Task.isCancelled { return }
                softness = 1 - Double(step) / Double(steps)
                try? await Task.sleep(nanoseconds: 16_000_000)
            }
            showsLens = false
            current.complete()
            phase = .dormant
            softness = 0
            returnHold = 0
        }
    }

    private func easeReturnHold(to target: Double) {
        let from = returnHold
        returnHoldTask?.cancel()
        returnHoldTask = Task { @MainActor in
            let duration = 0.45
            let start = Date()
            while !Task.isCancelled {
                guard phase == .beforeAfter, !returnPressing else { return }
                let t = min(1, Date().timeIntervalSince(start) / duration)
                let eased = t * t * (3 - 2 * t)
                returnHold = from + (target - from) * eased
                if t >= 1 { return }
                try? await Task.sleep(nanoseconds: 16_000_000)
            }
        }
    }

    func showPreview(_ phase: OrbPhase) {
        cancelMotion()
        switch phase {
        case .dormant:
            softness = 0
            showsLens = false
            self.phase = .dormant
        case .capture:
            thought = DemoCopy.unresolved
            softness = 0
            showsLens = false
            self.phase = .capture
        case .classifyStuck:
            softness = 0
            showsLens = false
            self.phase = .classifyStuck
        case .chooseDistance:
            softness = 0
            showsLens = false
            self.phase = .chooseDistance
        case .threshold:
            softness = 0
            showsLens = false
            self.phase = .threshold
        case .holding(let progress):
            softness = progress
            showsLens = false
            self.phase = .holding(progress: progress)
        case .resting:
            softness = 1
            showsLens = false
            self.phase = .resting
        case .returnDoorway:
            if thought.isEmpty { thought = DemoCopy.unresolved }
            softness = 1
            showsLens = false
            self.phase = .returnDoorway
            returnID += 1
        case .reflecting:
            if thought.isEmpty { thought = DemoCopy.unresolved }
            softness = 1
            showsLens = false
            self.phase = .reflecting
        case .beforeAfter:
            if thought.isEmpty { thought = DemoCopy.unresolved }
            if reflection.isEmpty { reflection = DemoCopy.reflection }
            softness = 1
            showsLens = false
            self.phase = .beforeAfter
        case .reentering:
            softness = 0.45
            showsLens = false
            self.phase = .reentering
        }
    }

    func finishHold() {
        enterRest()
    }

    /// Applies a session that changed on another device, through the same motion the Mac uses itself.
    /// A thought already resting here keeps the person's own words.
    func receive(_ session: FallowSession?) {
        switch session?.phase {
        case .resting:
            guard let session, !current.isAway else { return }
            current = session
            settle()
        case .returnRequested:
            guard let session else { return }
            switch phase {
            case .returnDoorway, .reflecting, .beforeAfter:
                return
            default:
                break
            }
            if current.phase == .resting {
                current.requestReturn()
            } else {
                current = session
            }
            if phase != .resting {
                cancelMotion()
                easeSoftness(to: 1, duration: 0.9)
            }
            showsLens = false
            phase = .returnDoorway
        default:
            if phase == .dormant {
                if current.phase != .dormant { current = FallowSession(originDevice: .mac, phase: .dormant) }
            } else {
                leave()
            }
        }
    }

    /// Leaves the current step and returns to the quiet orb. The veil clears with it.
    func leave() {
        guard phase != .dormant else { return }
        breakCue?(.stop)
        cancelMotion()
        showsLens = false
        current = FallowSession(originDevice: .mac, phase: .dormant)
        let from = softness
        phase = .dormant
        guard from > 0.01 else {
            softness = 0
            return
        }
        returnTask = Task { @MainActor in
            let duration = 0.45
            let start = Date()
            while !Task.isCancelled {
                guard phase == .dormant else { return }
                let t = min(1, Date().timeIntervalSince(start) / duration)
                let eased = t * t * (3 - 2 * t)
                softness = from * (1 - eased)
                if t >= 1 {
                    softness = 0
                    return
                }
                try? await Task.sleep(nanoseconds: 16_000_000)
            }
        }
    }

    private func cancelMotion() {
        interpretID += 1
        isInterpreting = false
        pressing = false
        returnPressing = false
        returnHold = 0
        holdTask?.cancel()
        holdTask = nil
        returnHoldTask?.cancel()
        returnHoldTask = nil
        releaseTask?.cancel()
        releaseTask = nil
        lensTask?.cancel()
        lensTask = nil
        returnTask?.cancel()
        returnTask = nil
    }

    private var isHolding: Bool {
        if case .holding = phase { return true }
        return false
    }

    private func enterRest() {
        pressing = false
        holdTask?.cancel()
        holdTask = nil
        releaseTask?.cancel()
        releaseTask = nil
        settleID += 1
        current.markReleased()
        phase = .resting
        softness = 1
        showLensBriefly()
    }

    /// A session released elsewhere arrives without a hold, so the veil eases in instead.
    private func settle() {
        cancelMotion()
        settleID += 1
        phase = .resting
        easeSoftness(to: 1, duration: 0.9)
        showLensBriefly()
    }

    private func showLensBriefly() {
        showsLens = true
        lensTask?.cancel()
        lensTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_200_000_000)
            guard phase == .resting else { return }
            showsLens = false
        }
    }

    private func easeSoftness(to target: Double, duration: Double) {
        let from = softness
        returnTask?.cancel()
        returnTask = Task { @MainActor in
            let start = Date()
            while !Task.isCancelled {
                let t = min(1, Date().timeIntervalSince(start) / duration)
                softness = from + (target - from) * t * t * (3 - 2 * t)
                if t >= 1 { return }
                try? await Task.sleep(nanoseconds: 16_000_000)
            }
        }
    }

    private func persist() {
        guard let sync else { return }
        let session = current
        Task { @MainActor in
            if session.phase == .dormant {
                await sync.clear()
            } else {
                await sync.save(session)
            }
        }
    }
}
