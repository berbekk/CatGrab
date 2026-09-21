import AppKit
import SwiftUI

/// Значок кота для строки меню: сначала `Mini-icon.svg` из бандла, иначе тот же контур, что в пироге.
enum StatusBarIcon {
    private static let logicalSize = NSSize(width: 18, height: 18)
    private static let insetRatio: CGFloat = 0.06

    static func make() -> NSImage {
        let url = Bundle.main.url(forResource: "Mini-icon", withExtension: "svg")
            ?? Bundle.module.url(forResource: "Mini-icon", withExtension: "svg")
        if let url, let svg = NSImage(contentsOf: url) {
            let raster = NSImage(size: logicalSize, flipped: false) { rect in
                svg.draw(in: rect)
                return true
            }
            raster.isTemplate = true
            raster.accessibilityDescription = "CatGrab"
            return raster
        }
        return drawCatSilhouette()
    }

    private static func drawCatSilhouette() -> NSImage {
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
        image.accessibilityDescription = "CatGrab"
        return image
    }
}
