import AppKit
import SwiftUI

struct CompanionView: View {
    @Bindable var session: SessionModel
    var config: OrbTuningConfig
    var syncChrome: () -> Void
    var syncVeil: () -> Void
    var openTuner: () -> Void
    @State private var sounds = BreakSounds()

    var body: some View {
        ZStack(alignment: alignment) {
            Color.clear
            switch session.phase {
            case .dormant, .reentering:
                orb
            case .capture:
                capture
            case .classifyStuck:
                choices(
                    prompt: DemoCopy.stuckPrompt,
                    items: StuckKind.allCases.map { ($0.title, $0 == session.stuck) },
                    select: { session.chooseStuck(StuckKind.allCases[$0]) }
                )
            case .chooseDistance:
                choices(
                    prompt: DemoCopy.distancePrompt,
                    items: DistanceKind.allCases.map { ($0.title, $0 == session.distance) },
                    select: { session.chooseDistance(DistanceKind.allCases[$0]) }
                )
            case .threshold, .holding:
                threshold
            case .resting:
                resting
            case .returnDoorway:
                doorway
            case .reflecting:
                reflecting
            case .beforeAfter:
                beforeAfter
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        .onExitCommand(perform: session.leave)
        .contextMenu {
            #if DEBUG
            Button("Tune orb") { openTuner() }
            #endif
            Button("Quit FALLOW") { NSApp.terminate(nil) }
        }
        .onAppear {
            pushTiming()
            session.breakCue = { [sounds] cue in
                switch cue {
                case .open: sounds.open()
                case .into: sounds.beginHold()
                case .cancel: sounds.cancelHold()
                case .out: sounds.returnFromBreak()
                case .stop: sounds.stopAll()
                }
            }
            syncChrome()
        }
        .onChange(of: layoutKey) { _, _ in syncChrome() }
        .onChange(of: session.softness) { _, _ in syncVeil() }
        .onChange(of: config.holdDuration) { _, _ in pushTiming() }
        .onChange(of: config.reentryDuration) { _, _ in pushTiming() }
        .onChange(of: config.layoutSignature) { _, _ in syncChrome() }
        .onChange(of: config.veilSignature) { _, _ in syncChrome() }
    }

    private func pushTiming() {
        session.holdDuration = config.holdDuration
        session.reentryDuration = config.reentryDuration
    }

    /// Ignores hold progress, so the window does not move on every tick.
    private var layoutKey: String {
        switch session.phase {
        case .dormant: "dormant"
        case .capture: session.thoughtIsCaptured ? "capture-kept" : "capture"
        case .classifyStuck: "stuck"
        case .chooseDistance: "distance"
        case .threshold, .holding: "threshold"
        case .resting: session.showsLens ? "lens" : "rest"
        case .returnDoorway: "return"
        case .reflecting: "reflect"
        case .beforeAfter: "compare"
        case .reentering: "reenter"
        }
    }

    private var alignment: Alignment {
        switch session.phase {
        case .threshold, .holding:
            .center
        case .returnDoorway, .reflecting, .beforeAfter:
            .topLeading
        default:
            .bottomTrailing
        }
    }

    private var orb: some View {
        OrbView(session: session, config: config)
            .modifier(OrbInput(session: session))
            .padding(session.phase == .dormant || session.phase == .reentering ? 4 : 0)
            .help(session.phase == .resting ? "Return" : "FALLOW")
    }

    private var capture: some View {
        VStack(alignment: .leading, spacing: 0) {
            card {
                Text(DemoCopy.carrying)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                if session.thoughtIsCaptured {
                    Text(session.thought)
                        .font(FallowType.macProcess)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    quietButton(DemoCopy.keep, action: session.confirmThought)
                } else {
                    Text("Voice, or text. The canvas stays visible.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.mute)
                    quietButton(DemoCopy.showThought, action: session.revealThought)
                }
            }
            HStack {
                Spacer(minLength: 0)
                orb
            }
        }
        .padding(12)
    }

    private func choices(prompt: String, items: [(String, Bool)], select: @escaping (Int) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            card {
                Text(prompt)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 6) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        Button {
                            select(index)
                        } label: {
                            Text(item.0)
                                .font(.system(size: 14, weight: item.1 ? .medium : .regular))
                                .foregroundStyle(item.1 ? Theme.canvas : Theme.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(item.1 ? Theme.ink : Theme.field, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            HStack {
                Spacer(minLength: 0)
                orb
            }
        }
        .padding(12)
    }

    private var threshold: some View {
        VStack(spacing: 10) {
            orb
            HStack(spacing: 8) {
                Text(DemoCopy.hold)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .fixedSize()
                Button(action: session.leave) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.ink.opacity(0.72))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help("Leave")
                .accessibilityLabel("Leave")
            }
            .padding(.leading, 18)
            .padding(.trailing, 10)
            .padding(.vertical, 8)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.rim, lineWidth: 1)
            )
        }
    }

    private var resting: some View {
        VStack(alignment: .leading, spacing: 12) {
            if session.showsLens {
                Text(DemoCopy.lens)
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: 320, alignment: .leading)
                    .padding(18)
                    .background(Theme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Theme.rim, lineWidth: 1)
                    )
                    .overlay(alignment: .topTrailing) { leaveMark }
                    .transition(.opacity)
            }
            Spacer(minLength: 0)
            HStack {
                Spacer(minLength: 0)
                orb
            }
        }
        .padding(8)
    }

