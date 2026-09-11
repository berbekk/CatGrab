import Foundation

/// Действия из «Системные настройки → Клавиатура → Сочетания клавиш → Функции клавиатуры».
enum MacOSSystemActionKind: String, Codable, CaseIterable, Identifiable {
    case missionControl
    case applicationWindows
    case quickNote
    case startScreenSaver
    case displaySleep
    case lockScreen

    var id: String { rawValue }

    /// Действия, которые можно выполнить в App Sandbox через NSWorkspace.
    var isAvailableInAppStore: Bool {
        switch self {
        case .missionControl, .startScreenSaver:
            return true
        case .applicationWindows, .quickNote, .displaySleep, .lockScreen:
            return false
        }
    }

    static var appStoreCases: [MacOSSystemActionKind] {
        allCases.filter(\.isAvailableInAppStore)
    }

    // Forward-compat: незнакомое значение `rawValue` из будущей версии приложения при декоде
    // не должно рушить весь `PieConfiguration`. В `MenuAction.init(from:)` такой случай уже маппится на `.unassigned`,
    // здесь дополнительно гарантируем, что именно декод enum не бросает при отсутствующем кейсе — оставляем
    // стандартное поведение (бросает `DataCorruptedError`), а обработку делает вызывающий код.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let kind = MacOSSystemActionKind(rawValue: raw) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown MacOSSystemActionKind: \(raw)"
            )
        }
        self = kind
    }

    /// Ключи в `AppleSymbolicHotKeys` (пробуем по порядку, пока не найдётся включённая запись).
    var symbolicHotKeyPreferenceKeys: [String] {
        switch self {
        case .missionControl:
            return ["32"]
        case .applicationWindows:
            return ["33", "34"]
        case .quickNote:
            return ["190", "191", "200", "201"]
        case .startScreenSaver, .displaySleep, .lockScreen:
            return []
        }
    }

    /// Резерв, если в plist отключено или нет параметров: виртуальный код и модификаторы в формате AppleSymbolicHotkeys (биты 17–20, 23).
    var fallbackAppleSymbolicKeyAndModifiers: (keyCode: Int, modifiers: Int)? {
        switch self {
        case .missionControl:
            return (126, 1 << 18)
        case .applicationWindows:
            return (125, 1 << 18)
        case .quickNote:
            return (12, 1 << 23)
        case .startScreenSaver, .displaySleep, .lockScreen:
            return nil
        }
    }

    var defaultSFSymbol: String {
        switch self {
        case .missionControl: return "square.grid.3x3.fill"
        case .applicationWindows: return "rectangle.on.rectangle.angled"
        case .quickNote: return "note.text"
        case .startScreenSaver: return "sparkles.tv"
        case .displaySleep: return "display.and.arrow.down"
        case .lockScreen: return "lock.fill"
        }
    }

    func displayName(language: AppLanguage) -> String {
        switch language {
        case .russian:
            switch self {
            case .missionControl: return "Mission Control"
            case .applicationWindows: return "Окна программы"
            case .quickNote: return "Быстрая заметка"
            case .startScreenSaver: return "Включить заставку"
            case .displaySleep: return "Перевести дисплей в сон"
            case .lockScreen: return "Заблокировать экран"
            }
        default:
            switch self {
            case .missionControl: return "Mission Control"
            case .applicationWindows: return "Application Windows"
            case .quickNote: return "Quick Note"
            case .startScreenSaver: return "Start Screen Saver"
            case .displaySleep: return "Put Display to Sleep"
            case .lockScreen: return "Lock Screen"
            }
        }
    }
}
