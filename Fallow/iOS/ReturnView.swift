import SwiftUI

/// Attention reforming around the thought. The room gathers inward and the surfaces return.
/// The return does not assume the break worked: something shifted, or it is still here.
struct ReturnView: View {
    @Bindable var store: PhoneStore

    var body: some View {
        ZStack {
            switch store.step {
            case .reflect:
                recapture(
                    prompt: DemoCopy.different,
                    text: $store.reflection,
                    target: .shift,
                    confirm: store.confirmReflection
                )
                .transition(.fallowText)
            case .beforeAfter:
                compare(
                    before: DemoCopy.beforeLabel,
                    after: DemoCopy.afterLabel,
                    afterText: store.reflection,
                    leaveLonger: false
                )
                .transition(.fallowText)
            case .stillStuck:
                stillStuck.transition(.fallowText)
            case .reframe:
                recapture(
                    prompt: DemoCopy.unresolvedNow,
                    text: $store.reframe,
                    target: .reframe,
                    confirm: store.confirmReframe
                )
                .transition(.fallowText)
            case .reframeCompare:
                compare(
                    before: DemoCopy.originalLabel,
                    after: DemoCopy.nowLabel,
                    afterText: store.reframe,
                    leaveLonger: true
                )
                .transition(.fallowText)
            default:
                welcome.transition(.fallowText)
            }
        }
    }

    // MARK: Welcome back

    private var welcome: some View {
        let session = store.session ?? DemoSessionFactory.fragments
        let fromMac = session.originDevice == .mac
        return GeometryReader { geo in
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    HStack {
                        CornerButton(systemName: "chevron.left", label: "Back to Home", color: Theme.muteOnDense) { store.cancelFlow() }
                        Spacer()
                    }
                    .padding(.top, 4)

                    // A thought released on the Mac is reflected on there, so the phone only hands it back.
                    Text(fromMac ? DemoCopy.macReady : DemoCopy.welcomeBack)
                        .font(FallowType.display(34))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                        .padding(.top, 10)

                    Spacer(minLength: 0)

                    VStack(spacing: 6) {
                        if !fromMac {
                            PrimaryButton(title: DemoCopy.somethingShifted) { store.somethingShifted() }
                            QuietButton(title: DemoCopy.stillStuck, color: Theme.muteOnDense) { store.stillStuck() }
                        }
                    }
                    .frame(minHeight: 52)
                    .padding(.bottom, fromMac ? 24 : 10)
                }

                // The prompt and the thought sit on the lower third, under the orb.
                VStack(spacing: 14) {
                    Text(welcomeLine(for: session))
                        .font(FallowType.secondary)
                        .foregroundStyle(Theme.muteOnDense)
                        .contentTransition(.opacity)

                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow(text: "You left with", color: Theme.muteOnDense)
                        ThoughtText(text: session.unresolvedThought, color: Theme.ink)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .glass(radius: 20)
                }
                .padding(.top, geo.size.height * 0.52)
            }
            .padding(.horizontal, 28)
        }
    }

    private func welcomeLine(for session: FallowSession) -> String {
        session.originDevice == .mac ? session.waitingLine : DemoCopy.hadSpace
    }

    // MARK: Still stuck

    private var stillStuck: some View {
        VStack(spacing: 0) {
            HStack {
                CornerButton(systemName: "chevron.left", label: "Back", color: Theme.muteOnDense) { store.back() }
                Spacer()
            }
            .padding(.top, 4)

            Text(DemoCopy.stillCarrying)
                .font(FallowType.display(28))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .padding(.top, 14)

            Spacer(minLength: 0)

            VStack(spacing: 8) {
                ChoiceRow(title: DemoCopy.leaveLonger, selected: false) { store.leaveLonger() }
                ChoiceRow(title: DemoCopy.sayUnresolved, selected: false) { store.sayWhatsUnresolved() }
                ChoiceRow(title: DemoCopy.goBackAnyway, selected: false) { store.goBackIn() }
            }
            .padding(.bottom, 28)
        }
        .padding(.horizontal, 24)
    }

    // MARK: One-step recapture

    /// Used for "what feels different" and for the reframe. One question, nothing else re-asked.
    private func recapture(
        prompt: String,
        text: Binding<String>,
        target: RecordingTarget,
        confirm: @escaping () -> Void
    ) -> some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                HStack {
                    CornerButton(systemName: "chevron.left", label: "Back", color: Theme.muteOnDense) { store.back() }
                    Spacer()
                }
                .padding(.top, 4)

                Text(prompt)
                    .font(FallowType.display(28))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .padding(.top, geo.size.height * 0.15)

                ThoughtComposer(
                    text: text,
                    placeholder: store.voiceError?.message ?? "Say it, or write it.",
                    isRecording: store.isRecording,
                    onMic: { store.isRecording ? store.stopRecording() : store.startRecording(target) },
                    onSubmit: confirm
                )
                .padding(.top, 24)

                Spacer(minLength: 16)
            }
            .padding(.horizontal, 28)
        }
    }

    // MARK: Before and after

    /// The shift is kept, whether the problem resolved or only changed shape.
    private func compare(before: String, after: String, afterText: String, leaveLonger: Bool) -> some View {
        let session = store.session ?? .demoFromPhone
        return GeometryReader { geo in
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow(text: before, color: Theme.muteOnDense)
                    ThoughtText(text: session.unresolvedThought, color: Theme.muteOnDense)
                }

                Rectangle()
                    .fill(Theme.rim)
                    .frame(height: 1)
                    .padding(.vertical, 26)

                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow(text: after, color: Theme.muteOnDense)
                    ThoughtText(text: afterText, color: Theme.ink)
                }

                Spacer(minLength: 16)

                VStack(spacing: 6) {
                    PrimaryButton(title: DemoCopy.goBack) { store.goBackIn() }
                    if leaveLonger {
                        QuietButton(title: DemoCopy.leaveLittleLonger, color: Theme.muteOnDense) { store.leaveLonger() }
                    }
                }
                .padding(.bottom, leaveLonger ? 10 : 20)
            }
            .padding(.top, geo.size.height * 0.24)
            .padding(.horizontal, 32)
        }
    }
}
