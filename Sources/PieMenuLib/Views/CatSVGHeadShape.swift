import SwiftUI

/// Контур головы кота из `cat.svg` (viewBox 99×93), только чёрный силуэт.
struct CatSVGHeadShape: Shape {
    func path(in rect: CGRect) -> Path {
        func t(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(
                x: rect.minX + x * rect.width / 99,
                y: rect.minY + y * rect.height / 93
            )
        }

        var p = Path()
        p.move(to: t(62.9443, 17.7817))
        p.addCurve(to: t(90.4189, 0.844176), control1: t(71.3823, 4.69493), control2: t(82.5023, -2.58303))
        p.addCurve(to: t(94.1777, 39.4662), control1: t(97.5994, 3.95285), control2: t(97.2199, 21.9127))
        p.addCurve(to: t(98.0225, 54.2612), control1: t(96.6536, 44.0141), control2: t(98.0224, 49.0135))
        p.addCurve(to: t(49.0117, 92.3032), control1: t(98.0225, 75.271), control2: t(76.0797, 92.303))
        p.addCurve(to: t(0, 54.2612), control1: t(21.9435, 92.3032), control2: t(0, 75.271))
        p.addCurve(to: t(3.03418, 41.0561), control1: t(5.28279e-05, 49.6182), control2: t(1.07235, 45.1697))
        p.addCurve(to: t(6.52441, 0.922301), control1: t(-0.24872, 23.0352), control2: t(-0.862363, 4.12037))
        p.addCurve(to: t(34.0986, 18.0151), control1: t(14.4723, -2.51843), control2: t(25.6488, 4.83069))
        p.addCurve(to: t(49.0117, 16.2202), control1: t(38.8011, 16.8505), control2: t(43.8117, 16.2202))
        p.addCurve(to: t(62.9443, 17.7817), control1: t(53.8521, 16.2202), control2: t(58.5279, 16.767))
        p.closeSubpath()
        return p
    }
}

/// Рот кота из `cat.svg` (белая заливка).
struct CatSVGMouthShape: Shape {
    func path(in rect: CGRect) -> Path {
        func t(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(
                x: rect.minX + x * rect.width / 99,
                y: rect.minY + y * rect.height / 93
            )
        }

        var p = Path()
        p.move(to: t(51.0513, 63.1152))
        p.addCurve(to: t(52.0513, 64.1152), control1: t(51.6036, 63.1152), control2: t(52.0513, 63.5629))
        p.addCurve(to: t(53.4751, 69.4863), control1: t(52.0513, 66.228), control2: t(52.5469, 68.1372))
        p.addCurve(to: t(57.5513, 71.6152), control1: t(54.3771, 70.7972), control2: t(55.7038, 71.6152))
        p.addCurve(to: t(58.5513, 72.6152), control1: t(58.1036, 71.6152), control2: t(58.5513, 72.0629))
        p.addCurve(to: t(57.5513, 73.6152), control1: t(58.5513, 73.1675), control2: t(58.1036, 73.6152))
        p.addCurve(to: t(51.8276, 70.6191), control1: t(54.9988, 73.6152), control2: t(53.0756, 72.4331))
        p.addCurve(to: t(50.9761, 69.0508), control1: t(51.4946, 70.135), control2: t(51.2123, 69.6084))
        p.addCurve(to: t(49.9946, 70.6621), control1: t(50.7001, 69.6259), control2: t(50.3744, 70.1676))
        p.addCurve(to: t(44.0513, 73.6152), control1: t(48.6226, 72.4486), control2: t(46.5892, 73.6152))
        p.addCurve(to: t(43.0513, 72.6152), control1: t(43.499, 73.6152), control2: t(43.0513, 73.1675))
        p.addCurve(to: t(44.0513, 71.6152), control1: t(43.0513, 72.0629), control2: t(43.499, 71.6152))
        p.addCurve(to: t(48.4077, 69.4434), control1: t(45.9133, 71.6152), control2: t(47.3798, 70.7818))
        p.addCurve(to: t(50.0513, 64.1152), control1: t(49.4515, 68.0843), control2: t(50.0513, 66.1842))
        p.addCurve(to: t(51.0513, 63.1152), control1: t(50.0513, 63.5629), control2: t(50.499, 63.1152))
        p.closeSubpath()
        return p
    }
}
