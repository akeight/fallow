import SwiftUI

/// The action color: a muted petal mauve from the dusk haze and the orb's cool shadow.
/// Distinct from the ink, and cooler than the warm surfaces around it.
enum Petal {
    static let fill = Color(hex: 0xCDBAC5)
    static let soft = Color(hex: 0xEADFE5)
    static let deep = Color(hex: 0x9C8292)
}

/// A small give under the finger. Nothing bounces.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(.easeOut(duration: 0.18), value: configuration.isPressed)
    }
}

struct PrimaryButton: View {
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(FallowType.button)
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Capsule().fill(Petal.fill))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.45), lineWidth: 1))
                .shadow(color: Petal.deep.opacity(0.25), radius: 12, y: 5)
                .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
    }
}

struct QuietButton: View {
    var title: String
    var color: Color = Theme.mute
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(FallowType.quietButton)
                .foregroundStyle(color)
                .frame(minWidth: 44, minHeight: 44)
                .padding(.horizontal, 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }
}

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

/// Softened attention: frosted, warm, with a hairline. Used before and after Fallow only.
struct GlassSurface: ViewModifier {
    var radius: CGFloat = 20
    var lit = false

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background {
                shape
                    .fill(.ultraThinMaterial)
                    .overlay(shape.fill((lit ? Petal.soft : Theme.paper).opacity(lit ? 0.85 : 0.5)))
            }
            .overlay(shape.strokeBorder(Color.white.opacity(lit ? 0.9 : 0.6), lineWidth: 1))
            .shadow(color: (lit ? Petal.deep : Color(hex: 0x5C4A32)).opacity(lit ? 0.16 : 0.07), radius: lit ? 16 : 10, y: 5)
    }
}

extension View {
    func glass(radius: CGFloat = 20, lit: Bool = false) -> some View {
        modifier(GlassSurface(radius: radius, lit: lit))
    }
}

private struct BlurAmount: ViewModifier {
    var radius: CGFloat

    func body(content: Content) -> some View {
        content.blur(radius: radius)
    }
}

extension AnyTransition {
    /// Text arrives from slightly below and out of focus, and leaves upward into softness.
    static var fallowText: AnyTransition {
        .asymmetric(
            insertion: .opacity
                .combined(with: .offset(y: 10))
                .combined(with: .modifier(active: BlurAmount(radius: 6), identity: BlurAmount(radius: 0))),
            removal: .opacity
                .combined(with: .offset(y: -6))
                .combined(with: .modifier(active: BlurAmount(radius: 8), identity: BlurAmount(radius: 0)))
        )
    }
}

/// The unresolved thought, set in mono so it reads as the person's own words.
struct ThoughtText: View {
    var text: String
    var color: Color = Theme.ink
    var alignment: TextAlignment = .leading

    var body: some View {
        Text("“\(text)”")
            .font(FallowType.process)
            .foregroundStyle(color)
            .lineSpacing(5)
            .multilineTextAlignment(alignment)
            .fixedSize(horizontal: false, vertical: true)
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
