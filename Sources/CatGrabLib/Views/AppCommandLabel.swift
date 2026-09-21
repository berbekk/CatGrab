import AppKit
import SwiftUI

/// Подпись выделенной команды в меню «Команды приложения»: полное название и сочетание клавиш.
/// Значка в секторе мало, чтобы отличить «Новое окно» от «Нового частного окна».
struct PieSubActionLabel: View {
    let action: PieSubAction

    private static let titleFont = NSFont.systemFont(ofSize: 12.5, weight: .semibold)
    private static let shortcutFont = NSFont.systemFont(ofSize: 12, weight: .medium)
    private static let horizontalPadding: CGFloat = 11
    private static let verticalPadding: CGFloat = 6
    private static let spacing: CGFloat = 8
    /// Отступ подписи от внешнего края кольца.
    private static let distanceFromRing: CGFloat = 10
    private static let screenMargin: CGFloat = 6

    var body: some View {
        HStack(spacing: Self.spacing) {
            Text(action.title)
                .font(Font(Self.titleFont as CTFont))
                .foregroundStyle(action.isDestructive ? DS.Pie.destructiveSubSectorIcon : .white)
                .opacity(action.isEnabled ? 1 : 0.5)
            if let shortcut = action.shortcut {
                Text(shortcut)
                    .font(Font(Self.shortcutFont as CTFont))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, Self.horizontalPadding)
        .padding(.vertical, Self.verticalPadding)
        .background(Capsule().fill(Color.black.opacity(0.5)))
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.7))
    }

    /// Размер считаем заранее, чтобы поставить подпись снаружи кольца и не вылезти за край экрана.
    static func estimatedSize(for action: PieSubAction) -> CGSize {
        let title = (action.title as NSString).size(withAttributes: [.font: titleFont])
        var width = title.width
        var height = title.height
        if let shortcut = action.shortcut {
            let size = (shortcut as NSString).size(withAttributes: [.font: shortcutFont])
            width += spacing + size.width
            height = max(height, size.height)
        }
        return CGSize(
            width: ceil(width) + horizontalPadding * 2,
            height: ceil(height) + verticalPadding * 2
        )
    }

    /// Центр подписи: за внешним краем кольца напротив сектора `angle`, прижатый к краям окна.
    static func position(
        for action: PieSubAction,
        angle: Double,
        ringOuterRadius: Double,
        menuCenter: CGPoint,
        bounds: CGSize
    ) -> CGPoint {
        let size = estimatedSize(for: action)
        let direction = CGVector(dx: cos(angle), dy: sin(angle))
        let anchorDistance = CGFloat(ringOuterRadius) + distanceFromRing
        // Опорная функция прямоугольника: на столько нужно сдвинуть центр вдоль направления,
        // чтобы ближайшая к кольцу сторона коснулась точки привязки.
        let support = abs(direction.dx) * size.width / 2 + abs(direction.dy) * size.height / 2
        let distance = anchorDistance + support
        let raw = CGPoint(x: menuCenter.x + direction.dx * distance, y: menuCenter.y + direction.dy * distance)
        let halfWidth = size.width / 2 + screenMargin
        let halfHeight = size.height / 2 + screenMargin
        return CGPoint(
            x: min(max(raw.x, halfWidth), max(halfWidth, bounds.width - halfWidth)),
            y: min(max(raw.y, halfHeight), max(halfHeight, bounds.height - halfHeight))
        )
    }
}
