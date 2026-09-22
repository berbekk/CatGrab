import AppKit
import Foundation
import CoreGraphics

struct PieMenuItem: Codable, Identifiable, Equatable {
    var id: UUID
    var title: String
    var icon: String
    var action: MenuAction
    /// Свой цвет сектора — действует, только когда `usesThemeColor == false`.
    var color: String
    /// Цвет берётся из темы меню по месту сектора в кольце (см. `PieMenu.themed`).
    var usesThemeColor: Bool
    var iconColor: String?
    var sectorIndex: Int
    /// Пользовательская горячая буква/цифра для выбора пункта при открытом меню.
    /// Нормализована к одному символу верхнего регистра (A–Z или 0–9); `nil` — используется автоматическая.
    var customShortcut: String?

    static let sectorPalette: [String] = [
        "#007AFF", "#28CD41", "#5AC8FA", "#8E8E93",
        "#FF2D55", "#FFCC00", "#AF52DE", "#FF9500"
    ]

    static let minItemCount = 3

    /// Прежняя общая иконка пустого пункта. Нужна только миграции, чтобы узнать и заменить её в старых конфигах.
    static let legacyUnassignedSFSymbol = "cat.fill"

    /// Из чего выбирается случайная иконка пустого пункта. Набор ручной, а не весь каталог SF Symbols:
    /// там полно символов, которые выглядят как действие или предупреждение (корзина, замок, «!»),
    /// и на пустом секторе они вводили бы в заблуждение. Все символы есть начиная с macOS 13.
    static let unassignedSymbolPool: [String] = [
        "star.fill", "heart.fill", "bolt.fill", "leaf.fill", "flame.fill", "drop.fill",
        "moon.fill", "sun.max.fill", "cloud.fill", "snowflake", "sparkles", "wand.and.stars",
        "paintbrush.fill", "paintpalette.fill", "pencil", "bookmark.fill", "tag.fill", "flag.fill",
        "bell.fill", "gift.fill", "crown.fill", "puzzlepiece.fill", "gamecontroller.fill",
        "headphones", "music.note", "camera.fill", "paperplane.fill", "tortoise.fill", "hare.fill",
        "ant.fill", "ladybug.fill", "globe", "lightbulb.fill", "cube.fill", "atom", "book.fill",
        "graduationcap.fill", "cup.and.saucer.fill", "airplane", "car.fill", "bicycle", "house.fill",
        "mountain.2.fill", "binoculars.fill", "theatermasks.fill", "die.face.5.fill",
        "guitars.fill", "film.fill", "tram.fill"
    ]

    /// Случайная иконка для пункта «не назначено». Выбирается один раз при создании пункта
    /// (или при сбросе действия) и сохраняется в конфиг, чтобы сектор не менял вид при каждом открытии.
    /// `avoiding` — иконки, уже занятые в этом меню: по возможности соседи не повторяются.
    static func randomUnassignedSymbol<G: RandomNumberGenerator>(
        avoiding used: Set<String> = [],
        using generator: inout G
    ) -> String {
        let fresh = unassignedSymbolPool.filter { !used.contains($0) }
        let candidates = fresh.isEmpty ? unassignedSymbolPool : fresh
        return candidates.randomElement(using: &generator) ?? "star.fill"
    }

    static func randomUnassignedSymbol(avoiding used: Set<String> = []) -> String {
        var generator = SystemRandomNumberGenerator()
        return randomUnassignedSymbol(avoiding: used, using: &generator)
    }

    /// Иконку можно перекрасить: символ SF Symbols или текст. Иконки приложений, картинки и эмодзи
    /// рисуются своими цветами.
    var hasTintableIcon: Bool {
        if action.bundleIdentifier != nil || icon.isEmpty || icon.hasPrefix("app:") || icon.hasPrefix("file:") {
            return false
        }
        return icon.hasPrefix("text:") || icon.allSatisfy(\.isASCII)
    }

    static func paletteColor(for index: Int) -> String {
        sectorPalette[index % sectorPalette.count]
    }

    /// Приводит произвольную строку к валидному значению `customShortcut`:
    /// один символ A–Z или 0–9 в верхнем регистре, иначе `nil`.
    static func normalizedCustomShortcut(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let scalar = trimmed.unicodeScalars.first,
              trimmed.unicodeScalars.count == 1 else { return nil }
        let upper = Character(scalar).uppercased()
        guard upper.count == 1, let ch = upper.first else { return nil }
        if ch.isLetter && ch.isASCII { return String(ch) }
        if ch.isNumber && ch.isASCII { return String(ch) }
        return nil
    }

    init(
        id: UUID = UUID(),
        title: String,
        icon: String,
        action: MenuAction,
        color: String = "#007AFF",
        usesThemeColor: Bool = true,
        iconColor: String? = nil,
        sectorIndex: Int = 0,
        customShortcut: String? = nil
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.action = action
        self.color = color
        self.usesThemeColor = usesThemeColor
        self.iconColor = iconColor
        self.sectorIndex = sectorIndex
        self.customShortcut = PieMenuItem.normalizedCustomShortcut(customShortcut)
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, icon, action, color, usesThemeColor, iconColor, sectorIndex, customShortcut
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Старые или вручную отредактированные конфиги могут не содержать `id` — генерим новый.
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? ""
        action = try container.decodeIfPresent(MenuAction.self, forKey: .action) ?? .unassigned
        color = try container.decodeIfPresent(String.self, forKey: .color) ?? PieMenuItem.paletteColor(for: 0)
        iconColor = try container.decodeIfPresent(String.self, forKey: .iconColor)
        sectorIndex = try container.decodeIfPresent(Int.self, forKey: .sectorIndex) ?? 0
        // До тем у каждого сектора был свой цвет. Цвет «по умолчанию для своего места» считаем цветом
        // темы — тема «Классика» даёт ровно его, и кольцо после обновления выглядит как раньше.
        usesThemeColor = try container.decodeIfPresent(Bool.self, forKey: .usesThemeColor)
            ?? (color.caseInsensitiveCompare(PieMenuItem.paletteColor(for: sectorIndex)) == .orderedSame)
        // Старый системный пикер цвета иконки записывал цвет сам — почти тот же, что у сектора, — и такая
        // иконка переставала следовать теме («Белые» её не красили). Похожий на цвет сектора цвет снимаем:
        // в цвет сектора иконку и так красит тема.
        if let iconHex = iconColor, HexColor.isClose(iconHex, color) {
            iconColor = nil
        }
        customShortcut = PieMenuItem.normalizedCustomShortcut(
            try container.decodeIfPresent(String.self, forKey: .customShortcut)
        )
    }
}

enum MenuAction: Codable, Equatable {
    case unassigned
    case launchApp(bundleIdentifier: String)
    case openURL(url: String)
    case keystroke(keyCode: Int, modifiers: Int)
    case systemShortcut(MacOSSystemActionKind)
    case snippet(text: String)

    var bundleIdentifier: String? {
        if case .launchApp(let id) = self { return id }
        return nil
    }

    /// Действие заполнено: выбрано приложение, есть ссылка или текст.
    var isConfigured: Bool {
        switch self {
        case .unassigned: return false
        case .launchApp(let id): return !id.isEmpty
        case .openURL(let url): return !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .snippet(let text): return !text.isEmpty
        case .keystroke, .systemShortcut: return true
        }
    }

    /// Действие адресовано приложению, из которого открыли меню (нажатие, сниппет), — перед ним
    /// нужно вернуть этому приложению фокус.
    var needsPreviousAppFocus: Bool {
        switch self {
        case .unassigned, .keystroke, .snippet: return true
        case .launchApp, .openURL, .systemShortcut: return false
        }
    }

    /// Удалённые системные действия в старых конфигах декодируются как «не назначено».
    private static let removedSystemShortcutRawValues: Set<String> = [
        "showDesktop", "notificationCenter", "launchpad", "stopScreenSaver"
    ]

    private enum CodingKeys: String, CodingKey {
        case unassigned, launchApp, openURL, keystroke, systemShortcut, snippet
    }

