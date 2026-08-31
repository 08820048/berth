import AppKit
import XCTest
@testable import Berth

final class MenuBarIconTests: XCTestCase {
    @MainActor
    func testEveryStateProducesAPaintedTemplateImage() throws {
        for state in BerthMenuBarIconState.allCases {
            let image = BerthMenuBarIconRenderer.image(for: state)
            XCTAssertTrue(image.isTemplate)
            XCTAssertEqual(image.size, NSSize(width: 18, height: 18))
            XCTAssertEqual(image.representations.count, 2)
            XCTAssertEqual(Set(image.representations.map(\.pixelsWide)), [18, 36])

            let data = try XCTUnwrap(image.tiffRepresentation)
            let bitmap = try XCTUnwrap(NSBitmapImageRep(data: data))
            var paintedPixels = 0
            for y in 0..<bitmap.pixelsHigh {
                for x in 0..<bitmap.pixelsWide where (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.1 {
                    paintedPixels += 1
                }
            }
            XCTAssertGreaterThan(paintedPixels, 20)
        }
    }
}
