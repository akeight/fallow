import Foundation
import UserNotifications

/// Local notifications for a resting thought, and where a tap on one should land.
/// Views never touch this; `PhoneStore` receives routes and applies them through its own transitions.
///
/// Permission is never asked at launch. Call `requestAuthorizationIfNeeded()` at a resting or handoff
/// moment; `schedule` also asks, once, if the person has not been asked yet.
///
/// Mac coordination, not implemented: when a Mac session enters `.resting` and that change reaches
/// the phone through real sync (CloudKit or push), the phone schedules `.restStarted` for it.
/// The in-memory `DemoFallowSyncService` never crosses devices, so the demo triggers it instead.
@MainActor
final class FallowNotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = FallowNotificationService()

    enum Kind: String, CaseIterable {
        case restStarted
        case gentleNudge

        var title: String { "FALLOW" }

        var body: String {
            switch self {
            case .restStarted: DemoCopy.restingNowNotice
            case .gentleNudge: DemoCopy.hadSpace
            }
        }

        /// One pending request per kind, so scheduling again replaces it.
        var identifier: String { "fallow.\(rawValue)" }
    }

    struct Route: Equatable {
        let kind: Kind
        let sessionID: UUID?
    }

    /// Delays for the prototype, in seconds. In DEBUG, `-fallowRestDelay 5` or `-fallowNudgeDelay 20` override them.
    enum Timing {
        static var restDelay: TimeInterval { delay("fallowRestDelay", fallback: 3) }
        static var nudgeDelay: TimeInterval { delay("fallowNudgeDelay", fallback: 15) }

        private static func delay(_ key: String, fallback: TimeInterval) -> TimeInterval {
            #if DEBUG
            let override = UserDefaults.standard.double(forKey: key)
            if override > 0 { return override }
            #endif
            return fallback
        }
    }

    private enum Key {
        static let kind = "fallowKind"
        static let sessionID = "fallowSessionID"
    }

    /// Set by the store. A tap that arrives first, on a cold launch, waits here until it is.
    var onRoute: ((Route) -> Void)? {
        didSet { flushPendingRoute() }
    }

    private var pendingRoute: Route?
    private let center = UNUserNotificationCenter.current()

    private override init() {
        super.init()
    }

    // MARK: Permission

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Shows the system prompt only when the person has never been asked.
    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        switch await authorizationStatus() {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert])) ?? false
        default:
            return false
        }
    }

    // MARK: Scheduling

    func schedule(_ kind: Kind, for session: FallowSession, after delay: TimeInterval) async {
        guard await requestAuthorizationIfNeeded() else { return }
        let content = UNMutableNotificationContent()
        content.title = kind.title
        content.body = kind.body
        content.userInfo = [Key.kind: kind.rawValue, Key.sessionID: session.id.uuidString]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(delay, 1), repeats: false)
        center.removePendingNotificationRequests(withIdentifiers: [kind.identifier])
        try? await center.add(UNNotificationRequest(identifier: kind.identifier, content: content, trigger: trigger))
    }

    /// Delivered notifications are left alone; tapping one later falls back through `PhoneStore.open`.
    func cancelPending() {
        center.removePendingNotificationRequests(withIdentifiers: Kind.allCases.map(\.identifier))
    }

    /// Pending and delivered alike, so an old banner cannot be tapped into a fresh start.
    func clearAll() {
        let identifiers = Kind.allCases.map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    // MARK: Routing

    private func deliver(_ route: Route) {
        if let onRoute {
            onRoute(route)
        } else {
            pendingRoute = route
        }
    }

    private func flushPendingRoute() {
        guard let route = pendingRoute, let onRoute else { return }
        pendingRoute = nil
        onRoute(route)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo
        let kind = (info[Key.kind] as? String).flatMap(Kind.init(rawValue:))
        let sessionID = (info[Key.sessionID] as? String).flatMap(UUID.init(uuidString:))
        Task { @MainActor in
            if let kind { self.deliver(Route(kind: kind, sessionID: sessionID)) }
            completionHandler()
        }
    }

    /// An open app is not interrupted, except in DEBUG so demo triggers can be seen in place.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        #if DEBUG
        completionHandler([.banner, .list])
        #else
        completionHandler([.list])
        #endif
    }
}
