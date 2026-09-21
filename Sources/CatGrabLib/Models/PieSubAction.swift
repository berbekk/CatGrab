import ApplicationServices
import Foundation

/// Куда положить окно: половина экрана или весь экран без перехода в полноэкранный режим.
enum WindowTile: Equatable {
    case left
    case right
    case top
    case bottom
    case fill
    /// По центру рабочей области, размер окна не меняется.
    case center
}

/// Команда в меню «Команды приложения»: пункт из меню самого приложения или управление его окном.
/// В конфиге не хранится — собирается при показе из того, что умеет активное приложение.
struct PieSubAction: Identifiable, Equatable {
    enum Kind: Equatable {
        /// Пункт из строки меню приложения (например, «Новое окно»), нажимается через Accessibility.
        case menuCommand(AppMenuCommand)
        case closeWindow(AXUIElement)
        case minimizeWindow(AXUIElement)
        case toggleFullScreen(AXUIElement)
        case tileWindow(AXUIElement, WindowTile)
        case hideApp
        case quitApp
        /// Команда из своего набора, которая сейчас недоступна: нет окна, пункт выключен или пропал из меню.
        /// Сектор остаётся на месте приглушённым, чтобы остальные не сдвигались.
        case unavailable

        static func == (lhs: Kind, rhs: Kind) -> Bool {
            switch (lhs, rhs) {
            case let (.menuCommand(a), .menuCommand(b)): return a == b
            case let (.closeWindow(a), .closeWindow(b)),
                 let (.minimizeWindow(a), .minimizeWindow(b)),
                 let (.toggleFullScreen(a), .toggleFullScreen(b)):
                return CFEqual(a, b)
            case let (.tileWindow(a, tileA), .tileWindow(b, tileB)):
                return tileA == tileB && CFEqual(a, b)
            case (.hideApp, .hideApp), (.quitApp, .quitApp), (.unavailable, .unavailable): return true
            default: return false
            }
        }
    }

    let id: String
    let title: String
    let icon: String
    /// Сочетание клавиш для подписи (`⇧⌘N`); `nil` — не показывать.
    let shortcut: String?
    let isDestructive: Bool
    let kind: Kind
    let pid: pid_t

    var isEnabled: Bool { kind != .unavailable }
}

/// Что выполнить при выборе: пункт обычного меню или команду приложения.
enum PieMenuSelection {
    case item(PieMenuItem)
    case subAction(PieSubAction)
}
