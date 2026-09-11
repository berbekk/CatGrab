import AppKit
import SwiftUI

/// Прозрачная область: по клику показывает `NSMenu` через `popUpContextMenu` (стабильно внутри SwiftUI).
private final class PullDownMenuHostView: NSView {
    var menuProvider: (() -> NSMenu)?
    var onHover: ((Bool) -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: DS.Sizing.sidebarRowMinHeight)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        let options: NSTrackingArea.Options = [.activeAlways, .mouseEnteredAndExited, .inVisibleRect]
        addTrackingArea(NSTrackingArea(rect: .zero, options: options, owner: self, userInfo: nil))
    }

    override func mouseDown(with event: NSEvent) {
        guard let menuProvider else { return }
        let menu = menuProvider()
        applyStableMenuAppearance(menu)
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    override func mouseEntered(with event: NSEvent) {
        onHover?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHover?(false)
    }

    private func applyStableMenuAppearance(_ menu: NSMenu) {
        // Контекстное меню в прозрачном хосте может терять контраст на светлом фоне.
        let sourceAppearance = window?.effectiveAppearance ?? effectiveAppearance
        let menuAppearanceName: NSAppearance.Name = sourceAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? .darkAqua
            : .aqua
        menu.appearance = NSAppearance(named: menuAppearanceName)
    }
}

struct TransparentNSMenuPullDown: NSViewRepresentable {
    var accessibilityLabel: String
    var menuItems: [(title: String, symbol: String, action: () -> Void)]
    var onHover: (Bool) -> Void

    final class Coordinator: NSObject {
        var menuItems: [(title: String, symbol: String, action: () -> Void)]

        init(menuItems: [(title: String, symbol: String, action: () -> Void)]) {
            self.menuItems = menuItems
        }

        @objc func itemClicked(_ sender: NSMenuItem) {
            let i = sender.tag
            guard menuItems.indices.contains(i) else { return }
            menuItems[i].action()
        }

        func buildMenu() -> NSMenu {
            let menu = NSMenu()
            for (idx, item) in menuItems.enumerated() {
                if item.symbol == "app.badge.fill" {
                    menu.addItem(.separator())
                }
                let mi = NSMenuItem(
                    title: item.title,
                    action: #selector(itemClicked(_:)),
                    keyEquivalent: ""
                )
                mi.target = self
                mi.tag = idx
                if let img = NSImage(systemSymbolName: item.symbol, accessibilityDescription: nil) {
                    mi.image = img
                }
                menu.addItem(mi)
            }
            return menu
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(menuItems: menuItems)
    }

    func makeNSView(context: Context) -> NSView {
        let view = PullDownMenuHostView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        let coordinator = context.coordinator
        view.menuProvider = { [weak coordinator] in
            coordinator?.buildMenu() ?? NSMenu()
        }
        view.onHover = onHover
        view.setAccessibilityElement(true)
        view.setAccessibilityRole(.button)
        view.setAccessibilityLabel(accessibilityLabel)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? PullDownMenuHostView else { return }
        context.coordinator.menuItems = menuItems
        let coordinator = context.coordinator
        view.menuProvider = { [weak coordinator] in
            coordinator?.buildMenu() ?? NSMenu()
        }
        view.onHover = onHover
        view.setAccessibilityLabel(accessibilityLabel)
    }
}
