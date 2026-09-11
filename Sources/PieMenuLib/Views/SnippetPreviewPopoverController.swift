import AppKit
import SwiftUI

/// Показ `SnippetPreviewBadge` под иконкой приложения в системном меню‑баре.
/// Используется как подсказка о сниппете при наведении на сектор в pie‑меню.
/// Внутри — borderless `NSPanel` с `NSHostingView`, позиционируется по статус‑баттону;
/// хвостик бабла указывает на центр иконки в меню‑баре.
@MainActor
final class SnippetPreviewPopoverController {
    /// Зазор между нижним краем иконки в меню‑баре и кончиком хвостика бабла.
    private static let verticalGap: CGFloat = 2
    /// Минимальный отступ от правого/левого краёв видимой области экрана.
    private static let screenMargin: CGFloat = 8
    /// Длина хвостика речевого пузыря.
    private static let tailLength: CGFloat = 9
    /// Половина ширины основания хвостика у плашки.
    private static let tailHalfBase: CGFloat = 7

    private var panel: NSPanel?
    private var hostingView: NSHostingView<SnippetPreviewBadge>?

    func show(text: String, caption: String, anchor: NSStatusItem) {
        let isFirstShow = panel == nil
        ensurePanel(text: text, caption: caption)
        guard let panel = panel, let hosting = hostingView else { return }

        layout(panel: panel, hosting: hosting, text: text, caption: caption, anchor: anchor)

        if isFirstShow || !panel.isVisible {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.12
                panel.animator().alphaValue = 1
            }
        }
    }

    func hide() {
        guard let panel = panel, panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.1
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })
    }

    private func ensurePanel(text: String, caption: String) {
        guard panel == nil else { return }

        let draft = SnippetPreviewBadge(
            text: text,
            caption: caption,
            tail: defaultTail(baseCenter: 0)
        )
        let hosting = NSHostingView(rootView: draft)
        hosting.frame = CGRect(origin: .zero, size: hosting.fittingSize)

        let panel = NSPanel(
            contentRect: hosting.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .statusBar
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.animationBehavior = .none
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.contentView = hosting
        panel.alphaValue = 0

        self.panel = panel
        self.hostingView = hosting
    }

    /// Два прохода: (1) меряем размер плашки с «черновым» хвостиком, позиционируем и клэмпим
    /// окно, (2) пересчитываем `baseCenter` хвостика так, чтобы его кончик попадал в центр
    /// статус‑иконки, и обновляем `rootView`.
    private func layout(panel: NSPanel, hosting: NSHostingView<SnippetPreviewBadge>, text: String, caption: String, anchor: NSStatusItem) {
        guard let button = anchor.button, let buttonWindow = button.window else { return }

        hosting.rootView = SnippetPreviewBadge(text: text, caption: caption, tail: defaultTail(baseCenter: 0))
        hosting.layoutSubtreeIfNeeded()
        let size = hosting.fittingSize

        let buttonFrameInWindow = button.convert(button.bounds, to: nil)
        let buttonFrameOnScreen = buttonWindow.convertToScreen(buttonFrameInWindow)

        var originX = buttonFrameOnScreen.midX - size.width / 2
        let originY = buttonFrameOnScreen.minY - Self.verticalGap - size.height

        let screen = NSScreen.screens.first(where: { $0.frame.intersects(buttonFrameOnScreen) }) ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            let minX = visible.minX + Self.screenMargin
            let maxX = visible.maxX - size.width - Self.screenMargin
            if minX <= maxX {
                originX = min(max(originX, minX), maxX)
            }
        }

        panel.setFrame(
            CGRect(x: originX, y: originY, width: size.width, height: size.height),
            display: true
        )

        let baseCenterLocal = buttonFrameOnScreen.midX - originX
        hosting.rootView = SnippetPreviewBadge(
            text: text,
            caption: caption,
            tail: defaultTail(baseCenter: baseCenterLocal)
        )
    }

    private func defaultTail(baseCenter: CGFloat) -> BubbleTail {
        BubbleTail(
            side: .top,
            baseCenter: baseCenter,
            baseHalfWidth: Self.tailHalfBase,
            length: Self.tailLength
        )
    }
}
