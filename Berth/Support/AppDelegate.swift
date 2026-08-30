import AppKit
import SwiftUI

@MainActor
final class BerthAppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: BerthAppDelegate?

    let model = AppModel()
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self
        NSApp.setActivationPolicy(.accessory)
        statusItem = StatusItemController(model: model)
    }

    func revealForSettings() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    func returnToAccessory() {
        NSApp.setActivationPolicy(.accessory)
    }
}

enum Clipboard {
    static func copy(_ value: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
    }
}

enum WorkspaceActions {
    static func openInBrowser(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    static func revealInFinder(_ path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
