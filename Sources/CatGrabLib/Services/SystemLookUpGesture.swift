import AppKit
import Foundation

/// Системный жест «Поиск и детекторы данных» по касанию тремя пальцами. Он срабатывает вместе
/// с касанием, которым открывается меню CatGrab: под курсором всплывает словарь. Отменить системный
/// жест приложение не может (касания читаются, а не перехватываются), поэтому настройки CatGrab
/// предупреждают о нём и ведут в настройки трекпада.
enum SystemLookUpGesture {
    /// Настройки встроенного и Bluetooth-трекпада хранятся отдельно.
    private static let domains = [
        "com.apple.AppleMultitouchTrackpad",
        "com.apple.driver.AppleBluetoothMultitouch.trackpad"
    ]
    private static let key = "TrackpadThreeFingerTapGesture"

    /// Жест включён хотя бы у одного трекпада. Значение 0 или отсутствие ключа — выключен
    /// (тогда словарь вызывается нажатием с усилием), любое другое — включён.
    static func isEnabled(values: [Int?]) -> Bool {
        values.contains { ($0 ?? 0) != 0 }
    }

    static var isThreeFingerTapEnabled: Bool {
        isEnabled(values: domains.map { domain in
            CFPreferencesAppSynchronize(domain as CFString)
            return CFPreferencesCopyAppValue(key as CFString, domain as CFString) as? Int
        })
    }

    static func openTrackpadSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.Trackpad-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.trackpad"
        ]
        for raw in candidates {
            if let url = URL(string: raw), NSWorkspace.shared.open(url) { return }
        }
    }
}
