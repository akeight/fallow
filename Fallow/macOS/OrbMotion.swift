import CoreGraphics
import SwiftUI

struct RGB {
    var r: Double
    var g: Double
    var b: Double

    func mix(_ other: RGB, _ t: Double) -> RGB {
        let u = min(1, max(0, t))
        return RGB(
            r: r + (other.r - r) * u,
            g: g + (other.g - g) * u,
            b: b + (other.b - b) * u
        )
    }

    var color: Color {
        Color(red: r, green: g, blue: b)
    }
}

enum OrbPalette {
    static let highlight = RGB(r: 0.992, g: 0.988, b: 0.976)
    static let shell = RGB(r: 0.945, g: 0.933, b: 0.910)
    static let body = RGB(r: 0.890, g: 0.874, b: 0.847)
    static let edge = RGB(r: 0.776, g: 0.753, b: 0.716)
    static let shadow = RGB(r: 139 / 255, g: 133 / 255, b: 122 / 255)
    static let deepShadow = RGB(r: 92 / 255, g: 86 / 255, b: 77 / 255)
    static let arc = RGB(r: 0.62, g: 0.58, b: 0.52)
    static let core = RGB(r: 1, g: 247 / 255, b: 223 / 255)
    static let warm = RGB(r: 229 / 255, g: 200 / 255, b: 146 / 255)
    static let gold = RGB(r: 216 / 255, g: 183 / 255, b: 122 / 255)
    static let sky = RGB(r: 0.80, g: 0.81, b: 0.90)
    static let peach = RGB(r: 0.96, g: 0.80, b: 0.64)
    static let ember = RGB(r: 1, g: 0.88, b: 0.66)
    static let amber = RGB(r: 0.62, g: 0.48, b: 0.34)
    static let glassCore = RGB(r: 0.995, g: 0.955, b: 0.88)
    static let glassBody = RGB(r: 0.92, g: 0.87, b: 0.82)
    static let glassEdge = RGB(r: 0.72, g: 0.62, b: 0.52)
}

struct OrbDraw {
    var diameter: Double
    var canvas: Double
    var stretchX: Double
    var stretchY: Double
    var asymmetry: Double
    var deformation: Double
    var deformPhase: Double
    var fold: Double
    var bias: CGSize
    var shellOpacity: Double
    var shellBlur: Double
    var warmth: Double
    var lightOpacity: Double
    var lightFraction: Double
    var lightBlur: Double
    var lightCenter: CGSize
    var diffusion: Double
    var breathScale: Double
    /// 1 is steady. Resting breathes the glow around this.
    var lightPulse: Double
    /// A soft press in the top of the shell, like a fingertip.
    var dimple: Double
    /// How clearly the inner fold reads.
    var swirl: Double
    /// The thin arc beside the orb while something is happening.
    var arc: Double
    var arcPhase: Double
    /// Soft ripples outside the shell while it listens.
    var listen: Double
    /// Clock for the ripples. Negative when motion is reduced.
    var listenTime: Double
    /// Extra edge shadow and a deeper surrounding glow for the round states.
    var depth: Double
}

@MainActor
enum OrbMotion {
    static func rawProgress(phase: SessionPhase, softness: Double) -> Double {
        switch phase {
        case .holding(let progress):
            progress
        case .threshold, .reentering:
            softness
        case .resting, .returnDoorway, .reflecting, .beforeAfter:
            1
        default:
            0
        }
    }

    /// Slow through the first quarter, then the middle of the hold does the visible work.
    static func holdEase(_ raw: Double) -> Double {
        let t = min(1, max(0, raw))
        return t * t * (3 - 2 * t)
    }

    /// Desk stays clear early. Recession gathers after the midpoint.
    static func veilAmount(raw: Double) -> Double {
        let t = min(1, max(0, raw))
        if t <= 0.25 {
            return (t / 0.25) * 0.06
        }
        if t <= 0.50 {
            let u = (t - 0.25) / 0.25
            return 0.06 + u * u * 0.22
        }
        if t <= 0.75 {
            let u = (t - 0.50) / 0.25
            return 0.28 + smooth(u) * 0.34
        }
        let u = (t - 0.75) / 0.25
        return 0.62 + smooth(u) * 0.38
    }

