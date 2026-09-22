import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

/// Права TCC для HID-перехвата (⌘Tab, Fn): «Универсальный доступ» — чтобы создать активный tap,
/// «Мониторинг ввода» — чтобы WindowServer вообще передавал в него нажатия клавиш.
struct PermissionsSnapshot: Equatable {
    let accessibilityTrusted: Bool
    let inputMonitoringGranted: Bool

    static func current() -> PermissionsSnapshot {
        PermissionsSnapshot(
            accessibilityTrusted: AXIsProcessTrusted(),
            inputMonitoringGranted: CGPreflightListenEventAccess()
        )
    }

    static func initiallyPessimistic() -> PermissionsSnapshot {
        PermissionsSnapshot(accessibilityTrusted: false, inputMonitoringGranted: false)
    }

    var allRequiredGranted: Bool { accessibilityTrusted && inputMonitoringGranted }

    /// Системный диалог: macOS сам добавляет CatGrab в список «Универсальный доступ» (выключенным).
    /// Показывается только один раз за всё время — второй вызов молча возвращает текущий статус,
    /// без диалога, даже если доступа так и не дали.
    static func promptAccessibilityIfNeeded() {
        guard !AXIsProcessTrusted() else { return }
        AppLaunchState.hasPromptedAccessibility = true
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Системный диалог: macOS добавляет CatGrab в список «Мониторинг ввода». Тоже разовый.
    static func promptInputMonitoringIfNeeded() {
        guard !CGPreflightListenEventAccess() else { return }
        AppLaunchState.hasPromptedInputMonitoring = true
        _ = CGRequestListenEventAccess()
    }

    /// Кнопка «Открыть настройки» в карточке доступов. Первый клик — системный диалог: он сам
    /// добавляет CatGrab в список и предлагает открыть настройки или отказать. Второй раз этот
    /// диалог не появится (macOS показывает его один раз на приложение), поэтому дальше сразу
    /// открываем нужную панель сами — иначе кнопка на повторный клик ничего бы не делала.
    static func requestAccessibility() {
        guard !AXIsProcessTrusted() else { return }
        guard AppLaunchState.hasPromptedAccessibility else {
            promptAccessibilityIfNeeded()
            return
        }
        openSettingsPane(anchor: "Privacy_Accessibility")
    }

    static func requestInputMonitoring() {
        guard !CGPreflightListenEventAccess() else { return }
        guard AppLaunchState.hasPromptedInputMonitoring else {
            promptInputMonitoringIfNeeded()
            return
        }
        openSettingsPane(anchor: "Privacy_ListenEvent")
    }

    private static func openSettingsPane(anchor: String) {
        let candidates = [
            "x-apple.systempreferences:com.apple.preference.security?\(anchor)",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?\(anchor)"
        ]
        for raw in candidates {
            if let url = URL(string: raw), NSWorkspace.shared.open(url) { return }
        }
    }
}
