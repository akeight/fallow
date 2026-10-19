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
    @Bindable var store: PhoneStore

    var body: some View {
        VStack(spacing: 0) {
            Text(DemoCopy.carrying)
                .font(FallowType.display(32))
                .foregroundStyle(Theme.inkOnDeep)
                .multilineTextAlignment(.center)
                .padding(.top, 66)

            Spacer(minLength: 0)

            VStack(spacing: 14) {
                status
                    .frame(minHeight: 66, alignment: .bottom)

                ThoughtComposer(
                    text: $store.draft,
                    placeholder: store.voiceError == nil ? "Speak it, and let it out" : DemoCopy.tryAgain,
                    isRecording: store.isRecording,
                    isGathering: store.isGathering || store.isInterpreting,
                    deep: true,
                    onMic: store.toggleRecording,
                    onSubmit: store.submitTyped
                )

                VStack(spacing: 0) {
                    if store.isRecording {
                        QuietButton(title: "Cancel", color: Theme.muteOnDeep) { store.cancelListening() }
                    }
                    #if DEBUG
                    if !store.isRecording && !store.isGathering && !store.isInterpreting && store.draft.isEmpty {
                        QuietButton(title: "Use the demo note", color: Theme.muteOnDeep) { store.useDemoNote() }
                    }
                    #endif
                }
            }
            .padding(.bottom, store.keyboardVisible ? 12 : store.isRecording ? 40 : 96)
        }
        .padding(.horizontal, 28)
    }

    /// Only the latest words while listening; older ones fade away so the screen stays calm.
    @ViewBuilder
    private var status: some View {
        if store.isRecording {
            Text(store.voice.recentTranscript.isEmpty ? " " : store.voice.recentTranscript)
                .font(FallowType.process)
                .foregroundStyle(Theme.muteOnDeep)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .truncationMode(.head)
                .mask(LinearGradient(colors: [.clear, .black, .black], startPoint: .top, endPoint: .center))
                .animation(.easeOut(duration: 0.3), value: store.voice.recentTranscript)
                .accessibilityHidden(true)
                .transition(.fallowText)
        } else if let error = store.voiceError {
            Text(error.message)
                .font(FallowType.secondary)
                .foregroundStyle(Theme.muteOnDeep)
                .multilineTextAlignment(.center)
                .transition(.fallowText)
        }
    }

}

/// After voice, the carried thought is the object; the full note sits behind a quiet link.
/// After typing, the editor comes first.
private struct TranscriptStep: View {
    @Bindable var store: PhoneStore
    @FocusState private var focused: Bool
    @State private var editing = false
    @State private var showsNote = false

    private var spoken: Bool { store.session?.captureMethod == .voice }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                HStack {
                    CornerButton(systemName: "chevron.left", label: "Back", color: Theme.muteOnDeep) { store.back() }
                    Spacer()
                }
                .padding(.top, 4)

                Eyebrow(text: spoken ? DemoCopy.carryingVoice : (store.focusTyping ? "What are you carrying?" : "You’re carrying"), color: Theme.muteOnDeep)
                    .padding(.top, geo.size.height * (store.keyboardVisible ? 0.15 : 0.26))

                Group {
                    if spoken && !editing {
                        carried
                    } else {
                        editor
                    }
                }
                .padding(.top, 14)

                if spoken {
                    HStack(spacing: 4) {
                        if !editing {
                            QuietButton(title: DemoCopy.edit, color: Theme.muteOnDeep) {
                                editing = true
                                focused = true
                            }
                        }
                        if store.session?.hasFullNote == true {
                            QuietButton(title: DemoCopy.viewFullNote, color: Theme.muteOnDeep) { showsNote = true }
                        }
                    }
                    .padding(.top, 6)
                }

                Spacer(minLength: 16)

