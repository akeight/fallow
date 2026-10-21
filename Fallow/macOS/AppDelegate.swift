import AppKit
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let sync = DemoFallowSyncService(defaults: .standard)
    private let notifications = FallowNotificationService.shared
    private lazy var session = SessionModel(sync: sync, notifications: notifications)
    private let config = OrbTuningConfig()
    private var companion: CompanionController?
    #if DEBUG
    private lazy var demo = DemoController(sync: sync)
    #endif

    /// Before launch finishes, so a tap that opened the app is still delivered.
    func applicationWillFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = notifications
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        sync.onRemoteChange = { [weak self] session in self?.session.receive(session) }
        #if DEBUG
        companion = CompanionController(session: session, config: config, demo: demo)
        #else
        companion = CompanionController(session: session, config: config)
        #endif
        companion?.start()
        Task {
            let active = await sync.loadActiveSession()
            if let active { session.receive(active) }
            notifications.cancelStaleReturn(restored: active)
            notifications.onRoute = { [weak self] route in self?.open(route) }
            #if DEBUG
            demo.applyLaunchArgument()
            #endif
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// The return nudge opens the doorway for the thought resting here. Other kinds are the iPhone's.
    private func open(_ route: FallowNotificationService.Route) {
        guard route.kind == .returnNudge else { return }
        session.openReturn(sessionID: route.sessionID)
        NSApp.activate(ignoringOtherApps: true)
    }
}
