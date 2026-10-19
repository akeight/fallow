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

/// Which field a voice capture fills.
enum RecordingTarget: Equatable {
    case thought
    case shift
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
    /// The one thread being worked with, from capture through return. Screens read and write it.
    var session: FallowSession? = nil {
        didSet { persist() }
    }
    var past: [FallowSession] = FallowSession.demoPast
    /// The interpreter's last answer for this capture, or nil when it failed or has not run.
    var interpretation: FallowInterpretation?
    /// A typed thought is being read before the state screen.
    var isInterpreting = false
    var releaseLine: ReleaseLine = .releasing
    var showsNudge = true
    var isRecording = false
    /// Between Stop and the carried thought appearing.
    var isGathering = false
    /// Why the last voice attempt produced nothing. Typing stays available.
    var voiceError: VoiceCaptureError?
    var focusTyping = false
    /// Environment openness outside the hold. Changed inside animations so layers interpolate.
    var baseOpenness = 0.0
    var reduceMotion = false

    /// Progress of the hold that ends a return, 0 through 1.
    var returnHold = 0.0
    /// The orb's light is carrying the person from the return back to Home.
    var isBloomingHome = false
    static let returnHoldDuration = 1.6

    /// How much of the screen the keyboard covers, in points. The orb is placed in the space above it.
    var keyboardInset: CGFloat = 0
    var keyboardVisible: Bool { keyboardInset > 0 }

    var holdStartTick = 0
    var holdNearTick = 0
    var releasedTick = 0
    var selectionTick = 0

    let orb = SessionModel()
    let orbConfig = OrbTuningConfig()
    let leaves = LeafEmitter()
    let voice = VoiceCaptureService()
    let sounds = BreakSounds()
    let interpreter: any FallowInterpreting = FallowInterpreterFactory.make()
    let sync = DemoFallowSyncService()
    #if DEBUG
    let demo: DemoController
    #endif

    @ObservationIgnored private var flowTask: Task<Void, Never>?
    @ObservationIgnored private var returnHoldTask: Task<Void, Never>?
    @ObservationIgnored private var recordingTarget: RecordingTarget = .thought
    /// Bumped on every new interpretation or cancel, so a late answer never lands on the wrong capture.
    @ObservationIgnored private var interpretID = 0

    init() {
        #if DEBUG
        demo = DemoController(sync: sync)
        #endif
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
        orb.breakCue = { [sounds] cue in
            switch cue {
            case .open: sounds.open()
            case .into: sounds.beginHold()
            case .cancel: sounds.cancelHold()
            case .out: sounds.returnFromBreak()
            case .stop: sounds.stopAll()
            }
        }
        voice.onLevel = { [orb] level in orb.voiceLevel = level }
        voice.onEndedEarly = { [weak self] in self?.stopRecording() }
        sync.onRemoteChange = { [weak self] session in self?.receive(session) }
        syncOrb()
        Task {
            if let active = await sync.loadActiveSession() { receive(active) }
        }
    }

    // MARK: Session fields

    /// A session that has been released and is resting or being returned to. Home shows it.
    var active: FallowSession? {
        guard let session, session.isAway else { return nil }
        return session
    }

    var draft: String {
        get { session?.unresolvedThought ?? "" }
        set { session?.unresolvedThought = newValue }
    }

    var reflection: String {
        get { session?.returnedThought ?? "" }
        set { session?.returnedThought = newValue }
    }

    /// The highlighted choice: the person's pick, or the guess until they make one.
    var highlightedState: CreativeState? {
        session?.creativeState ?? interpretation?.suggestedState
    }

    var difficultyDisengaging: Bool {
        session?.difficultyDisengaging ?? false
    }

    // MARK: Derived

    var openness: Double {
        guard tab == .pause, step == .release else { return baseOpenness }
        return max(baseOpenness, 0.15 + 0.55 * orb.holdAmount)
    }

    /// Pause, up to the release, sits on the deepened garden with light type.
    var isDeep: Bool {
        guard tab == .pause else { return false }
        switch step {
        case .capture, .transcript, .refine, .distance, .release, .releasing: return true
        default: return false
        }
    }

