import AppKit
import CoreImage

/// A click-through veil. It blurs whatever is behind FALLOW and does not resize other apps.
final class SofteningPanel: NSPanel {
    private let root = NSView()
    private let effect = NSVisualEffectView()
    private let tint = NSView()
    private let landscape = NSView()
    private var landscapeTarget = -1.0
    private var hiding = false

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

        landscape.wantsLayer = true
        landscape.layer?.contents = Self.frosted(Self.fallbackScene)
        landscape.layer?.contentsGravity = .resizeAspectFill
        landscape.layer?.masksToBounds = true
        landscape.frame = root.bounds
        landscape.autoresizingMask = [.width, .height]
        landscape.alphaValue = 0
        let frost = NSView(frame: landscape.bounds)
        frost.wantsLayer = true
        frost.layer?.backgroundColor = NSColor(calibratedRed: 0.96, green: 0.94, blue: 0.9, alpha: 0.34).cgColor
        frost.autoresizingMask = [.width, .height]
        landscape.addSubview(frost)

        root.addSubview(effect)
        root.addSubview(landscape)

        contentView = root
        alphaValue = 0
    }

    func follow(_ screen: NSScreen) {
        setFrame(screen.frame, display: true)
    }

    /// A frosted landscape over the blurred desk. Below 1, the desk shows faintly through it.
    func setLandscape(amount: Double) {
        let target = min(1, max(0, amount))
        let step = abs(target - landscapeTarget)
        guard step > 0.005 else { return }
        landscapeTarget = target
        // Small steps come from the hold itself, frame by frame; only phase changes ease.
        guard step > 0.12 else {
            landscape.alphaValue = target
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = target > landscape.alphaValue ? 1.6 : 0.9
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            landscape.animator().alphaValue = target
        }
    }

    /// Crossfades to a frosted scene, or to the fallback landscape if the name is not bundled.
    func setScene(_ name: String) {
        guard name != sceneName, let image = Self.frosted(name) ?? Self.frosted(Self.fallbackScene) else { return }
        sceneName = name
        let fade = CATransition()
        fade.type = .fade
        fade.duration = landscape.alphaValue > 0.01 ? 1.2 : 0
        fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        landscape.layer?.add(fade, forKey: "scene")
        landscape.layer?.contents = image
    }

    static let fallbackScene = "RestLandscape"
    private var sceneName = SofteningPanel.fallbackScene
    private static var frostedCache: [String: CGImage] = [:]

    /// Blurred once per scene; the images are small, so stretching them to the screen only softens them further.
    private static func frosted(_ name: String) -> CGImage? {
        if let cached = frostedCache[name] { return cached }
        guard let url = Bundle.main.url(forResource: name, withExtension: "jpg"),
              let source = CIImage(contentsOf: url) else { return nil }
        let frosted = source.clampedToExtent()
            .applyingGaussianBlur(sigma: 9)
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 0.8,
                kCIInputBrightnessKey: 0.06
            ])
            .cropped(to: source.extent)
        let image = CIContext().createCGImage(frosted, from: source.extent)
        frostedCache[name] = image
        return image
    }

    /// `amount` is already the curved recession, 0 through 1.
    /// Blur and contrast are the completion sliders; they scale that curve.
    func setRecession(amount: Double, blur: Double, contrast: Double) {
        let shaped = min(1, max(0, amount))
        if shaped <= 0.012 {
            guard isVisible, !hiding else { return }
            hiding = true
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.4
                animator().alphaValue = 0
            } completionHandler: { [weak self] in
                guard let self, self.hiding else { return }
                self.hiding = false
                self.orderOut(nil)
            }
            return
        }
        if hiding {
            hiding = false
            animator().alphaValue = 1
        }
        if !isVisible {
            alphaValue = 0
            orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.6
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                animator().alphaValue = 1
            }
        }
        let blurMix = min(1, max(0, blur) / 40)
        effect.alphaValue = shaped * (0.22 + 0.78 * blurMix)
        tint.alphaValue = shaped * min(1, max(0, contrast))
    }
}
