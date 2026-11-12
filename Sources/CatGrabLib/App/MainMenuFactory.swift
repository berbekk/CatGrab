import AppKit

/// Главное меню приложения (видно, пока открыто окно настроек): стандартные пункты macOS
/// на языке интерфейса CatGrab — «О программе», «Настройки…», Правка, Окно.
@MainActor
enum MainMenuFactory {
    /// `target` получает `about` и `settings`; остальные пункты идут по цепочке респондеров.
    static func make(localizer: LocalizationStore, target: AnyObject, about: Selector, settings: Selector) -> NSMenu {
        let mainMenu = NSMenu()

        // App menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "CatGrab"

        let aboutItem = NSMenuItem(
            title: MenuTitles.about(appName: appName, language: localizer.language),
            action: about,
            keyEquivalent: ""
        )
        aboutItem.target = target
        appMenu.addItem(aboutItem)
        appMenu.addItem(NSMenuItem.separator())

        // Cmd+, — стандарт HIG для открытия настроек.
        let preferencesItem = NSMenuItem(
            title: localizer.text(.statusSettings) + "…",
            action: settings,
            keyEquivalent: ","
        )
        preferencesItem.keyEquivalentModifierMask = [.command]
        preferencesItem.target = target
        appMenu.addItem(preferencesItem)

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

        return mainMenu
    }
}
