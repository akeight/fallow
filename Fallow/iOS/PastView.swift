import SwiftUI

/// A quiet archive of how unfinished thoughts changed while you were away.
struct PastView: View {
    var store: PhoneStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Reflections")
                    .font(FallowType.display(37))
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
                    LazyVStack(spacing: 20) {
                        ForEach(Array(store.past.enumerated()), id: \.element.id) { index, session in
                            ReflectionCard(session: session, order: index)
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

/// The orb's rim, cool where the glass meets the sky and warm where the light pools.
/// Here it runs from the thought that was left to the one that came back.
private enum Strand {
    /// Deepened from the orb's sky, peach, and gold so they hold against light glass.
    static let cool = Color(hex: 0x9EA5D6)
    static let mid = Color(hex: 0xE9AE8C)
    static let warm = Color(hex: 0xD49A55)
    static let glow = OrbPalette.ember.color
    static let width: CGFloat = 2.5
    static let knot: CGFloat = 9
    /// Leaves room for the thread beside the words.
    static let inset: CGFloat = 24
}

private enum ReflectionType {
    static let label = Font.system(size: 12, weight: .regular)
}

private struct ReflectionCard: View {
    var session: FallowSession
    /// Position in the list, so the cards arrive one after another.
    var order: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var arrived = false
    @State private var traced = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: header)
                .padding(.bottom, 16)

            left
            returned
        }
        .padding(CardThought.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glass(radius: CardThought.radius)
        .opacity(arrived ? 1 : 0)
        .offset(y: arrived || reduceMotion ? 0 : 14)
        .blur(radius: arrived || reduceMotion ? 0 : 6)
        .accessibilityElement(children: .combine)
        .onAppear(perform: arrive)
    }

    private var header: String {
        [Self.day(session.lastTouched), session.distance.map(Self.away)]
            .compactMap { $0 }
            .joined(separator: "  ·  ")
    }

    private var left: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("You left with")
                .font(ReflectionType.label)
                .foregroundStyle(Theme.mute)
            ThoughtText(text: session.unresolvedThought, color: Theme.mute, size: CardThought.quietSize)
        }
        .padding(.leading, Strand.inset)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .topLeading) {
            VStack(spacing: 0) {
                Circle()
                    .strokeBorder(Strand.cool, lineWidth: 2)
                    .frame(width: Strand.knot, height: Strand.knot)
                    .padding(.top, 3)
                Capsule()
                    .fill(LinearGradient(colors: [Strand.cool, Strand.mid], startPoint: .top, endPoint: .bottom))
                    .frame(width: Strand.width)
                    .frame(maxHeight: .infinity)
                    .scaleEffect(y: traced ? 1 : 0, anchor: .top)
            }
            .frame(width: Strand.knot)
        }
    }

    @ViewBuilder
    private var returned: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let thought = session.latestThought {
                Text(session.reframedThought == nil ? "You returned with" : "It became")
                    .font(ReflectionType.label)
                    .foregroundStyle(Theme.mute)
                ThoughtText(text: thought, size: CardThought.size)
            } else {
                Text("You returned to it on your Mac.")
                    .font(ReflectionType.label)
                    .foregroundStyle(Theme.mute)
            }
        }
        .padding(.leading, Strand.inset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .topLeading) {
            VStack(spacing: 0) {
                Capsule()
                    .fill(LinearGradient(colors: [Strand.mid, Strand.warm], startPoint: .top, endPoint: .bottom))
                    .frame(width: Strand.width, height: 3)
                    .scaleEffect(y: traced ? 1 : 0, anchor: .top)
                Circle()
                    .fill(Strand.warm)
                    .frame(width: Strand.knot, height: Strand.knot)
                    .background(
                        Circle()
                            .fill(Strand.glow)
                            .blur(radius: 5)
                            .scaleEffect(2.2)
                            .opacity(traced ? 0.9 : 0)
                    )
                    .scaleEffect(traced ? 1 : 0.4)
                    .opacity(traced ? 1 : 0.3)
            }
            .frame(width: Strand.knot)
        }
    }

    /// The card settles in, then the thread runs down from what was left to what came back.
    private func arrive() {
        guard !arrived else { return }
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.3)) { arrived = true }
            traced = true
            return
        }
        let delay = Double(min(order, 5)) * 0.09
        withAnimation(.easeOut(duration: 0.55).delay(delay)) { arrived = true }
        withAnimation(.timingCurve(0.45, 0, 0.25, 1, duration: 0.9).delay(delay + 0.25)) { traced = true }
    }

    private static func day(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.wide))
    }

    /// How long it rested, said looking back.
    private static func away(_ distance: FallowDistance) -> String {
        switch distance {
        case .breath: "A breath"
        case .someDistance: "Some distance"
        case .sleepOnIt: "Slept on it"
        case .openEnded: "Open-ended"
        }
    }
}
