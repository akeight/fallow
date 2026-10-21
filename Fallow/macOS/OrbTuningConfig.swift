import Foundation
import Observation

/// Live visual values for the Mac orb. Defaults are the motion spec's starting points.
@MainActor
@Observable
final class OrbTuningConfig {
    var idleSize: Double = OrbTuningDefaults.idleSize
    var breathDuration: Double = OrbTuningDefaults.breathDuration
    var breathAmplitude: Double = OrbTuningDefaults.breathAmplitude
    var shellOpacity: Double = OrbTuningDefaults.shellOpacity
    var lightOpacity: Double = OrbTuningDefaults.lightOpacity
    var lightBlur: Double = OrbTuningDefaults.lightBlur
    var lightXDrift: Double = OrbTuningDefaults.lightXDrift
    var lightYDrift: Double = OrbTuningDefaults.lightYDrift
    var lightDriftDuration: Double = OrbTuningDefaults.lightDriftDuration

    var attentiveScale: Double = OrbTuningDefaults.attentiveScale
    var attentiveDuration: Double = OrbTuningDefaults.attentiveDuration
    var attentiveLightChange: Double = OrbTuningDefaults.attentiveLightChange

    var holdDuration: Double = OrbTuningDefaults.holdDuration
    var holdStartSize: Double = OrbTuningDefaults.holdStartSize
    var holdEndSize: Double = OrbTuningDefaults.holdEndSize
    var holdOuterSoftness: Double = OrbTuningDefaults.holdOuterSoftness
    var holdLightStartOpacity: Double = OrbTuningDefaults.holdLightStartOpacity
    var holdLightEndOpacity: Double = OrbTuningDefaults.holdLightEndOpacity
    var holdLightSize: Double = OrbTuningDefaults.holdLightSize
    var workspaceBlur: Double = OrbTuningDefaults.workspaceBlur
    var workspaceContrast: Double = OrbTuningDefaults.workspaceContrast
    var workspaceRecession: Double = OrbTuningDefaults.workspaceRecession

    var restSize: Double = OrbTuningDefaults.restSize
    var restBreathDuration: Double = OrbTuningDefaults.restBreathDuration
    var restGlowOpacity: Double = OrbTuningDefaults.restGlowOpacity

    var returnSize: Double = OrbTuningDefaults.returnSize
    var returnDuration: Double = OrbTuningDefaults.returnDuration
    var reentryDuration: Double = OrbTuningDefaults.reentryDuration
    /// How long the orb is held before the return gives way.
    var returnHoldDuration: Double = OrbTuningDefaults.returnHoldDuration

    var asymmetry: Double = OrbTuningDefaults.asymmetry
    var horizontalStretch: Double = OrbTuningDefaults.horizontalStretch
    var verticalStretch: Double = OrbTuningDefaults.verticalStretch
    var deformationAmount: Double = OrbTuningDefaults.deformationAmount
    var deformationSpeed: Double = OrbTuningDefaults.deformationSpeed

    var coreSize: Double = OrbTuningDefaults.coreSize
    var diffusion: Double = OrbTuningDefaults.diffusion
    var lightOffsetX: Double = OrbTuningDefaults.lightOffsetX
    var lightOffsetY: Double = OrbTuningDefaults.lightOffsetY
    var driftRange: Double = OrbTuningDefaults.driftRange
    var warmth: Double = OrbTuningDefaults.warmth

    var shellLightDelay: Double = OrbTuningDefaults.shellLightDelay
    var lightSettlingDuration: Double = OrbTuningDefaults.lightSettlingDuration

    var layoutSignature: Double {
        idleSize + restSize + holdEndSize + holdStartSize + holdOuterSoftness + returnSize
    }

    var veilSignature: Double {
        workspaceBlur + workspaceContrast * 10 + workspaceRecession * 10
    }

    func reset() {
        idleSize = OrbTuningDefaults.idleSize
        breathDuration = OrbTuningDefaults.breathDuration
        breathAmplitude = OrbTuningDefaults.breathAmplitude
        shellOpacity = OrbTuningDefaults.shellOpacity
        lightOpacity = OrbTuningDefaults.lightOpacity
        lightBlur = OrbTuningDefaults.lightBlur
        lightXDrift = OrbTuningDefaults.lightXDrift
        lightYDrift = OrbTuningDefaults.lightYDrift
        lightDriftDuration = OrbTuningDefaults.lightDriftDuration
        attentiveScale = OrbTuningDefaults.attentiveScale
        attentiveDuration = OrbTuningDefaults.attentiveDuration
        attentiveLightChange = OrbTuningDefaults.attentiveLightChange
        holdDuration = OrbTuningDefaults.holdDuration
        holdStartSize = OrbTuningDefaults.holdStartSize
        holdEndSize = OrbTuningDefaults.holdEndSize
        holdOuterSoftness = OrbTuningDefaults.holdOuterSoftness
        holdLightStartOpacity = OrbTuningDefaults.holdLightStartOpacity
        holdLightEndOpacity = OrbTuningDefaults.holdLightEndOpacity
        holdLightSize = OrbTuningDefaults.holdLightSize
        workspaceBlur = OrbTuningDefaults.workspaceBlur
        workspaceContrast = OrbTuningDefaults.workspaceContrast
        workspaceRecession = OrbTuningDefaults.workspaceRecession
        restSize = OrbTuningDefaults.restSize
        restBreathDuration = OrbTuningDefaults.restBreathDuration
        restGlowOpacity = OrbTuningDefaults.restGlowOpacity
        returnSize = OrbTuningDefaults.returnSize
        returnDuration = OrbTuningDefaults.returnDuration
        reentryDuration = OrbTuningDefaults.reentryDuration
        returnHoldDuration = OrbTuningDefaults.returnHoldDuration
        asymmetry = OrbTuningDefaults.asymmetry
        horizontalStretch = OrbTuningDefaults.horizontalStretch
        verticalStretch = OrbTuningDefaults.verticalStretch
        deformationAmount = OrbTuningDefaults.deformationAmount
        deformationSpeed = OrbTuningDefaults.deformationSpeed
        coreSize = OrbTuningDefaults.coreSize
        diffusion = OrbTuningDefaults.diffusion
        lightOffsetX = OrbTuningDefaults.lightOffsetX
        lightOffsetY = OrbTuningDefaults.lightOffsetY
        driftRange = OrbTuningDefaults.driftRange
        warmth = OrbTuningDefaults.warmth
        shellLightDelay = OrbTuningDefaults.shellLightDelay
        lightSettlingDuration = OrbTuningDefaults.lightSettlingDuration
    }

