import AppKit
import SwiftUI

@MainActor
final class BerthAppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var panelPresentation: Binding<Bool>?
    private weak var panelWindow: NSWindow?
    private var panelResizeObserver: NSObjectProtocol?
    private var panelRightEdge: CGFloat?
    private var releasePanelAnchor: DispatchWorkItem?
    private var lastHotKey: HotKeySpec?
    private var hotKeyTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
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

    func bindPanelWindow(_ window: NSWindow) {
        guard panelWindow !== window else { return }
        if let panelResizeObserver {
            NotificationCenter.default.removeObserver(panelResizeObserver)
        }
        panelWindow = window
        panelResizeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification,
            object: window,
            queue: .main
        ) { [weak self, weak window] _ in
            MainActor.assumeIsolated {
                guard let self, let window, let rightEdge = self.panelRightEdge else { return }
                window.setFrameOrigin(NSPoint(x: rightEdge - window.frame.width, y: window.frame.minY))
            }
        }
    }

    func anchorPanelRightEdge() {
        guard let panelWindow else { return }
        panelRightEdge = panelWindow.frame.maxX
        releasePanelAnchor?.cancel()
        let release = DispatchWorkItem { [weak self] in
            self?.panelRightEdge = nil
        }
        releasePanelAnchor = release
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: release)
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
