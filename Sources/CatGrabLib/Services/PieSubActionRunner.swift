import AppKit
@preconcurrency import ApplicationServices

/// Выполняет команду из меню «Команды приложения».
///
/// Команды меню и полноэкранный режим — про работу в приложении, поэтому сначала выводим его вперёд.
/// Закрыть, свернуть, скрыть и завершить — «уборка»: приложение трогаем, не переключаясь на него,
/// и возвращаем фокус туда, где пользователь был до меню.
@MainActor
enum PieSubActionRunner {
    static func perform(_ action: PieSubAction, previousApp: NSRunningApplication?) {
        guard let app = NSRunningApplication(processIdentifier: action.pid), !app.isTerminated else {
            PieLog.launcher.notice("sub-action \(action.id, privacy: .public): app is gone")
            previousApp?.activate()
            return
        }
        let bundleID = app.bundleIdentifier ?? "?"
        PieLog.launcher.notice("sub-action \(action.id, privacy: .public) for \(bundleID, privacy: .public)")

        switch action.kind {
        case .menuCommand(let command):
            bringToFront(app)
            FrontmostAppWaiter.wait(for: app.processIdentifier) {
                PieSubActionResolver.queue.async {
                    press(command, pid: app.processIdentifier)
                }
            }
        case .toggleFullScreen(let window):
            bringToFront(app)
            FrontmostAppWaiter.wait(for: app.processIdentifier) {
                PieSubActionResolver.queue.async {
                    WindowAX.toggleFullScreen(window)
                }
            }
        case .tileWindow(let window, let tile):
            bringToFront(app)
            let screens = workAreas()
            PieSubActionResolver.queue.async {
                WindowAX.tile(window, tile, screens: screens)
            }
        case .closeWindow(let window):
            returnFocus(to: previousApp, leaving: app)
            PieSubActionResolver.queue.async { WindowAX.close(window) }
        case .minimizeWindow(let window):
            returnFocus(to: previousApp, leaving: app)
            PieSubActionResolver.queue.async { WindowAX.minimize(window) }
        case .hideApp:
            app.hide()
            returnFocus(to: previousApp, leaving: app)
        case .quitApp:
            app.terminate()
            returnFocus(to: previousApp, leaving: app)
        case .unavailable:
            returnFocus(to: previousApp, leaving: app)
        }
    }

    /// Рабочие области экранов (без строки меню и Dock) в координатах Accessibility.
    private static func workAreas() -> [CGRect] {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return NSScreen.screens.map { WindowAX.accessibilityFrame($0.visibleFrame, primaryScreenHeight: primaryHeight) }
    }

    private static func bringToFront(_ app: NSRunningApplication) {
        if !RunningAppFocus.focus(app) {
            app.activate()
        }
    }

    /// Если пользователь был в том же приложении, которое прячем или завершаем, macOS сама выберет следующее.
    private static func returnFocus(to previousApp: NSRunningApplication?, leaving app: NSRunningApplication) {
        guard let previousApp, previousApp.processIdentifier != app.processIdentifier else { return }
        previousApp.activate()
    }

    /// Вызывать на `PieSubActionResolver.queue`. Элемент меню мог устареть, если приложение пересобрало
    /// меню после чтения, — тогда ищем пункт заново по пути, а затем по сочетанию.
    private nonisolated static func press(_ command: AppMenuCommand, pid: pid_t) {
        AXUIElementSetMessagingTimeout(command.element, AppMenuCommandReader.messagingTimeout)
        let result = AXUIElementPerformAction(command.element, kAXPressAction as CFString)
        // `cannotComplete` — приложение не ответило за таймаут (например, открыло модальный диалог),
        // но команду уже получило: повторять нельзя, иначе она выполнится дважды.
        if result == .success || result == .cannotComplete { return }
        guard let fresh = AppMenuCommandReader.item(pid: pid, path: command.path, shortcut: command.shortcut) else {
            PieLog.launcher.error("sub-action: menu item \(command.path.joined(separator: " › "), privacy: .public) not found")
            return
        }
        AXUIElementSetMessagingTimeout(fresh.element, AppMenuCommandReader.messagingTimeout)
        _ = AXUIElementPerformAction(fresh.element, kAXPressAction as CFString)
    }
}
