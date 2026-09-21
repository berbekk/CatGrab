import SwiftUI
import AppKit

struct SettingsView: View {
    private struct BackupAlert: Identifiable {
        enum Kind {
            case success
            case failure
        }

        let id = UUID()
        let kind: Kind
        let title: String
        let message: String
    }

    @State private var config: PieConfiguration
    @State private var selectedMenuId: UUID?
    /// Открытый набор команд приложения; важнее выбранного меню.
    @State private var selectedAppBundleId: String?
    @State private var showingSystemPreferencesPane = false
    @State private var backupAlert: BackupAlert?
    @State private var showAppearancePanel = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var localizer: LocalizationStore
    @State private var pendingSaveWorkItem: DispatchWorkItem?
    @State private var pendingConfigForSave: PieConfiguration?
    @State private var skipNextConfigSave = false

    init() {
        let cfg = ConfigManager.shared.configuration
        _config = State(initialValue: cfg)
        _selectedMenuId = State(initialValue: cfg.menus.first?.id)
    }

    var body: some View {
        contentContainer
            .onChange(of: config) { newConfig in
                if skipNextConfigSave {
                    skipNextConfigSave = false
                    return
                }
                scheduleConfigSave(newConfig)
            }
            .onChange(of: config.language) { language in
                localizer.language = language
            }
            .onReceive(NotificationCenter.default.publisher(for: .configurationDidChange)) { _ in
                let updated = ConfigManager.shared.configuration
                guard updated != config else { return }
                skipNextConfigSave = true
                config = updated
                if let selectedMenuId,
                   !updated.menus.contains(where: { $0.id == selectedMenuId }) {
                    self.selectedMenuId = updated.menus.first?.id
                }
                if let selectedAppBundleId, updated.appSubMenu(for: selectedAppBundleId) == nil {
                    self.selectedAppBundleId = nil
                }
            }
            .onDisappear {
                flushPendingConfigSave()
            }
            .sheet(item: $backupAlert) { alert in
                BackupResultSheet(
                    isSuccess: alert.kind == .success,
                    title: alert.title,
                    message: alert.message,
                    onDismiss: { backupAlert = nil }
                )
            }
    }

