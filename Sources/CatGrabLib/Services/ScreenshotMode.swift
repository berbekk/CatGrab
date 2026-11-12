import AppKit
import Foundation

/// Служебный режим для скриншотов в README: `CATGRAB_SCREENSHOT_DIR=<папка>` — приложение само
/// открывает нужное окно, ждёт, пока оно нарисуется, снимает его через WindowServer и завершается.
/// Своё окно приложение может снять без разрешения «Запись экрана», поэтому снимки получаются
/// такими, какими их видит пользователь: со стеклом и настоящими иконками.
///
/// `CATGRAB_SCREENSHOT_TARGET`: `settings` (по умолчанию), `onboarding` или `pie`;
/// `CATGRAB_SCREENSHOT_MENU`: `main`, `runningApps` или `appCommands` — что выбрать в настройках;
/// `CATGRAB_SCREENSHOT_PANE`: `general` — общие настройки, `app:<bundle id>` — набор команд приложения;
/// `CATGRAB_SCREENSHOT_PANEL`: `appearance` — открыть «Параметры», `item` — инспектор первого сектора;
/// `CATGRAB_SCREENSHOT_SIZE`: размер окна настроек, например `880x580`;
/// `CATGRAB_SCREENSHOT_NAME`: имя файла без расширения (по умолчанию — цель);
/// `CATGRAB_SCREENSHOT_ACTIVATE=1`: сделать окно активным (цветные переключатели и кнопки окна) —
/// для снимков в README. Без этого окно показывается, не отбирая фокус у того, с чем вы работаете.
///
/// В этом режиме приложение не регистрирует сочетания, не слушает трекпад и не трогает системный
/// ⌘Tab: снимки можно делать, пока рядом работает установленный CatGrab.
enum ScreenshotMode {
    enum Target: String {
        case settings
        case onboarding
        /// Само кольцо поверх фона-«обоев»: `CATGRAB_SCREENSHOT_MENU` — какое меню (`main`,
        /// `runningApps`), `CATGRAB_SCREENSHOT_HIGHLIGHT` — номер выделенного сектора с нуля,
        /// `CATGRAB_SCREENSHOT_BACKDROP` — своя картинка фона, `CATGRAB_SCREENSHOT_SIZE` — размер кадра.
        case pie
    }

    private static let environment = ProcessInfo.processInfo.environment

    static var outputDirectory: URL? {
        guard let path = environment["CATGRAB_SCREENSHOT_DIR"], !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    static var isEnabled: Bool { outputDirectory != nil }

    /// Показать окно, не активируя приложение: снимок не должен отбирать фокус.
    static var showsWithoutActivating: Bool {
        isEnabled && environment["CATGRAB_SCREENSHOT_ACTIVATE"] != "1"
    }

    static var target: Target {
        environment["CATGRAB_SCREENSHOT_TARGET"].flatMap(Target.init(rawValue:)) ?? .settings
    }

    static var fileName: String {
        environment["CATGRAB_SCREENSHOT_NAME"] ?? target.rawValue
    }

    /// Страница знакомства для снимка (`CATGRAB_SCREENSHOT_PAGE`, номер с нуля); по умолчанию первая.
    static var onboardingPage: OnboardingPage {
        environment["CATGRAB_SCREENSHOT_PAGE"].flatMap(Int.init).flatMap(OnboardingPage.init(rawValue:)) ?? .welcome
    }

    enum Pane: Equatable {
        case general
        case app(bundleIdentifier: String)
    }

    /// Что открыть в настройках вместо меню; `nil` — меню из `CATGRAB_SCREENSHOT_MENU`.
    static var pane: Pane? {
        guard isEnabled, let raw = environment["CATGRAB_SCREENSHOT_PANE"] else { return nil }
        if raw == "general" { return .general }
        if raw.hasPrefix("app:") { return .app(bundleIdentifier: String(raw.dropFirst(4))) }
        return nil
    }

    enum Panel: String {
        case appearance
        case item
    }

    /// Какую выезжающую панель открыть поверх сайдбара.
    static var panel: Panel? {
        guard isEnabled else { return nil }
        return environment["CATGRAB_SCREENSHOT_PANEL"].flatMap(Panel.init(rawValue:))
    }

    /// `CATGRAB_SCREENSHOT_UPDATE=1.9.0` — показать интерфейс так, будто вышла эта версия.
    static var simulatedUpdateVersion: String? {
        guard isEnabled else { return nil }
        return environment["CATGRAB_SCREENSHOT_UPDATE"]
    }

    /// Размер содержимого окна настроек для снимка; `nil` — обычный.
    static var windowSize: NSSize? {
        guard isEnabled, let raw = environment["CATGRAB_SCREENSHOT_SIZE"] else { return nil }
        let parts = raw.lowercased().split(separator: "x").compactMap { Double($0) }
        guard parts.count == 2, parts[0] > 0, parts[1] > 0 else { return nil }
        return NSSize(width: parts[0], height: parts[1])
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
    /// `CATGRAB_SCREENSHOT_DELAY` — своё время в секундах, чтобы поймать нужный момент анимации.
    static var settleDelay: TimeInterval {
        environment["CATGRAB_SCREENSHOT_DELAY"].flatMap(Double.init) ?? 2.5
    }

    /// Какой сектор выделить на снимке кольца; по умолчанию — второй.
    static var highlightedSector: Int? {
        guard let raw = environment["CATGRAB_SCREENSHOT_HIGHLIGHT"] else { return 1 }
        return Int(raw)
    }

    /// Своя картинка фона для снимка кольца; `nil` — нарисованный градиент.
    static var backdropImage: NSImage? {
        environment["CATGRAB_SCREENSHOT_BACKDROP"].flatMap { NSImage(contentsOfFile: $0) }
    }

    /// Снимок области экрана, собранный только из своих окон (фон и кольцо): чужие окна и рабочий
    /// стол в кадр не попадают, разрешение «Запись экрана» не нужно. `windows` — от верхнего к нижнему.
    @MainActor
    @discardableResult
    static func capture(windows: [NSWindow], frame: NSRect) -> Bool {
        guard let primaryHeight = NSScreen.screens.first?.frame.height else { return false }
        let bounds = CGRect(x: frame.minX, y: primaryHeight - frame.maxY, width: frame.width, height: frame.height)
        // Список окон для WindowServer — массив самих номеров окон (как указателей), а не `CFNumber`.
        var ids: [UnsafeRawPointer?] = windows.map { UnsafeRawPointer(bitPattern: UInt($0.windowNumber)) }
        guard let array = CFArrayCreate(kCFAllocatorDefault, &ids, ids.count, nil),
              let image = CGImage(windowListFromArrayScreenBounds: bounds, windowArray: array, imageOption: [.bestResolution]) else {
            PieLog.ui.error("screenshot: composite image unavailable")
            return false
        }
        return write(image)
    }

    /// Снимок окна в его нативном разрешении (на Retina — 2×), без тени.
    @MainActor
    @discardableResult
    static func capture(window: NSWindow) -> Bool {
        let windowID = CGWindowID(window.windowNumber)
        guard let image = CGWindowListCreateImage(.null, .optionIncludingWindow, windowID, [.boundsIgnoreFraming, .bestResolution]) else {
            PieLog.ui.error("screenshot: window image unavailable")
            return false
        }
        return write(image)
    }

    private static func write(_ image: CGImage) -> Bool {
        guard let directory = outputDirectory else { return false }
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
