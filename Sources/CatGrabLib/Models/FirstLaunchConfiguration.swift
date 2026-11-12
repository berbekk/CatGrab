import AppKit
import Foundation

extension AppLanguage {
    /// Язык интерфейса для первой установки: первый из языков системы, на который CatGrab переведён.
    /// `preferredLanguages` — как в `Locale.preferredLanguages`: «ru-RU», «zh-Hans-CN», «pt-BR».
    static func preferred(from preferredLanguages: [String]) -> AppLanguage {
        for identifier in preferredLanguages {
            let code = identifier.split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map { $0.lowercased() }
            if let code, let language = AppLanguage(rawValue: code) { return language }
        }
        return .english
    }
}

extension PieConfiguration {
    /// Конфиг для человека, который открыл CatGrab впервые: язык системы, название главного меню
    /// на этом языке, а секторы подписаны так, как приложения называются в его Finder
    /// («Заметки», а не «Notes»). `defaultConfig` остаётся неизменным английским образцом.
    static func firstLaunchConfig(
        preferredLanguages: [String] = Locale.preferredLanguages,
        appName: (String) -> String? = PieConfiguration.installedAppName
    ) -> PieConfiguration {
        var config = defaultConfig
        let language = AppLanguage.preferred(from: preferredLanguages)
        config.language = language
        guard let index = config.menus.firstIndex(where: { !$0.isDynamicMenu }) else { return config }
        config.menus[index].name = LocalizationStore(language: language).text(.defaultMainMenuName)
        for itemIndex in config.menus[index].items.indices {
            guard let bundleId = config.menus[index].items[itemIndex].action.bundleIdentifier,
                  let name = appName(bundleId), !name.isEmpty else { continue }
            config.menus[index].items[itemIndex].title = name
        }
        return config
    }

    /// Название установленного приложения, каким его показывает Finder; `nil` — приложения нет.
    static func installedAppName(bundleIdentifier: String) -> String? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else { return nil }
        let name = FileManager.default.displayName(atPath: url.path)
        return name.hasSuffix(".app") ? String(name.dropLast(4)) : name
    }
}
