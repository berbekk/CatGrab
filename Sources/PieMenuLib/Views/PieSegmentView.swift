import SwiftUI

let centerCircleRadius: Double = 32

struct PieSegmentView: View {
    let item: PieMenuItem
    let shortcutLabel: String?
    let isHovered: Bool
    let startAngle: Double
    let endAngle: Double
    let radius: Double
    let innerRadius: Double
    let iconDistance: Double
    let iconSize: Double
    let liquidGlass: LiquidGlassSettings
    /// Для оверлея меню отключают: несколько `.interactive()` glass в одной группе дают артефакты заливки (macOS 26+).
    var glassInteractive: Bool = true
    var pawDecorationEnabled: Bool = true
    var pawSizeScale: Double = PieMenu.defaultPawSizeScale
    var pawRadialInset: Double = PieMenu.defaultPawRadialInset
    var shortcutDigitSizeScale: Double = PieMenu.defaultShortcutDigitSizeScale
    var shortcutDigitInsetLeftScale: Double = PieMenu.defaultShortcutDigitInsetLeftScale
    var shortcutDigitInsetRightScale: Double = PieMenu.defaultShortcutDigitInsetRightScale
    var shortcutDigitOpacity: Double = PieMenu.defaultShortcutDigitOpacity
    var shortcutDigitColorHex: String = PieMenu.defaultShortcutDigitColorHex

    private var midAngle: Double {
        (startAngle + endAngle) / 2
    }

    private var labelRadius: Double {
        innerRadius + (radius - innerRadius) * iconDistance
    }

    private var labelOffset: CGPoint {
        CGPoint(x: cos(midAngle) * labelRadius, y: sin(midAngle) * labelRadius)
    }

    private var segmentColor: Color {
        Color(hex: item.color) ?? .accentColor
    }

    private var resolvedIconColor: Color {
        if let hex = item.iconColor, let c = Color(hex: hex) { return c }
        return segmentColor
    }

    private var isUnassignedAction: Bool {
        item.action == .unassigned
    }

    private var sectorFillOpacityFactor: Double {
        isUnassignedAction ? DS.Pie.unassignedSectorFillOpacityFactor : 1
    }

    private var iconContentOpacity: Double {
        isUnassignedAction ? DS.Pie.unassignedIconOpacity : 1
    }

    private var sectorBorderOpacityMultiplier: Double {
        isUnassignedAction ? DS.Pie.unassignedSectorBorderOpacityMultiplier : 1
    }

    private var sectorCornerRadius: CGFloat {
        min(DS.Pie.sectorCornerRadius, CGFloat(radius * 0.11))
    }

    private var iconRenderSize: Double {
        isHovered ? iconSize + 4 : iconSize
    }

    private var ringWidth: Double {
        max(1, radius - innerRadius)
    }

    private var pawSize: CGFloat {
        let sizeRatio =
            PieMenu.clampedPawSizeScale(pawSizeScale)
            / PieMenu.defaultPawSizeScale
        return max(
            6,
            CGFloat(ringWidth)
                * CGFloat(PieMenu.pawSizeBaseFromRingWidth)
                * CGFloat(sizeRatio)
        )
    }

    private var pawRadialDistanceFromCenter: CGFloat {
        PieMenu.pawRadialDistanceFromMenuCenter(pawRadialInset: pawRadialInset, outerRadius: radius)
    }

    private var shortcutBadgeFontSize: CGFloat {
        let sizeRatio =
            PieMenu.clampedShortcutDigitSizeScale(shortcutDigitSizeScale)
            / PieMenu.defaultShortcutDigitSizeScale
        return max(
            6,
            CGFloat(ringWidth)
                * CGFloat(PieMenu.shortcutDigitFontBaseFromRingWidth)
                * CGFloat(sizeRatio)
        )
    }

    private var shortcutBadgePosition: CGPoint {
        // Ставим цифру относительно одного и того же геометрического угла сектора:
        // внешний угол на `startAngle` + одинаковые отступы внутрь.
        let corner = CGPoint(x: cos(startAngle) * radius, y: sin(startAngle) * radius)
        let leftRatio =
            PieMenu.clampedShortcutDigitInsetLeftScale(shortcutDigitInsetLeftScale)
            / PieMenu.defaultShortcutDigitInsetLeftScale
        let rightRatio =
            PieMenu.clampedShortcutDigitInsetRightScale(shortcutDigitInsetRightScale)
            / PieMenu.defaultShortcutDigitInsetRightScale
        let radialInset = max(
            4,
            CGFloat(ringWidth)
                * CGFloat(PieMenu.shortcutDigitInsetLeftBaseFromRingWidth)
                * CGFloat(leftRatio)
        )
        let tangentialInset = max(
            4,
            CGFloat(ringWidth)
                * CGFloat(PieMenu.shortcutDigitInsetRightBaseFromRingWidth)
                * CGFloat(rightRatio)
        )
        let radial = CGVector(dx: cos(startAngle), dy: sin(startAngle))
        let tangent = CGVector(dx: -sin(startAngle), dy: cos(startAngle))
        return CGPoint(
            x: corner.x - radial.dx * radialInset + tangent.dx * tangentialInset,
            y: corner.y - radial.dy * radialInset + tangent.dy * tangentialInset
        )
    }

