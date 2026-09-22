import SwiftUI
import AppKit

struct SettingsSidebarView: View {
    @Binding var config: PieConfiguration
    @Binding var selectedMenuId: UUID?
    /// Выбранный набор команд приложения. Пока он выбран, строка меню не подсвечивается.
    @Binding var selectedAppBundleId: String?
    @Binding var showingSystemPreferencesPane: Bool
    @Binding var showAppearancePanel: Bool

    @State private var hoveredMenuId: UUID?
    @State private var hoveredAppId: String?
    @State private var isAddAppRowHovered = false
    @State private var renamingMenuId: UUID?
    @State private var renamingDraft: String = ""
    @FocusState private var renameFieldFocused: Bool
    @State private var isAddMenuRowHovered = false
    @State private var isSystemPrefsRowHovered = false
    @State private var measuredSidebarMenuHeight: CGFloat = 0

    @EnvironmentObject private var localizer: LocalizationStore

    var onAddMenu: () -> Void
    var onRemoveMenu: (UUID) -> Void
    var onDuplicateMenu: (UUID) -> Void
    /// Свой набор команд для приложения: создать или открыть, если уже есть.
    var onAddApp: (String) -> Void
    var onChooseApp: () -> Void
    var onRemoveApp: (String) -> Void

    /// Подсвечена ровно одна строка: системные параметры, набор команд приложения или меню.
    private var highlightedAppBundleId: String? {
        showingSystemPreferencesPane ? nil : selectedAppBundleId
    }

    private var highlightedMenuId: UUID? {
        showingSystemPreferencesPane || selectedAppBundleId != nil ? nil : selectedMenuId
    }