    static func smooth(_ t: Double) -> Double {
        let x = min(1, max(0, t))
        return x * x * (3 - 2 * x)
    }

    static func resolve(
        phase: SessionPhase,
        softness: Double,
        config: OrbTuningConfig,
        time: TimeInterval,
        hover: Double,
        hoverLocation: CGPoint?,
        reduceMotion: Bool,
        settleStart: Date?,
        returnStart: Date?,
        laggedEase: Double
    ) -> OrbDraw {
        let raw = rawProgress(phase: phase, softness: softness)
        let eased = holdEase(raw)
        let lightEase = reduceMotion ? eased : laggedEase

        var diameter = config.idleSize
        var stretchX = config.horizontalStretch
        var stretchY = config.verticalStretch
        var asymmetry = config.asymmetry
        var deformation = config.deformationAmount
        var fold = 0.16
        var biasY = 0.0
        var shellOpacity = config.shellOpacity
        var shellBlur = max(4.0, min(10, config.idleSize * 0.06))
        var warmth = config.warmth
        var lightOpacity = config.lightOpacity
        var lightFraction = config.coreSize
        var lightBlur = config.lightBlur
        var diffusion = config.diffusion
        var driftScale = 1.0
        var breathPeriod = config.breathDuration
        var breathAmplitude = min(0.035, config.breathAmplitude)
        var breathe = !reduceMotion
        var lightPulse = 1.0
        var lightDrop = 0.0
        var dimple = 0.0
        var swirl = 0.55
        var arc = 0.0
        var listen = 0.0
        var depth = 0.0

        switch phase {
        case .dormant:
            let attention = reduceMotion ? 0 : hover
            diameter = config.idleSize * (1 + (config.attentiveScale - 1) * attention)
            stretchX = lerp(stretchX, stretchX * 0.96, attention)
            stretchY = lerp(stretchY, min(1.08, stretchY * 1.06), attention)
            deformation = lerp(deformation, deformation * 0.55, attention)
            fold = lerp(0.18, 0.06, attention)
            biasY = lerp(0, -diameter * 0.03, attention)
            lightOpacity = lerp(config.lightOpacity - 0.12, min(1, config.lightOpacity + 0.06 + config.attentiveLightChange), attention)
            warmth = lerp(min(1, warmth + 0.08), min(1, warmth + 0.2), attention)
            depth = lerp(1.45, 1, attention)
            lightDrop = lerp(diameter * 0.2, diameter * 0.14, attention)
            swirl = lerp(0.5, 0.8, attention)
            arc = attention * 0.55
        case .capture, .classifyStuck, .chooseDistance:
            diameter = config.idleSize * 1.14
            deformation *= 0.4
            asymmetry *= 0.65
            fold = 0.22
            stretchX = lerp(stretchX, 1.02, 0.5)
            stretchY = lerp(stretchY, 0.98, 0.5)
            lightOpacity = min(0.95, config.lightOpacity + config.attentiveLightChange * 1.3)
            lightFraction = config.coreSize * 1.12
            warmth = min(1, warmth + 0.2)
            depth = 1
            breathPeriod = config.breathDuration * (7.2 / 6.8)
            breathAmplitude *= 0.55
            driftScale = 0.45
            lightDrop = diameter * 0.15
            swirl = 0.9
            arc = 1
            listen = 1
            lightPulse = listeningPulse(time: time, reduced: reduceMotion)
        case .threshold, .holding:
            diameter = lerp(config.holdStartSize, config.holdEndSize, eased)
            stretchX = lerp(config.horizontalStretch * 1.02, config.horizontalStretch * 1.18, eased)
            stretchY = lerp(config.verticalStretch * 0.96, config.verticalStretch * 0.78, eased)
            deformation = lerp(config.deformationAmount * 0.7, config.deformationAmount * 0.35, eased)
            fold = lerp(0.22, 0.72, eased)
            biasY = lerp(diameter * 0.02, diameter * 0.06, eased)
            shellOpacity = lerp(config.shellOpacity, min(0.96, config.shellOpacity + 0.04), eased)
            shellBlur = lerp(6, min(18, config.holdOuterSoftness * 0.45), eased)
            warmth = lerp(config.warmth + 0.04, min(1, config.warmth + 0.18), lightEase)
            lightOpacity = lerp(config.holdLightStartOpacity, config.holdLightEndOpacity, lightEase)
            lightFraction = lerp(min(config.coreSize, config.holdLightSize * 0.75), config.holdLightSize, lightEase)
            lightBlur = lerp(config.lightBlur, config.lightBlur + config.holdOuterSoftness * 0.35, lightEase)
            diffusion = lerp(config.diffusion, config.diffusion * 1.15, lightEase)
            breathe = false
            driftScale = lerp(0.55, 0.25, eased)
            lightDrop = lerp(diameter * 0.15, diameter * 0.12, eased)
            dimple = eased
            swirl = lerp(0.85, 0.35, eased)
            arc = 1
        case .resting:
            let settled = settleAmount(since: settleStart, duration: config.lightSettlingDuration, now: time)
            let hero = holdPose(config: config)
            diameter = lerp(hero.diameter, config.restSize, settled)
            stretchX = lerp(hero.stretchX, config.horizontalStretch * 1.26, settled)
            stretchY = lerp(hero.stretchY, config.verticalStretch * 0.8, settled)
            deformation = lerp(hero.deformation, config.deformationAmount * 0.3, settled)
            fold = lerp(hero.fold, 0.34, settled)
            asymmetry = config.asymmetry * lerp(0.8, 0.7, settled)
            biasY = lerp(hero.biasY, diameter * 0.04, settled)
            shellOpacity = lerp(hero.shellOpacity, config.shellOpacity * 0.9, settled)
            shellBlur = lerp(hero.blur, 8, settled)
            warmth = lerp(hero.warmth, min(1, config.warmth + 0.1), settled)
            lightOpacity = lerp(config.holdLightEndOpacity, config.restGlowOpacity, settled)
            lightFraction = lerp(config.holdLightSize, config.coreSize * 0.95, settled)
            lightBlur = lerp(config.lightBlur * 1.3, config.lightBlur, settled)
            diffusion = lerp(config.diffusion, config.diffusion * 1.35, settled)
            breathPeriod = config.restBreathDuration
            breathAmplitude = settled > 0.98 ? 0.012 : 0
            breathe = settled > 0.98 && !reduceMotion
            driftScale = lerp(0.2, 1.3, settled)
            lightDrop = lerp(diameter * 0.12, diameter * 0.18, settled)
            dimple = lerp(1, 0, settled)
            swirl = lerp(0.35, 0.45, settled)
            arc = lerp(0.6, 0, settled)
            if settled > 0.98 {
                lightPulse = lightBreath(time: time, period: config.restBreathDuration, reduced: reduceMotion)
            }
        case .returnDoorway, .reflecting, .beforeAfter:
            let gathered = phase == .returnDoorway
                ? settleAmount(since: returnStart, duration: config.returnDuration, now: time)
                : 1
            let restDiameter = config.restSize
            diameter = lerp(restDiameter, config.returnSize, gathered)
            stretchX = lerp(config.horizontalStretch * 1.26, config.horizontalStretch * 1.0, gathered)
            stretchY = lerp(config.verticalStretch * 0.8, config.verticalStretch * 1.0, gathered)
            deformation = lerp(config.deformationAmount * 0.3, config.deformationAmount * 0.35, gathered)
            fold = lerp(0.34, 0.12, gathered)
            biasY = lerp(config.restSize * 0.04, -config.returnSize * 0.02, gathered)
            shellOpacity = lerp(config.shellOpacity * 0.72, config.shellOpacity, gathered)
            shellBlur = lerp(12, 8, gathered)
            warmth = lerp(max(0, config.warmth - 0.1), min(1, config.warmth + 0.12), gathered)
            let gatheredLight = min(0.70, max(0.55, config.lightOpacity + 0.19))
            lightOpacity = lerp(config.restGlowOpacity, gatheredLight, gathered)
            lightFraction = lerp(config.coreSize * 0.72, config.coreSize * 0.9, gathered)
            lightBlur = lerp(config.lightBlur * 1.2, config.lightBlur * 0.9, gathered)
            diffusion = lerp(config.diffusion * 1.3, config.diffusion * 0.7, gathered)
            breathe = false
            driftScale = lerp(0.25, 0.4, gathered)
            lightDrop = lerp(config.restSize * 0.18, config.returnSize * 0.13, gathered)
            lightPulse = lerp(0.85, 1, gathered)
            swirl = lerp(0.3, 0.95, gathered)
            arc = gathered
        case .reentering:
            let t = smooth(1 - softness)
            diameter = lerp(config.returnSize, config.idleSize, t)
            stretchX = lerp(config.horizontalStretch, config.horizontalStretch, t)
            stretchY = lerp(config.verticalStretch, config.verticalStretch, t)
            deformation = lerp(config.deformationAmount * 0.35, config.deformationAmount, t)
            fold = lerp(0.12, 0.18, t)
            biasY = lerp(-config.returnSize * 0.02, 0, t)
            shellOpacity = config.shellOpacity
            warmth = lerp(min(1, config.warmth + 0.1), config.warmth, t)
            lightOpacity = lerp(min(0.70, config.lightOpacity + 0.19), config.lightOpacity, t)
            lightFraction = lerp(config.coreSize * 0.9, config.coreSize, t)
            diffusion = lerp(config.diffusion * 0.7, config.diffusion, t)
            breathe = false
            driftScale = lerp(0.4, 1, t)
            lightDrop = lerp(config.returnSize * 0.13, config.idleSize * 0.2, t)
            swirl = lerp(0.95, 0.5, t)
            arc = 1 - t
        }

        let breathScale = breathScaleValue(
            time: time,
            period: breathPeriod,
            amplitude: breathe ? breathAmplitude : 0
        )
        let deformPhase = reduceMotion ? 0.7 : time * max(0, config.deformationSpeed) * 2 * .pi
        let lightTime = time - (reduceMotion ? 0 : config.shellLightDelay)
        let drift = lightDrift(
            time: lightTime,
            duration: config.lightDriftDuration,
            range: config.driftRange * driftScale,
            reduced: reduceMotion
        )
        var centerX = config.lightXDrift + config.lightOffsetX + drift.width
        var centerY = config.lightYDrift + config.lightOffsetY + drift.height
        let reachGuess = diameter * 0.5 * max(stretchX, stretchY) * 1.06 + Double(max(shellBlur, lightBlur)) + 18
        if phase == .returnDoorway || phase == .reflecting || phase == .beforeAfter {
            let gathered = phase == .returnDoorway
                ? settleAmount(since: returnStart, duration: config.returnDuration, now: time)
                : 1
            centerX = lerp(centerX, centerX * 0.25, gathered)
            centerY = lerp(centerY, centerY * 0.25, gathered)
        }
        if phase == .reentering {
            let t = smooth(1 - softness)
            centerX = lerp(centerX * 0.25, config.lightXDrift + config.lightOffsetX, t)
            centerY = lerp(centerY * 0.25, config.lightYDrift + config.lightOffsetY, t)
        }
        centerY += lightDrop
        if let hoverLocation, hover > 0, phase == .dormant {
            let center = max(64.0, reachGuess) / 2
            let nudge = max(8, diameter * 0.06)
            centerX += min(nudge, max(-nudge, hoverLocation.x - center)) * hover
            centerY += min(nudge, max(-nudge, hoverLocation.y - center)) * hover
        }

        let reach = canvasExtent(phase: phase, config: config)
        return OrbDraw(
            diameter: diameter,
            canvas: reach,
            stretchX: stretchX,
            stretchY: stretchY,
            asymmetry: asymmetry,
            deformation: deformation,
            deformPhase: deformPhase,
            fold: fold,
            bias: CGSize(width: 0, height: CGFloat(biasY)),
            shellOpacity: shellOpacity,
            shellBlur: shellBlur,
            warmth: warmth,
            lightOpacity: lightOpacity,
            lightFraction: lightFraction,
            lightBlur: lightBlur,
            lightCenter: CGSize(width: CGFloat(centerX), height: CGFloat(centerY)),
            diffusion: diffusion,
            breathScale: breathScale,
            lightPulse: lightPulse,
            dimple: dimple,
            swirl: swirl,
            arc: arc,
            arcPhase: reduceMotion ? 0 : time / 9 * 2 * .pi,
            listen: listen,
            listenTime: reduceMotion ? -1 : time,
            depth: depth
        )
    }

