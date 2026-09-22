import SwiftUI

/// Центр меню «Команды приложения»: кот выглядывает из-за иконки приложения и придерживает её лапкой.
/// Голова стоит за иконкой — над её верхним краем видны уши и глаза, — а лапка обхватывает левый край.
/// Вторая лапка — та, что выбирает сектор (`PieMenu.pawDecorationEnabled`), поэтому здесь одна.
///
/// Рамка вида — рамка иконки (`iconSide` × `iconSide`); голова выходит за неё вверх, лапка — влево.
/// Чтобы вся композиция стояла по центру круга, её сдвигаем вниз на `centeringOffset`.
struct CatHoldingAppIconView: View {
    let bundleIdentifier: String
    let iconSide: CGFloat
    /// Смещение зрачков, см. `PieCenterCatEyesView.lookOffset`.
    var pupilOffset: CGSize = .zero
    var headColor: Color = .black
    var pawColor: Color = .black

    /// У иконок macOS по сетке Apple сама плашка — 824 из 1024, по 100 поля с каждой стороны:
    /// кот держит плашку, а не прозрачное поле вокруг неё. Остальное — в долях стороны плашки.
    private enum Layout {
        static let plateInset: CGFloat = 100 / 1024
        /// Голова шириной с плашку.
        static let headWidth: CGFloat = 1
        /// Пропорции `design/cat.svg`: viewBox 99×93, центр глаз на y = 45.96, радиус белка 13.5.
        static let headAspect: CGFloat = 93 / 99
        static let eyeCenterY: CGFloat = 45.957 / 93
        static let scleraRadius: CGFloat = 13.5 / 99
        /// Глаза стоят низом на верхнем крае плашки: видны целиком, а подбородок уже за иконкой.
        static let eyeGapAbovePlate: CGFloat = 0
        /// Лапка: высота, насколько выступает влево за плашку и где начинается сверху.
        static let pawHeight: CGFloat = 0.376
        static let pawLeft: CGFloat = -0.2
        static let pawTop: CGFloat = 0.242
    }

    private static func plateSide(_ s: CGFloat) -> CGFloat {
        s * (1 - 2 * Layout.plateInset)
    }

    /// Верх головы относительно верха рамки иконки (отрицательный — над ней).
    private static func headTop(iconSide s: CGFloat) -> CGFloat {
        let headWidth = self.headWidth(iconSide: s)
        let headHeight = headWidth * Layout.headAspect
        let plateTop = Layout.plateInset * s
        let eyeCenter = plateTop - Layout.eyeGapAbovePlate * plateSide(s) - Layout.scleraRadius * headWidth
        return eyeCenter - Layout.eyeCenterY * headHeight
    }

    /// На сколько сдвинуть рамку иконки вниз, чтобы по центру оказалась вся композиция:
    /// от макушки кота до низа плашки.
    static func centeringOffset(iconSide s: CGFloat) -> CGFloat {
        let top = headTop(iconSide: s)
        let bottom = s * (1 - Layout.plateInset)
        return s / 2 - (top + bottom) / 2
    }

    /// Центр мордочки относительно центра рамки иконки — от него считать взгляд.
    static func headCenterOffset(iconSide s: CGFloat) -> CGSize {
        let headHeight = headWidth(iconSide: s) * Layout.headAspect
        return CGSize(width: 0, height: headTop(iconSide: s) + headHeight / 2 - s / 2)
    }

    static func headWidth(iconSide s: CGFloat) -> CGFloat {
        Layout.headWidth * plateSide(s)
    }

    var body: some View {
        let s = iconSide
        let plate = Self.plateSide(s)
        let pawHeight = Layout.pawHeight * plate
        let pawWidth = pawHeight * CatGrabPawView.aspect
        // Рисунок лапки вписан в квадрат по высоте, поэтому ставим квадрат, а считаем по настоящей ширине.
        let pawCenter = CGPoint(
            x: -plate / 2 + Layout.pawLeft * plate + pawWidth / 2,
            y: -plate / 2 + Layout.pawTop * plate + pawHeight / 2
        )

        ZStack {
            PieCenterCatEyesView(
                diameter: Self.headWidth(iconSide: s),
                pupilOffset: pupilOffset,
                showsMouth: false,
                headColor: headColor
            )
            .offset(Self.headCenterOffset(iconSide: s))

            IconView(icon: "app:\(bundleIdentifier)", size: s, appBundleId: bundleIdentifier)
                .frame(width: s, height: s)
                .shadow(color: .black.opacity(0.35), radius: s * 0.06, y: s * 0.02)

            CatGrabPawView(size: pawHeight, pawColor: pawColor)
                .shadow(color: .black.opacity(0.3), radius: s * 0.02, y: s * 0.01)
                .offset(x: pawCenter.x, y: pawCenter.y)
        }
        .frame(width: s, height: s)
        .allowsHitTesting(false)
    }
}
