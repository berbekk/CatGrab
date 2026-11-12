import AppKit
import Foundation

/// Номер версии «1.4.0»: сравнивается по числам, а не как строка («1.10» новее «1.9»).
struct AppVersion: Comparable {
    let components: [Int]

    /// Понимает «1.4.0», «v1.4.0» и «1.4.0 (12)»; хвост после чисел (сборка, «-beta») отбрасывается.
    init?(_ string: String) {
        var text = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("v") || text.hasPrefix("V") { text.removeFirst() }
        let core = text.prefix { $0.isASCII && ($0.isNumber || $0 == ".") }
        let parts = core.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard !parts.isEmpty, parts.count <= 4, !parts.contains(nil) else { return nil }
        components = parts.compactMap { $0 }
    }

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right { return left < right }
        }
        return false
    }

    static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }
}

/// Новая версия на GitHub: номер без «v» и страница, с которой её скачивают.
struct AvailableUpdate: Equatable {
    let version: String
    let pageURL: URL
}

enum UpdateCheckState: Equatable {
    case idle
    case checking
    case upToDate
    case available(AvailableUpdate)
    case failed
}

/// Проверка обновлений. У CatGrab нет платной подписи Apple, поэтому приложение не обновляет себя
/// само: оно только узнаёт у GitHub номер последнего выпуска и ведёт на страницу загрузки.
///
/// В запросе нет ничего о пользователе. Автоматическая проверка (раз в сутки) включается в общих
/// настройках и по умолчанию выключена — сам по себе CatGrab в сеть не ходит.
@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    nonisolated static let latestReleaseAPI = "https://api.github.com/repos/berbekk/CatGrab/releases/latest"
    nonisolated static let releasesPage = "https://github.com/berbekk/CatGrab/releases/latest"
    /// Страницу выпуска открываем, только если она в репозитории CatGrab; иначе — общую страницу выпусков.
    nonisolated static let trustedPagePrefix = "https://github.com/berbekk/CatGrab/"

    private static let automaticChecksKey = "pie.updates.automaticChecks"
    private static let lastCheckKey = "pie.updates.lastCheck"
    private static let skippedVersionKey = "pie.updates.skippedVersion"
    nonisolated private static let automaticInterval: TimeInterval = 24 * 60 * 60

    @Published private(set) var state: UpdateCheckState = .idle
    @Published var automaticChecksEnabled: Bool {
        didSet {
            guard automaticChecksEnabled != oldValue else { return }
            defaults.set(automaticChecksEnabled, forKey: Self.automaticChecksKey)
            if automaticChecksEnabled { checkAutomaticallyIfDue() }
        }
    }
    /// Версия, про которую человек сказал «не напоминать»: баннер и пункт меню о ней молчат.
    @Published private(set) var skippedVersion: String?

    private let defaults: UserDefaults
    private let currentVersion: String?
    private let fetch: (URLRequest) async throws -> Data
    private var timer: Timer?

    init(
        defaults: UserDefaults = .standard,
        currentVersion: String? = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
        fetch: @escaping (URLRequest) async throws -> Data = UpdateChecker.fetchFromNetwork
    ) {
        self.defaults = defaults
        self.currentVersion = currentVersion
        self.fetch = fetch
        automaticChecksEnabled = defaults.bool(forKey: Self.automaticChecksKey)
        skippedVersion = defaults.string(forKey: Self.skippedVersionKey)
        if let simulated = ScreenshotMode.simulatedUpdateVersion, let page = URL(string: Self.releasesPage) {
            state = .available(AvailableUpdate(version: simulated, pageURL: page))
        }
    }

    /// Обновление, о котором стоит напомнить: найдено и не пропущено.
    var updateToAnnounce: AvailableUpdate? {
        guard case .available(let update) = state, update.version != skippedVersion else { return nil }
        return update
    }

    /// При запуске и дальше раз в несколько часов: если проверки включены и с прошлой прошли сутки.
    func startAutomaticChecks() {
        guard timer == nil else { return }
        checkAutomaticallyIfDue()
        let timer = Timer(timeInterval: 6 * 60 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.checkAutomaticallyIfDue() }
        }
        timer.tolerance = 10 * 60
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func checkAutomaticallyIfDue(now: Date = Date()) {
        guard automaticChecksEnabled, !ScreenshotMode.isEnabled else { return }
        let last = defaults.object(forKey: Self.lastCheckKey) as? Date
        guard Self.isCheckDue(lastCheck: last, now: now) else { return }
        Task { await check() }
    }

    nonisolated static func isCheckDue(lastCheck: Date?, now: Date) -> Bool {
        guard let lastCheck else { return true }
        // Часы перевели назад — прошлую проверку считаем устаревшей, а не ждём «до будущего».
        return now.timeIntervalSince(lastCheck) >= automaticInterval || lastCheck > now
    }

    /// Спросить GitHub о последнем выпуске. Ошибку сети показывает только ручная проверка:
    /// автоматическая молча попробует в следующий раз.
    func check(userInitiated: Bool = false) async {
        guard state != .checking else { return }
        guard let currentVersion, let url = URL(string: Self.latestReleaseAPI) else {
            if userInitiated { state = .failed }
            return
        }
        let previous = state
        state = .checking
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("CatGrab", forHTTPHeaderField: "User-Agent")
        do {
            let data = try await fetch(request)
            defaults.set(Date(), forKey: Self.lastCheckKey)
            switch Self.evaluate(releaseJSON: data, currentVersion: currentVersion) {
            case .available(let update): state = .available(update)
            case .upToDate: state = .upToDate
            case .unreadable: state = userInitiated ? .failed : previous.settled
            }
        } catch {
            PieLog.config.error("update check failed: \(String(describing: error), privacy: .public)")
            state = userInitiated ? .failed : previous.settled
        }
    }

    /// Не напоминать об этой версии; о следующей напомним снова.
    func skip(_ update: AvailableUpdate) {
        skippedVersion = update.version
        defaults.set(update.version, forKey: Self.skippedVersionKey)
    }

    func openDownloadPage(for update: AvailableUpdate) {
        NSWorkspace.shared.open(update.pageURL)
    }

    enum ReleaseEvaluation: Equatable {
        /// Ответ не разобрать: не JSON выпуска или номер версии не число.
        case unreadable
        case upToDate
        case available(AvailableUpdate)
    }

    private struct Release: Decodable {
        let tagName: String
        let pageURL: String?
        let draft: Bool?
        let prerelease: Bool?

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case pageURL = "html_url"
            case draft
            case prerelease
        }
    }

    /// Ответ GitHub → есть ли версия новее текущей. Черновики и пререлизы не считаются.
    nonisolated static func evaluate(releaseJSON: Data, currentVersion: String) -> ReleaseEvaluation {
        guard let release = try? JSONDecoder().decode(Release.self, from: releaseJSON),
              let latest = AppVersion(release.tagName),
              let current = AppVersion(currentVersion) else { return .unreadable }
        guard release.draft != true, release.prerelease != true, current < latest else { return .upToDate }
        let page = release.pageURL
            .flatMap { $0.hasPrefix(trustedPagePrefix) ? URL(string: $0) : nil }
            ?? URL(string: releasesPage)
        guard let page else { return .unreadable }
        let version = latest.components.map(String.init).joined(separator: ".")
        return .available(AvailableUpdate(version: version, pageURL: page))
    }

    nonisolated static func fetchFromNetwork(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}

private extension UpdateCheckState {
    /// Во что вернуться после неудачной тихой проверки: прежний итог, но не «проверяю».
    var settled: UpdateCheckState {
        self == .checking ? .idle : self
    }
}
