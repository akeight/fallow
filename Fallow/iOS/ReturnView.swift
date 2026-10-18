import SwiftUI

/// Attention reforming around the thought. The room gathers inward and the surfaces return.
struct ReturnView: View {
    @Bindable var store: PhoneStore

    var body: some View {
        ZStack {
            switch store.step {
            case .reflect:
                reflect.transition(.fallowText)
            case .beforeAfter:
                beforeAfter.transition(.fallowText)
            default:
                welcome.transition(.fallowText)
            }
        }
    }

    // MARK: Welcome back

    private var welcome: some View {
        let session = store.active ?? .demo
        return GeometryReader { geo in
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    HStack {
                        CornerButton(systemName: "chevron.left", label: "Back to Home") { store.cancelFlow() }
                        Spacer()
                    }
                    .padding(.top, 4)

                    Text(DemoCopy.welcomeBack)
                        .font(FallowType.display(34))
                        .foregroundStyle(Theme.ink)
                        .padding(.top, 10)

                    Spacer(minLength: 0)

                    ZStack {
                        if session.origin == .mac {
                            if !store.handedToMac {
                                PrimaryButton(title: DemoCopy.returnOnMac) { store.returnOnMac() }
                                    .transition(.fallowText)
                            }
                        } else {
                            PrimaryButton(title: "Continue") { store.beginReflection() }
                        }
                    }
                    .frame(minHeight: 52)
                    .padding(.bottom, 24)
                }

                // The prompt and the thought sit on the lower third, under the orb.
                VStack(spacing: 14) {
                    Text(welcomeLine(for: session))
                        .font(FallowType.secondary)
                        .foregroundStyle(Theme.mute)
                        .contentTransition(.opacity)

                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow(text: "You left with")
                        ThoughtText(text: session.unresolvedThought)
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
        guard session.origin == .mac else { return DemoCopy.different }
        return store.handedToMac
            ? "\(session.projectName) is open on your Mac."
            : "\(session.projectName) is waiting for you."
    }

    // MARK: Phone-originated reflection

    private var reflect: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                HStack {
                    CornerButton(systemName: "chevron.left", label: "Back") { store.back() }
                    Spacer()
                }
                .padding(.top, 4)

                Text(DemoCopy.different)
                    .font(FallowType.display(28))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .padding(.top, geo.size.height * 0.11)

                VStack(alignment: .leading, spacing: 12) {
                    ZStack(alignment: .topLeading) {
                        if store.reflection.isEmpty {
                            Text(store.isRecording ? "Listening…" : "Say it, or write it.")
                                .font(FallowType.process)
                                .foregroundStyle(Theme.ash)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $store.reflection)
                            .font(FallowType.process)
                            .foregroundStyle(Theme.ink)
                            .lineSpacing(5)
                            .scrollContentBackground(.hidden)
                    }
                    .frame(minHeight: 110, maxHeight: 160)

                    HStack {
                        Spacer()
                        Button {
                            store.isRecording ? store.stopRecording() : store.startRecording(forReflection: true)
                        } label: {
                            Image(systemName: store.isRecording ? "stop.fill" : "mic")
                                .font(.system(size: store.isRecording ? 12 : 16, weight: .medium))
                                .foregroundStyle(Haze.dawn)
                                .frame(width: 38, height: 38)
                                .background(Circle().fill(store.isRecording ? Haze.soot : Haze.bark))
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel(store.isRecording ? "Stop listening" : "Speak it")
                    }
                }
                .padding(14)
                .glass(radius: 20, lit: store.isRecording)
                .padding(.top, 20)

                Spacer(minLength: 16)

                PrimaryButton(title: "Continue") { store.confirmReflection() }
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, 28)
        }
    }

    // MARK: Before and after

    private var beforeAfter: some View {
        let session = store.active ?? .demoFromPhone
        return GeometryReader { geo in
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow(text: DemoCopy.beforeLabel)
                    ThoughtText(text: session.unresolvedThought, color: Theme.ash)
                }

                Rectangle()
                    .fill(Theme.rim)
                    .frame(height: 1)
                    .padding(.vertical, 26)

                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow(text: DemoCopy.afterLabel)
                    ThoughtText(text: store.reflection)
                }

                Spacer(minLength: 16)

                Text("Kept in Past, with the story of how it changed.")
                    .font(FallowType.caption)
                    .foregroundStyle(Theme.ash)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 10)

                PrimaryButton(title: "Done") { store.finishReturn() }
                    .padding(.bottom, 20)
            }
            .padding(.top, geo.size.height * 0.24)
            .padding(.horizontal, 32)
        }
    }
}
