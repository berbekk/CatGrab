import AppKit
import Combine
import Foundation

/// Состояние значка в строке меню.
///
/// В macOS 26 сторонние `NSStatusItem` размещает системный ControlCenter, и приложение должно быть
/// разрешено в «Системные настройки → Строка меню → Разрешить в строке меню». Если запрет включён,
/// `statusItem(withLength:)` успешно возвращает элемент, но его окно так и остаётся с начальным
/// кадром за пределами экрана (высота 22, `screen == nil` или y < 0). На MacBook с вырезом значок
/// дополнительно может не поместиться — тогда он попадает в зону выреза.
@MainActor
final class MenuBarIconStatus: ObservableObject {
    enum Problem: Equatable {
        /// Значок не размещён системой (запрет в настройках «Строка меню» или ещё не разложен).
        case notPlacedBySystem
        /// Значок перекрыт вырезом экрана.
        case hiddenByNotch
    }

    static let shared = MenuBarIconStatus()

    @Published private(set) var problem: Problem?

    var isHidden: Bool { problem != nil }

    private init() {}

    func evaluate(statusItem: NSStatusItem?) {
        problem = Self.detectProblem(statusItem: statusItem)
    }

    static func openMenuBarSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.MenuBarSettings",
            "x-apple.systempreferences:com.apple.ControlCenter-Settings.extension?MenuBar",
            "x-apple.systempreferences:com.apple.ControlCenter-Settings.extension"
        ]
        for raw in candidates {
            if let url = URL(string: raw), NSWorkspace.shared.open(url) { return }
        }
    }

    private static func detectProblem(statusItem: NSStatusItem?) -> Problem? {
        guard let statusItem, statusItem.isVisible,
              let window = statusItem.button?.window else { return .notPlacedBySystem }
        let frame = window.frame
        guard frame.width > 0 else { return .notPlacedBySystem }

        let center = CGPoint(x: frame.midX, y: frame.midY)
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(center) }) else {
            return .notPlacedBySystem
        }

        // Размещённый элемент занимает всю высоту строки меню и лежит в её полосе.
        let menuBarBand = CGRect(
            x: screen.frame.minX,
            y: screen.visibleFrame.maxY,
            width: screen.frame.width,
            height: screen.frame.maxY - screen.visibleFrame.maxY
        )
        guard menuBarBand.height > 0, menuBarBand.intersects(frame) else {
            return .notPlacedBySystem
        }

        if #available(macOS 12.0, *),
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            let notch = CGRect(
                x: left.maxX,
                y: frame.minY,
                width: max(0, right.minX - left.maxX),
                height: frame.height
            )
            if notch.width > 0, notch.intersects(frame) {
                return .hiddenByNotch
            }
        }
        return nil
    }
}
