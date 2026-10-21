#if DEBUG
import Foundation

/// Puts this device's active session into a step of the presentation, as if it had synced
/// from the other device. The stores apply it through their normal transitions.
///
/// Rehearsal, with no code changes between steps:
/// - Mac: Demo › Reset. Capture a thought for real, choose its creative state and distance,
///   and hold to release. The Mac keeps the presenter's own words.
/// - iPhone: long-press the wordmark › Prepare Demo Rest, then lock the phone. Tap the
///   notification, check the resting thought, and tap "I’m ready to return".
/// - Mac: Demo › Return Requested, then reflect and go back in through the real return.
/// - Between takes: Reset on the Mac, No Active Session on the iPhone.
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
            case .macReleased: "Resting"
            case .phoneResting: "Mac Resting"
            case .phoneReturnRequested, .macReturning: "Return Requested"
            case .complete: "Complete"
            }
        }

        static let mac: [Scenario] = [.reset, .macReleased, .macReturning, .complete]
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
        case .phoneResting: preparePhoneForMacRest()
        case .phoneReturnRequested: preparePhoneReturnRequested()
        case .macReturning: prepareMacReturn()
        case .complete: setComplete()
        }
    }

    /// `-fallowDemo phoneResting`, for example. Unknown names are ignored.
    func applyLaunchArgument() {
        guard let name = UserDefaults.standard.string(forKey: "fallowDemo"),
              let scenario = Scenario(rawValue: name) else { return }
        run(scenario)
    }

    /// Clears the staged session and, on the iPhone, every pending or delivered FALLOW notification,
    /// so nothing from the last take can land in the next one.
    func resetDemo() {
        #if os(iOS)
        notifications?.clearAll()
        #endif
        sync.stage(nil)
    }

    /// A thought already resting on this Mac keeps the presenter's words; otherwise the demo session rests.
    func setMacReleased() {
        sync.stage(DemoSessionFactory.macRestingDemo)
    }

    /// The Mac-originated session, already resting. Setup is not replayed.
    func preparePhoneForMacRest() {
        sync.stage(DemoSessionFactory.macRestingDemo)
    }

    func preparePhoneReturnRequested() {
        sync.stage(returnRequested)
    }

    /// Runs the Mac's real return from the doorway. A session resting here keeps its own words and choices.
    func prepareMacReturn() {
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
    /// One tap before locking the phone: the Mac session rests here, and its notification follows.
    func prepareDemoRest() {
        notifications?.clearAll()
        preparePhoneForMacRest()
        triggerRestNotification()
    }

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

    /// The staged session lives in memory, so it is gone if the app was closed before its
    /// notification was tapped. Stage it again so the tap still lands on the resting thought.
    func restore(for route: FallowNotificationService.Route) {
        guard route.sessionID == DemoSessionFactory.id, sync.activeSession == nil else { return }
        preparePhoneForMacRest()
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
