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
        // Пример будущей миграции:
        // if config.schemaVersion < 2 {
        //     migrateV1ToV2(&config)
        //     config.schemaVersion = 2
        // }

        if config.schemaVersion > PieConfiguration.currentSchemaVersion {
            // Конфиг из будущей версии — оставляем как есть, теряя то, что старый код не понимает.
            config.schemaVersion = PieConfiguration.currentSchemaVersion
        }

        backfillGlobalSidebarIconColors(menus: &config.menus)
    }

    /// Старые конфиги и меню, созданные до появления поля: задаём цвет плитки в сайдбаре по порядку глобальных меню.
    private static func backfillGlobalSidebarIconColors(menus: inout [PieMenu]) {
        var ordinal = 0
        for i in menus.indices {
            guard menus[i].isGlobal, !menus[i].isRunningAppsMenu else { continue }
            if menus[i].globalSidebarIconColorHex == nil {
                menus[i].globalSidebarIconColorHex = PieMenuItem.paletteColor(for: ordinal)
            }
            ordinal += 1
        }
    }
}
