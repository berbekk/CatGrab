import SwiftUI

// MARK: - viewBox 32×43 (см. `paw.svg`)

private enum PawSVG {
    static let viewW: CGFloat = 32
    static let viewH: CGFloat = 43
}

/// Силуэт лапки из `paw.svg`.
struct PawSVGBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        func t(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(
                x: rect.minX + x * rect.width / PawSVG.viewW,
                y: rect.minY + y * rect.height / PawSVG.viewH
            )
        }

        var p = Path()
        p.move(to: t(16.6636, 1.24902))
        p.addCurve(to: t(24.939, 4.24805), control1: t(17.6639, -0.748993), control2: t(23.6636, -0.751842))
        p.addCurve(to: t(30.6069, 16.1172), control1: t(29.3842, 4.92529), control2: t(33.164, 8.25122))
        p.addCurve(to: t(27.937, 24.4785), control1: t(30.6047, 16.171), control2: t(30.3975, 21.0086))
        p.addLine(to: t(28.8042, 32.8516))
        p.addCurve(to: t(19.8784, 42.749), control1: t(29.3517, 38.1445), control2: t(25.1996, 42.7489))
        p.addLine(to: t(13.0024, 42.749))
        p.addCurve(to: t(4.02881, 33.7754), control1: t(8.0464, 42.749), control2: t(4.02886, 38.7314))
        p.addLine(to: t(4.02881, 23.4053))
        p.addCurve(to: t(2.9126, 22.125), control1: t(3.63245, 23.0041), control2: t(3.25867, 22.5782))
        p.addCurve(to: t(7.66357, 4.24805), control1: t(-2.33615, 15.2512), control2: t(-0.336785, 3.24792))
        p.addCurve(to: t(16.6636, 1.24902), control1: t(8.16361, 1.2489), control2: t(12.664, -1.24939))
        p.closeSubpath()
        return p
    }
}

/// Центральная светлая подушечка из `paw.svg`.
struct PawSVGPalmPadShape: Shape {
    func path(in rect: CGRect) -> Path {
        func t(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(
                x: rect.minX + x * rect.width / PawSVG.viewW,
                y: rect.minY + y * rect.height / PawSVG.viewH
            )
        }

        var p = Path()
        p.move(to: t(15.5799, 13.9589))
        p.addCurve(to: t(19.8182, 17.1259), control1: t(17.7822, 13.8845), control2: t(19.6315, 15.2861))
        p.addCurve(to: t(22.0643, 22.0556), control1: t(21.8798, 18.0966), control2: t(22.885, 20.3015))
        p.addCurve(to: t(16.8299, 23.4843), control1: t(21.242, 23.8125), control2: t(18.8986, 24.4523))
        p.addCurve(to: t(15.5066, 22.5692), control1: t(16.3209, 23.2461), control2: t(15.876, 22.9325))
        p.addCurve(to: t(15.3563, 22.7089), control1: t(15.4575, 22.6163), control2: t(15.4078, 22.6634))
        p.addCurve(to: t(9.93145, 22.8124), control1: t(13.6438, 24.2203), control2: t(11.2152, 24.2666))
        p.addCurve(to: t(10.7078, 17.4423), control1: t(8.64775, 21.3579), control2: t(8.99527, 18.9538))
        p.addCurve(to: t(11.6502, 16.7899), control1: t(11.0038, 17.1811), control2: t(11.321, 16.9635))
        p.addCurve(to: t(15.5799, 13.9589), control1: t(12.0307, 15.2297), control2: t(13.6277, 14.0251))
        p.closeSubpath()
        return p
    }
}
