import AppKit
import SwiftUI

/// Aligns SwiftUI scrollers in NSPopover with the panel chrome.
/// Default popover hosting leaves a black scroller slot; overlay + window
/// background matches MenuBarExtra apps like Port Radar.
struct PanelScrollFix: NSViewRepresentable {
    func makeNSView(context: Context) -> SentinelView {
        SentinelView()
    }

    func updateNSView(_ nsView: SentinelView, context: Context) {
        nsView.applySoon()
    }

    final class SentinelView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            applySoon()
        }

        override func viewDidMoveToSuperview() {
            super.viewDidMoveToSuperview()
            applySoon()
        }

        func applySoon() {
            DispatchQueue.main.async { [weak self] in
                self?.apply()
            }
        }

        func apply() {
            guard let scroll = nearestScrollView() else { return }
            let fill = NSColor.windowBackgroundColor
            scroll.drawsBackground = true
            scroll.backgroundColor = fill
            scroll.contentView.drawsBackground = true
            scroll.contentView.backgroundColor = fill
            scroll.autohidesScrollers = true
            scroll.hasHorizontalScroller = false
            scroll.scrollerStyle = .overlay
            scroll.scrollerKnobStyle = .default
            style(scroll.verticalScroller, fill: fill)
            style(scroll.horizontalScroller, fill: fill)
        }

        private func style(_ scroller: NSScroller?, fill: NSColor) {
            guard let scroller else { return }
            scroller.knobStyle = .default
            scroller.controlSize = .small
            scroller.wantsLayer = true
            scroller.layer?.backgroundColor = fill.withAlphaComponent(0).cgColor
            scroller.layer?.masksToBounds = true
        }

        private func nearestScrollView() -> NSScrollView? {
            var current: NSView? = self
            while let view = current {
                if let scroll = view as? NSScrollView {
                    return scroll
                }
                current = view.superview
            }
            return window?.contentView?.firstScrollView()
        }
    }
}

private extension NSView {
    func firstScrollView() -> NSScrollView? {
        if let scroll = self as? NSScrollView { return scroll }
        for child in subviews {
            if let found = child.firstScrollView() { return found }
        }
        return nil
    }
}