    private var doorway: some View {
        HStack(alignment: .top, spacing: 14) {
            orb
            VStack(alignment: .leading, spacing: 6) {
                Text(DemoCopy.leftHere)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.ash)
                Text(DemoCopy.project)
                    .font(FallowType.brand(22))
                    .foregroundStyle(Theme.ink)
                Text(session.thought)
                    .font(FallowType.macProcess)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                quietButton("Continue", action: session.continueFromDoorway)
                    .padding(.top, 8)
            }
            .dialogChrome(leave: session.leave)
        }
        .padding(18)
    }

    private var reflecting: some View {
        HStack(alignment: .top, spacing: 14) {
            orb
            VStack(alignment: .leading, spacing: 10) {
                Text(DemoCopy.different)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if session.reflection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    quietButton(DemoCopy.showThought, action: {
                        session.reflection = DemoCopy.reflection
                    })
                } else {
                    Text(session.reflection)
                        .font(FallowType.macProcess)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    quietButton("Keep this", action: session.confirmReflection)
                }
            }
            .dialogChrome(leave: session.leave)
        }
        .padding(18)
    }

    private var beforeAfter: some View {
        HStack(alignment: .top, spacing: 14) {
            orb
            VStack(alignment: .leading, spacing: 8) {
                Text(DemoCopy.beforeLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.ash)
                Text(DemoCopy.before)
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.mute)
                    .fixedSize(horizontal: false, vertical: true)
                Text(DemoCopy.afterLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.ash)
                    .padding(.top, 16)
                Text(session.reflection.isEmpty ? DemoCopy.after : session.reflection)
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                quietButton(DemoCopy.goBack, action: session.goBackIn)
                    .padding(.top, 12)
            }
            .dialogChrome(leave: session.leave)
        }
        .padding(18)
    }

    private var leaveMark: some View {
        LeaveButton(action: session.leave)
            .padding(8)
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(18)
        .padding(.trailing, 20)
        .frame(width: 300, alignment: .leading)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.rim, lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) { leaveMark }
    }

    private func quietButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Theme.ink)
            .padding(.top, 4)
    }
}

private extension View {
    func dialogChrome(leave: @escaping () -> Void) -> some View {
        padding(18)
            .padding(.trailing, 20)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.rim, lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                LeaveButton(action: leave)
                    .padding(8)
            }
    }
}

struct LeaveButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.ink)
                .frame(width: 22, height: 22)
                .background(Theme.paper.opacity(0.94), in: Circle())
                .overlay(Circle().stroke(Theme.rim, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help("Leave")
        .accessibilityLabel("Leave")
    }
}

private struct OrbInput: ViewModifier {
    var session: SessionModel

    @ViewBuilder
    func body(content: Content) -> some View {
        switch session.phase {
        case .threshold, .holding:
            content.gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in session.pressHold() }
                    .onEnded { _ in session.releaseHold() }
            )
        case .dormant:
            content
        case .resting:
            content.onTapGesture { session.tapOrb() }
        default:
            content
        }
    }
}
