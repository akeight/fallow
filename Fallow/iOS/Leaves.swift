import SwiftUI
import UIKit

/// Leaves mark a change of state: shedding, making space. They never decorate a working screen.
enum LeafMode: Equatable {
    case off
    case release
    /// Release density for a few seconds while the thought recedes, then the resting trickle.
    case afterRelease
    case resting
    /// Nothing new. Leaves already falling fade out.
    case draining
}

enum LeafBand: Int {
    case back
    case mid
    case front
}

struct LeafEmitterConfig {
    var maxLeaves: Int
    /// Seconds between spawns at full intensity.
    var spawnInterval: ClosedRange<Double>
    var sizeScale: Double
    var drift: ClosedRange<Double>
    var fallDuration: ClosedRange<Double>
    var opacity: ClosedRange<Double>
    var backBlur: ClosedRange<Double>
    var frontChance: Double
    var backChance: Double

    static let release = LeafEmitterConfig(
        maxLeaves: 8,
        spawnInterval: 0.5...1.0,
        sizeScale: 1,
        drift: -70...70,
        fallDuration: 6...9,
        opacity: 0.35...0.8,
        backBlur: 1.5...2,
        frontChance: 0.1,
        backChance: 0.4
    )

    static let resting = LeafEmitterConfig(
        maxLeaves: 2,
        spawnInterval: 8...15,
        sizeScale: 0.85,
        drift: -40...40,
        fallDuration: 10...14,
        opacity: 0.35...0.55,
        backBlur: 1.5...2,
        frontChance: 0.06,
        backChance: 0.5
    )

    static let returning = LeafEmitterConfig(
        maxLeaves: 0,
        spawnInterval: 1...1,
        sizeScale: 1,
        drift: 0...0,
        fallDuration: 1...1,
        opacity: 0...0,
        backBlur: 0...0,
        frontChance: 0,
        backChance: 0
    )
}

struct LeafParticle {
    var sprite: Int
    var band: LeafBand
    var birth: TimeInterval
    var startX: Double
    var size: Double
    var opacity: Double
    var rotation: Double
    var spin: Double
    var drift: Double
    var duration: Double
    var wobbleAmplitude: Double
    var wobbleFrequency: Double
    var wobblePhase: Double
    var blur: Double
    /// Reduce Motion: a short slow drift that fades rather than crossing the screen.
    var fadesInPlace: Bool

    func isFinished(at time: TimeInterval) -> Bool {
        time - birth > duration
    }

    /// Position, angle, flutter, and alpha at a moment. Pure, so frames never accumulate error.
    func pose(at time: TimeInterval, in size: CGSize) -> (point: CGPoint, angle: Double, flutter: Double, alpha: Double)? {
        let u = (time - birth) / duration
        guard u >= 0, u <= 1 else { return nil }
        let swing = u * wobbleFrequency * 2 * .pi + wobblePhase
        let sway = sin(swing)
        let travel = fadesInPlace ? 0.16 : 1
        let fall = (u * 0.8 + u * u * 0.2) * travel
        let startY = fadesInPlace ? size.height * Double.random(in: 0.2...0.4, seed: birth) : -30
        let endY = size.height + 30
        // A leaf lifts a little at the end of each swing, like it is catching air.
        let lift = fadesInPlace ? 0 : wobbleAmplitude * 0.18 * cos(2 * swing)
        let x = startX * size.width + drift * u * travel + wobbleAmplitude * sway * (fadesInPlace ? 0.3 : 1)
        let y = startY + (endY - startY) * fall - lift
        let angle = fadesInPlace ? rotation : rotation + spin * u + sway * 16
        let flutter = fadesInPlace ? 1 : 0.72 + 0.28 * abs(cos(swing * 0.5))
        let alpha: Double
        if fadesInPlace {
            alpha = sin(.pi * u)
        } else {
            let fadeIn = min(1, u / 0.1)
            let fadeOut = min(1, (1 - u) / 0.15)
            alpha = fadeIn * fadeOut
        }
        return (CGPoint(x: x, y: y), angle, flutter, alpha * opacity)
    }
}

/// Owns the particles. Not observed: the leaf layer's timeline drives it.
final class LeafEmitter {
    private(set) var particles: [LeafParticle] = []
    private var mode: LeafMode = .off
    private var modeStart: TimeInterval = 0
    private var nextSpawn: TimeInterval = 0
    private var drainStart: TimeInterval?
    private var lastTick: TimeInterval = 0

    func tick(now: TimeInterval, mode next: LeafMode, intensity: Double, reduced: Bool) {
        guard now != lastTick else { return }
        lastTick = now
        if next != mode {
            mode = next
            modeStart = now
            drainStart = next == .draining ? now : nil
            if next == .resting {
                nextSpawn = now + Double.random(in: 2...5)
            } else {
                nextSpawn = min(nextSpawn, now + 0.3)
            }
        }
        particles.removeAll { $0.isFinished(at: now) || drainFaded(now) }

        let (config, strength) = activeConfig(now: now, intensity: intensity, reduced: reduced)
        guard let config, strength > 0 else { return }
        let target = max(1, Int((Double(config.maxLeaves) * min(1, strength)).rounded()))
        let cap = reduced ? min(2, target) : target
        guard particles.count < cap, now >= nextSpawn else { return }
        particles.append(make(config, now: now, reduced: reduced))
        let base = Double.random(in: config.spawnInterval)
        nextSpawn = now + base / max(0.25, min(1, strength))
    }

