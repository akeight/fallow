import SwiftUI

/// What is resting right now. Almost empty on purpose.
struct HomeView: View {
    var store: PhoneStore
    #if DEBUG
    @State private var showsDemo = false
    #endif

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                if let session = store.active {
                    active(session)
                        .transition(.fallowText)
                } else {
                    empty
                        .transition(.fallowText)
                }

                wordmark
                    .position(x: geo.size.width / 2, y: Self.wordmarkCenter(geo.size.height))
            }
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// The open sky above the orb, where the wordmark sits.
    private static func wordmarkCenter(_ height: CGFloat) -> CGFloat {
        height * 0.22
    }

    @ViewBuilder
    private var wordmark: some View {
        let mark = FallowWordmark(size: 32)
        #if DEBUG
        mark
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 0.8) { showsDemo = true }
            .confirmationDialog("Demo", isPresented: $showsDemo) {
                Button("Prepare Demo Rest") { store.demo.prepareDemoRest() }
                Button("No Active Session") { store.demo.run(.reset) }
                Button(DemoController.Scenario.phoneResting.title) { store.demo.run(.phoneResting) }
                Button("Trigger Rest Notification") { store.demo.triggerRestNotification() }
                Button(DemoController.Scenario.phoneReturnRequested.title) { store.demo.run(.phoneReturnRequested) }
                Button("Gentle Nudge") { store.demo.triggerGentleNudge() }
                Button("Notification Permission") { store.demo.requestNotificationPermission() }
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
                    .font(FallowType.display(33))
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
                    .font(FallowType.display(31))
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
