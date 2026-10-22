import AppKit
import SwiftUI

/// Where things sit, in screen coordinates. The view converts them into the window.
@MainActor
@Observable
final class CompanionLayout {
    var window = CGRect.zero
    var content = CGRect.zero
    var orbCenter = CGPoint.zero
}

@MainActor
final class CompanionController {
    private let session: SessionModel
    private let config: OrbTuningConfig
    private let layout = CompanionLayout()
    private var shrinkTask: Task<Void, Never>?
    private let panel = CompanionPanel()
    private var softening: SofteningPanel?
    private var anchor = CGPoint.zero
    private var escapeMonitor: Any?
    private let leavePanel = LeavePanel()
    private var leaveShown = false
    #if DEBUG
    private var tuner: NSPanel?
    private var demo: DemoController?

    init(session: SessionModel, config: OrbTuningConfig, demo: DemoController? = nil) {
        self.session = session
        self.config = config
        self.demo = demo
    }
    #else
    init(session: SessionModel, config: OrbTuningConfig) {
        self.session = session
        self.config = config
    }
    #endif

    func start() {
        guard let screen = NSScreen.main else { return }
        let veil = SofteningPanel(screen: screen)
        softening = veil

        let visible = screen.visibleFrame
        anchor = CGPoint(x: visible.maxX - 20, y: visible.minY + 20)

        var view = CompanionView(
            session: session,
            config: config,
            layout: layout,
            syncChrome: { [weak self] in self?.syncChrome() },
            syncVeil: { [weak self] in self?.syncVeil() },
            openTuner: { [weak self] in self?.showTuner() }
        )
        #if DEBUG
        view.runDemo = { [weak self] scenario in self?.demo?.run(scenario) }
        #endif
        let host = CompanionHostingView(rootView: view)
        host.sizingOptions = []
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = host
        let leaveHost = CompanionHostingView(rootView: LeaveButton { [weak self] in
            self?.session.leave()
        })
        leaveHost.sizingOptions = []
        leavePanel.contentView = leaveHost
        panel.canDrag = { [weak self] in
            guard let self else { return false }
            return self.session.phase == .dormant && self.shrinkTask == nil
        }
        panel.onQuietClick = { [weak self] in
            self?.session.tapOrb()
        }
        panel.onQuietMove = { [weak self] ended in
            guard let self else { return }
            self.rememberPlace()
            let frame = self.panel.frame
            self.place(window: frame, area: frame, center: CGPoint(x: frame.midX, y: frame.midY))
            if ended, let screen = self.hostScreen() {
                self.softening?.follow(screen)
            }
        }
        watchEscape()
        syncChrome()
    }

    /// SwiftUI calls this from `onAppear` and `onChange`, which run inside the hosting view's layout.
    /// Resizing the panel there calls `-layoutSubtreeIfNeeded` on a view that is already being laid out.
    /// On current macOS that nested layout never returns, so Fallow has to be force-quit.
    private var chromeScheduled = false
    private var veilScheduled = false

