import SwiftUI

@main
struct RuSecureApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        SiteStore.shared.seedDefaultsIfNeeded()
        GeositeStore.shared.load()
        GeositeStore.shared.updateIfNeededAsync()
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
