import SwiftUI

struct RestingView: View {
    var session: FallowSession
    var onSpacePassed: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FallowWordmark(size: 32)
                .padding(.top, 28)

            Text("\(session.projectName) is resting.")
                .font(FallowType.screenTitle)
                .foregroundStyle(Theme.ink)
                .padding(.top, 124)

            Text("You left with")
                .font(FallowType.caption)
                .foregroundStyle(Theme.mute)
                .padding(.top, 32)

            Text(session.unresolvedThought)
                .font(FallowType.process)
                .foregroundStyle(Theme.ink)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)

            Text(session.distance.title)
                .font(FallowType.caption)
                .foregroundStyle(Theme.ash)
                .padding(.top, 20)

            QuietOrb()
                .frame(maxWidth: .infinity)

            Spacer(minLength: 16)

            Button("Some time has passed", action: onSpacePassed)
                .buttonStyle(.plain)
                .font(FallowType.quietButton)
                .foregroundStyle(Theme.mute)
                .frame(minHeight: 44, alignment: .leading)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.canvas)
    }
}

#Preview("Resting") {
    RestingView(session: .demo, onSpacePassed: {})
}
