import SwiftUI

struct RootView: View {
    @State private var store = PhoneStore()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Atmosphere(
                openness: store.openness,
                restScene: store.restScene,
                drifting: store.tab == .pause && store.step == .resting
            )
            .ignoresSafeArea()

            GeometryReader { geo in
                let placement = store.orbPlacement
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
                        .position(x: geo.size.width / 2, y: geo.size.height * placement.y)
                        .opacity(placement.visible ? 1 : 0)
                        .allowsHitTesting(placement.visible)
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
            }
            .ignoresSafeArea(.keyboard)

            content

            if store.showsTabBar {
                VStack {
                    Spacer()
                    FallowTabBar(tab: store.tab) { store.select($0) }
                        .opacity(store.tabBarEmphasis)
                        .padding(.bottom, 6)
                }
                .ignoresSafeArea(.keyboard)
                .transition(.opacity.combined(with: .offset(y: 16)))
            }
        }
        .onAppear {
            store.reduceMotion = reduceMotion
            #if DEBUG
            if let name = UserDefaults.standard.string(forKey: "fallowScreen") {
                store.open(debugScreen: name)
            }
            #endif
        }
        .onChange(of: reduceMotion) { _, value in store.reduceMotion = value }
        .onChange(of: store.orb.settleID) { _, _ in store.holdCompleted() }
        .onChange(of: store.holdProgress >= 0.85) { _, near in
            if near { store.holdNearTick += 1 }
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.5), trigger: store.holdStartTick)
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.7), trigger: store.holdNearTick)
        .sensoryFeedback(.success, trigger: store.releasedTick)
        .sensoryFeedback(.selection, trigger: store.selectionTick)
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
