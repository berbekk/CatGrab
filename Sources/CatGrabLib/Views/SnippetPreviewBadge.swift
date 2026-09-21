import SwiftUI

/// Сторона плашки, из которой выходит хвостик бабла.
enum BubbleTailSide {
    case top, bottom, left, right
}

/// Параметры хвостика речевого пузыря.
/// Координаты `baseCenter` задаются в локальной системе всей плашки (включая область хвостика):
/// по оси X для `.top`/`.bottom` и по оси Y для `.left`/`.right`.
struct BubbleTail: Equatable {
    let side: BubbleTailSide
    let baseCenter: CGFloat
    let baseHalfWidth: CGFloat
    let length: CGFloat
}

/// Форма речевого пузыря: скруглённый прямоугольник с треугольным хвостиком.
/// `rect` — фрейм всей плашки; основная часть (body) получает `inset` с той стороны,
/// где рисуется хвостик, чтобы кончик оказался на соответствующей границе rect.
struct SpeechBubbleShape: Shape {
    let cornerRadius: CGFloat
    let tail: BubbleTail?

    func path(in rect: CGRect) -> Path {
        let body = bodyRect(in: rect)
        let r = min(cornerRadius, min(body.width, body.height) / 2)

        guard let tail = tail, tail.length > 0, tail.baseHalfWidth > 0 else {
            return Path(roundedRect: body, cornerRadius: r, style: .continuous)
        }

        var p = Path()
        let corners = CornerPoints(body: body, radius: r)
        p.move(to: corners.topLeftStart)

        appendTopEdge(to: &p, body: body, radius: r, tail: tail, corners: corners)
        p.addQuadCurve(to: corners.rightTopStart, control: corners.topRight)

        appendRightEdge(to: &p, body: body, radius: r, tail: tail, corners: corners)
        p.addQuadCurve(to: corners.bottomRightStart, control: corners.bottomRight)

        appendBottomEdge(to: &p, body: body, radius: r, tail: tail, corners: corners)
        p.addQuadCurve(to: corners.leftBottomStart, control: corners.bottomLeft)

        appendLeftEdge(to: &p, body: body, radius: r, tail: tail, corners: corners)
        p.addQuadCurve(to: corners.topLeftStart, control: corners.topLeft)

        p.closeSubpath()
        return p
    }

    private func bodyRect(in rect: CGRect) -> CGRect {
        guard let tail = tail else { return rect }
        var body = rect
        switch tail.side {
        case .top:
            body.origin.y += tail.length
            body.size.height = max(0, body.size.height - tail.length)
        case .bottom:
            body.size.height = max(0, body.size.height - tail.length)
        case .left:
            body.origin.x += tail.length
            body.size.width = max(0, body.size.width - tail.length)
        case .right:
            body.size.width = max(0, body.size.width - tail.length)
        }
        return body
    }

    private struct CornerPoints {
        let topLeftStart: CGPoint
        let topRightEnd: CGPoint
        let rightTopStart: CGPoint
        let rightBottomEnd: CGPoint
        let bottomRightStart: CGPoint
        let bottomLeftEnd: CGPoint
        let leftBottomStart: CGPoint
        let leftTopEnd: CGPoint
        let topLeft: CGPoint
        let topRight: CGPoint
        let bottomRight: CGPoint
        let bottomLeft: CGPoint

        init(body: CGRect, radius: CGFloat) {
            topLeftStart = CGPoint(x: body.minX + radius, y: body.minY)
            topRightEnd = CGPoint(x: body.maxX - radius, y: body.minY)
            rightTopStart = CGPoint(x: body.maxX, y: body.minY + radius)
            rightBottomEnd = CGPoint(x: body.maxX, y: body.maxY - radius)
            bottomRightStart = CGPoint(x: body.maxX - radius, y: body.maxY)
            bottomLeftEnd = CGPoint(x: body.minX + radius, y: body.maxY)
            leftBottomStart = CGPoint(x: body.minX, y: body.maxY - radius)
            leftTopEnd = CGPoint(x: body.minX, y: body.minY + radius)
            topLeft = CGPoint(x: body.minX, y: body.minY)
            topRight = CGPoint(x: body.maxX, y: body.minY)
            bottomRight = CGPoint(x: body.maxX, y: body.maxY)
            bottomLeft = CGPoint(x: body.minX, y: body.maxY)
        }
    }

