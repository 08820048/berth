import AppKit
import SwiftUI

@MainActor
final class BerthAppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: BerthAppDelegate?

    let model = AppModel()
    private let settingsWindow = SettingsWindowController()
    private var panelPresentation: Binding<Bool>?
    private var lastHotKey: HotKeySpec?
    private var hotKeyTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self
        NSApp.setActivationPolicy(.accessory)
        HotKeyCenter.shared.onPressed = { [weak self] in
            self?.panelPresentation?.wrappedValue.toggle()
        }
        hotKeyTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                let current = self.model.settings.hotKey
                if current != self.lastHotKey {
                    self.lastHotKey = current
                    HotKeyCenter.shared.register(current)
                }
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
        }
    }

    func bindPanelPresentation(_ binding: Binding<Bool>) {
        panelPresentation = binding
    }

    func openSettings() {
        settingsWindow.show(settings: model.settings)
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
