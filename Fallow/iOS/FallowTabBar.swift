import SwiftUI

/// Home, Pause, Reflections, and a Settings item for show. The orb rests on whichever one is open.
struct FallowTabBar: View {
    var tab: PhoneTab
    /// Over the deepened garden the glass goes dark and the type goes light.
    var deep = false
    var select: (PhoneTab) -> Void

    @Namespace private var marker
    /// Settings is for show: the orb rests on it, but nothing behind the bar changes.
    @State private var onSettings = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let tabs: [PhoneTab] = [.home, .pause, .past]
    private static let slotCount = tabs.count + 1
    private static let iconSize: CGFloat = 30

    var body: some View {
        HStack(spacing: 0) {
            item(.home, title: "Home", symbol: "house")
            item(.pause, title: "Pause", symbol: "leaf")
            item(.past, title: "Reflections", symbol: "clock.arrow.circlepath")
            button(title: "Settings", symbol: "gearshape", isActive: onSettings) { onSettings = true }
        }
        .overlay(alignment: .topLeading) {
            GeometryReader { geo in
                let slot = geo.size.width / CGFloat(Self.slotCount)
                let index = CGFloat(onSettings ? Self.tabs.count : Self.tabs.firstIndex(of: tab) ?? 0)
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
        .animation(reduceMotion ? .easeInOut(duration: 0.25) : .spring(duration: 0.85, bounce: 0), value: onSettings)
        .onChange(of: tab) { _, _ in onSettings = false }
    }

    private func item(_ item: PhoneTab, title: String, symbol: String) -> some View {
        button(title: title, symbol: symbol, isActive: !onSettings && tab == item) {
            onSettings = false
            select(item)
        }
        .accessibilityHint(item == .pause ? "Give a thought somewhere to rest" : "")
    }

    private func button(title: String, symbol: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
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
