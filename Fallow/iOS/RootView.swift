import SwiftUI

enum CompanionPage: Equatable {
    case resting
    case nudge
    case handoff
}

struct RootView: View {
    @State private var page = CompanionPage.resting
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let session = FallowSession.demo

    var body: some View {
        ZStack {
            switch page {
            case .resting:
                RestingView(session: session) {
                    page = .nudge
                }
                .transition(.opacity)
            case .nudge:
                NudgeView(
                    onReturn: { page = .handoff },
                    onNotYet: { page = .resting },
                    onLater: { page = .resting }
                )
                .transition(.opacity)
            case .handoff:
                ReturnHandoffView(session: session)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.6), value: page)
    }
}

#Preview("Companion") {
    RootView()
}