    var body: some View {
        GeometryReader { geo in
            let chrome = DS.Sizing.sidebarBottomChromeHeight
            let maxScrollHeight = max(48, geo.size.height - chrome)
            let scrollHeight = measuredSidebarMenuHeight > 0
                ? min(measuredSidebarMenuHeight, maxScrollHeight)
                : maxScrollHeight

            VStack(spacing: 0) {
                ScrollView {
                    menuListStack
                        .background(
                            GeometryReader { proxy in
                                Color.clear.preference(
                                    key: SidebarMenuContentHeightKey.self,
                                    value: proxy.size.height
                                )
                            }
                        )
                }
                .frame(height: scrollHeight)
                .animation(nil, value: measuredSidebarMenuHeight)
                .onPreferenceChange(SidebarMenuContentHeightKey.self) { measuredSidebarMenuHeight = $0 }

                Spacer(minLength: 0)

                VStack(spacing: 0) {
                    sidebarAddMenuBar

                    Color.clear
                        .frame(height: DS.Sizing.sidebarFooterVerticalGutter)

                    Rectangle()
                        .fill(DS.Colors.stroke)
                        .frame(height: DS.Sizing.sidebarDividerLineHeight)
                        .frame(maxWidth: .infinity)

                    Color.clear
                        .frame(height: DS.Sizing.sidebarFooterVerticalGutter)

                    sidebarSystemPreferencesBar
                }
                .padding(.bottom, DS.Sizing.sidebarFooterVerticalGutter)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: config.menus.map(\.id)) { ids in
                if let h = hoveredMenuId, !ids.contains(h) {
                    hoveredMenuId = nil
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// «Новое меню» во всю ширину. Удаляют меню на его странице справа (и правым кликом в списке).
    private var sidebarAddMenuBar: some View {
        let rowShape = RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
        let baseFill = Color.primary.opacity(0.04)

        return HStack(alignment: .top, spacing: DS.Spacing.s) {
            Button(action: onAddMenu) {
                HStack(spacing: DS.Spacing.s) {
                    Image(systemName: "plus")
                        .font(.system(size: DS.Sizing.sidebarIconGlyph, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: DS.Sizing.sidebarIconTile, height: DS.Sizing.sidebarIconTile)
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous)
                                .fill(DS.Colors.blueAccent)
                        )

                    Text(localizer.text(.newMenu))
                        .font(DS.Typography.body)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, DS.Sizing.sidebarRowInnerPadding)
                .frame(minHeight: DS.Sizing.sidebarRowMinHeight)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    rowShape.fill(isAddMenuRowHovered ? Color.primary.opacity(0.07) : baseFill)
                )
                .overlay(
                    rowShape.strokeBorder(DS.Colors.stroke, lineWidth: DS.Border.hairline)
                )
                .contentShape(rowShape)
            }
            .buttonStyle(DSPlainButtonStyle())
            .onHover { isAddMenuRowHovered = $0 }
            .pointingHandCursor()
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, DS.Sizing.sidebarHorizontalPadding)
        .padding(.top, DS.Spacing.s)
        .animation(.easeInOut(duration: 0.15), value: isAddMenuRowHovered)
    }

    /// Такая же строка, как у меню и приложений: плитка-иконка слева, выбор — той же заливкой и рамкой.
    private var sidebarSystemPreferencesBar: some View {
        let rowShape = RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)

        return Button {
            showAppearancePanel = false
            showingSystemPreferencesPane = true
        } label: {
            HStack(alignment: .center, spacing: DS.Spacing.s) {
                sidebarIconTile(symbol: "gearshape.fill", fill: Color(nsColor: .systemGray))
                Text(localizer.text(.settingsSidebarSystemPreferences))
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, DS.Sizing.sidebarRowInnerPadding)
            .frame(minHeight: DS.Sizing.sidebarRowMinHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sidebarRowChrome(isSelected: showingSystemPreferencesPane, isHovered: isSystemPrefsRowHovered)
            .contentShape(rowShape)
        }
        .buttonStyle(DSPlainButtonStyle())
        .onHover { isSystemPrefsRowHovered = $0 }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DS.Sizing.sidebarHorizontalPadding)
        .animation(.easeInOut(duration: 0.15), value: isSystemPrefsRowHovered)
        .animation(.easeInOut(duration: 0.15), value: showingSystemPreferencesPane)
    }

    /// «Меню» — те, что вы собираете сами; «Встроенные» — готовые, их только включают и вызывают;
    /// «Приложения» — какие команды меню «Команды приложения» покажет в конкретном приложении.
    private var menuListStack: some View {
        VStack(spacing: DS.Spacing.xs) {
            let standardMenus = config.menus.filter { !$0.isDynamicMenu }
            let builtInMenus = config.menus.filter(\.isDynamicMenu)
                .sorted { $0.isRunningAppsMenu && !$1.isRunningAppsMenu }

            if !standardMenus.isEmpty {
                sidebarSection(localizer.text(.menusSection)) {
                    ForEach(standardMenus) { menu in
                        sidebarRow(menu)
                    }
                }
            }

            sidebarSection(localizer.text(.builtInMenusSection)) {
                ForEach(builtInMenus) { menu in
                    sidebarRow(menu)
                }
            }

            sidebarSection(localizer.text(.appsSection)) {
                ForEach(config.appSubMenus) { set in
                    sidebarAppRow(set)
                }
                addAppRow
            }
        }
        .padding(.horizontal, DS.Sizing.sidebarHorizontalPadding)
        .padding(.top, DS.Spacing.s)
        .padding(.bottom, DS.Spacing.m)
    }

    private func sidebarSection<Rows: View>(_ title: String, @ViewBuilder rows: () -> Rows) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            DSSectionHeader(title: title)
            VStack(spacing: DS.Spacing.xs) {
                rows()
            }
        }
    }

    // MARK: - Приложения

    private func sidebarAppRow(_ set: AppSubMenu) -> some View {
        let isSelected = highlightedAppBundleId.map { set.matches(bundleIdentifier: $0) } ?? false
        let isHovered = hoveredAppId == set.id
        let rowShape = RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
        let commandCount = String(format: localizer.text(.subMenuCommandsCountFormat), set.entries.count)

        return Button {
            selectApp(set.bundleIdentifier)
        } label: {
            HStack(alignment: .center, spacing: DS.Spacing.s) {
                appIcon(set.bundleIdentifier)
                Text(AppSubMenuEditorView.appName(for: set.bundleIdentifier))
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                Text(commandCount)
                    .font(DS.Typography.label)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.horizontal, DS.Sizing.sidebarRowInnerPadding)
            .frame(minHeight: DS.Sizing.sidebarRowMinHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sidebarRowChrome(isSelected: isSelected, isHovered: isHovered)
            .contentShape(rowShape)
        }
        .buttonStyle(DSPlainButtonStyle())
        .pointingHandCursor()
        .onHover { hovering in
            hoveredAppId = hovering ? set.id : nil
        }
        .contextMenu {
            Button(role: .destructive) { onRemoveApp(set.bundleIdentifier) } label: {
                Label(localizer.text(.delete), systemImage: "trash")
            }
        }
    }

    /// Выпадающий список запущенных приложений: чаще всего настраивают то, чем сейчас пользуются.
    private var addAppRow: some View {
        let rowShape = RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
        return ZStack(alignment: .leading) {
            HStack(spacing: DS.Spacing.s) {
                Image(systemName: "plus")
                    .font(.system(size: DS.Sizing.sidebarIconGlyph, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: DS.Sizing.sidebarIconTile, height: DS.Sizing.sidebarIconTile)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    )
                Text(localizer.text(.addAppCommands))
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary.opacity(0.75))
            }
            .padding(.horizontal, DS.Sizing.sidebarRowInnerPadding)
            .frame(minHeight: DS.Sizing.sidebarRowMinHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .allowsHitTesting(false)

            TransparentNSMenuPullDown(
                accessibilityLabel: localizer.text(.addAppCommands),
                makeEntries: addAppMenuEntries,
                onHover: { isAddAppRowHovered = $0 }
            )
            .frame(maxWidth: .infinity)
            .frame(minHeight: DS.Sizing.sidebarRowMinHeight)
        }
        .background(rowShape.fill(Color.primary.opacity(isAddAppRowHovered ? 0.07 : 0)))
        .overlay(
            rowShape.strokeBorder(
                DS.Colors.stroke,
                style: StrokeStyle(lineWidth: DS.Border.hairline, dash: [4, 3])
            )
        )
        .animation(.easeInOut(duration: 0.15), value: isAddAppRowHovered)
    }

    private func addAppMenuEntries() -> [PullDownMenuEntry] {
        let own = Bundle.main.bundleIdentifier
        let apps = NSWorkspace.shared.runningApplications
            .filter { app in
                guard app.activationPolicy == .regular, let bid = app.bundleIdentifier, bid != own else { return false }
                return config.appSubMenu(for: bid) == nil
            }
            .sorted { ($0.localizedName ?? "").localizedCaseInsensitiveCompare($1.localizedName ?? "") == .orderedAscending }
        var entries: [PullDownMenuEntry] = apps.compactMap { app in
            guard let bid = app.bundleIdentifier else { return nil }
            let icon = app.icon.map { image -> NSImage in
                let copy = image.copy() as? NSImage ?? image
                copy.size = NSSize(width: 16, height: 16)
                return copy
            }
            return .item(app.localizedName ?? bid, image: icon) { onAddApp(bid) }
        }
        if !entries.isEmpty {
            entries.append(.separator)
        }
        entries.append(.item(localizer.text(.subMenuChooseApp), symbol: "folder", action: onChooseApp))
        return entries
    }

    private func selectApp(_ bundleId: String) {
        if renamingMenuId != nil {
            commitMenuRename()
        }
        showAppearancePanel = false
        showingSystemPreferencesPane = false
        selectedAppBundleId = bundleId
    }

    @ViewBuilder
    private func appIcon(_ bundleId: String) -> some View {
        let size = DS.Sizing.sidebarIconTile
        if let nsImage = AppIconResolver.shared.icon(forBundleIdentifier: bundleId) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: "app")
                .font(.system(size: DS.Sizing.sidebarIconGlyph, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous)
                        .fill(Color.gray)
                )
        }
    }

    // MARK: - Меню

    private func sidebarSelectMenu(menu: PieMenu) {
        if renamingMenuId != nil {
            commitMenuRename()
        }
        showingSystemPreferencesPane = false
        selectedAppBundleId = nil
        selectedMenuId = menu.id
    }

    @ViewBuilder
    private func sidebarRowTitleGroup(menu: PieMenu) -> some View {
        Group {
            if renamingMenuId == menu.id, !menu.isDynamicMenu {
                TextField("", text: $renamingDraft)
                    .textFieldStyle(.plain)
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)
                    .focused($renameFieldFocused)
                    .onSubmit { commitMenuRename() }
                    .onExitCommand { cancelMenuRename() }
                    .stretchInputHorizontally()
                    .pointingHandCursor()
            } else {
                let title = dynamicMenuTitle(menu) ?? menu.name
                if !menu.isDynamicMenu {
                    Text(title)
                        .font(DS.Typography.body)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                        .highPriorityGesture(
                            TapGesture(count: 2).onEnded {
                                beginMenuRename(menu: menu)
                            }
                        )
                } else {
                    Text(title)
                        .font(DS.Typography.body)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func sidebarRowSelectableLeading(menu: PieMenu) -> some View {
        if renamingMenuId == menu.id, !menu.isDynamicMenu {
            HStack(alignment: .center, spacing: DS.Spacing.s) {
                sidebarIcon(menu)
                sidebarRowTitleGroup(menu: menu)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            Button {
                sidebarSelectMenu(menu: menu)
            } label: {
                HStack(alignment: .center, spacing: DS.Spacing.s) {
                    sidebarIcon(menu)
                        .contentShape(Rectangle())
                    sidebarRowTitleGroup(menu: menu)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .background(Color.clear)
                .contentShape(Rectangle())
            }
            .buttonStyle(DSPlainButtonStyle())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .pointingHandCursor()
        }
    }

    private func sidebarRow(_ menu: PieMenu) -> some View {
        let isSelected = highlightedMenuId == menu.id
        let isHovered = hoveredMenuId == menu.id
        // Динамические меню («Активные приложения», «Команды приложения»): NSHostingView с NSSwitch перехватывает
        // hit-testing; вместо кнопки+иконки+текста — полноэкранная plain-кнопка под строкой, сверху только
        // декоративный HStack и отдельный слой с переключателем.
        return Group {
            if menu.isDynamicMenu {
                ZStack(alignment: .trailing) {
                    Button {
                        sidebarSelectMenu(menu: menu)
                    } label: {
                        Color.clear
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(DSPlainButtonStyle())

                    HStack(alignment: .center, spacing: DS.Spacing.s) {
                        sidebarIcon(menu)
                        sidebarRowTitleGroup(menu: menu)
                        hotkeyCaption(menu)
                    }
                    .padding(.trailing, DS.Sizing.sidebarRunningAppsSwitchColumnWidth + DS.Spacing.s)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .allowsHitTesting(false)

                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        RunningAppsMenuEnabledSwitch(isOn: bindingForRunningAppsEnabled(menuId: menu.id))
                            .fixedSize(horizontal: true, vertical: true)
                    }
                    .accessibilityLabel(localizer.text(.activeAppsMenuEnabled))
                    .help(localizer.text(.activeAppsMenuEnabledHelp))
                    .frame(width: DS.Sizing.sidebarRunningAppsSwitchColumnWidth, height: DS.Sizing.fieldHeight)
                }
            } else {
                HStack(alignment: .center, spacing: DS.Spacing.s) {
                    sidebarRowSelectableLeading(menu: menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    hotkeyCaption(menu)
                        .allowsHitTesting(false)
                }
            }
        }
        .padding(.horizontal, DS.Sizing.sidebarRowInnerPadding)
        .frame(minHeight: DS.Sizing.sidebarRowMinHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sidebarRowChrome(isSelected: isSelected, isHovered: isHovered)
        .onHover { hovering in
            hoveredMenuId = hovering ? menu.id : nil
        }
        .contextMenu {
            if !menu.isDynamicMenu {
                Button { onDuplicateMenu(menu.id) } label: {
                    Label(localizer.text(.duplicateMenu), systemImage: "plus.square.on.square")
                }
                Divider()
                Button(role: .destructive) { onRemoveMenu(menu.id) } label: {
                    Label(localizer.text(.delete), systemImage: "trash")
                }
            }
        }
        .onChange(of: renameFieldFocused) { focused in
            if !focused, renamingMenuId != nil {
                commitMenuRename()
            }
        }
    }

    private func beginMenuRename(menu: PieMenu) {
        guard !menu.isDynamicMenu else { return }
        renamingMenuId = menu.id
        renamingDraft = menu.name
        DispatchQueue.main.async {
            renameFieldFocused = true
        }
    }

    private func commitMenuRename() {
        guard let id = renamingMenuId else { return }
        let trimmed = renamingDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if let idx = config.menus.firstIndex(where: { $0.id == id }),
           !config.menus[idx].isDynamicMenu,
           !trimmed.isEmpty {
            config.menus[idx].name = trimmed
        }
        renamingMenuId = nil
        renamingDraft = ""
        renameFieldFocused = false
    }

    private func cancelMenuRename() {
        renamingMenuId = nil
        renamingDraft = ""
        renameFieldFocused = false
    }

    private func sidebarIcon(_ menu: PieMenu) -> some View {
        MenuIconTile(menu: menu)
    }

    /// Цветная плитка с белым символом — одна у всех строк сайдбара.
    private func sidebarIconTile(symbol: String, fill: Color, weight: Font.Weight = .medium) -> some View {
        Image(systemName: symbol)
            .font(.system(size: DS.Sizing.sidebarIconGlyph, weight: weight))
            .foregroundStyle(.white)
            .frame(width: DS.Sizing.sidebarIconTile, height: DS.Sizing.sidebarIconTile)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous)
                    .fill(fill)
            )
    }

    /// Название динамического меню — локализованное, а не из конфига; `nil` для обычных меню.
    private func dynamicMenuTitle(_ menu: PieMenu) -> String? {
        switch menu.kind {
        case .standard: return nil
        case .runningApps: return localizer.text(.activeAppsMenuTitle)
        case .appCommands: return localizer.text(.appCommandsMenuTitle)
        }
    }

    /// Сочетание, которым открывается меню, — справа в строке. Меняется в карточке «Как открыть» редактора.
    @ViewBuilder
    private func hotkeyCaption(_ menu: PieMenu) -> some View {
        if !menu.hotkey.isEmpty {
            HotkeyCaption(text: menu.hotkey.glyphString)
                .help(menu.hotkey.displayString(language: localizer.language))
        }
    }

    private func bindingForRunningAppsEnabled(menuId: UUID) -> Binding<Bool> {
        Binding(
            get: {
                config.menus.first { $0.id == menuId }?.runningAppsMenuEnabled ?? true
            },
            set: { newValue in
                guard let idx = config.menus.firstIndex(where: { $0.id == menuId }) else { return }
                var next = config
                next.menus[idx].runningAppsMenuEnabled = newValue
                config = next
            }
        )
    }
}

enum SidebarMenuContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
