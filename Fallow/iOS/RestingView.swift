import SwiftUI

/// The Fallow state. Nothing to do here, which is the point: close the app.
struct RestingView: View {
    var store: PhoneStore

    var body: some View {
        let session = store.active
        VStack(spacing: 0) {
            HStack {
                CornerButton(systemName: "chevron.down", label: "Close", color: Theme.mute.opacity(0.7)) {
                    store.closeRest()
                }
                Spacer()
            }
            .padding(.top, 4)

            Text(DemoCopy.itsHere)
                .font(FallowType.display(34))
                .foregroundStyle(Theme.ink)
                .padding(.top, 34)

            Eyebrow(text: DemoCopy.letItBe)
                .padding(.top, 12)
                .frame(maxWidth: 200)

            Spacer(minLength: 0)

            VStack(spacing: 14) {
                if let line = session?.creativeState.restLine {
                    Text(line)
                        .font(FallowType.secondary)
                        .foregroundStyle(Color.white.opacity(0.88))
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
                .foregroundStyle(Color.white.opacity(0.72))
            }
            .shadow(color: Color(hex: 0x2A1D12).opacity(0.35), radius: 8)
            .padding(.bottom, 40)
        }
        .padding(.horizontal, 28)
    }
}
