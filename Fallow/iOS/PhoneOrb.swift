import SwiftUI

/// The one live orb. It stays mounted across every screen so its motion carries the thread.
struct PhoneOrb: View {
    var store: PhoneStore

    @State private var pressed = false

    var body: some View {
        ZStack {
            OrbView(session: store.orb, config: store.orbConfig)
                .allowsHitTesting(false)
                .scaleEffect(pressed && !holding && !isReturn ? 0.97 : 1)
                .brightness(pressed && !holding && !isReturn ? 0.03 : 0)
                .animation(.easeOut(duration: 0.25), value: pressed)
                // Holding to return gathers the orb a little before its light takes over.
                .scaleEffect(1 + 0.12 * store.returnHold)
                .brightness(0.08 * store.returnHold)

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
            } else if isReturn {
                store.completeReturnHold()
            } else {
                store.tapOrb()
            }
        }
    }

    private var isRelease: Bool {
        store.tab == .pause && store.step == .release
    }

    private var isReturn: Bool {
        store.tab == .pause && store.step == .beforeAfter
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
        case (.pause, .beforeAfter): "Return"
        default: "FALLOW"
        }
    }
}
