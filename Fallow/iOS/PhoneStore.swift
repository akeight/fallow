import Observation
import SwiftUI

enum PhoneTab: Equatable {
    case home
    case pause
    case past
}

/// Steps inside the Pause destination. Return lives here too, because it continues the same thread.
enum PhoneStep: Equatable {
    case capture
    case transcript
    case refine
    case distance
    case release
    case releasing
    case resting
    case returning
    case reflect
    case beforeAfter
}

enum ReleaseLine: Equatable {
    case releasing
    case restingNow
}

/// Where the orb sits for the current screen, as a fraction of the content height.
struct OrbPlacement: Equatable {
    var y: Double
    var scale: Double
    var visible = true
}

@MainActor
@Observable
final class PhoneStore {
    var tab: PhoneTab = .home
    var step: PhoneStep = .capture
    var active: FallowSession? = .demo
    var past: [FallowSession] = FallowSession.demoPast
    var draft = ""
    var creativeState: CreativeState = .lostPerspective
    var suggestedState: CreativeState = .lostPerspective
    var distance: DistanceKind?
    var reflection = ""
    var releaseLine: ReleaseLine = .releasing
    var handedToMac = false
    var showsNudge = true
    var isRecording = false
    var focusTyping = false
    /// Environment openness outside the hold. Changed inside animations so layers interpolate.
    var baseOpenness = 0.0
    var reduceMotion = false

    var holdStartTick = 0
    var holdNearTick = 0
    var releasedTick = 0
    var selectionTick = 0

    let orb = SessionModel()
    let orbConfig = OrbTuningConfig()
    let leaves = LeafEmitter()
    let voice = VoiceCapture()

    @ObservationIgnored private var flowTask: Task<Void, Never>?
    @ObservationIgnored private var simulatedVoice: Task<Void, Never>?
    @ObservationIgnored private var demoIndex = 0
    @ObservationIgnored private var recordingReflection = false

    init() {
        orbConfig.idleSize = 100
        orbConfig.holdStartSize = 150
        orbConfig.holdEndSize = 225
        // Rounder than the Mac stone: on a narrow screen the pressed pose reads as a pill.
        orbConfig.horizontalStretch = 0.98
        orbConfig.verticalStretch = 1.04
        orbConfig.restSize = 120
        orbConfig.restBreathDuration = 11
        orbConfig.returnSize = 140
        orbConfig.returnDuration = 1.8
        orbConfig.deformationSpeed = 0.02
        orb.holdDuration = 2.8
        voice.onLevel = { [orb] level in orb.voiceLevel = level }
        syncOrb()
    }

    // MARK: Derived

    var openness: Double {
        guard tab == .pause, step == .release else { return baseOpenness }
        return max(baseOpenness, 0.15 + 0.55 * orb.holdAmount)
    }

    var holdProgress: Double {
        guard tab == .pause, step == .release else { return 0 }
        return orb.holdAmount
    }

    var restScene: DistanceKind {
        active?.distance ?? distance ?? .someDistance
    }

    var showsTabBar: Bool {
        switch tab {
        case .home, .past: true
        case .pause: step == .capture && !isRecording
        }
    }

    /// The bar recedes once a thought is being worked with.
    var tabBarEmphasis: Double {
        tab == .pause ? 0.5 : 1
    }

    var leafMode: LeafMode {
        guard tab == .pause else { return .off }
        switch step {
        case .release:
            return .release
        case .releasing:
            return .afterRelease
        case .resting:
            return .resting
        case .returning, .reflect, .beforeAfter:
            return .draining
        default:
            return .off
        }
    }

    /// Hold progress below half sheds nothing. The second half builds to a quiet peak.
    var leafIntensity: Double {
        switch step {
        case .release:
            let p = holdProgress
            if p < 0.5 { return 0 }
            if p < 0.75 { return 0.12 + (p - 0.5) / 0.25 * 0.16 }
            return 0.28 + (p - 0.75) / 0.25 * 0.72
        default:
            return 1
        }
    }

