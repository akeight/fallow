import SwiftUI
import UIKit

/// The environment behind every screen. One value, openness, carries it from a quiet
/// product surface to open space and back. Nature only appears once something is let go.
struct Atmosphere: View {
    var openness: Double
    var restScene: FallowDistance
    var drifting: Bool
    /// Opacity of the garden behind Home, Past, Pause and the return. 0 hides it.
    var garden: Double = 0
    /// Share of `garden` left at the top edge. Below 1 the garden fades up from the bottom.
    var gardenTop: Double = 1
    /// Darkens everything below the rest scene for light type. 0 is off, 1 is fully deep.
    var depth: Double = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                Theme.canvas

                // Lifted when faint so `Theme.muteOnScene` keeps 4.5:1 over its darkest areas.
                // Holds through distance and release (openness 0.15), then gives way to the scene.
                SceneImage(name: "HomeGarden", size: size)
                    .brightness(0.24 * (1 - depth))
                    .opacity(garden * (1 - ramp(openness, 0.15, 0.4)))
                    .mask(LinearGradient(colors: [.black.opacity(gardenTop), .black], startPoint: .top, endPoint: .bottom))
                    .animation(.easeInOut(duration: reduceMotion ? 0.3 : 1.2), value: garden)
                    .animation(.easeInOut(duration: reduceMotion ? 0.3 : 1.2), value: gardenTop)

                RadialGradient(
                    colors: [Theme.light.opacity(0.85), Theme.canvas.opacity(0)],
                    center: UnitPoint(x: 0.5, y: 0.4),
                    startRadius: 0,
                    endRadius: size.height * 0.62
                )
                .opacity((0.5 + 0.5 * ramp(openness, 0, 0.3)) * (1 - depth))

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

                // Deepest at the bottom, a little lighter behind the titles.
                LinearGradient(
                    colors: [Color(hex: 0x241B13).opacity(0.48), Color(hex: 0x241B13).opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .opacity(depth * (1 - ramp(openness, 0.15, 0.4)))

                RestLayer(
                    name: restScene.sceneName,
                    size: size,
                    openness: openness,
                    drifting: drifting
                )
                .opacity(ramp(openness, 0.6, 0.9))

                // A thin frost over the open scene; the text adds its own haze.
                Theme.canvas
                    .opacity(0.2 * ramp(openness, 0.6, 0.9))

                Grain()
                    .opacity(0.05 * (1 - ramp(openness, 0.2, 0.6)))

                // Keeps editorial type legible at the top of bright skies.
                LinearGradient(
                    colors: [Theme.canvas.opacity(0.62), Theme.canvas.opacity(0.35), Theme.canvas.opacity(0)],
                    startPoint: .top,
                    endPoint: UnitPoint(x: 0.5, y: 0.36)
                )
                .opacity(ramp(openness, 0.45, 0.8))
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
                .blur(radius: 24 - 19.5 * settle, opaque: true)
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
