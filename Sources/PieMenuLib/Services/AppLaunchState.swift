import Foundation

enum AppLaunchState {
    /// Если `PIE_FIRST_LAUNCH=1`, окно доступов показывается всегда (для проверок из терминала).
    private static let forceFirstLaunchEnvironmentKey = "PIE_FIRST_LAUNCH"
    private static let hasSeenPermissionIntroKey = "pie.hasSeenPermissionIntro"
    private static let hasAutoOpenedSettingsAfterPermissionsKey = "pie.hasAutoOpenedSettingsAfterPermissions"
    private static let settingsAutoOpenMigrationDoneKey = "pie.settingsAutoOpenAfterPermissionsMigrationDone"

    static var hasSeenPermissionIntro: Bool {
        get { UserDefaults.standard.bool(forKey: hasSeenPermissionIntroKey) }
        set { UserDefaults.standard.set(newValue, forKey: hasSeenPermissionIntroKey) }
    }

    /// Один раз: автоматически открыть окно настроек после первого получения всех нужных доступов.
    static var hasAutoOpenedSettingsAfterPermissionsComplete: Bool {
        get { UserDefaults.standard.bool(forKey: hasAutoOpenedSettingsAfterPermissionsKey) }
        set { UserDefaults.standard.set(newValue, forKey: hasAutoOpenedSettingsAfterPermissionsKey) }
    }

    /// Один раз при первом запуске версии с авто-настройками: у кого уже был пройден онбординг — не показывать окно.
    static func applySettingsAutoOpenMigrationForExistingInstallsIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: settingsAutoOpenMigrationDoneKey) else { return }
        UserDefaults.standard.set(true, forKey: settingsAutoOpenMigrationDoneKey)
        if hasSeenPermissionIntro {
            hasAutoOpenedSettingsAfterPermissionsComplete = true
        }
    }

    /// Окно доступов: первый запуск, принудительно из терминала, либо доступ отсутствует,
    /// а в конфиге есть хоткеи, которые без него не работают (⌘Tab, Fn).
    static func shouldShowPermissionsOnboarding(accessibilityGranted: Bool, needsAccessibility: Bool) -> Bool {
        if ProcessInfo.processInfo.environment[Self.forceFirstLaunchEnvironmentKey] == "1" {
            return true
        }
        if !hasSeenPermissionIntro { return true }
        return needsAccessibility && !accessibilityGranted
    }
}
