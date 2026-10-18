import SwiftUI

/// The one live orb. It stays mounted across every screen so its motion carries the thread.
struct PhoneOrb: View {
    var store: PhoneStore

    @State private var pressed = false

    var body: some View {
        ZStack {
            OrbView(session: store.orb, config: store.orbConfig)
                .allowsHitTesting(false)
                .scaleEffect(pressed && !holding ? 0.97 : 1)
                .brightness(pressed && !holding ? 0.03 : 0)
                .animation(.easeOut(duration: 0.25), value: pressed)

            Circle()
                .fill(Color.white.opacity(0.001))
                .frame(width: 190, height: 190)
                .contentShape(Circle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            guard !pressed else { return }
                            pressed = true
                            store.orbDown()
                        }
                        .onEnded { value in
                            pressed = false
                            let moved = hypot(value.translation.width, value.translation.height) > 24
                            store.orbUp(moved: moved)
                        }
                )
        }
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            if isRelease {
                store.releaseWithoutHold()
            } else {
                store.tapOrb()
            }
        }
    }

    private var isRelease: Bool {
        store.tab == .pause && store.step == .release
    }

    private var holding: Bool {
        if case .holding = store.orb.phase { return true }
        return false
    }

    private var label: String {
        switch (store.tab, store.step) {
        case (.pause, .release): "Let it rest"
        case (.pause, .capture): store.isRecording ? "Stop listening" : "Speak your thought"
        case (.pause, .resting): "Return to it"
        default: "FALLOW"
        }
    }
}
