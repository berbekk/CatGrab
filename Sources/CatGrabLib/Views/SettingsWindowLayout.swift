import Foundation

enum SettingsWindowLayout {
    static let screenInset: CGFloat = 16

    /// Окно полностью остаётся на рабочей области, включая заголовок и кнопки закрытия.
    /// Учитывает отрицательные координаты внешних экранов и их отключение.
    static func fittedFrame(_ frame: CGRect, visibleFrame: CGRect, minimumSize: CGSize) -> CGRect {
        let inset = min(screenInset, min(visibleFrame.width, visibleFrame.height) / 4)
        let available = visibleFrame.insetBy(dx: inset, dy: inset)
        let size = CGSize(
            width: min(max(frame.width, minimumSize.width), available.width),
            height: min(max(frame.height, minimumSize.height), available.height)
        )
        return CGRect(
            x: min(max(frame.minX, available.minX), available.maxX - size.width),
            y: min(max(frame.minY, available.minY), available.maxY - size.height),
            width: size.width,
            height: size.height
        )
    }
}
