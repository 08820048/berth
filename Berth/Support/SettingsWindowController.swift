import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var settings: AppSettings?

    func show(settings: AppSettings) {
        self.settings = settings
        if window == nil {
            window = makeWindow(settings: settings)
        }
        BerthAppDelegate.shared?.revealForSettings()
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
        NSApp.activate()
    }

    func windowWillClose(_ notification: Notification) {
        BerthAppDelegate.shared?.returnToAccessory()
    }

    func windowDidBecomeKey(_ notification: Notification) {
        BerthAppDelegate.shared?.revealForSettings()
    }

    private func makeWindow(settings: AppSettings) -> NSWindow {
        let hosting = NSHostingController(rootView: SettingsView(settings: settings))
        let window = NSWindow(contentViewController: hosting)
        window.title = L10n.string("settings.title")
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 480, height: 560))
        window.contentMinSize = NSSize(width: 460, height: 480)
        window.isReleasedWhenClosed = false
        window.identifier = NSUserInterfaceItemIdentifier("berth-settings")
        window.delegate = self
        window.level = .normal
        return window
    }
}