    private var contentContainer: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                SettingsSidebarView(
                    config: $config,
                    selectedMenuId: $selectedMenuId,
                    selectedAppBundleId: $selectedAppBundleId,
                    showingSystemPreferencesPane: $showingSystemPreferencesPane,
                    showAppearancePanel: $showAppearancePanel,
                    onAddMenu: addMenu,
                    onRemoveMenu: removeMenu,
                    onAddApp: addApp,
                    onChooseApp: chooseApp,
                    onRemoveApp: removeApp
                )
                .frame(width: DS.Sizing.sidebarWidth)
                Rectangle()
                    .fill(DS.Colors.stroke)
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
                    .ignoresSafeArea(edges: .top)
                VStack(spacing: 0) {
                    MenuBarIconHiddenBanner()
                    detail
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if let selId = selectedMenuId, let i = menuIndex, i < config.menus.count,
               !showingSystemPreferencesPane, selectedAppBundleId == nil {
                let drawerW = DS.Sizing.appearanceDrawerWidth
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { showAppearancePanel = false }
                    .allowsHitTesting(showAppearancePanel)

                MenuAppearanceControlsView(menu: bindingForMenu(id: selId), onClose: {
                    showAppearancePanel = false
                })
                .frame(width: drawerW)
                .frame(maxHeight: .infinity)
                .background(DS.Colors.canvasTop)
                .overlay(alignment: .trailing) {
                    Rectangle()
                        .fill(DS.Colors.stroke)
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                        .ignoresSafeArea(edges: .top)
                }
                .offset(x: showAppearancePanel ? 0 : -drawerW)
                .animation(DS.Motion.respectReducing(DS.Motion.slidePanelSpring, reduce: reduceMotion), value: showAppearancePanel)
                .allowsHitTesting(showAppearancePanel)
            }
        }
        // Окно уже само ограничено до видимой области экрана (`SettingsWindowController.targetContentSize`);
        // фиксированный размер здесь не давал контенту сжаться вместе с окном на невысоких экранах,
        // и низ сайдбара обрезался. Тянемся на весь предложенный размер, с тем же нижним порогом.
        .frame(minWidth: DS.SettingsWindow.minimumContentWidth, minHeight: DS.SettingsWindow.minimumContentHeight)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Colors.canvasTop)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        if showingSystemPreferencesPane {
            SystemPreferencesView(
                appLanguage: $config.language,
                hapticFeedbackEnabled: $config.hapticFeedbackEnabled,
                onExportSettings: exportSettingsToFile,
                onImportSettings: importSettingsFromFile
            )
        } else if let bundleId = selectedAppBundleId, config.appSubMenu(for: bundleId) != nil {
            AppSubMenuEditorView(
                bundleIdentifier: bundleId,
                appSubMenus: $config.appSubMenus,
                appCommandsMenu: config.menus.first(where: \.isAppCommandsMenu)
                    ?? PieConfiguration.templateAppCommandsMenu(),
                hapticFeedbackEnabled: config.hapticFeedbackEnabled,
                onReset: { removeApp(bundleId) }
            )
            .id(bundleId.lowercased())
        } else if let selId = selectedMenuId, let i = menuIndex, i < config.menus.count {
            MenuEditorView(
                menu: $config.menus[i],
                hapticFeedbackEnabled: $config.hapticFeedbackEnabled,
                trackpadFingerCount: bindingForTrackpadFingerCount(menuId: selId),
                trackpadFingerCountOwners: trackpadFingerCountOwners(excludingMenuId: selId),
                showAppearancePanel: $showAppearancePanel,
                otherMenuApplyTargets: config.menus.filter { $0.id != selId }.map { ($0.id, menuDisplayName($0)) },
                onApplySharedSettingsToMenuIds: { ids in
                    applySharedVisualSettings(fromMenuIndex: i, toMenuIds: ids)
                }
            )
            .id(selId)
            .onChange(of: selId) { _ in showAppearancePanel = false }
        } else {
            emptyState
        }
    }

    private var menuIndex: Int? {
        guard let id = selectedMenuId else { return nil }
        return config.menus.firstIndex(where: { $0.id == id })
    }

    private func menuDisplayName(_ menu: PieMenu) -> String {
        switch menu.kind {
        case .standard: return menu.name
        case .runningApps: return localizer.text(.activeAppsMenuTitle)
        case .appCommands: return localizer.text(.appCommandsMenuTitle)
        }
    }

    /// Binding по `id`, чтобы после удаления/перестановки меню не обращаться к `menus[i]` с устаревшим индексом.
    private func bindingForMenu(id: UUID) -> Binding<PieMenu> {
        Binding(
            get: {
                guard let idx = config.menus.firstIndex(where: { $0.id == id }) else {
                    return PieMenu()
                }
                return config.menus[idx]
            },
            set: { newValue in
                guard let idx = config.menus.firstIndex(where: { $0.id == id }) else { return }
                var next = config
                next.menus[idx] = newValue
                config = next
            }
        )
    }

    private func bindingForTrackpadFingerCount(menuId: UUID) -> Binding<Int> {
        Binding(
            get: { config.menus.first { $0.id == menuId }?.trackpadFingerCount ?? 0 },
            set: { config.assignTrackpadFingerCount($0, toMenuId: menuId) }
        )
    }

    /// Какие касания уже открывают другие меню — чтобы в выборе было видно, у кого число заберётся.
    private func trackpadFingerCountOwners(excludingMenuId menuId: UUID) -> [Int: String] {
        var owners: [Int: String] = [:]
        for menu in config.menus
        where menu.id != menuId && TrackpadGesture.isEnabled(fingerCount: menu.trackpadFingerCount) {
            owners[menu.trackpadFingerCount] = menuDisplayName(menu)
        }
        return owners
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.xl) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [DS.Colors.blueAccent.opacity(0.1), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: DS.Sizing.emptyStateHalo / 2
                        )
                    )
                    .frame(width: DS.Sizing.emptyStateHalo, height: DS.Sizing.emptyStateHalo)

                Image(systemName: "circle.grid.cross.fill")
                    .font(DS.Typography.emptyStateGlyph)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.secondary.opacity(0.5), .gray.opacity(0.2)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            Text(localizer.text(.selectOrCreateMenu))
                .font(DS.Typography.emptyTitle)
                .foregroundStyle(.primary)

            Button(action: addMenu) {
                Label(localizer.text(.newMenu), systemImage: "plus")
                    .font(DS.Typography.bodyEmphasized)
            }
            .buttonStyle(.borderedProminent)
            .tint(DS.Colors.blueAccent)
            .controlSize(.regular)
            .pointingHandCursor()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            DS.Colors.canvasTop
        )
    }

    // MARK: - Actions

    private func addMenu() {
        var menu = PieMenu(
            name: "\(localizer.text(.menuNamePrefix)) \(config.menus.count + 1)",
            items: placeholderItems()
        )
        if let template = PieMenu.mainTemplateMenu(from: config.menus) {
            menu.applySharedVisualSettings(from: template)
        }
        menu.rotationDegrees = 0
        let standardCount = config.menus.filter { !$0.isDynamicMenu }.count
        menu.globalSidebarIconColorHex = PieMenuItem.paletteColor(for: standardCount)
        withoutAnimation {
            config.menus.append(menu)
            showingSystemPreferencesPane = false
            selectedAppBundleId = nil
            selectedMenuId = menu.id
        }
    }

    /// Новый набор начинается с набора по умолчанию: его проще подправить, чем собрать с нуля.
    private func addApp(_ bundleId: String) {
        if config.appSubMenu(for: bundleId) == nil {
            let entries = config.defaultAppCommands.map(\.withNewID)
            config.appSubMenus.append(AppSubMenu(bundleIdentifier: bundleId, entries: entries))
        }
        withoutAnimation {
            showAppearancePanel = false
            showingSystemPreferencesPane = false
            selectedAppBundleId = bundleId
        }
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = localizer.text(.select)
        guard panel.runModal() == .OK, let url = panel.url,
              let descriptor = AppDescriptorResolver.resolve(from: url) else { return }
        addApp(descriptor.bundleIdentifier)
    }

    /// Без своего набора приложение снова получает автоматические команды. После удаления открываем
    /// само меню команд: там объяснено, откуда они берутся.
    private func removeApp(_ bundleId: String) {
        withoutAnimation {
            config.appSubMenus.removeAll { $0.matches(bundleIdentifier: bundleId) }
            if let selected = selectedAppBundleId, selected.caseInsensitiveCompare(bundleId) == .orderedSame {
                selectedAppBundleId = nil
                selectedMenuId = config.menus.first(where: \.isAppCommandsMenu)?.id ?? selectedMenuId
            }
        }
    }

    private func placeholderItems() -> [PieMenuItem] {
        let baseTitle = localizer.text(.newItem)
        var usedIcons: Set<String> = []

        return (0..<PieMenuItem.minItemCount).map { index in
            let icon = PieMenuItem.randomUnassignedSymbol(avoiding: usedIcons)
            usedIcons.insert(icon)
            return PieMenuItem(
                title: "\(baseTitle) \(index + 1)",
                icon: icon,
                action: .unassigned,
                color: PieMenuItem.paletteColor(for: index),
                sectorIndex: index
            )
        }
    }

    private func removeMenu(_ id: UUID) {
        guard let target = config.menus.first(where: { $0.id == id }), !target.isDynamicMenu else { return }
        withoutAnimation {
            config.menus.removeAll { $0.id == id }
            if selectedMenuId == id {
                selectedMenuId = config.menus.first?.id
            }
        }
    }

    private func applySharedVisualSettings(fromMenuIndex sourceIndex: Int, toMenuIds: Set<UUID>) {
        guard sourceIndex < config.menus.count else { return }
        let template = config.menus[sourceIndex]
        for j in config.menus.indices where toMenuIds.contains(config.menus[j].id) {
            config.menus[j].applySharedVisualSettings(from: template)
        }
    }

    private func exportSettingsToFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "pie-menu-settings.json"
        panel.isExtensionHidden = false
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let destination = panel.url else { return }

        do {
            try ConfigManager.shared.exportConfiguration(to: destination)
            backupAlert = BackupAlert(
                kind: .success,
                title: localizer.text(.settingsExportDoneTitle),
                message: String(format: localizer.text(.settingsExportDoneBodyFormat), destination.path)
            )
        } catch {
            backupAlert = BackupAlert(
                kind: .failure,
                title: localizer.text(.settingsExportFailedTitle),
                message: String(format: localizer.text(.settingsExportFailedBodyFormat), error.localizedDescription)
            )
        }
    }

    private func importSettingsFromFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json]

        guard panel.runModal() == .OK, let source = panel.url else { return }

        do {
            try ConfigManager.shared.importConfiguration(from: source)
            let imported = ConfigManager.shared.configuration
            config = imported
            showingSystemPreferencesPane = false
            selectedAppBundleId = nil
            selectedMenuId = imported.menus.first?.id
            backupAlert = BackupAlert(
                kind: .success,
                title: localizer.text(.settingsImportDoneTitle),
                message: String(format: localizer.text(.settingsImportDoneBodyFormat), source.lastPathComponent)
            )
        } catch {
            backupAlert = BackupAlert(
                kind: .failure,
                title: localizer.text(.settingsImportFailedTitle),
                message: localizer.text(.settingsImportFailedBody)
            )
        }
    }

    private func scheduleConfigSave(_ config: PieConfiguration) {
        pendingConfigForSave = config
        pendingSaveWorkItem?.cancel()

        let workItem = DispatchWorkItem {
            flushPendingConfigSave()
        }
        pendingSaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Timings.settingsSaveDebounce, execute: workItem)
    }

    private func flushPendingConfigSave() {
        pendingSaveWorkItem?.cancel()
        pendingSaveWorkItem = nil
        guard let configToSave = pendingConfigForSave else { return }
        pendingConfigForSave = nil
        ConfigManager.shared.save(configToSave)
    }

}

#Preview("Settings") {
    SettingsView()
        .environmentObject(LocalizationStore(language: .russian))
        .frame(width: DS.SettingsWindow.contentWidth, height: 700)
}