    func syncChrome() {
        guard !chromeScheduled else { return }
        chromeScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.chromeScheduled = false
            self.applyChrome()
        }
    }

    func syncVeil() {
        guard !veilScheduled else { return }
        veilScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.veilScheduled = false
            self.applyVeil()
        }
    }

    private func applyChrome() {
        guard let screen = hostScreen() else { return }
        softening?.follow(screen)
        let area = panelFrame(size: panelSize, screen: screen)
        let center = orbCenter(in: area)
        shrinkTask?.cancel()
        shrinkTask = nil
        if session.phase != .dormant {
            place(window: screen.visibleFrame, area: area, center: center)
        } else if panel.frame.width > area.width + 1 {
            // Let the orb finish gliding home before the window closes in around it.
            layout.content = area
            layout.orbCenter = center
            shrinkTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 1_150_000_000)
                guard let self, !Task.isCancelled, self.session.phase == .dormant else { return }
                self.shrinkTask = nil
                self.place(window: area, area: area, center: center)
            }
        } else {
            place(window: area, area: area, center: center)
        }
        panel.alphaValue = 1
        applyVeil()
        panel.orderFrontRegardless()
        if session.phase != .dormant {
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKey()
        }
    }

    private func applyVeil() {
        let curved = OrbMotion.veilAmount(raw: session.softness)
        let veil = isHoldStep ? 0.32 + 0.68 * curved : curved
        softening?.setRecession(
            amount: veil * config.workspaceRecession,
            blur: config.workspaceBlur,
            contrast: config.workspaceContrast
        )
        let landscape = isHoldStep ? 0.18 + 0.82 * curved : curved
        if let scene { softening?.setScene(scene) }
        softening?.setLandscape(amount: landscape * landscapeStrength)
        placeLeave()
    }

    /// The hold screen opens on a light frost that thickens as the hold builds.
    private var isHoldStep: Bool {
        switch session.phase {
        case .threshold, .holding:
            true
        default:
            false
        }
    }

    /// Grows with the hold, full while resting, thinner on the way back so the blurred desk shows again.
    private var landscapeStrength: Double {
        switch session.phase {
        case .threshold, .holding, .resting:
            1
        case .returnDoorway, .reflecting, .beforeAfter:
            0.88
        default:
            0
        }
    }

    /// The same scenes as the phone: the threshold to let go, the chosen distance to rest, the garden to return.
    private var scene: String? {
        switch session.phase {
        case .threshold, .holding:
            "SceneThreshold"
        case .resting:
            session.distance?.sceneName ?? SofteningPanel.fallbackScene
        case .returnDoorway, .reflecting, .beforeAfter:
            "HomeGarden"
        default:
            nil
        }
    }

    private func placeLeave() {
        guard let screen = panel.screen ?? NSScreen.main else { return }
        let veil = OrbMotion.veilAmount(raw: session.softness)
        let overlayIsUp = (veil > 0.04 || isHoldStep) && session.phase != .dormant
        guard overlayIsUp else {
            if leaveShown {
                leavePanel.orderOut(nil)
                leaveShown = false
            }
            return
        }
        let visible = screen.visibleFrame
        let side: CGFloat = 36
        let frame = NSRect(
            x: visible.maxX - 18 - side,
            y: visible.maxY - 14 - side,
            width: side,
            height: side
        )
        if !leaveShown || frame.integral != leavePanel.frame.integral {
            leavePanel.setFrame(frame, display: true)
            leavePanel.orderFrontRegardless()
            leaveShown = true
        }
    }

    /// Dormant, the window hugs the orb so the desk stays clickable. Otherwise it spans the screen
    /// and the orb glides inside it.
    /// A window resize never animates the orb, or it would sweep across the new window.
    private func place(window: NSRect, area: NSRect, center: CGPoint) {
        var still = Transaction()
        still.disablesAnimations = window.integral != layout.window.integral
        withTransaction(still) {
            layout.window = window
            layout.content = area
            layout.orbCenter = center
        }
        if window.integral != panel.frame.integral {
            // display: false avoids laying the hosting view out before this call returns.
            panel.setFrame(window, display: false)
        }
    }

    /// The first steps keep the orb exactly where it was resting; hold, rest, and return center it.
    private func orbCenter(in area: NSRect) -> CGPoint {
        switch session.phase {
        case .capture, .classifyStuck, .chooseDistance:
            homeCenter
        case .threshold, .holding:
            // A little below center, so the orb only grazes the pane above it. Screen y runs up.
            CGPoint(x: area.midX, y: area.midY - 30)
        default:
            CGPoint(x: area.midX, y: area.midY)
        }
    }

    private var homeSide: CGFloat {
        CGFloat(max(180, config.idleSize * 2.2))
    }

    private var homeCenter: CGPoint {
        CGPoint(x: anchor.x - homeSide / 2, y: anchor.y + homeSide / 2)
    }

    private func rememberPlace() {
        anchor = CGPoint(x: panel.frame.maxX, y: panel.frame.minY)
    }

    private func hostScreen() -> NSScreen? {
        let center = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
        if let match = NSScreen.screens.first(where: { $0.frame.contains(center) }) {
            return match
        }
        return panel.screen ?? NSScreen.main
    }

    private func watchEscape() {
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            #if DEBUG
            if let self, let scenario = Self.demoShortcut(event) {
                self.demo?.run(scenario)
                return nil
            }
            #endif
            guard event.keyCode == 53, let self else { return event }
            #if DEBUG
            if let tuner = self.tuner, tuner.isKeyWindow { return event }
            #endif
            guard self.session.phase != .dormant else { return event }
            self.session.leave()
            return nil
        }
    }

    #if DEBUG
    /// Control-Option-Command with 0 through 3 stages the presentation on this Mac.
    private static func demoShortcut(_ event: NSEvent) -> DemoController.Scenario? {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers == [.control, .option, .command] else { return nil }
        switch event.charactersIgnoringModifiers {
        case "0": return .reset
        case "1": return .macReleased
        case "2": return .macReturning
        case "3": return .complete
        default: return nil
        }
    }
    #endif

    func showTuner() {
        #if DEBUG
        if tuner == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 72, y: 80, width: 440, height: 720),
                styleMask: [.titled, .closable, .resizable, .utilityWindow],
                backing: .buffered,
                defer: false
            )
            panel.title = "Orb tuner"
            panel.isFloatingPanel = true
            panel.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 2)
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            panel.contentView = NSHostingView(rootView: OrbTunerView(session: session, config: config))
            tuner = panel
        }
        tuner?.makeKeyAndOrderFront(nil)
        #endif
    }

    private var panelSize: NSSize {
        switch session.phase {
        case .dormant, .reentering:
            return NSSize(width: homeSide, height: homeSide)
        case .capture:
            return NSSize(width: 500, height: 720)
        case .classifyStuck:
            return NSSize(width: 500, height: 780)
        case .chooseDistance:
            return NSSize(width: 500, height: 720)
        case .threshold, .holding:
            let side = CGFloat(max(420, config.holdEndSize * 1.55 + 80))
            return NSSize(width: side, height: side + 36)
        case .resting:
            return NSSize(width: 520, height: 400)
        case .returnDoorway, .reflecting, .beforeAfter:
            return NSSize(width: 560, height: 820)
        }
    }

    private func panelFrame(size: NSSize, screen: NSScreen) -> NSRect {
        let visible = screen.visibleFrame
        switch session.phase {
        case .threshold, .holding, .resting, .returnDoorway, .reflecting, .beforeAfter:
            return centered(size: size, visible: visible)
        case .dormant, .reentering:
            return NSRect(
                x: anchor.x - size.width,
                y: anchor.y,
                width: size.width,
                height: size.height
            )
        default:
            return inputFrame(on: visible)
        }
    }

    /// Capture, the state, and the distance. The orb stays where it was.
    /// In the top half the card hangs under the orb, which rests on the card.
    /// In the bottom half the card sits above the orb, its bottom on the crown, and grows upward.
    private func inputFrame(on visible: NSRect) -> NSRect {
        let home = homeCenter
        let width = panelSize.width
        let x = min(max(home.x - width / 2, visible.minX + 8), visible.maxX - 8 - width)
        let upper = home.y >= visible.midY
        if upper {
            // Rest on the pane's top edge. The heading starts below that, so the orb does not cover it.
            let top = min(home.y - inputBody + 8, visible.maxY - 8)
            let bottom = visible.minY + 8
            let height = max(160, top - bottom)
            return NSRect(x: x, y: top - height, width: width, height: height)
        }
        let bottom = min(max(home.y + inputCrown, visible.minY + 8), visible.maxY - 168)
        let top = visible.maxY - 8
        let height = max(160, top - bottom)
        return NSRect(x: x, y: min(bottom, top - height), width: width, height: height)
    }

    /// Half the input orb's height. The upper card tucks just under this.
    private var inputBody: CGFloat {
        let diameter = config.idleSize * 1.14
        return CGFloat(diameter / 2 * config.verticalStretch)
    }

    /// The input orb's crown, plus a little air, so a taller prompt never settles onto the glass.
    private var inputCrown: CGFloat {
        inputBody + 12
    }

    private func centered(size: NSSize, visible: NSRect) -> NSRect {
        let height = min(size.height, visible.height - 32)
        return NSRect(
            x: visible.midX - size.width / 2,
            y: visible.midY - height / 2,
            width: size.width,
            height: height
        )
    }
}

/// A nested `-layoutSubtreeIfNeeded` never returns on current macOS, so the app has to be force-quit.
private final class CompanionHostingView<Content: View>: NSHostingView<Content> {
    private var layingOut = false

    override func layoutSubtreeIfNeeded() {
        guard !layingOut else { return }
        layingOut = true
        super.layoutSubtreeIfNeeded()
        layingOut = false
    }
}
