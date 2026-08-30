import SwiftUI

@main
struct BerthApp: App {
    @NSApplicationDelegateAdaptor(BerthAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(settings: appDelegate.model.settings)
        }
    }
}

@MainActor
@Observable
final class AppModel {
    let settings: AppSettings
    let store: PortStore

    init() {
        let settings = AppSettings()
        self.settings = settings
        self.store = PortStore(settings: settings)
    }
}
