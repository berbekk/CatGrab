import AppKit
import SwiftUI

@MainActor
final class PermissionsOnboardingWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var onFinished: (() -> Void)?

    func present(onFinished: @escaping () -> Void) {
        self.onFinished = onFinished

        if window != nil {
            showFront()
            return
        }

        let localizer = LocalizationStore.shared
        let root = PermissionsOnboardingView { [weak self] in
            self?.closeAndFinish()
        }
        .environmentObject(localizer)

        let hosting = NSHostingView(rootView: root)
        let w = NSWindow(
            contentRect: NSRect(origin: .zero, size: hosting.fittingSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = localizer.text(.permissionsSidebarHeader)
        w.contentView = hosting
        w.setContentSize(hosting.fittingSize)
        w.isReleasedWhenClosed = false
        w.delegate = self
        w.center()
        w.level = .normal
        w.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]

        window = w
        showFront()

        // Как у остальных menu-bar приложений: системный запрос сразу при первом окне,
        // чтобы PieMenu уже стоял в списке «Универсальный доступ» к моменту, когда пользователь его откроет.
        DispatchQueue.main.asyncAfter(deadline: .now() + Timings.accessibilityPromptAfterOnboardingDelay) {
            if PermissionsSnapshot.current().accessibilityTrusted {
                PermissionsSnapshot.promptInputMonitoringIfNeeded()
            } else {
                PermissionsSnapshot.promptAccessibilityIfNeeded()
            }
        }
    }

    private func showFront() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }

    /// Доступ выдан в Системных настройках — окно закрывается само и возвращает пользователя в PieMenu.
    func finishBecausePermissionsGranted() {
        guard window != nil, onFinished != nil else { return }
        NSApp.activate(ignoringOtherApps: true)
        closeAndFinish()
    }

    private func closeAndFinish() {
        AppLaunchState.hasSeenPermissionIntro = true
        window?.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
        onFinished?()
        onFinished = nil
    }

    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === window else { return }
        AppLaunchState.hasSeenPermissionIntro = true
        NSApp.setActivationPolicy(.accessory)
        onFinished?()
        onFinished = nil
    }
}
