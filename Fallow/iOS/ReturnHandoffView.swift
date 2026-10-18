import SwiftUI

struct ReturnHandoffView: View {
    var session: FallowSession

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FallowWordmark(size: 32)
                .padding(.top, 28)

            Text("Head back when you’re ready.")
                .font(FallowType.screenTitle)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 124)

            Text("\(session.projectName) is waiting on your Mac.")
                .font(FallowType.body)
                .foregroundStyle(Theme.mute)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 20)

            Text("Your thought will be there.")
                .font(FallowType.body)
                .foregroundStyle(Theme.ink)
                .padding(.top, 12)

            QuietOrb(awake: true)
                .frame(maxWidth: .infinity)
                .padding(.top, 68)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.canvas)
    }
}

#Preview("Return") {
    ReturnHandoffView(session: .demo)
}
