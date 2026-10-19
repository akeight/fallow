import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let sync = DemoFallowSyncService()
    private lazy var session = SessionModel(sync: sync)
    private let config = OrbTuningConfig()
    private var companion: CompanionController?
    #if DEBUG
    private lazy var demo = DemoController(sync: sync)
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        sync.onRemoteChange = { [weak self] session in self?.session.receive(session) }
        #if DEBUG
        companion = CompanionController(session: session, config: config, demo: demo)
        #else
        companion = CompanionController(session: session, config: config)
        #endif
        companion?.start()
        Task {
            if let active = await sync.loadActiveSession() { session.receive(active) }
            #if DEBUG
            demo.applyLaunchArgument()
            #endif
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
