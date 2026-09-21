import AppKit
import CatGrabLib

// main.swift выполняется на главном потоке, но Swift пока считает его nonisolated.
// Явно переходим на MainActor, чтобы корректно создать @MainActor AppDelegate.
MainActor.assumeIsolated {
    // До первого обращения к конфигу: забираем настройки, сделанные ещё под именем PieMenu.
    LegacyPieMenuMigration.run()
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