    private struct HoldLook {
        var diameter: Double
        var stretchX: Double
        var stretchY: Double
        var deformation: Double
        var fold: Double
        var biasY: Double
        var shellOpacity: Double
        var blur: Double
        var warmth: Double
    }

    private static func holdPose(config: OrbTuningConfig) -> HoldLook {
        HoldLook(
            diameter: config.holdEndSize,
            stretchX: config.horizontalStretch * 1.18,
            stretchY: config.verticalStretch * 0.78,
            deformation: config.deformationAmount * 0.35,
            fold: 0.72,
            biasY: config.holdEndSize * 0.06,
            shellOpacity: min(0.92, config.shellOpacity + 0.10),
            blur: config.holdOuterSoftness,
            warmth: min(1, config.warmth + 0.2)
        )
    }

    static func canvasExtent(phase: SessionPhase, config: OrbTuningConfig) -> Double {
        switch phase {
        case .dormant:
            max(200, config.idleSize * 2.05)
        case .reentering:
            max(360, config.returnSize * 1.65)
        case .capture, .classifyStuck, .chooseDistance:
            max(220, config.idleSize * 2.25)
        case .threshold, .holding:
            max(420, config.holdEndSize * 1.42)
        case .resting:
            // Starts from the full hold shape, then settles inside the same canvas.
            max(420, config.holdEndSize * 1.42, config.restSize * 2.45)
        case .returnDoorway, .reflecting, .beforeAfter:
            max(360, config.returnSize * 1.65)
        }
    }

