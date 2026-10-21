import SwiftUI

/// A faint way out of a step. Kept small so it never competes with the thought.
struct CornerButton: View {
    var systemName: String
    var label: String
    var color: Color = Theme.ash
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(label)
    }
}

extension View {
    /// A feathered patch of light behind text on the open scene, so dark type keeps 4.5:1.
    func restHaze() -> some View {
        background {
            Capsule()
                .fill(Theme.canvas.opacity(0.45))
                .padding(.horizontal, -28)
                .padding(.vertical, -20)
                .blur(radius: 24)
        }
    }
}

/// The person's words inside a card, a step under the open-screen thought. Shared with Reflections.
enum CardThought {
    static let size: CGFloat = 15
    /// What was left behind, when it sits above what came back.
    static let quietSize: CGFloat = 13
    static let padding: CGFloat = 24
    static let radius: CGFloat = 24
}

/// A light, cheap orb for the tab bar's selected tab. The live orb stays unique.
struct MiniOrb: View {
    var diameter: CGFloat = 30
    /// 0 is dormant, 1 is gathered.
    var glow: Double = 0.5

    /// How much of the artwork's square the orb itself fills.
    private static let artworkFill: CGFloat = 0.76

    var body: some View {
        Image("FallowOrb")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: diameter / Self.artworkFill, height: diameter / Self.artworkFill)
            .frame(width: diameter, height: diameter)
        .background(
            Circle()
                .fill(OrbPalette.warm.color.opacity(0.25 + 0.35 * glow))
                .blur(radius: diameter * 0.35)
                .scaleEffect(1.2)
        )
        .accessibilityHidden(true)
    }
}
