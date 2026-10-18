import SwiftUI
import UIKit

/// The environment behind every screen. One value, openness, carries it from a quiet
/// product surface to open space and back. Nature only appears once something is let go.
struct Atmosphere: View {
    var openness: Double
    var restScene: FallowDistance
    var drifting: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                Theme.canvas

                RadialGradient(
                    colors: [Theme.light.opacity(0.85), Theme.canvas.opacity(0)],
                    center: UnitPoint(x: 0.5, y: 0.4),
                    startRadius: 0,
                    endRadius: size.height * 0.62
                )
                .opacity(0.5 + 0.5 * ramp(openness, 0, 0.3))

                LinearGradient(
                    colors: [Color(hex: 0xF3D9B4), Color(hex: 0xE2B78A), Color(hex: 0xB98E68)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .opacity(0.75 * ramp(openness, 0.12, 0.45))

                SceneImage(name: "SceneWall", size: size)
                    .blur(radius: 26, opaque: true)
                    .opacity(0.2 * ramp(openness, 0.08, 0.2) * (1 - ramp(openness, 0.35, 0.5)))

                SceneImage(name: "SceneThreshold", size: size)
                    .blur(radius: 30 - 18 * ramp(openness, 0.3, 0.75), opaque: true)
                    .scaleEffect(reduceMotion ? 1.06 : 1.1 - 0.05 * ramp(openness, 0.3, 0.8))
                    .brightness(0.08)
                    .opacity(0.85 * ramp(openness, 0.3, 0.55))

                RestLayer(
                    name: Self.sceneName(for: restScene),
                    size: size,
                    openness: openness,
                    drifting: drifting
                )
                .opacity(ramp(openness, 0.6, 0.9))

                Grain()
                    .opacity(0.05 * (1 - ramp(openness, 0.2, 0.6)))

                // Keeps editorial type legible at the top of bright skies.
                LinearGradient(
                    colors: [Theme.canvas.opacity(0.62), Theme.canvas.opacity(0.35), Theme.canvas.opacity(0)],
                    startPoint: .top,
                    endPoint: UnitPoint(x: 0.5, y: 0.36)
                )
                .opacity(ramp(openness, 0.45, 0.8))

                // Warm floor so light captions read over foliage.
                LinearGradient(
                    colors: [Color(hex: 0x2A1D12).opacity(0), Color(hex: 0x2A1D12).opacity(0.5)],
                    startPoint: UnitPoint(x: 0.5, y: 0.62),
                    endPoint: .bottom
                )
                .opacity(ramp(openness, 0.6, 0.9))
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    static func sceneName(for distance: FallowDistance) -> String {
        switch distance {
        case .breath: "SceneWall"
        case .someDistance: "SceneValley"
        case .sleepOnIt: "SceneWater"
        case .openEnded: "SceneMeadow"
        }
    }
}

func ramp(_ value: Double, _ start: Double, _ end: Double) -> Double {
    guard end > start else { return value >= end ? 1 : 0 }
    let t = min(1, max(0, (value - start) / (end - start)))
    return t * t * (3 - 2 * t)
}

private struct SceneImage: View {
    var name: String
    var size: CGSize

    private static var cache: [String: UIImage] = [:]

    var body: some View {
        if let image = Self.load(name) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .clipped()
        }
    }

    private static func load(_ name: String) -> UIImage? {
        if let cached = cache[name] { return cached }
        let image = UIImage(named: "\(name).jpg")
        cache[name] = image
        return image
    }
}

/// The open scene. It sharpens as openness completes and drifts only while resting.
private struct RestLayer: View {
    var name: String
    var size: CGSize
    var openness: Double
    var drifting: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let settle = ramp(openness, 0.6, 1)
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: !drifting || reduceMotion)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let live = drifting && !reduceMotion
            SceneImage(name: name, size: size)
                .scaleEffect(reduceMotion ? 1.04 : 1.12 - 0.08 * settle + (live ? 0.008 * sin(t / 11) : 0))
                .offset(
                    x: live ? 5 * sin(t / 17) : 0,
                    y: live ? 3 * cos(t / 23) : 0
                )
                .blur(radius: 24 - 21 * settle, opaque: true)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }
}

/// Fine paper grain so the neutral surface is not a flat fill.
private struct Grain: View {
    var body: some View {
        Canvas { context, size in
            var seed: UInt64 = 0x9E37_79B9_7F4A_7C15
            func next() -> Double {
                seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                return Double(seed >> 33) / Double(UInt32.max >> 1)
            }
            let count = Int(size.width * size.height / 90)
            for _ in 0..<count {
                let x = next() * size.width
                let y = next() * size.height
                let dark = next() > 0.5
                context.fill(
                    Path(CGRect(x: x, y: y, width: 1, height: 1)),
                    with: .color(dark ? Theme.ink : .white)
                )
            }
        }
        .drawingGroup()
    }
}
