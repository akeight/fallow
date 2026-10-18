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
            case .returning, .reflect, .beforeAfter, .stillStuck, .reframe, .reframeCompare:
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
                status
                    .frame(minHeight: 66, alignment: .bottom)

                field

                VStack(spacing: 0) {
                    QuietButton(title: store.isRecording ? "Cancel" : "Type instead") {
                        store.isRecording ? store.cancelListening() : store.typeInstead()
                    }
                    .disabled(store.isGathering)
                    #if DEBUG
                    if !store.isRecording && !store.isGathering {
                        QuietButton(title: "Use the demo note", color: Theme.ash) { store.useDemoNote() }
                    }
                    #endif
                }
            }
            .padding(.bottom, store.isRecording ? 40 : 96)
        }
        .padding(.horizontal, 28)
    }

    /// Only the latest words while listening; older ones fade away so the screen stays calm.
    @ViewBuilder
    private var status: some View {
        if store.isRecording {
            Text(store.voice.recentTranscript.isEmpty ? " " : store.voice.recentTranscript)
                .font(FallowType.process)
                .foregroundStyle(Theme.mute)
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
                .foregroundStyle(Theme.mute)
                .multilineTextAlignment(.center)
                .transition(.fallowText)
        }
    }

    private var label: String {
        if store.isRecording { return DemoCopy.listening }
        if store.isGathering { return DemoCopy.gathering }
        if store.voiceError != nil { return DemoCopy.tryAgain }
        return "Speak it, and let it out"
    }

    private var field: some View {
        Button { store.toggleRecording() } label: {
            HStack(spacing: 12) {
                Text(label)
                    .font(FallowType.secondary)
                    .foregroundStyle(store.isRecording ? Theme.ink : Theme.mute)
                    .contentTransition(.opacity)
                Spacer(minLength: 0)
                ZStack {
                    Circle()
                        .fill(store.isRecording ? Theme.ink.opacity(0.85) : Haze.dawn.opacity(0.7))
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
        .disabled(store.isGathering)
        .accessibilityLabel(store.isRecording ? "Stop listening" : "Speak your thought")
        .accessibilityValue(store.isRecording ? "Recording" : "")
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
                    CornerButton(systemName: "chevron.left", label: "Back") { store.back() }
                    Spacer()
                }
                .padding(.top, 4)

                Eyebrow(text: spoken ? DemoCopy.carryingVoice : (store.focusTyping ? "What are you carrying?" : "You’re carrying"))
                    .padding(.top, geo.size.height * 0.26)

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
                            QuietButton(title: DemoCopy.edit) {
                                editing = true
                                focused = true
                            }
                        }
                        if store.session?.hasFullNote == true {
                            QuietButton(title: DemoCopy.viewFullNote, color: Theme.ash) { showsNote = true }
                        }
                    }
                    .padding(.top, 6)
                }

                Spacer(minLength: 16)

                VStack(spacing: 6) {
                    PrimaryButton(title: "Continue") { store.continueFromTranscript() }
                        .disabled(isEmpty)
                        .opacity(isEmpty ? 0.5 : 1)
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
        .sheet(isPresented: $showsNote) {
            FullNoteSheet(text: store.session?.rawTranscript ?? "")
        }
    }

    private var isEmpty: Bool {
        store.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var carried: some View {
        ThoughtText(text: store.draft)
            .frame(maxWidth: .infinity, minHeight: 102, alignment: .topLeading)
            .padding(20)
            .glass(radius: 20)
    }

    private var editor: some View {
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
        .presentationDetents([.medium, .large])
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

                Text(store.interpretation.suggestedState == nil ? DemoCopy.notSureYet : DemoCopy.suggestedGuess)
                    .font(FallowType.caption)
                    .foregroundStyle(Theme.ash)
                    .padding(.top, 8)

                VStack(spacing: 8) {
                    ForEach(CreativeState.allCases) { state in
                        ChoiceRow(
                            title: state.title,
                            subtitle: state.meaning,
                            note: state == store.interpretation.suggestedState ? "Suggested" : nil,
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

/// One answer in a short list. Tapping it is the answer; there is no separate Continue.
struct ChoiceRow: View {
    var title: String
    var subtitle: String? = nil
    var note: String? = nil
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Circle()
                    .fill(selected ? Haze.sand : Theme.rim)
                    .frame(width: 8, height: 8)
                    .shadow(color: Haze.dawn.opacity(selected ? 0.9 : 0), radius: 6)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: selected ? .semibold : .regular))
                        .foregroundStyle(Theme.ink)
                    if let subtitle {
                        Text(subtitle)
                            .font(FallowType.caption)
                            .foregroundStyle(Theme.mute)
                    }
                }
                Spacer(minLength: 0)
                if let note {
                    Text(note)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.ash)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: subtitle == nil ? 52 : 58)
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
