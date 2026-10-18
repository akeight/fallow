import SwiftUI

/// The Fallow state. Nothing to do here, which is the point: close the app.
/// Title and the quiet line sit on either side of the orb, balanced on the thirds.
struct RestingView: View {
    var store: PhoneStore

    var body: some View {
        let session = store.active
        GeometryReader { geo in
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    HStack {
                        CornerButton(systemName: "chevron.down", label: "Close", color: Theme.mute.opacity(0.7)) {
                            store.closeRest()
                        }
                        Spacer()
                    }
                    .padding(.top, 4)

                    VStack(spacing: 12) {
                        Text(DemoCopy.itsHere)
                            .font(FallowType.display(34))
                            .foregroundStyle(Theme.ink)
                        Eyebrow(text: DemoCopy.letItBe)
                            .frame(maxWidth: 200)
                    }
                    .padding(.top, geo.size.height * 0.14)

                    Spacer(minLength: 0)
                }

                VStack(spacing: 14) {
                    if let line = session?.creativeState.restLine {
                        Text(line)
                            .font(FallowType.secondary)
                            .foregroundStyle(Color.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .frame(maxWidth: 270)
                    }
                    HStack(spacing: 8) {
                        Text("Resting here")
                        Text("·").accessibilityHidden(true)
                        Text(store.restScene.title)
                    }
                    .font(FallowType.caption)
                    .foregroundStyle(Color.white.opacity(0.75))
                }
                .shadow(color: Color(hex: 0x2A1D12).opacity(0.45), radius: 8)
                .position(x: geo.size.width / 2 - 28, y: geo.size.height * 0.72)
            }
            .padding(.horizontal, 28)
        }
    }
}
