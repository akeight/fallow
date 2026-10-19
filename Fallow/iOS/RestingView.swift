import SwiftUI

/// The Fallow state. Nothing to do here, which is the point: close the app.
/// Title and the quiet line sit on either side of the orb, balanced on the thirds.
struct RestingView: View {
    var store: PhoneStore

    /// Where the title's top edge sits. Releasing shares it so the words land in the same place.
    static func titleTop(height: CGFloat) -> CGFloat {
        48 + height * 0.2
    }

    var body: some View {
        let session = store.session
        GeometryReader { geo in
                ZStack(alignment: .top) {
                HStack {
                    CornerButton(systemName: "chevron.down", label: "Close", color: Theme.muteOnScene) {
                        store.closeRest()
                    }
                    Spacer()
                }
                .padding(.top, 4)

                VStack(spacing: 12) {
                    Text(DemoCopy.itsHere)
                        .font(FallowType.display(34))
                        .foregroundStyle(Theme.ink)
                    Eyebrow(
                        text: FallowBehaviorResolver.reassurance(difficultyDisengaging: store.difficultyDisengaging) ?? DemoCopy.letItBe,
                        color: Theme.muteOnScene
                    )
                    .frame(maxWidth: 220)
                }
                .restHaze()
                .padding(.top, Self.titleTop(height: geo.size.height))

                // Silence is a valid intervention: then nothing is said here.
                if let line = session?.intervention?.line {
                    Text(line)
                        .font(.system(size: 17, weight: .regular))
                        .tracking(0.3)
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .frame(maxWidth: 290)
                        .restHaze()
                        .position(x: geo.size.width / 2 - 28, y: geo.size.height * 0.72)
                }
            }
            .padding(.horizontal, 28)
        }
    }
}
