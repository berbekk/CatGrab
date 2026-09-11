import SwiftUI

/// Декоративная лапка кота, которая "хватает" иконку в выбранном секторе.
/// Геометрия из `paw.svg` (viewBox 32×43).
struct CatPawGrabView: View {
    let size: CGFloat
    /// 0...1: от расслабленного состояния к "захвату".
    let grabProgress: CGFloat
    var pawColor: Color = .black

    private static let viewW: CGFloat = 32
    private static let viewH: CGFloat = 43

    private var clampedProgress: CGFloat {
        min(max(grabProgress, 0), 1)
    }

    private var pawHeight: CGFloat {
        size * (Self.viewH / Self.viewW)
    }

    var body: some View {
        let squeezeY = 1 - 0.08 * clampedProgress
        let squeezeX = 1 + 0.05 * clampedProgress
        let lift = -size * 0.05 * clampedProgress
        let padHighlightOpacity = 0.14 + 0.12 * clampedProgress

        ZStack {
            PawSVGBodyShape()
                .fill(pawColor)
                .overlay(
                    PawSVGBodyShape()
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.9)
                )
                .shadow(color: Color.black.opacity(0.28), radius: 5, x: 0, y: 2)

            PawSVGPalmPadShape()
                .fill(Color.white.opacity(0.95))
                .overlay(
                    PawSVGPalmPadShape()
                        .fill(Color.white.opacity(padHighlightOpacity))
                        .blur(radius: 1.2)
                )

            ForEach(toeEllipses, id: \.id) { toe in
                Ellipse()
                    .fill(Color.white.opacity(0.95))
                    .frame(
                        width: size * (toe.rx * 2 / Self.viewW),
                        height: pawHeight * (toe.ry * 2 / Self.viewH)
                    )
                    .rotationEffect(.degrees(toe.rotation))
                    .position(
                        x: size * toe.cx / Self.viewW,
                        y: pawHeight * toe.cy / Self.viewH
                    )
            }
        }
        .frame(width: size, height: pawHeight)
        .scaleEffect(x: squeezeX, y: squeezeY, anchor: .center)
        .offset(y: lift)
    }

    private var toeEllipses: [ToeEllipse] {
        [
            .init(id: 1, cx: 20.0083, cy: 7.81669, rx: 3.38514, ry: 2.87499, rotation: -87.6864),
            .init(id: 2, cx: 25.5518, cy: 13.2496, rx: 3.38514, ry: 2.6834, rotation: -80.5711),
            .init(id: 3, cx: 12.6801, cy: 7.36446, rx: 3.40719, ry: 2.75729, rotation: -94.5012),
            .init(id: 4, cx: 6.64418, cy: 11.9006, rx: 3.42247, ry: 2.9067, rotation: -93.1068)
        ]
    }

    private struct ToeEllipse {
        let id: Int
        let cx: CGFloat
        let cy: CGFloat
        let rx: CGFloat
        let ry: CGFloat
        let rotation: CGFloat
    }
}

#Preview("Cat Paw Grab") {
    ZStack {
        Color.gray.opacity(0.18)
        CatPawGrabView(size: 56, grabProgress: 1)
    }
    .frame(width: 180, height: 180)
}
