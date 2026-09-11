import AppKit
import Foundation
import CoreGraphics

struct PieMenuItem: Codable, Identifiable, Equatable {
    var id: UUID
    var title: String
    var icon: String
    var action: MenuAction
    var color: String
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

    /// Иконка по умолчанию для пункта с действием «не назначено».
    static let unassignedSFSymbol = "cat.fill"

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

    init(id: UUID = UUID(), title: String, icon: String, action: MenuAction, color: String = "#007AFF", iconColor: String? = nil, sectorIndex: Int = 0, customShortcut: String? = nil) {
        self.id = id
        self.title = title
        self.icon = icon
        self.action = action
        self.color = color
        self.iconColor = iconColor
        self.sectorIndex = sectorIndex
        self.customShortcut = PieMenuItem.normalizedCustomShortcut(customShortcut)
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, icon, action, color, iconColor, sectorIndex, customShortcut
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
    case standard = "standard"
    case runningApps = "runningApps"
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
    /// Для `runningApps` список `items` не используется при показе меню.
    var items: [PieMenuItem]
    var kind: PieMenuKind
    /// Bundle ID приложений, которые не показывать в меню запущенных (даже если открыты).
    var runningAppsExcludedBundleIds: [String]
    /// Для `runningApps`: включено ли меню (глобальный хоткей не регистрируется, пока выключено).
    var runningAppsMenuEnabled: Bool
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
    var boundAppBundleId: String?
    var boundAppName: String?
    /// Фон плитки с иконкой глобального меню в боковой панели (HEX). `nil` — старые конфиги, в UI — системный accent.
    var globalSidebarIconColorHex: String?

    var isGlobal: Bool { boundAppBundleId == nil }

    var isRunningAppsMenu: Bool { kind == .runningApps }

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
    /// Базовые коэффициенты шорткатов к ширине кольца сектора (`menuRadius - innerRadius`).
    static let shortcutDigitFontBaseFromRingWidth: Double = 0.13
    static let shortcutDigitInsetLeftBaseFromRingWidth: Double = 0.165
    static let shortcutDigitInsetRightBaseFromRingWidth: Double = 0.20
    private static let minCenterCatScale: Double = 0.45
    private static let maxCenterCatScale: Double = 1.2

    static func clampedCenterCatScale(_ value: Double) -> Double {
        min(max(value, minCenterCatScale), maxCenterCatScale)
    }

    static var centerCatScaleAllowedRange: ClosedRange<Double> { minCenterCatScale...maxCenterCatScale }

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

    init(id: UUID = UUID(), name: String = "Новое меню", hotkey: HotkeyConfig = .defaultHotkey,
         items: [PieMenuItem] = [], kind: PieMenuKind = .standard,
         runningAppsExcludedBundleIds: [String] = [], runningAppsMenuEnabled: Bool = true,
         menuRadius: Double = defaultMenuRadius,
         innerRadius: Double = defaultInnerRadius,
         iconDistance: Double? = nil, iconSize: Double = 42,
         appearanceScale: Double = defaultAppearanceScale,
         rotationDegrees: Double = 0,
         liquidGlass: LiquidGlassSettings = .default,
         animationDuration: Double = 0.2,
         pawDecorationEnabled: Bool = true,
         pawSizeScale: Double = PieMenu.defaultPawSizeScale,
         pawRadialInset: Double = PieMenu.defaultPawRadialInset,
         centerCatScale: Double = PieMenu.defaultCenterCatScale,
         shortcutDigitSizeScale: Double = PieMenu.defaultShortcutDigitSizeScale,
         shortcutDigitInsetLeftScale: Double = PieMenu.defaultShortcutDigitInsetLeftScale,
         shortcutDigitInsetRightScale: Double = PieMenu.defaultShortcutDigitInsetRightScale,
         shortcutDigitOpacity: Double = PieMenu.defaultShortcutDigitOpacity,
         shortcutDigitColorHex: String = PieMenu.defaultShortcutDigitColorHex,
         boundAppBundleId: String? = nil, boundAppName: String? = nil,
         globalSidebarIconColorHex: String? = nil) {
        self.id = id
        self.name = name
        self.hotkey = hotkey
        self.items = items
        self.kind = kind
        self.runningAppsExcludedBundleIds = runningAppsExcludedBundleIds
        self.runningAppsMenuEnabled = runningAppsMenuEnabled
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
        self.shortcutDigitSizeScale = Self.clampedShortcutDigitSizeScale(shortcutDigitSizeScale)
        self.shortcutDigitInsetLeftScale = Self.clampedShortcutDigitInsetLeftScale(shortcutDigitInsetLeftScale)
        self.shortcutDigitInsetRightScale = Self.clampedShortcutDigitInsetRightScale(shortcutDigitInsetRightScale)
        self.shortcutDigitOpacity = Self.clampedShortcutDigitOpacity(shortcutDigitOpacity)
        self.shortcutDigitColorHex = shortcutDigitColorHex
        self.boundAppBundleId = boundAppBundleId
        self.boundAppName = boundAppName
        self.globalSidebarIconColorHex = globalSidebarIconColorHex
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
        boundAppBundleId = try container.decodeIfPresent(String.self, forKey: .boundAppBundleId)
        boundAppName = try container.decodeIfPresent(String.self, forKey: .boundAppName)
        globalSidebarIconColorHex = try container.decodeIfPresent(String.self, forKey: .globalSidebarIconColorHex)
        kind = try container.decodeIfPresent(PieMenuKind.self, forKey: .kind) ?? .standard
        runningAppsExcludedBundleIds = Self.deduplicatedRunningAppsExcludedBundleIds(
            try container.decodeIfPresent([String].self, forKey: .runningAppsExcludedBundleIds) ?? []
        )
        runningAppsMenuEnabled = try container.decodeIfPresent(Bool.self, forKey: .runningAppsMenuEnabled) ?? true
        if kind == .runningApps {
            boundAppBundleId = nil
            boundAppName = nil
        }

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
        try container.encode(shortcutDigitSizeScale, forKey: .shortcutDigitSizeScale)
        try container.encode(shortcutDigitInsetLeftScale, forKey: .shortcutDigitInsetLeftScale)
        try container.encode(shortcutDigitInsetRightScale, forKey: .shortcutDigitInsetRightScale)
        try container.encode(shortcutDigitOpacity, forKey: .shortcutDigitOpacity)
        try container.encode(shortcutDigitColorHex, forKey: .shortcutDigitColorHex)
        try container.encodeIfPresent(boundAppBundleId, forKey: .boundAppBundleId)
        try container.encodeIfPresent(boundAppName, forKey: .boundAppName)
        try container.encodeIfPresent(globalSidebarIconColorHex, forKey: .globalSidebarIconColorHex)
    }

    /// Копирует размер кольца, внешний вид и анимацию из шаблона.
    /// Поворот (`rotationDegrees`) намеренно не копируется:
    /// у каждого меню он настраивается индивидуально.
    /// Не меняет id, имя, хоткей, элементы и привязку к приложению.
    mutating func applySharedVisualSettings(from template: PieMenu) {
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
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case hotkey
        case items
        case kind
        case runningAppsExcludedBundleIds
        case runningAppsMenuEnabled
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
        case shortcutDigitSizeScale
        case shortcutDigitInsetLeftScale
        case shortcutDigitInsetRightScale
        case shortcutDigitCornerInsetScale // legacy fallback
        case shortcutDigitOpacity
        case shortcutDigitColorHex
        case boundAppBundleId
        case boundAppName
        case globalSidebarIconColorHex
    }

    /// Визуальный образец для новых меню: «Main», иначе первое глобальное стандартное, иначе любое стандартное (не «запущенные приложения»).
    static func mainTemplateMenu(from menus: [PieMenu]) -> PieMenu? {
        let standard = menus.filter { !$0.isRunningAppsMenu && $0.kind == .standard }
        if let main = standard.first(where: { $0.name.lowercased() == "main" }) {
            return main
        }
        if let global = standard.first(where: { $0.isGlobal }) {
            return global
        }
        return standard.first
    }
}

struct PieConfiguration: Codable, Equatable {
    /// Текущая версия схемы конфига. Инкрементируется при изменении формата данных,
    /// чтобы при декоде применять миграции и не терять совместимость со старыми установками.
    static let currentSchemaVersion: Int = 1

