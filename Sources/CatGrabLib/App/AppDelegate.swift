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
    private var statusAboutItem: NSMenuItem?
    private var statusSettingsItem: NSMenuItem?
    private var statusQuitItem: NSMenuItem?
    private var settingsMenuItem: NSMenuItem?
    private var quitMenuItem: NSMenuItem?
    private var hotkeyManager: HotkeyManager!
    private let trackpadGestureMonitor = TrackpadGestureMonitor()
    /// Какой жест сейчас слушаем — чтобы не переподключаться к трекпадам на каждое сохранение настроек.
    private var activeTrackpadFingerCounts: Set<Int> = []
    private var pieMenuWindow: PieMenuWindowController!
    private var settingsWindow: SettingsWindowController?
    private var onboardingController: OnboardingWindowController?
    private var onboardingRequestObserver: NSObjectProtocol?
    private var previousApp: NSRunningApplication?
    /// Меню команд ждёт, пока команды активного приложения соберутся; `nil` — не ждёт.
    private var pendingAppCommandsToken: UUID?
    private var appActivationObserver: NSObjectProtocol?
    private var appLaunchObserver: NSObjectProtocol?
    private var configurationObserver: NSObjectProtocol?
    private var didBecomeActiveObserver: NSObjectProtocol?
    private var screenParametersObserver: NSObjectProtocol?
    private var languageSubscription: AnyCancellable?
    private var appearanceSubscription: AnyCancellable?
    private var permissionsSubscription: AnyCancellable?

    deinit {
        if let token = configurationObserver { NotificationCenter.default.removeObserver(token) }
        if let token = didBecomeActiveObserver { NotificationCenter.default.removeObserver(token) }
        if let token = screenParametersObserver { NotificationCenter.default.removeObserver(token) }
        if let token = appActivationObserver { NSWorkspace.shared.notificationCenter.removeObserver(token) }
        if let token = appLaunchObserver { NSWorkspace.shared.notificationCenter.removeObserver(token) }
        if let token = onboardingRequestObserver { NotificationCenter.default.removeObserver(token) }
    }

    public override init() {
        super.init()
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    public func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager?.unregisterAll()
        trackpadGestureMonitor.stop()
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
        RunningAppsActivationHistory.startObservingIfNeeded()
        languageSubscription = ConfigManager.shared.configurationPublisher
            .map(\.language)
            .removeDuplicates()
            .sink { language in
                LocalizationStore.shared.language = language
            }
        appearanceSubscription = ConfigManager.shared.configurationPublisher
            .map(\.appearance)
            .removeDuplicates()
            .sink { appearance in
                NSApp.appearance = appearance.nsAppearance
            }
        setupMainMenu()
        NSApp.setActivationPolicy(.accessory)
        setupStatusBar()
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
                self?.prewarmMenuAssets()
            }
        }

        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.evaluateStatusItemVisibility(openSettingsIfHidden: false)
            }
        }

        onboardingRequestObserver = NotificationCenter.default.addObserver(
            forName: .showOnboardingRequested,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.showOnboarding(startPage: .welcome) }
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
                    if snapshot.accessibilityTrusted, self.onboardingController?.isVisible == true {
                        PermissionsSnapshot.promptInputMonitoringIfNeeded()
                    }
                    return
                }
                // В туре перезапуск делает последняя страница — с объяснением, зачем он.
                if let onboarding = self.onboardingController, onboarding.isVisible {
                    onboarding.permissionsGranted()
                    return
                }
                if self.hotkeyManager.hidTapIsRunningWithoutKeyEvents {
                    self.relaunchToApplyPermissions(afterRelaunch: self.settingsWindow?.isVisible == true ? .openSettings : nil)
                }
            }

        appActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            Task { @MainActor [weak self] in self?.prefetchAppCommands(for: app) }
        }

        // Установленное только что приложение: сектор с ним перестаёт быть приглушённым.
        appLaunchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bundleId = app.bundleIdentifier else { return }
            AppIconResolver.shared.noteLaunched(bundleIdentifier: bundleId)
        }

        // Кольцо и иконки готовятся заранее, после того как приложение уже запустилось и показало значок.
        DispatchQueue.main.async { [weak self] in
            self?.prewarmMenuAssets()
            self?.prewarmPieMenu()
        }

        screenParametersObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.evaluateStatusItemVisibility(openSettingsIfHidden: false) }
        }

        if ScreenshotMode.isEnabled {
            runScreenshotMode()
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.resumeAfterRelaunchOrPresentOnboarding()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Timings.statusItemLayoutSettleDelay) { [weak self] in
            self?.evaluateStatusItemVisibility(openSettingsIfHidden: true)
        }
    }

    /// Скриншоты для README: открыть окно, снять, выйти. См. `ScreenshotMode`.
    private func runScreenshotMode() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }
            switch ScreenshotMode.target {
            case .settings: self.openSettings()
            case .onboarding: self.showOnboarding(startPage: .welcome)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + ScreenshotMode.settleDelay) {
                if let window = NSApp.keyWindow ?? NSApp.windows.first(where: \.isVisible) {
                    ScreenshotMode.capture(window: window)
                }
                NSApp.terminate(nil)
            }
        }
    }

    /// После перезапуска ради прав — сразу настройки: иначе непонятно, запустилось ли приложение.
    /// Иначе — знакомство, если его ещё не было или без прав не работают заданные сочетания.
    private func resumeAfterRelaunchOrPresentOnboarding() {
        if let pending = AppLaunchState.afterRelaunch {
            AppLaunchState.afterRelaunch = nil
            ReadyBannerState.shared.isShown = pending == .openSettingsWithReadyBanner
            openSettings()
            return
        }
        let needsAccessibility = HotkeyHIDTap.requiresAccessibility(menus: ConfigManager.shared.configuration.menus)
        let granted = PermissionsMonitor.shared.snapshot.allRequiredGranted
        guard let entry = AppLaunchState.onboardingEntry(accessibilityGranted: granted, needsAccessibility: needsAccessibility) else {
            return
        }
        showOnboarding(startPage: entry == .tour ? .welcome : .permissions)
    }

    private func showOnboarding(startPage: OnboardingPage) {
        if let onboardingController, onboardingController.isVisible {
            onboardingController.model.page = startPage
            onboardingController.present(onClosed: {})
            return
        }
        let controller = OnboardingWindowController(startPage: startPage)
        controller.model.needsRelaunch = { [weak self] in self?.hotkeyManager?.hidTapIsRunningWithoutKeyEvents ?? false }
        controller.model.onFinish = { [weak self, weak controller] relaunch in
            guard let self else { return }
            AppLaunchState.hasCompletedOnboarding = true
            controller?.close()
            self.onboardingController = nil
            if relaunch {
                self.relaunchToApplyPermissions(afterRelaunch: .openSettingsWithReadyBanner)
            } else {
                ReadyBannerState.shared.isShown = true
                self.openSettings()
            }
        }
        onboardingController = controller
        controller.present { [weak self] in
            AppLaunchState.hasCompletedOnboarding = true
            self?.onboardingController = nil
        }
    }

    /// WindowServer отдаёт клавиши в event tap только новому процессу: после «Мониторинга ввода»
    /// нужен перезапуск. Что открыть после него, запоминаем заранее.
    private func relaunchToApplyPermissions(afterRelaunch: AppLaunchState.AfterRelaunch?) {
        AppLaunchState.afterRelaunch = afterRelaunch
        AppRelauncher.relaunch()
    }

    /// macOS 26 может запретить значок («Строка меню → Разрешить в строке меню»), а на MacBook
    /// с вырезом — спрятать его под вырез. В обоих случаях показываем окно настроек с подсказкой,
    /// иначе пользователь решит, что приложение не запустилось.
    private func evaluateStatusItemVisibility(openSettingsIfHidden: Bool) {
        MenuBarIconStatus.shared.evaluate(statusItem: statusItem)
        guard let problem = MenuBarIconStatus.shared.problem else { return }
        PieLog.ui.error("status item not visible: \(String(describing: problem), privacy: .public)")
        guard openSettingsIfHidden, onboardingController == nil else { return }
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
            ?? "CatGrab"

        let aboutItem = NSMenuItem(
            title: MenuTitles.about(appName: appName, language: localizer.language),
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
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
        statusItem.autosaveName = "CatGrabStatusItem"
        statusItem.isVisible = true
        if let button = statusItem.button {
            let icon = Self.statusBarIconImage()
            button.image = icon
            button.image?.isTemplate = true
            button.imagePosition = .imageOnly
            button.toolTip = "CatGrab"
            button.setAccessibilityLabel("CatGrab")
            button.setAccessibilityRole(.menuButton)
        }

        let menu = NSMenu()
        let localizer = LocalizationStore.shared
        let aboutItem = NSMenuItem(
            title: MenuTitles.about(appName: "CatGrab", language: localizer.language),
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        aboutItem.setAlwaysVisibleImage(Self.statusMenuItemIcon("info.circle"))
        statusAboutItem = aboutItem
        menu.addItem(aboutItem)
        let settingsItem = NSMenuItem(title: localizer.text(.statusSettings), action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        settingsItem.setAlwaysVisibleImage(Self.statusMenuItemIcon("gearshape"))
        statusSettingsItem = settingsItem
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: localizer.text(.statusQuit), action: #selector(quitApp), keyEquivalent: "")
        quitItem.target = self
        quitItem.setAlwaysVisibleImage(Self.statusMenuItemIcon("power"))
        statusQuitItem = quitItem
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    private func refreshLocalizedTitles() {
        let localizer = LocalizationStore.shared
        statusAboutItem?.title = MenuTitles.about(appName: "CatGrab", language: localizer.language)
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
        pieMenuWindow.onCommandSelected = { [weak self] action in
            self?.pieMenuWindow.hide()
            self?.performAppCommand(action)
        }
    }

    /// Окно кольца и его SwiftUI-дерево собираются заранее, чтобы первый хоткей не ждал их создания.
    private func prewarmPieMenu() {
        let menus = ConfigManager.shared.configuration.menus
        guard let menu = PieMenu.mainTemplateMenu(from: menus) ?? menus.first(where: { !$0.isDynamicMenu }) else { return }
        pieMenuWindow.prewarm(menu: menu)
    }

    /// Иконки приложений и картинки секторов всех меню — в кэш, пока меню никто не открывает.
    private func prewarmMenuAssets() {
        let configuration = ConfigManager.shared.configuration
        var bundleIdentifiers: [String] = []
        var filePaths: [String] = []
        func collect(icon: String, action: MenuAction?) {
            if let bundleId = action?.bundleIdentifier { bundleIdentifiers.append(bundleId) }
            if icon.hasPrefix("app:") { bundleIdentifiers.append(String(icon.dropFirst(4))) }
            if icon.hasPrefix("file:") { filePaths.append(String(icon.dropFirst(5))) }
        }
        for menu in configuration.menus {
            for item in menu.items { collect(icon: item.icon, action: item.action) }
            for entry in menu.appCommandsDefaultEntries { collect(icon: entry.resolvedIcon, action: entry.action) }
        }
        for set in configuration.appSubMenus {
            bundleIdentifiers.append(set.bundleIdentifier)
            for entry in set.entries { collect(icon: entry.resolvedIcon, action: entry.action) }
        }
        AppIconResolver.shared.prewarm(bundleIdentifiers: bundleIdentifiers)
        FileIconCache.shared.prewarm(paths: filePaths)
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
        setupTrackpadGesture(configuration)
        dismissRunningAppsMenuIfDisabled(configuration: configuration)
    }

    /// Общий жест из системных настроек и свои жесты меню распознаются одним монитором.
    private func setupTrackpadGesture(_ configuration: PieConfiguration) {
        trackpadGestureMonitor.onTap = { [weak self] fingerCount in
            self?.handleTrackpadGesture(fingerCount: fingerCount)
        }
        let fingerCounts = Set(configuration.trackpadGestureTargets().keys)
        guard fingerCounts != activeTrackpadFingerCounts else { return }
        activeTrackpadFingerCounts = fingerCounts
        if fingerCounts.isEmpty {
            trackpadGestureMonitor.stop()
        } else {
            trackpadGestureMonitor.start(fingerCounts: fingerCounts)
        }
    }

    /// Касание пальцами ничего не «держит», поэтому меню открывается как по клику:
    /// сектор выбирают курсором и кликом, повторное касание или Esc закрывают меню.
    private func handleTrackpadGesture(fingerCount: Int) {
        let configuration = ConfigManager.shared.configuration
        guard let idx = configuration.trackpadGestureTargets()[fingerCount] else { return }
        let menu = configuration.menus[idx]

        if !pieMenuWindow.isVisible {
            previousApp = NSWorkspace.shared.frontmostApplication
        }
        togglePieMenu(menu: menu, triggerHotkey: .empty)
    }

    private func dismissRunningAppsMenuIfDisabled(configuration: PieConfiguration) {
        guard pieMenuWindow.isVisible,
              let shownId = pieMenuWindow.displayedMenuId,
              let menu = configuration.menus.first(where: { $0.id == shownId }),
              menu.isDynamicMenu,
              !menu.runningAppsMenuEnabled else { return }
        pieMenuWindow.hide()
        restoreFocus()
    }

    private func handleHotkeyReleased(candidateIndices: [UInt32]) {
        let menus = ConfigManager.shared.configuration.menus
        // Одиночную клавишу отпустили раньше, чем команды приложения собрались: меню уже не нужно.
        if pendingAppCommandsToken != nil,
           let idx = resolveMenuIndex(fromCandidates: candidateIndices, menus: menus),
           menus[idx].isAppCommandsMenu,
           menus[idx].hotkey.carbonModifiers == 0 {
            pendingAppCommandsToken = nil
            previousApp = nil
            return
        }
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
        if menu.isDynamicMenu && !menu.runningAppsMenuEnabled { return }

        if !pieMenuWindow.isVisible {
            previousApp = NSWorkspace.shared.frontmostApplication
        }

        togglePieMenu(menu: menu, triggerHotkey: menu.hotkey)
    }

    /// Если у нескольких меню одно сочетание клавиш, повтор сочетания относится к показанному меню, иначе — первое по порядку.
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

        return menus.indices.first { candidateSet.contains($0) && !menus[$0].hotkey.isEmpty }
    }

    private func restoreAndExecute(item: PieMenuItem) {
        PieLog.launcher.debug("execute: \(item.title, privacy: .public)")
        // Переключение на приложение, ссылка и системное действие сами выводят вперёд своё окно.
        // Если сначала вернуть фокус прежнему приложению, а через паузу переключиться, экран дёргается дважды.
        guard item.action.needsPreviousAppFocus, let app = previousApp else {
            previousApp = nil
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

    /// Команда сама решает, куда отдать фокус: оставить его в приложении или вернуть туда, где был пользователь.
    private func performAppCommand(_ action: PieSubAction) {
        if case .customAction(let item) = action.kind {
            restoreAndExecute(item: item)
            return
        }
        let previous = previousApp
        previousApp = nil
        PieSubActionRunner.perform(action, previousApp: previous)
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
        } else if menu.isAppCommandsMenu {
            showAppCommands(menu: menu, triggerHotkey: triggerHotkey)
        } else {
            let chordNav: HotkeyConfig? = triggerHotkey.supportsRunningAppsRepeatKeyCycle
                ? triggerHotkey
                : nil
            pieMenuWindow.show(
                menu: menu,
                itemsOverride: resolvedItems(for: menu),
                navigationHotkeyForChordRepeat: chordNav
            )
            armModifierReleaseDismissal(triggerHotkey)
        }
    }

    private func armModifierReleaseDismissal(_ triggerHotkey: HotkeyConfig) {
        guard triggerHotkey.carbonModifiers != 0 else { return }
        pieMenuWindow.scheduleClickModeModifierChordReleaseDismissal(hotkey: triggerHotkey) { [weak self] in
            self?.handleClickModeModifierChordReleased()
        }
    }

    /// Меню команд активного приложения. Состояние окна и пункты меню читаются у приложения через
    /// Accessibility, поэтому меню показывается, когда они готовы (обычно сразу — пункты своего набора
    /// заранее найдены при переключении на приложение, см. `prefetchAppCommands`).
    private func showAppCommands(menu: PieMenu, triggerHotkey: HotkeyConfig) {
        guard let app = PieSubActionResolver.targetApp(), let bundleId = app.bundleIdentifier else {
            previousApp = nil
            return
        }
        let token = UUID()
        pendingAppCommandsToken = token
        PieSubActionResolver.resolve(app: app) { [weak self] actions in
            guard let self, self.pendingAppCommandsToken == token else { return }
            self.pendingAppCommandsToken = nil
            guard !actions.isEmpty, !self.pieMenuWindow.isVisible else { return }
            // Сочетание с модификаторами отпустили, пока собирались команды, — показывать уже поздно.
            if triggerHotkey.carbonModifiers != 0 {
                let held = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
                guard held.contains(triggerHotkey.nsDeviceIndependentModifierFlags) else {
                    self.previousApp = nil
                    return
                }
            }
            let configuration = ConfigManager.shared.configuration
            self.pieMenuWindow.show(
                menu: configuration.appCommandsMenu(menu, for: bundleId),
                appCommands: PieMenuWindowController.AppCommands(
                    bundleIdentifier: bundleId,
                    actions: actions,
                    entries: configuration.appSubMenu(for: bundleId)?.entries ?? configuration.defaultAppCommands
                )
            )
            self.armModifierReleaseDismissal(triggerHotkey)
        }
    }

    /// Пока пользователь работает в приложении, заранее ищем в его строке меню пункты своего набора —
    /// тогда меню команд откроется по хоткею без паузы. Только если меню команд вообще можно вызвать.
    private func prefetchAppCommands(for app: NSRunningApplication) {
        guard app.bundleIdentifier != Bundle.main.bundleIdentifier, app.activationPolicy == .regular else { return }
        let configuration = ConfigManager.shared.configuration
        guard let index = configuration.menus.firstIndex(where: \.isAppCommandsMenu) else { return }
        let menu = configuration.menus[index]
        let gestureOpensIt = configuration.trackpadGestureTargets().values.contains(index)
        guard menu.runningAppsMenuEnabled, !menu.hotkey.isEmpty || gestureOpensIt else { return }
        PieSubActionResolver.prefetch(app: app)
    }

    private func handleClickModeModifierChordReleased() {
        guard pieMenuWindow.isVisible else { return }
        let selection = pieMenuWindow.currentSelection
        pieMenuWindow.hide()
        switch selection {
        case .item(let item):
            restoreAndExecute(item: item)
        case .subAction(let action):
            performAppCommand(action)
        case nil:
            restoreFocus()
        }
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController()
        }
        settingsWindow?.show()
    }

    /// Стандартное окно «О программе» с автором и ссылками. У приложения в строке меню нет Дока,
    /// поэтому сначала выводим его вперёд — иначе окно откроется под другими.
    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: AppInfo.aboutPanelCredits(localizer: LocalizationStore.shared)
        ])
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private static func statusBarIconImage() -> NSImage {
        StatusBarIcon.make()
    }

    /// Иконка пункта меню строки меню: контурная, одного размера и веса у всех пунктов.
    /// Шаблонная — подстраивается под подсветку и тему.
    private static func statusMenuItemIcon(_ symbolName: String) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        return image
    }
}

extension Notification.Name {
    /// «Показать снова» в настройках: открыть знакомство с первой страницы.
    static let showOnboardingRequested = Notification.Name("CatGrab.showOnboardingRequested")
}

extension AppAppearance {
    /// `nil` — окна следуют системной теме.
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}
