import SwiftUI

struct NudgeView: View {
    var onReturn: () -> Void
    var onNotYet: () -> Void
    var onLater: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)

            Text("Your idea has had some space.")
                .font(FallowType.screenTitle)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Button("Return to it", action: onReturn)
                .buttonStyle(.plain)
                .font(FallowType.button)
                .foregroundStyle(Theme.ink)
                .frame(minHeight: 44, alignment: .leading)
                .padding(.top, 32)

            Button("Not yet", action: onNotYet)
                .buttonStyle(.plain)
                .font(FallowType.quietButton)
                .foregroundStyle(Theme.mute)
                .frame(minHeight: 44, alignment: .leading)

            Button("Later today", action: onLater)
                .buttonStyle(.plain)
                .font(FallowType.quietButton)
                .foregroundStyle(Theme.mute)
                .frame(minHeight: 44, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Theme.canvas)
    }
}

#Preview("Nudge") {
    NudgeView(onReturn: {}, onNotYet: {}, onLater: {})
}
