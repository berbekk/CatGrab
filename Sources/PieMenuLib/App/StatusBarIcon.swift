import AppKit
import SwiftUI

/// Значок для строки меню рисуется кодом из того же контура, что и кот в центре пирога.
/// Никаких файлов ресурсов: не зависит от того, как собран бандл (SwiftPM / Xcode / build.sh).
enum StatusBarIcon {
    private static let logicalSize = NSSize(width: 18, height: 18)
    private static let insetRatio: CGFloat = 0.06

    static func make() -> NSImage {
        let image = NSImage(size: logicalSize, flipped: true) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let inset = rect.width * insetRatio
            let box = rect.insetBy(dx: inset, dy: inset)
            ctx.addPath(CatSVGHeadShape().path(in: box).cgPath)
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.fillPath()
            ctx.setBlendMode(.clear)
            ctx.addPath(CatSVGMouthShape().path(in: box).cgPath)
            ctx.fillPath()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "PieMenu"
        return image
    }
}
