import AppKit
import XCTest
@testable import Berth

@MainActor
final class PanelWindowAnchorTests: XCTestCase {
    func testResizingKeepsRightEdgeFixedDuringSettingsTransition() {
        let delegate = BerthAppDelegate()
        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 380, height: 500),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        let rightEdge = window.frame.maxX

        delegate.bindPanelWindow(window)
        delegate.anchorPanelRightEdge()
        window.setFrame(NSRect(x: 100, y: 100, width: 700, height: 500), display: false)

        XCTAssertEqual(window.frame.maxX, rightEdge, accuracy: 0.5)
    }
}
