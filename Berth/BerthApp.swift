import SwiftUI
import MenuBarExtraAccess

@main
struct BerthApp: App {
    @NSApplicationDelegateAdaptor(BerthAppDelegate.self) private var appDelegate
    @State private var isMenuPresented = false

    var body: some Scene {
        let menuPresentation = $isMenuPresented

        MenuBarExtra {
            MenuBarPanel(
                store: appDelegate.model.store,
                settings: appDelegate.model.settings,
                onSettingsTransition: { appDelegate.anchorPanelRightEdge() }
            )
            .introspectMenuBarExtraWindow { appDelegate.bindPanelWindow($0) }
            .environment(\.locale, appDelegate.model.settings.language.locale)
        } label: {
            MenuBarLabel(store: appDelegate.model.store, settings: appDelegate.model.settings)
                .environment(\.locale, appDelegate.model.settings.language.locale)
        }
        .menuBarExtraAccess(isPresented: menuPresentation) { _ in
            appDelegate.bindPanelPresentation(menuPresentation)
        }
        .menuBarExtraStyle(.window)
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
