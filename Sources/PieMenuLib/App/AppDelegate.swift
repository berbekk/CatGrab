import AppKit
import Combine

private enum TooltipTiming {
    /// Типичная системная задержка подсказки `.help()` ~1000 ms; целимся примерно в 2× быстрее.
    static let initialDelayMilliseconds = Timings.tooltipInitialDelayMilliseconds
    static let userDefaultsKey = "NSInitialToolTipDelay"
}

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var statusSettingsItem: NSMenuItem?
    private var statusQuitItem: NSMenuItem?
    private var settingsMenuItem: NSMenuItem?
    private var quitMenuItem: NSMenuItem?
    private var hotkeyManager: HotkeyManager!
    private var pieMenuWindow: PieMenuWindowController!
    private var snippetPreviewPopover: SnippetPreviewPopoverController?
    private var settingsWindow: SettingsWindowController?
    private var permissionsOnboardingController: PermissionsOnboardingWindowController?
    private var previousApp: NSRunningApplication?
    private var configurationObserver: NSObjectProtocol?
    private var didBecomeActiveObserver: NSObjectProtocol?
    private var screenParametersObserver: NSObjectProtocol?
    private var languageSubscription: AnyCancellable?
    private var permissionsSubscription: AnyCancellable?

    deinit {
        if let token = configurationObserver { NotificationCenter.default.removeObserver(token) }
        if let token = didBecomeActiveObserver { NotificationCenter.default.removeObserver(token) }
        if let token = screenParametersObserver { NotificationCenter.default.removeObserver(token) }
    }

    public override init() {
        super.init()
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    public func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager?.unregisterAll()
        NativeAppSwitcher.restore()
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return true
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        if UserDefaults.standard.object(forKey: TooltipTiming.userDefaultsKey) == nil {
            UserDefaults.standard.set(
                TooltipTiming.initialDelayMilliseconds,
                forKey: TooltipTiming.userDefaultsKey
            )
        }
        AppLaunchState.applySettingsAutoOpenMigrationForExistingInstallsIfNeeded()
        RunningAppsActivationHistory.startObservingIfNeeded()
        languageSubscription = ConfigManager.shared.configurationPublisher
            .map(\.language)
            .removeDuplicates()
            .sink { language in
                LocalizationStore.shared.language = language
            }
        setupMainMenu()
        NSApp.setActivationPolicy(.regular)
        setupStatusBar()
        NSApp.setActivationPolicy(.accessory)
        setupPieMenu()
        setupHotkeys()

        configurationObserver = NotificationCenter.default.addObserver(
            forName: .configurationDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshLocalizedTitles()
                self?.setupHotkeys()
            }
        }

        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.presentSettingsOnceIfFirstLaunchPermissionsComplete()
                self?.evaluateStatusItemVisibility(openSettingsIfHidden: false)
            }
        }

        // Права выданы в Системных настройках → сразу поднимаем HID-tap и закрываем онбординг.
        permissionsSubscription = PermissionsMonitor.shared.$snapshot
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] snapshot in
                guard let self else { return }
                self.setupHotkeys()
                guard snapshot.allRequiredGranted else {
                    // Универсальный доступ уже дали — следующим шагом сразу запрашиваем Мониторинг ввода.
                    if snapshot.accessibilityTrusted, self.permissionsOnboardingController != nil {
                        PermissionsSnapshot.promptInputMonitoringIfNeeded()
                    }
                    return
                }
                self.permissionsOnboardingController?.finishBecausePermissionsGranted()
                if self.hotkeyManager.hidTapIsRunningWithoutKeyEvents {
                    AppRelauncher.relaunch()
                }
            }

        screenParametersObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.evaluateStatusItemVisibility(openSettingsIfHidden: false) }
        }

        DispatchQueue.main.async { [weak self] in
            self?.presentFirstLaunchPermissionsIfNeeded()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Timings.statusItemLayoutSettleDelay) { [weak self] in
            self?.evaluateStatusItemVisibility(openSettingsIfHidden: true)
        }
    }

    private func presentFirstLaunchPermissionsIfNeeded() {
        let needsAccessibility = HotkeyHIDTap.requiresAccessibility(menus: ConfigManager.shared.configuration.menus)
        let granted = PermissionsMonitor.shared.snapshot.allRequiredGranted
        guard AppLaunchState.shouldShowPermissionsOnboarding(
            accessibilityGranted: granted,
            needsAccessibility: needsAccessibility
        ) else {
            presentSettingsOnceIfFirstLaunchPermissionsComplete()
            return
        }
        let c = PermissionsOnboardingWindowController()
        permissionsOnboardingController = c
        c.present { [weak self] in
            self?.permissionsOnboardingController = nil
            self?.presentSettingsOnceIfFirstLaunchPermissionsComplete()
        }
    }

    /// macOS 26 может запретить значок («Строка меню → Разрешить в строке меню»), а на MacBook
    /// с вырезом — спрятать его под вырез. В обоих случаях показываем окно настроек с подсказкой,
    /// иначе пользователь решит, что приложение не запустилось.
    private func evaluateStatusItemVisibility(openSettingsIfHidden: Bool) {
        MenuBarIconStatus.shared.evaluate(statusItem: statusItem)
        guard let problem = MenuBarIconStatus.shared.problem else { return }
        PieLog.ui.error("status item not visible: \(String(describing: problem), privacy: .public)")
        guard openSettingsIfHidden, permissionsOnboardingController == nil else { return }
        openSettings()
    }

    /// После онбординга доступов, когда все требования выполнены — один раз открыть настройки.
    private func presentSettingsOnceIfFirstLaunchPermissionsComplete() {
        guard !AppLaunchState.hasAutoOpenedSettingsAfterPermissionsComplete else { return }
        guard AppLaunchState.hasSeenPermissionIntro else { return }
        guard PermissionsSnapshot.current().allRequiredGranted else { return }
        AppLaunchState.hasAutoOpenedSettingsAfterPermissionsComplete = true
        openSettings()
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()
        let localizer = LocalizationStore.shared

        // App menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "PieMenu"

        let aboutItem = NSMenuItem(
            title: MenuTitles.about(appName: appName, language: localizer.language),
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(aboutItem)
        appMenu.addItem(NSMenuItem.separator())

        // Cmd+, — стандарт HIG для открытия настроек.
        let preferencesItem = NSMenuItem(
            title: localizer.text(.statusSettings) + "…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        preferencesItem.keyEquivalentModifierMask = [.command]
        preferencesItem.target = self
        appMenu.addItem(preferencesItem)
        settingsMenuItem = preferencesItem

        appMenu.addItem(NSMenuItem.separator())

        // Services submenu — стандартный для любого macOS-приложения.
        let servicesMenuItem = NSMenuItem(
            title: MenuTitles.services(language: localizer.language),
            action: nil,
            keyEquivalent: ""
        )
        let servicesMenu = NSMenu(title: "Services")
        servicesMenuItem.submenu = servicesMenu
        NSApp.servicesMenu = servicesMenu
        appMenu.addItem(servicesMenuItem)

        appMenu.addItem(NSMenuItem.separator())

        let hideItem = NSMenuItem(
            title: MenuTitles.hide(appName: appName, language: localizer.language),
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        )
        appMenu.addItem(hideItem)

        let hideOthersItem = NSMenuItem(
            title: MenuTitles.hideOthers(language: localizer.language),
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h"
        )
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthersItem)

        let showAllItem = NSMenuItem(
            title: MenuTitles.showAll(language: localizer.language),
            action: #selector(NSApplication.unhideAllApplications(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(showAllItem)

        appMenu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: MenuTitles.quit(appName: appName, language: localizer.language),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenu.addItem(quitItem)
        quitMenuItem = quitItem

        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // Edit menu (responder chain делает Undo/Redo рабочими в текстовых полях).
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: MenuTitles.edit(language: localizer.language))
        editMenu.addItem(withTitle: MenuTitles.undo(language: localizer.language),
                         action: Selector(("undo:")), keyEquivalent: "z")
        let redoItem = NSMenuItem(
            title: MenuTitles.redo(language: localizer.language),
            action: Selector(("redo:")),
            keyEquivalent: "z"
        )
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redoItem)
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: MenuTitles.cut(language: localizer.language),
                         action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: MenuTitles.copy(language: localizer.language),
                         action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: MenuTitles.paste(language: localizer.language),
                         action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: MenuTitles.delete(language: localizer.language),
                         action: #selector(NSText.delete(_:)), keyEquivalent: "")
        editMenu.addItem(withTitle: MenuTitles.selectAll(language: localizer.language),
                         action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // Window menu (Minimize/Zoom — `SettingsWindowController` скрывает стандартный заголовок, но AppKit-способы всё равно работают).
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: MenuTitles.window(language: localizer.language))
        windowMenu.addItem(withTitle: MenuTitles.minimize(language: localizer.language),
                           action: #selector(NSWindow.performMiniaturize(_:)),
                           keyEquivalent: "m")
        windowMenu.addItem(withTitle: MenuTitles.zoom(language: localizer.language),
                           action: #selector(NSWindow.performZoom(_:)),
                           keyEquivalent: "")
        windowMenu.addItem(NSMenuItem.separator())
        windowMenu.addItem(withTitle: MenuTitles.bringAllToFront(language: localizer.language),
                           action: #selector(NSApplication.arrangeInFront(_:)),
                           keyEquivalent: "")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)
        NSApp.windowsMenu = windowMenu

        NSApp.mainMenu = mainMenu
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.isVisible = true
        if let button = statusItem.button {
            let icon = Self.statusBarIconImage()
            button.image = icon
            button.image?.isTemplate = true
            button.imagePosition = .imageOnly
            button.toolTip = "PieMenu"
            button.setAccessibilityLabel("PieMenu")
            button.setAccessibilityRole(.menuButton)
        }

        let menu = NSMenu()
        let localizer = LocalizationStore.shared
        let settingsItem = NSMenuItem(title: localizer.text(.statusSettings), action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        settingsItem.image = NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: localizer.text(.statusSettings))
        statusSettingsItem = settingsItem
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: localizer.text(.statusQuit), action: #selector(quitApp), keyEquivalent: "")
        quitItem.target = self
        quitItem.image = NSImage(systemSymbolName: "rectangle.portrait.and.arrow.right", accessibilityDescription: localizer.text(.statusQuit))
        statusQuitItem = quitItem
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    private func refreshLocalizedTitles() {
        let localizer = LocalizationStore.shared
        statusSettingsItem?.title = localizer.text(.statusSettings)
        statusQuitItem?.title = localizer.text(.statusQuit)
        // Главное меню пересобираем целиком — дешевле, чем следить за каждым пунктом.
        setupMainMenu()
    }

    private func setupPieMenu() {
        pieMenuWindow = PieMenuWindowController()
        pieMenuWindow.onItemSelected = { [weak self] item in
            self?.pieMenuWindow.hide()
            self?.restoreAndExecute(item: item)
        }
        pieMenuWindow.onHoverChanged = { [weak self] item in
            self?.updateSnippetPreview(for: item)
        }
        pieMenuWindow.onHide = { [weak self] in
            self?.snippetPreviewPopover?.hide()
        }
    }

    /// Показывает бабл с превью текста сниппета под иконкой приложения в меню‑баре.
    /// Для всех прочих типов действий скрывает его.
    private func updateSnippetPreview(for item: PieMenuItem?) {
        guard let item, case .snippet(let text) = item.action else {
            snippetPreviewPopover?.hide()
            return
        }
        if snippetPreviewPopover == nil {
            snippetPreviewPopover = SnippetPreviewPopoverController()
        }
        snippetPreviewPopover?.show(
            text: text,
            caption: LocalizationStore.shared.text(.actionTypeSnippet),
            anchor: statusItem
        )
    }

    private func setupHotkeys() {
        if hotkeyManager == nil {
            hotkeyManager = HotkeyManager()
        } else {
            hotkeyManager.unregisterAll()
        }

        hotkeyManager.onHotkeyPressed = { [weak self] candidateIndices in
            DispatchQueue.main.async {
                self?.handleHotkeyPressed(candidateIndices: candidateIndices)
            }
        }
        hotkeyManager.onHotkeyReleased = { [weak self] candidateIndices in
            DispatchQueue.main.async {
                self?.handleHotkeyReleased(candidateIndices: candidateIndices)
            }
        }

        let configuration = ConfigManager.shared.configuration
        hotkeyManager.registerAll(menus: configuration.menus)
        dismissRunningAppsMenuIfDisabled(configuration: configuration)
    }

    private func dismissRunningAppsMenuIfDisabled(configuration: PieConfiguration) {
        guard pieMenuWindow.isVisible,
              let shownId = pieMenuWindow.displayedMenuId,
              let menu = configuration.menus.first(where: { $0.id == shownId }),
              menu.isRunningAppsMenu,
              !menu.runningAppsMenuEnabled else { return }
        pieMenuWindow.hide()
        restoreFocus()
    }

    private func handleHotkeyReleased(candidateIndices: [UInt32]) {
        let menus = ConfigManager.shared.configuration.menus
        guard pieMenuWindow.isVisible,
              let shownId = pieMenuWindow.displayedMenuId,
              let idx = resolveMenuIndex(fromCandidates: candidateIndices, menus: menus),
              idx < menus.count,
              menus[idx].id == shownId else { return }
        let trigger = menus[idx].hotkey

        if trigger.supportsRunningAppsRepeatKeyCycle {
            pieMenuWindow.clearChordNavigationInitialHoldSuppression()
        }

        // Hold-to-show для одиночных хоткеев (без модификаторов): отпускание главной клавиши
        // закрывает меню и выполняет выделенный сектор, если есть.
        // Для хоткеев с модификаторами закрытием управляет `scheduleClickModeModifierChordReleaseDismissal`.
        if trigger.carbonModifiers == 0 && !trigger.isEmpty {
            handleClickModeModifierChordReleased()
        }
    }

    private func handleHotkeyPressed(candidateIndices: [UInt32]) {
        let menus = ConfigManager.shared.configuration.menus
        guard let idx = resolveMenuIndex(fromCandidates: candidateIndices, menus: menus) else { return }
        let menu = menus[idx]
        if menu.isRunningAppsMenu && !menu.runningAppsMenuEnabled { return }

        if !pieMenuWindow.isVisible {
            previousApp = NSWorkspace.shared.frontmostApplication
        }

        togglePieMenu(menu: menu, triggerHotkey: menu.hotkey)
    }

    /// Несколько меню могут иметь одно сочетание клавиш (глобальное + для разных приложений); выбираем по фокусу и порядку в конфиге.
    private func resolveMenuIndex(fromCandidates candidateIndices: [UInt32], menus: [PieMenu]) -> Int? {
        let candidateSet = Set(candidateIndices.map(Int.init))
        guard !candidateSet.isEmpty else { return nil }

        if pieMenuWindow.isVisible,
           let shownId = pieMenuWindow.displayedMenuId,
           let shownIdx = menus.firstIndex(where: { $0.id == shownId }),
           candidateSet.contains(shownIdx),
           !menus[shownIdx].hotkey.isEmpty {
            return shownIdx
        }

        let frontBundle = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

        for i in menus.indices {
            guard candidateSet.contains(i) else { continue }
            let m = menus[i]
            guard !m.hotkey.isEmpty, !m.isGlobal, let bid = m.boundAppBundleId else { continue }
            if bid == frontBundle { return i }
        }

        for i in menus.indices {
            guard candidateSet.contains(i) else { continue }
            let m = menus[i]
            if m.isGlobal, !m.hotkey.isEmpty { return i }
        }

        return nil
    }

    private func restoreAndExecute(item: PieMenuItem) {
        guard let app = previousApp else {
            AppLauncher.execute(
                item: item,
                targetPID: NSWorkspace.shared.frontmostApplication?.processIdentifier
            )
            return
        }
        let pid = app.processIdentifier
        previousApp = nil
        app.activate()
        DispatchQueue.main.asyncAfter(deadline: .now() + Timings.focusRestorationDelay) {
            AppLauncher.execute(item: item, targetPID: pid)
        }
    }

    private func restoreFocus() {
        previousApp?.activate()
        previousApp = nil
    }

    private func resolvedItems(for menu: PieMenu) -> [PieMenuItem]? {
        if menu.kind == .runningApps {
            return RunningAppsMenuItems.build(for: menu)
        }
        return nil
    }

    private func togglePieMenu(menu: PieMenu, triggerHotkey: HotkeyConfig) {
        if pieMenuWindow.isVisible {
            if triggerHotkey.supportsRunningAppsRepeatKeyCycle,
               pieMenuWindow.displayedMenuId == menu.id {
                if !pieMenuWindow.isChordNavigationAdvanceSuppressed {
                    pieMenuWindow.advanceRunningAppsSelection()
                }
                return
            }
            pieMenuWindow.hide()
            restoreFocus()
        } else {
            let chordNav: HotkeyConfig? = triggerHotkey.supportsRunningAppsRepeatKeyCycle
                ? triggerHotkey
                : nil
            pieMenuWindow.show(
                menu: menu,
                itemsOverride: resolvedItems(for: menu),
                navigationHotkeyForChordRepeat: chordNav
            )
            if triggerHotkey.carbonModifiers != 0 {
                pieMenuWindow.scheduleClickModeModifierChordReleaseDismissal(hotkey: triggerHotkey) { [weak self] in
                    self?.handleClickModeModifierChordReleased()
                }
            }
        }
    }

    private func handleClickModeModifierChordReleased() {
        guard pieMenuWindow.isVisible else { return }
        let item = pieMenuWindow.currentHoveredItem
        pieMenuWindow.hide()
        if let item {
            restoreAndExecute(item: item)
        } else {
            restoreFocus()
        }
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController()
        }
        settingsWindow?.show()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private static func statusBarIconImage() -> NSImage {
        StatusBarIcon.make()
    }
}
