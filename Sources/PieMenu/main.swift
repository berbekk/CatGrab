import AppKit
import PieMenuLib

// main.swift выполняется на главном потоке, но Swift пока считает его nonisolated.
// Явно переходим на MainActor, чтобы корректно создать @MainActor AppDelegate.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
