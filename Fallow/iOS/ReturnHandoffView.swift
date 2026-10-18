import SwiftUI

struct ReturnHandoffView: View {
    var session: FallowSession

    var body: some View {
        VStack(spacing: 0) {
            FallowWordmark(size: 22)
                .padding(.top, 28)

            Text("Head back when you’re ready.")
                .font(FallowType.display(34))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 88)

            Eyebrow(text: "\(session.projectName) is waiting on your Mac")
                .padding(.top, 14)

            QuietOrb(awake: true)
                .padding(.top, 4)

            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "scribble.variable")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.mute)
                    .padding(.top, 2)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 8) {
                    Text("“\(session.unresolvedThought)”")
                        .font(FallowType.process)
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Your thought will be there.")
                        .font(FallowType.caption)
                        .foregroundStyle(Theme.ash)
                }
                Spacer(minLength: 0)
            }
            .padding(18)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Theme.paper.opacity(0.55))
                    )
            }
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
            )
            .shadow(color: Color(hex: 0x5C4A32).opacity(0.1), radius: 14, y: 6)
            .padding(.top, -28)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.canvas)
    }
}

#Preview("Return") {
    ReturnHandoffView(session: .demo)
}
