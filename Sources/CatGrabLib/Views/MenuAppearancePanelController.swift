import SwiftUI
import AppKit

final class MenuAppearancePanelController: NSObject, ObservableObject, NSWindowDelegate {
    @Published private(set) var isVisible = false

    private var panel: NSPanel?
    private weak var parentWindow: NSWindow?
    private var parentObservers: [NSObjectProtocol] = []
    private let panelWidth: CGFloat = 280
    private let panelGap: CGFloat = 14
    private let showAnimationOffset: CGFloat = 20

    deinit {
        close()
    }

    func setParentWindow(_ window: NSWindow?) {
        parentWindow = window
        syncPanelFrameWithParent()
    }

    func show(
        menu: Binding<PieMenu>,
        localizer: LocalizationStore,
        parentWindow: NSWindow?
    ) {
        guard let parentWindow else { return }
        close()
        self.parentWindow = parentWindow

        let rootView = MenuAppearanceControlsView(menu: menu) { [weak self] in
            self?.close()
        }
        .environmentObject(localizer)

        let hostingView = NSHostingView(rootView: rootView)

        let finalFrame = panelFrame(for: parentWindow)
        var initialFrame = finalFrame
        initialFrame.origin.x -= showAnimationOffset

        let panel = NSPanel(
            contentRect: initialFrame,
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isReleasedWhenClosed = false
        panel.isFloatingPanel = false
        panel.hidesOnDeactivate = false
        panel.hasShadow = false
        panel.backgroundColor = NSColor.windowBackgroundColor
        panel.contentView = hostingView
        panel.level = .normal
        panel.delegate = self
        panel.alphaValue = 1

        self.panel = panel
        observeParentWindow(parentWindow)
        parentWindow.addChildWindow(panel, ordered: .above)
        panel.orderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(finalFrame, display: true)
        }
        isVisible = true
    }

    func close() {
        removeParentObservers()
        if let panel, let parentWindow {
            parentWindow.removeChildWindow(panel)
        }
        panel?.orderOut(nil)
        panel?.delegate = nil
        panel = nil
        isVisible = false
    }

    func windowWillClose(_ notification: Notification) {
        if let closingWindow = notification.object as? NSWindow, closingWindow == panel {
            close()
        }
    }

    private func observeParentWindow(_ window: NSWindow) {
        removeParentObservers()

        let center = NotificationCenter.default
        parentObservers.append(center.addObserver(
            forName: NSWindow.didResizeNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.syncPanelFrameWithParent()
        })
        parentObservers.append(center.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.close()
        })
    }

    private func removeParentObservers() {
        let center = NotificationCenter.default
        parentObservers.forEach { center.removeObserver($0) }
        parentObservers.removeAll()
    }

    private func syncPanelFrameWithParent() {
        guard let panel, let parentWindow else { return }
        panel.setFrame(panelFrame(for: parentWindow), display: true, animate: false)
    }

    private func panelFrame(for parentWindow: NSWindow) -> NSRect {
        let frame = parentWindow.frame
        return NSRect(
            x: frame.maxX + panelGap,
            y: frame.minY,
            width: panelWidth,
            height: frame.height
        )
    }
}
