import SwiftUI

/// A quiet archive of how unfinished thoughts changed while you were away.
struct PastView: View {
    var store: PhoneStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Past")
                    .font(FallowType.display(34))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 28)

                Text("How unfinished thoughts changed while you were away.")
                    .font(FallowType.secondary)
                    .foregroundStyle(Theme.muteOnScene)
                    .padding(.top, 8)

                if store.past.isEmpty {
                    Text("Nothing yet. What you leave and what you return with will gather here.")
                        .font(FallowType.secondary)
                        .foregroundStyle(Theme.muteOnScene)
                        .padding(.top, 48)
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(store.past) { session in
                            PastCard(session: session)
                        }
                    }
                    .padding(.top, 28)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
    }
}

private struct PastCard: View {
    var session: FallowSession

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                MiniOrb(diameter: 20, glow: session.latestThought == nil ? 0.3 : 0.7)
                Text(Self.day(session.lastTouched))
                    .font(FallowType.caption)
                    .foregroundStyle(Theme.mute)
                Text(session.projectName ?? "")
                    .font(FallowType.eyebrow)
                    .tracking(2)
                    .foregroundStyle(Theme.mute)
                Spacer(minLength: 0)
            }

            Text("You left with")
                .font(FallowType.caption)
                .foregroundStyle(Theme.mute)
                .padding(.top, 18)
            ThoughtText(text: session.unresolvedThought, color: Theme.mute)
                .padding(.top, 6)

            Rectangle()
                .fill(Theme.rim.opacity(0.7))
                .frame(width: 24, height: 1)
                .padding(.vertical, 16)

            if let returned = session.latestThought {
                Text(session.reframedThought == nil ? "You returned with" : "It became")
                    .font(FallowType.caption)
                    .foregroundStyle(Theme.mute)
                ThoughtText(text: returned)
                    .padding(.top, 6)
            } else {
                Text("You returned to it on your Mac.")
                    .font(FallowType.caption)
                    .foregroundStyle(Theme.mute)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.paper.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.rim.opacity(0.6), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private static func day(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.wide))
    }
}