    var schemaVersion: Int
    var menus: [PieMenu]
    var appMenuHotkey: HotkeyConfig
    var language: AppLanguage
    /// Тактильная отдача при наведении на секторы и в редакторе.
    var hapticFeedbackEnabled: Bool
    /// Метка времени сохранения: нужна, чтобы не затирать свежие локальные правки устаревшими данными из iCloud.
    var lastModified: Date

    init(
        menus: [PieMenu],
        appMenuHotkey: HotkeyConfig = .empty,
        language: AppLanguage = .english,
        hapticFeedbackEnabled: Bool = true,
        lastModified: Date = Date(),
        schemaVersion: Int = PieConfiguration.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.menus = menus
        self.appMenuHotkey = appMenuHotkey
        self.language = language
        self.hapticFeedbackEnabled = hapticFeedbackEnabled
        self.lastModified = lastModified
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case menus
        case appMenuHotkey
        case language
        case hapticFeedbackEnabled
        case lastModified
        case items, hotkey, menuRadius, animationDuration, menuBehavior // menuBehavior: legacy decode only
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 0
        if container.contains(.menus) {
            menus = try container.decode([PieMenu].self, forKey: .menus)
            let legacyShared = try container.decodeIfPresent(HotkeyConfig.self, forKey: .appMenuHotkey)
                ?? Self.legacyAppMenuHotkey(from: menus)
            if !legacyShared.isEmpty {
                for i in menus.indices where !menus[i].isGlobal && menus[i].hotkey.isEmpty {
                    menus[i].hotkey = legacyShared
                }
            }
            appMenuHotkey = .empty
            language = try container.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .english
            hapticFeedbackEnabled = try container.decodeIfPresent(Bool.self, forKey: .hapticFeedbackEnabled) ?? true
            lastModified = try container.decodeIfPresent(Date.self, forKey: .lastModified) ?? .distantPast
        } else {
            let items = try container.decode([PieMenuItem].self, forKey: .items)
            let hotkey = try container.decode(HotkeyConfig.self, forKey: .hotkey)
            let radius = try container.decode(Double.self, forKey: .menuRadius)
            let duration = try container.decode(Double.self, forKey: .animationDuration)
            _ = try container.decodeIfPresent(String.self, forKey: .menuBehavior)
            menus = [PieMenu(name: "Main", hotkey: hotkey, items: items,
                            menuRadius: radius, animationDuration: duration)]
            appMenuHotkey = .empty
            language = .english
            hapticFeedbackEnabled = true
            lastModified = .distantPast
        }
        PieConfigurationMigrator.migrate(&self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try container.encode(menus, forKey: .menus)
        try container.encode(appMenuHotkey, forKey: .appMenuHotkey)
        try container.encode(language, forKey: .language)
        try container.encode(hapticFeedbackEnabled, forKey: .hapticFeedbackEnabled)
        try container.encode(lastModified, forKey: .lastModified)
    }

    private static func legacyAppMenuHotkey(from menus: [PieMenu]) -> HotkeyConfig {
        menus.first(where: { !$0.isGlobal && !$0.hotkey.isEmpty })?.hotkey ?? .empty
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

    /// В конфиге всегда ровно одно меню `runningApps`: лишние удаляются, при отсутствии добавляется шаблон.
    mutating func ensureRunningAppsMenuInvariant() {
        let runningIndices = menus.enumerated().filter { $0.element.isRunningAppsMenu }.map(\.offset)
        if runningIndices.isEmpty {
            menus.append(Self.templateRunningAppsMenu())
            return
        }
        guard runningIndices.count > 1 else { return }
        for idx in runningIndices.dropFirst().reversed() {
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
                        action: .launchApp(bundleIdentifier: "com.apple.Notes"), color: "#FFCC00", sectorIndex: 5),
                ],
                animationDuration: 0.2,
                globalSidebarIconColorHex: PieMenuItem.paletteColor(for: 0)
            ),
            templateRunningAppsMenu(),
        ], appMenuHotkey: .empty, language: .english)
    }
}
