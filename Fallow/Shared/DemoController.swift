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
    #if os(iOS)
    private let notifications: FallowNotificationService?

    init(sync: DemoFallowSyncService, notifications: FallowNotificationService? = nil) {
        self.sync = sync
        self.notifications = notifications
    }
    #else
    init(sync: DemoFallowSyncService) {
        self.sync = sync
    }
    #endif

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

    #if os(iOS)
    /// "Your thought is resting now." for the demo session, after `Timing.restDelay`. Lock the phone to see it land.
    func triggerRestNotification() {
        notify(.restStarted, after: FallowNotificationService.Timing.restDelay)
    }

    /// "Your idea has had some space." for the demo session, after `Timing.nudgeDelay`.
    func triggerGentleNudge() {
        notify(.gentleNudge, after: FallowNotificationService.Timing.nudgeDelay)
    }

    /// Shows the system prompt if this install has never been asked. Reset it by deleting the app.
    func requestNotificationPermission() {
        guard let notifications else { return }
        Task { await notifications.requestAuthorizationIfNeeded() }
    }

    /// Notifications name a resting session, so one is staged first when nothing is resting.
    private func notify(_ kind: FallowNotificationService.Kind, after delay: TimeInterval) {
        guard let notifications else { return }
        if sync.activeSession?.phase != .resting {
            sync.stage(DemoSessionFactory.macRestingDemo)
        }
        guard let session = sync.activeSession else { return }
        Task { await notifications.schedule(kind, for: session, after: delay) }
    }
    #endif
}
#endif
