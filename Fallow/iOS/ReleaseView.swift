import SwiftUI

/// Press and hold the orb to hand the thought over. Progress has no bar: the thought itself
/// becomes harder to read, the room opens, and letting go early simply eases everything back.
struct ReleaseView: View {
    var store: PhoneStore

    var body: some View {
        let hold = store.holdProgress
        let releasing = store.step == .releasing
        let chrome = releasing ? 0 : 1 - ramp(hold, 0.08, 0.55)

        GeometryReader { geo in
            ZStack {
                VStack(spacing: 0) {
                    HStack {
                        CornerButton(systemName: "chevron.left", label: "Back") { store.back() }
                        Spacer()
                    }
                    .padding(.top, 4)
                    .opacity(chrome)
                    .allowsHitTesting(chrome > 0.5)

                    Text(DemoCopy.takeBreath)
                        .font(FallowType.display(30))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .padding(.top, 6)
                        .opacity(chrome)
                        .blur(radius: 4 * (1 - chrome))

                    Spacer(minLength: 0)

                    if !releasing {
                        thought(hold: hold)
                            .padding(.bottom, 24)
                            .transition(.opacity)

                        Text(DemoCopy.hold)
                            .font(FallowType.eyebrow)
                            .tracking(2.4)
                            .textCase(.uppercase)
                            .foregroundStyle(Theme.mute)
                            .opacity(chrome)
                            .padding(.bottom, 34)
                    }
                }
                .padding(.horizontal, 28)

                if releasing {
                    releaseLine
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.2)
                }
            }
        }
    }

    /// 100% → 70% → 35% → nearly gone, softening and drifting back as it leaves attention.
    private func thought(hold: Double) -> some View {
        let fade = interpolate(hold, [(0, 1), (0.33, 0.7), (0.66, 0.35), (1, 0.03)])
        return ThoughtText(text: store.draft.isEmpty ? DemoCopy.phoneUnresolved : store.draft, alignment: .center)
            .opacity(fade)
            .blur(radius: 5 * ramp(hold, 0.2, 1))
            .scaleEffect(1 - 0.06 * hold)
            .offset(y: -18 * hold)
            .accessibilityLabel("Your thought: \(store.draft)")
    }

    private var releaseLine: some View {
        ZStack {
            switch store.releaseLine {
            case .releasing:
                Text(DemoCopy.releasing)
                    .font(FallowType.display(26))
                    .transition(.fallowText)
            case .restingNow:
                Text(DemoCopy.restingNow)
                    .font(FallowType.display(30))
                    .transition(.fallowText)
            }
        }
        .foregroundStyle(Theme.ink)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 36)
    }

    private func interpolate(_ value: Double, _ points: [(Double, Double)]) -> Double {
        guard let first = points.first, value > first.0 else { return points.first?.1 ?? 1 }
        for (a, b) in zip(points, points.dropFirst()) where value <= b.0 {
            let t = (value - a.0) / (b.0 - a.0)
            return a.1 + (b.1 - a.1) * t
        }
        return points.last?.1 ?? 0
    }
}
