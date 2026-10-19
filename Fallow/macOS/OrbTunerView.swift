#if DEBUG
import AppKit
import SwiftUI

enum OrbPreview: String, CaseIterable, Identifiable {
    case dormant
    case capture
    case threshold
    case holding
    case resting
    case returning
    case reentering

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dormant: "Dormant"
        case .capture: "Capture"
        case .threshold: "Threshold"
        case .holding: "Holding"
        case .resting: "Rest"
        case .returning: "Return"
        case .reentering: "Re-entry"
        }
    }

    var phase: OrbPhase {
        switch self {
        case .dormant: .dormant
        case .capture: .capture
        case .threshold: .threshold
        case .holding: .holding(progress: 0.45)
        case .resting: .resting
        case .returning: .returnDoorway
        case .reentering: .reentering
        }
    }
}

struct OrbTunerView: View {
    var session: SessionModel
    @Bindable var config: OrbTuningConfig
    @State private var preview: OrbPreview = .dormant
    @State private var copied = false
    @State private var replayTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("DEBUG")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if copied {
                    Text("Copied")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Picker("State", selection: $preview) {
                ForEach(OrbPreview.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .onChange(of: preview) { _, newValue in
                replayTask?.cancel()
                session.showPreview(newValue.phase)
            }
            HStack {
                Button("Replay", action: replay)
                Button("Reset defaults", action: reset)
                Button("Copy config", action: copyConfig)
            }
            .buttonStyle(.bordered)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    group("Idle") {
                        slider("Orb size", $config.idleSize, 48...180, "pt")
                        slider("Breath duration", $config.breathDuration, 4...12, "s")
                        slider("Breath amplitude", $config.breathAmplitude, 0...0.035, "", 3)
                        slider("Shell opacity", $config.shellOpacity, 0.4...0.95)
                        slider("Light opacity", $config.lightOpacity, 0.15...1)
                        slider("Light blur", $config.lightBlur, 2...32, "pt")
                        slider("Light x drift", $config.lightXDrift, -12...12, "pt")
                        slider("Light y drift", $config.lightYDrift, -12...12, "pt")
                        slider("Drift duration", $config.lightDriftDuration, 6...22, "s")
                    }
                    group("Attentive") {
                        slider("Scale", $config.attentiveScale, 1...1.2)
                        slider("Transition", $config.attentiveDuration, 0.2...1.2, "s")
                        slider("Light change", $config.attentiveLightChange, 0...0.4)
                    }
                    group("Hold") {
                        slider("Duration", $config.holdDuration, 0.8...3.2, "s")
                        slider("Start size", $config.holdStartSize, 80...240, "pt")
                        slider("End size", $config.holdEndSize, 140...380, "pt")
                        slider("Outer softness", $config.holdOuterSoftness, 4...40, "pt")
                        slider("Light start", $config.holdLightStartOpacity, 0.2...1)
                        slider("Light end", $config.holdLightEndOpacity, 0.2...1)
                        slider("Light size", $config.holdLightSize, 0.12...0.7)
                        slider("Workspace blur", $config.workspaceBlur, 0...40)
                        slider("Contrast reduction", $config.workspaceContrast, 0...1)
                        slider("Recession", $config.workspaceRecession, 0...1)
                    }
                    group("Rest") {
                        slider("Size", $config.restSize, 48...160, "pt")
                        slider("Breath duration", $config.restBreathDuration, 6...14, "s")
                        slider("Glow opacity", $config.restGlowOpacity, 0.05...1)
                    }
                    group("Return") {
                        slider("Orb size", $config.returnSize, 80...260, "pt")
                        slider("Return duration", $config.returnDuration, 0.6...2.2, "s")
                        slider("Re-entry duration", $config.reentryDuration, 0.4...1.8, "s")
                        slider("Hold to return", $config.returnHoldDuration, 1.2...4, "s")
                    }
                    group("Form") {
                        slider("Asymmetry", $config.asymmetry, 0...1)
                        slider("Horizontal stretch", $config.horizontalStretch, 0.8...1.25)
                        slider("Vertical stretch", $config.verticalStretch, 0.8...1.25)
                        slider("Deformation", $config.deformationAmount, 0...1)
                        slider("Deformation speed", $config.deformationSpeed, 0...0.3, "Hz", 3)
                    }
                    group("Light") {
                        slider("Core size", $config.coreSize, 0.08...0.55)
                        slider("Diffusion", $config.diffusion, 0...1.8)
                        slider("X offset", $config.lightOffsetX, -12...12, "pt")
                        slider("Y offset", $config.lightOffsetY, -12...12, "pt")
                        slider("Drift range", $config.driftRange, 0...12, "pt")
                        slider("Warmth", $config.warmth, 0...1)
                    }
                    group("Phase") {
                        slider("Shell / light delay", $config.shellLightDelay, 0...1.2, "s")
                        slider("Light settling", $config.lightSettlingDuration, 0.4...1.8, "s")
                    }
                }
                .padding(.bottom, 12)
            }
        }
        .padding(16)
        .frame(minWidth: 380, minHeight: 480)
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            content()
        }
    }

    private func slider(
        _ title: String,
        _ value: Binding<Double>,
        _ range: ClosedRange<Double>,
        _ unit: String = "",
        _ places: Int = 2
    ) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12))
                .frame(width: 128, alignment: .leading)
            Slider(value: value, in: range)
            Text(label(value.wrappedValue, places: places, unit: unit))
                .font(.system(size: 11, design: .monospaced))
                .frame(width: 64, alignment: .trailing)
                .foregroundStyle(.secondary)
        }
    }

    private func label(_ value: Double, places: Int, unit: String) -> String {
        let number = String(format: "%.\(places)f", value)
        return unit.isEmpty ? number : "\(number) \(unit)"
    }

    private func reset() {
        replayTask?.cancel()
        config.reset()
        session.holdDuration = config.holdDuration
        session.reentryDuration = config.reentryDuration
        session.returnHoldDuration = config.returnHoldDuration
    }

    private func copyConfig() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(config.swiftSource(), forType: .string)
        copied = true
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            copied = false
        }
    }

    private func replay() {
        replayTask?.cancel()
        replayTask = Task { @MainActor in
            switch preview {
            case .holding:
                session.showPreview(.threshold)
                let duration = max(0.2, config.holdDuration)
                let start = Date()
                while !Task.isCancelled {
                    let progress = min(1, Date().timeIntervalSince(start) / duration)
                    session.phase = .holding(progress: progress)
                    session.softness = progress
                    if progress >= 1 {
                        session.finishHold()
                        return
                    }
                    try? await Task.sleep(nanoseconds: 16_000_000)
                }
            case .resting:
                session.showPreview(.threshold)
                session.phase = .holding(progress: 1)
                session.softness = 1
                session.finishHold()
            case .returning:
                session.showPreview(.returnDoorway)
            case .reentering:
                session.showPreview(.beforeAfter)
                session.returnHoldDuration = config.returnHoldDuration
                session.reentryDuration = config.reentryDuration
                session.pressReturn()
            default:
                session.showPreview(preview.phase)
            }
        }
    }
}
#endif
