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
    static func promptAccessibilityIfNeeded() {
        guard !AXIsProcessTrusted() else { return }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Системный диалог: macOS добавляет CatGrab в список «Мониторинг ввода».
    static func promptInputMonitoringIfNeeded() {
        guard !CGPreflightListenEventAccess() else { return }
        _ = CGRequestListenEventAccess()
    }

    static func requestAccessibility() {
        promptAccessibilityIfNeeded()
        DispatchQueue.main.asyncAfter(deadline: .now() + Timings.accessibilitySettingsOpenDelay) {
            guard !AXIsProcessTrusted() else { return }
            openSettingsPane(anchor: "Privacy_Accessibility")
        }
    }

    static func requestInputMonitoring() {
        promptInputMonitoringIfNeeded()
        DispatchQueue.main.asyncAfter(deadline: .now() + Timings.accessibilitySettingsOpenDelay) {
            guard !CGPreflightListenEventAccess() else { return }
            openSettingsPane(anchor: "Privacy_ListenEvent")
        }
    }

    static func openAccessibilitySettings() {
        openSettingsPane(anchor: "Privacy_Accessibility")
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
