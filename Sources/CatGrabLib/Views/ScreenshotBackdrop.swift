import AppKit
import SwiftUI

/// Фон для снимка кольца (`ScreenshotMode`, цель `pie`): своё окно под кольцом, чтобы в кадр
/// не попадал настоящий рабочий стол. По умолчанию — нарисованные «обои», на которых видно стекло.
enum ScreenshotBackdrop {
    @MainActor
    static func makeWindow(frame: NSRect, image: NSImage?) -> NSWindow {
        let window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = true
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        // Сразу под кольцом (оно на уровне `.screenSaver`).
        window.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue - 1)
        window.collectionBehavior = [.transient, .ignoresCycle, .fullScreenAuxiliary]
        window.contentView = NSHostingView(rootView: ScreenshotBackdropView(image: image))
        window.setFrame(frame, display: true)
        return window
    }
}

private struct ScreenshotBackdropView: View {
    let image: NSImage?

    var body: some View {
        GeometryReader { geometry in
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            } else {
                wallpaper(size: geometry.size)
            }
        }
        .ignoresSafeArea()
    }

    /// Большие мягкие пятна цвета на тёмно-синем — как абстрактные обои macOS.
    private func wallpaper(size: CGSize) -> some View {
        let side = max(size.width, size.height)
        return ZStack {
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.09, blue: 0.27), Color(red: 0.20, green: 0.10, blue: 0.38)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            blob(Color(red: 0.16, green: 0.45, blue: 1.0), side * 0.9, x: -0.32, y: -0.30, in: size)
            blob(Color(red: 0.98, green: 0.36, blue: 0.56), side * 0.8, x: 0.36, y: 0.34, in: size)
            blob(Color(red: 1.0, green: 0.70, blue: 0.28), side * 0.55, x: 0.42, y: -0.38, in: size)
            blob(Color(red: 0.45, green: 0.25, blue: 0.95), side * 0.7, x: -0.38, y: 0.42, in: size)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    private func blob(_ color: Color, _ diameter: CGFloat, x: CGFloat, y: CGFloat, in size: CGSize) -> some View {
        Circle()
            .fill(color.opacity(0.75))
            .frame(width: diameter, height: diameter)
            .blur(radius: diameter * 0.28)
            .offset(x: x * size.width, y: y * size.height)
    }
}
