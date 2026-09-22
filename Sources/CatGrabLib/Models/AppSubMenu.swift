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
    /// Свой вид меню только для этого приложения; `nil` — общий вид меню «Команды приложения».
    var look: MenuLook?

    var id: String { bundleIdentifier.lowercased() }

    init(
        bundleIdentifier: String,
        entries: [AppSubMenuEntry] = [],
        rotationDegrees: Double? = nil,
        look: MenuLook? = nil
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.entries = entries
        self.rotationDegrees = rotationDegrees
        self.look = look
    }

    func matches(bundleIdentifier other: String) -> Bool {
        bundleIdentifier.caseInsensitiveCompare(other) == .orderedSame
    }

    private enum CodingKeys: String, CodingKey {
        case bundleIdentifier, entries, rotationDegrees, look
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bundleIdentifier = try container.decode(String.self, forKey: .bundleIdentifier)
        // Запись незнакомого вида (из будущей версии) пропускаем, а не роняем весь конфиг.
        let lossy = try container.decodeIfPresent([LossyAppSubMenuEntry].self, forKey: .entries) ?? []
        entries = lossy.compactMap(\.entry)
        rotationDegrees = try container.decodeIfPresent(Double.self, forKey: .rotationDegrees)
        // Вид из будущей версии, который не читается, — не повод терять набор: остаётся общий вид.
        look = try? container.decodeIfPresent(MenuLook.self, forKey: .look)
    }
}

/// Команда незнакомого вида (из будущей версии) при чтении списка пропускается, а не роняет весь конфиг.
struct LossyAppSubMenuEntry: Decodable {
    let entry: AppSubMenuEntry?

    init(from decoder: Decoder) throws {
        entry = try? AppSubMenuEntry(from: decoder)
    }
}

