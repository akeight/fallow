import SwiftUI

/// Starting a Fallow from the phone. On the Mac the work recedes; here the thought does.
struct PauseFlowView: View {
    var store: PhoneStore

    var body: some View {
        ZStack {
            switch store.step {
            case .capture:
                CaptureStep(store: store).transition(.fallowText)
            case .transcript:
                TranscriptStep(store: store).transition(.fallowText)
            case .refine:
                RefineStep(store: store).transition(.fallowText)
            case .distance:
                DistanceStep(store: store).transition(.fallowText)
            case .release, .releasing:
                ReleaseView(store: store).transition(.opacity)
            case .resting:
                RestingView(store: store).transition(.fallowText)
            case .returning, .reflect, .beforeAfter:
                ReturnView(store: store).transition(.fallowText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CaptureStep: View {
    var store: PhoneStore

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                CornerButton(systemName: "xmark", label: "Cancel") { store.cancelFlow() }
                Spacer()
            }
            .padding(.top, 4)

            Text(DemoCopy.carrying)
                .font(FallowType.display(32))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .padding(.top, 18)

            Spacer(minLength: 0)

            VStack(spacing: 14) {
                if store.isRecording {
                    Text(store.voice.transcript.isEmpty ? " " : store.voice.transcript)
                        .font(FallowType.process)
                        .foregroundStyle(Theme.mute)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .truncationMode(.head)
                        .frame(minHeight: 44, alignment: .bottom)
                        .animation(.easeOut(duration: 0.3), value: store.voice.transcript)
                        .transition(.fallowText)
                }

                field

                QuietButton(title: store.isRecording ? "Cancel" : "Type instead") {
                    store.isRecording ? store.cancelFlow() : store.typeInstead()
                }
            }
            .padding(.bottom, store.isRecording ? 40 : 96)
        }
        .padding(.horizontal, 28)
    }

    private var field: some View {
        Button { store.toggleRecording() } label: {
            HStack(spacing: 12) {
                Text(store.isRecording ? "Listening" : "Speak it, and let it out")
                    .font(FallowType.secondary)
                    .foregroundStyle(store.isRecording ? Theme.ink : Theme.mute)
                    .contentTransition(.opacity)
                Spacer(minLength: 0)
                ZStack {
                    Circle()
                        .fill(store.isRecording ? Theme.ink.opacity(0.85) : Theme.light.opacity(0.9))
                    Image(systemName: store.isRecording ? "stop.fill" : "mic")
                        .font(.system(size: store.isRecording ? 12 : 16, weight: .medium))
                        .foregroundStyle(store.isRecording ? Theme.canvas : Theme.ink)
                        .contentTransition(.symbolEffect(.replace))
                }
                .frame(width: 38, height: 38)
            }
            .padding(.leading, 20)
            .padding(.trailing, 7)
            .frame(height: 52)
            .glass(radius: 26, lit: store.isRecording)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(store.isRecording ? "Stop listening" : "Speak your thought")
    }
}

private struct TranscriptStep: View {
    @Bindable var store: PhoneStore
    @FocusState private var focused: Bool

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                HStack {
                    CornerButton(systemName: "chevron.left", label: "Back") { store.back() }
                    Spacer()
                }
                .padding(.top, 4)

                Eyebrow(text: store.focusTyping ? "What are you carrying?" : "You’re carrying")
                    .padding(.top, geo.size.height * 0.26)

                ZStack(alignment: .topLeading) {
                    if store.draft.isEmpty {
                        Text("Write it the way it sounds in your head.")
                            .font(FallowType.process)
                            .foregroundStyle(Theme.ash)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $store.draft)
                        .font(FallowType.process)
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(5)
                        .scrollContentBackground(.hidden)
                        .focused($focused)
                }
                .frame(height: 130)
                .padding(14)
                .glass(radius: 20)
                .padding(.top, 14)

                Spacer(minLength: 16)

                VStack(spacing: 6) {
                    PrimaryButton(title: "Continue") { store.continueFromTranscript() }
                    Button { store.rerecord() } label: {
                        Label("Say it again", systemImage: "mic")
                            .font(FallowType.quietButton)
                            .foregroundStyle(Theme.mute)
                            .frame(minHeight: 44)
                            .padding(.horizontal, 8)
                    }
                    .buttonStyle(PressableStyle())
                }
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 28)
        }
        .onAppear {
            if store.focusTyping { focused = true }
        }
    }
}

private struct RefineStep: View {
    var store: PhoneStore

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                HStack {
                    CornerButton(systemName: "chevron.left", label: "Back") { store.back() }
                    Spacer()
                }
                .padding(.top, 4)

                Text(DemoCopy.feelsLike)
                    .font(FallowType.display(30))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, geo.size.height * 0.08)

                Text("A guess. Change it if it doesn’t fit.")
                    .font(FallowType.caption)
                    .foregroundStyle(Theme.ash)
                    .padding(.top, 8)

                VStack(spacing: 8) {
                    ForEach(CreativeState.allCases) { state in
                        card(state)
                    }
                }
                .padding(.top, 20)

                Spacer(minLength: 12)

                PrimaryButton(title: "Continue") { store.continueFromRefine() }
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, 24)
        }
    }

    private func card(_ state: CreativeState) -> some View {
        let selected = store.creativeState == state
        return Button { store.choose(state) } label: {
            HStack(spacing: 14) {
                Circle()
                    .fill(selected ? Petal.deep : Theme.rim.opacity(0.6))
                    .frame(width: 8, height: 8)
                    .shadow(color: Petal.fill.opacity(selected ? 0.9 : 0), radius: 6)
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.title)
                        .font(.system(size: 16, weight: selected ? .semibold : .regular))
                        .foregroundStyle(Theme.ink)
                    Text(state.subtitle)
                        .font(FallowType.caption)
                        .foregroundStyle(Theme.ash)
                }
                Spacer(minLength: 0)
                if state == store.suggestedState {
                    Text("Suggested")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.ash)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 58)
            .glass(radius: 16, lit: selected)
            .animation(.easeInOut(duration: 0.35), value: selected)
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct DistanceStep: View {
    var store: PhoneStore

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                CornerButton(systemName: "chevron.left", label: "Back") { store.back() }
                Spacer()
            }
            .padding(.top, 4)

            Text(DemoCopy.distancePrompt)
                .font(FallowType.display(28))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .padding(.top, 14)
                .padding(.horizontal, 12)

            Spacer(minLength: 0)

            VStack(spacing: 4) {
                ForEach(DistanceKind.allCases) { kind in
                    option(kind)
                }
            }
            .padding(.bottom, 36)
        }
        .padding(.horizontal, 28)
    }

    private func option(_ kind: DistanceKind) -> some View {
        let selected = store.distance == kind
        return Button { store.choose(kind) } label: {
            Text(kind.title)
                .font(.system(size: 18, weight: selected ? .medium : .regular))
                .foregroundStyle(selected ? Theme.ink : Theme.mute)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background {
                    if selected {
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(Capsule().fill(Petal.soft.opacity(0.85)))
                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.9), lineWidth: 1))
                            .shadow(color: Petal.deep.opacity(0.2), radius: 14)
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }
                }
                .contentShape(Capsule())
                .animation(.easeInOut(duration: 0.35), value: selected)
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
