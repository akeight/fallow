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
    #endif

    init(session: SessionModel, config: OrbTuningConfig) {
        self.session = session
        self.config = config
    }

    func start() {
        guard let screen = NSScreen.main else { return }
        let veil = SofteningPanel(screen: screen)
        softening = veil

        let visible = screen.visibleFrame
        anchor = CGPoint(x: visible.maxX - 20, y: visible.minY + 20)

        let host = NSHostingView(rootView: CompanionView(
            session: session,
            config: config,
            layout: layout,
            syncChrome: { [weak self] in self?.syncChrome() },
            syncVeil: { [weak self] in self?.syncVeil() },
            openTuner: { [weak self] in self?.showTuner() }
        ))
        host.sizingOptions = []
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = host
        let leaveHost = NSHostingView(rootView: LeaveButton { [weak self] in
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
        panel.orderFrontRegardless()
    }

    func syncChrome() {
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
        syncVeil()
        panel.orderFrontRegardless()
        if session.phase != .dormant {
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKey()
        }
    }

    func syncVeil() {
        let curved = OrbMotion.veilAmount(raw: session.softness)
        let veil = isHoldStep ? 0.32 + 0.68 * curved : curved
        softening?.setRecession(
            amount: veil * config.workspaceRecession,
            blur: config.workspaceBlur,
            contrast: config.workspaceContrast
        )
        let landscape = isHoldStep ? 0.18 + 0.82 * curved : curved
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
            panel.setFrame(window, display: true)
        }
    }

    /// The first steps keep the orb exactly where it was resting; hold, rest, and return center it.
    private func orbCenter(in area: NSRect) -> CGPoint {
        switch session.phase {
        case .capture, .classifyStuck, .chooseDistance:
            homeCenter
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

    private func fitted(_ frame: NSRect, within visible: NSRect) -> NSRect {
        var frame = frame
        if frame.maxX > visible.maxX { frame.origin.x -= frame.maxX - visible.maxX }
        if frame.minX < visible.minX { frame.origin.x += visible.minX - frame.minX }
        if frame.maxY > visible.maxY { frame.origin.y -= frame.maxY - visible.maxY }
        if frame.minY < visible.minY { frame.origin.y += visible.minY - frame.minY }
        return frame
    }

    private func watchEscape() {
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53, let self else { return event }
            #if DEBUG
            if let tuner = self.tuner, tuner.isKeyWindow { return event }
            #endif
            guard self.session.phase != .dormant else { return event }
            self.session.leave()
            return nil
        }
    }

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
            return NSSize(width: 480, height: 600)
        case .classifyStuck:
            return NSSize(width: 480, height: 680)
        case .chooseDistance:
            return NSSize(width: 480, height: 640)
        case .threshold, .holding:
            let side = CGFloat(max(420, config.holdEndSize * 1.55 + 80))
            return NSSize(width: side, height: side + 36)
        case .resting:
            return NSSize(width: 520, height: 400)
        case .returnDoorway, .reflecting, .beforeAfter:
            return NSSize(width: 560, height: 720)
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
            // The card sits above the orb, whose slot is the bottom-right corner of this area.
            let half = CGFloat(OrbMotion.canvasExtent(phase: session.phase, config: config)) / 2
            let home = homeCenter
            return fitted(
                NSRect(
                    x: home.x + 12 + half - size.width,
                    y: home.y - 12 - half,
                    width: size.width,
                    height: size.height
                ),
                within: visible
            )
        }
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
