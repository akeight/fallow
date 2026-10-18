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
    /// The session was left before the return finished.
    case stop
}

@MainActor
@Observable
final class SessionModel {
    var phase: SessionPhase = .dormant
    var thought: String = ""
    var thoughtIsCaptured = false
    var stuck: StuckKind?
    var distance: DistanceKind?
    var reflection: String = ""
    /// Raw recession, 0 through 1. The veil shapes this; it is not pre-curved.
    var softness: Double = 0
    var showsLens = false
    var holdDuration = 1.8
    var reentryDuration = 0.9
    /// Smoothed microphone level, 0 through 1. Only the phone sets it.
    var voiceLevel = 0.0
    /// Increments only when a hold completes, so an early release never settles.
    var settleID = 0
    /// Increments when the return entrance should play again.
    var returnID = 0
    /// Mac playback. Ignored by observation so assigning it does not refresh the UI.
    @ObservationIgnored var breakCue: ((BreakCue) -> Void)?

    private var pressing = false
    private var holdTask: Task<Void, Never>?
    private var lensTask: Task<Void, Never>?
    private var returnTask: Task<Void, Never>?
    private var releaseTask: Task<Void, Never>?

    var holdAmount: Double {
        if case .holding(let progress) = phase { return progress }
        if case .threshold = phase { return softness }
        return softness
    }

    func tapOrb() {
        switch phase {
        case .dormant:
            breakCue?(.open)
            phase = .capture
        case .resting where !showsLens:
            phase = .returnDoorway
        default:
            break
        }
    }

    func revealThought() {
        thought = DemoCopy.unresolved
        thoughtIsCaptured = true
    }

    func confirmThought() {
        if thought.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            thought = DemoCopy.unresolved
        }
        thoughtIsCaptured = true
        phase = .classifyStuck
    }

    func chooseStuck(_ kind: StuckKind) {
        stuck = kind
        phase = .chooseDistance
    }

    func chooseDistance(_ kind: DistanceKind) {
        distance = kind
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
        if reflection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            reflection = DemoCopy.reflection
        }
        phase = .beforeAfter
    }

    func goBackIn() {
        guard phase == .beforeAfter else { return }
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
            phase = .dormant
            softness = 0
        }
    }

    func showPreview(_ phase: SessionPhase) {
        cancelMotion()
        switch phase {
        case .dormant:
            softness = 0
            showsLens = false
            self.phase = .dormant
        case .capture:
            thought = DemoCopy.unresolved
            thoughtIsCaptured = true
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

    /// Leaves the current step and returns to the quiet orb. The veil clears with it.
    func leave() {
        guard phase != .dormant else { return }
        breakCue?(.stop)
        cancelMotion()
        showsLens = false
        thought = ""
        thoughtIsCaptured = false
        reflection = ""
        stuck = nil
        distance = nil
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
        pressing = false
        holdTask?.cancel()
        holdTask = nil
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
        phase = .resting
        softness = 1
        showsLens = true
        lensTask?.cancel()
        lensTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_200_000_000)
            guard phase == .resting else { return }
            showsLens = false
        }
    }
}
