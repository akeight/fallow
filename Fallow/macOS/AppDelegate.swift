import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let session = SessionModel()
    private let config = OrbTuningConfig()
    private var companion: CompanionController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        companion = CompanionController(session: session, config: config)
        companion?.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
