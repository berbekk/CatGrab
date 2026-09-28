import AppKit

/// Исполняет действия пунктов пирога.
struct AppLauncher {
    static func execute(item: PieMenuItem, targetPID: pid_t? = nil) {
        switch item.action {
        case .unassigned:
            return
        case .keystroke(let keyCode, let modifiers):
            KeystrokeSender.perform(keyCode: keyCode, modifiers: modifiers, targetPID: targetPID)
        case .launchApp(let bundleIdentifier):
            launchApp(bundleIdentifier: bundleIdentifier)
        case .openURL(let urlString):
            openURL(urlString)
        case .systemShortcut(let kind):
            MacOSSystemActionRunner.perform(kind)
        case .snippet(let text):
            SnippetInserter.perform(text: text, targetPID: targetPID)
        }
    }

    private static func launchApp(bundleIdentifier: String) {
        // Приложение и так впереди — выбор сектора показывает его следующее окно, как ⌘`.
        if let running = runningApplication(bundleIdentifier: bundleIdentifier),
           NSWorkspace.shared.frontmostApplication?.processIdentifier == running.processIdentifier,
           AXIsProcessTrusted() {
            cycleWindows(of: running, bundleIdentifier: bundleIdentifier)
            return
        }
        // Уже запущенное приложение переключаем через WindowServer: Launch Services из фонового CatGrab
        // активирует его, но не переходит в пространство, где оно открыто (например, во весь экран).
        if let running = runningApplication(bundleIdentifier: bundleIdentifier),
           RunningAppFocus.focus(running) {
            return
        }
        // Не запущено или нет ни одного окна — обычный запуск; для открытого приложения без окон
        // он же просит его создать новое окно.
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: .init())
    }

    /// Окна читаются по Accessibility не на главном потоке. Окон нет вовсе — обычный запуск:
    /// открытое приложение без окон в ответ открывает новое, как по щелчку в Dock.
    private static func cycleWindows(of app: NSRunningApplication, bundleIdentifier: String) {
        let pid = app.processIdentifier
        WindowCycler.queue.async {
            let outcome = WindowCycler.cycle(pid: pid)
            PieLog.launcher.debug("window cycle \(bundleIdentifier, privacy: .public): \(String(describing: outcome), privacy: .public)")
            guard outcome == .noWindows else { return }
            DispatchQueue.main.async {
                guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else { return }
                NSWorkspace.shared.openApplication(at: url, configuration: .init())
            }
        }
    }

    private static func runningApplication(bundleIdentifier: String) -> NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .first { $0.activationPolicy == .regular && !$0.isTerminated }
    }

    private static func openURL(_ urlString: String) {
        guard let url = URLNormalizer.url(from: urlString) else {
            PieLog.launcher.error("open url: not a valid address")
            return
        }
        NSWorkspace.shared.open(url)
    }
}
