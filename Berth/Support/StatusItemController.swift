import AppKit
import SwiftUI

@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    private let item: NSStatusItem
    private let popover = NSPopover()
    private let model: AppModel
    private let settingsWindow = SettingsWindowController()
    private var iconTask: Task<Void, Never>?

    init(model: AppModel) {
        self.model = model
        self.item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureItem()
        configurePopover()
        configureHotKey()
        observeIcon()
        refreshIcon()
    }

    func togglePanel() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPanel()
        }
    }

    func showPanel() {
        guard let button = item.button else { return }
        Task { await model.store.refresh() }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        button.isHighlighted = true
        NSApp.activate()
    }

    func hidePanel() {
        popover.performClose(nil)
    }

    func openSettings() {
        hidePanel()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.settingsWindow.show(settings: self.model.settings)
        }
    }

    func popoverDidClose(_ notification: Notification) {
        item.button?.isHighlighted = false
    }

    private func configureItem() {
        guard let button = item.button else { return }
        button.imagePosition = .imageLeft
        button.target = self
        button.action = #selector(clicked)
        button.sendAction(on: [.leftMouseUp])
        button.setAccessibilityLabel("Berth")
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        let root = MenuBarPanel(
            store: model.store,
            settings: model.settings,
            onOpenSettings: { [weak self] in self?.openSettings() },
            onSizeChange: { [weak self] size in
                guard let self else { return }
                let next = NSSize(width: BerthLayout.panelWidth, height: min(max(size.height, 160), 560))
                if abs(self.popover.contentSize.height - next.height) > 1
                    || abs(self.popover.contentSize.width - next.width) > 1 {
                    self.popover.contentSize = next
                }
            }
        )
        let hosting = NSHostingController(rootView: root)
        popover.contentViewController = hosting
        popover.contentSize = NSSize(width: BerthLayout.panelWidth, height: 280)
    }

    private func configureHotKey() {
        HotKeyCenter.shared.onPressed = { [weak self] in
            self?.togglePanel()
        }
        HotKeyCenter.shared.register(model.settings.hotKey)
    }

    private func observeIcon() {
        iconTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                self.refreshIcon()
                self.reregisterHotKeyIfNeeded()
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
        }
    }

    private var lastHotKey: HotKeySpec?

    private func reregisterHotKeyIfNeeded() {
        let current = model.settings.hotKey
        if lastHotKey != current {
            lastHotKey = current
            HotKeyCenter.shared.register(current)
        }
    }

    private func refreshIcon() {
        let store = model.store
        let settings = model.settings
        let symbol: String
        if store.isStopping {
            symbol = "arrow.triangle.2.circlepath"
        } else if store.hasConflict {
            symbol = "exclamationmark.triangle"
        } else {
            symbol = "anchor"
        }
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Berth")
        image?.isTemplate = true
        item.button?.image = image
        if settings.showMenuBarCount, store.developmentCount > 0, !store.isStopping {
            item.button?.title = "\(store.developmentCount)"
        } else {
            item.button?.title = ""
        }
        let label: String
        if store.isStopping {
            label = L10n.string("menu.busy")
        } else if store.hasConflict {
            label = L10n.string("menu.conflict")
        } else {
            label = L10n.string("menu.count", store.developmentCount)
        }
        item.button?.setAccessibilityLabel(label)
        item.button?.toolTip = label
    }

    @objc private func clicked() {
        togglePanel()
    }
}
