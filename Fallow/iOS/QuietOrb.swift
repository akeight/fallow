import SwiftUI

/// A tether to the Mac orb. Resting by default; `awake` rises into the return pose.
struct QuietOrb: View {
    var awake = false
    @State private var model = QuietOrbModel()

    var body: some View {
        OrbView(session: model.session, config: model.config)
            .frame(width: 300, height: 260)
            .clipped()
            .accessibilityHidden(true)
            .task {
                guard awake else { return }
                try? await Task.sleep(nanoseconds: 450_000_000)
                model.session.phase = .returnDoorway
            }
    }
}

@MainActor
private final class QuietOrbModel {
    let session = SessionModel()
    let config = OrbTuningConfig()

    init() {
        session.phase = .resting
        session.softness = 1
        config.applyQuietCompanion()
    }
}
