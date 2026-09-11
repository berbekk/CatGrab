import SwiftUI

/// Мордочка кота по `cat.svg`: силуэт головы и глаза с зрачками, следящими за курсором.
struct PieCenterCatEyesView: View {
    let diameter: CGFloat
    /// Смещение зрачков в координатах вида (уже ограниченное по амплитуде).
    var pupilOffset: CGSize = .zero

    @State private var eyeOpenScaleY: CGFloat = 1
    @State private var blinkTask: Task<Void, Never>?

    /// Как `PieSegmentView.sectorBorder` / `PieCenterHubView` при неактивном секторе.
    private enum MenuItemOutline {
        static let lineWidth: CGFloat = 0.7
        static let whiteOpacity: CGFloat = 0.24
        static let blackOpacity: CGFloat = 0.16
    }

    /// Координаты из `cat.svg`, viewBox 99×93.
    private enum CatSVG {
        static let viewW: CGFloat = 99
        static let viewH: CGFloat = 93
        static let leftSclera = CGPoint(x: 29.48, y: 45.957)
        static let rightSclera = CGPoint(x: 72.4795, y: 45.957)
        static let leftPupil = CGPoint(x: 30.98, y: 44.457)
        static let rightPupil = CGPoint(x: 73.9795, y: 44.457)
        static let scleraR: CGFloat = 13.5
        static let pupilR: CGFloat = 7
        static let scleraFill = Color(red: 246 / 255, green: 242 / 255, blue: 242 / 255)
    }

    var body: some View {
        let w = diameter
        let h = diameter * (CatSVG.viewH / CatSVG.viewW)
        let s = w / CatSVG.viewW

        ZStack {
            CatSVGHeadShape()
                .fill(Color.black)
                .frame(width: w, height: h)
                .overlay {
                    CatSVGHeadShape()
                        .stroke(Color.white.opacity(MenuItemOutline.whiteOpacity), lineWidth: MenuItemOutline.lineWidth)
                }
                .overlay {
                    CatSVGHeadShape()
                        .stroke(Color.black.opacity(MenuItemOutline.blackOpacity), lineWidth: MenuItemOutline.lineWidth)
                }

            ZStack {
                catEyeFromSVG(
                    scleraCenter: CatSVG.leftSclera,
                    restPupil: CGPoint(
                        x: CatSVG.leftPupil.x - CatSVG.leftSclera.x,
                        y: CatSVG.leftPupil.y - CatSVG.leftSclera.y
                    ),
                    w: w,
                    h: h,
                    s: s
                )

                catEyeFromSVG(
                    scleraCenter: CatSVG.rightSclera,
                    restPupil: CGPoint(
                        x: CatSVG.rightPupil.x - CatSVG.rightSclera.x,
                        y: CatSVG.rightPupil.y - CatSVG.rightSclera.y
                    ),
                    w: w,
                    h: h,
                    s: s
                )
            }
            .scaleEffect(x: 1, y: eyeOpenScaleY, anchor: .center)

            CatSVGMouthShape()
                .fill(Color.white)
                .frame(width: w, height: h)
        }
        .frame(width: diameter, height: diameter)
        .allowsHitTesting(false)
        .onAppear {
            blinkTask?.cancel()
            blinkTask = Task { @MainActor in
                while !Task.isCancelled {
                    let pauseNs = UInt64(Double.random(in: 2.4 ... 5.8) * 1_000_000_000)
                    try? await Task.sleep(nanoseconds: pauseNs)
                    guard !Task.isCancelled else { break }
                    withAnimation(.easeOut(duration: 0.055)) {
                        eyeOpenScaleY = 0.06
                    }
                    try? await Task.sleep(nanoseconds: 75_000_000)
                    guard !Task.isCancelled else { break }
                    withAnimation(.easeInOut(duration: 0.14)) {
                        eyeOpenScaleY = 1
                    }
                }
            }
        }
        .onDisappear {
            blinkTask?.cancel()
            blinkTask = nil
        }
    }

    private func catEyeFromSVG(
        scleraCenter: CGPoint,
        restPupil: CGPoint,
        w: CGFloat,
        h: CGFloat,
        s: CGFloat
    ) -> some View {
        let scleraR = CatSVG.scleraR * s
        let pupilR = CatSVG.pupilR * s
        let fromCenter = CGSize(
            width: w * (scleraCenter.x / CatSVG.viewW - 0.5),
            height: h * (scleraCenter.y / CatSVG.viewH - 0.5)
        )
        let rest = CGSize(width: restPupil.x * s, height: restPupil.y * s)
        let combined = CGSize(
            width: rest.width + pupilOffset.width,
            height: rest.height + pupilOffset.height
        )
        let clamped = Self.clampedPupilOffset(
            combined,
            eyeSize: 2 * scleraR,
            pupilSize: 2 * pupilR
        )
        let glintSize = pupilR * 0.6
        let glintShift = pupilR * 0.25

        return ZStack {
            Circle()
                .fill(CatSVG.scleraFill)
                .frame(width: 2 * scleraR, height: 2 * scleraR)

            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: 2 * pupilR, height: 2 * pupilR)

                Circle()
                    .fill(Color.white.opacity(0.92))
                    .frame(width: glintSize, height: glintSize)
                    .offset(x: -glintShift, y: -glintShift)
            }
            .offset(clamped)
        }
        .offset(fromCenter)
    }

    /// Укладывает центр зрачка в круг радиусом `(eyeSize - pupilSize) / 2`.
    private static func clampedPupilOffset(_ offset: CGSize, eyeSize: CGFloat, pupilSize: CGFloat) -> CGSize {
        let maxRadius = max(0, (eyeSize - pupilSize) / 2)
        let x = offset.width
        let y = offset.height
        let d = hypot(x, y)
        guard d > maxRadius, d > 0 else { return offset }
        let scale = maxRadius / d
        return CGSize(width: x * scale, height: y * scale)
    }

    /// Смещение зрачков в сторону `pointer` относительно центра «мордочки».
    static func lookOffset(pointer: CGPoint, hubCenter: CGPoint, hubDiameter: CGFloat) -> CGSize {
        let dx = pointer.x - hubCenter.x
        let dy = pointer.y - hubCenter.y
        let dist = hypot(dx, dy)
        guard dist > 0.5 else { return .zero }
        let nx = dx / dist
        let ny = dy / dist
        let maxMove = max(2, hubDiameter * 0.10)
        let dampen = min(1, dist / max(hubDiameter * 0.5, 8))
        let cap = hubDiameter * 0.065
        let ox = min(max(nx * maxMove * dampen, -cap), cap)
        let oy = min(max(ny * maxMove * dampen, -cap), cap)
        return CGSize(width: ox, height: oy)
    }
}
