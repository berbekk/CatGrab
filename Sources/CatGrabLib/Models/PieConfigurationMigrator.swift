import Foundation

/// Централизованная точка для пошаговых миграций `PieConfiguration`.
/// Каждая миграция применяется при переходе с версии N к версии N+1 и фиксирует `schemaVersion`.
enum PieConfigurationMigrator {
    static func migrate(_ config: inout PieConfiguration) {
        // Пока нет активных миграций: любые старые конфиги (schemaVersion == 0) безопасно
        // маппятся в версию 1 через существующий `init(from:)`. Здесь — точка для будущих шагов.
        if config.schemaVersion < 1 {
            config.schemaVersion = 1
        }
        if config.schemaVersion < 2 {
            replaceLegacyUnassignedIcons(menus: &config.menus)
            config.schemaVersion = 2
        }
        if config.schemaVersion < 3 {
            upgradeAppCommandsDefaultSet(menus: &config.menus)
            config.schemaVersion = 3
        }

        if config.schemaVersion > PieConfiguration.currentSchemaVersion {
            // Конфиг из будущей версии — оставляем как есть, теряя то, что старый код не понимает.
            config.schemaVersion = PieConfiguration.currentSchemaVersion
        }

        backfillGlobalSidebarIconColors(menus: &config.menus)
    }

    /// v1 → v2: раньше каждый пустой пункт получал одну и ту же иконку кота. Меняем её на случайную,
    /// не повторяя иконки внутри меню. Шаг привязан к версии схемы и выполняется один раз — кота,
    /// выбранного вручную уже после обновления, миграция не трогает.
    private static func replaceLegacyUnassignedIcons(menus: inout [PieMenu]) {
        for m in menus.indices {
            var usedIcons = Set(menus[m].items.map(\.icon))
            for i in menus[m].items.indices {
                let item = menus[m].items[i]
                guard item.action == .unassigned,
                      item.icon == PieMenuItem.legacyUnassignedSFSymbol else { continue }
                let icon = PieMenuItem.randomUnassignedSymbol(avoiding: usedIcons)
                usedIcons.insert(icon)
                menus[m].items[i].icon = icon
            }
        }
    }

    /// v2 → v3: набор по умолчанию меню команд вырос с шести команд до восьми («Заполнить» и «По центру»),
    /// и восемь секторов стоят по сторонам кольца при своём повороте. Меняем только прежний набор из шести —
    /// в любом порядке; поворот под шесть секторов к восьми не подходит, поэтому он тоже новый.
    private static func upgradeAppCommandsDefaultSet(menus: inout [PieMenu]) {
        let previousDefault: Set<AppSubMenuEntry.Kind> = [.toggleFullScreen, .tileRight, .tileBottom, .quitApp, .tileLeft, .tileTop]
        for i in menus.indices where menus[i].isAppCommandsMenu {
            let kinds = menus[i].appCommandsDefaultEntries.map(\.kind)
            guard kinds.count == previousDefault.count, Set(kinds) == previousDefault else { continue }
            menus[i].appCommandsDefaultEntries = AppSubMenuEntry.automaticBuiltIns
            menus[i].rotationDegrees = AppSubMenuEntry.automaticRingRotationDegrees
        }
    }

    /// Старые конфиги и меню, созданные до появления поля: задаём цвет плитки в сайдбаре по порядку обычных меню.
    private static func backfillGlobalSidebarIconColors(menus: inout [PieMenu]) {
        var ordinal = 0
        for i in menus.indices {
            guard !menus[i].isDynamicMenu else { continue }
            if menus[i].globalSidebarIconColorHex == nil {
                menus[i].globalSidebarIconColorHex = PieMenuItem.paletteColor(for: ordinal)
            }
            ordinal += 1
        }
    }
}
