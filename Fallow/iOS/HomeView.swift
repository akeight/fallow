import SwiftUI

/// What is resting right now. Almost empty on purpose.
struct HomeView: View {
    var store: PhoneStore

    var body: some View {
        VStack(spacing: 0) {
            FallowWordmark(size: 24)
                .padding(.top, 18)
                .contentShape(Rectangle())
                .onLongPressGesture(minimumDuration: 0.8) { store.cycleDemo() }
                .accessibilityAction(named: "Next demo state") { store.cycleDemo() }

            if let session = store.active {
                active(session)
                    .transition(.fallowText)
            } else {
                empty
                    .transition(.fallowText)
            }
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func active(_ session: FallowSession) -> some View {
        VStack(spacing: 0) {
            Text("\(session.projectName) is resting.")
                .font(FallowType.display(30))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .padding(.top, 44)

            Eyebrow(text: "You left with")
                .padding(.top, 26)

            ThoughtText(text: session.unresolvedThought, alignment: .center)
                .padding(.top, 10)
                .padding(.horizontal, 8)

            Text(session.distance.title)
                .font(FallowType.caption)
                .foregroundStyle(Theme.ash)
                .padding(.top, 12)

            Spacer(minLength: 150)

            VStack(spacing: 6) {
                if store.showsNudge {
                    Text(DemoCopy.hadSpace)
                        .font(FallowType.secondary)
                        .foregroundStyle(Theme.mute)
                        .padding(.bottom, 10)
                        .transition(.fallowText)
                }
                PrimaryButton(title: DemoCopy.returnToIt) { store.returnToIt() }
                QuietButton(title: DemoCopy.leaveLonger) { store.leaveLonger() }
            }
            .padding(.bottom, 92)
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
                    .foregroundStyle(Theme.mute)
            }
            .multilineTextAlignment(.center)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 150)
        }
        .frame(maxHeight: .infinity)
    }
}
