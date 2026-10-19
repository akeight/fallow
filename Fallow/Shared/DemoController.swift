#if DEBUG
import Foundation

/// Puts this device's active session into a step of the presentation, as if it had synced
/// from the other device. The stores apply it through their normal transitions.
@MainActor
final class DemoController {
    enum Scenario: String, CaseIterable, Identifiable {
        case reset
        case macReleased
        case phoneResting
        case phoneReturnRequested
        case macReturning
        case complete

        var id: String { rawValue }

        var title: String {
            switch self {
            case .reset: "Reset"
            case .macReleased: "Mac Released"
            case .phoneResting: "Phone Resting"
            case .phoneReturnRequested: "Phone Requests Return"
            case .macReturning: "Mac Return"
            case .complete: "Complete"
            }
        }

        var phoneTitle: String {
            switch self {
            case .reset: "No Active Session"
            case .macReleased, .phoneResting: "Mac Released / Resting"
            case .phoneReturnRequested, .macReturning: "Return Requested"
            case .complete: "Complete"
            }
        }

        static let mac: [Scenario] = [.reset, .macReleased, .macReturning, .complete]
        static let phone: [Scenario] = [.reset, .phoneResting, .phoneReturnRequested, .complete]
    }

    private let sync: DemoFallowSyncService

    init(sync: DemoFallowSyncService) {
        self.sync = sync
    }

    func run(_ scenario: Scenario) {
        switch scenario {
        case .reset: resetDemo()
        case .macReleased: setMacReleased()
        case .phoneResting: setPhoneResting()
        case .phoneReturnRequested: setPhoneReturnRequested()
        case .macReturning: setMacReturning()
        case .complete: setComplete()
        }
    }

    /// `-fallowDemo phoneResting`, for example. Unknown names are ignored.
    func applyLaunchArgument() {
        guard let name = UserDefaults.standard.string(forKey: "fallowDemo"),
              let scenario = Scenario(rawValue: name) else { return }
        run(scenario)
    }

    func resetDemo() {
        sync.stage(nil)
    }

    func setMacReleased() {
        sync.stage(DemoSessionFactory.macRestingDemo)
    }

    func setPhoneResting() {
        sync.stage(DemoSessionFactory.macRestingDemo)
    }

    func setPhoneReturnRequested() {
        sync.stage(returnRequested)
    }

    func setMacReturning() {
        sync.stage(returnRequested)
    }

    func setComplete() {
        var session = sync.activeSession ?? returnRequested
        session.complete()
        sync.stage(session)
    }

    private var returnRequested: FallowSession {
        var session = DemoSessionFactory.macRestingDemo
        session.requestReturn()
        return session
    }
}
#endif
