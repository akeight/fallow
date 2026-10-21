import CoreGraphics
import Foundation
import UserNotifications

/// The parts of `UNUserNotificationCenter` FALLOW uses, so tests can stand in for it.
protocol NotificationCentering: AnyObject {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func removeDeliveredNotifications(withIdentifiers identifiers: [String])
}

extension UNUserNotificationCenter: NotificationCentering {
    func authorizationStatus() async -> UNAuthorizationStatus {
        await notificationSettings().authorizationStatus
    }
}

/// Local notifications for a resting thought, and where a tap on one should land.
/// Views never touch this; the stores receive routes and apply them through their own transitions.
///
/// Permission is never asked at launch. Call `requestAuthorizationIfNeeded()` at a resting or handoff
/// moment; `schedule` also asks, once, if the person has not been asked yet.
///
/// The return nudge is scheduled only by the device where the pause began, from
/// `FallowReturnPolicy.action(from:to:)`. A session that arrives from the other device never schedules,
/// so the two devices cannot both check in for the same pause.
@MainActor
final class FallowNotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = FallowNotificationService()

    enum Kind: String, CaseIterable {
        case restStarted
        case gentleNudge
        /// The one state-aware check-in for a resting thought. Its words come from `FallowReturnPolicy`.
        case returnNudge

        var title: String { "FALLOW" }

        var body: String {
            switch self {
            case .restStarted: DemoCopy.restingNowNotice
            case .gentleNudge, .returnNudge: DemoCopy.hadSpace
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
    /// The return nudge has its own `-fallowReturnDelay`, read by `FallowReturnPolicy`.
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
    private let center: any NotificationCentering
    private let orbURL: URL?
    /// Bumped by every schedule or cancel of the return nudge, so one still waiting on permission
    /// never lands after the person has already come back.
    private var returnGeneration = 0

    init(
        center: any NotificationCentering = UNUserNotificationCenter.current(),
        orbURL: URL? = Bundle.main.url(forResource: "NotificationOrb", withExtension: "png")
    ) {
        self.center = center
        self.orbURL = orbURL
        super.init()
    }

    // MARK: Permission

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.authorizationStatus()
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
        let content = content(kind, sessionID: session.id, title: kind.title, body: kind.body)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(delay, 1), repeats: false)
        center.removePendingNotificationRequests(withIdentifiers: [kind.identifier])
        try? await center.add(UNNotificationRequest(identifier: kind.identifier, content: content, trigger: trigger))
    }

    /// Applies what a session change means for its check-in.
    func apply(_ action: FallowReturnAction) {
        switch action {
        case .schedule(let nudge):
            Task { await scheduleReturn(nudge) }
        case .cancel:
            cancelReturn()
        case .none:
            break
        }
    }

    /// Replaces any earlier return nudge. A time already passed sends nothing.
    func scheduleReturn(_ nudge: FallowNudge, now: Date = Date()) async {
        returnGeneration += 1
        let generation = returnGeneration
        let delay = nudge.fireDate.timeIntervalSince(now)
        guard delay > 0 else { return }
        guard await requestAuthorizationIfNeeded(), generation == returnGeneration else { return }
        let identifier = Kind.returnNudge.identifier
        let content = content(.returnNudge, sessionID: nudge.sessionID, title: nudge.title, body: nudge.body)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(delay, 1), repeats: false)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
        try? await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    /// Pending and delivered alike, so a check-in can neither fire nor be tapped once the person is back.
    func cancelReturn() {
        returnGeneration += 1
        let identifier = Kind.returnNudge.identifier
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    /// After a launch restores the session: a check-in with no resting thought behind it is stale.
    func cancelStaleReturn(restored session: FallowSession?) {
        guard session?.phase != .resting else { return }
        cancelReturn()
    }

    /// Delivered notifications are left alone; tapping one later falls back through the store's `open`.
    func cancelPending() {
        center.removePendingNotificationRequests(withIdentifiers: Kind.allCases.map(\.identifier))
    }

    /// Pending and delivered alike, so an old banner cannot be tapped into a fresh start.
    func clearAll() {
        returnGeneration += 1
        let identifiers = Kind.allCases.map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    private func content(_ kind: Kind, sessionID: UUID, title: String, body: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.userInfo = [Key.kind: kind.rawValue, Key.sessionID: sessionID.uuidString]
        if let orb = orbAttachment() { content.attachments = [orb] }
        return content
    }

    /// The orb as the notification's image; the system app icon stays its identity. The system takes
    /// ownership of attachment files, so it gets a fresh copy rather than the bundle's own.
    /// Any failure sends the notification without it.
    private func orbAttachment() -> UNNotificationAttachment? {
        guard let orbURL else { return nil }
        let copy = FileManager.default.temporaryDirectory
            .appendingPathComponent("fallow-orb-\(UUID().uuidString)")
            .appendingPathExtension("png")
        do {
            try FileManager.default.copyItem(at: orbURL, to: copy)
            return try UNNotificationAttachment(identifier: "orb", url: copy, options: [
                // The orb fills the middle of its canvas; the thumbnail shows only that.
                UNNotificationAttachmentOptionsThumbnailClippingRectKey:
                    CGRect(x: 0.11, y: 0.11, width: 0.78, height: 0.78).dictionaryRepresentation
            ])
        } catch {
            try? FileManager.default.removeItem(at: copy)
            return nil
        }
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
    /// On the Mac the app stays frontmost behind the resting frost, so the return nudge still shows.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        #if DEBUG
        completionHandler([.banner, .list])
        #elseif os(macOS)
        let kind = (notification.request.content.userInfo[Key.kind] as? String).flatMap(Kind.init(rawValue:))
        completionHandler(kind == .returnNudge ? [.banner, .list] : [.list])
        #else
        completionHandler([.list])
        #endif
    }
}
