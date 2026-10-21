import SwiftUI

struct RootView: View {
    @State private var store = PhoneStore()
    @State private var showsSplash = Self.launchesWithSplash
    /// Home waits under the splash until its light covers the screen.
    @State private var homeHidden = Self.launchesWithSplash
    @State private var fullHeight: CGFloat = 0
    @State private var visibleHeight: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private static var launchesWithSplash: Bool {
        #if DEBUG
        let defaults = UserDefaults.standard
        return defaults.string(forKey: "fallowScreen") == nil && defaults.string(forKey: "fallowDemo") == nil
        #else
        return true
        #endif
    }

    var body: some View {
        ZStack {
            Atmosphere(
                openness: store.openness,
                restScene: store.restScene,
                drifting: store.tab == .pause && store.step == .resting,
                garden: store.gardenOpacity,
                gardenTop: store.gardenTop,
                depth: store.isDeep ? 1 : 0,
                vignette: store.tab == .home || store.isReturning ? 1 : 0
            )
            .ignoresSafeArea()

            GeometryReader { geo in
                let placement = store.orbPlacement
                let height = geo.size.height - store.keyboardInset
                ZStack {
                    if store.leafMode != .off {
                        LeafLayerView(
                            emitter: store.leaves,
                            bands: [.back, .mid],
                            mode: store.leafMode,
                            intensity: store.leafIntensity,
                            drives: true
                        )
                    }

                    PhoneOrb(store: store)
                        .scaleEffect(placement.scale)
                        .position(x: geo.size.width / 2, y: height * placement.y)
                        .opacity(placement.visible ? 1 : 0)
                        .allowsHitTesting(placement.visible)
                        // Inner of the two, so a keyboard move keeps the keyboard's pace.
                        .animation(Self.keyboardAnimation, value: store.keyboardInset)
                        .animation(.smooth(duration: reduceMotion ? 0.3 : 1.1), value: placement)

                    if store.leafMode != .off {
                        LeafLayerView(
                            emitter: store.leaves,
                            bands: [.front],
                            mode: store.leafMode,
                            intensity: store.leafIntensity,
                            drives: false
                        )
                    }
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                    fullHeight = $0
                    updateKeyboardInset()
                }
            }
            .ignoresSafeArea(.keyboard)
            .opacity(homeHidden ? 0 : 1)

            content
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                    visibleHeight = $0
                    updateKeyboardInset()
                }
                .opacity(homeHidden ? 0 : 1)

            if store.showsTabBar {
                VStack {
                    Spacer()
                    FallowTabBar(tab: store.tab, deep: store.isDeep) { store.select($0) }
                        .padding(.bottom, 6)
                }
                .ignoresSafeArea(.keyboard)
                .transition(.opacity.combined(with: .offset(y: 16)))
                .opacity(homeHidden ? 0 : 1)
            }

            if store.isBloomingHome {
                ReturnBloom(store: store)
            }

            if showsSplash {
                LaunchSplash(
                    store: store,
                    onCovered: { homeHidden = false },
                    onFinished: {
                        showsSplash = false
                        store.splashFinished()
                    }
                )
            }
        }
        .preferredColorScheme(store.isDeep ? .dark : .light)
        .onAppear {
            store.reduceMotion = reduceMotion
            #if DEBUG
            if let name = UserDefaults.standard.string(forKey: "fallowScreen") {
                store.open(debugScreen: name)
            }
            store.demo.applyLaunchArgument()
            #endif
        }
        .onChange(of: reduceMotion) { _, value in store.reduceMotion = value }
        .onChange(of: scenePhase) { _, phase in
            // Deferred so a launch-time active transition cannot update the store inside this frame.
            // Doing it here stalls the splash: the orb never expands across the screen.
            guard phase == .active else { return }
            Task { @MainActor in store.appBecameActive() }
        }
        .onChange(of: store.orb.settleID) { _, _ in store.holdCompleted() }
        .onChange(of: store.holdProgress >= 0.85) { _, near in
            if near { store.holdNearTick += 1 }
        }
        .onChange(of: store.returnHold >= 0.85) { _, near in
            if near { store.holdNearTick += 1 }
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.5), trigger: store.holdStartTick)
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.7), trigger: store.holdNearTick)
        .sensoryFeedback(.success, trigger: store.releasedTick)
        .sensoryFeedback(.selection, trigger: store.selectionTick)
    }

    private static let keyboardAnimation = Animation.smooth(duration: 0.4)

    /// The content shrinks above the keyboard while the orb layer does not; the difference is the keyboard.
    private func updateKeyboardInset() {
        guard fullHeight > 0, visibleHeight > 0 else { return }
        let covered = fullHeight - visibleHeight
        let inset = covered > 40 ? covered : 0
        guard inset != store.keyboardInset else { return }
        withAnimation(Self.keyboardAnimation) { store.keyboardInset = inset }
    }

    @ViewBuilder
    private var content: some View {
        ZStack {
            switch store.tab {
            case .home:
                HomeView(store: store)
                    .transition(.fallowText)
            case .past:
                PastView(store: store)
                    .transition(.fallowText)
            case .pause:
                PauseFlowView(store: store)
                    .transition(.fallowText)
            }
        }
    }
}

#Preview("FALLOW") {
    RootView()
}
