import AppKit
import Foundation

/// Служебный режим для скриншотов в README: `CATGRAB_SCREENSHOT_DIR=<папка>` — приложение само
/// открывает нужное окно, ждёт, пока оно нарисуется, снимает его через WindowServer и завершается.
/// Своё окно приложение может снять без разрешения «Запись экрана», поэтому снимки получаются
/// такими, какими их видит пользователь: со стеклом и настоящими иконками.
///
/// `CATGRAB_SCREENSHOT_TARGET`: `settings` (по умолчанию) или `onboarding`;
/// `CATGRAB_SCREENSHOT_MENU`: `main`, `runningApps` или `appCommands` — что выбрать в настройках;
/// `CATGRAB_SCREENSHOT_NAME`: имя файла без расширения (по умолчанию — цель).
enum ScreenshotMode {
    enum Target: String {
        case settings
        case onboarding
    }

    private static let environment = ProcessInfo.processInfo.environment

    static var outputDirectory: URL? {
        guard let path = environment["CATGRAB_SCREENSHOT_DIR"], !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    static var isEnabled: Bool { outputDirectory != nil }

    static var target: Target {
        environment["CATGRAB_SCREENSHOT_TARGET"].flatMap(Target.init(rawValue:)) ?? .settings
    }

    static var fileName: String {
        environment["CATGRAB_SCREENSHOT_NAME"] ?? target.rawValue
    }

    /// Какое меню открыть в настройках; `nil` — первое в списке.
    static func initialMenu(in configuration: PieConfiguration) -> PieMenu? {
        switch environment["CATGRAB_SCREENSHOT_MENU"] {
        case "runningApps": return configuration.menus.first(where: \.isRunningAppsMenu)
        case "appCommands": return configuration.menus.first(where: \.isAppCommandsMenu)
        case "main": return PieMenu.mainTemplateMenu(from: configuration.menus)
        default: return nil
        }
    }

    /// Сколько ждать до снимка: иконки, стекло и превью должны успеть нарисоваться.
    static let settleDelay: TimeInterval = 2.5

    /// Снимок окна в его нативном разрешении (на Retina — 2×), без тени.
    @MainActor
    @discardableResult
    static func capture(window: NSWindow) -> Bool {
        guard let directory = outputDirectory else { return false }
        let windowID = CGWindowID(window.windowNumber)
        guard let image = CGWindowListCreateImage(.null, .optionIncludingWindow, windowID, [.boundsIgnoreFraming, .bestResolution]) else {
            PieLog.ui.error("screenshot: window image unavailable")
            return false
        }
        let rep = NSBitmapImageRep(cgImage: image)
        guard let png = rep.representation(using: .png, properties: [:]) else { return false }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("\(fileName).png")
            try png.write(to: url)
            PieLog.ui.notice("screenshot saved: \(url.path, privacy: .public)")
            return true
        } catch {
            PieLog.ui.error("screenshot failed: \(String(describing: error), privacy: .public)")
            return false
        }
    }
}
