import Foundation

/// Один срок для всего поиска, включая поиск по пути и запасной поиск по сочетанию.
/// Монотонные часы не зависят от смены времени; нулевой AX timeout означал бы системный default.
struct AXReadBudget {
    private let deadline: TimeInterval

    init(duration: TimeInterval, now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        deadline = now + duration
    }

    func timeout(at now: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Float? {
        let remaining = deadline - now
        guard remaining.isFinite, remaining > 0 else { return nil }
        let timeout = min(AppMenuCommandReader.messagingTimeout, Float(remaining))
        return timeout > 0 ? timeout : nil
    }

    var isExpired: Bool { timeout() == nil }
}
