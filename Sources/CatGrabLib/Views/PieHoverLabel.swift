import AppKit
import SwiftUI

/// Подпись выделенного сектора снаружи кольца: название и, приглушённо, что выполнится —
/// сочетание команды, адрес ссылки, начало текста. Значка в секторе мало, чтобы отличить
/// «Новое окно» от «Нового частного окна» или один сниппет от другого.
struct PieHoverLabel: View {
    let title: String
    var detail: String?
    var isDestructive = false
    var isEnabled = true

    private static let titleFont = NSFont.systemFont(ofSize: 12.5, weight: .semibold)
    private static let detailFont = NSFont.systemFont(ofSize: 12, weight: .medium)
    private static let horizontalPadding: CGFloat = 11
    private static let verticalPadding: CGFloat = 6
    private static let spacing: CGFloat = 8
    /// Отступ подписи от внешнего края кольца.
    private static let distanceFromRing: CGFloat = 10
    private static let screenMargin: CGFloat = 6

    init(title: String, detail: String? = nil, isDestructive: Bool = false, isEnabled: Bool = true) {
        self.title = title
        self.detail = detail
        self.isDestructive = isDestructive
        self.isEnabled = isEnabled
    }

    init(action: PieSubAction) {
        self.init(
            title: action.title,
            detail: action.shortcut,
            isDestructive: action.isDestructive,
            isEnabled: action.isEnabled
        )
    }

    init(text: PieHoverLabelText, isEnabled: Bool = true) {
        self.init(title: text.title, detail: text.detail, isEnabled: isEnabled)
    }

    var body: some View {
        HStack(spacing: Self.spacing) {
            Text(title)
                .font(Font(Self.titleFont as CTFont))
                .foregroundStyle(isDestructive ? DS.Pie.destructiveSubSectorIcon : .white)
                .opacity(isEnabled ? 1 : 0.5)
            if let detail {
                Text(detail)
                    .font(Font(Self.detailFont as CTFont))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, Self.horizontalPadding)
        .padding(.vertical, Self.verticalPadding)
        // Сплошная плашка, без материала: слой с блюром рядом со стеклом заставлял все секторы
        // пересэмплировать фон при каждой смене подписи — кольцо тёмно моргало.
        .background(Capsule().fill(Color.black.opacity(0.66)))
        .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.7))
        .accessibilityElement(children: .combine)
    }

    /// Размер считаем заранее, чтобы поставить подпись снаружи кольца и не вылезти за край экрана.
    static func estimatedSize(title: String, detail: String?) -> CGSize {
        let titleSize = (title as NSString).size(withAttributes: [.font: titleFont])
        var width = titleSize.width
        var height = titleSize.height
        if let detail {
            let size = (detail as NSString).size(withAttributes: [.font: detailFont])
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
        size: CGSize,
        angle: Double,
        ringOuterRadius: Double,
        menuCenter: CGPoint,
        bounds: CGSize
    ) -> CGPoint {
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

    func position(angle: Double, ringOuterRadius: Double, menuCenter: CGPoint, bounds: CGSize) -> CGPoint {
        Self.position(
            size: Self.estimatedSize(title: title, detail: detail),
            angle: angle,
            ringOuterRadius: ringOuterRadius,
            menuCenter: menuCenter,
            bounds: bounds
        )
    }
}
