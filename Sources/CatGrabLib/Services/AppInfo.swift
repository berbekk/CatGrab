import AppKit

/// Кто сделал приложение и где его найти — для «О приложении» в настройках и стандартного окна «О программе».
enum AppInfo {
    static let telegramURL = link("https://t.me/berbekk")
    static let githubURL = link("https://github.com/berbekk")
    static let repositoryURL = link("https://github.com/berbekk/CatGrab")
    static let issuesURL = link("https://github.com/berbekk/CatGrab/issues/new/choose")

    /// Адреса заданы здесь же и заведомо корректны; запасной вариант — только чтобы не падать.
    private static func link(_ string: String) -> URL {
        URL(string: string) ?? URL(fileURLWithPath: "/")
    }

    /// По-русски — как в паспорте, на остальных языках — латиницей.
    static func developerName(_ language: AppLanguage) -> String {
        language == .russian ? "Кудряш Василий" : "Kudriash Vasiliy"
    }

    /// «1.0.0 (1)»; `nil`, когда версии в бандле нет (тесты, превью).
    static var version: String? {
        guard let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else {
            return nil
        }
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return build.map { "\(short) (\($0))" } ?? short
    }

    /// Строки под названием в стандартном окне «О программе»: автор и ссылки, по которым можно кликнуть.
    static func aboutPanelCredits(localizer: LocalizationStore) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineSpacing = 2
        let base: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: paragraph
        ]
        let credits = NSMutableAttributedString(
            string: "\(localizer.text(.developerLabel)): \(developerName(localizer.language))\n",
            attributes: base
        )
        let links: [(String, URL)] = [
            ("Telegram", telegramURL),
            ("GitHub", githubURL),
            (localizer.text(.sourceCodeAction), repositoryURL)
        ]
        for (index, link) in links.enumerated() {
            if index > 0 {
                credits.append(NSAttributedString(string: "  ·  ", attributes: base))
            }
            var attributes = base
            attributes[.link] = link.1
            credits.append(NSAttributedString(string: link.0, attributes: attributes))
        }
        return credits
    }
}
