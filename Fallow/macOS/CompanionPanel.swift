import AppKit

final class LeavePanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 36, height: 36),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 2)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        hidesOnDeactivate = false
    }
}

final class CompanionPanel: NSPanel {
    var canDrag: () -> Bool = { false }
    var onQuietClick: () -> Void = {}
    var onQuietMove: (_ ended: Bool) -> Void = { _ in }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 96, height: 96),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        hidesOnDeactivate = false
        animationBehavior = .none
        isMovable = false
    }

    override func mouseDown(with event: NSEvent) {
        guard canDrag() else {
            super.mouseDown(with: event)
            return
        }
        let start = NSEvent.mouseLocation
        let origin = frame.origin
        var moved = false
        while let next = nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            if next.type == .leftMouseUp { break }
            let mouse = NSEvent.mouseLocation
            let dx = mouse.x - start.x
            let dy = mouse.y - start.y
            if hypot(dx, dy) >= 4 {
                if !moved { NSCursor.closedHand.push() }
                moved = true
            }
            setFrameOrigin(NSPoint(x: origin.x + dx, y: origin.y + dy))
            onQuietMove(false)
        }
        if moved {
            NSCursor.pop()
            onQuietMove(true)
        } else {
            onQuietClick()
        }
    }
}