    private enum LaunchAppKeys: String, CodingKey { case bundleIdentifier }
    private enum OpenURLKeys: String, CodingKey { case url }
    private enum KeystrokeKeys: String, CodingKey { case keyCode, modifiers }
    private enum SystemShortcutNestedKeys: String, CodingKey { case _0 }
    private enum SnippetKeys: String, CodingKey { case text }
    private struct Empty: Codable {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if c.contains(.unassigned) {
            _ = try c.decode(Empty.self, forKey: .unassigned)
            self = .unassigned
        } else if c.contains(.launchApp) {
            let nested = try c.nestedContainer(keyedBy: LaunchAppKeys.self, forKey: .launchApp)
            let bid = try nested.decode(String.self, forKey: .bundleIdentifier)
            self = .launchApp(bundleIdentifier: bid)
        } else if c.contains(.openURL) {
            let nested = try c.nestedContainer(keyedBy: OpenURLKeys.self, forKey: .openURL)
            let url = try nested.decode(String.self, forKey: .url)
            self = .openURL(url: url)
        } else if c.contains(.keystroke) {
            let nested = try c.nestedContainer(keyedBy: KeystrokeKeys.self, forKey: .keystroke)
            let kc = try nested.decode(Int.self, forKey: .keyCode)
            let mods = try nested.decode(Int.self, forKey: .modifiers)
            self = .keystroke(keyCode: kc, modifiers: mods)
        } else if c.contains(.systemShortcut) {
            let nested = try c.nestedContainer(keyedBy: SystemShortcutNestedKeys.self, forKey: .systemShortcut)
            let raw = try nested.decode(String.self, forKey: ._0)
            if Self.removedSystemShortcutRawValues.contains(raw) {
                self = .unassigned
            } else if let k = MacOSSystemActionKind(rawValue: raw) {
                self = .systemShortcut(k)
            } else {
                self = .unassigned
            }
        } else if c.contains(.snippet) {
            let nested = try c.nestedContainer(keyedBy: SnippetKeys.self, forKey: .snippet)
            let text = try nested.decodeIfPresent(String.self, forKey: .text) ?? ""
            self = .snippet(text: text)
        } else {
            // Неизвестный тип действия из будущих версий приложения не должен ронять весь конфиг.
            self = .unassigned
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .unassigned:
            try c.encode(Empty(), forKey: .unassigned)
        case .launchApp(let bid):
            var nested = c.nestedContainer(keyedBy: LaunchAppKeys.self, forKey: .launchApp)
            try nested.encode(bid, forKey: .bundleIdentifier)
        case .openURL(let url):
            var nested = c.nestedContainer(keyedBy: OpenURLKeys.self, forKey: .openURL)
            try nested.encode(url, forKey: .url)
        case .keystroke(let kc, let mods):
            var nested = c.nestedContainer(keyedBy: KeystrokeKeys.self, forKey: .keystroke)
            try nested.encode(kc, forKey: .keyCode)
            try nested.encode(mods, forKey: .modifiers)
        case .systemShortcut(let kind):
            var nested = c.nestedContainer(keyedBy: SystemShortcutNestedKeys.self, forKey: .systemShortcut)
            try nested.encode(kind.rawValue, forKey: ._0)
        case .snippet(let text):
            var nested = c.nestedContainer(keyedBy: SnippetKeys.self, forKey: .snippet)
            try nested.encode(text, forKey: .text)
        }
    }
}

/// Тип меню: обычное (секторы из конфигурации) или динамический список запущенных приложений.
enum PieMenuKind: String, Codable, CaseIterable, Equatable {
    case standard
    case runningApps
    /// Команды активного приложения: из его строки меню, работа с окном, скрыть и завершить.
    case appCommands
}

struct HotkeyConfig: Codable, Equatable {
    var keyCode: Int
    var carbonModifiers: Int

    /// Carbon `kEventKeyModifierFnMask` — для F1–F12 на клавиатурах Apple с клавишей Fn.
    static let carbonFnModifierMask: Int = 1 << 17

    /// macOS `kVK_Function` — отдельная клавиша Fn.
    static let fnKeyVirtualCode: Int = 63

    /// `kVK_LeftArrow` … `kVK_UpArrow` — при keyDown система иногда ставит `.function` без физического Fn.
    static let arrowKeyVirtualCodes: Set<Int> = [123, 124, 125, 126]

    /// Fn и F1…F12 для выбора в интерфейсе (`kVK_Function`, `kVK_F1` … `kVK_F12`).
    static let functionKeyVirtualCodes: [(label: String, code: Int)] = [
        ("Fn", fnKeyVirtualCode),
        ("Tab", 48),
        ("F1", 122), ("F2", 120), ("F3", 99), ("F4", 118), ("F5", 96), ("F6", 97),
        ("F7", 98), ("F8", 100), ("F9", 101), ("F10", 109), ("F11", 103), ("F12", 111)
    ]

    static var defaultHotkey: HotkeyConfig {
        HotkeyConfig(keyCode: 49, carbonModifiers: 6144)
    }

    static var empty: HotkeyConfig {
        HotkeyConfig(keyCode: -1, carbonModifiers: 0)
    }

    var isEmpty: Bool { keyCode < 0 }

    /// Повторное нажатие клавиши хоткея переключает сектор (только не для одиночной Fn).
    var supportsRunningAppsRepeatKeyCycle: Bool {
        guard !isEmpty else { return false }
        if keyCode == Self.fnKeyVirtualCode, carbonModifiers == 0 { return false }
        return true
    }

    /// Carbon `carbonModifiers` → флаги для сравнения с `NSEvent.modifierFlags` (device-independent).
    var nsDeviceIndependentModifierFlags: NSEvent.ModifierFlags {
        var ns: NSEvent.ModifierFlags = []
        if carbonModifiers & 256 != 0 { ns.insert(.command) }
        if carbonModifiers & 512 != 0 { ns.insert(.shift) }
        if carbonModifiers & 2048 != 0 { ns.insert(.option) }
        if carbonModifiers & 4096 != 0 { ns.insert(.control) }
        if carbonModifiers & Self.carbonFnModifierMask != 0 { ns.insert(.function) }
        return ns
    }

    /// Те же биты Carbon, для сравнения с `NSEvent` (делегирует в общий `CarbonModifiers`).
    static func carbonFromNSEventModifierFlags(_ flags: NSEvent.ModifierFlags) -> Int {
        CarbonModifiers.carbon(from: flags)
    }

    /// KeyDown совпадает с хоткеем (переключение сектора при открытом меню).
    func matchesKeyDownForChordRepeat(_ event: NSEvent) -> Bool {
        guard supportsRunningAppsRepeatKeyCycle else { return false }
        guard event.keyCode == UInt16(keyCode) else { return false }
        return Self.carbonFromNSEventModifierFlags(event.modifierFlags) == carbonModifiers
    }

    /// Сочетания, которые система забирает до Carbon: ⌘Tab; отдельная Fn/Globe — через HID `flagsChanged`.
    /// Любой хоткей с битом Fn: Carbon `RegisterEventHotKey` с `kEventKeyModifierFnMask` часто не работает — только HID.
    /// HID-хоткей, который можно продублировать через Carbon: ⌘Tab и ⌘⇧Tab, но не сочетания с Fn.
    var canUseCarbonBackup: Bool {
        prefersHIDEventTap
            && keyCode == 48
            && carbonModifiers & Self.carbonFnModifierMask == 0
    }

    var prefersHIDEventTap: Bool {
        guard !isEmpty else { return false }
        if keyCode == Self.fnKeyVirtualCode, carbonModifiers == 0 { return true }
        if carbonModifiers & Self.carbonFnModifierMask != 0 { return true }
        if keyCode == 48 { return (carbonModifiers & 256) != 0 }
        return false
    }

    var displayString: String {
        displayString(language: .russian)
    }

    func displayString(language: AppLanguage) -> String {
        if isEmpty {
            return language.usesRussianCopy ? "Не назначено" : "Unassigned"
        }
        var parts: [String] = []
        if carbonModifiers & 4096 != 0 { parts.append("Ctrl") }
        if carbonModifiers & 2048 != 0 { parts.append("Alt") }
        if carbonModifiers & 512 != 0 { parts.append("Shift") }
        if carbonModifiers & 256 != 0 { parts.append("Cmd") }
        if carbonModifiers & Self.carbonFnModifierMask != 0 { parts.append("Fn") }
        parts.append(Self.keyCodeToString(keyCode))
        return parts.joined(separator: " + ")
    }

    /// Коротко, как сочетания в меню macOS: «⌃⌥Space», «⌘⇥». Пусто, если хоткей не назначен.
    var glyphString: String {
        guard !isEmpty else { return "" }
        var result = ""
        if carbonModifiers & Self.carbonFnModifierMask != 0 { result += "fn " }
        if carbonModifiers & 4096 != 0 { result += "⌃" }
        if carbonModifiers & 2048 != 0 { result += "⌥" }
        if carbonModifiers & 512 != 0 { result += "⇧" }
        if carbonModifiers & 256 != 0 { result += "⌘" }
        let glyphs: [Int: String] = [36: "↩", 48: "⇥", 51: "⌫", 53: "⎋", 117: "⌦"]
        return result + (glyphs[keyCode] ?? Self.keyCodeToString(keyCode))
    }

    static func keyCodeToString(_ keyCode: Int) -> String {
        let keyNames: [Int: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 10: "§", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5",
            24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "O",
            32: "U", 33: "[", 34: "I", 35: "P", 36: "Return", 37: "L", 38: "J",
            39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M",
            47: ".", 48: "Tab", 49: "Space", 50: "`", 51: "Delete", 53: "Esc",
            63: "Fn",
            64: "F17", 79: "F18", 80: "F19", 90: "F20",
            96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9",
            103: "F11", 105: "F13", 106: "F16", 107: "F14", 109: "F10", 111: "F12",
            113: "F15", 114: "Help", 115: "Home", 116: "Page Up",
            117: "Fwd Del", 118: "F4", 119: "End", 120: "F2",
            121: "Page Down", 122: "F1",
            123: "←", 124: "→", 125: "↓", 126: "↑"
        ]
        return keyNames[keyCode] ?? "Key\(keyCode)"
    }

