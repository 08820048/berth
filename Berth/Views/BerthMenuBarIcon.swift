import AppKit
import SwiftUI

enum BerthMenuBarIconState: CaseIterable {
    case normal
    case conflict
    case working
}

struct BerthMenuBarIcon: View {
    let state: BerthMenuBarIconState

    var body: some View {
        Image(nsImage: BerthMenuBarIconRenderer.image(for: state))
            .renderingMode(.template)
            .frame(width: 18, height: 18)
            .accessibilityHidden(true)
    }
}

/// `MenuBarExtra` ultimately hosts an AppKit status item. Supplying a native
/// template image keeps the custom mark visible and lets macOS tint it for every
/// menu-bar appearance, including the selected state.
@MainActor
enum BerthMenuBarIconRenderer {
    private static let normalImage = makeImage(for: .normal)
    private static let conflictImage = makeImage(for: .conflict)
    private static let workingImage = makeImage(for: .working)

    static func image(for state: BerthMenuBarIconState) -> NSImage {
        switch state {
        case .normal: normalImage
        case .conflict: conflictImage
        case .working: workingImage
        }
    }

    private static func makeImage(for state: BerthMenuBarIconState) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18))
        for scale in [1, 2] {
            image.addRepresentation(makeRepresentation(for: state, scale: scale))
        }
        image.isTemplate = true
        return image
    }

    private static func makeRepresentation(for state: BerthMenuBarIconState, scale: Int) -> NSBitmapImageRep {
        let pixels = 18 * scale
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixels,
            pixelsHigh: pixels,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else {
            preconditionFailure("Could not create menu bar icon bitmap")
        }
        bitmap.size = NSSize(width: 18, height: 18)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        graphics.imageInterpolation = .high
        graphics.shouldAntialias = true
        graphics.cgContext.translateBy(x: 0, y: CGFloat(pixels))
        graphics.cgContext.scaleBy(x: CGFloat(scale), y: -CGFloat(scale))

        let iconRect = NSRect(x: 1, y: 1, width: 16, height: 16)
        NSColor.black.setFill()
        covePath(in: iconRect).fill()
        drawStatus(state, in: iconRect)
        NSGraphicsContext.restoreGraphicsState()
        return bitmap
    }

    private static func drawStatus(_ state: BerthMenuBarIconState, in rect: NSRect) {
        let center = CGPoint(x: rect.midX, y: rect.midY + 1)
        switch state {
        case .normal:
            NSBezierPath(ovalIn: NSRect(x: center.x - 1.5, y: center.y - 1.5, width: 3, height: 3)).fill()
        case .conflict:
            NSBezierPath(
                roundedRect: NSRect(x: center.x - 0.75, y: center.y - 2.7, width: 1.5, height: 3.2),
                xRadius: 0.75,
                yRadius: 0.75
            ).fill()
            NSBezierPath(ovalIn: NSRect(x: center.x - 0.75, y: center.y + 1.1, width: 1.5, height: 1.5)).fill()
        case .working:
            NSColor.black.setStroke()
            let ring = NSBezierPath(ovalIn: NSRect(x: center.x - 2.25, y: center.y - 2.25, width: 4.5, height: 4.5))
            ring.lineWidth = 1.4
            ring.stroke()
        }
    }

    private static func covePath(in rect: NSRect) -> NSBezierPath {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }

        let path = NSBezierPath()
        path.move(to: point(0.78, 0.06))
        path.curve(to: point(0.59, 0.90), controlPoint1: point(0.92, 0.36), controlPoint2: point(0.84, 0.75))
        path.curve(to: point(0.12, 0.75), controlPoint1: point(0.39, 0.96), controlPoint2: point(0.20, 0.89))
        path.curve(to: point(0.42, 0.26), controlPoint1: point(-0.02, 0.55), controlPoint2: point(0.16, 0.28))
        path.curve(to: point(0.51, 0.37), controlPoint1: point(0.46, 0.27), controlPoint2: point(0.49, 0.32))
        path.curve(to: point(0.22, 0.64), controlPoint1: point(0.34, 0.36), controlPoint2: point(0.19, 0.47))
        path.curve(to: point(0.53, 0.77), controlPoint1: point(0.31, 0.77), controlPoint2: point(0.40, 0.80))
        path.curve(to: point(0.72, 0.49), controlPoint1: point(0.66, 0.73), controlPoint2: point(0.73, 0.61))
        path.curve(to: point(0.78, 0.06), controlPoint1: point(0.70, 0.32), controlPoint2: point(0.77, 0.23))
        path.close()
        return path
    }
}