/// Один сектор меню команд: пункт из меню приложения, встроенная команда или своё действие —
/// то же, что у пункта обычного меню (приложение, ссылка, сочетание клавиш, действие macOS, текст).
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

    /// «Завершить» по умолчанию предупреждающе-красный, чтобы его не спутать с безобидными соседями.
    static let destructiveColorHex = "#FF453B"

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
        /// Своё действие сектора (`action`), как у пункта обычного меню.
        case action

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
            case .menuItem, .hideApp, .quitApp, .action: return false
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
            case .action: return "square.dashed"
            }
        }

        func title(appName: String, language: AppLanguage) -> String {
            switch self {
            case .menuItem, .action: return ""
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
    /// Свой цвет сектора; `nil` — цвет темы по месту, как у пунктов обычных меню.
    var color: String?
    /// Свой цвет иконки; `nil` — как задано в меню («Цветные» или «Белые» иконки).
    var iconColor: String?
    /// Своя клавиша быстрого выбора (A–Z, 0–9); `nil` — по позиции.
    var customShortcut: String?
    /// Для `action`: что делает сектор и его название.
    var action: MenuAction?
    var title: String?

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
        self.color = Self.defaultColor(for: kind)
    }

    static func defaultColor(for kind: Kind) -> String? {
        kind == .quitApp ? destructiveColorHex : nil
    }

    /// Цвет сектора или иконки отличается от того, с каким команда добавляется.
    var hasCustomColors: Bool {
        color != Self.defaultColor(for: kind) || (iconColor != nil && hasTintableIcon)
    }

    /// Эмодзи и картинки рисуются своими цветами — цвет иконки к ним не применяется.
    var hasTintableIcon: Bool {
        let icon = resolvedIcon
        if icon.hasPrefix("app:") || icon.hasPrefix("file:") { return false }
        return icon.hasPrefix("text:") || icon.allSatisfy(\.isASCII)
    }

    mutating func resetColors() {
        color = Self.defaultColor(for: kind)
        iconColor = nil
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

    /// Название сектора: пункта меню, встроенной команды или своего действия.
    func displayTitle(appName: String, language: AppLanguage) -> String {
        switch kind {
        case .menuItem: return menuTitle
        case .action: return title ?? ""
        default: return kind.title(appName: appName, language: language)
        }
    }

    /// Иконка в секторе: выбранная пользователем или подобранная по названию и сочетанию.
    var resolvedIcon: String {
        if let icon, !icon.isEmpty { return icon }
        if kind == .menuItem { return SubActionIconGuess.icon(title: menuTitle, shortcut: shortcut) }
        return kind.defaultIcon
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, menuPath, shortcutCharacter, shortcutModifiers, icon, color, iconColor, customShortcut
        case action, title
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        kind = try container.decode(Kind.self, forKey: .kind)
        menuPath = try container.decodeIfPresent([String].self, forKey: .menuPath) ?? []
        shortcutCharacter = try container.decodeIfPresent(String.self, forKey: .shortcutCharacter)
        shortcutModifiers = try container.decodeIfPresent(Int.self, forKey: .shortcutModifiers)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        // Ключ пишется всегда, в том числе пустым: «как в теме» у «Завершить» — осознанный выбор.
        // Нет ключа — набор из версии без цветов команд: «Завершить» остаётся красным.
        color = container.contains(.color)
            ? try container.decodeIfPresent(String.self, forKey: .color)
            : Self.defaultColor(for: kind)
        iconColor = try container.decodeIfPresent(String.self, forKey: .iconColor)
        customShortcut = PieMenuItem.normalizedCustomShortcut(
            try container.decodeIfPresent(String.self, forKey: .customShortcut)
        )
        action = try container.decodeIfPresent(MenuAction.self, forKey: .action)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        if kind == .action, action == nil {
            throw DecodingError.dataCorruptedError(forKey: .action, in: container, debugDescription: "action sector needs an action")
        }
        if kind == .menuItem, menuPath.count < 2 {
            throw DecodingError.dataCorruptedError(
                forKey: .menuPath,
                in: container,
                debugDescription: "menuItem needs a path of at least two titles"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(menuPath, forKey: .menuPath)
        try container.encodeIfPresent(shortcutCharacter, forKey: .shortcutCharacter)
        try container.encodeIfPresent(shortcutModifiers, forKey: .shortcutModifiers)
        try container.encodeIfPresent(icon, forKey: .icon)
        try container.encode(color, forKey: .color)
        try container.encodeIfPresent(iconColor, forKey: .iconColor)
        try container.encodeIfPresent(customShortcut, forKey: .customShortcut)
        try container.encodeIfPresent(action, forKey: .action)
        try container.encodeIfPresent(title, forKey: .title)
    }
}

/// Сектор меню команд в инспекторе — тот же пункт, что у обычных меню. Команда приложения видна
/// там как пункт без действия (`unassigned`): что она делает, показывает сам инспектор.
extension AppSubMenuEntry {
    /// Своё действие из пункта обычного меню: действие, название, иконка, цвета и клавиша.
    init(action item: PieMenuItem) {
        self.init(kind: .action, icon: item.icon)
        action = item.action
        title = item.title
        color = item.usesThemeColor ? nil : item.color
        iconColor = item.iconColor
        customShortcut = item.customShortcut
    }

    /// Сектор как пункт обычного меню; `themeColor` — цвет, который сектор получает от темы.
    func asMenuItem(title: String, themeColor: String, sectorIndex: Int) -> PieMenuItem {
        PieMenuItem(
            id: id,
            title: title,
            icon: resolvedIcon,
            action: kind == .action ? action ?? .unassigned : .unassigned,
            color: color ?? themeColor,
            usesThemeColor: color == nil,
            iconColor: iconColor,
            sectorIndex: sectorIndex,
            customShortcut: customShortcut
        )
    }

    /// Правка из инспектора. Цвета, клавиша и иконка переносятся всегда. Действие — если сектор уже
    /// своё действие или ему только что выбрали действие вместо команды приложения.
    mutating func apply(_ item: PieMenuItem) {
        color = item.usesThemeColor ? nil : item.color
        iconColor = item.iconColor
        customShortcut = item.customShortcut
        if kind != .action, item.action == .unassigned {
            // Иконку, подобранную по названию, не записываем: пусть и дальше следует за командой.
            if item.icon != resolvedIcon { icon = item.icon }
            return
        }
        kind = .action
        action = item.action
        title = item.title
        icon = item.icon
        menuPath = []
        shortcutCharacter = nil
        shortcutModifiers = nil
    }

    /// Команда вместо того, что делал сектор; место, цвета и клавиша остаются. Цвет по умолчанию
    /// следует за командой: «Завершить» вместо другой команды станет красным, и наоборот.
    mutating func replaceCommand(with command: AppSubMenuEntry) {
        if color == Self.defaultColor(for: kind) {
            color = Self.defaultColor(for: command.kind)
        }
        kind = command.kind
        menuPath = command.menuPath
        shortcutCharacter = command.shortcutCharacter
        shortcutModifiers = command.shortcutModifiers
        icon = command.icon
        action = nil
        title = nil
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