    static func keystrokeDisplayString(keyCode: Int, modifiers: Int) -> String {
        keystrokeDisplayString(keyCode: keyCode, modifiers: modifiers, language: .russian)
    }

    static func keystrokeDisplayString(keyCode: Int, modifiers: Int, language: AppLanguage) -> String {
        if keyCode == 0 && modifiers == 0 {
            return language.usesRussianCopy ? "Не назначено" : "Unassigned"
        }
        let flags = UInt64(modifiers)
        var parts: [String] = []
        if flags & CGEventFlags.maskControl.rawValue != 0 { parts.append("Ctrl") }
        if flags & CGEventFlags.maskAlternate.rawValue != 0 { parts.append("Alt") }
        if flags & CGEventFlags.maskShift.rawValue != 0 { parts.append("Shift") }
        if flags & CGEventFlags.maskCommand.rawValue != 0 { parts.append("Cmd") }
        if flags & CGEventFlags.maskSecondaryFn.rawValue != 0 { parts.append("Fn") }
        parts.append(keyCodeToString(keyCode))
        return parts.joined(separator: " + ")
    }

    static func cgEventModifiers(from flags: Int) -> Int {
        var cg: UInt64 = 0
        if flags & 256 != 0 { cg |= CGEventFlags.maskCommand.rawValue }
        if flags & 512 != 0 { cg |= CGEventFlags.maskShift.rawValue }
        if flags & 2048 != 0 { cg |= CGEventFlags.maskAlternate.rawValue }
        if flags & 4096 != 0 { cg |= CGEventFlags.maskControl.rawValue }
        if flags & carbonFnModifierMask != 0 { cg |= CGEventFlags.maskSecondaryFn.rawValue }
        return Int(cg)
    }

    /// На ноутбуках Fn+стрелка приходит как Home/End/Page Up/Page Down; для `CGEvent` и тайлинга нужны коды стрелок и `maskSecondaryFn`.
    static func normalizedKeystrokeFromRecording(keyCode: Int, carbonModifiers: Int, fnGlobeHeld: Bool) -> (keyCode: Int, cgModifiers: Int) {
        var carbon = carbonModifiers
        if fnGlobeHeld, carbon & carbonFnModifierMask == 0 {
            carbon |= carbonFnModifierMask
        }
        var code = keyCode
        if fnGlobeHeld {
            switch code {
            case 115: code = 123
            case 119: code = 124
            case 116: code = 126
            case 121: code = 125
            default: break
            }
        }
        return (code, cgEventModifiers(from: carbon))
    }
}