    /// The return keeps dark type over a garden that is denser at the bottom.
    var isReturning: Bool {
        tab == .pause && !isDeep && step != .resting
    }

    /// Opacity at the bottom edge. Each surface fades lighter toward the top.
    var gardenOpacity: Double {
        if isDeep { return 1 }
        if isReturning { return 0.6 }
        return tab == .pause ? 0 : 0.5
    }

    /// Share of `gardenOpacity` left at the top edge.
    var gardenTop: Double {
        if isDeep { return 1 }
        return isReturning ? 0.4 / 0.6 : 0.3 / 0.5
    }

    var holdProgress: Double {
        guard tab == .pause, step == .release else { return 0 }
        return orb.holdAmount
    }

    var restScene: FallowDistance {
        session?.distance ?? .someDistance
    }

    var showsTabBar: Bool {
        switch tab {
        case .home, .past: true
        case .pause: step == .capture && !isRecording && !isGathering && !isInterpreting
        }
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
            return active == nil ? OrbPlacement(y: 0.42, scale: 1) : OrbPlacement(y: HomeView.activeOrbY, scale: 0.78)
        case .past:
            return OrbPlacement(y: 0.42, scale: 0.6, visible: false)
        case .pause:
            switch step {
            // With the keyboard up, these sit in the gap between the heading and the field.
            case .capture:
                return keyboardVisible ? OrbPlacement(y: 0.47, scale: 0.95) : OrbPlacement(y: 0.44, scale: 1.15)
            case .transcript:
                return keyboardVisible ? OrbPlacement(y: 0.16, scale: 0.42) : OrbPlacement(y: 0.21, scale: 0.5)
            case .refine: return OrbPlacement(y: 0.09, scale: 0.42)
            case .distance: return OrbPlacement(y: 0.38, scale: 0.78)
            case .release: return OrbPlacement(y: 0.46, scale: 1)
            case .releasing, .resting: return OrbPlacement(y: 0.5, scale: 0.78)
            case .returning:
                // The Mac handoff sits where Home's resting orb does, at the same visual size.
                if session?.originDevice == .mac { return OrbPlacement(y: HomeView.activeOrbY, scale: 0.68) }
                return OrbPlacement(y: 0.33, scale: 0.9)
            case .reflect: return OrbPlacement(y: 0.12, scale: 0.5)
            // Near the middle: it is what you hold to return.
            // Matches the release orb's size so entering and leaving rest feel like one gesture.
            case .beforeAfter: return OrbPlacement(y: 0.26, scale: 1.07)
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
        session = FallowSession(originDevice: .iPhone)
        interpretation = nil
        sounds.open()
        transition(0.6) {
            self.tab = .pause
            self.step = .capture
            self.baseOpenness = 0
        }
        syncOrb()
    }

    /// Leaving setup discards the unreleased session. Leaving a return keeps the thought resting.
    func cancelFlow() {
        cancelRecording()
        flowTask?.cancel()
        if session?.isAway == true {
            session?.leaveLonger()
        } else {
            session = nil
        }
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

    /// Applies a session that changed on another device. A thought released on the Mac opens
    /// straight onto Home; a return request opens the handoff. Setup is never replayed.
    func receive(_ incoming: FallowSession?) {
        cancelRecording()
        flowTask?.cancel()
        switch incoming?.phase {
        case .resting:
            session = incoming
            showsNudge = false
            selectionTick += 1
            transition(0.8) {
                self.tab = .home
                self.baseOpenness = 0
            }
            syncOrb()
        case .returnRequested:
            session = incoming
            showReturn()
        case .complete:
            guard let incoming else { return }
            archive(incoming)
        default:
            session = nil
            transition(0.7) {
                self.tab = .home
                self.baseOpenness = 0
            }
            syncOrb()
        }
    }

    // MARK: Capture

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else if !isGathering {
            startRecording()
        }
    }

    func startRecording(_ target: RecordingTarget = .thought) {
        guard !isRecording, !isGathering, !voice.isBusy else { return }
        recordingTarget = target
        voiceError = nil
        Task {
            await voice.start()
            if voice.isListening {
                setRecording(true)
                announce("Listening")
            } else if let error = voice.error {
                transition(0.4) { self.voiceError = error }
                announce(error.message)
            }
        }
    }

    /// Ends listening and turns the note into text. A failure stays on the same screen with typing open.
    func stopRecording() {
        guard isRecording else { return }
        let target = recordingTarget
        setRecording(false)
        if target == .thought {
            transition(0.4) { self.isGathering = true }
            announce("Gathering the thought")
            syncOrb()
        }
        Task {
            let started = Date()
            let heard = await voice.stop()
            guard let heard else {
                transition(0.4) {
                    self.isGathering = false
                    self.voiceError = self.voice.error ?? .noSpeech
                }
                announce((voice.error ?? .noSpeech).message)
                syncOrb()
                return
            }
            switch target {
            case .shift:
                reflection = heard
                voice.reset()
            case .thought:
                await carryVoice(heard, started: started)
            }
        }
    }

    /// Keeps the whole note, then carries the distilled thread if interpretation worked
    /// or the note itself if it did not. Either way the person lands on the editable thought.
    private func carryVoice(_ heard: String, started: Date) async {
        interpretID += 1
        let id = interpretID
        let result = try? await interpreter.interpret(text: heard)
        let elapsed = Date().timeIntervalSince(started)
        if elapsed < 0.6 {
            try? await Task.sleep(nanoseconds: UInt64((0.6 - elapsed) * 1_000_000_000))
        }
        guard id == interpretID, isGathering else { return }
        session?.captureVoice(raw: heard, distilled: result?.distilledThought)
        interpretation = result
        focusTyping = false
        isGathering = false
        voice.reset()
        go(.transcript)
    }

    /// Stops listening without leaving the screen.
    func cancelListening() {
        cancelRecording()
        announce("Stopped")
    }

    /// Typed straight into the capture field. The words are already the thought, so there is nothing to review.
    func submitTyped() {
        guard !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        cancelRecording()
        voiceError = nil
        session?.rawTranscript = nil
        session?.captureMethod = .text
        continueFromTranscript()
    }

    func rerecord() {
        go(.capture)
        startRecording()
    }

    /// A spoken note was already read while gathering. Typed words are kept exactly as written
    /// and only classified. If reading fails, the state screen opens with nothing suggested.
    func continueFromTranscript() {
        let thought = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !thought.isEmpty, let current = session, !isInterpreting else { return }
        guard current.captureMethod == .text else {
            proceedToRefine(thought, interpretation: interpretation)
            return
        }
        interpretID += 1
        let id = interpretID
        transition(0.4) { self.isInterpreting = true }
        announce(DemoCopy.reading)
        syncOrb()
        Task {
            let result = try? await interpreter.interpret(text: thought)
            guard id == interpretID else { return }
            isInterpreting = false
            proceedToRefine(thought, interpretation: result)
        }
    }

    private func proceedToRefine(_ thought: String, interpretation result: FallowInterpretation?) {
        guard var current = session else { return }
        current.confirmCapture(thought)
        current.applyInterpretation(result)
        interpretation = result
        session = current
        focusTyping = false
        go(.refine)
    }

    #if DEBUG
    /// Stands in for a long spoken note when there is no microphone to demo with.
    /// Goes through the same interpretation as a real note.
    func useDemoNote() {
        cancelRecording()
        voiceError = nil
        transition(0.4) { self.isGathering = true }
        syncOrb()
        Task { await carryVoice(DemoCopy.demoRamble, started: Date()) }
    }
    #endif

    func choose(_ state: CreativeState) {
        session?.choose(state)
        selectionTick += 1
        flowTask?.cancel()
        flowTask = Task {
            try? await Task.sleep(nanoseconds: 550_000_000)
            guard !Task.isCancelled, step == .refine else { return }
            go(.distance, openness: 0.15, duration: 1.4)
        }
    }

    func choose(_ distance: FallowDistance) {
        session?.choose(distance)
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
        if canHoldToReturn {
            beginReturnHold()
            return
        }
        guard tab == .pause, step == .release else { return }
        holdStartTick += 1
        session?.beginRelease()
        orb.pressHold()
    }

    func orbUp(moved: Bool) {
        if tab == .pause, step == .release {
            orb.releaseHold()
            if case .threshold = orb.phase { session?.cancelRelease() }
            return
        }
        if returnHoldTask != nil {
            cancelReturnHold()
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
        session?.markReleased()
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

    /// Back to rest without restarting anything. Used from Home and the before and after.
    func leaveLonger() {
        cancelRecording()
        session?.leaveLonger()
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

    /// A thought released on the Mac is handed back there; one from the phone returns here.
    func returnToIt() {
        cancelRecording()
        session?.requestReturn()
        showReturn()
    }

    private func showReturn() {
        transition(0.9) {
            self.tab = .pause
            self.step = .returning
        }
        transition(reduceMotion ? 1 : 2.6) { self.baseOpenness = 0.12 }
        syncOrb()
    }

    func somethingShifted() {
        go(.reflect)
    }

    func confirmReflection() {
        let text = reflection.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        cancelRecording()
        session?.recordShift(text)
        go(.beforeAfter)
    }

    // MARK: Hold to return

    /// Holding the orb ends the session, as holding it began the rest.
    var canHoldToReturn: Bool {
        tab == .pause && step == .beforeAfter && !isBloomingHome
    }

    func beginReturnHold() {
        guard canHoldToReturn, returnHoldTask == nil else { return }
        holdStartTick += 1
        let start = Date()
        returnHoldTask = Task { @MainActor in
            while !Task.isCancelled {
                let progress = min(1, Date().timeIntervalSince(start) / Self.returnHoldDuration)
                returnHold = progress
                if progress >= 1 {
                    returnHoldTask = nil
                    completeReturnHold()
                    return
                }
                try? await Task.sleep(nanoseconds: 16_000_000)
            }
        }
    }

    /// Let go early: everything eases back and nothing happens.
    func cancelReturnHold() {
        returnHoldTask?.cancel()
        returnHoldTask = nil
        withAnimation(.easeOut(duration: 0.45)) { returnHold = 0 }
    }

    /// The hold completed, or VoiceOver asked for it. The orb's light carries the person home.
    func completeReturnHold() {
        guard canHoldToReturn else { return }
        returnHoldTask?.cancel()
        returnHoldTask = nil
        returnHold = 1
        releasedTick += 1
        sounds.returnFromBreak()
        isBloomingHome = true
    }

    /// Called under the bloom's light, so Home is already in place when it clears.
    func finishReturn() {
        returnHold = 0
        guard var session else { return }
        session.complete()
        archive(session)
    }

    func bloomFinished() {
        isBloomingHome = false
    }

    // MARK: Private

    private func archive(_ session: FallowSession) {
        past.removeAll { $0.id == session.id }
        past.insert(session, at: 0)
        self.session = nil
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
        voice.cancel()
        orb.voiceLevel = 0
        if isRecording { setRecording(false) }
        isGathering = false
        isInterpreting = false
        interpretID += 1
    }

    private func setRecording(_ value: Bool) {
        transition(0.5) { self.isRecording = value }
        orb.isListening = value
        syncOrb()
    }

    private func announce(_ message: String) {
        AccessibilityNotification.Announcement(message).post()
    }

    private func persist() {
        let current = session
        Task {
            if let current {
                await sync.save(current)
            } else {
                await sync.clear()
            }
        }
    }

    #if DEBUG
    /// Opens a screen directly, for previews and screenshots: `-fallowScreen release-mid`.
    func open(debugScreen name: String) {
        var setup = FallowSession(originDevice: .iPhone)
        setup.captureText(DemoCopy.phoneUnresolved)
        interpretation = LocalInterpreter.interpretation(for: DemoCopy.phoneUnresolved)
        var chosen = setup
        chosen.choose(.looping)
        var ready = chosen
        ready.choose(.someDistance)
        var returning = FallowSession.demoFromPhone
        returning.requestReturn()

        func resting(_ state: CreativeState, _ distance: FallowDistance, disengaging: Bool = false) -> FallowSession {
            var rest = setup
            rest.choose(state)
            rest.setDifficultyDisengaging(disengaging)
            rest.choose(distance)
            rest.markReleased()
            return rest
        }

        switch name {
        case "home-empty": session = nil
        case "home-phone": session = .demoFromPhone
        case "past": tab = .past
        case "capture": tab = .pause; step = .capture; session = FallowSession(originDevice: .iPhone)
        case "listening":
            tab = .pause; step = .capture; session = FallowSession(originDevice: .iPhone); isRecording = true; orb.isListening = true; orb.voiceLevel = 0.6
        case "gathering": tab = .pause; step = .capture; session = FallowSession(originDevice: .iPhone); isGathering = true
        case "voice-error": tab = .pause; step = .capture; session = FallowSession(originDevice: .iPhone); voiceError = .microphoneDenied
        case "voice-transcript", "voice-short":
            var spoken = FallowSession(originDevice: .iPhone)
            let raw = name == "voice-short" ? "The opening screen feels wrong." : DemoCopy.demoRamble
            spoken.captureVoice(raw: raw, distilled: HeuristicDistiller.distill(raw))
            tab = .pause; step = .transcript; session = spoken
        case "transcript": tab = .pause; step = .transcript; session = setup
        case "refine": tab = .pause; step = .refine; session = setup
        case "refine-unsure":
            setup.captureText(DemoCopy.unresolved)
            interpretation = LocalInterpreter.interpretation(for: DemoCopy.unresolved)
            tab = .pause; step = .refine; session = setup
        case "distance": tab = .pause; step = .distance; session = chosen; baseOpenness = 0.15
        case "release", "release-mid", "release-late", "release-auto":
            tab = .pause; step = .release; session = ready; baseOpenness = 0.15
        case "releasing": tab = .pause; step = .releasing; session = .demoFromPhone; baseOpenness = 1
        case "resting": tab = .pause; step = .resting; session = DemoSessionFactory.macRestingDemo; baseOpenness = 1
        case "resting-empty": tab = .pause; step = .resting; session = resting(.runningOnEmpty, .breath); baseOpenness = 1
        case "resting-disengaging":
            tab = .pause; step = .resting; session = resting(.lostPerspective, .someDistance, disengaging: true); baseOpenness = 1
        case "return-mac":
            var handoff = DemoSessionFactory.macRestingDemo
            handoff.requestReturn()
            tab = .pause; step = .returning; session = handoff; baseOpenness = 0.12
        case "return-phone": tab = .pause; step = .returning; session = returning; baseOpenness = 0.12
        case "reflect": tab = .pause; step = .reflect; session = returning; baseOpenness = 0.12
        case "before-after", "before-after-auto":
            returning.recordShift(DemoCopy.phoneReflection)
            tab = .pause; step = .beforeAfter; session = returning; baseOpenness = 0.12
        case "before-after-long":
            returning.unresolvedThought = DemoCopy.demoRamble
            returning.recordShift(DemoCopy.demoRamble)
            tab = .pause; step = .beforeAfter; session = returning; baseOpenness = 0.12
        default: break
        }
        if name == "listening" { orb.showPreview(.capture); return }
        syncOrb()
        if name == "release-mid" { orb.showPreview(.holding(progress: 0.6)) }
        if name == "release-late" { orb.showPreview(.holding(progress: 0.9)) }
        if name == "before-after-auto" {
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                beginReturnHold()
            }
        }
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
        let phase: OrbPhase
        switch tab {
        case .home:
            phase = active == nil ? .dormant : .resting
        case .past:
            phase = .dormant
        case .pause:
            switch step {
            case .capture: phase = isRecording || isGathering || isInterpreting ? .capture : .dormant
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
