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

/// Пункт выпадающего меню; без действия — разделитель.
struct PullDownMenuEntry {
    let title: String
    let image: NSImage?
    let action: (() -> Void)?

    static func item(_ title: String, symbol: String, action: @escaping () -> Void) -> Self {
        Self(title: title, image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil), action: action)
    }

    static func item(_ title: String, image: NSImage?, action: @escaping () -> Void) -> Self {
        Self(title: title, image: image, action: action)
    }

    static let separator = Self(title: "", image: nil, action: nil)
}

struct TransparentNSMenuPullDown: NSViewRepresentable {
    var accessibilityLabel: String
    /// Пункты собираются в момент клика: список может зависеть от того, что запущено прямо сейчас.
    var makeEntries: () -> [PullDownMenuEntry]
    var onHover: (Bool) -> Void

    final class Coordinator: NSObject {
        var makeEntries: () -> [PullDownMenuEntry]
        private var shownEntries: [PullDownMenuEntry] = []

        init(makeEntries: @escaping () -> [PullDownMenuEntry]) {
            self.makeEntries = makeEntries
        }

        @objc func itemClicked(_ sender: NSMenuItem) {
            guard shownEntries.indices.contains(sender.tag) else { return }
            shownEntries[sender.tag].action?()
        }

        func buildMenu() -> NSMenu {
            shownEntries = makeEntries()
            let menu = NSMenu()
            for (idx, entry) in shownEntries.enumerated() {
                guard entry.action != nil else {
                    menu.addItem(.separator())
                    continue
                }
                let mi = NSMenuItem(title: entry.title, action: #selector(itemClicked(_:)), keyEquivalent: "")
                mi.target = self
                mi.tag = idx
                mi.image = entry.image
                menu.addItem(mi)
            }
            return menu
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(makeEntries: makeEntries)
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
        context.coordinator.makeEntries = makeEntries
        view.onHover = onHover
        view.setAccessibilityLabel(accessibilityLabel)
    }
}
