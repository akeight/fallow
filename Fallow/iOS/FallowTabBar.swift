import SwiftUI

/// Home, Pause, Past. Three places, kept quiet. The orb rests on whichever one is open.
struct FallowTabBar: View {
    var tab: PhoneTab
    /// Over the deepened garden the glass goes dark and the type goes light.
    var deep = false
    var select: (PhoneTab) -> Void

    @Namespace private var marker
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let tabs: [PhoneTab] = [.home, .pause, .past]
    private static let iconSize: CGFloat = 30

    var body: some View {
        HStack(spacing: 0) {
            item(.home, title: "Home", symbol: "house")
            item(.pause, title: "Pause", symbol: "leaf")
            item(.past, title: "Past", symbol: "clock.arrow.circlepath")
        }
        .overlay(alignment: .topLeading) {
            GeometryReader { geo in
                let slot = geo.size.width / CGFloat(Self.tabs.count)
                let index = CGFloat(Self.tabs.firstIndex(of: tab) ?? 0)
                MiniOrb(diameter: Self.iconSize, glow: 1)
                    .position(x: slot * (index + 0.5), y: Self.iconSize / 2)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .padding(.horizontal, 10)
        .frame(height: 62)
        .barSurface()
        .environment(\.colorScheme, deep ? .dark : .light)
        .padding(.horizontal, 44)
        .animation(reduceMotion ? .easeInOut(duration: 0.25) : .spring(duration: 0.85, bounce: 0), value: tab)
    }

    private func item(_ item: PhoneTab, title: String, symbol: String) -> some View {
        let isActive = tab == item
        return Button { select(item) } label: {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .regular))
                    .frame(width: Self.iconSize, height: Self.iconSize)
                    .opacity(isActive ? 0 : 1)
                    .scaleEffect(isActive ? 0.8 : 1)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                ZStack {
                    if isActive {
                        Capsule()
                            .fill((deep ? Theme.inkOnDeep : Theme.ink).opacity(0.55))
                            .frame(width: 14, height: 2)
                            .matchedGeometryEffect(id: "marker", in: marker)
                    }
                }
                .frame(height: 2)
            }
            .foregroundStyle(deep ? (isActive ? Theme.inkOnDeep : Theme.muteOnDeep) : (isActive ? Theme.ink : Theme.muteOnScene))
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(title)
        .accessibilityHint(item == .pause ? "Give a thought somewhere to rest" : "")
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

private extension View {
    /// System Liquid Glass where available; the frosted surface elsewhere.
    @ViewBuilder
    func barSurface() -> some View {
        if #available(iOS 26, *) {
            glassEffect(.regular, in: Capsule())
        } else {
            glass(radius: 31)
        }
    }
}
