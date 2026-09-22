import Foundation

enum AppLaunchState {
    /// Если `CATGRAB_FIRST_LAUNCH=1`, знакомство показывается всегда (для проверок из терминала).
    private static let forceFirstLaunchEnvironmentKey = "CATGRAB_FIRST_LAUNCH"
    private static let hasCompletedOnboardingKey = "pie.hasCompletedOnboarding"
    /// Ключ первой версии: тогда знакомство было одним окном с правами. Кто его видел, тур не получает.
    private static let legacyHasSeenPermissionIntroKey = "pie.hasSeenPermissionIntro"
    private static let hasPromptedAccessibilityKey = "pie.hasPromptedAccessibility"
    private static let hasPromptedInputMonitoringKey = "pie.hasPromptedInputMonitoring"
    private static let afterRelaunchKey = "pie.afterRelaunch"

    /// Тур пройден или закрыт: больше не показывается сам. Права при этом могут быть и не выданы.
    static var hasCompletedOnboarding: Bool {
        get {
            UserDefaults.standard.bool(forKey: hasCompletedOnboardingKey)
                || UserDefaults.standard.bool(forKey: legacyHasSeenPermissionIntroKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: hasCompletedOnboardingKey)
            if !newValue {
                UserDefaults.standard.removeObject(forKey: legacyHasSeenPermissionIntroKey)
            }
        }
    }

    /// Системный диалог запроса показывается только один раз на приложение — второй раз macOS
    /// его не покажет, даже если доступ так и не дали. Отмечаем, что он уже был, чтобы кнопка
    /// в настройках не ждала его и сразу вела в System Settings.
    static var hasPromptedAccessibility: Bool {
        get { UserDefaults.standard.bool(forKey: hasPromptedAccessibilityKey) }
        set { UserDefaults.standard.set(newValue, forKey: hasPromptedAccessibilityKey) }
    }

    static var hasPromptedInputMonitoring: Bool {
        get { UserDefaults.standard.bool(forKey: hasPromptedInputMonitoringKey) }
        set { UserDefaults.standard.set(newValue, forKey: hasPromptedInputMonitoringKey) }
    }

    /// Что сделать сразу после перезапуска (WindowServer применяет «Мониторинг ввода» только к новому
    /// процессу). Без этого после перезапуска не появлялось ничего, и было непонятно, жив ли CatGrab.
    enum AfterRelaunch: String {
        /// Открыть настройки и сказать, что всё готово и каким сочетанием открывать меню.
        case openSettingsWithReadyBanner
        /// Окно настроек было открыто в момент перезапуска — вернуть его.
        case openSettings
    }

    static var afterRelaunch: AfterRelaunch? {
        get { UserDefaults.standard.string(forKey: afterRelaunchKey).flatMap(AfterRelaunch.init(rawValue:)) }
        set { UserDefaults.standard.set(newValue?.rawValue, forKey: afterRelaunchKey) }
    }

    /// С чего начать знакомство при запуске; `nil` — не показывать.
    enum OnboardingEntry: Equatable {
        /// Первый запуск: весь тур, права в конце.
        case tour
        /// Тур уже видели, но в конфиге есть сочетания (⌘Tab, Fn), которые без прав не работают:
        /// сразу страница с правами.
        case permissions
    }

    static func onboardingEntry(accessibilityGranted: Bool, needsAccessibility: Bool) -> OnboardingEntry? {
        let forced = ProcessInfo.processInfo.environment[Self.forceFirstLaunchEnvironmentKey] == "1"
        return onboardingEntry(
            hasCompletedOnboarding: hasCompletedOnboarding && !forced,
            accessibilityGranted: accessibilityGranted,
            needsAccessibility: needsAccessibility
        )
    }

    static func onboardingEntry(
        hasCompletedOnboarding: Bool,
        accessibilityGranted: Bool,
        needsAccessibility: Bool
    ) -> OnboardingEntry? {
        if !hasCompletedOnboarding { return .tour }
        return needsAccessibility && !accessibilityGranted ? .permissions : nil
    }
}
