import SwiftUI
import AppKit

struct SettingsSidebarView: View {
    @Binding var config: PieConfiguration
    @Binding var selectedMenuId: UUID?
    @Binding var showingSystemPreferencesPane: Bool
    @Binding var showAppearancePanel: Bool

    @State private var hoveredMenuId: UUID?
    @State private var renamingMenuId: UUID?
    @State private var renamingDraft: String = ""
    @FocusState private var renameFieldFocused: Bool
    @State private var isAddMenuRowHovered = false
    @State private var isDeleteMenuButtonHovered = false
    @State private var isSystemPrefsRowHovered = false
    @State private var measuredSidebarMenuHeight: CGFloat = 0

    @EnvironmentObject private var localizer: LocalizationStore

    var onAddGlobalMenu: () -> Void
    var onAddAppMenu: () -> Void
    var onRemoveMenu: (UUID) -> Void
    var onSelectAppBundleGroup: (String) -> Void
    var onChangeBoundAppGroup: (String) -> Void

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
                    sidebarAddDeleteBar

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

    private var sidebarAddDeleteBar: some View {
        let rowShape = RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
        let baseFill = Color.primary.opacity(0.04)
        let selectedIsRunningApps = selectedMenuId.flatMap { sid in
            config.menus.first { $0.id == sid }?.isRunningAppsMenu
        } ?? false
        let canDeleteMenu = selectedMenuId != nil && !config.menus.isEmpty && !selectedIsRunningApps

        return HStack(alignment: .top, spacing: DS.Spacing.s) {
            ZStack(alignment: .leading) {
                HStack(spacing: DS.Spacing.s) {
                    Image(systemName: "plus")
                        .font(.system(size: DS.Sizing.sidebarIconGlyph, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: DS.Sizing.sidebarIconTile, height: DS.Sizing.sidebarIconTile)
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous)
                                .fill(DS.Colors.blueAccent)
                        )

                    Text(localizer.text(.add))
                        .font(DS.Typography.body)
                        .foregroundStyle(.primary)
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
                    accessibilityLabel: localizer.text(.add),
                    menuItems: [
                        (localizer.text(.addGlobalMenu), "globe", onAddGlobalMenu),
                        (localizer.text(.addForApp), "app.badge.fill", onAddAppMenu),
                    ],
                    onHover: { isAddMenuRowHovered = $0 }
                )
                .frame(maxWidth: .infinity)
                .frame(minHeight: DS.Sizing.sidebarRowMinHeight)
            }
            .background(
                rowShape.fill(isAddMenuRowHovered ? Color.primary.opacity(0.08) : baseFill)
            )
            .overlay(
                rowShape.strokeBorder(DS.Colors.stroke, lineWidth: DS.Border.hairline)
            )
            .contentShape(Rectangle())
            .frame(maxWidth: .infinity)

            Button(role: .destructive) {
                guard let id = selectedMenuId else { return }
                onRemoveMenu(id)
            } label: {
                let destructiveStroke = canDeleteMenu
                    ? Color.red.opacity(isDeleteMenuButtonHovered ? 0.42 : 0.28)
                    : DS.Colors.stroke
                Image(systemName: "trash")
                    .font(.system(size: DS.Sizing.sidebarIconGlyph, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(
                        canDeleteMenu
                            ? Color.red.opacity(isDeleteMenuButtonHovered ? 1.0 : 0.88)
                            : Color.primary.opacity(0.35)
                    )
                    .frame(width: DS.Sizing.sidebarRowMinHeight, height: DS.Sizing.sidebarRowMinHeight)
                    .background(
                        rowShape.fill(
                            canDeleteMenu
                                ? Color.red.opacity(isDeleteMenuButtonHovered ? 0.16 : 0.1)
                                : baseFill
                        )
                    )
                    .overlay(
                        rowShape.strokeBorder(destructiveStroke, lineWidth: DS.Border.hairline)
                    )
                    .contentShape(rowShape)
            }
            .buttonStyle(DSPlainButtonStyle())
            .accessibilityLabel(localizer.text(.delete))
            .disabled(!canDeleteMenu)
            .onHover {
                guard canDeleteMenu else {
                    isDeleteMenuButtonHovered = false
                    return
                }
                isDeleteMenuButtonHovered = $0
            }
        }
        .padding(.horizontal, DS.Sizing.sidebarHorizontalPadding)
        .padding(.top, DS.Spacing.s)
        .animation(.easeInOut(duration: 0.15), value: isAddMenuRowHovered)
        .animation(.easeInOut(duration: 0.15), value: isDeleteMenuButtonHovered)
    }

    private var sidebarSystemPreferencesBar: some View {
        let rowShape = RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
        let baseFill = Color.primary.opacity(0.04)

        return Button {
            showAppearancePanel = false
            showingSystemPreferencesPane = true
        } label: {
            let isSelected = showingSystemPreferencesPane
            HStack {
                Spacer(minLength: 0)
                HStack(alignment: .center, spacing: DS.Spacing.xs) {
                    Image(systemName: "gearshape")
                        .font(.system(size: DS.Sizing.sidebarIconGlyph, weight: .regular))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(.primary.opacity(isSystemPrefsRowHovered ? 0.95 : 0.88))

                    Text(localizer.text(.settingsSidebarSystemPreferences))
                        .font(DS.Typography.body)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, DS.Sizing.sidebarRowInnerPadding)
            .frame(minHeight: DS.Sizing.sidebarRowMinHeight)
            .frame(maxWidth: .infinity)
            .background(
                rowShape.fill(
                    isSelected
                        ? Color.primary.opacity(0.07)
                        : isSystemPrefsRowHovered
                            ? Color.primary.opacity(0.06)
                            : baseFill
                )
            )
            .overlay(
                rowShape.strokeBorder(DS.Colors.stroke, lineWidth: DS.Border.hairline)
            )
            .contentShape(rowShape)
        }
        .buttonStyle(DSPlainButtonStyle())
        .onHover { isSystemPrefsRowHovered = $0 }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DS.Sizing.sidebarHorizontalPadding)
        .animation(.easeInOut(duration: 0.15), value: isSystemPrefsRowHovered)
        .animation(.easeInOut(duration: 0.15), value: showingSystemPreferencesPane)
    }

    private var menuListStack: some View {
        VStack(spacing: DS.Spacing.xs) {
            let standardGlobalMenus = config.menus.filter { $0.isGlobal && !$0.isRunningAppsMenu }
            let runningAppsMenus = config.menus.filter { $0.isGlobal && $0.isRunningAppsMenu }
            let appMenus = config.menus.filter { !$0.isGlobal }

            if !standardGlobalMenus.isEmpty {
                VStack(alignment: .leading, spacing: DS.Spacing.s) {
                    sectionLabel(localizer.text(.globalSection))
                    VStack(spacing: DS.Spacing.xs) {
                        ForEach(standardGlobalMenus) { menu in
                            sidebarRow(menu)
                        }
                    }
                }
            }

            if !runningAppsMenus.isEmpty {
                VStack(alignment: .leading, spacing: DS.Spacing.s) {
                    sectionLabel(localizer.text(.runningAppsSection))
                    VStack(spacing: DS.Spacing.xs) {
                        ForEach(runningAppsMenus) { menu in
                            sidebarRow(menu)
                        }
                    }
                }
            }

            if !appMenus.isEmpty {
                VStack(alignment: .leading, spacing: DS.Spacing.s) {
                    sectionLabel(localizer.text(.appSection))
                    VStack(spacing: DS.Spacing.xs) {
                        ForEach(Self.orderedAppBundleKeys(from: appMenus), id: \.self) { bundleKeyLower in
                            let group = appMenus.filter { $0.boundAppBundleId?.lowercased() == bundleKeyLower }
                            if let rep = group.first {
                                sidebarAppGroupRow(representative: rep, bundleIdLower: bundleKeyLower, groupMenus: group)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, DS.Sizing.sidebarHorizontalPadding)
        .padding(.top, DS.Spacing.s)
        .padding(.bottom, DS.Spacing.m)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(DS.Typography.section)
            .foregroundStyle(.secondary.opacity(0.7))
            .textCase(.uppercase)
            .tracking(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, DS.Spacing.m)
    }

    private static func orderedAppBundleKeys(from menus: [PieMenu]) -> [String] {
        var seen = Set<String>()
        var keys: [String] = []
        for m in menus {
            guard let bid = m.boundAppBundleId else { continue }
            let k = bid.lowercased()
            if seen.insert(k).inserted {
                keys.append(k)
            }
        }
        return keys
    }

    private func sidebarAppGroupRow(representative: PieMenu, bundleIdLower: String, groupMenus: [PieMenu]) -> some View {
        let isSelected = groupMenus.contains { $0.id == selectedMenuId }
        let isHovered = groupMenus.contains { hoveredMenuId == $0.id }
        let rowShape = RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
        let baseFill = Color.primary.opacity(0.04)
        let rowFill: Color = {
            if isSelected { return Color.primary.opacity(0.07) }
            if isHovered { return Color.primary.opacity(0.09) }
            return baseFill
        }()
        let title = representative.boundAppName
            ?? (representative.boundAppBundleId.flatMap { bid in
                NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid).map {
                    FileManager.default.displayName(atPath: $0.path)
                }
            } ?? representative.name)

        // Шеврон — сосед справа, не подложка под кнопкой: иначе у текста остаётся «логическая»
        // ширина с отступом под колонку, но разметка даёт лишь intrinsic — раннее троеточие.
        return HStack(alignment: .center, spacing: 0) {
            Button {
                sidebarSelectAppGroup(bundleIdLower: bundleIdLower)
            } label: {
                HStack(alignment: .center, spacing: DS.Spacing.s) {
                    sidebarIcon(representative)
                    Text(title)
                        .font(DS.Typography.body)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(DSPlainButtonStyle())
            .frame(maxWidth: .infinity)
            .frame(maxHeight: .infinity, alignment: .center)
            .pointingHandCursor()

            SidebarAppMenuChevronColumn(
                action: { onChangeBoundAppGroup(bundleIdLower) },
                helpText: localizer.text(.chooseApplication),
                menuCount: groupMenus.count
            )
        }
        .padding(.horizontal, DS.Sizing.sidebarRowInnerPadding)
        .frame(minHeight: DS.Sizing.sidebarRowMinHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowShape.fill(rowFill))
        .overlay(
            rowShape.strokeBorder(
                isSelected ? DS.Colors.sidebarMenuSelectedStroke : .clear,
                lineWidth: isSelected ? DS.Border.focus : DS.Border.hairline
            )
        )
        .onHover { hovering in
            hoveredMenuId = hovering ? groupMenus.first?.id : nil
        }
    }

    private func sidebarSelectAppGroup(bundleIdLower: String) {
        if renamingMenuId != nil {
            commitMenuRename()
        }
        onSelectAppBundleGroup(bundleIdLower)
    }

    private func sidebarSelectMenu(menu: PieMenu) {
        if renamingMenuId != nil {
            commitMenuRename()
        }
        showingSystemPreferencesPane = false
        selectedMenuId = menu.id
    }

    @ViewBuilder
    private func sidebarRowTitleGroup(menu: PieMenu) -> some View {
        Group {
            if renamingMenuId == menu.id, menu.isGlobal, !menu.isRunningAppsMenu {
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
                let title = menu.isRunningAppsMenu ? localizer.text(.activeAppsMenuTitle) : menu.name
                if menu.isGlobal, !menu.isRunningAppsMenu {
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
        if renamingMenuId == menu.id, menu.isGlobal, !menu.isRunningAppsMenu {
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
        let isSelected = selectedMenuId == menu.id
        let isHovered = hoveredMenuId == menu.id
        let rowShape = RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
        let baseFill = Color.primary.opacity(0.04)

        let rowFill: Color = {
            if isSelected { return Color.primary.opacity(0.07) }
            if isHovered { return Color.primary.opacity(0.09) }
            return baseFill
        }()
        // «Активные приложения»: NSHostingView с NSSwitch перехватывает hit-testing; вместо кнопки+иконки+текста —
        // полноэкранная plain-кнопка под строкой, сверху только декоративный HStack и отдельный слой с переключателем.
        return Group {
            if menu.isRunningAppsMenu {
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
                    }
                    .padding(.trailing, DS.Sizing.sidebarRunningAppsSwitchColumnWidth)
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

                    HotkeyRecorderView(hotkey: bindingForMenuHotkey(menuId: menu.id))
                        .frame(
                            minWidth: DS.Sizing.sidebarHotkeyColumnMaxWidth,
                            maxWidth: DS.Sizing.sidebarHotkeyColumnMaxWidth,
                            alignment: .leading
                        )
                }
            }
        }
        .padding(.horizontal, DS.Sizing.sidebarRowInnerPadding)
        .frame(minHeight: DS.Sizing.sidebarRowMinHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowShape.fill(rowFill))
        .overlay(
            rowShape.strokeBorder(
                isSelected ? DS.Colors.sidebarMenuSelectedStroke : .clear,
                lineWidth: isSelected ? DS.Border.focus : DS.Border.hairline
            )
        )
        .onHover { hovering in
            hoveredMenuId = hovering ? menu.id : nil
        }
        .contextMenu {
            if !menu.isRunningAppsMenu {
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
        guard menu.isGlobal, !menu.isRunningAppsMenu else { return }
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
           config.menus[idx].isGlobal,
           !config.menus[idx].isRunningAppsMenu,
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

    @ViewBuilder
    private func sidebarIcon(_ menu: PieMenu) -> some View {
        let iconSize: CGFloat = DS.Sizing.sidebarIconTile
        let cornerRadius: CGFloat = DS.Radius.s

        if menu.isRunningAppsMenu {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: DS.Sizing.sidebarIconGlyph, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: iconSize, height: iconSize)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color(nsColor: .systemTeal))
                )
        } else if menu.isGlobal {
            let fillColor: Color = {
                if let hex = menu.globalSidebarIconColorHex, let c = Color(hex: hex) { return c }
                return DS.Colors.blueAccent
            }()
            Image(systemName: "globe")
                .font(.system(size: DS.Sizing.sidebarIconGlyph, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: iconSize, height: iconSize)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(fillColor)
                )
        } else if let bundleId = menu.boundAppBundleId,
                  let nsImage = AppIconResolver.shared.icon(forBundleIdentifier: bundleId) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: iconSize, height: iconSize)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            Image(systemName: "app")
                .font(.system(size: DS.Sizing.sidebarIconGlyph, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: iconSize, height: iconSize)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.gray)
                )
        }
    }

    private func bindingForMenuHotkey(menuId: UUID) -> Binding<HotkeyConfig> {
        Binding(
            get: {
                config.menus.first { $0.id == menuId }?.hotkey ?? .empty
            },
            set: { newValue in
                guard let idx = config.menus.firstIndex(where: { $0.id == menuId }) else { return }
                var next = config
                next.menus[idx].hotkey = newValue
                config = next
            }
        )
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
