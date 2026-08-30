import AppKit
import SwiftUI

/// Aligns SwiftUI scrollers in NSPopover with the panel chrome.
/// Default popover hosting leaves a black scroller slot; clearing the scroll
/// view's own backgrounds keeps the popover's frosted material visible,
/// matching MenuBarExtra apps like Port Radar.
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
            // Clear every background layer so the popover's frosted material
            // shows through the scroller area.
            scroll.drawsBackground = false
            scroll.backgroundColor = .clear
            scroll.contentView.drawsBackground = false
            scroll.contentView.backgroundColor = .clear
            (scroll.documentView as? NSView)?.wantsLayer = true
            (scroll.documentView as? NSView)?.layer?.backgroundColor = .clear
            scroll.autohidesScrollers = true
            scroll.hasHorizontalScroller = false
            scroll.scrollerStyle = .overlay
            scroll.scrollerKnobStyle = .default
            style(scroll.verticalScroller)
            style(scroll.horizontalScroller)
        }

        private func style(_ scroller: NSScroller?) {
            guard let scroller else { return }
            scroller.knobStyle = .default
            scroller.controlSize = .small
            scroller.wantsLayer = true
            scroller.layer?.backgroundColor = NSColor.clear.cgColor
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
