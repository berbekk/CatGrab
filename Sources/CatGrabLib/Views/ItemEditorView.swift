import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ItemEditorView: View {
    /// Сектор меню команд: к обычным действиям добавляется «Команда приложения».
    struct AppCommandSlot {
        struct Summary {
            let title: String
            let caption: String
            let shortcut: String?
            let isMissing: Bool
        }

        /// Что делает сектор, если это команда приложения; `nil` — у сектора своё действие.
        let command: Summary?
        /// Открыть список команд приложения, чтобы выбрать команду для сектора.
        let choose: () -> Void
    }

    @Binding var item: PieMenuItem
    var onClose: (() -> Void)?
    let onDelete: () -> Void
    /// Цвет, который сектор получает от темы на своём месте, и цвета темы для палитры.
    let themeColor: String
    let themeColors: [String]
    /// Цвет иконки по теме: белый или цвет сектора.
    let iconThemeColor: String
    let appCommand: AppCommandSlot?

    @State private var actionType: ActionType?
    @State private var bundleId: String
    @State private var selectedAppName: String
    @State private var urlString: String
    @State private var keystrokeKeyCode: Int
    @State private var keystrokeModifiers: Int
    @State private var systemKind: MacOSSystemActionKind
    @State private var snippetText: String
    @State private var showIconPicker = false
    /// Название, которое подставили за пользователя (домен ссылки, сочетание, начало текста):
    /// пока оно не изменено вручную, его можно подставлять заново при смене действия.
    @State private var autoTitle: String?
    @State private var isIconHovered = false
    @State private var isBrowseAppHovered = false
    @State private var isCommandHovered = false
    @EnvironmentObject private var localizer: LocalizationStore

    enum ActionType: CaseIterable {
        /// Только в меню команд: пункт из меню приложения или встроенная команда окна.
        case appCommand
        case launchApp
        case openURL
        case keystroke
        case systemShortcut
        case snippet

        /// Действия, которые есть у сектора любого меню.
        static let regular: [ActionType] = allCases.filter { $0 != .appCommand }

        func title(_ localizer: LocalizationStore) -> String {
            switch self {
            case .appCommand:
                return localizer.text(.actionTypeAppCommand)
            case .launchApp:
                return localizer.text(.actionTypeApp)
            case .openURL:
                return localizer.text(.actionTypeUrl)
            case .keystroke:
                return localizer.text(.actionTypeKeystroke)
            case .systemShortcut:
                return localizer.text(.actionTypeSystem)
            case .snippet:
                return localizer.text(.actionTypeSnippet)
            }
        }
    }

    init(
        item: Binding<PieMenuItem>,
        themeColor: String = PieMenuItem.paletteColor(for: 0),
        themeColors: [String] = PieMenuItem.sectorPalette,
        iconThemeColor: String = PieMenuItem.paletteColor(for: 0),
        appCommand: AppCommandSlot? = nil,
        onClose: (() -> Void)? = nil,
        onDelete: @escaping () -> Void
    ) {
        _item = item
        self.themeColor = themeColor
        self.themeColors = themeColors
        self.iconThemeColor = iconThemeColor
        self.appCommand = appCommand
        self.onClose = onClose
        self.onDelete = onDelete

        let action = item.wrappedValue.action
        switch action {
        case .unassigned:
            _actionType = State(initialValue: nil)
            _bundleId = State(initialValue: "")
            _selectedAppName = State(initialValue: "")
            _urlString = State(initialValue: "")
            _keystrokeKeyCode = State(initialValue: 0)
            _keystrokeModifiers = State(initialValue: 0)
            _systemKind = State(initialValue: .missionControl)
            _snippetText = State(initialValue: "")
        case .launchApp(let id):
            _actionType = State(initialValue: .launchApp)
            _bundleId = State(initialValue: id)
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
                _selectedAppName = State(initialValue: FileManager.default.displayName(atPath: url.path))
            } else {
                _selectedAppName = State(initialValue: item.wrappedValue.title)
            }
            _urlString = State(initialValue: "")
            _keystrokeKeyCode = State(initialValue: 0)
            _keystrokeModifiers = State(initialValue: 0)
            _systemKind = State(initialValue: .missionControl)
            _snippetText = State(initialValue: "")
        case .openURL(let url):
            _actionType = State(initialValue: .openURL)
            _bundleId = State(initialValue: "")
            _selectedAppName = State(initialValue: "")
            _urlString = State(initialValue: url)
            _keystrokeKeyCode = State(initialValue: 0)
            _keystrokeModifiers = State(initialValue: 0)
            _systemKind = State(initialValue: .missionControl)
            _snippetText = State(initialValue: "")
        case .keystroke(let code, let mods):
            _actionType = State(initialValue: .keystroke)
            _bundleId = State(initialValue: "")
            _selectedAppName = State(initialValue: "")
            _urlString = State(initialValue: "")
            _keystrokeKeyCode = State(initialValue: code)
            _keystrokeModifiers = State(initialValue: mods)
            _systemKind = State(initialValue: .missionControl)
            _snippetText = State(initialValue: "")
        case .systemShortcut(let kind):
            _actionType = State(initialValue: .systemShortcut)
            _bundleId = State(initialValue: "")
            _selectedAppName = State(initialValue: "")
            _urlString = State(initialValue: "")
            _keystrokeKeyCode = State(initialValue: 0)
            _keystrokeModifiers = State(initialValue: 0)
            _systemKind = State(initialValue: kind)
            _snippetText = State(initialValue: "")
        case .snippet(let text):
            _actionType = State(initialValue: .snippet)
            _bundleId = State(initialValue: "")
            _selectedAppName = State(initialValue: "")
            _urlString = State(initialValue: "")
            _keystrokeKeyCode = State(initialValue: 0)
            _keystrokeModifiers = State(initialValue: 0)
            _systemKind = State(initialValue: .missionControl)
            _snippetText = State(initialValue: text)
        }
        if appCommand?.command != nil {
            _actionType = State(initialValue: .appCommand)
        }
    }

    private var segmentColor: Color {
        Color(hex: item.usesThemeColor ? themeColor : item.color) ?? .blue
    }

    private var resolvedIconColor: Color {
        Color(hex: item.iconColor ?? iconThemeColor) ?? segmentColor
    }

    var body: some View {
        InspectorPanel(title: localizer.text(.selectedItemParameters), onClose: onClose, onDelete: onDelete) {
            // Сначала что делает сектор, потом как он выглядит, в конце — клавиша.
            InspectorField(label: localizer.text(.actionType)) {
                actionTypePicker
            }

            // Без типа действия настраивать нечего — поле «Не назначено» только повторяло бы список выше.
            if actionType != nil {
                InspectorField(label: actionFieldLabel) {
                    actionFields
                }
            }

            // Название — это подпись сектора под курсором в кольце. Ссылке, сочетанию и тексту оно
            // подставляется само, а здесь его можно поправить.
            if actionType != .launchApp {
                InspectorField(label: localizer.text(.title)) {
                    ModernTextField(localizer.text(.title), text: $item.title)
                }
            }

            // У приложения иконка — его собственная.
            if actionType != .launchApp {
                InspectorField(label: localizer.text(.icon)) {
                    iconField
                }
            }

            InspectorField(label: localizer.text(.sectorColor)) {
                SectorColorField(item: $item, themeColor: themeColor, themeColors: themeColors)
            }

            // Эмодзи и значки приложений рисуются своими цветами — перекрашивать нечего.
            if actionType != .launchApp, item.hasTintableIcon {
                InspectorField(label: localizer.text(.iconColorLabel)) {
                    IconColorField(item: $item, themeColor: iconThemeColor, themeColors: ["#FFFFFF"] + themeColors)
                }
            }

            InspectorField(label: localizer.text(.customShortcut)) {
                CustomShortcutField(value: $item.customShortcut)
            }
        }
        .onChange(of: actionType) { _ in updateAction() }
        .onChange(of: bundleId) { _ in updateAction() }
        .onChange(of: urlString) { newValue in
            updateAction()
            if actionType == .openURL,
               let host = extractHost(from: newValue),
               !host.isEmpty {
                FaviconDownloader.shared.fetch(domain: host) { path in
                    item.icon = "file:\(path)"
                }
            }
        }
        .onChange(of: keystrokeKeyCode) { _ in updateAction() }
        .onChange(of: keystrokeModifiers) { _ in updateAction() }
        .onChange(of: systemKind) { _ in updateAction() }
        .onChange(of: snippetText) { _ in updateAction() }
    }

    /// Названия новых секторов на любом языке: такое название — ещё не название, его можно заменить.
    private static let placeholderTitles: Set<String> = Set(
        AppLanguage.allCases.map { LocalizationStore(language: $0).text(.newItem) } + ["New item"]
    )

    /// Подставить название за пользователя, если он ещё не дал своего.
    private func suggestTitle(_ suggestion: String?) {
        let current = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let isPlaceholder = current.isEmpty
            || current == autoTitle
            || Self.placeholderTitles.contains { current == $0 || current.hasPrefix($0 + " ") }
        guard isPlaceholder else { return }
        let suggestion = suggestion?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !suggestion.isEmpty, suggestion != current else { return }
        item.title = suggestion
        autoTitle = suggestion
    }

    private var actionFieldLabel: String {
        guard let actionType else { return localizer.text(.parameters) }
        switch actionType {
        case .appCommand: return localizer.text(.commandLabel)
        case .launchApp: return localizer.text(.application)
        case .openURL: return localizer.text(.actionTypeUrl)
        case .keystroke: return localizer.text(.keyCombination)
        case .systemShortcut: return localizer.text(.systemMacAction)
        case .snippet: return localizer.text(.snippetText)
        }
    }

    /// В меню команд «Не назначено» нет: сектор — команда приложения или одно из обычных действий.
    /// Выбор «Команды приложения» открывает список команд; тип меняется, когда команда выбрана.
    private var actionTypePicker: some View {
        let types = appCommand == nil ? ActionType.regular : ActionType.allCases
        let unassigned: [(ActionType?, String)] = appCommand == nil ? [(nil, localizer.text(.unassigned))] : []
        return DSPopUpPicker(
            selection: Binding(
                get: { actionType },
                set: { newType in
                    if newType == .appCommand, let appCommand, appCommand.command == nil {
                        appCommand.choose()
                        return
                    }
                    actionType = newType
                }
            ),
            options: unassigned + types.map { (Optional($0), $0.title(localizer)) },
            width: nil,
            accessibilityLabel: localizer.text(.actionType)
        )
    }

    /// Иконка на тёмной плитке в цвете сектора — как в самом кольце: белая иконка видна и в светлой теме.
    /// Иконка — полем во всю ширину, как соседние: плитка в цвете сектора (так иконка выглядит
    /// в кольце, и белая видна в светлой теме) и «Сменить иконку».
    private var iconField: some View {
        let tile = RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous)
        return Button { showIconPicker.toggle() } label: {
            HStack(spacing: DS.Spacing.s) {
                IconView(icon: item.icon, size: 14, color: resolvedIconColor)
                    .frame(width: 22, height: 22)
                    .background(tile.fill(segmentColor.opacity(0.28)))
                    .background(tile.fill(Color(white: 0.16)))
                Text(localizer.text(.changeIcon))
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                SidebarAppMenuPickerChevronLabel()
            }
            .padding(.horizontal, DS.Spacing.fieldInsetHorizontal)
            .frame(height: DS.Sizing.fieldHeight)
            .frame(maxWidth: .infinity)
            .dsFieldChrome(isHovered: isIconHovered, isFocused: showIconPicker)
            .contentShape(Rectangle())
        }
        .buttonStyle(DSPlainButtonStyle())
        .onHover { isIconHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isIconHovered)
        .popover(isPresented: $showIconPicker) {
            IconPickerView(
                selectedIcon: $item.icon,
                launchAppBundleId: actionType == .launchApp && !bundleId.isEmpty ? bundleId : nil
            )
        }
    }

    @ViewBuilder
    private var actionFields: some View {
        if let actionType {
            switch actionType {
            case .appCommand:
                appCommandField
            case .launchApp:
                Button(action: browseApp) {
                    HStack(spacing: DS.Spacing.s) {
                        if !bundleId.isEmpty {
                            if let nsImage = AppIconResolver.shared.icon(forBundleIdentifier: bundleId) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .frame(width: 20, height: 20)
                            } else {
                                Image(systemName: "app.fill")
                                    .font(DS.Typography.control)
                                    .foregroundStyle(.secondary.opacity(0.8))
                                    .frame(width: 20, height: 20)
                            }
                            Text(selectedAppName.isEmpty ? bundleId : selectedAppName)
                                .font(DS.Typography.body)
                                .foregroundStyle(.primary.opacity(isBrowseAppHovered ? 0.95 : 0.9))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        } else {
                            Text(localizer.text(.chooseApplication))
                                .font(DS.Typography.body)
                                .foregroundStyle(.secondary.opacity(isBrowseAppHovered ? 0.95 : 0.75))
                            Spacer(minLength: 0)
                        }
                        Image(systemName: "chevron.right")
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary.opacity(isBrowseAppHovered ? 0.85 : 0.6))
                    }
                    .padding(.horizontal, DS.Spacing.fieldInsetHorizontal)
                    .frame(height: DS.Sizing.fieldHeight)
                    .frame(maxWidth: .infinity)
                    .dsFieldChrome(isHovered: isBrowseAppHovered)
                }
                .buttonStyle(DSPlainButtonStyle())
                .onHover { isBrowseAppHovered = $0 }
                .animation(.easeInOut(duration: 0.12), value: isBrowseAppHovered)
                if !bundleId.isEmpty, !AppIconResolver.shared.isInstalled(bundleIdentifier: bundleId) {
                    // В кольце такой сектор приглушён и не выбирается — здесь сказано почему.
                    Label(localizer.text(.appNotInstalled), systemImage: "exclamationmark.triangle")
                        .font(DS.Typography.caption)
                        .foregroundStyle(Color.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }

            case .openURL:
                ModernTextField("https://...", text: $urlString, updateMode: .onBlur)

            case .keystroke:
                KeystrokeRecorderView(keyCode: $keystrokeKeyCode, modifiers: $keystrokeModifiers)
            case .systemShortcut:
                systemActionPicker
            case .snippet:
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    SnippetTextEditor(text: $snippetText, placeholder: localizer.text(.snippetPlaceholder))
                    Text(localizer.text(.snippetClipboardHint))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func updateAction() {
        guard let actionType else {
            item.action = .unassigned
            // Новая случайная, но не та же, что была: иначе сброс действия выглядит как «ничего не произошло».
            item.icon = PieMenuItem.randomUnassignedSymbol(avoiding: [item.icon])
            return
        }

        switch actionType {
        case .appCommand:
            // Команду выбирают в списке команд приложения, у пункта действия нет.
            return
        case .launchApp:
            item.action = .launchApp(bundleIdentifier: bundleId)
            if !bundleId.isEmpty {
                item.icon = "app:\(bundleId)"
                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                    item.title = FileManager.default.displayName(atPath: url.path)
                } else if !selectedAppName.isEmpty {
                    item.title = selectedAppName
                }
            }
        case .openURL:
            item.action = .openURL(url: urlString)
            suggestTitle(URLNormalizer.host(of: urlString))
        case .keystroke:
            item.action = .keystroke(keyCode: keystrokeKeyCode, modifiers: keystrokeModifiers)
            suggestTitle(HotkeyConfig.keystrokeGlyphString(keyCode: keystrokeKeyCode, modifiers: keystrokeModifiers))
        case .systemShortcut:
            let kind = systemKind.isAvailableInAppStore ? systemKind : .missionControl
            systemKind = kind
            item.action = .systemShortcut(kind)
            item.title = kind.displayName(language: localizer.language)
            item.icon = kind.defaultSFSymbol
        case .snippet:
            item.action = .snippet(text: snippetText)
            suggestTitle(PieHoverLabelText.excerpt(snippetText))
        }
    }

    /// Какая команда у сектора и откуда она; по клику — выбрать другую из списка.
    @ViewBuilder
    private var appCommandField: some View {
        if let appCommand, let command = appCommand.command {
            Button(action: appCommand.choose) {
                HStack(spacing: DS.Spacing.s) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(command.title)
                            .font(DS.Typography.body)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(command.isMissing ? localizer.text(.subMenuMissing) : command.caption)
                            .font(DS.Typography.label)
                            .foregroundStyle(command.isMissing ? Color.orange : Color.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if let shortcut = command.shortcut {
                        HotkeyCaption(text: shortcut)
                    }
                    Image(systemName: "chevron.right")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary.opacity(isCommandHovered ? 0.85 : 0.6))
                }
                .padding(.horizontal, DS.Spacing.fieldInsetHorizontal)
                .padding(.vertical, DS.Spacing.s)
                .frame(minHeight: DS.Sizing.fieldHeight)
                .frame(maxWidth: .infinity)
                .dsFieldChrome(isHovered: isCommandHovered)
                .contentShape(Rectangle())
            }
            .buttonStyle(DSPlainButtonStyle())
            .onHover { isCommandHovered = $0 }
            .animation(.easeInOut(duration: 0.12), value: isCommandHovered)
        }
    }

    private var systemActionPicker: some View {
        DSPopUpPicker(
            selection: $systemKind,
            options: MacOSSystemActionKind.appStoreCases.map { ($0, $0.displayName(language: localizer.language)) },
            width: nil,
            accessibilityLabel: localizer.text(.systemMacAction)
        )
    }

    /// Домен для фавикона — с `www.`: сервисы фавиконов отдают по нему то же, что сайт показывает сам.
    private func extractHost(from urlString: String) -> String? {
        URLNormalizer.url(from: urlString)?.host
    }

    private func browseApp() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = localizer.text(.select)
        if panel.runModal() == .OK, let url = panel.url,
           let descriptor = AppDescriptorResolver.resolve(from: url) {
            bundleId = descriptor.bundleIdentifier
            selectedAppName = descriptor.displayName
            item.title = descriptor.displayName
            item.action = .launchApp(bundleIdentifier: descriptor.bundleIdentifier)
            item.icon = "app:\(descriptor.bundleIdentifier)"
        }
    }
}

private struct ItemEditorPreview: View {
    @State private var item = PieMenuItem(
        title: "Safari",
        icon: "safari",
        action: .launchApp(bundleIdentifier: "com.apple.Safari"),
        color: "#007AFF",
        sectorIndex: 0
    )
    var body: some View {
        ItemEditorView(item: $item, onDelete: {})
            .frame(width: 340, height: 500)
            .background(
                LinearGradient(
                    colors: [DS.Colors.panelTop, DS.Colors.panelBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .preferredColorScheme(.dark)
            .environmentObject(LocalizationStore(language: .russian))
    }
}

#Preview("ItemEditor") {
    ItemEditorPreview()
}
