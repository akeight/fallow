import SwiftUI

/// Home, Pause, Past. Three places, kept quiet. The center is the orb itself.
struct FallowTabBar: View {
    var tab: PhoneTab
    var select: (PhoneTab) -> Void

    @Namespace private var marker

    var body: some View {
        HStack(spacing: 0) {
            side(.home, title: "Home", symbol: "circle.dotted")
            pause
            side(.past, title: "Past", symbol: "text.alignleft")
        }
        .padding(.horizontal, 10)
        .frame(height: 62)
        .glass(radius: 31)
        .padding(.horizontal, 44)
        .animation(.smooth(duration: 0.45), value: tab)
    }

    private func side(_ item: PhoneTab, title: String, symbol: String) -> some View {
        let isActive = tab == item
        return Button { select(item) } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .regular))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                ZStack {
                    if isActive {
                        Capsule()
                            .fill(Theme.ink.opacity(0.55))
                            .frame(width: 14, height: 2)
                            .matchedGeometryEffect(id: "marker", in: marker)
                    }
                }
                .frame(height: 2)
            }
            .foregroundStyle(isActive ? Theme.ink : Theme.ash)
            .frame(maxWidth: .infinity, minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private var pause: some View {
        let isActive = tab == .pause
        return Button { select(.pause) } label: {
            VStack(spacing: 3) {
                MiniOrb(diameter: 34, glow: isActive ? 1 : 0.45)
                    .scaleEffect(isActive ? 1.06 : 1)
                Text("Pause")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isActive ? Theme.ink : Theme.ash)
            }
            .offset(y: -6)
            .frame(maxWidth: .infinity, minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Pause")
        .accessibilityHint("Give a thought somewhere to rest")
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}
