import SwiftUI
import UserNotifications

@main
struct FallowIOSApp: App {
    init() {
        FallowFont.register()
        // Before launch finishes, so a tap that opened the app is still delivered.
        UNUserNotificationCenter.current().delegate = FallowNotificationService.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