    private var shortcutBadgeColor: Color {
        Color(hex: shortcutDigitColorHex) ?? .white
    }

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

            ZStack {
                Group {
                    PieSectorFillView(
                        startAngle: startAngle,
                        endAngle: endAngle,
                        innerRadius: innerRadius,
                        outerRadius: radius,
                        cornerRadius: sectorCornerRadius,
                        tintColor: segmentColor,
                        fillOpacityFactor: sectorFillOpacityFactor,
                        glassSettings: liquidGlass,
                        interactiveGlass: glassInteractive
                    )
                    sectorHighlight
                    sectorBorder
                }
                .scaleEffect(isHovered ? 1.04 : 1.0)

                Group {
                    if item.icon.hasPrefix("text:") {
                        PieSectorArcTextIcon(
                            text: String(item.icon.dropFirst(5)),
                            center: center,
                            startAngle: startAngle,
                            endAngle: endAngle,
                            radialDistance: CGFloat(labelRadius),
                            baseFontSize: max(CGFloat(iconRenderSize) * DS.PieIconVisualScale.textFontToCell, 9),
                            color: resolvedIconColor
                        )
                    } else {
                        IconView(
                            icon: item.icon,
                            size: iconRenderSize,
                            color: resolvedIconColor,
                            appBundleId: item.action.bundleIdentifier
                        )
                        .frame(width: iconRenderSize, height: iconRenderSize)
                        .position(
                            x: center.x + labelOffset.x,
                            y: center.y + labelOffset.y
                        )
                    }
                }
                .opacity(iconContentOpacity)
                .shadow(color: isHovered ? resolvedIconColor.opacity(0.5 * iconContentOpacity) : .clear, radius: 8, x: 0, y: 0)

                if let shortcutLabel {
                    let shortcutOpacity =
                        PieMenu.clampedShortcutDigitOpacity(shortcutDigitOpacity)
                        * (isUnassignedAction ? DS.Pie.unassignedShortcutBadgeOpacityMultiplier : 1)
                    Text(shortcutLabel)
                        .font(.system(size: shortcutBadgeFontSize, weight: .medium, design: .rounded))
                        .monospaced()
                        .foregroundStyle(shortcutBadgeColor.opacity(shortcutOpacity))
                        .position(
                            x: center.x + shortcutBadgePosition.x,
                            y: center.y + shortcutBadgePosition.y
                        )
                }

                if pawDecorationEnabled {
                    CatPawGrabView(
                        size: pawSize,
                        grabProgress: isHovered ? 1 : 0,
                        pawColor: .black.opacity(0.96)
                    )
                    .rotationEffect(.radians(midAngle + .pi / 2))
                    .scaleEffect(isHovered ? 1 : 0.84)
                    .opacity(isHovered ? 1 : 0)
                    .position(
                        x: center.x + CGFloat(cos(midAngle)) * pawRadialDistanceFromCenter,
                        y: center.y + CGFloat(sin(midAngle)) * pawRadialDistanceFromCenter
                    )
                }
            }
            .contentShape(
                PieSectorShape(
                    startAngle: startAngle,
                    endAngle: endAngle,
                    innerRadius: innerRadius,
                    outerRadius: radius,
                    cornerRadius: sectorCornerRadius
                )
            )
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovered)
    }

    private var sectorHighlight: some View {
        PieSectorShape(
            startAngle: startAngle,
            endAngle: endAngle,
            innerRadius: innerRadius,
            outerRadius: radius,
            cornerRadius: sectorCornerRadius
        )
        .fill(
            RadialGradient(
                colors: isHovered
                    ? [Color.white.opacity(0.1), .clear]
                    : [.clear, .clear],
                center: .center,
                startRadius: innerRadius,
                endRadius: radius
            )
        )
    }

    private var sectorBorder: some View {
        let lineWidth = isHovered ? 1.4 : 0.7
        let m = sectorBorderOpacityMultiplier
        return PieSectorShape(
            startAngle: startAngle,
            endAngle: endAngle,
            innerRadius: innerRadius,
            outerRadius: radius,
            cornerRadius: sectorCornerRadius
        )
        .stroke(Color.white.opacity((isHovered ? 0.4 : 0.24) * m), lineWidth: lineWidth)
        .overlay(
            PieSectorShape(
                startAngle: startAngle,
                endAngle: endAngle,
                innerRadius: innerRadius,
                outerRadius: radius,
                cornerRadius: sectorCornerRadius
            )
            .stroke(Color.black.opacity((isHovered ? 0.26 : 0.16) * m), lineWidth: lineWidth)
        )
    }
}

#Preview("PieSegment") {
    let item = PieMenuItem(
        title: "Safari",
        icon: "safari",
        action: .launchApp(bundleIdentifier: "com.apple.Safari"),
        color: "#007AFF",
        sectorIndex: 0
    )
    PieSegmentView(
        item: item,
        shortcutLabel: "0",
        isHovered: false,
        startAngle: -.pi / 2,
        endAngle: -.pi / 2 + .pi / 3,
        radius: 140,
        innerRadius: centerCircleRadius,
        iconDistance: 0.55,
        iconSize: 30,
        liquidGlass: .default,
        glassInteractive: true
    )
    .frame(width: 300, height: 300)
    .preferredColorScheme(.dark)
}