    var orbPlacement: OrbPlacement {
        switch tab {
        case .home:
            return active == nil ? OrbPlacement(y: 0.42, scale: 1) : OrbPlacement(y: 0.57, scale: 0.7)
        case .past:
            return OrbPlacement(y: 0.42, scale: 0.6, visible: false)
        case .pause:
            switch step {
            case .capture: return OrbPlacement(y: 0.44, scale: 1.15)
            case .transcript: return OrbPlacement(y: 0.12, scale: 0.5)
            case .refine: return OrbPlacement(y: 0.09, scale: 0.42)
            case .distance: return OrbPlacement(y: 0.38, scale: 0.78)
            case .release: return OrbPlacement(y: 0.46, scale: 1)
            case .releasing, .resting: return OrbPlacement(y: 0.5, scale: 0.78)
            case .returning: return OrbPlacement(y: 0.33, scale: 0.9)
            case .reflect: return OrbPlacement(y: 0.12, scale: 0.5)
            case .beforeAfter: return OrbPlacement(y: 0.11, scale: 0.45)
            }
        }
    }

    // MARK: Navigation

    func select(_ next: PhoneTab) {
        guard next != tab || next == .pause else { return }
        if next == .pause {
            startPause()
            return
        }
        cancelRecording()
        transition(0.6) {
            self.tab = next
            self.baseOpenness = 0
        }
        syncOrb()
    }

    func startPause() {
        if active != nil {
            leaveLonger()
            return
        }
        draft = ""
        reflection = ""
        distance = nil
        handedToMac = false
        transition(0.6) {
            self.tab = .pause
            self.step = .capture
            self.baseOpenness = 0
        }
        syncOrb()
    }

    func cancelFlow() {
        cancelRecording()
        flowTask?.cancel()
        transition(0.7) {
            self.tab = .home
            self.baseOpenness = 0
        }
        syncOrb()
    }

    func back() {
        cancelRecording()
        let previous: PhoneStep? = switch step {
        case .transcript: .capture
        case .refine: .transcript
        case .distance: .refine
        case .release: .distance
        case .reflect: .returning
        default: nil
        }
        guard let previous else {
            cancelFlow()
            return
        }
        go(previous)
    }

    func cycleDemo() {
        demoIndex = (demoIndex + 1) % 3
        active = switch demoIndex {
        case 0: .demo
        case 1: nil
        default: .demoFromPhone
        }
        showsNudge = active != nil
        selectionTick += 1
        transition(0.6) { self.tab = .home }
        syncOrb()
    }

    // MARK: Capture

    func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    func startRecording(forReflection: Bool = false) {
        guard !isRecording else { return }
        recordingReflection = forReflection
        transition(0.5) { self.isRecording = true }
        syncOrb()
        Task {
            await voice.start()
            if voice.unavailable, isRecording {
                simulateVoice()
            }
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        voice.stop()
        simulatedVoice?.cancel()
        orb.voiceLevel = 0
        let heard = voice.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        transition(0.5) { self.isRecording = false }
        if recordingReflection {
            reflection = heard.isEmpty ? (reflection.isEmpty ? DemoCopy.phoneReflection : reflection) : heard
            syncOrb()
            return
        }
        draft = heard.isEmpty ? DemoCopy.phoneUnresolved : heard
        focusTyping = false
        go(.transcript)
    }

    func typeInstead() {
        cancelRecording()
        focusTyping = true
        go(.transcript)
    }

    func rerecord() {
        draft = ""
        go(.capture)
        startRecording()
    }

    func continueFromTranscript() {
        if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draft = DemoCopy.phoneUnresolved
        }
        focusTyping = false
        suggestedState = CreativeState.suggested(for: draft)
        creativeState = suggestedState
        go(.refine)
    }

    func choose(_ state: CreativeState) {
        creativeState = state
        selectionTick += 1
    }

