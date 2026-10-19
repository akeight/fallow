import SwiftUI

/// Attention reforming around the thought. The room gathers inward and the surfaces return.
/// It ends the way the rest began: by holding the orb.
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
                BeforeAfter(store: store)
                    .transition(.fallowText)
            default:
                welcome.transition(.fallowText)
            }
        }
    }

    // MARK: Welcome back

    @ViewBuilder
    private var welcome: some View {
        let session = store.session ?? DemoSessionFactory.macRestingDemo
        if session.originDevice == .mac {
            handoff(session)
        } else {
            welcomeBack(session)
        }
    }

    /// A thought released on the Mac is reflected on there, so the phone only hands it back.
    /// Laid out like Home's resting state: heading above the orb, the thought beneath it.
    private func handoff(_ session: FallowSession) -> some View {
        GeometryReader { geo in
            let orbY = geo.size.height * HomeView.activeOrbY
            ZStack(alignment: .top) {
                HStack {
                    CornerButton(systemName: "chevron.left", label: "Back to Home", color: Theme.muteOnDense) { store.cancelFlow() }
                    Spacer()
                }
                .padding(.top, 4)

                // Bottom-aligned so the heading ends where Home's does, whether it takes one line or two.
                Text(DemoCopy.macReady)
                    .font(FallowType.display(30))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .frame(height: orbY - 100, alignment: .bottom)

                VStack(spacing: 14) {
                    Text(session.waitingLine)
                        .font(FallowType.secondary)
                        .foregroundStyle(Theme.muteOnDense)

                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow(text: "You left with", color: Theme.muteOnDense)
                        ThoughtText(text: session.unresolvedThought, color: Theme.ink, size: CardThought.size)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(CardThought.padding)
                    .glass(radius: CardThought.radius)
                }
                .padding(.top, orbY + 76)
            }
            .padding(.horizontal, 28)
        }
    }

    private func welcomeBack(_ session: FallowSession) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    HStack {
                        CornerButton(systemName: "chevron.left", label: "Back to Home", color: Theme.muteOnDense) { store.cancelFlow() }
                        Spacer()
                    }
                    .padding(.top, 4)

                    Text(DemoCopy.welcomeBack)
                        .font(FallowType.display(34))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                        .padding(.top, 10)

                    Spacer(minLength: 0)

                    PrimaryButton(title: DemoCopy.somethingShifted) { store.somethingShifted() }
                    .frame(minHeight: 52)
                    .padding(.bottom, 10)
                }

                // The prompt and the thought sit on the lower third, under the orb.
                VStack(spacing: 14) {
                    Text(DemoCopy.hadSpace)
                        .font(FallowType.secondary)
                        .foregroundStyle(Theme.muteOnDense)
                        .contentTransition(.opacity)

                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow(text: "You left with", color: Theme.muteOnDense)
                        ThoughtText(text: session.unresolvedThought, color: Theme.ink, size: CardThought.size)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(CardThought.padding)
                    .glass(radius: CardThought.radius)
                }
                .padding(.top, geo.size.height * 0.52)
            }
            .padding(.horizontal, 28)
        }
    }

    // MARK: One-step recapture

    /// "What feels different now": one question, nothing else re-asked.
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

}

// MARK: Before and after

/// The shift is kept. The orb sits near the middle and is what you hold to return;
/// long thoughts are clamped so the screen stays calm, with the whole text one tap away.
private struct BeforeAfter: View {
    var store: PhoneStore

    @State private var beforeClamped = false
    @State private var afterClamped = false
    @State private var showsFull = false

    var body: some View {
        let session = store.session ?? .demoFromPhone
        GeometryReader { geo in
            let orbY = geo.size.height * store.orbPlacement.y
            VStack(spacing: 0) {
                Text(DemoCopy.holdToReturn)
                    .font(FallowType.eyebrow)
                    .tracking(2.4)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.muteOnDense)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .opacity(1 - store.returnHold)
                    .accessibilityHidden(true)
                    .padding(.top, orbY + 110)

                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow(text: DemoCopy.beforeLabel, color: Theme.muteOnDense)
                        ClampedThought(text: session.unresolvedThought, color: Theme.muteOnDense, size: CardThought.quietSize, lines: 3, clamped: $beforeClamped)
                    }

                    Rectangle()
                        .fill(Theme.rim)
                        .frame(height: 1)
                        .padding(.vertical, 22)

                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow(text: DemoCopy.afterLabel, color: Theme.muteOnDense)
                        ClampedThought(text: store.reflection, color: Theme.ink, size: CardThought.size, lines: 4, clamped: $afterClamped)
                    }

                    if beforeClamped || afterClamped {
                        QuietButton(title: DemoCopy.viewFull, color: Theme.muteOnDense) { showsFull = true }
                            .padding(.top, 6)
                            .offset(x: -10)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 52)
                .padding(.horizontal, 4)

                Spacer(minLength: 12)

                QuietButton(title: DemoCopy.leaveLittleLonger, color: Theme.muteOnDense) { store.leaveLonger() }
                    .padding(.bottom, 10)
            }
            .padding(.horizontal, 28)
            .opacity(store.isBloomingHome ? 0 : 1)
            .animation(.easeOut(duration: 0.5), value: store.isBloomingHome)
        }
        .sheet(isPresented: $showsFull) {
            FullThoughtsSheet(before: session.unresolvedThought, after: store.reflection)
        }
    }
}

/// A thought cut to a few lines. Reports whether anything was cut, so "View full" only appears when needed.
private struct ClampedThought: View {
    var text: String
    var color: Color
    var size: CGFloat
    var lines: Int
    @Binding var clamped: Bool

    @State private var shown: CGFloat = 0
    @State private var whole: CGFloat = 0

    var body: some View {
        ThoughtText(text: text, color: color, size: size)
            .lineLimit(lines)
            .truncationMode(.tail)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { shown = $0; update() }
            .background(alignment: .top) {
                ThoughtText(text: text, color: color, size: size)
                    .hidden()
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { whole = $0; update() }
            }
    }

    private func update() {
        clamped = whole > shown + 1
    }
}

/// Both thoughts in full. Read-only and selectable.
private struct FullThoughtsSheet: View {
    var before: String
    var after: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                QuietButton(title: "Done") { dismiss() }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow(text: DemoCopy.beforeLabel)
                        ThoughtText(text: before, color: Theme.mute, size: CardThought.quietSize)
                            .textSelection(.enabled)
                    }
                    Rectangle()
                        .fill(Theme.rim)
                        .frame(height: 1)
                        .padding(.vertical, 22)
                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow(text: DemoCopy.afterLabel)
                        ThoughtText(text: after, color: Theme.ink, size: CardThought.size)
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 20)
        .background(Theme.canvas)
        .environment(\.colorScheme, .light)
        .presentationDetents([.medium, .large])
    }
}