    private func appendTopEdge(to p: inout Path, body: CGRect, radius: CGFloat, tail: BubbleTail, corners: CornerPoints) {
        guard tail.side == .top else {
            p.addLine(to: corners.topRightEnd)
            return
        }
        let minBase = body.minX + radius + tail.baseHalfWidth
        let maxBase = body.maxX - radius - tail.baseHalfWidth
        guard minBase <= maxBase else {
            p.addLine(to: corners.topRightEnd); return
        }
        let base = max(minBase, min(tail.baseCenter, maxBase))
        let left = CGPoint(x: base - tail.baseHalfWidth, y: body.minY)
        let right = CGPoint(x: base + tail.baseHalfWidth, y: body.minY)
        let tip = CGPoint(x: base, y: body.minY - tail.length)
        p.addLine(to: left)
        p.addLine(to: tip)
        p.addLine(to: right)
        p.addLine(to: corners.topRightEnd)
    }

    private func appendRightEdge(to p: inout Path, body: CGRect, radius: CGFloat, tail: BubbleTail, corners: CornerPoints) {
        guard tail.side == .right else {
            p.addLine(to: corners.rightBottomEnd)
            return
        }
        let minBase = body.minY + radius + tail.baseHalfWidth
        let maxBase = body.maxY - radius - tail.baseHalfWidth
        guard minBase <= maxBase else {
            p.addLine(to: corners.rightBottomEnd); return
        }
        let base = max(minBase, min(tail.baseCenter, maxBase))
        let top = CGPoint(x: body.maxX, y: base - tail.baseHalfWidth)
        let bot = CGPoint(x: body.maxX, y: base + tail.baseHalfWidth)
        let tip = CGPoint(x: body.maxX + tail.length, y: base)
        p.addLine(to: top)
        p.addLine(to: tip)
        p.addLine(to: bot)
        p.addLine(to: corners.rightBottomEnd)
    }

    private func appendBottomEdge(to p: inout Path, body: CGRect, radius: CGFloat, tail: BubbleTail, corners: CornerPoints) {
        guard tail.side == .bottom else {
            p.addLine(to: corners.bottomLeftEnd)
            return
        }
        let minBase = body.minX + radius + tail.baseHalfWidth
        let maxBase = body.maxX - radius - tail.baseHalfWidth
        guard minBase <= maxBase else {
            p.addLine(to: corners.bottomLeftEnd); return
        }
        let base = max(minBase, min(tail.baseCenter, maxBase))
        let right = CGPoint(x: base + tail.baseHalfWidth, y: body.maxY)
        let left = CGPoint(x: base - tail.baseHalfWidth, y: body.maxY)
        let tip = CGPoint(x: base, y: body.maxY + tail.length)
        p.addLine(to: right)
        p.addLine(to: tip)
        p.addLine(to: left)
        p.addLine(to: corners.bottomLeftEnd)
    }

    private func appendLeftEdge(to p: inout Path, body: CGRect, radius: CGFloat, tail: BubbleTail, corners: CornerPoints) {
        guard tail.side == .left else {
            p.addLine(to: corners.leftTopEnd)
            return
        }
        let minBase = body.minY + radius + tail.baseHalfWidth
        let maxBase = body.maxY - radius - tail.baseHalfWidth
        guard minBase <= maxBase else {
            p.addLine(to: corners.leftTopEnd); return
        }
        let base = max(minBase, min(tail.baseCenter, maxBase))
        let bot = CGPoint(x: body.minX, y: base + tail.baseHalfWidth)
        let top = CGPoint(x: body.minX, y: base - tail.baseHalfWidth)
        let tip = CGPoint(x: body.minX - tail.length, y: base)
        p.addLine(to: bot)
        p.addLine(to: tip)
        p.addLine(to: top)
        p.addLine(to: corners.leftTopEnd)
    }
}