    func drainAlpha(at time: TimeInterval) -> Double {
        guard let drainStart else { return 1 }
        return max(0, 1 - (time - drainStart) / 1.5)
    }

    private func drainFaded(_ now: TimeInterval) -> Bool {
        drainAlpha(at: now) <= 0
    }

    private func activeConfig(now: TimeInterval, intensity: Double, reduced: Bool) -> (LeafEmitterConfig?, Double) {
        switch mode {
        case .off:
            return (nil, 0)
        case .draining:
            return (.returning, 0)
        case .release:
            return (.release, intensity)
        case .afterRelease:
            if now - modeStart < 4 { return (.release, 1) }
            return reduced ? (nil, 0) : (.resting, 1)
        case .resting:
            return reduced ? (nil, 0) : (.resting, 1)
        }
    }

    private func make(_ config: LeafEmitterConfig, now: TimeInterval, reduced: Bool) -> LeafParticle {
        let roll = Double.random(in: 0...1)
        let band: LeafBand = roll < config.frontChance ? .front : (roll < config.frontChance + config.backChance ? .back : .mid)
        let size: Double
        switch band {
        case .back:
            size = Double.random(in: 10...14)
        case .mid:
            size = Double.random(in: 0...1) < 0.67 ? Double.random(in: 11...14) : Double.random(in: 14...20)
        case .front:
            size = Double.random(in: 20...26)
        }
        let startX: Double = switch band {
        case .front: Bool.random() ? Double.random(in: -0.02...0.18) : Double.random(in: 0.82...1.02)
        default: Double.random(in: 0.04...0.96)
        }
        // Two uniforms average toward the middle of the range, where most leaves should sit.
        let opacity = (Double.random(in: config.opacity) + Double.random(in: config.opacity)) / 2
        let bandOpacity: Double = band == .back ? 0.8 : 1
        let spinSign: Double = Bool.random() ? 1 : -1
        return LeafParticle(
            sprite: Int.random(in: 0...1),
            band: band,
            birth: now + Double.random(in: 0...0.4),
            startX: startX,
            size: size * config.sizeScale,
            opacity: opacity * bandOpacity,
            rotation: Double.random(in: -60...60),
            spin: reduced ? 0 : spinSign * Double.random(in: 20...90),
            drift: Double.random(in: config.drift),
            duration: Double.random(in: config.fallDuration) * (reduced ? 1.3 : 1),
            wobbleAmplitude: Double.random(in: 10...28),
            wobbleFrequency: Double.random(in: 1.2...2.6),
            wobblePhase: Double.random(in: 0...(2 * .pi)),
            blur: band == .back ? Double.random(in: config.backBlur) : (band == .mid ? 0.4 : 0),
            fadesInPlace: reduced
        )
    }
}

struct LeafLayerView: View {
    var emitter: LeafEmitter
    var bands: Set<LeafBand>
    var mode: LeafMode
    var intensity: Double
    /// Only one layer advances the emitter each frame.
    var drives: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let sprites: [UIImage] = ["Leaf1", "Leaf2"].compactMap {
        UIImage(named: "\($0).png")
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                if drives {
                    emitter.tick(now: now, mode: mode, intensity: intensity, reduced: reduceMotion)
                }
                guard !Self.sprites.isEmpty else { return }
                let resolved = Self.sprites.map { context.resolve(Image(uiImage: $0)) }
                let drain = emitter.drainAlpha(at: now)
                for leaf in emitter.particles where bands.contains(leaf.band) {
                    guard let pose = leaf.pose(at: now, in: size) else { continue }
                    let sprite = resolved[leaf.sprite % resolved.count]
                    let aspect = sprite.size.height / max(1, sprite.size.width)
                    let width = CGFloat(leaf.size)
                    let height = width * aspect
                    context.drawLayer { layer in
                        layer.opacity = pose.alpha * drain
                        if leaf.blur > 0.05 {
                            layer.addFilter(.blur(radius: CGFloat(leaf.blur)))
                        }
                        layer.translateBy(x: pose.point.x, y: pose.point.y)
                        layer.rotate(by: .degrees(pose.angle))
                        layer.scaleBy(x: CGFloat(pose.flutter), y: 1)
                        layer.draw(sprite, in: CGRect(x: -width / 2, y: -height / 2, width: width, height: height))
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private extension Double {
    /// Stable per-leaf randomness for values computed every frame.
    static func random(in range: ClosedRange<Double>, seed: Double) -> Double {
        let x = sin(seed * 12.9898) * 43758.5453
        let unit = x - x.rounded(.down)
        return range.lowerBound + (range.upperBound - range.lowerBound) * unit
    }
}