    func continueFromRefine() {
        go(.distance, openness: 0.15, duration: 1.4)
    }

    func choose(_ kind: DistanceKind) {
        distance = kind
        selectionTick += 1
        flowTask?.cancel()
        flowTask = Task {
            try? await Task.sleep(nanoseconds: 550_000_000)
            guard !Task.isCancelled, step == .distance else { return }
            go(.release, openness: 0.15, duration: 1)
        }
    }

    // MARK: Hold and release

    func orbDown() {
        guard tab == .pause, step == .release else { return }
        holdStartTick += 1
        orb.pressHold()
    }

    func orbUp(moved: Bool) {
        if tab == .pause, step == .release {
            orb.releaseHold()
            return
        }
        guard !moved else { return }
        tapOrb()
    }

    func tapOrb() {
        switch tab {
        case .home:
            if active != nil { leaveLonger() } else { startPause() }
        case .past:
            break
        case .pause:
            switch step {
            case .capture: toggleRecording()
            case .resting: returnToIt()
            default: break
            }
        }
    }

    /// VoiceOver cannot press and hold, so the accessible action completes the release.
    func releaseWithoutHold() {
        guard tab == .pause, step == .release else { return }
        orb.finishHold()
    }

    func holdCompleted() {
        guard tab == .pause, step == .release else { return }
        releasedTick += 1
        let thought = draft.isEmpty ? DemoCopy.phoneUnresolved : draft
        active = FallowSession(
            projectName: "FRAGMENTS",
            unresolvedThought: thought,
            creativeState: creativeState,
            distance: distance ?? .someDistance,
            status: .resting,
            origin: .phone
        )
        showsNudge = false
        baseOpenness = 0.7
        releaseLine = .releasing
        transition(0.9) { self.step = .releasing }
        transition(reduceMotion ? 1.2 : 3.6) { self.baseOpenness = 1 }
        flowTask?.cancel()
        flowTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled, step == .releasing else { return }
            transition(1.2) { self.releaseLine = .restingNow }
            try? await Task.sleep(nanoseconds: 2_800_000_000)
            guard !Task.isCancelled, step == .releasing else { return }
            transition(1.4) { self.step = .resting }
        }
    }

    // MARK: Resting and return

    func leaveLonger() {
        cancelRecording()
        showsNudge = false
        transition(0.8) {
            self.tab = .pause
            self.step = .resting
        }
        transition(reduceMotion ? 1 : 2.4) { self.baseOpenness = 1 }
        syncOrb()
    }

    func closeRest() {
        transition(1.2) {
            self.tab = .home
            self.baseOpenness = 0
        }
        syncOrb()
    }

    func returnToIt() {
        cancelRecording()
        handedToMac = false
        reflection = ""
        transition(0.9) {
            self.tab = .pause
            self.step = .returning
        }
        transition(reduceMotion ? 1 : 2.6) { self.baseOpenness = 0.12 }
        syncOrb()
    }

    func returnOnMac() {
        guard var session = active else { return }
        transition(0.8) { self.handedToMac = true }
        session.status = .returning
        session.date = Date()
        flowTask?.cancel()
        flowTask = Task {
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            guard !Task.isCancelled else { return }
            archive(session)
        }
    }

    func beginReflection() {
        go(.reflect)
    }

    func confirmReflection() {
        cancelRecording()
        if reflection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            reflection = DemoCopy.phoneReflection
        }
        go(.beforeAfter)
    }

    func finishReturn() {
        guard var session = active else { return }
        session.returnedWith = reflection
        session.status = .returning
        session.date = Date()
        archive(session)
    }

    // MARK: Private

    private func archive(_ session: FallowSession) {
        past.insert(session, at: 0)
        active = nil
        transition(1) {
            self.tab = .home
            self.baseOpenness = 0
        }
        orb.showPreview(.reentering)
        flowTask = Task {
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !Task.isCancelled else { return }
            syncOrb()
        }
    }

    private func go(_ next: PhoneStep, openness: Double = 0, duration: Double = 0.7) {
        transition(0.7) { self.step = next }
        transition(duration) { self.baseOpenness = openness }
        syncOrb()
    }

    private func transition(_ duration: Double, _ body: () -> Void) {
        let length = reduceMotion ? min(duration, 0.35) : duration
        withAnimation(.easeInOut(duration: length), body)
    }

    private func cancelRecording() {
        guard isRecording else { return }
        voice.stop()
        simulatedVoice?.cancel()
        orb.voiceLevel = 0
        isRecording = false
    }

    /// Without a microphone the orb still listens, so the demo keeps its feel.
    private func simulateVoice() {
        simulatedVoice?.cancel()
        simulatedVoice = Task {
            var level = 0.0
            var t = 0.0
            while !Task.isCancelled, isRecording {
                t += 0.05
                let target = max(0, 0.45 + 0.35 * sin(t * 5.3) * sin(t * 1.7) + Double.random(in: -0.15...0.15))
                level += (target - level) * 0.3
                orb.voiceLevel = level
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
            orb.voiceLevel = 0
        }
    }

    #if DEBUG
    /// Opens a screen directly, for previews and screenshots: `-fallowScreen release-mid`.
    func open(debugScreen name: String) {
        draft = DemoCopy.phoneUnresolved
        suggestedState = .looping
        creativeState = .looping
        switch name {
        case "home-empty": active = nil
        case "home-phone": active = .demoFromPhone
        case "past": tab = .past
        case "capture": tab = .pause; step = .capture; active = nil
        case "listening": tab = .pause; step = .capture; active = nil; isRecording = true; orb.voiceLevel = 0.6
        case "transcript": tab = .pause; step = .transcript; active = nil
        case "refine": tab = .pause; step = .refine; active = nil
        case "distance": tab = .pause; step = .distance; active = nil; distance = .someDistance; baseOpenness = 0.15
        case "release", "release-mid", "release-late", "release-auto":
            tab = .pause; step = .release; active = nil; distance = .someDistance; baseOpenness = 0.15
        case "releasing": tab = .pause; step = .releasing; active = .demoFromPhone; baseOpenness = 1
        case "resting": tab = .pause; step = .resting; baseOpenness = 1
        case "return-mac": tab = .pause; step = .returning; baseOpenness = 0.12
        case "return-phone": tab = .pause; step = .returning; active = .demoFromPhone; baseOpenness = 0.12
        case "reflect": tab = .pause; step = .reflect; active = .demoFromPhone; baseOpenness = 0.12
        case "before-after":
            tab = .pause; step = .beforeAfter; active = .demoFromPhone; reflection = DemoCopy.phoneReflection; baseOpenness = 0.12
        default: break
        }
        if name == "listening" { orb.showPreview(.capture); return }
        syncOrb()
        if name == "release-mid" { orb.showPreview(.holding(progress: 0.6)) }
        if name == "release-late" { orb.showPreview(.holding(progress: 0.9)) }
        if name == "release-auto" {
            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                orbDown()
            }
        }
    }
    #endif

    /// Points the shared orb at the pose for the current screen. Hold drives itself.
    private func syncOrb() {
        let phase: SessionPhase
        switch tab {
        case .home:
            phase = active == nil ? .dormant : .resting
        case .past:
            phase = .dormant
        case .pause:
            switch step {
            case .capture: phase = isRecording ? .capture : .dormant
            case .transcript, .refine: phase = .dormant
            case .distance, .release: phase = .threshold
            case .releasing, .resting: phase = .resting
            case .returning: phase = .returnDoorway
            case .reflect: phase = isRecording ? .capture : .reflecting
            case .beforeAfter: phase = .beforeAfter
            }
        }
        if orb.phase == phase { return }
        if phase == .resting, case .holding = orb.phase { return }
        orb.showPreview(phase)
    }
}
