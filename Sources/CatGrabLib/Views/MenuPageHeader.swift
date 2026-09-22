import SwiftUI

/// Цветная плитка меню с белым символом — в сайдбаре и в шапке страницы меню.
struct MenuIconTile: View {
    let menu: PieMenu
    var side: CGFloat = DS.Sizing.sidebarIconTile

    private var symbol: (name: String, fill: Color, weight: Font.Weight) {
        switch menu.kind {
        case .appCommands:
            return ("command", Color(nsColor: .systemIndigo), .semibold)
        case .runningApps:
            return ("square.stack.3d.up.fill", Color(nsColor: .systemTeal), .medium)
        case .standard:
            return ("globe", menu.globalSidebarIconColorHex.flatMap { Color(hex: $0) } ?? DS.Colors.blueAccent, .medium)
        }
    }

    var body: some View {
        let scale = side / DS.Sizing.sidebarIconTile
        Image(systemName: symbol.name)
            .font(.system(size: DS.Sizing.sidebarIconGlyph * scale, weight: symbol.weight))
            .foregroundStyle(.white)
            .frame(width: side, height: side)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.s * scale, style: .continuous)
                    .fill(symbol.fill)
            )
    }
}

/// Шапка страницы меню и набора приложения: иконка, название и действие справа. Высота —
/// как у поля, поэтому страница с кнопкой и без неё не прыгает.
struct PageTitleRow<Icon: View, Trailing: View>: View {
    let title: String
    @ViewBuilder let icon: () -> Icon
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            icon()
                .frame(width: DS.Sizing.sidebarIconTile, height: DS.Sizing.sidebarIconTile)
            Text(title)
                .font(DS.Typography.screenTitle)
                .lineLimit(1)
            Spacer(minLength: DS.Spacing.l)
            trailing()
        }
        .frame(height: DS.Sizing.fieldHeight)
    }
}

/// «Тема»: слева — кнопка, которая открывает панель «Параметры», справа — выпадающий список
/// «Моих тем» (выбор применяет тему сразу, без захода в настройки).
/// Вместе они той же ширины, что и соседние контролы, — края колонки совпадают.
struct MenuStyleField: View {
    let menu: PieMenu
    let customThemes: [CustomMenuTheme]
    let isActive: Bool
    /// Выбор темы в выпадающем списке.
    let onQuickApply: (CustomMenuTheme) -> Void
    /// Открыть панель «Параметры».
    let action: () -> Void

    @EnvironmentObject private var localizer: LocalizationStore
    @State private var isHovered = false

    /// Пункт меню — само название пункта или, когда тем ещё нет, подсказка сохранить одну.
    private var menuTitles: [String] {
        customThemes.isEmpty ? [localizer.text(.myThemesEmptyMenuHint)] : customThemes.map(\.name)
    }

    private static let pickerWidth = DS.Sizing.settingsControlWidth - DS.Sizing.fieldHeight - DS.Spacing.s

    private var selectedThemeIndex: Int? {
        guard let id = menu.themeID else { return nil }
        return customThemes.firstIndex { $0.id == id }
    }

    var body: some View {
        HStack(spacing: DS.Spacing.s) {
            Button(action: action) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary.opacity(isActive ? 0.96 : 0.88))
                    .frame(width: DS.Sizing.fieldHeight, height: DS.Sizing.fieldHeight)
                    .dsFieldChrome(isHovered: false, isFocused: isActive)
            }
            .buttonStyle(DSPlainButtonStyle())
            .iconOnlyHelp(localizer.text(.appearanceSettingsButtonHelp))

            ZStack {
                HStack(spacing: DS.Spacing.s) {
                    ThemeMiniRing(look: MenuLook(menu))
                        .frame(width: 20, height: 20)
                    Text(menu.styleName(customThemes: customThemes, localizer: localizer))
                        .font(DS.Typography.body)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if menu.hasUnsavedThemeChanges(in: customThemes) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 6, height: 6)
                            .help(localizer.text(.themeModifiedHelp))
                    }
                    Spacer(minLength: 0)
                    SidebarAppMenuPickerChevronLabel()
                }
                .padding(.horizontal, DS.Spacing.fieldInsetHorizontal)
                .allowsHitTesting(false)

                // Настоящий `NSMenu`, как у остальных списков (`DSPopUpPicker`): нативное поведение,
                // а подпись — своя, с мини-кольцом темы.
                PopUpMenuHost(
                    titles: menuTitles,
                    selectedIndex: selectedThemeIndex,
                    accessibilityLabel: localizer.text(.appearanceRowTitle),
                    onSelect: { index in
                        guard customThemes.indices.contains(index) else { return }
                        onQuickApply(customThemes[index])
                    },
                    onHover: { isHovered = $0 }
                )
            }
            .frame(width: Self.pickerWidth, height: DS.Sizing.fieldHeight)
            .dsFieldChrome(isHovered: isHovered)
            .animation(.easeInOut(duration: 0.12), value: isHovered)
        }
    }
}

extension PieMenu {
    /// Название меню в интерфейсе: у встроенных — локализованное.
    func displayName(_ localizer: LocalizationStore) -> String {
        switch kind {
        case .standard: return name
        case .runningApps: return localizer.text(.activeAppsMenuTitle)
        case .appCommands: return localizer.text(.appCommandsMenuTitle)
        }
    }

    /// Как называется оформление меню: его тема или «Своя», если меню не привязано к теме.
    func styleName(customThemes: [CustomMenuTheme], localizer: LocalizationStore) -> String {
        theme(in: customThemes)?.name ?? localizer.text(.customStyleName)
    }
}
