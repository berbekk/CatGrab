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
    /// Последнее выбранное подменю в группе приложения (ключ — bundle id в нижнем регистре).
    @State private var lastAppSubmenuSelection: [String: UUID] = [:]
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
            .onChange(of: selectedMenuId) { newId in
                guard let newId,
                      let m = config.menus.first(where: { $0.id == newId }),
                      let bid = m.boundAppBundleId else { return }
                lastAppSubmenuSelection[bid.lowercased()] = newId
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
                    showingSystemPreferencesPane: $showingSystemPreferencesPane,
                    showAppearancePanel: $showAppearancePanel,
                    onAddGlobalMenu: addGlobalMenu,
                    onAddAppMenu: addAppMenu,
                    onRemoveMenu: removeMenu,
                    onSelectAppBundleGroup: selectAppBundleGroup(bundleIdLower:),
                    onChangeBoundAppGroup: changeBoundAppGroup(bundleIdLower:)
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

            if let selId = selectedMenuId, let i = menuIndex, i < config.menus.count, !showingSystemPreferencesPane {
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
        .frame(width: DS.SettingsWindow.contentWidth, height: DS.SettingsWindow.contentHeight)
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
        } else if let selId = selectedMenuId, let i = menuIndex, i < config.menus.count {
            VStack(spacing: 0) {
                if let bid = config.menus[i].boundAppBundleId {
                    AppBoundMenusPanel(
                        config: $config,
                        selectedMenuId: $selectedMenuId,
                        bundleIdLower: bid.lowercased(),
                        onAddSibling: { addMenuForApp(bundleIdLower: bid.lowercased()) },
                        onRemoveMenu: removeMenu
                    )
                    .padding(.horizontal, DS.Spacing.l)
                    .padding(.top, DS.Spacing.s)
                    .padding(.bottom, DS.Spacing.xs)
                }
                MenuEditorView(
                    menu: $config.menus[i],
                    hapticFeedbackEnabled: $config.hapticFeedbackEnabled,
                    showAppearancePanel: $showAppearancePanel,
                    otherMenuApplyTargets: config.menus.filter { $0.id != selId }.map { ($0.id, menuDisplayName($0)) },
                    onApplySharedSettingsToMenuIds: { ids in
                        applySharedVisualSettings(fromMenuIndex: i, toMenuIds: ids)
                    }
                )
                .id(selId)
            }
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
        if menu.isRunningAppsMenu {
            return localizer.text(.activeAppsMenuTitle)
        }
        return menu.name
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

            VStack(spacing: DS.Spacing.s) {
                Text(localizer.text(.selectOrCreateMenu))
                    .font(DS.Typography.emptyTitle)
                    .foregroundStyle(.primary)
                Text(localizer.text(.addGlobalOrAppMenu))
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: DS.Spacing.s) {
                Button(action: addGlobalMenu) {
                    Label(localizer.text(.global), systemImage: "globe")
                        .font(DS.Typography.bodyEmphasized)
                }
                .buttonStyle(.borderedProminent)
                .tint(DS.Colors.blueAccent)
                .pointingHandCursor()

                Button(action: addAppMenu) {
                    Label(localizer.text(.forApp), systemImage: "app.badge")
                        .font(DS.Typography.bodyEmphasized)
                }
                .buttonStyle(.bordered)
                .pointingHandCursor()
            }
            .controlSize(.regular)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            DS.Colors.canvasTop
        )
    }

    // MARK: - Actions

    private func addGlobalMenu() {
        var menu = PieMenu(
            name: "\(localizer.text(.menuNamePrefix)) \(config.menus.count + 1)",
            items: placeholderItems()
        )
        if let template = PieMenu.mainTemplateMenu(from: config.menus) {
            menu.applySharedVisualSettings(from: template)
        }
        menu.rotationDegrees = 0
        let globalStandardCount = config.menus.filter { $0.isGlobal && !$0.isRunningAppsMenu }.count
        menu.globalSidebarIconColorHex = PieMenuItem.paletteColor(for: globalStandardCount)
        withoutAnimation {
            config.menus.append(menu)
            showingSystemPreferencesPane = false
            selectedMenuId = menu.id
        }
    }

    private func addAppMenu() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = localizer.text(.select)
        panel.message = localizer.text(.selectAppForMenu)

        guard panel.runModal() == .OK, let url = panel.url,
              let descriptor = AppDescriptorResolver.resolve(from: url) else { return }

        var menu = PieMenu(
            name: descriptor.displayName,
            hotkey: .empty,
            items: defaultItemsForAppMenu(),
            rotationDegrees: WindowTilingDefaults.defaultAppMenuRotationDegrees,
            boundAppBundleId: descriptor.bundleIdentifier,
            boundAppName: descriptor.displayName
        )
        if let template = PieMenu.mainTemplateMenu(from: config.menus) {
            menu.applySharedVisualSettings(from: template)
            menu.rotationDegrees = WindowTilingDefaults.defaultAppMenuRotationDegrees
        }
        withoutAnimation {
            config.menus.append(menu)
            showingSystemPreferencesPane = false
            selectedMenuId = menu.id
        }
    }

    private func placeholderItems() -> [PieMenuItem] {
        let baseTitle = localizer.text(.newItem)

        return (0..<PieMenuItem.minItemCount).map { index in
            PieMenuItem(
                title: "\(baseTitle) \(index + 1)",
                icon: PieMenuItem.unassignedSFSymbol,
                action: .unassigned,
                color: PieMenuItem.paletteColor(for: index),
                sectorIndex: index
            )
        }
    }

    private func defaultItemsForAppMenu() -> [PieMenuItem] {
        WindowTilingDefaults.halvesPieMenuItems(
            left: localizer.text(.appMenuTileLeft),
            right: localizer.text(.appMenuTileRight),
            top: localizer.text(.appMenuTileTop),
            bottom: localizer.text(.appMenuTileBottom)
        )
    }

    private func removeMenu(_ id: UUID) {
        guard let target = config.menus.first(where: { $0.id == id }), !target.isRunningAppsMenu else { return }
        let bundleKey = target.boundAppBundleId?.lowercased()
        let siblingAfterRemove = config.menus.filter {
            $0.id != id && $0.boundAppBundleId?.lowercased() == bundleKey
        }
        withoutAnimation {
            config.menus.removeAll { $0.id == id }
            if selectedMenuId == id {
                if let next = siblingAfterRemove.first?.id {
                    selectedMenuId = next
                } else {
                    if let bundleKey { lastAppSubmenuSelection[bundleKey] = nil }
                    selectedMenuId = config.menus.first?.id
                }
            }
        }
    }

    private func selectAppBundleGroup(bundleIdLower: String) {
        let group = config.menus.filter { $0.boundAppBundleId?.lowercased() == bundleIdLower }
        let pick: UUID?
        if let last = lastAppSubmenuSelection[bundleIdLower], group.contains(where: { $0.id == last }) {
            pick = last
        } else {
            pick = group.first?.id
        }
        showingSystemPreferencesPane = false
        selectedMenuId = pick
    }

    private func changeBoundAppGroup(bundleIdLower: String) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = localizer.text(.select)
        guard panel.runModal() == .OK, let url = panel.url,
              let descriptor = AppDescriptorResolver.resolve(from: url) else { return }
        let newBid = descriptor.bundleIdentifier
        let newName = descriptor.displayName
        for idx in config.menus.indices {
            guard let bid = config.menus[idx].boundAppBundleId,
                  bid.lowercased() == bundleIdLower else { continue }
            config.menus[idx].boundAppBundleId = newBid
            config.menus[idx].boundAppName = newName
        }
    }

    private func addMenuForApp(bundleIdLower: String) {
        guard let ref = config.menus.first(where: { $0.boundAppBundleId?.lowercased() == bundleIdLower }),
              let canonicalBid = ref.boundAppBundleId else { return }
        var displayName = ref.boundAppName ?? ""
        if displayName.isEmpty, let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: canonicalBid) {
            displayName = FileManager.default.displayName(atPath: appUrl.path)
        }
        let ordinal = config.menus.filter { $0.boundAppBundleId?.lowercased() == bundleIdLower }.count
        var menu = PieMenu(
            name: "\(localizer.text(.menuNamePrefix)) \(ordinal + 1)",
            hotkey: .empty,
            items: defaultItemsForAppMenu(),
            rotationDegrees: WindowTilingDefaults.defaultAppMenuRotationDegrees,
            boundAppBundleId: canonicalBid,
            boundAppName: displayName.isEmpty ? nil : displayName
        )
        if let template = PieMenu.mainTemplateMenu(from: config.menus) {
            menu.applySharedVisualSettings(from: template)
            menu.rotationDegrees = WindowTilingDefaults.defaultAppMenuRotationDegrees
        }
        withoutAnimation {
            config.menus.append(menu)
            showingSystemPreferencesPane = false
            selectedMenuId = menu.id
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
