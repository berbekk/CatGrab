import AppKit
import SwiftUI

/// Окно знакомства: тур по меню с живым кольцом, права в конце. Закрыть можно в любой момент —
/// это считается пройденным туром; про права напомнит страница прав при следующем запуске,
/// если в конфиге есть сочетания, которые без них не работают.
@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    let model: OnboardingModel
    private var onClosed: (() -> Void)?

    init(startPage: OnboardingPage) {
        model = OnboardingModel(startPage: startPage)
        super.init()
    }

    var isVisible: Bool { window?.isVisible ?? false }

    func present(onClosed: @escaping () -> Void) {
        // Окно уже открыто — только вывести вперёд; обработчик закрытия остаётся прежним.
        if window != nil {
            showFront()
            return
        }
        self.onClosed = onClosed

        let localizer = LocalizationStore.shared
        let root = OnboardingView(model: model)
            .environmentObject(localizer)
        let hosting = NSHostingView(rootView: root)
        let w = NSWindow(
            contentRect: NSRect(origin: .zero, size: OnboardingView.windowSize),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        w.title = localizer.text(.permissionsWelcomeTitle)
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.contentView = hosting
        w.setContentSize(OnboardingView.windowSize)
        w.isReleasedWhenClosed = false
        w.isMovableByWindowBackground = true
        w.delegate = self
        w.center()
        w.level = .normal
        w.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]

        window = w
        showFront()
    }

    private func showFront() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }

    /// Права выдали в Системных настройках — возвращаем человека в тур, на последнюю страницу.
    func permissionsGranted() {
        guard window != nil else { return }
        model.permissionsGranted()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func close() {
        guard let window else { return }
        model.flushPendingSave()
        window.delegate = nil
        window.orderOut(nil)
        self.window = nil
        NSApp.setActivationPolicy(.accessory)
        onClosed?()
        onClosed = nil
    }

    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === window else { return }
        model.flushPendingSave()
        window = nil
        NSApp.setActivationPolicy(.accessory)
        onClosed?()
        onClosed = nil
    }
}
