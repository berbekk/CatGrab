import Foundation

/// Свой набор команд меню «Команды приложения» для одного приложения. Нет записи — команды
/// подбираются автоматически (см. `PieSubActionResolver`).
struct AppSubMenu: Codable, Equatable, Identifiable {
    var bundleIdentifier: String
    /// По часовой стрелке от верха кольца.
    var entries: [AppSubMenuEntry]
    /// Свой поворот кольца: у наборов разное число секторов, и удобный поворот у них разный.
    /// `nil` — поворот меню «Команды приложения».
    var rotationDegrees: Double?

    var id: String { bundleIdentifier.lowercased() }

    init(bundleIdentifier: String, entries: [AppSubMenuEntry] = [], rotationDegrees: Double? = nil) {
        self.bundleIdentifier = bundleIdentifier
        self.entries = entries
        self.rotationDegrees = rotationDegrees
    }

    func matches(bundleIdentifier other: String) -> Bool {
        bundleIdentifier.caseInsensitiveCompare(other) == .orderedSame
    }

    private enum CodingKeys: String, CodingKey {
        case bundleIdentifier, entries, rotationDegrees
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bundleIdentifier = try container.decode(String.self, forKey: .bundleIdentifier)
        // Запись незнакомого вида (из будущей версии) пропускаем, а не роняем весь конфиг.
        let lossy = try container.decodeIfPresent([LossyAppSubMenuEntry].self, forKey: .entries) ?? []
        entries = lossy.compactMap(\.entry)
        rotationDegrees = try container.decodeIfPresent(Double.self, forKey: .rotationDegrees)
    }
}

/// Команда незнакомого вида (из будущей версии) при чтении списка пропускается, а не роняет весь конфиг.
struct LossyAppSubMenuEntry: Decodable {
    let entry: AppSubMenuEntry?

    init(from decoder: Decoder) throws {
        entry = try? AppSubMenuEntry(from: decoder)
    }
}

/// Одна команда в своём наборе: пункт из меню приложения или встроенная команда.
struct AppSubMenuEntry: Codable, Equatable, Identifiable {
    /// Набор по умолчанию, с которым создаётся меню «Команды приложения» (`PieMenu.appCommandsDefaultEntries`).
    /// Восемь секторов при повороте `automaticRingRotationDegrees` стоят серединами ровно на верх, низ,
    /// бока и диагонали: каждая половина экрана — на своей стороне кольца, а полный экран, «Заполнить»,
    /// «По центру» и «Завершить» — на диагоналях между ними.
    static var automaticBuiltIns: [AppSubMenuEntry] {
        let kinds: [Kind] = [
            .tileTop, .toggleFullScreen, .tileRight, .fillScreen, .tileBottom, .quitApp, .tileLeft, .centerWindow
        ]
        return kinds.map { AppSubMenuEntry(kind: $0) }
    }

    /// Первый из восьми секторов начинается у верха кольца; поворот на полсектора ставит его серединой наверх.
    static let automaticRingRotationDegrees: Double = -22.5

    enum Kind: String, Codable, CaseIterable {
        case menuItem
        case hideApp
        case minimizeWindow
        case toggleFullScreen
        case tileLeft
        case tileRight
        case tileTop
        case tileBottom
        case fillScreen
        case centerWindow
        case closeWindow
        case quitApp

        /// Встроенные команды — в том порядке, в каком их предлагает редактор.
        static let builtIns: [Kind] = [
            .toggleFullScreen, .tileLeft, .tileRight, .tileTop, .tileBottom, .fillScreen, .centerWindow,
            .minimizeWindow, .closeWindow, .hideApp, .quitApp
        ]

        /// Команда работает с окном приложения: без окна она недоступна.
        var needsWindow: Bool {
            switch self {
            case .minimizeWindow, .toggleFullScreen, .tileLeft, .tileRight, .tileTop, .tileBottom, .fillScreen,
                 .centerWindow, .closeWindow:
                return true
            case .menuItem, .hideApp, .quitApp: return false
            }
        }

        var defaultIcon: String {
            switch self {
            case .menuItem: return "command"
            case .hideApp: return "eye.slash"
            case .minimizeWindow: return "minus.square"
            case .toggleFullScreen: return "arrow.up.left.and.arrow.down.right"
            case .tileLeft: return "rectangle.lefthalf.filled"
            case .tileRight: return "rectangle.righthalf.filled"
            case .tileTop: return "rectangle.tophalf.filled"
            case .tileBottom: return "rectangle.bottomhalf.filled"
            case .fillScreen: return "rectangle.inset.filled"
            case .centerWindow: return "rectangle.center.inset.filled"
            case .closeWindow: return "xmark.square"
            case .quitApp: return "power"
            }
        }

