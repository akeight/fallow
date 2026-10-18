import SwiftUI

struct OrbView: View {
    var session: SessionModel
    var config: OrbTuningConfig

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var hover = 0.0
    @State private var hoverPoint: CGPoint?
    @State private var settleStart: Date?
    @State private var returnStart: Date?
    @State private var lag = LightLag()
    @State private var pose = PoseEase()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let raw = OrbMotion.rawProgress(phase: session.phase, softness: session.softness)
            let lagged = lag.step(
                target: OrbMotion.holdEase(raw),
                delay: config.shellLightDelay,
                now: now,
                reduced: reduceMotion
            )
            let target = OrbMotion.resolve(
                phase: session.phase,
                softness: session.softness,
                config: config,
                time: now,
                hover: hover,
                hoverLocation: hover > 0 ? hoverPoint : nil,
                reduceMotion: reduceMotion,
                settleStart: settleStart,
                returnStart: returnStart,
                laggedEase: lagged
            )
            let holding: Bool = if case .holding = session.phase { true } else { false }
            let draw = pose.follow(target, now: now, tau: holding ? 0.28 : 1.05, reduced: reduceMotion)
            OrbCanvas(draw: draw, liftsForDarkDesktop: colorScheme == .dark)
                .frame(width: CGFloat(target.canvas), height: CGFloat(target.canvas))
        }
        .contentShape(Circle())
        #if os(macOS)
        .onContinuousHover { state in
            switch state {
            case .active(let location):
                hoverPoint = location
                guard session.phase == .dormant else { return }
                if hover < 1 {
                    withAnimation(.easeInOut(duration: config.attentiveDuration)) {
                        hover = 1
                    }
                }
            case .ended:
                withAnimation(.easeInOut(duration: config.attentiveDuration)) {
                    hover = 0
                }
            }
        }
        #endif
        .onChange(of: session.settleID) { _, id in
            if id > 0 {
                settleStart = .now
            }
        }
        .onChange(of: session.returnID) { _, id in
            if id > 0 {
                returnStart = .now
            }
        }
        .onChange(of: session.phase) { _, phase in
        if case .returnDoorway = phase {
            returnStart = .now
        }
        if hover != 0 {
            if case .dormant = phase {
            } else {
                hover = 0
            }
        }
        }
        .accessibilityLabel("FALLOW")
    }
}

private final class PoseEase {
    private var pose: OrbDraw?
    private var last = 0.0

    func follow(_ target: OrbDraw, now: TimeInterval, tau: Double, reduced: Bool) -> OrbDraw {
        guard var current = pose, !reduced else {
            pose = target
            last = now
            return target
        }
        let dt = last == 0 ? 0 : min(0.05, max(0, now - last))
        last = now
        let k = dt == 0 ? 1 : min(1, dt / max(0.05, tau))
        func mix(_ from: Double, _ to: Double) -> Double { from + (to - from) * k }
        current.diameter = mix(current.diameter, target.diameter)
        current.stretchX = mix(current.stretchX, target.stretchX)
        current.stretchY = mix(current.stretchY, target.stretchY)
        current.asymmetry = mix(current.asymmetry, target.asymmetry)
        current.deformation = mix(current.deformation, target.deformation)
        current.fold = mix(current.fold, target.fold)
        current.shellOpacity = mix(current.shellOpacity, target.shellOpacity)
        current.shellBlur = mix(current.shellBlur, target.shellBlur)
        current.warmth = mix(current.warmth, target.warmth)
        current.lightOpacity = mix(current.lightOpacity, target.lightOpacity)
        current.lightFraction = mix(current.lightFraction, target.lightFraction)
        current.lightBlur = mix(current.lightBlur, target.lightBlur)
        current.diffusion = mix(current.diffusion, target.diffusion)
        current.breathScale = mix(current.breathScale, target.breathScale)
        current.lightPulse = mix(current.lightPulse, target.lightPulse)
        current.dimple = mix(current.dimple, target.dimple)
        current.swirl = mix(current.swirl, target.swirl)
        current.arc = mix(current.arc, target.arc)
        current.arcPhase = target.arcPhase
        current.listen = mix(current.listen, target.listen)
        current.listenTime = target.listenTime
        current.depth = mix(current.depth, target.depth)
        let step = CGFloat(k)
        current.bias.width += (target.bias.width - current.bias.width) * step
        current.bias.height += (target.bias.height - current.bias.height) * step
        current.lightCenter.width += (target.lightCenter.width - current.lightCenter.width) * step
        current.lightCenter.height += (target.lightCenter.height - current.lightCenter.height) * step
        current.deformPhase = target.deformPhase
        current.canvas = target.canvas
        pose = current
        return current
    }
}

private final class LightLag {
    var value = 0.0
    var last = 0.0

