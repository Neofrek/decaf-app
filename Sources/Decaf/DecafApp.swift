import AppKit
import SwiftUI

@main
struct DecafApp: App {
    @StateObject private var controller = DecafController()

    var body: some Scene {
        MenuBarExtra {
            DecafMenuView()
                .environmentObject(controller)
        } label: {
            Image(nsImage: DecafMenuBarIcon.image(for: controller.currentMode))
                .accessibilityLabel("Decaf")
        }
        .menuBarExtraStyle(.window)
    }
}

enum DecafMenuBarIcon {
    static func image(for mode: DecafMode) -> NSImage {
        let image = NSImage(size: NSSize(width: 22, height: 22), flipped: true) { rect in
            draw(in: rect, mode: mode)
            return true
        }
        image.isTemplate = !(mode == .night || mode == .focusNight)
        return image
    }

    private static func draw(in rect: CGRect, mode: DecafMode) {
        let scale = min(rect.width, rect.height) / 22
        let origin = CGPoint(x: rect.midX - 11 * scale, y: rect.midY - 11 * scale)
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: origin.x + x * scale, y: origin.y + y * scale)
        }
        func box(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
            CGRect(x: origin.x + x * scale, y: origin.y + y * scale, width: width * scale, height: height * scale)
        }

        NSColor.black.setStroke()
        NSColor.black.setFill()

        let alpha: CGFloat = mode == .off ? 0.56 : 1
        let primary = NSColor.black.withAlphaComponent(alpha)
        let secondary = NSColor.black.withAlphaComponent(alpha * 0.62)
        let moonColor = (mode == .night || mode == .focusNight) ? NSColor(calibratedRed: 1.0, green: 0.76, blue: 0.28, alpha: 1) : primary

        let mug = NSBezierPath(roundedRect: box(4.2, 9.1, 11.2, 9.55), xRadius: 2.1 * scale, yRadius: 2.35 * scale)
        primary.setStroke()
        mug.lineWidth = 1.18 * scale
        mug.stroke()

        let lip = NSBezierPath(ovalIn: box(4.1, 8.2, 11.4, 2.7))
        lip.lineWidth = 1.05 * scale
        lip.stroke()

        let coffee = NSBezierPath()
        coffee.move(to: point(5.4, 9.5))
        coffee.curve(to: point(14.3, 9.5), controlPoint1: point(7.8, 10.2), controlPoint2: point(11.9, 10.2))
        secondary.setStroke()
        coffee.lineWidth = 0.82 * scale
        coffee.lineCapStyle = .round
        coffee.stroke()

        let handle = NSBezierPath()
        handle.move(to: point(15.3, 11.0))
        handle.curve(to: point(19.1, 11.8), controlPoint1: point(18.1, 9.2), controlPoint2: point(20.2, 10.6))
        handle.curve(to: point(15.4, 15.5), controlPoint1: point(20.0, 14.0), controlPoint2: point(18.0, 16.2))
        primary.setStroke()
        handle.lineWidth = 1.16 * scale
        handle.lineCapStyle = .round
        handle.stroke()

        let steam1 = NSBezierPath()
        steam1.move(to: point(8.2, 7.2))
        steam1.curve(to: point(8.9, 2.7), controlPoint1: point(6.7, 5.3), controlPoint2: point(10.0, 4.6))
        secondary.setStroke()
        steam1.lineWidth = 1.35 * scale
        steam1.lineCapStyle = .round
        steam1.stroke()

        let steam2 = NSBezierPath()
        steam2.move(to: point(11.8, 7.0))
        steam2.curve(to: point(12.6, 2.3), controlPoint1: point(13.5, 5.1), controlPoint2: point(10.2, 4.1))
        steam2.lineWidth = 1.35 * scale
        steam2.lineCapStyle = .round
        steam2.stroke()

        let crescent = NSBezierPath()
        crescent.move(to: point(10.9, 12.85))
        crescent.curve(to: point(8.35, 14.9), controlPoint1: point(9.9, 12.95), controlPoint2: point(8.9, 13.85))
        crescent.curve(to: point(9.85, 16.95), controlPoint1: point(7.95, 15.75), controlPoint2: point(8.4, 16.65))
        crescent.curve(to: point(12.55, 16.35), controlPoint1: point(10.65, 17.15), controlPoint2: point(11.65, 16.95))
        crescent.curve(to: point(10.85, 16.55), controlPoint1: point(11.65, 16.35), controlPoint2: point(11.2, 16.45))
        crescent.curve(to: point(9.85, 14.9), controlPoint1: point(10.0, 16.15), controlPoint2: point(9.65, 15.55))
        crescent.curve(to: point(10.9, 12.85), controlPoint1: point(10.0, 14.1), controlPoint2: point(10.35, 13.45))
        crescent.close()
        moonColor.setFill()
        crescent.fill()

        if mode == .focusNight || mode == .attached {
            NSBezierPath(ovalIn: box(14.1, 4.2, 2.0, 2.0)).fill()
        }
    }
}
