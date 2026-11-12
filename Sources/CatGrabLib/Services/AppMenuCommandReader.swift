import AppKit
import ApplicationServices

/// Сочетание клавиш пункта меню в терминах Accessibility (`AXMenuItemCmdChar` + `AXMenuItemCmdModifiers`).
struct MenuShortcut: Hashable {
    /// Биты `AXMenuItemCmdModifiers`: 0 — только ⌘.
    struct Modifiers: OptionSet, Hashable {
        let rawValue: Int
        static let shift = Modifiers(rawValue: 1 << 0)
        static let option = Modifiers(rawValue: 1 << 1)
        static let control = Modifiers(rawValue: 1 << 2)
        static let noCommand = Modifiers(rawValue: 1 << 3)
    }

    let character: String
    let modifiers: Modifiers

    init(_ character: String, _ modifiers: Modifiers = []) {
        self.character = character.uppercased()
        self.modifiers = modifiers
    }

    /// Подпись в стиле меню macOS: `⌃⌥⇧⌘N`.
    var displayString: String {
        var s = ""
        if modifiers.contains(.control) { s += "⌃" }
        if modifiers.contains(.option) { s += "⌥" }
        if modifiers.contains(.shift) { s += "⇧" }
        if !modifiers.contains(.noCommand) { s += "⌘" }
        return s + character
    }
}

/// Пункт меню приложения, найденный через Accessibility.
struct AppMenuItemInfo {
    /// Названия от меню в строке меню до самого пункта: `["Файл", "Новое окно"]`.
    let path: [String]
    let shortcut: MenuShortcut?
    let isEnabled: Bool
    let element: AXUIElement

    var title: String { path.last ?? "" }
}

/// Пункт меню приложения, который показан в меню команд.
struct AppMenuCommand: Equatable {
    let title: String
    let path: [String]
    let shortcut: MenuShortcut?
    let element: AXUIElement

    init(_ info: AppMenuItemInfo) {
        title = info.title
        path = info.path
        shortcut = info.shortcut
        element = info.element
    }

    static func == (lhs: AppMenuCommand, rhs: AppMenuCommand) -> Bool {
        lhs.path == rhs.path && lhs.shortcut == rhs.shortcut
    }
}

/// Читает строку меню чужого приложения через Accessibility. Все функции — не для главного потока:
/// каждый запрос — IPC к приложению.
enum AppMenuCommandReader {
    /// Бюджет на поиск пункта по сочетанию при вызове меню команд: оно должно открыться без заметной
    /// задержки, а большие приложения (Xcode) держат тысячи пунктов.
    static let quickScanBudget: TimeInterval = 0.35
    /// Бюджет для редактора: там пользователь ждёт полный список и видит индикатор загрузки.
    static let fullScanBudget: TimeInterval = 4
    /// Таймаут одного AX-запроса: зависшее приложение не должно держать очередь по 6 секунд (значение по умолчанию).
    static let messagingTimeout: Float = 0.2

    /// Все пункты меню приложения — для выбора в редакторе.
    static func allItems(pid: pid_t) -> [AppMenuItemInfo] {
        guard AXIsProcessTrusted() else { return [] }
        return readItems(pid: pid, budget: AXReadBudget(duration: fullScanBudget), maxDepth: 3)
    }

    /// Пункт по сохранённому пути, а если название поменялось — по сочетанию клавиш.
    static func item(pid: pid_t, path: [String], shortcut: MenuShortcut?) -> AppMenuItemInfo? {
        guard AXIsProcessTrusted() else { return nil }
        let budget = AXReadBudget(duration: quickScanBudget)
        if let found = walk(pid: pid, path: path, budget: budget) { return found }
        guard let shortcut else { return nil }
        return readItems(pid: pid, budget: budget, maxDepth: 3).first { $0.shortcut == shortcut }
    }

    // MARK: - Обход

    private static let itemAttributes = [
        kAXTitleAttribute,
        kAXMenuItemCmdCharAttribute,
        kAXMenuItemCmdModifiersAttribute,
        kAXEnabledAttribute,
        kAXChildrenAttribute
    ] as CFArray

    private struct ItemValues {
        let title: String?
        let shortcut: MenuShortcut?
        let isEnabled: Bool
        let submenus: [AXUIElement]
    }

    /// Меню в строке меню с их названиями. Меню Apple пропускаем — в нём нет команд приложения.
    private static func topMenus(pid: pid_t, budget: AXReadBudget) -> [(title: String, menus: [AXUIElement])] {
        let app = AXUIElementCreateApplication(pid)
        guard let menuBar: AXUIElement = readAttribute(app, kAXMenuBarAttribute, budget: budget),
              let barItems: [AXUIElement] = readAttribute(menuBar, kAXChildrenAttribute, budget: budget) else { return [] }
        return barItems.dropFirst().compactMap { barItem in
            guard let title: String = readAttribute(barItem, kAXTitleAttribute, budget: budget), !title.isEmpty else { return nil }
            return (title, readAttribute(barItem, kAXChildrenAttribute, budget: budget) ?? [])
        }
    }

