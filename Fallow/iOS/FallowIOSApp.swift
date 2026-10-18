import SwiftUI

@main
struct FallowIOSApp: App {
    init() {
        FallowFont.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