    func swiftSource() -> String {
        """
        config.idleSize = \(n(idleSize))
        config.breathDuration = \(n(breathDuration))
        config.breathAmplitude = \(n(breathAmplitude, 3))
        config.shellOpacity = \(n(shellOpacity))
        config.lightOpacity = \(n(lightOpacity))
        config.lightBlur = \(n(lightBlur))
        config.lightXDrift = \(n(lightXDrift))
        config.lightYDrift = \(n(lightYDrift))
        config.lightDriftDuration = \(n(lightDriftDuration))
        config.attentiveScale = \(n(attentiveScale))
        config.attentiveDuration = \(n(attentiveDuration))
        config.attentiveLightChange = \(n(attentiveLightChange))
        config.holdDuration = \(n(holdDuration))
        config.holdStartSize = \(n(holdStartSize))
        config.holdEndSize = \(n(holdEndSize))
        config.holdOuterSoftness = \(n(holdOuterSoftness))
        config.holdLightStartOpacity = \(n(holdLightStartOpacity))
        config.holdLightEndOpacity = \(n(holdLightEndOpacity))
        config.holdLightSize = \(n(holdLightSize))
        config.workspaceBlur = \(n(workspaceBlur))
        config.workspaceContrast = \(n(workspaceContrast))
        config.workspaceRecession = \(n(workspaceRecession))
        config.restSize = \(n(restSize))
        config.restBreathDuration = \(n(restBreathDuration))
        config.restGlowOpacity = \(n(restGlowOpacity))
        config.returnSize = \(n(returnSize))
        config.returnDuration = \(n(returnDuration))
        config.reentryDuration = \(n(reentryDuration))
        config.returnHoldDuration = \(n(returnHoldDuration))
        config.asymmetry = \(n(asymmetry))
        config.horizontalStretch = \(n(horizontalStretch))
        config.verticalStretch = \(n(verticalStretch))
        config.deformationAmount = \(n(deformationAmount))
        config.deformationSpeed = \(n(deformationSpeed, 3))
        config.coreSize = \(n(coreSize))
        config.diffusion = \(n(diffusion))
        config.lightOffsetX = \(n(lightOffsetX))
        config.lightOffsetY = \(n(lightOffsetY))
        config.driftRange = \(n(driftRange))
        config.warmth = \(n(warmth))
        config.shellLightDelay = \(n(shellLightDelay))
        config.lightSettlingDuration = \(n(lightSettlingDuration))
        """
    }

    private func n(_ value: Double, _ places: Int = 2) -> String {
        String(format: "%.\(places)f", value)
    }
}

enum OrbTuningDefaults {
    static let idleSize = 96.0
    static let breathDuration = 6.8
    static let breathAmplitude = 0.025
    static let shellOpacity = 0.92
    static let lightOpacity = 0.74
    static let lightBlur = 20.0
    static let lightXDrift = -2.0
    static let lightYDrift = 3.0
    static let lightDriftDuration = 12.5

    static let attentiveScale = 1.06
    static let attentiveDuration = 0.52
    static let attentiveLightChange = 0.16

    static let holdDuration = 1.8
    static let holdStartSize = 150.0
    static let holdEndSize = 280.0
    static let holdOuterSoftness = 28.0
    static let holdLightStartOpacity = 0.68
    static let holdLightEndOpacity = 0.9
    static let holdLightSize = 0.40
    static let workspaceBlur = 24.0
    static let workspaceContrast = 0.48
    static let workspaceRecession = 1.0

    static let restSize = 150.0
    static let restBreathDuration = 9.2
    static let restGlowOpacity = 0.72

    static let returnSize = 168.0
    static let returnDuration = 1.3
    static let reentryDuration = 0.9
    static let returnHoldDuration = 2.5

    static let asymmetry = 0.4
    static let horizontalStretch = 1.06
    static let verticalStretch = 0.94
    static let deformationAmount = 0.45
    static let deformationSpeed = 0.03

    static let coreSize = 0.28
    static let diffusion = 0.85
    static let lightOffsetX = 0.0
    static let lightOffsetY = 0.0
    static let driftRange = 3.5
    static let warmth = 0.46

    static let shellLightDelay = 0.35
    static let lightSettlingDuration = 0.95
}