    /// Обход в ширину: сначала пункты всех меню верхнего уровня, потом их подменю (там, например,
    /// «Новое окно с профилем» у Терминала), — чтобы при нехватке времени потерять самое глубокое.
    private static func readItems(pid: pid_t, budget: AXReadBudget, maxDepth: Int) -> [AppMenuItemInfo] {
        var pending: [(menu: AXUIElement, path: [String])] = topMenus(pid: pid, budget: budget).flatMap { top in
            top.menus.map { ($0, [top.title]) }
        }
        var result: [AppMenuItemInfo] = []
        var depth = 0
        while !pending.isEmpty, depth < maxDepth, !budget.isExpired {
            var nextLevel: [(menu: AXUIElement, path: [String])] = []
            for (menu, path) in pending {
                guard !budget.isExpired else { break }
                let items: [AXUIElement] = readAttribute(menu, kAXChildrenAttribute, budget: budget) ?? []
                for item in items {
                    guard !budget.isExpired else { break }
                    guard let values = values(of: item, budget: budget), let title = values.title, !title.isEmpty else { continue }
                    if !values.submenus.isEmpty {
                        nextLevel.append(contentsOf: values.submenus.map { ($0, path + [title]) })
                        continue
                    }
                    result.append(AppMenuItemInfo(
                        path: path + [title],
                        shortcut: values.shortcut,
                        isEnabled: values.isEnabled,
                        element: item
                    ))
                }
            }
            pending = nextLevel
            depth += 1
        }
        return result
    }

    /// Прямой спуск по названиям — намного дешевле полного обхода.
    private static func walk(pid: pid_t, path: [String], budget: AXReadBudget) -> AppMenuItemInfo? {
        guard path.count >= 2,
              let top = topMenus(pid: pid, budget: budget).first(where: { $0.title == path[0] }) else { return nil }
        var menus = top.menus
        for (offset, component) in path.dropFirst().enumerated() {
            guard let match = firstItem(titled: component, in: menus, budget: budget) else { return nil }
            let isLast = offset == path.count - 2
            if isLast {
                guard match.values.submenus.isEmpty else { return nil }
                return AppMenuItemInfo(
                    path: path,
                    shortcut: match.values.shortcut,
                    isEnabled: match.values.isEnabled,
                    element: match.element
                )
            }
            menus = match.values.submenus
        }
        return nil
    }

    private static func firstItem(titled title: String, in menus: [AXUIElement], budget: AXReadBudget) -> (element: AXUIElement, values: ItemValues)? {
        for menu in menus {
            guard !budget.isExpired else { return nil }
            let items: [AXUIElement] = readAttribute(menu, kAXChildrenAttribute, budget: budget) ?? []
            for item in items {
                guard !budget.isExpired else { return nil }
                if let values = values(of: item, budget: budget), values.title == title {
                    return (item, values)
                }
            }
        }
        return nil
    }

    /// Все атрибуты пункта одним IPC-запросом. Отсутствующий атрибут приходит как AXValue с ошибкой
    /// и просто не проходит приведение типа.
    private static func values(of element: AXUIElement, budget: AXReadBudget) -> ItemValues? {
        guard configureTimeout(element, budget: budget) else { return nil }
        var raw: CFArray?
        guard AXUIElementCopyMultipleAttributeValues(element, itemAttributes, [], &raw) == .success,
              let array = raw as? [Any], array.count == 5 else { return nil }
        return ItemValues(
            title: array[0] as? String,
            shortcut: shortcut(character: array[1], modifiers: array[2]),
            isEnabled: (array[3] as? Bool) ?? true,
            submenus: (array[4] as? [AXUIElement]) ?? []
        )
    }

    private static func shortcut(character: Any, modifiers: Any) -> MenuShortcut? {
        guard let character = character as? String,
              character.count == 1,
              let scalar = character.unicodeScalars.first,
              // Служебные глифы (стрелки, F-клавиши) приходят символами из Private Use Area — их не показываем.
              !(0xE000...0xF8FF).contains(scalar.value) else { return nil }
        let raw = (modifiers as? Int) ?? 0
        return MenuShortcut(character, MenuShortcut.Modifiers(rawValue: raw))
    }

    private static func configureTimeout(_ element: AXUIElement, budget: AXReadBudget) -> Bool {
        guard let timeout = budget.timeout() else { return false }
        return AXUIElementSetMessagingTimeout(element, timeout) == .success
    }

    private static func readAttribute<T>(_ element: AXUIElement, _ attribute: String, budget: AXReadBudget) -> T? {
        guard configureTimeout(element, budget: budget) else { return nil }
        return copyAttribute(element, attribute)
    }

    static func copyAttribute<T>(_ element: AXUIElement, _ attribute: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? T
    }
}