                VStack(spacing: 6) {
                    PrimaryButton(title: store.isInterpreting ? DemoCopy.reading : "Continue") { store.continueFromTranscript() }
                        .disabled(isEmpty || store.isInterpreting)
                        .opacity(isEmpty || store.isInterpreting ? 0.5 : 1)
                    Button { store.rerecord() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "mic")
                            Text("Say it again").underline()
                        }
                            .font(FallowType.quietButton)
                            .foregroundStyle(Theme.muteOnDeep)
                            .frame(minHeight: 44)
                            .padding(.horizontal, 8)
                    }
                    .buttonStyle(PressableStyle())
                }
                .padding(.bottom, store.keyboardVisible ? 8 : 20)
            }
            .padding(.horizontal, 28)
        }
        .onAppear {
            if store.focusTyping { focused = true }
        }
        .sheet(isPresented: $showsNote) {
            FullNoteSheet(text: store.session?.rawTranscript ?? "")
        }
    }

    private var isEmpty: Bool {
        store.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var carried: some View {
        ThoughtText(text: store.draft, color: Theme.inkOnDeep)
            .frame(maxWidth: .infinity, minHeight: 102, alignment: .topLeading)
            .padding(20)
            .glass(radius: 20)
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            if store.draft.isEmpty {
                Text("Write it the way it sounds in your head.")
                    .font(FallowType.process)
                    .foregroundStyle(Theme.muteOnDeep)
                    .padding(.top, 8)
                    .padding(.leading, 5)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $store.draft)
                .font(FallowType.process)
                .foregroundStyle(Theme.inkOnDeep)
                .lineSpacing(5)
                .scrollContentBackground(.hidden)
                .focused($focused)
        }
        .frame(height: 130)
        .padding(14)
        .glass(radius: 20)
    }
}

/// The whole spoken note, as source material. Read-only and selectable.
private struct FullNoteSheet: View {
    var text: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Eyebrow(text: DemoCopy.fullNote)
                Spacer()
                QuietButton(title: "Done") { dismiss() }
            }
            ScrollView {
                Text(text)
                    .font(FallowType.process)
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(5)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 12)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 20)
        .background(Theme.canvas)
        .environment(\.colorScheme, .light)
        .presentationDetents([.medium, .large])
    }
}

private struct RefineStep: View {
    var store: PhoneStore

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                HStack {
                    CornerButton(systemName: "chevron.left", label: "Back", color: Theme.muteOnDeep) { store.back() }
                    Spacer()
                }
                .padding(.top, 4)

                Text(DemoCopy.feelsLike)
                    .font(FallowType.display(30))
                    .foregroundStyle(Theme.inkOnDeep)
                    .padding(.top, geo.size.height * 0.08)

                Text(store.interpretation?.suggestedState == nil ? DemoCopy.notSureYet : DemoCopy.suggestedGuess)
                    .font(FallowType.caption)
                    .foregroundStyle(Theme.muteOnDeep)
                    .padding(.top, 8)

                VStack(spacing: 8) {
                    ForEach(CreativeState.allCases) { state in
                        ChoiceRow(
                            title: state.title,
                            subtitle: state.meaning,
                            note: state == store.interpretation?.suggestedState ? "Suggested" : nil,
                            selected: store.highlightedState == state
                        ) { store.choose(state) }
                    }
                }
                .padding(.top, geo.size.height * 0.07)

                Spacer(minLength: 12)
            }
            .padding(.horizontal, 24)
        }
    }
}

private struct DistanceStep: View {
    var store: PhoneStore

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                CornerButton(systemName: "chevron.left", label: "Back", color: Theme.muteOnDeep) { store.back() }
                Spacer()
            }
            .padding(.top, 4)

            Text(DemoCopy.distancePrompt)
                .font(FallowType.display(28))
                .foregroundStyle(Theme.inkOnDeep)
                .multilineTextAlignment(.center)
                .padding(.top, 14)
                .padding(.horizontal, 16)

            Spacer(minLength: 0)

            VStack(spacing: 8) {
                ForEach(FallowDistance.allCases) { kind in
                    ChoiceRow(title: kind.title, selected: store.session?.distance == kind) {
                        store.choose(kind)
                    }
                }
            }
            .padding(.bottom, 28)
        }
        .padding(.horizontal, 24)
    }
}