/// Превью текста сниппета в форме речевого пузыря с хвостиком, указывающим на источник
/// (например, на иконку приложения в меню‑баре). Стилистически — в духе центрального
/// хаба меню: `ultraThinMaterial` + двойная тонкая обводка + мягкая тень; фиксированный
/// тёмный appearance, чтобы читаться на любом фоне.
struct SnippetPreviewBadge: View {
    let text: String
    let caption: String
    let tail: BubbleTail?

    private static let cornerRadius: CGFloat = DS.Radius.l
    private static let bodyMaxWidth: CGFloat = 300
    private static let maxLines: Int = 6

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var displayedText: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : text
    }

    var body: some View {
        let shape = SpeechBubbleShape(cornerRadius: Self.cornerRadius, tail: tail)
        return content
            .padding(.horizontal, DS.Spacing.m)
            .padding(.vertical, DS.Spacing.s + 2)
            .padding(tailPadding)
            .frame(maxWidth: Self.bodyMaxWidth + horizontalTailPadding, alignment: .leading)
            // `.ultraThinMaterial` продолжает пропускать рабочий стол даже при «Уменьшить прозрачность» —
            // подменяем его сплошной тёмной подложкой того же тона, раз appearance у бейджа и так фиксирован.
            .background(materialBackground(shape))
            .background(tintBackground(shape))
            .overlay(shape.stroke(Color.white.opacity(0.26), lineWidth: 0.7))
            .overlay(shape.stroke(Color.black.opacity(0.18), lineWidth: 0.7))
            .shadow(color: Color.black.opacity(0.28), radius: 14, x: 0, y: 6)
            .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private func materialBackground(_ shape: SpeechBubbleShape) -> some View {
        if reduceTransparency {
            shape.fill(Color.clear)
        } else {
            shape.fill(.ultraThinMaterial)
        }
    }

    private func tintBackground(_ shape: SpeechBubbleShape) -> some View {
        shape.fill(Color.black.opacity(reduceTransparency ? 0.92 : 0.22))
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            header
            Text(displayedText)
                .font(DS.Typography.body)
                .foregroundStyle(.primary)
                .lineLimit(Self.maxLines)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.disabled)
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            CatSVGHeadShape()
                .fill(Color.secondary)
                .frame(width: 13, height: 13 * 93 / 99)
            Text(caption.uppercased())
                .font(DS.Typography.caption)
                .tracking(0.6)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var tailPadding: EdgeInsets {
        guard let tail = tail else { return EdgeInsets() }
        switch tail.side {
        case .top:    return EdgeInsets(top: tail.length, leading: 0, bottom: 0, trailing: 0)
        case .bottom: return EdgeInsets(top: 0, leading: 0, bottom: tail.length, trailing: 0)
        case .left:   return EdgeInsets(top: 0, leading: tail.length, bottom: 0, trailing: 0)
        case .right:  return EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: tail.length)
        }
    }

    private var horizontalTailPadding: CGFloat {
        switch tail?.side {
        case .left, .right: return tail?.length ?? 0
        default: return 0
        }
    }
}

#Preview("SnippetPreviewBadge") {
    VStack(spacing: 24) {
        SnippetPreviewBadge(
            text: "Привет! Это превью сниппета, который будет вставлен в активное поле ввода или попадёт в буфер обмена.",
            caption: "Сниппет",
            tail: BubbleTail(side: .top, baseCenter: 48, baseHalfWidth: 8, length: 10)
        )
        SnippetPreviewBadge(text: "", caption: "Snippet", tail: nil)
    }
    .padding(40)
    .background(Color.gray)
    .preferredColorScheme(.dark)
}
