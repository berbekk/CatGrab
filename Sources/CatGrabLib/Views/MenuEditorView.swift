import SwiftUI
import AppKit

struct MenuEditorView: View {
    @Binding var menu: PieMenu
    @Binding var hapticFeedbackEnabled: Bool
    /// Касание трекпада этого меню. Запись снимает то же число пальцев с других меню.
    @Binding var trackpadFingerCount: Int
    /// Число пальцев → название другого меню, которое сейчас открывается этим касанием.
    var trackpadFingerCountOwners: [Int: String]
    @Binding var showAppearancePanel: Bool
    /// Свои темы — чтобы «Оформление» назвало тему меню.
    var customThemes: [CustomMenuTheme] = []
    /// Удалить меню; `nil` — встроенное меню, удалять нечего.
    var onDelete: (() -> Void)?
    /// Копия меню рядом с этим; `nil` — встроенное меню.
    var onDuplicate: (() -> Void)?
    /// Другое меню с тем же сочетанием — предупредить, что сработает то, что выше в списке.
    var hotkeyConflictMenuName: String?
    @EnvironmentObject private var localizer: LocalizationStore

    @State private var selectedItemId: UUID?

    var body: some View {
        VStack(spacing: 0) {
            menuSettingsSection
            previewSection
                .frame(minHeight: 0)
                .layoutPriority(1)
        }
        .padding(.top, DS.Spacing.s)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Colors.canvasTop)
        // Инспектор и «Параметры» выезжают в одно место — открытие одного закрывает другое.
        .onChange(of: selectedItemId) { id in
            if id != nil { showAppearancePanel = false }
        }
        .onChange(of: showAppearancePanel) { visible in
            if visible { selectedItemId = nil }
        }
    }

    // MARK: - Menu Settings

    /// У каждого меню сверху одно и то же: шапка с названием (и «Удалить меню» справа), под ней
    /// карточка «хоткей + жест + оформление». Строки — общие `SettingsRow`, контролы справа одной ширины.
    private var menuSettingsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            PageTitleRow(title: menu.displayName(localizer)) {
                MenuIconTile(menu: menu)
            } trailing: {
                HStack(spacing: DS.Spacing.s) {
                    if let onDuplicate {
                        Button(action: onDuplicate) {
                            Label(localizer.text(.duplicateMenu), systemImage: "plus.square.on.square")
                        }
                        .buttonStyle(DSFieldButtonStyle())
                    }
                    if let onDelete {
                        Button(role: .destructive, action: onDelete) {
                            Label(localizer.text(.deleteMenu), systemImage: "trash")
                        }
                        .buttonStyle(DSFieldButtonStyle(isDestructive: true))
                    }
                }
            }

            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                SettingsCard {
                    VStack(spacing: DS.Spacing.s) {
                        hotkeyRow
                        SettingsRowDivider()
                        trackpadGestureRow
                        SettingsRowDivider()
                        appearanceRow
                        if menu.isRunningAppsMenu {
                            SettingsRowDivider()
                            runningAppsExclusionsContent
                        }
                    }
                }
                if menu.isAppCommandsMenu {
                    appCommandsFootnote
                }
                if let hotkeyConflictMenuName {
                    hotkeyConflictFootnote(otherMenuName: hotkeyConflictMenuName)
                } else if !menu.isDynamicMenu {
                    howToOpenFootnote
                }
            }
        }
        .padding(.horizontal, DS.Spacing.l)
        .padding(.top, DS.Spacing.m)
        .padding(.bottom, DS.Spacing.m)
    }

    /// Само взаимодействие — зажать, повести, отпустить — нигде в приложении не показано;
    /// одна строка под сочетанием говорит, как меню открывают и как выбирают сектор.
    private var howToOpenFootnote: some View {
        Text(localizer.text(.howToOpenHint))
            .font(DS.Typography.label)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, DS.Spacing.m)
    }

    /// Одно сочетание у двух меню: второе молча не откроется — лучше сказать об этом здесь.
    private func hotkeyConflictFootnote(otherMenuName: String) -> some View {
        Label {
            Text(String(format: localizer.text(.hotkeyConflictFormat), otherMenuName))
        } icon: {
            Image(systemName: "exclamationmark.triangle")
        }
        .font(DS.Typography.label)
        .foregroundStyle(Color.orange)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, DS.Spacing.m)
    }

    /// Тема меню и вход в панель «Параметры» — рядом с остальными настройками меню.
    private var appearanceRow: some View {
        SettingsRow(localizer.text(.appearanceRowTitle)) {
            MenuStyleField(
                menu: menu,
                customThemes: customThemes,
                isActive: showAppearancePanel,
                onQuickApply: { menu.applyTheme($0) },
                action: { showAppearancePanel.toggle() }
            )
        }
    }

    private var hotkeyRow: some View {
        SettingsRow(localizer.text(.hotkey)) {
            HotkeyRecorderView(hotkey: $menu.hotkey)
                .frame(width: DS.Sizing.settingsControlWidth)
        }
    }

    /// Касание трекпада, которое открывает это меню. Число, занятое другим меню, подписано его названием:
    /// выбор заберёт касание у того меню.
    private var trackpadGestureRow: some View {
        SettingsRow(localizer.text(.trackpadGestureTitle)) {
            DSPopUpPicker(
                selection: $trackpadFingerCount,
                options: [(0, localizer.text(.trackpadGestureOff))]
                    + TrackpadGesture.supportedFingerCounts.map { ($0, trackpadGestureOptionTitle($0)) },
                accessibilityLabel: localizer.text(.trackpadGestureTitle)
            )
        }
        .help(localizer.text(.trackpadGestureSubtitle))
    }

    private func trackpadGestureOptionTitle(_ count: Int) -> String {
        let title = String(format: localizer.text(.trackpadGestureFingersFormat), count)
        guard let owner = trackpadFingerCountOwners[count] else { return title }
        return "\(title) — \(owner)"
    }

    /// Исключения — такая же строка, как остальные; выбранные приложения идут строками под ней.
    private var runningAppsExclusionsContent: some View {
        VStack(spacing: DS.Spacing.s) {
            SettingsRow(localizer.text(.runningAppsLimitTitle), subtitle: localizer.text(.runningAppsLimitSubtitle)) {
                DSPopUpPicker(
                    selection: $menu.runningAppsLimit,
                    options: PieMenu.runningAppsLimitOptions.map {
                        ($0, $0 == 0 ? localizer.text(.runningAppsLimitAll) : String($0))
                    },
                    accessibilityLabel: localizer.text(.runningAppsLimitTitle)
                )
            }
            SettingsRowDivider()
            SettingsRow(
                localizer.text(.runningAppsExclusions),
                subtitle: localizer.text(.runningAppsExclusionsExplainer)
            ) {
                Button(action: addRunningAppExclusion) {
                    Label(localizer.text(.addExclusion), systemImage: "plus")
                }
                .buttonStyle(DSFieldButtonStyle(width: DS.Sizing.settingsControlWidth))
            }
            ForEach(menu.runningAppsExcludedBundleIds, id: \.self) { bundleId in
                SettingsRowDivider()
                exclusionRow(bundleId: bundleId)
            }
        }
    }

    private func exclusionRow(bundleId: String) -> some View {
        HStack(spacing: DS.Spacing.s) {
            Group {
                if let nsImage = AppIconResolver.shared.icon(forBundleIdentifier: bundleId) {
                    Image(nsImage: nsImage).resizable()
                } else {
                    Image(systemName: "app.dashed").foregroundStyle(.secondary)
                }
            }
            .frame(width: 20, height: 20)
            Text(exclusionDisplayName(bundleId: bundleId))
                .font(DS.Typography.body)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                removeRunningAppExclusion(bundleId: bundleId)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(DSPlainButtonStyle())
            .iconOnlyHelp(localizer.text(.removeExclusion))
        }
        .frame(minHeight: DS.Sizing.settingsRowMinHeight)
    }

    /// Что это за меню и где менять команды отдельных приложений — подпись под карточкой.
    private var appCommandsFootnote: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(localizer.text(.appCommandsMenuPurpose))
            Text(localizer.text(.appCommandsCustomizeHint))
        }
        .font(DS.Typography.label)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, DS.Spacing.m)
    }

    private func exclusionDisplayName(bundleId: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return FileManager.default.displayName(atPath: url.path)
        }
        return bundleId
    }

    private func addRunningAppExclusion() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = localizer.text(.select)
        panel.message = localizer.text(.runningAppsExclusionsExplainer)
        guard panel.runModal() == .OK, let url = panel.url,
              let descriptor = AppDescriptorResolver.resolve(from: url) else { return }
        let bid = descriptor.bundleIdentifier
        let bidKey = bid.lowercased()
        guard !menu.runningAppsExcludedBundleIds.contains(where: { $0.lowercased() == bidKey }) else { return }
        menu.runningAppsExcludedBundleIds.append(bid)
    }

    private func removeRunningAppExclusion(bundleId: String) {
        let key = bundleId.lowercased()
        menu.runningAppsExcludedBundleIds.removeAll { $0.lowercased() == key }
    }

    // MARK: - Preview

    private var previewSection: some View {
        sectionBlock(title: localizer.text(.previewAndFineTuning)) {
            if menu.isAppCommandsMenu {
                CommandSetEditorPane(
                    menu: $menu,
                    bundleIdentifier: nil,
                    hapticFeedbackEnabled: hapticFeedbackEnabled,
                    showAppearancePanel: $showAppearancePanel
                )
            } else {
                itemsPreview
            }
        }
    }

    private var itemsPreview: some View {
        MenuPreviewView(
            menu: $menu,
            selectedItemId: $selectedItemId,
            hapticFeedbackEnabled: hapticFeedbackEnabled,
            isAppearancePanelVisible: showAppearancePanel,
            onAddItem: menu.isDynamicMenu ? nil : addItem
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sideDrawer(itemInspector)
    }

    /// Инспектор выбранного сектора — в левой панели окна, как «Параметры».
    private var itemInspector: SideDrawerContent? {
        guard let id = selectedItemId, let index = menu.items.firstIndex(where: { $0.id == id }) else { return nil }
        return SideDrawerContent(id: id, onClose: closeInspector) {
            ItemEditorView(
                item: Binding(
                    get: { menu.items.first { $0.id == id } ?? menu.items[min(index, menu.items.count - 1)] },
                    set: { item in
                        if let i = menu.items.firstIndex(where: { $0.id == id }) { menu.items[i] = item }
                    }
                ),
                themeColor: themeColor(forItemAt: index),
                themeColors: menu.colorScheme.sampleColors,
                iconThemeColor: iconThemeColor(forItemAt: index),
                onClose: closeInspector,
                onDelete: removeSelectedItem
            )
        }
    }

    private func closeInspector() {
        selectedItemId = nil
    }

    private func sectionBlock<Content: View>(
        title: String,
        fillBackground: Bool = true,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: DS.Spacing.s) {
            DSSectionHeader(title: title)
            SettingsCard(fillBackground: fillBackground) {
                content()
            }
            .frame(maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, DS.Spacing.l)
        .padding(.top, DS.Spacing.xs)
        .padding(.bottom, DS.Spacing.l)
    }

    /// Цвет темы на месте сектора — по порядку секторов, как его раскрасит кольцо.
    private func themeColor(forItemAt index: Int) -> String {
        let sorted = menu.items.sorted { $0.sectorIndex < $1.sectorIndex }
        let position = sorted.firstIndex { $0.id == menu.items[index].id } ?? 0
        return menu.colorScheme.color(at: position, count: sorted.count)
    }

    /// Цвет иконки по теме: белый при «Белых иконках», иначе цвет сектора (свой или из темы).
    private func iconThemeColor(forItemAt index: Int) -> String {
        if menu.iconStyle == .white { return "#FFFFFF" }
        let item = menu.items[index]
        return item.usesThemeColor ? themeColor(forItemAt: index) : item.color
    }

    // MARK: - Actions

    private func addItem() {
        let nextIndex = menu.nextFreeSectorIndex
        let item = PieMenuItem(
            title: localizer.text(.newItem),
            icon: PieMenuItem.randomUnassignedSymbol(avoiding: Set(menu.items.map(\.icon))),
            action: .unassigned,
            color: PieMenuItem.paletteColor(for: nextIndex),
            sectorIndex: nextIndex
        )
        withoutAnimation {
            menu.items.append(item)
            menu.snapRotationToAestheticAnchor()
        }
    }

    private func removeSelectedItem() {
        guard let id = selectedItemId else { return }
        guard menu.items.count > PieMenuItem.minItemCount else { return }
        withoutAnimation {
            menu.items.removeAll { $0.id == id }
            menu.snapRotationToAestheticAnchor()
        }
        selectedItemId = nil
    }

}

private struct MenuEditorPreview: View {
    @State private var menu = PieConfiguration.defaultConfig.menus[0]
    @State private var hapticFeedbackEnabled = true
    @State private var trackpadFingerCount = 0
    @State private var showPanel = false
    var body: some View {
        MenuEditorView(
            menu: $menu,
            hapticFeedbackEnabled: $hapticFeedbackEnabled,
            trackpadFingerCount: $trackpadFingerCount,
            trackpadFingerCountOwners: [:],
            showAppearancePanel: $showPanel
        )
            .frame(width: 800, height: 600)
            .preferredColorScheme(.dark)
            .environmentObject(LocalizationStore(language: .russian))
    }
}

#Preview("MenuEditor") {
    MenuEditorPreview()
}
