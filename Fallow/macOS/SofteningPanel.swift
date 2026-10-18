import AppKit

/// A click-through veil. It blurs whatever is behind FALLOW and does not resize other apps.
final class SofteningPanel: NSPanel {
    private let root = NSView()
    private let effect = NSVisualEffectView()
    private let tint = NSView()
    private let wash = NSView()
    private var washTarget = -1.0

    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        animationBehavior = .none

        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.clear.cgColor
        root.frame = NSRect(origin: .zero, size: screen.frame.size)

        effect.frame = root.bounds
        effect.autoresizingMask = [.width, .height]

        tint.wantsLayer = true
        tint.layer?.backgroundColor = NSColor(calibratedRed: 0.89, green: 0.86, blue: 0.82, alpha: 1).cgColor
        tint.alphaValue = 0
        tint.frame = effect.bounds
        tint.autoresizingMask = [.width, .height]
        effect.addSubview(tint)

        let gradient = CAGradientLayer()
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        let tone = NSColor(calibratedRed: 0.93, green: 0.89, blue: 0.82, alpha: 1)
        gradient.colors = [
            tone.withAlphaComponent(0.96).cgColor,
            tone.withAlphaComponent(0.72).cgColor,
            tone.withAlphaComponent(0.34).cgColor,
            tone.withAlphaComponent(0).cgColor
        ]
        gradient.locations = [0, 0.28, 0.62, 1]
        wash.wantsLayer = true
        wash.layer = gradient
        wash.alphaValue = 0
        root.addSubview(effect)
        root.addSubview(wash)

        contentView = root
        alphaValue = 0
        layoutWash()
    }

    func follow(_ screen: NSScreen) {
        setFrame(screen.frame, display: true)
        layoutWash()
    }

    /// A warm field on the left, fading out before the middle, behind the page copy.
    func setLeftWash(amount: Double) {
        layoutWash()
        let target = min(1, max(0, amount))
        guard abs(target - washTarget) > 0.02 else { return }
        washTarget = target
        NSAnimationContext.runAnimationGroup { context in
            context.duration = target > wash.alphaValue ? 0.85 : 0.5
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            wash.animator().alphaValue = target
        }
    }

    private func layoutWash() {
        let bounds = contentView?.bounds ?? .zero
        wash.frame = NSRect(x: 0, y: 0, width: bounds.width * 0.64, height: bounds.height)
        wash.layer?.frame = wash.bounds
    }

    /// `amount` is already the curved recession, 0 through 1.
    /// Blur and contrast are the completion sliders; they scale that curve.
    func setRecession(amount: Double, blur: Double, contrast: Double) {
        let shaped = min(1, max(0, amount))
        if shaped <= 0.012 {
            alphaValue = 0
            orderOut(nil)
            return
        }
        if !isVisible {
            orderFrontRegardless()
        }
        alphaValue = 1
        let blurMix = min(1, max(0, blur) / 40)
        effect.alphaValue = shaped * (0.22 + 0.78 * blurMix)
        tint.alphaValue = shaped * min(1, max(0, contrast))
    }
}
