import AppKit
import SwiftUI

struct CompanionView: View {
    @Bindable var session: SessionModel
    var config: OrbTuningConfig
    var layout: CompanionLayout
    var syncChrome: () -> Void
    var syncVeil: () -> Void
    var openTuner: () -> Void
    #if DEBUG
    var runDemo: (DemoController.Scenario) -> Void = { _ in }
    #endif
    @State private var sounds = BreakSounds()
    @State private var voice = VoiceCaptureService()
    @State private var gathering = false
    @State private var showsNote = false
    /// Which field the microphone is filling.
    @State private var voiceTarget: VoiceTarget = .thought
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let window = layout.window
        let area = layout.content
        ZStack(alignment: .topLeading) {
            if holdsFocus {
                // Fully clear pixels let clicks fall through to the app behind, which then
                // takes the next Escape. Nearly clear keeps them, and the focus, in FALLOW.
                Color.black.opacity(0.01)
                    .contentShape(Rectangle())
            }
            // Light only around the orb; the orb reads the desktop's appearance itself.
            content
                .environment(\.colorScheme, .light)
                .frame(width: area.width, height: area.height, alignment: alignment)
                .offset(x: area.minX - window.minX, y: window.maxY - area.maxY)
                .id(contentKey)
                .transition(.opacity)
            // One orb for the whole session, so its shape and place ease between steps.
            orb
                .modifier(ScreenPlacement(center: layout.orbCenter, window: window))
                .animation(reduceMotion ? nil : .smooth(duration: 1.1), value: layout.orbCenter)
        }
        .animation(.easeInOut(duration: 0.5), value: contentKey)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onExitCommand(perform: escape)
        .contextMenu {
            #if DEBUG
            Button("Tune orb") { openTuner() }
            Menu("Demo") {
                ForEach(DemoController.Scenario.mac) { scenario in
                    Button(scenario.title) { runDemo(scenario) }
                }
            }
            #endif
            Button("Quit FALLOW") { NSApp.terminate(nil) }
        }
        .onAppear {
            pushTiming()
            session.breakCue = { [sounds] cue in
                switch cue {
                case .open: sounds.open()
                case .into: sounds.beginHold()
                case .cancel: sounds.cancelHold()
                case .out: sounds.returnFromBreak()
                case .stop: sounds.stopAll()
                }
            }
            voice.onLevel = { [session] level in session.voiceLevel = level }
            voice.onEndedEarly = { stopListening() }
            syncChrome()
        }
        .onChange(of: session.phase) { _, phase in
            if !voiceTarget.lives(in: phase) { cancelListening() }
        }
        .onChange(of: layoutKey) { _, _ in syncChrome() }
        .onChange(of: session.softness) { _, _ in syncVeil() }
        .onChange(of: config.holdDuration) { _, _ in pushTiming() }
        .onChange(of: config.reentryDuration) { _, _ in pushTiming() }
        .onChange(of: config.layoutSignature) { _, _ in syncChrome() }
        .onChange(of: config.veilSignature) { _, _ in syncChrome() }
    }

    /// Everything but the orb. Each step leaves an empty space where the orb will sit.
    @ViewBuilder
    private var content: some View {
        switch session.phase {
        case .dormant, .reentering:
            Color.clear
        case .capture:
            capture
        case .classifyStuck:
            choices(
                prompt: DemoCopy.stuckPrompt,
                hint: session.interpretation?.suggestedState == nil ? DemoCopy.notSureYet : DemoCopy.suggestedGuess,
                items: CreativeState.allCases.map { ($0.title, $0 == session.creativeState) },
                subtitles: CreativeState.allCases.map(\.meaning),
                notes: CreativeState.allCases.map { $0 == session.interpretation?.suggestedState ? "Suggested" : nil },
                select: { session.chooseState(CreativeState.allCases[$0]) }
            )
        case .chooseDistance:
            choices(
                prompt: DemoCopy.distancePrompt,
                items: FallowDistance.allCases.map { ($0.title, $0 == session.distance) },
                select: { session.chooseDistance(FallowDistance.allCases[$0]) }
            )
        case .threshold, .holding:
            threshold
        case .resting:
            resting
        case .returnDoorway, .reflecting:
            doorway
        case .beforeAfter:
            beforeAfter
        }
    }

    /// While the frost covers the desk, the desk is not meant to be used.
    private var holdsFocus: Bool {
        switch session.phase {
        case .threshold, .holding, .resting, .returnDoorway, .reflecting, .beforeAfter:
            true
        default:
            false
        }
    }

    /// The lens line changes inside the resting page, so it does not refade the page.
    private var contentKey: String {
        session.phase == .resting ? "rest" : layoutKey
    }

    private func pushTiming() {
        session.holdDuration = config.holdDuration
        session.reentryDuration = config.reentryDuration
    }

    /// Ignores hold progress, so the window does not move on every tick.
    private var layoutKey: String {
        switch session.phase {
        case .dormant: "dormant"
        case .capture: "capture"
        case .classifyStuck: "stuck"
        case .chooseDistance: "distance"
        case .threshold, .holding: "threshold"
        case .resting: session.showsLens ? "lens" : "rest"
        case .returnDoorway: "return"
        case .reflecting: "reflect"
        case .beforeAfter: "compare"
        case .reentering: "reenter"
        }
    }

    private var alignment: Alignment {
        switch session.phase {
        case .threshold, .holding, .resting, .returnDoorway, .reflecting, .beforeAfter:
            .center
        default:
            .bottomTrailing
        }
    }

    private var orb: some View {
        OrbView(session: session, config: config)
            .modifier(OrbInput(session: session))
            .help(session.phase == .resting ? "Return" : "FALLOW")
    }

    private var orbSpace: some View {
        let side = CGFloat(OrbMotion.canvasExtent(phase: session.phase, config: config))
        return Color.clear.frame(width: side, height: side)
    }

    /// The first steps share one column beside the orb's home: separate glass pieces with room between them.
    private func column<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                content()
            }
            .frame(width: Self.columnWidth)
            orbSpace
        }
        .padding(16)
    }

    private static let columnWidth: CGFloat = 380

    /// The question on its own pane: a serif title over a quiet caption.
    private func promptPane(_ title: String, hint: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(FallowType.display(28))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let hint {
                Text(hint)
                    .font(FallowType.caption)
                    .foregroundStyle(Theme.mute)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        .padding(.trailing, 18)
        .glass(radius: 22)
        .overlay(alignment: .topTrailing) { leaveMark }
    }

    private var capture: some View {
        column {
            promptPane(DemoCopy.carrying, hint: session.current.hasFullNote ? nil : "Voice, or text. The canvas stays visible.")

            VStack(alignment: .leading, spacing: 10) {
                voiceStatus(for: .thought)
                ThoughtComposer(
                    text: $session.thought,
                    placeholder: DemoCopy.speakOrType,
                    isRecording: isListening(.thought),
                    isGathering: gathering,
                    showsSend: false,
                    onMic: { toggleListening(.thought) },
                    onSubmit: session.confirmThought
                )
                .disabled(session.isInterpreting)
            }

            VStack(spacing: 4) {
                PrimaryButton(title: session.isInterpreting ? DemoCopy.reading : DemoCopy.keep, action: session.confirmThought)
                    .disabled(thoughtIsEmpty || voice.isListening || gathering || session.isInterpreting)
                    .opacity(thoughtIsEmpty || session.isInterpreting ? 0.5 : 1)
                if session.current.hasFullNote && !voice.isBusy && !gathering {
                    QuietButton(title: DemoCopy.viewFullNote) { showsNote = true }
                        .popover(isPresented: $showsNote, arrowEdge: .bottom) { fullNote }
                }
                #if DEBUG
                if thoughtIsEmpty && !voice.isBusy && !gathering {
                    QuietButton(title: DemoCopy.showThought) { session.captureText(DemoCopy.unresolved) }
                }
                #endif
            }
        }
    }

    private var thoughtIsEmpty: Bool {
        session.thought.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func isListening(_ target: VoiceTarget) -> Bool {
        voice.isListening && voiceTarget == target
    }

    private func toggleListening(_ target: VoiceTarget) {
        isListening(target) ? stopListening() : startListening(target)
    }

    /// Only the latest words while listening, or why voice did not work. Gathering shows in the composer.
    @ViewBuilder
    private func voiceStatus(for target: VoiceTarget) -> some View {
        if isListening(target) {
            Text(voice.recentTranscript.isEmpty ? " " : voice.recentTranscript)
                .font(FallowType.process)
                .foregroundStyle(Theme.mute)
                .lineLimit(2)
                .truncationMode(.head)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .animation(.easeOut(duration: 0.3), value: voice.recentTranscript)
                .accessibilityHidden(true)
                .transition(.fallowText)
        } else if voiceTarget == target, let error = voice.error {
            Text(error.message)
                .font(FallowType.caption)
                .foregroundStyle(Theme.mute)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20)
                .transition(.fallowText)
        }
    }

    private var fullNote: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: DemoCopy.fullNote)
            ScrollView {
                Text(session.current.rawTranscript ?? "")
                    .font(FallowType.process)
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(5)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(22)
        .frame(width: 360, height: 280)
    }

    private func startListening(_ target: VoiceTarget) {
        guard !voice.isBusy, !gathering else { return }
        voiceTarget = target
        Task {
            await voice.start()
            if voice.isListening {
                session.isListening = true
                announce("Listening")
            } else if let error = voice.error {
                announce(error.message)
            }
        }
    }

    /// The whole note is kept; its concise thought lands in the field for editing.
    /// A reflection is a short answer, so it goes into its field as spoken.
    private func stopListening() {
        guard voice.isListening else { return }
        session.isListening = false
        if voiceTarget == .reflection {
            Task {
                if let heard = await voice.stop(), voiceTarget.lives(in: session.phase) {
                    session.reflection = heard
                    voice.reset()
                } else if let error = voice.error {
                    announce(error.message)
                }
            }
            return
        }
        gathering = true
        announce("Gathering the thought")
        Task {
            guard let heard = await voice.stop() else {
                gathering = false
                session.voiceLevel = 0
                announce((voice.error ?? .noSpeech).message)
                return
            }
            await session.carryVoice(heard)
            guard gathering, session.phase == .capture else { return }
            gathering = false
            session.voiceLevel = 0
            voice.reset()
        }
    }

    private func cancelListening() {
        voice.cancel()
        session.cancelInterpretation()
        gathering = false
        showsNote = false
        session.isListening = false
        session.voiceLevel = 0
    }

    /// Escape stops listening first, then leaves.
    private func escape() {
        if voice.isBusy || gathering {
            cancelListening()
        } else {
            session.leave()
        }
    }

    private func announce(_ message: String) {
        AccessibilityNotification.Announcement(message).post()
    }

    /// One answer per glass row; choosing one is the answer.
    private func choices(
        prompt: String,
        hint: String? = nil,
        items: [(String, Bool)],
        subtitles: [String?] = [],
        notes: [String?] = [],
        select: @escaping (Int) -> Void
    ) -> some View {
        column {
            promptPane(prompt, hint: hint)
            VStack(spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    ChoiceRow(
                        title: item.0,
                        subtitle: subtitles.indices.contains(index) ? subtitles[index] : nil,
                        note: notes.indices.contains(index) ? notes[index] : nil,
                        selected: item.1
                    ) { select(index) }
                }
            }
        }
    }

    /// Hold, rest, and return share the screen's center for the orb; the copy sits around this space.
    private func centeredOrb(height: Double) -> some View {
        Color.clear.frame(width: 1, height: CGFloat(height))
    }

    private var threshold: some View {
        let extent = max(
            config.holdStartSize * config.verticalStretch * 0.96,
            config.holdEndSize * config.verticalStretch * 0.78
        )
        return centeredOrb(height: extent)
            .overlay(alignment: .bottom) {
                Text(DemoCopy.hold)
                    .font(FallowType.secondary)
                    .foregroundStyle(Theme.ink)
                    .fixedSize()
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .glass(radius: 22)
                    .alignmentGuide(.bottom) { d in d[.top] - 24 }
            }
    }

    private var resting: some View {
        centeredOrb(height: config.restSize * config.verticalStretch * 0.8)
            .overlay(alignment: .top) {
                VStack(spacing: 12) {
                    Text(DemoCopy.itsHere)
                        .font(FallowType.display(34))
                        .foregroundStyle(Theme.ink)
                    Eyebrow(text: session.current.restingLine)
                }
                .fixedSize()
                .alignmentGuide(.top) { d in d[.bottom] + 44 }
            }
            .overlay(alignment: .bottom) {
                Text(session.showsLens ? (session.restLine ?? DemoCopy.returnWhenReady) : DemoCopy.returnWhenReady)
                    .id(session.showsLens)
                    .transition(.fallowText)
                    .font(.system(size: 17, weight: .regular))
                    .tracking(0.3)
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(width: 340)
                    .fixedSize(horizontal: false, vertical: true)
                    .alignmentGuide(.bottom) { d in d[.top] - 44 }
            }
            .animation(.easeInOut(duration: 0.6), value: session.showsLens)
    }

    private static let returnWidth: CGFloat = 420
    private static let returnOrbHeight: CGFloat = 190

    /// Welcome back above the orb, the step's pieces below it.
    private func returnPage<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        centeredOrb(height: Self.returnOrbHeight)
            .overlay(alignment: .top) {
                VStack(spacing: 12) {
                    Text(DemoCopy.welcomeBack)
                        .font(FallowType.display(40))
                        .foregroundStyle(Theme.ink)
                    Eyebrow(text: DemoCopy.different)
                }
                .fixedSize()
                .alignmentGuide(.top) { d in d[.bottom] + 12 }
            }
            .overlay(alignment: .top) {
                VStack(spacing: 16) {
                    content()
                }
                .frame(width: Self.returnWidth)
                .alignmentGuide(.top) { _ in -Self.returnOrbHeight - 24 }
            }
    }

    private var doorway: some View {
        returnPage {
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow(text: "You left with")
                ThoughtText(text: session.thought)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(22)
            .padding(.trailing, 18)
            .glass(radius: 22)
            .overlay(alignment: .topTrailing) { leaveMark }

            VStack(alignment: .leading, spacing: 10) {
                voiceStatus(for: .reflection)
                ThoughtComposer(
                    text: $session.reflection,
                    placeholder: "Say it, or write it.",
                    isRecording: isListening(.reflection),
                    onMic: { toggleListening(.reflection) },
                    onSubmit: session.confirmReflection
                )
            }

            #if DEBUG
            if reflectionIsEmpty && !voice.isBusy {
                QuietButton(title: DemoCopy.showThought) { session.reflection = DemoCopy.reflection }
            }
            #endif
        }
    }

    private var reflectionIsEmpty: Bool {
        session.reflection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var beforeAfter: some View {
        returnPage {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow(text: DemoCopy.beforeLabel)
                    ThoughtText(text: session.thought, color: Theme.mute)
                }
                Rectangle()
                    .fill(Theme.rim)
                    .frame(height: 1)
                    .padding(.vertical, 22)
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow(text: DemoCopy.afterLabel)
                    ThoughtText(text: session.reflection)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .padding(.trailing, 14)
            .glass(radius: 22)
            .overlay(alignment: .topTrailing) { leaveMark }

            PrimaryButton(title: DemoCopy.goBack, action: session.goBackIn)
                .padding(.top, 4)
        }
    }

    private var leaveMark: some View {
        LeaveButton(action: session.leave)
            .padding(10)
    }
}

