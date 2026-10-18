import SwiftUI

@main
struct FallowMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        FallowFont.register()
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
