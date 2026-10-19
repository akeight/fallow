import SwiftUI

/// What is resting right now. Almost empty on purpose.
struct HomeView: View {
    var store: PhoneStore
    #if DEBUG
    @State private var showsDemo = false
    #endif

    var body: some View {
        ZStack(alignment: .top) {
            if let session = store.active {
                active(session)
                    .transition(.fallowText)
            } else {
                empty
                    .transition(.fallowText)
            }

            wordmark
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var wordmark: some View {
        let mark = FallowWordmark(size: 24)
            .padding(.top, 18)
        #if DEBUG
        mark
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 0.8) { showsDemo = true }
            .confirmationDialog("Demo", isPresented: $showsDemo) {
                ForEach(DemoController.Scenario.phone) { scenario in
                    Button(scenario.phoneTitle) { store.demo.run(scenario) }
                }
            }
        #else
        mark
        #endif
    }

    /// Where the orb sits while something rests, as a fraction of the content height. The thought hangs below it.
    static let activeOrbY = 0.44

    /// Title where the resting screen puts it, then the orb, then the thought beneath it.
    private func active(_ session: FallowSession) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                Text(session.restingLine)
                    .font(FallowType.display(30))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .padding(.top, RestingView.titleTop(height: geo.size.height))

                VStack(spacing: 0) {
                    VStack(spacing: 8) {
                        Eyebrow(text: "You left with", color: Theme.muteOnScene)
                        ThoughtText(text: session.unresolvedThought, alignment: .center)
                            .lineLimit(3)
                            .truncationMode(.tail)
                            .padding(.horizontal, 8)
                    }
                    .padding(.top, geo.size.height * Self.activeOrbY + 76)

                    Spacer(minLength: 18)

                    VStack(spacing: 6) {
                        // The rest's own guidance, wherever it was released. Silence says nothing.
                        if let line = session.intervention?.line {
                            Text(line)
                                .font(FallowType.secondary)
                                .tracking(0.3)
                                .foregroundStyle(Theme.ink)
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                                .frame(maxWidth: 290)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.bottom, 10)
                        }
                        if store.showsNudge {
                            Text(DemoCopy.hadSpace)
                                .font(FallowType.secondary)
                                .foregroundStyle(Theme.muteOnScene)
                                .padding(.bottom, 10)
                                .transition(.fallowText)
                        }
                        PrimaryButton(title: session.originDevice == .mac ? DemoCopy.readyToReturn : DemoCopy.returnToIt) {
                            store.returnToIt()
                        }
                        QuietButton(title: DemoCopy.leaveLonger, color: Theme.muteOnScene) {
                            store.leaveLonger()
                        }
                    }
                    .padding(.bottom, 92)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var empty: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(spacing: 12) {
                Text(DemoCopy.nothingResting)
                    .font(FallowType.display(28))
                    .foregroundStyle(Theme.ink)
                Text(DemoCopy.giveThought)
                    .font(FallowType.secondary)
                    .foregroundStyle(Theme.muteOnScene)
            }
            .multilineTextAlignment(.center)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 240)
        }
        .frame(maxHeight: .infinity)
    }
}