struct PieMenu: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var hotkey: HotkeyConfig
    /// Для динамических меню (`runningApps`, `appCommands`) список `items` не используется при показе меню.
    var items: [PieMenuItem]
    var kind: PieMenuKind
    /// Bundle ID приложений, которые не показывать в меню запущенных (даже если открыты).
    var runningAppsExcludedBundleIds: [String]
    /// Для динамических меню: включено ли меню (хоткей и жест не срабатывают, пока выключено).
    /// Имя поля осталось от времён, когда динамическое меню было одно, — так его хранит конфиг.
    var runningAppsMenuEnabled: Bool
    /// Касание трекпада, которое открывает это меню: сколько пальцев, 0 — выключено.
    /// Одно число пальцев открывает одно меню (см. `PieConfiguration.assignTrackpadFingerCount`).
    var trackpadFingerCount: Int
    var menuRadius: Double
    /// Радиус внутреннего «отверстия» кольца секторов (граница между центром и дугами).
    var innerRadius: Double
    var iconDistance: Double
    var iconSize: Double
    /// Общий масштаб: внешний радиус, внутренний радиус и размер иконок умножаются на это значение.
    var appearanceScale: Double
    var rotationDegrees: Double
    var liquidGlass: LiquidGlassSettings
    var animationDuration: Double
    /// Декоративная «лапка» у выделенного сектора.
    var pawDecorationEnabled: Bool
    /// Размер лапки (множитель относительно базового размера от ширины кольца сектора).
    var pawSizeScale: Double
    /// «Ближе к центру»: 0% — у внешней границы сектора (`menuRadius`), 100% — в центре меню (центр кота). Равномерно по длине этого отрезка.
    var pawRadialInset: Double
    /// Масштаб мордочки кота в центре (1.0 — размер по умолчанию).
    var centerCatScale: Double
    /// Иконка приложения в центре меню «Команды приложения»: доля диаметра центрального круга.
    var centerAppIconScale: Double
    /// Меню «Команды приложения»: команды для приложений без своего набора, по часовой стрелке от верха
    /// кольца. Порядок меняют перетаскиванием в превью. У остальных меню пусто.
    var appCommandsDefaultEntries: [AppSubMenuEntry]
    /// Размер цифр-шорткатов (0...9) относительно ширины кольца сектора (`menuRadius - innerRadius`).
    var shortcutDigitSizeScale: Double
    /// Отступ цифр-шорткатов от «левой» стороны угла сектора, относительно ширины кольца сектора.
    var shortcutDigitInsetLeftScale: Double
    /// Отступ цифр-шорткатов от «правой» стороны угла сектора, относительно ширины кольца сектора.
    var shortcutDigitInsetRightScale: Double
    /// Прозрачность цифр-шорткатов.
    var shortcutDigitOpacity: Double
    /// Цвет цифр-шорткатов в HEX.
    var shortcutDigitColorHex: String
    /// Цвет кота в центре меню (и выглядывающего из-за иконки в меню команд), в HEX.
    var catColorHex: String
    /// Цвет лапки — и той, что хватает выбранный сектор, и той, что держит иконку в меню команд.
    var pawColorHex: String
    /// Подпись выделенного сектора снаружи кольца: название, а для ссылки, сочетания и текста — ещё и
    /// что именно выполнится. Выключают, когда кольцо из одних иконок приложений и подпись лишняя.
    var showsHoverLabel: Bool
    /// Фон плитки с иконкой меню в боковой панели (HEX). `nil` — старые конфиги, в UI — системный accent.
    var globalSidebarIconColorHex: String?
    /// Раскраска кольца. Секторы без своего цвета берут цвет отсюда по месту (см. `themed(_:)`).
    var colorScheme: SectorColorScheme
    /// Цвет иконок-символов: в цвет сектора или белые.
    var iconStyle: SectorIconStyle
    /// Своя тема, которой оформлено меню. Сохранённые изменения темы расходятся по всем её меню;
    /// несохранённые правки видны как «тема изменена». `nil` — оформление не из темы.
    var themeID: UUID?

    var isRunningAppsMenu: Bool { kind == .runningApps }

    var isAppCommandsMenu: Bool { kind == .appCommands }

    /// Пункты собираются при показе, а не хранятся в конфиге: запущенные приложения или команды
    /// активного приложения. Такое меню одно своего вида, его нельзя переименовать или удалить.
    var isDynamicMenu: Bool { kind != .standard }

    /// Подписи клавиатурных шорткатов для быстрых выборов в меню.
    static let quickSelectLabels: [String] = [
        "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
        "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P",
        "A", "S", "D", "F", "G", "H", "J", "K", "L",
        "Z", "X", "C", "V", "B", "N", "M"
    ]

    static func quickSelectLabel(for index: Int) -> String? {
        guard index >= 0, index < quickSelectLabels.count else { return nil }
        return quickSelectLabels[index]
    }

    /// Итоговые подписи шорткатов для пунктов в том порядке, в каком они будут отрисованы.
    /// Пользовательские буквы/цифры приоритетнее; авто-подпись скрывается, если её символ занят пользовательским у другого пункта.
    static func resolvedShortcutLabels(for items: [PieMenuItem]) -> [String?] {
        var labels: [String?] = (0..<items.count).map { quickSelectLabel(for: $0) }
        let customByIndex: [(Int, String)] = items.enumerated().compactMap { idx, item in
            guard let s = item.customShortcut, !s.isEmpty else { return nil }
            return (idx, s)
        }
        let usedCustom = Set(customByIndex.map { $0.1.uppercased() })
        for i in labels.indices {
            if customByIndex.contains(where: { $0.0 == i }) { continue }
            if let auto = labels[i], usedCustom.contains(auto.uppercased()) {
                labels[i] = nil
            }
        }
        for (idx, custom) in customByIndex where idx < labels.count {
            labels[idx] = custom
        }
        return labels
    }

    /// Индекс пункта, которому соответствует нажатая клавиша (по уже рассчитанным меткам).
    static func itemIndex(forPressedKey key: String, resolvedLabels: [String?]) -> Int? {
        let normalized = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else { return nil }
        return resolvedLabels.firstIndex(where: { ($0?.uppercased() ?? "") == normalized })
    }

    private static let defaultMenuRadius: Double = 150
    static let defaultInnerRadius: Double = 76
    private static let minInnerRadius: Double = 12
    private static let minRingWidth: Double = 22
    private static let defaultIconDistanceFromCenter: Double = 55
    private static let defaultIconDistanceRatio: Double = 0.50
    static let defaultAppearanceScale: Double = 1.0
    private static let minAppearanceScale: Double = 0.5
    private static let maxAppearanceScale: Double = 2.0

    static let defaultPawSizeScale: Double = 0.80
    static let defaultPawRadialInset: Double = 0.50
    /// Базовые параметры лапки, привязанные к ширине кольца сектора (`menuRadius - innerRadius`).
    static let pawSizeBaseFromRingWidth: Double = 0.54
    private static let pawRadialInsetSliderMin: Double = 0.05
    private static let pawRadialInsetSliderMax: Double = 0.95
    static let defaultCenterCatScale: Double = 0.75
    static let defaultShortcutDigitSizeScale: Double = 0.23
    static let defaultShortcutDigitInsetLeftScale: Double = 0.29
    static let defaultShortcutDigitInsetRightScale: Double = 0.35
    static let defaultShortcutDigitOpacity: Double = 0.29
    static let defaultShortcutDigitColorHex: String = "#FFFFFF"
    static let defaultCatColorHex: String = "#000000"
    static let defaultPawColorHex: String = "#000000"
    /// Базовые коэффициенты шорткатов к ширине кольца сектора (`menuRadius - innerRadius`).
    static let shortcutDigitFontBaseFromRingWidth: Double = 0.13
    static let shortcutDigitInsetLeftBaseFromRingWidth: Double = 0.165
    static let shortcutDigitInsetRightBaseFromRingWidth: Double = 0.20
    private static let minCenterCatScale: Double = 0.45
    private static let maxCenterCatScale: Double = 1.2
    static let defaultCenterAppIconScale: Double = 0.4
    private static let minCenterAppIconScale: Double = 0.3
    /// Над иконкой ещё голова кота (вся композиция в 1,3 раза выше иконки): больше — и кот залезает на секторы.
    private static let maxCenterAppIconScale: Double = 0.7

    static func clampedCenterCatScale(_ value: Double) -> Double {
        min(max(value, minCenterCatScale), maxCenterCatScale)
    }

    static var centerCatScaleAllowedRange: ClosedRange<Double> { minCenterCatScale...maxCenterCatScale }

    static func clampedCenterAppIconScale(_ value: Double) -> Double {
        min(max(value, minCenterAppIconScale), maxCenterAppIconScale)
    }

    static var centerAppIconScaleAllowedRange: ClosedRange<Double> { minCenterAppIconScale...maxCenterAppIconScale }

    static func clampedPawSizeScale(_ value: Double) -> Double {
        min(max(value, 0.35), 0.95)
    }

    static func clampedPawRadialInset(_ value: Double) -> Double {
        min(max(value, pawRadialInsetSliderMin), pawRadialInsetSliderMax)
    }

    /// Расстояние от центра меню до лапки по лучу сектора: при минимуме слайдера — у внешней дуги (`outerRadius`), при максимуме — в центре (0).
    static func pawRadialDistanceFromMenuCenter(pawRadialInset: Double, outerRadius: Double) -> CGFloat {
        let r = clampedPawRadialInset(pawRadialInset)
        let span = pawRadialInsetSliderMax - pawRadialInsetSliderMin
        let t = (r - pawRadialInsetSliderMin) / span
        return CGFloat(outerRadius * (1 - t))
    }

    static func clampedAppearanceScale(_ value: Double) -> Double {
        min(max(value, minAppearanceScale), maxAppearanceScale)
    }

    static var appearanceScaleAllowedRange: ClosedRange<Double> { minAppearanceScale...maxAppearanceScale }
    static var shortcutDigitSizeScaleAllowedRange: ClosedRange<Double> { 0.10...0.60 }
    static var shortcutDigitInsetLeftScaleAllowedRange: ClosedRange<Double> { 0.05...0.90 }
    static var shortcutDigitInsetRightScaleAllowedRange: ClosedRange<Double> { 0.05...0.90 }
    static var shortcutDigitOpacityAllowedRange: ClosedRange<Double> { 0.10...1.00 }

    static func clampedShortcutDigitSizeScale(_ value: Double) -> Double {
        min(max(value, shortcutDigitSizeScaleAllowedRange.lowerBound), shortcutDigitSizeScaleAllowedRange.upperBound)
    }

    static func clampedShortcutDigitInsetLeftScale(_ value: Double) -> Double {
        min(max(value, shortcutDigitInsetLeftScaleAllowedRange.lowerBound), shortcutDigitInsetLeftScaleAllowedRange.upperBound)
    }

    static func clampedShortcutDigitInsetRightScale(_ value: Double) -> Double {
        min(max(value, shortcutDigitInsetRightScaleAllowedRange.lowerBound), shortcutDigitInsetRightScaleAllowedRange.upperBound)
    }

    static func clampedShortcutDigitOpacity(_ value: Double) -> Double {
        min(max(value, shortcutDigitOpacityAllowedRange.lowerBound), shortcutDigitOpacityAllowedRange.upperBound)
    }

    var effectiveMenuRadius: Double { menuRadius * appearanceScale }
    var effectiveInnerRadius: Double { innerRadius * appearanceScale }
    var effectiveIconSize: Double { iconSize * appearanceScale }

    /// Иконка в кольце из `sectorCount` секторов: заданного размера, но не больше места в секторе.
    /// Место — ширина сектора на радиусе иконки и толщина кольца: в меню с многими секторами
    /// сектор узкий, и иконка уменьшается, чтобы не вылезать за края.
    func fittedIconSize(sectorCount: Int) -> Double {
        let ring = max(1, effectiveMenuRadius - effectiveInnerRadius)
        let radius = effectiveInnerRadius + ring * iconDistance
        let sectorWidth = sectorCount > 1 ? 2 * radius * sin(.pi / Double(sectorCount)) : ring
        let room = min(sectorWidth * Self.iconWidthShare, ring * Self.iconRingShare)
        return max(Self.minFittedIconSize, min(effectiveIconSize, room))
    }

    /// Какую долю ширины сектора может занять иконка: остальное — поля до соседей и зазоров.
    private static let iconWidthShare = 0.62
    /// Вдоль радиуса места больше: иконка у края кольца заметна меньше, чем наезд на соседа.
    private static let iconRingShare = 0.8
    private static let minFittedIconSize = 12.0

    static func clampedInnerRadius(_ inner: Double, outerRadius: Double) -> Double {
        let maxInner = max(minInnerRadius, outerRadius - minRingWidth)
        return min(max(inner, minInnerRadius), maxInner)
    }

    /// Диапазон допустимого внутреннего радиуса при заданном внешнем (`menuRadius`).
    static func innerRadiusAllowedRange(outerRadius: Double) -> ClosedRange<Double> {
        let upper = max(minInnerRadius, outerRadius - minRingWidth)
        return minInnerRadius...upper
    }

    /// Уникальные bundle ID для исключений (меню «запущенные приложения»), без учёта регистра.
    static func deduplicatedRunningAppsExcludedBundleIds(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        result.reserveCapacity(ids.count)
        for id in ids {
            let key = id.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(id)
        }
        return result
    }

    private static func iconDistanceForRadius(_ radius: Double, menuRadius: Double, innerRadius: Double) -> Double {
        guard menuRadius > innerRadius else { return 1 }
        return (radius - innerRadius) / (menuRadius - innerRadius)
    }

    init(id: UUID = UUID(),
         name: String = "New menu",
         hotkey: HotkeyConfig = .defaultHotkey,
         items: [PieMenuItem] = [],
         kind: PieMenuKind = .standard,
         runningAppsExcludedBundleIds: [String] = [],
         runningAppsMenuEnabled: Bool = true,
         trackpadFingerCount: Int = 0,
         menuRadius: Double = defaultMenuRadius,
         innerRadius: Double = defaultInnerRadius,
         iconDistance: Double? = nil,
         iconSize: Double = 42,
         appearanceScale: Double = defaultAppearanceScale,
         rotationDegrees: Double = 0,
         liquidGlass: LiquidGlassSettings = .default,
         animationDuration: Double = 0.2,
         pawDecorationEnabled: Bool = true,
         pawSizeScale: Double = PieMenu.defaultPawSizeScale,
         pawRadialInset: Double = PieMenu.defaultPawRadialInset,
         centerCatScale: Double = PieMenu.defaultCenterCatScale,
         centerAppIconScale: Double = PieMenu.defaultCenterAppIconScale,
         appCommandsDefaultEntries: [AppSubMenuEntry] = [],
         shortcutDigitSizeScale: Double = PieMenu.defaultShortcutDigitSizeScale,
         shortcutDigitInsetLeftScale: Double = PieMenu.defaultShortcutDigitInsetLeftScale,
         shortcutDigitInsetRightScale: Double = PieMenu.defaultShortcutDigitInsetRightScale,
         shortcutDigitOpacity: Double = PieMenu.defaultShortcutDigitOpacity,
         shortcutDigitColorHex: String = PieMenu.defaultShortcutDigitColorHex,
         catColorHex: String = PieMenu.defaultCatColorHex,
         pawColorHex: String = PieMenu.defaultPawColorHex,
         showsHoverLabel: Bool = true,
         globalSidebarIconColorHex: String? = nil,
         colorScheme: SectorColorScheme = MenuThemePreset.classic.scheme,
         iconStyle: SectorIconStyle = .tinted,
         themeID: UUID? = nil) {
        self.id = id
        self.name = name
        self.hotkey = hotkey
        self.items = items
        self.kind = kind
        self.runningAppsExcludedBundleIds = runningAppsExcludedBundleIds
        self.runningAppsMenuEnabled = runningAppsMenuEnabled
        self.trackpadFingerCount = trackpadFingerCount
        self.menuRadius = menuRadius
        self.innerRadius = Self.clampedInnerRadius(innerRadius, outerRadius: menuRadius)
        self.iconDistance = iconDistance ?? Self.defaultIconDistanceRatio
        self.iconSize = iconSize
        self.appearanceScale = Self.clampedAppearanceScale(appearanceScale)
        self.rotationDegrees = rotationDegrees
        self.liquidGlass = liquidGlass
        self.animationDuration = animationDuration
        self.pawDecorationEnabled = pawDecorationEnabled
        self.pawSizeScale = Self.clampedPawSizeScale(pawSizeScale)
        self.pawRadialInset = Self.clampedPawRadialInset(pawRadialInset)
        self.centerCatScale = Self.clampedCenterCatScale(centerCatScale)
        self.centerAppIconScale = Self.clampedCenterAppIconScale(centerAppIconScale)
        self.appCommandsDefaultEntries = Self.resolvedAppCommandsDefaultEntries(appCommandsDefaultEntries, kind: kind)
        self.shortcutDigitSizeScale = Self.clampedShortcutDigitSizeScale(shortcutDigitSizeScale)
        self.shortcutDigitInsetLeftScale = Self.clampedShortcutDigitInsetLeftScale(shortcutDigitInsetLeftScale)
        self.shortcutDigitInsetRightScale = Self.clampedShortcutDigitInsetRightScale(shortcutDigitInsetRightScale)
        self.shortcutDigitOpacity = Self.clampedShortcutDigitOpacity(shortcutDigitOpacity)
        self.shortcutDigitColorHex = shortcutDigitColorHex
        self.catColorHex = catColorHex
        self.pawColorHex = pawColorHex
        self.showsHoverLabel = showsHoverLabel
        self.globalSidebarIconColorHex = globalSidebarIconColorHex
        self.colorScheme = colorScheme
        self.iconStyle = iconStyle
        self.themeID = themeID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        hotkey = try container.decode(HotkeyConfig.self, forKey: .hotkey)
        items = try container.decode([PieMenuItem].self, forKey: .items)
        menuRadius = try container.decode(Double.self, forKey: .menuRadius)
        innerRadius = try container.decodeIfPresent(Double.self, forKey: .innerRadius) ?? Self.defaultInnerRadius
        innerRadius = Self.clampedInnerRadius(innerRadius, outerRadius: menuRadius)
        iconDistance = try container.decodeIfPresent(Double.self, forKey: .iconDistance)
            ?? Self.iconDistanceForRadius(Self.defaultIconDistanceFromCenter, menuRadius: menuRadius, innerRadius: innerRadius)
        iconSize = try container.decodeIfPresent(Double.self, forKey: .iconSize) ?? 42
        appearanceScale = Self.clampedAppearanceScale(
            try container.decodeIfPresent(Double.self, forKey: .appearanceScale) ?? Self.defaultAppearanceScale
        )
        rotationDegrees = try container.decodeIfPresent(Double.self, forKey: .rotationDegrees) ?? 0
        liquidGlass = try container.decodeIfPresent(LiquidGlassSettings.self, forKey: .liquidGlass) ?? .default
        animationDuration = try container.decode(Double.self, forKey: .animationDuration)
        pawDecorationEnabled = try container.decodeIfPresent(Bool.self, forKey: .pawDecorationEnabled) ?? true
        pawSizeScale = Self.clampedPawSizeScale(
            try container.decodeIfPresent(Double.self, forKey: .pawSizeScale) ?? Self.defaultPawSizeScale
        )
        pawRadialInset = Self.clampedPawRadialInset(
            try container.decodeIfPresent(Double.self, forKey: .pawRadialInset) ?? Self.defaultPawRadialInset
        )
        centerCatScale = Self.clampedCenterCatScale(
            try container.decodeIfPresent(Double.self, forKey: .centerCatScale) ?? Self.defaultCenterCatScale
        )
        centerAppIconScale = Self.clampedCenterAppIconScale(
            try container.decodeIfPresent(Double.self, forKey: .centerAppIconScale) ?? Self.defaultCenterAppIconScale
        )
        shortcutDigitSizeScale = Self.clampedShortcutDigitSizeScale(
            try container.decodeIfPresent(Double.self, forKey: .shortcutDigitSizeScale) ?? Self.defaultShortcutDigitSizeScale
        )
        let legacyCornerInset = try container.decodeIfPresent(Double.self, forKey: .shortcutDigitCornerInsetScale)
        shortcutDigitInsetLeftScale = Self.clampedShortcutDigitInsetLeftScale(
            try container.decodeIfPresent(Double.self, forKey: .shortcutDigitInsetLeftScale)
                ?? legacyCornerInset
                ?? Self.defaultShortcutDigitInsetLeftScale
        )
        shortcutDigitInsetRightScale = Self.clampedShortcutDigitInsetRightScale(
            try container.decodeIfPresent(Double.self, forKey: .shortcutDigitInsetRightScale)
                ?? legacyCornerInset
                ?? Self.defaultShortcutDigitInsetRightScale
        )
        shortcutDigitOpacity = Self.clampedShortcutDigitOpacity(
            try container.decodeIfPresent(Double.self, forKey: .shortcutDigitOpacity) ?? Self.defaultShortcutDigitOpacity
        )
        shortcutDigitColorHex = try container.decodeIfPresent(String.self, forKey: .shortcutDigitColorHex) ?? Self.defaultShortcutDigitColorHex
        catColorHex = try container.decodeIfPresent(String.self, forKey: .catColorHex) ?? Self.defaultCatColorHex
        pawColorHex = try container.decodeIfPresent(String.self, forKey: .pawColorHex) ?? Self.defaultPawColorHex
        showsHoverLabel = try container.decodeIfPresent(Bool.self, forKey: .showsHoverLabel) ?? true
        globalSidebarIconColorHex = try container.decodeIfPresent(String.self, forKey: .globalSidebarIconColorHex)
        colorScheme = Self.decodeColorScheme(from: container)
        kind = try container.decodeIfPresent(PieMenuKind.self, forKey: .kind) ?? .standard
        // Иконки команд всегда были белыми — у меню команд так и остаётся, пока не выберут другие.
        iconStyle = (try? container.decodeIfPresent(String.self, forKey: .iconStyle))
            .flatMap(SectorIconStyle.init(rawValue:)) ?? (kind == .appCommands ? .white : .tinted)
        themeID = try container.decodeIfPresent(UUID.self, forKey: .themeID) ?? Self.legacyThemeID(in: &colorScheme)
        runningAppsExcludedBundleIds = Self.deduplicatedRunningAppsExcludedBundleIds(
            try container.decodeIfPresent([String].self, forKey: .runningAppsExcludedBundleIds) ?? []
        )
        runningAppsMenuEnabled = try container.decodeIfPresent(Bool.self, forKey: .runningAppsMenuEnabled) ?? true
        trackpadFingerCount = try container.decodeIfPresent(Int.self, forKey: .trackpadFingerCount) ?? 0
        appCommandsDefaultEntries = Self.resolvedAppCommandsDefaultEntries(
            try container.decodeIfPresent([LossyAppSubMenuEntry].self, forKey: .appCommandsDefaultEntries)?
                .compactMap(\.entry) ?? [],
            kind: kind
        )

        if items.count > 1 && items.allSatisfy({ $0.sectorIndex == 0 }) {
            for i in items.indices {
                items[i].sectorIndex = i
            }
        }

        if items.count > 1 {
            let colors = Set(items.map { $0.color })
            if colors.count == 1 {
                for i in items.indices {
                    items[i].color = PieMenuItem.paletteColor(for: items[i].sectorIndex)
                    items[i].usesThemeColor = true
                }
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(hotkey, forKey: .hotkey)
        try container.encode(items, forKey: .items)
        try container.encode(kind, forKey: .kind)
        try container.encode(runningAppsExcludedBundleIds, forKey: .runningAppsExcludedBundleIds)
        try container.encode(runningAppsMenuEnabled, forKey: .runningAppsMenuEnabled)
        try container.encode(trackpadFingerCount, forKey: .trackpadFingerCount)
        try container.encode(menuRadius, forKey: .menuRadius)
        try container.encode(innerRadius, forKey: .innerRadius)
        try container.encode(iconDistance, forKey: .iconDistance)
        try container.encode(iconSize, forKey: .iconSize)
        try container.encode(appearanceScale, forKey: .appearanceScale)
        try container.encode(rotationDegrees, forKey: .rotationDegrees)
        try container.encode(liquidGlass, forKey: .liquidGlass)
        try container.encode(animationDuration, forKey: .animationDuration)
        try container.encode(pawDecorationEnabled, forKey: .pawDecorationEnabled)
        try container.encode(pawSizeScale, forKey: .pawSizeScale)
        try container.encode(pawRadialInset, forKey: .pawRadialInset)
        try container.encode(centerCatScale, forKey: .centerCatScale)
        try container.encode(centerAppIconScale, forKey: .centerAppIconScale)
        if !appCommandsDefaultEntries.isEmpty {
            try container.encode(appCommandsDefaultEntries, forKey: .appCommandsDefaultEntries)
        }
        try container.encode(shortcutDigitSizeScale, forKey: .shortcutDigitSizeScale)
        try container.encode(shortcutDigitInsetLeftScale, forKey: .shortcutDigitInsetLeftScale)
        try container.encode(shortcutDigitInsetRightScale, forKey: .shortcutDigitInsetRightScale)
        try container.encode(shortcutDigitOpacity, forKey: .shortcutDigitOpacity)
        try container.encode(shortcutDigitColorHex, forKey: .shortcutDigitColorHex)
        try container.encode(catColorHex, forKey: .catColorHex)
        try container.encode(pawColorHex, forKey: .pawColorHex)
        try container.encode(showsHoverLabel, forKey: .showsHoverLabel)
        try container.encodeIfPresent(globalSidebarIconColorHex, forKey: .globalSidebarIconColorHex)
        try container.encode(colorScheme, forKey: .colorScheme)
        try container.encode(iconStyle, forKey: .iconStyle)
        try container.encodeIfPresent(themeID, forKey: .themeID)
    }

    /// Первая версия своих тем помечала раскраску меню как `custom:<id темы>` — такое меню
    /// становится привязанным к этой теме, а метка из раскраски убирается.
    private static func legacyThemeID(in scheme: inout SectorColorScheme) -> UUID? {
        guard let presetID = scheme.presetID, presetID.hasPrefix(CustomMenuTheme.legacyIDPrefix) else { return nil }
        scheme.presetID = nil
        return UUID(uuidString: String(presetID.dropFirst(CustomMenuTheme.legacyIDPrefix.count)))
    }

    /// Пункты в том виде, в каком их рисует кольцо: цвет из темы по месту сектора в кольце
    /// (если у сектора нет своего) и белые иконки, если так задано. Место — по `sectorIndex`,
    /// а не по порядку в массиве: перетаскивание в редакторе меняет номера секторов, не порядок
    /// пунктов, и иначе меню и превью раскрасили бы секторы по-разному. Порядок пунктов не меняется.
    func themed(_ items: [PieMenuItem]) -> [PieMenuItem] {
        let ringOrder = items.indices.sorted { (items[$0].sectorIndex, $0) < (items[$1].sectorIndex, $1) }
        var position = [Int](repeating: 0, count: items.count)
        for (place, index) in ringOrder.enumerated() {
            position[index] = place
        }
        return items.enumerated().map { index, item in
            var item = item
            if item.usesThemeColor {
                item.color = colorScheme.color(at: position[index], count: items.count)
            }
            if iconStyle == .white, item.iconColor == nil {
                item.iconColor = "#FFFFFF"
            }
            return item
        }
    }

    /// Готовая палитра: раскраска, насыщенность, стекло и иконки. Форма, детали, свои цвета секторов
    /// и привязка к теме остаются — у меню с темой палитра становится несохранённой правкой темы.
    mutating func applyPalette(_ preset: MenuThemePreset) {
        colorScheme = preset.scheme
        liquidGlass.tintOpacity = preset.intensity
        liquidGlass.variant = preset.glass
        iconStyle = preset.icons
    }

    /// Сколько пунктов со своим цветом сектора или иконки — они не следуют теме.
    /// У меню команд — сколько таких команд.
    var customColorCount: Int {
        if isAppCommandsMenu {
            return appCommandsDefaultEntries.filter(\.hasCustomColors).count
        }
        return items.filter { !$0.usesThemeColor || ($0.iconColor != nil && $0.hasTintableIcon) }.count
    }

    /// Вернуть всем секторам и иконкам цвета темы (у «Завершить» — его красный).
    mutating func resetSectorColors() {
        for i in appCommandsDefaultEntries.indices {
            appCommandsDefaultEntries[i].resetColors()
        }
        for i in items.indices {
            items[i].usesThemeColor = true
            items[i].iconColor = nil
        }
    }

    /// Сколько секторов в кольце: у меню команд — команды, у остальных — пункты.
    var sectorCount: Int {
        isAppCommandsMenu ? appCommandsDefaultEntries.count : items.count
    }

    /// Нет схемы — конфиг до тем: «Классика». Цвет меню из промежуточной версии (`accent`) становится
    /// схемой одного цвета. Схема из будущей версии, которую не прочесть, — тоже «Классика».
    private static func decodeColorScheme(from container: KeyedDecodingContainer<CodingKeys>) -> SectorColorScheme {
        if let scheme = try? container.decodeIfPresent(SectorColorScheme.self, forKey: .colorScheme),
           !scheme.colors.isEmpty, scheme.colors.allSatisfy(HexColor.isValid) {
            return scheme
        }
        let legacyAccents = [
            "blue": "#0A84FF", "purple": "#BF5AF2", "pink": "#FF375F", "red": "#FF453A",
            "orange": "#FF9F0A", "yellow": "#FFD60A", "green": "#30D158", "graphite": "#98989D"
        ]
        if let accent = try? container.decodeIfPresent(String.self, forKey: .accent), let hex = legacyAccents[accent] {
            return SectorColorScheme(mode: .single, colors: [hex], presetID: nil)
        }
        return MenuThemePreset.classic.scheme
    }

    /// Копирует размер кольца, внешний вид, цвет меню и анимацию из шаблона.
    /// Поворот (`rotationDegrees`) намеренно не копируется:
    /// у каждого меню он настраивается индивидуально. Размер иконки приложения в центре — тоже:
    /// он есть только у меню команд, и копия из обычного меню затёрла бы настройку значением по умолчанию.
    /// Не меняет id, имя, хоткей и пункты — их собственные цвета тоже остаются.
    mutating func applySharedVisualSettings(from template: PieMenu) {
        colorScheme = template.colorScheme
        iconStyle = template.iconStyle
        menuRadius = template.menuRadius
        innerRadius = Self.clampedInnerRadius(template.innerRadius, outerRadius: template.menuRadius)
        iconDistance = template.iconDistance
        iconSize = template.iconSize
        appearanceScale = template.appearanceScale
        liquidGlass = template.liquidGlass
        animationDuration = template.animationDuration
        pawDecorationEnabled = template.pawDecorationEnabled
        pawSizeScale = template.pawSizeScale
        pawRadialInset = template.pawRadialInset
        centerCatScale = template.centerCatScale
        shortcutDigitSizeScale = template.shortcutDigitSizeScale
        shortcutDigitInsetLeftScale = template.shortcutDigitInsetLeftScale
        shortcutDigitInsetRightScale = template.shortcutDigitInsetRightScale
        shortcutDigitOpacity = template.shortcutDigitOpacity
        shortcutDigitColorHex = template.shortcutDigitColorHex
        catColorHex = template.catColorHex
        pawColorHex = template.pawColorHex
        showsHoverLabel = template.showsHoverLabel
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case hotkey
        case items
        case kind
        case runningAppsExcludedBundleIds
        case runningAppsMenuEnabled
        case trackpadFingerCount
        case menuRadius
        case innerRadius
        case iconDistance
        case iconSize
        case appearanceScale
        case rotationDegrees
        case liquidGlass
        case animationDuration
        case pawDecorationEnabled
        case pawSizeScale
        case pawRadialInset
        case centerCatScale
        case centerAppIconScale
        case appCommandsDefaultEntries
        case shortcutDigitSizeScale
        case shortcutDigitInsetLeftScale
        case shortcutDigitInsetRightScale
        case shortcutDigitCornerInsetScale // legacy fallback
        case shortcutDigitOpacity
        case shortcutDigitColorHex
        case catColorHex
        case pawColorHex
        case showsHoverLabel
        case globalSidebarIconColorHex
        case colorScheme
        case iconStyle
        case themeID
        case accent // legacy decode only: цвет меню из промежуточной версии
    }

    /// Набор по умолчанию есть только у меню команд; пустым он быть не может — меню без секторов бесполезно.
    private static func resolvedAppCommandsDefaultEntries(_ entries: [AppSubMenuEntry], kind: PieMenuKind) -> [AppSubMenuEntry] {
        guard kind == .appCommands else { return [] }
        return entries.isEmpty ? AppSubMenuEntry.automaticBuiltIns : entries
    }

    /// Копия меню для списка: новые id у меню и пунктов, без хоткея и жеста — они у одного меню,
    /// и копия с тем же сочетанием только перехватывала бы его у оригинала.
    func duplicated(named name: String) -> PieMenu {
        var copy = self
        copy.id = UUID()
        copy.name = name
        copy.hotkey = .empty
        copy.trackpadFingerCount = 0
        copy.items = items.map { item in
            var item = item
            item.id = UUID()
            return item
        }
        copy.appCommandsDefaultEntries = appCommandsDefaultEntries.map(\.withNewID)
        return copy
    }

    /// Первый свободный номер сектора: пункты удаляли и переставляли, и номера идут с пропусками.
    var nextFreeSectorIndex: Int {
        let used = Set(items.map(\.sectorIndex))
        return (0...).first { !used.contains($0) } ?? items.count
    }

    /// Визуальный образец для новых меню: «Main», иначе первое обычное меню.
    static func mainTemplateMenu(from menus: [PieMenu]) -> PieMenu? {
        let standard = menus.filter { !$0.isDynamicMenu }
        return standard.first { $0.name.lowercased() == "main" } ?? standard.first
    }
}

struct PieConfiguration: Codable, Equatable {
    /// Текущая версия схемы конфига. Инкрементируется при изменении формата данных,
    /// чтобы при декоде применять миграции и не терять совместимость со старыми установками.
    /// 2 — пустые пункты больше не получают общую иконку кота (см. `PieConfigurationMigrator`).
    /// 3 — в наборе по умолчанию меню команд восемь команд вместо шести.
    static let currentSchemaVersion: Int = 3

    var schemaVersion: Int
    var menus: [PieMenu]
    var language: AppLanguage
    /// Тактильная отдача при наведении на секторы и в редакторе.
    var hapticFeedbackEnabled: Bool
    /// Светлое или тёмное оформление окон приложения; по умолчанию — как в системе.
    var appearance: AppAppearance
    /// Свои наборы команд меню «Команды приложения» для отдельных приложений; остальным команды подбираются автоматически.
    var appSubMenus: [AppSubMenu]
    /// Свои темы пользователя — рядом с готовыми в галерее любого меню.
    var customThemes: [CustomMenuTheme]
    /// Метка времени сохранения: нужна, чтобы не затирать свежие локальные правки устаревшими данными из iCloud.
    var lastModified: Date

    init(
        menus: [PieMenu],
        language: AppLanguage = .english,
        hapticFeedbackEnabled: Bool = true,
        appearance: AppAppearance = .system,
        appSubMenus: [AppSubMenu] = [],
        customThemes: [CustomMenuTheme] = [],
        lastModified: Date = Date(),
        schemaVersion: Int = PieConfiguration.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.menus = menus
        self.language = language
        self.hapticFeedbackEnabled = hapticFeedbackEnabled
        self.appearance = appearance
        self.appSubMenus = appSubMenus
        self.customThemes = customThemes
        self.lastModified = lastModified
    }

    /// Какое меню открывает касание каждым числом пальцев. Настройки не дают назначить одно число
    /// двум меню, но импортированный конфиг может — тогда побеждает меню ниже в списке.
    /// Выключенные динамические меню жест не открывают.
    func trackpadGestureTargets() -> [Int: Int] {
        var targets: [Int: Int] = [:]
        for (index, menu) in menus.enumerated() where TrackpadGesture.isEnabled(fingerCount: menu.trackpadFingerCount) {
            targets[menu.trackpadFingerCount] = index
        }
        return targets.filter { _, index in
            let menu = menus[index]
            return !(menu.isDynamicMenu && !menu.runningAppsMenuEnabled)
        }
    }

    /// Назначает меню касание `fingerCount` пальцами (0 — выключить). Одно число пальцев открывает
    /// одно меню, поэтому у остальных меню это число снимается.
    mutating func assignTrackpadFingerCount(_ fingerCount: Int, toMenuId menuId: UUID) {
        guard let index = menus.firstIndex(where: { $0.id == menuId }) else { return }
        let count = TrackpadGesture.isEnabled(fingerCount: fingerCount) ? fingerCount : 0
        if count != 0 {
            for i in menus.indices where i != index && menus[i].trackpadFingerCount == count {
                menus[i].trackpadFingerCount = 0
            }
        }
        menus[index].trackpadFingerCount = count
    }

    func appSubMenu(for bundleIdentifier: String) -> AppSubMenu? {
        appSubMenus.first { $0.matches(bundleIdentifier: bundleIdentifier) }
    }

    /// Копия обычного меню сразу за оригиналом; `nil` — такого меню нет или оно встроенное.
    @discardableResult
    mutating func duplicateMenu(id: UUID, name: String) -> PieMenu? {
        guard let index = menus.firstIndex(where: { $0.id == id }), !menus[index].isDynamicMenu else { return nil }
        let copy = menus[index].duplicated(named: name)
        menus.insert(copy, at: index + 1)
        return copy
    }

    /// Другое включённое меню с тем же сочетанием: по нему хоткей откроет то из них, что выше в списке.
    func menuSharingHotkey(with menu: PieMenu) -> PieMenu? {
        guard !menu.hotkey.isEmpty else { return nil }
        return menus.first {
            $0.id != menu.id && $0.hotkey == menu.hotkey && !($0.isDynamicMenu && !$0.runningAppsMenuEnabled)
        }
    }

    /// Меню команд в том виде, в каком оно откроется в приложении: у своего набора может быть
    /// свой поворот и свой вид.
    func appCommandsMenu(_ menu: PieMenu, for bundleIdentifier: String) -> PieMenu {
        var result = menu
        guard let set = appSubMenu(for: bundleIdentifier) else { return result }
        if let rotation = set.rotationDegrees {
            result.rotationDegrees = rotation
        }
        set.look?.apply(to: &result)
        return result
    }

    /// Набор приложения как обычное меню: вид (свой или общий), поворот и команды набора
    /// в `appCommandsDefaultEntries`. Так его редактируют тем же превью и той же панелью, что и остальные меню.
    func appSetMenu(for bundleIdentifier: String) -> PieMenu? {
        guard let set = appSubMenu(for: bundleIdentifier),
              let shared = menus.first(where: \.isAppCommandsMenu) else { return nil }
        var menu = appCommandsMenu(shared, for: bundleIdentifier)
        menu.appCommandsDefaultEntries = set.entries
        return menu
    }

    /// Записывает правку меню набора обратно: команды и поворот — в набор, вид — в свой вид набора,
    /// а если своего нет — в общее меню «Команды приложения».
    mutating func updateAppSetMenu(_ menu: PieMenu, for bundleIdentifier: String) {
        guard let old = appSetMenu(for: bundleIdentifier),
              let setIndex = appSubMenus.firstIndex(where: { $0.matches(bundleIdentifier: bundleIdentifier) }),
              let sharedIndex = menus.firstIndex(where: \.isAppCommandsMenu) else { return }
        if menu.appCommandsDefaultEntries != old.appCommandsDefaultEntries {
            appSubMenus[setIndex].entries = menu.appCommandsDefaultEntries
        }
        if menu.rotationDegrees != old.rotationDegrees {
            appSubMenus[setIndex].rotationDegrees = menu.rotationDegrees
        }
        let look = MenuLook(menu)
        guard look != MenuLook(old) else { return }
        if appSubMenus[setIndex].look != nil {
            appSubMenus[setIndex].look = look
        } else {
            look.apply(to: &menus[sharedIndex])
        }
    }

    /// Свой вид у набора: включение начинает с общего вида, выключение возвращает общий.
    mutating func setAppSetHasOwnLook(_ ownLook: Bool, for bundleIdentifier: String) {
        guard let setIndex = appSubMenus.firstIndex(where: { $0.matches(bundleIdentifier: bundleIdentifier) }),
              let shared = menus.first(where: \.isAppCommandsMenu) else { return }
        appSubMenus[setIndex].look = ownLook ? MenuLook(shared) : nil
    }

    // MARK: - Свои темы

    /// Новая тема из вида меню. Меню к ней не привязывается — это делает `PieMenu.applyTheme`.
    @discardableResult
    mutating func createTheme(named name: String, from menu: PieMenu) -> CustomMenuTheme {
        let theme = CustomMenuTheme(name: name, menu: menu)
        customThemes.append(theme)
        return theme
    }

    /// Сохранить вид меню в тему и разнести его по всем меню этой темы: обычным, встроенным
    /// и своим видам наборов приложений.
    mutating func saveTheme(_ id: UUID, from menu: PieMenu) {
        guard let index = customThemes.firstIndex(where: { $0.id == id }) else { return }
        customThemes[index].update(from: menu)
        let theme = customThemes[index]
        for i in menus.indices where menus[i].themeID == id {
            menus[i].applyTheme(theme)
        }
        for i in appSubMenus.indices where appSubMenus[i].look?.themeID == id {
            appSubMenus[i].look = appSubMenus[i].look.map { Self.look($0, restyledWith: theme) }
        }
    }

    /// Удалить тему. Её меню сохраняют свой вид, но больше к ней не привязаны.
    mutating func deleteTheme(_ id: UUID) {
        customThemes.removeAll { $0.id == id }
        for i in menus.indices where menus[i].themeID == id {
            menus[i].themeID = nil
        }
        for i in appSubMenus.indices where appSubMenus[i].look?.themeID == id {
            appSubMenus[i].look?.themeID = nil
        }
    }

    private static func look(_ look: MenuLook, restyledWith theme: CustomMenuTheme) -> MenuLook {
        var menu = PieMenu()
        look.apply(to: &menu)
        menu.applyTheme(theme)
        return MenuLook(menu)
    }

    /// Команды для приложений без своего набора — из меню «Команды приложения».
    var defaultAppCommands: [AppSubMenuEntry] {
        menus.first(where: \.isAppCommandsMenu)?.appCommandsDefaultEntries ?? AppSubMenuEntry.automaticBuiltIns
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case menus
        case language
        case hapticFeedbackEnabled
        case appearance
        case appSubMenus
        case customThemes
        case trackpadGesture // legacy decode only: общий жест из системных настроек
        case lastModified
        case items, hotkey, menuRadius, animationDuration, menuBehavior // menuBehavior: legacy decode only
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 0
        if container.contains(.menus) {
            menus = try container.decode([PieMenu].self, forKey: .menus)
            let appBound = try container.decode([LegacyAppBinding].self, forKey: .menus).map(\.isBoundToApp)
            menus = zip(menus, appBound).filter { !$0.1 }.map(\.0)
            language = try container.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .english
            hapticFeedbackEnabled = try container.decodeIfPresent(Bool.self, forKey: .hapticFeedbackEnabled) ?? true
            appearance = (try? container.decodeIfPresent(String.self, forKey: .appearance))
                .flatMap(AppAppearance.init(rawValue:)) ?? .system
            appSubMenus = try container.decodeIfPresent([AppSubMenu].self, forKey: .appSubMenus) ?? []
            customThemes = (try? container.decodeIfPresent([LossyCustomMenuTheme].self, forKey: .customThemes))?
                .compactMap(\.theme) ?? []
            lastModified = try container.decodeIfPresent(Date.self, forKey: .lastModified) ?? .distantPast
            if let legacyGesture = try? container.decodeIfPresent(LegacyTrackpadGesture.self, forKey: .trackpadGesture) {
                legacyGesture.moveIntoMenu(of: &menus)
            }
        } else {
            let items = try container.decode([PieMenuItem].self, forKey: .items)
            let hotkey = try container.decode(HotkeyConfig.self, forKey: .hotkey)
            let radius = try container.decode(Double.self, forKey: .menuRadius)
            let duration = try container.decode(Double.self, forKey: .animationDuration)
            _ = try container.decodeIfPresent(String.self, forKey: .menuBehavior)
            menus = [PieMenu(name: "Main", hotkey: hotkey, items: items,
                            menuRadius: radius, animationDuration: duration)]
            language = .english
            hapticFeedbackEnabled = true
            appearance = .system
            appSubMenus = []
            customThemes = []
            lastModified = .distantPast
        }
        PieConfigurationMigrator.migrate(&self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try container.encode(menus, forKey: .menus)
        try container.encode(language, forKey: .language)
        try container.encode(hapticFeedbackEnabled, forKey: .hapticFeedbackEnabled)
        try container.encode(appearance, forKey: .appearance)
        try container.encode(appSubMenus, forKey: .appSubMenus)
        try container.encode(customThemes, forKey: .customThemes)
        try container.encode(lastModified, forKey: .lastModified)
    }

    /// Раньше меню можно было привязать к приложению (`boundAppBundleId`). Их заменило меню
    /// «Команды приложения» со своими наборами команд, поэтому такие меню из старых конфигов отбрасываются.
    /// У динамических меню поле игнорировалось и раньше.
    private struct LegacyAppBinding: Decodable {
        let boundAppBundleId: String?
        let kind: PieMenuKind?
        var isBoundToApp: Bool { boundAppBundleId != nil && (kind ?? .standard) == .standard }
    }

    /// Раньше жест обычных меню был один на всё приложение и настраивался в системных параметрах:
    /// число пальцев и меню (`nil` или удалённое — первое обычное; меню команд — никогда, у него был свой).
    /// Теперь жест хранит каждое меню, и старое значение переезжает в то меню, которое он открывал.
    /// Если это число уже занято своим жестом меню, оно и раньше побеждало — тогда переносить нечего.
    private struct LegacyTrackpadGesture: Decodable {
        let fingerCount: Int?
        let menuId: UUID?

        func moveIntoMenu(of menus: inout [PieMenu]) {
            guard let fingerCount, TrackpadGesture.isEnabled(fingerCount: fingerCount),
                  !menus.contains(where: { $0.trackpadFingerCount == fingerCount }) else { return }
            let chosen = menus.firstIndex { $0.id == menuId && !$0.isAppCommandsMenu }
            guard let index = chosen ?? menus.firstIndex(where: { !$0.isDynamicMenu }),
                  menus[index].trackpadFingerCount == 0 else { return }
            menus[index].trackpadFingerCount = fingerCount
        }
    }

    /// Шаблон единственного меню «запущенные приложения» (имя можно сменить в редакторе).
    static func templateRunningAppsMenu() -> PieMenu {
        PieMenu(
            name: "Active apps",
            hotkey: HotkeyConfig(keyCode: KeyCodes.tab, carbonModifiers: CarbonModifiers.command),
            items: [],
            kind: .runningApps,
            runningAppsExcludedBundleIds: []
        )
    }

    /// Шаблон единственного меню команд активного приложения. Хоткея по умолчанию нет — его назначает пользователь.
    /// Лапки нет: в центре иконка приложения, а не кот, и лапка рядом с ней выглядит лишней.
    static func templateAppCommandsMenu() -> PieMenu {
        PieMenu(
            name: "App commands",
            hotkey: .empty,
            items: [],
            kind: .appCommands,
            rotationDegrees: AppSubMenuEntry.automaticRingRotationDegrees,
            pawDecorationEnabled: false,
            iconStyle: .white
        )
    }

    /// В конфиге всегда ровно по одному динамическому меню каждого вида: лишние удаляются,
    /// при отсутствии добавляется шаблон.
    mutating func ensureDynamicMenusInvariant() {
        ensureSingleMenu(of: .runningApps, template: Self.templateRunningAppsMenu())
        ensureSingleMenu(of: .appCommands, template: Self.templateAppCommandsMenu())
    }

    private mutating func ensureSingleMenu(of kind: PieMenuKind, template: PieMenu) {
        let indices = menus.enumerated().filter { $0.element.kind == kind }.map(\.offset)
        if indices.isEmpty {
            menus.append(template)
            return
        }
        for idx in indices.dropFirst().reversed() {
            menus.remove(at: idx)
        }
    }

    static var defaultConfig: PieConfiguration {
        PieConfiguration(menus: [
            PieMenu(
                name: "Main",
                hotkey: .defaultHotkey,
                items: [
                    PieMenuItem(title: "Safari", icon: "safari",
                        action: .launchApp(bundleIdentifier: "com.apple.Safari"), color: "#007AFF", sectorIndex: 0),
                    PieMenuItem(title: "Terminal", icon: "terminal",
                        action: .launchApp(bundleIdentifier: "com.apple.Terminal"), color: "#28CD41", sectorIndex: 1),
                    PieMenuItem(title: "Finder", icon: "folder.fill",
                        action: .launchApp(bundleIdentifier: "com.apple.finder"), color: "#5AC8FA", sectorIndex: 2),
                    PieMenuItem(title: "Settings", icon: "gearshape.fill",
                        action: .launchApp(bundleIdentifier: "com.apple.systempreferences"), color: "#8E8E93", sectorIndex: 3),
                    PieMenuItem(title: "Music", icon: "music.note",
                        action: .launchApp(bundleIdentifier: "com.apple.Music"), color: "#FF2D55", sectorIndex: 4),
                    PieMenuItem(title: "Notes", icon: "note.text",
                        action: .launchApp(bundleIdentifier: "com.apple.Notes"), color: "#FFCC00", sectorIndex: 5)
                ],
                animationDuration: 0.2,
                globalSidebarIconColorHex: PieMenuItem.paletteColor(for: 0)
            ),
            templateRunningAppsMenu(),
            templateAppCommandsMenu()
        ], language: .english)
    }
}
