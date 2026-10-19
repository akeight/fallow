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

/// A light, cheap orb for the tab bar and the archive. The live orb stays unique.
struct MiniOrb: View {
    var diameter: CGFloat = 30
    /// 0 is dormant, 1 is gathered.
    var glow: Double = 0.5

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            OrbPalette.glassCore.color,
                            OrbPalette.peach.mix(OrbPalette.glassCore, 0.55).color,
                            OrbPalette.glassBody.color,
                            OrbPalette.glassEdge.color
                        ],
                        center: UnitPoint(x: 0.48, y: 0.56),
                        startRadius: 0,
                        endRadius: diameter * 0.62
                    )
                )
            Circle()
                .fill(OrbPalette.ember.color)
                .frame(width: diameter * (0.32 + 0.14 * glow), height: diameter * (0.26 + 0.1 * glow))
                .blur(radius: diameter * 0.12)
                .offset(y: diameter * 0.08)
                .opacity(0.55 + 0.4 * glow)
            Ellipse()
                .fill(Color.white.opacity(0.7))
                .frame(width: diameter * 0.3, height: diameter * 0.14)
                .blur(radius: diameter * 0.03)
                .offset(x: -diameter * 0.17, y: -diameter * 0.22)
            Circle()
                .strokeBorder(Color.white.opacity(0.55), lineWidth: max(0.6, diameter * 0.025))
        }
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
