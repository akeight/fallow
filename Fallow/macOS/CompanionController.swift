import AppKit
import SwiftUI

@MainActor
final class CompanionController {
    private let session: SessionModel
    private let config: OrbTuningConfig
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
            self?.session.phase == .dormant
        }
        panel.onQuietClick = { [weak self] in
            self?.session.tapOrb()
        }
        panel.onQuietMove = { [weak self] ended in
            guard let self else { return }
            self.rememberPlace()
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
        let size = panelSize
        let frame = panelFrame(size: size, screen: screen)
        if frame.integral != panel.frame.integral {
            panel.setFrame(frame, display: true, animate: true)
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
        softening?.setRecession(
            amount: curved * config.workspaceRecession,
            blur: config.workspaceBlur,
            contrast: config.workspaceContrast
        )
        softening?.setLeftWash(amount: showsLeftPage ? curved : 0)
        placeLeave()
    }

    private var showsLeftPage: Bool {
        switch session.phase {
        case .returnDoorway, .reflecting, .beforeAfter:
            true
        case .resting:
            session.showsLens
        default:
            false
        }
    }

    private func placeLeave() {
        guard let screen = panel.screen ?? NSScreen.main else { return }
        let veil = OrbMotion.veilAmount(raw: session.softness)
        let overlayIsUp = veil > 0.04 && session.phase != .dormant
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
            let side = CGFloat(max(180, config.idleSize * 2.2))
            return NSSize(width: side, height: side)
        case .capture:
            return session.thoughtIsCaptured ? NSSize(width: 480, height: 540) : NSSize(width: 480, height: 500)
        case .classifyStuck:
            return NSSize(width: 480, height: 680)
        case .chooseDistance:
            return NSSize(width: 480, height: 640)
        case .threshold, .holding:
            let side = CGFloat(max(420, config.holdEndSize * 1.55 + 80))
            return NSSize(width: side, height: side + 36)
        case .resting where session.showsLens:
            return NSSize(width: 560, height: 440)
        case .resting:
            let side = CGFloat(max(230, config.restSize * 2.8))
            return NSSize(width: side, height: side)
        case .returnDoorway, .reflecting, .beforeAfter:
            return NSSize(width: 680, height: 480)
        }
    }

    private func panelFrame(size: NSSize, screen: NSScreen) -> NSRect {
        let visible = screen.visibleFrame
        switch session.phase {
        case .threshold, .holding:
            return NSRect(
                x: visible.midX - size.width * 0.72,
                y: visible.midY - size.height * 0.35,
                width: size.width,
                height: size.height
            )
        case .returnDoorway, .reflecting, .beforeAfter:
            return openFrame(size: size, visible: visible)
        case .resting where session.showsLens:
            return openFrame(size: size, visible: visible)
        case .dormant, .reentering:
            return NSRect(
                x: anchor.x - size.width,
                y: anchor.y,
                width: size.width,
                height: size.height
            )
        default:
            return fitted(
                NSRect(
                    x: anchor.x - size.width,
                    y: anchor.y,
                    width: size.width,
                    height: size.height
                ),
                within: visible
            )
        }
    }

    private func openFrame(size: NSSize, visible: NSRect) -> NSRect {
        NSRect(
            x: visible.minX + 48,
            y: visible.midY - size.height * 0.2,
            width: size.width,
            height: size.height
        )
    }
}