        func title(appName: String, language: AppLanguage) -> String {
            switch self {
            case .menuItem: return ""
            case .hideApp: return MenuTitles.hide(appName: appName, language: language)
            case .minimizeWindow: return MenuTitles.minimize(language: language)
            case .toggleFullScreen: return MenuTitles.toggleFullScreen(language: language)
            case .tileLeft: return MenuTitles.tileLeft(language: language)
            case .tileRight: return MenuTitles.tileRight(language: language)
            case .tileTop: return MenuTitles.tileTop(language: language)
            case .tileBottom: return MenuTitles.tileBottom(language: language)
            case .fillScreen: return MenuTitles.fillScreen(language: language)
            case .centerWindow: return MenuTitles.centerWindow(language: language)
            case .closeWindow: return MenuTitles.closeWindow(language: language)
            case .quitApp: return MenuTitles.quit(appName: appName, language: language)
            }
        }
    }

    var id: UUID
    var kind: Kind
    /// Для `menuItem`: путь по названиям от меню в строке меню до пункта, например `["Файл", "Новое окно"]`.
    var menuPath: [String]
    /// Сочетание пункта — запасной способ найти его, если название поменялось
    /// (переключатели вроде «Показать / Скрыть боковую панель»).
    var shortcutCharacter: String?
    var shortcutModifiers: Int?
    /// Своя иконка команды; `nil` — подобрать по названию.
    var icon: String?

    init(
        id: UUID = UUID(),
        kind: Kind,
        menuPath: [String] = [],
        shortcut: MenuShortcut? = nil,
        icon: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.menuPath = menuPath
        self.shortcutCharacter = shortcut?.character
        self.shortcutModifiers = shortcut?.modifiers.rawValue
        self.icon = icon
    }

    /// Та же команда с новым id — для копии в другой набор.
    var withNewID: AppSubMenuEntry {
        var copy = self
        copy.id = UUID()
        return copy
    }

    var shortcut: MenuShortcut? {
        guard let shortcutCharacter, !shortcutCharacter.isEmpty else { return nil }
        return MenuShortcut(shortcutCharacter, MenuShortcut.Modifiers(rawValue: shortcutModifiers ?? 0))
    }

    /// Название пункта меню — последняя часть пути.
    var menuTitle: String { menuPath.last ?? "" }

    /// Иконка в секторе: выбранная пользователем или подобранная по названию и сочетанию.
    var resolvedIcon: String {
        if let icon, !icon.isEmpty { return icon }
        if kind == .menuItem { return SubActionIconGuess.icon(title: menuTitle, shortcut: shortcut) }
        return kind.defaultIcon
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, menuPath, shortcutCharacter, shortcutModifiers, icon
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        kind = try container.decode(Kind.self, forKey: .kind)
        menuPath = try container.decodeIfPresent([String].self, forKey: .menuPath) ?? []
        shortcutCharacter = try container.decodeIfPresent(String.self, forKey: .shortcutCharacter)
        shortcutModifiers = try container.decodeIfPresent(Int.self, forKey: .shortcutModifiers)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        if kind == .menuItem, menuPath.count < 2 {
            throw DecodingError.dataCorruptedError(
                forKey: .menuPath,
                in: container,
                debugDescription: "menuItem needs a path of at least two titles"
            )
        }
    }
}

/// Значок для пункта меню, у которого нет своего: по словам в названии, затем по сочетанию.
/// Слова точнее: ⇧⌘N у браузера — «частное окно», а у Finder — «новая папка». Слова — на английском
/// и русском, самых частых языках интерфейса; для остальных сработает сочетание или общий значок,
/// который пользователь может сменить в редакторе.
enum SubActionIconGuess {
    private static let keywords: [(words: [String], icon: String)] = [
        // Не «eye.slash»: так выглядит «Скрыть приложение», и две команды в одном кольце путались бы.
        (["private", "incognito", "приват", "частн", "инкогнито"], "sunglasses"),
        (["reopen", "closed", "закрытую", "закрытое", "закрытые", "вернуть"], "arrow.uturn.backward"),
        (["close", "закрыть"], "xmark.square"),
        (["tab", "вкладк"], "plus.square.on.square"),
        (["window", "окн"], "macwindow.badge.plus"),
        (["folder", "папк"], "folder.badge.plus"),
        (["settings", "preferences", "настройк", "параметр"], "gearshape"),
        (["print", "печат"], "printer"),
        (["export", "share", "экспорт", "поделиться"], "square.and.arrow.up"),
        (["save", "сохран"], "square.and.arrow.down"),
        (["find", "search", "найти", "поиск"], "magnifyingglass"),
        (["reload", "refresh", "обновить", "перезагруз"], "arrow.clockwise"),
        (["history", "истори"], "clock"),
        (["bookmark", "закладк"], "bookmark"),
        (["download", "загрузк"], "arrow.down.circle"),
        (["sidebar", "боков"], "sidebar.left"),
        (["open", "откры"], "folder"),
        (["new", "нов", "создать"], "plus.circle")
    ]

    static func icon(title: String, shortcut: MenuShortcut?) -> String {
        // По началу слова: так «вкладк» ловит «вкладку» и «вкладки», но не середину чужого слова.
        let words = title.lowercased().split(whereSeparator: { !$0.isLetter })
        for rule in keywords where rule.words.contains(where: { key in words.contains { $0.hasPrefix(key) } }) {
            return rule.icon
        }
        return shortcut.map(PieSubActionResolver.icon(for:)) ?? "command"
    }
}