/// A behind-window blur clipped to rounded corners, kept in the light appearance so ink text stays legible.
struct FrostedGlass: NSViewRepresentable {
    var cornerRadius: CGFloat

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        view.appearance = NSAppearance(named: .aqua)
        view.maskImage = Self.mask(cornerRadius)
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}

    private static func mask(_ radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}

struct LeaveButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.ink)
                .frame(width: 24, height: 24)
                .glass(radius: 12)
                .contentShape(Circle())
        }
        .buttonStyle(PressableStyle())
        .environment(\.colorScheme, .light)
        .help("Leave")
        .accessibilityLabel("Leave")
    }
}

/// Places a view by a screen point. Only the point animates; when the window itself
/// moves or resizes, the view stays put on screen.
private struct ScreenPlacement: ViewModifier, Animatable {
    var center: CGPoint
    var window: CGRect

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(center.x, center.y) }
        set { center = CGPoint(x: newValue.first, y: newValue.second) }
    }

    func body(content: Content) -> some View {
        content.position(x: center.x - window.minX, y: window.maxY - center.y)
    }
}

private struct OrbInput: ViewModifier {
    var session: SessionModel

    @ViewBuilder
    func body(content: Content) -> some View {
        switch session.phase {
        case .threshold, .holding:
            content.gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in session.pressHold() }
                    .onEnded { _ in session.releaseHold() }
            )
        case .dormant:
            content
        case .resting:
            content.onTapGesture { session.tapOrb() }
        default:
            content
        }
    }
}

private enum VoiceTarget {
    case thought
    case reflection

    func lives(in phase: OrbPhase) -> Bool {
        switch self {
        case .thought: phase == .capture
        case .reflection: phase == .returnDoorway || phase == .reflecting
        }
    }
}