    func step(target: Double, delay: Double, now: TimeInterval, reduced: Bool) -> Double {
        if reduced || delay <= 0.001 {
            value = target
            last = now
            return value
        }
        let dt = last == 0 ? 0 : min(0.05, now - last)
        last = now
        if dt == 0 {
            value = target
        } else {
            let tau = max(0.05, delay)
            value += (target - value) * min(1, dt / tau)
        }
        return value
    }
}

private struct OrbCanvas: View {
    var draw: OrbDraw
    var liftsForDarkDesktop: Bool

    var body: some View {
        Canvas { context, size in
            let path = shellPath(in: size)
            let m = shellMetrics(in: size)
            let reach = max(m.rx, m.ry)
            let light = draw.lightOpacity * draw.lightPulse
            let scale = max(0.6, CGFloat(draw.diameter / 110))
            let warmHalo = min(1, draw.depth)

            // Contact shadow: a tight core and a wide soft spread.
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: max(10, reach * 0.22)))
                layer.fill(
                    Path(ellipseIn: ellipse(cx: m.cx + m.rx * 0.06, cy: m.cy + m.ry * 0.9, width: m.rx * 1.9, height: max(10, m.ry * 0.5))),
                    with: .color(OrbPalette.shadow.color.opacity(0.26 * draw.shellOpacity))
                )
            }
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: max(4, reach * 0.07)))
                layer.fill(
                    Path(ellipseIn: ellipse(cx: m.cx + m.rx * 0.04, cy: m.cy + m.ry * 0.93, width: m.rx * 1.3, height: max(5, m.ry * 0.16))),
                    with: .color(OrbPalette.deepShadow.color.opacity(0.32 * draw.shellOpacity))
                )
            }
            // Warm light leaving the base and landing on the surface.
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: max(10, reach * 0.26)))
                layer.fill(
                    Path(ellipseIn: ellipse(cx: m.cx + draw.lightCenter.width * 0.5, cy: m.cy + m.ry * 0.96, width: m.rx * 1.1, height: max(8, m.ry * 0.34))),
                    with: .color(lightColor.color.opacity(light * (0.5 + 0.15 * warmHalo)))
                )
            }
            // Soft halo so the edge breathes into its surroundings.
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: max(8, reach * (0.16 + 0.05 * warmHalo))))
                layer.fill(
                    path,
                    with: .color(OrbPalette.warm.mix(OrbPalette.gold, 0.4 * warmHalo).color.opacity(light * (0.22 + 0.16 * warmHalo)))
                )
            }

            context.fill(
                path,
                with: .radialGradient(
                    Gradient(stops: [
                        .init(color: OrbPalette.highlight.color, location: 0),
                        .init(color: OrbPalette.shell.color, location: 0.42),
                        .init(color: OrbPalette.body.color, location: 0.78),
                        .init(color: OrbPalette.edge.color, location: 1)
                    ]),
                    center: CGPoint(x: m.cx - m.rx * 0.34, y: m.cy - m.ry * 0.42),
                    startRadius: 0,
                    endRadius: reach * 1.62
                )
            )
            if liftsForDarkDesktop {
                context.fill(path, with: .color(Color.white.opacity(0.1)))
            }

            context.drawLayer { layer in
                layer.clip(to: path)

                // Form shadow that wraps the lower right edge.
                layer.drawLayer { shade in
                    shade.addFilter(.blur(radius: max(6, reach * 0.14)))
                    shade.translateBy(x: m.rx * 0.07, y: m.ry * 0.1)
                    shade.stroke(path, with: .color(OrbPalette.shadow.color.opacity(0.34 + 0.08 * draw.depth)), lineWidth: reach * 0.34)
                }
                if draw.depth > 0.01 {
                    layer.drawLayer { shade in
                        shade.addFilter(.blur(radius: max(3, reach * 0.06)))
                        shade.stroke(path, with: .color(OrbPalette.shadow.color.opacity(0.16 * draw.depth)), lineWidth: reach * 0.14)
                    }
                }

                if draw.dimple > 0.01 {
                    let press = CGFloat(draw.dimple)
                    layer.drawLayer { shade in
                        shade.addFilter(.blur(radius: max(5, m.ry * 0.14)))
                        shade.fill(
                            Path(ellipseIn: ellipse(cx: m.cx, cy: m.cy - m.ry * 0.6, width: m.rx * 0.95, height: m.ry * 0.5)),
                            with: .color(OrbPalette.shadow.color.opacity(0.3 * press))
                        )
                    }
                    layer.drawLayer { glow in
                        glow.addFilter(.blur(radius: max(4, m.ry * 0.08)))
                        glow.fill(
                            Path(ellipseIn: ellipse(cx: m.cx, cy: m.cy - m.ry * 0.28, width: m.rx * 1.05, height: m.ry * 0.22)),
                            with: .color(Color.white.opacity(0.4 * press))
                        )
                    }
                }

                if draw.swirl > 0.01 {
                    let fold = foldPath(m)
                    let strength = draw.swirl
                    layer.drawLayer { shade in
                        shade.addFilter(.blur(radius: max(4, reach * 0.07)))
                        shade.translateBy(x: m.rx * 0.05, y: m.ry * 0.04)
                        shade.stroke(fold, with: .color(OrbPalette.shadow.color.opacity(0.3 * strength)), lineWidth: reach * 0.16)
                    }
                    layer.drawLayer { glow in
                        glow.addFilter(.blur(radius: max(1.5, reach * 0.022)))
                        glow.stroke(fold, with: .color(Color.white.opacity(0.85 * strength)), lineWidth: max(1.2, reach * 0.045))
                    }
                }

                for blob in lightBlobs(in: size, tint: lightColor) {
                    layer.drawLayer { glow in
                        glow.addFilter(.blur(radius: blob.blur * scale))
                        glow.fill(Path(ellipseIn: blob.rect), with: .color(blob.color.opacity(blob.opacity * draw.lightPulse)))
                    }
                }

                // Broad sheen across the upper body.
                layer.drawLayer { glow in
                    glow.addFilter(.blur(radius: max(6, m.ry * 0.18)))
                    glow.fill(
                        Path(ellipseIn: ellipse(cx: m.cx - m.rx * 0.18, cy: m.cy - m.ry * 0.72, width: m.rx * 1.5, height: m.ry * 0.7)),
                        with: .color(Color.white.opacity(0.5 - 0.2 * draw.dimple))
                    )
                }
                // Specular point, upper left.
                layer.drawLayer { glow in
                    glow.addFilter(.blur(radius: max(1.5, reach * 0.035)))
                    glow.fill(
                        Path(ellipseIn: ellipse(cx: m.cx - m.rx * 0.44, cy: m.cy - m.ry * 0.5, width: m.rx * 0.34, height: m.ry * 0.16)),
                        with: .color(Color.white.opacity(0.78))
                    )
                }
                // Thin bright rim where the shell turns away.
                layer.drawLayer { rim in
                    rim.addFilter(.blur(radius: 0.8))
                    rim.translateBy(x: -m.rx * 0.015, y: -m.ry * 0.02)
                    rim.stroke(path, with: .color(Color.white.opacity(0.55)), lineWidth: max(1, reach * 0.018))
                }
            }

            if draw.arc > 0.01 {
                drawArc(in: &context, m: m)
            }
            if draw.listen > 0.01, draw.listenTime >= 0 {
                drawRipples(in: &context, m: m)
            }
        }
    }

    /// Two soft rings that leave the shell and fade, offset by half a cycle.
    private func drawRipples(in context: inout GraphicsContext, m: (cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat)) {
        let cycle = 3.4
        for offset in [0.0, 0.5] {
            let u = (draw.listenTime / cycle + offset).truncatingRemainder(dividingBy: 1)
            let grow = CGFloat(1.04 + 0.4 * u)
            let fade = sin(.pi * u) * (1 - u * 0.4)
            let ring = Path(ellipseIn: ellipse(cx: m.cx, cy: m.cy, width: m.rx * 2 * grow, height: m.ry * 2 * grow))
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: 1.6))
                layer.stroke(
                    ring,
                    with: .color(OrbPalette.warm.mix(OrbPalette.arc, 0.45).color.opacity(0.5 * draw.listen * fade)),
                    lineWidth: 1.4
                )
            }
        }
    }

    /// The inner fold that curls from the upper right down around the light.
    private func foldPath(_ m: (cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat)) -> Path {
        let sway = CGSize(width: draw.lightCenter.width * 0.35, height: draw.lightCenter.height * 0.25)
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: m.cx + m.rx * x + sway.width, y: m.cy + m.ry * y + sway.height)
        }
        let lift = CGFloat(draw.dimple) * 0.18
        var path = Path()
        path.move(to: p(0.62, -0.7 + lift))
        path.addCurve(to: p(-0.38, 0.32), control1: p(-0.1, -0.86 + lift), control2: p(-0.72, -0.18))
        path.addCurve(to: p(0.3, 0.3), control1: p(-0.12, 0.66), control2: p(0.26, 0.6))
        return path
    }

    private func drawArc(in context: inout GraphicsContext, m: (cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat)) {
        let radiusX = m.rx * 1.12 + 8
        let radiusY = m.ry * 1.12 + 8
        let center = -0.62 + 0.12 * sin(draw.arcPhase)
        let sweep = 0.95
        let steps = 28
        for index in 0..<steps {
            let u0 = Double(index) / Double(steps)
            let u1 = Double(index + 1) / Double(steps)
            let a0 = center - sweep / 2 + sweep * u0
            let a1 = center - sweep / 2 + sweep * u1
            var segment = Path()
            segment.move(to: CGPoint(x: m.cx + CGFloat(cos(a0)) * radiusX, y: m.cy + CGFloat(sin(a0)) * radiusY))
            segment.addLine(to: CGPoint(x: m.cx + CGFloat(cos(a1)) * radiusX, y: m.cy + CGFloat(sin(a1)) * radiusY))
            let fade = sin(.pi * (u0 + u1) / 2)
            context.stroke(
                segment,
                with: .color(OrbPalette.arc.color.opacity(0.62 * draw.arc * fade)),
                style: StrokeStyle(lineWidth: 1.4, lineCap: .round)
            )
        }
    }

    private var lightColor: RGB {
        OrbPalette.core
            .mix(OrbPalette.warm, draw.warmth)
            .mix(OrbPalette.gold, draw.warmth * 0.35)
    }

    private func shellMetrics(in size: CGSize) -> (cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat) {
        let cx = size.width / 2 + draw.bias.width
        let cy = size.height / 2 + draw.bias.height
        let rx = CGFloat(draw.diameter / 2 * draw.stretchX * draw.breathScale)
        let ry = CGFloat(draw.diameter / 2 * draw.stretchY * draw.breathScale)
        return (cx, cy, rx, ry)
    }

    private func shellPath(in size: CGSize) -> Path {
        let metrics = shellMetrics(in: size)
        let samples = 160
        var path = Path()
        for index in 0..<samples {
            let angle = Double(index) / Double(samples) * 2 * .pi
            let up = max(0, -sin(angle))
            var offTop = angle - 1.5 * .pi
            if offTop < -.pi { offTop += 2 * .pi }
            let press = exp(-pow(offTop / 0.5, 2)) * draw.dimple * 0.17
            let cup = pow(up, 1.35) * draw.fold * 0.07 + press
            let lobe = sin(3 * angle + draw.deformPhase) * 0.02
                + sin(5 * angle - draw.deformPhase * 0.67) * 0.01
                + sin(angle + 0.55) * 0.01 * draw.asymmetry
            let radius = 1 - cup + draw.deformation * lobe
            let point = CGPoint(
                x: metrics.cx + CGFloat(cos(angle) * radius) * metrics.rx,
                y: metrics.cy + CGFloat(sin(angle) * radius) * metrics.ry
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }

    private func lightBlobs(in size: CGSize, tint: RGB) -> [LightBlob] {
        let cx = size.width / 2 + draw.lightCenter.width + draw.bias.width * 0.35
        let cy = size.height / 2 + draw.lightCenter.height + draw.bias.height * 0.35
        let core = CGFloat(draw.diameter * draw.lightFraction)
        let spread = CGFloat(draw.diffusion)
        let base = draw.lightOpacity
        return [
            LightBlob(
                rect: ellipse(cx: cx, cy: cy + core * 0.1, width: core * 3.0, height: core * 2.3),
                color: OrbPalette.warm.mix(tint, 0.4).color,
                opacity: base * 0.5,
                blur: CGFloat(draw.lightBlur * 2.2)
            ),
            LightBlob(
                rect: ellipse(cx: cx - core * 0.22 * spread, cy: cy + core * 0.18 * spread, width: core * (1.55 + 0.4 * spread), height: core * (1.15 + 0.25 * spread)),
                color: OrbPalette.gold.mix(tint, 0.35).color,
                opacity: base * 0.42,
                blur: CGFloat(draw.lightBlur * 1.35)
            ),
            LightBlob(
                rect: ellipse(cx: cx + core * 0.18 * spread, cy: cy - core * 0.12 * spread, width: core * (1.2 + 0.2 * spread), height: core * 0.86),
                color: OrbPalette.warm.mix(tint, 0.5).color,
                opacity: base * 0.62,
                blur: CGFloat(draw.lightBlur)
            ),
            LightBlob(
                rect: ellipse(cx: cx, cy: cy, width: core, height: core * 0.78),
                color: tint.color,
                opacity: min(1, base * 1.1),
                blur: CGFloat(max(4, draw.lightBlur * 0.55))
            ),
            LightBlob(
                rect: ellipse(cx: cx, cy: cy, width: core * 0.55, height: core * 0.42),
                color: OrbPalette.core.mix(RGB(r: 1, g: 1, b: 1), 0.5).color,
                opacity: min(1, base * 1.45),
                blur: CGFloat(max(2, draw.lightBlur * 0.25))
            )
        ]
    }

    private func ellipse(cx: CGFloat, cy: CGFloat, width: CGFloat, height: CGFloat) -> CGRect {
        CGRect(x: cx - width / 2, y: cy - height / 2, width: width, height: height)
    }
}

private struct LightBlob {
    var rect: CGRect
    var color: Color
    var opacity: Double
    var blur: CGFloat
}