    private static func settleAmount(since start: Date?, duration: Double, now: TimeInterval) -> Double {
        guard let start else { return 1 }
        let age = max(0, now - start.timeIntervalSinceReferenceDate)
        return smooth(min(1, age / max(0.2, duration)))
    }

    /// A slow brightening and dimming of the resting glow. The shell barely moves.
    private static func lightBreath(time: TimeInterval, period: Double, reduced: Bool) -> Double {
        guard !reduced else { return 1 }
        let cycle = max(6, period + 0.4 * sin(time * 0.19))
        let u = time.truncatingRemainder(dividingBy: cycle) / cycle
        let wave = 0.5 - 0.5 * cos(u * 2 * .pi)
        return 0.78 + 0.22 * wave
    }

    /// A gentle brightening while it listens. Faster than rest, never a heartbeat.
    private static func listeningPulse(time: TimeInterval, reduced: Bool) -> Double {
        guard !reduced else { return 1 }
        let cycle = 3.4
        let u = time.truncatingRemainder(dividingBy: cycle) / cycle
        let wave = 0.5 - 0.5 * cos(u * 2 * .pi)
        return 0.88 + 0.14 * wave
    }

    private static func breathScaleValue(time: TimeInterval, period: Double, amplitude: Double) -> Double {
        guard amplitude > 0.0001 else { return 1 }
        let wobblePeriod = 0.4 * sin(time * 0.23)
        let wobbleAmp = 0.003 * sin(time * 0.17)
        let cycle = max(4.5, period + wobblePeriod)
        let amp = min(0.035, max(0, amplitude + wobbleAmp))
        let u = time.truncatingRemainder(dividingBy: cycle) / cycle
        let wave = 0.5 - 0.5 * cos(u * 2 * .pi)
        return 1 + amp * wave
    }

    private static func lightDrift(time: TimeInterval, duration: Double, range: Double, reduced: Bool) -> (width: Double, height: Double) {
        guard !reduced, range > 0.01 else { return (0, 0) }
        let cycle = max(6, duration)
        let u = time / cycle * 2 * .pi
        return (
            width: sin(u) * range,
            height: cos(u * 0.73 + 0.6) * range * 0.72
        )
    }

    private static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * min(1, max(0, t))
    }
}
