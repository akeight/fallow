import AppKit
import SwiftUI

struct CompanionView: View {
    @Bindable var session: SessionModel
    var config: OrbTuningConfig
    var layout: CompanionLayout
    var syncChrome: () -> Void
    var syncVeil: () -> Void
    var openTuner: () -> Void
    @State private var sounds = BreakSounds()
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
            content
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
        .onExitCommand(perform: session.leave)
        .contextMenu {
            #if DEBUG
            Button("Tune orb") { openTuner() }
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
            syncChrome()
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
                items: StuckKind.allCases.map { ($0.title, $0 == session.stuck) },
                select: { session.chooseStuck(StuckKind.allCases[$0]) }
            )
        case .chooseDistance:
            choices(
                prompt: DemoCopy.distancePrompt,
                items: DistanceKind.allCases.map { ($0.title, $0 == session.distance) },
                select: { session.chooseDistance(DistanceKind.allCases[$0]) }
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
        case .capture: session.thoughtIsCaptured ? "capture-kept" : "capture"
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

    private var capture: some View {
        VStack(alignment: .leading, spacing: 0) {
            card {
                Text(DemoCopy.carrying)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                if session.thoughtIsCaptured {
                    Text(session.thought)
                        .font(FallowType.macProcess)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    quietButton(DemoCopy.keep, action: session.confirmThought)
                } else {
                    Text("Voice, or text. The canvas stays visible.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.mute)
                    quietButton(DemoCopy.showThought, action: session.revealThought)
                }
            }
            HStack {
                Spacer(minLength: 0)
                orbSpace
            }
        }
        .padding(12)
    }

    private func choices(prompt: String, items: [(String, Bool)], select: @escaping (Int) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            card {
                Text(prompt)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 6) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        Button {
                            select(index)
                        } label: {
                            HStack {
                                Text(item.0)
                                    .font(.system(size: 14, weight: item.1 ? .medium : .regular))
                                    .foregroundStyle(Theme.ink)
                                Spacer(minLength: 8)
                                if item.1 {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(Theme.ink)
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(
                                Color.white.opacity(item.1 ? 0.78 : 0.26),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Color.white.opacity(item.1 ? 0.9 : 0.45), lineWidth: 1)
                            )
                            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            HStack {
                Spacer(minLength: 0)
                orbSpace
            }
        }
        .padding(12)
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
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .fixedSize()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .frostedCard(radius: 16)
                    .alignmentGuide(.bottom) { d in d[.top] - 18 }
            }
    }

    private var resting: some View {
        centeredOrb(height: config.restSize * config.verticalStretch * 0.8)
            .overlay(alignment: .top) {
                VStack(spacing: 14) {
                    FallowWordmark(size: 34)
                    Eyebrow(text: DemoCopy.restingHere)
                }
                .fixedSize()
                .alignmentGuide(.top) { d in d[.bottom] + 40 }
            }
            .overlay(alignment: .bottom) {
                Text(session.showsLens ? DemoCopy.lens : DemoCopy.returnWhenReady)
                    .id(session.showsLens)
                    .transition(.opacity)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.mute)
                    .multilineTextAlignment(.center)
                    .fixedSize()
                    .alignmentGuide(.bottom) { d in d[.top] - 40 }
            }
            .animation(.easeInOut(duration: 0.6), value: session.showsLens)
    }

    /// Welcome back above the orb, the step's cards below it.
    private func returnPage<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        centeredOrb(height: 190)
            .overlay(alignment: .top) {
                VStack(spacing: 12) {
                    Text(DemoCopy.welcomeBack)
                        .font(FallowType.display(40))
                        .foregroundStyle(Theme.ink)
                    Eyebrow(text: DemoCopy.different)
                }
                .fixedSize()
                .alignmentGuide(.top) { d in d[.bottom] + 8 }
            }
            .overlay(alignment: .top) {
                VStack(spacing: 12) {
                    content()
                }
                .frame(width: 400)
                .alignmentGuide(.top) { d in -190 - 8 }
            }
    }

    private var doorway: some View {
        returnPage {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "scribble.variable")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.mute)
                    .padding(.top, 2)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 8) {
                    Text("“\(session.thought)”")
                        .font(FallowType.macProcess)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(leftWith)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.ash)
                }
                Spacer(minLength: 0)
            }
            .padding(18)
            .padding(.trailing, 20)
            .frostedCard()
            .overlay(alignment: .topTrailing) { leaveMark }

            HStack(spacing: 10) {
                TextField(DemoCopy.different, text: $session.reflection)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.ink)
                    .onSubmit(session.confirmReflection)
                Button(action: session.confirmReflection) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.8), in: Circle())
                        .overlay(Circle().strokeBorder(Color.white, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help("Continue")
                .accessibilityLabel("Continue")
            }
            .padding(.leading, 18)
            .padding(.trailing, 8)
            .padding(.vertical, 8)
            .frostedCard()

            if session.reflection.isEmpty {
                Button(DemoCopy.showThought) {
                    session.reflection = DemoCopy.reflection
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(Theme.ash)
            }
        }
    }

    private var leftWith: String {
        guard let distance = session.distance else { return DemoCopy.project }
        return "\(DemoCopy.project) · \(distance.title)"
    }

    private var beforeAfter: some View {
        returnPage {
            VStack(alignment: .leading, spacing: 8) {
                Text(DemoCopy.beforeLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.ash)
                Text(DemoCopy.before)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.mute)
                    .fixedSize(horizontal: false, vertical: true)
                Text(DemoCopy.afterLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.ash)
                    .padding(.top, 12)
                Text(session.reflection.isEmpty ? DemoCopy.after : session.reflection)
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .padding(.trailing, 20)
            .frostedCard()
            .overlay(alignment: .topTrailing) { leaveMark }

            Button(action: session.goBackIn) {
                HStack(spacing: 8) {
                    Text(DemoCopy.goBack)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 20)
                .padding(.vertical, 11)
                .frostedCard(radius: 20)
            }
            .buttonStyle(.plain)
        }
    }

    private var leaveMark: some View {
        LeaveButton(action: session.leave)
            .padding(8)
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(18)
        .padding(.trailing, 20)
        .frame(width: 300, alignment: .leading)
        .frostedCard()
        .overlay(alignment: .topTrailing) { leaveMark }
    }

    private func quietButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Theme.ink)
            .padding(.top, 4)
    }
}

extension View {
    /// Frosted macOS glass: the desktop blurs through, warmed by a translucent paper tint.
    func frostedCard(radius: CGFloat = 18) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .circular)
        return background {
            ZStack {
                FrostedGlass(cornerRadius: radius)
                shape.fill(
                    LinearGradient(
                        colors: [Theme.paper.opacity(0.62), Theme.paper.opacity(0.4)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .overlay(
            shape.strokeBorder(
                LinearGradient(
                    colors: [Color.white.opacity(0.75), Color.white.opacity(0.18)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1
            )
        )
        .shadow(color: Color(hex: 0x5C4A32).opacity(0.12), radius: 14, y: 6)
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
                .frame(width: 22, height: 22)
                .background {
                    ZStack {
                        FrostedGlass(cornerRadius: 11)
                        Circle().fill(Theme.paper.opacity(0.5))
                    }
                }
                .overlay(Circle().strokeBorder(Color.white.opacity(0.6), lineWidth: 1))
        }
        .buttonStyle(.plain)
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
