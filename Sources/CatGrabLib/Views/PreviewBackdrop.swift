import AppKit
import SwiftUI

/// Фон превью «светлый | тёмный»: меню открывается поверх любых окон, а стекло секторов
/// подстраивается под то, что под ним. Граница делит фон сверху донизу, её двигают ручкой
/// (`PreviewBackdropHandle`) — видно, как те же секторы выглядят на тёмном и на светлом.
struct PreviewBackdrop: View {
    /// Где граница: доля ширины слева, занятая светлым фоном.
    let split: Double

    static let darkFill = LinearGradient(
        colors: [Color(red: 0.17, green: 0.17, blue: 0.19), Color(red: 0.07, green: 0.07, blue: 0.08)],
        startPoint: .top,
        endPoint: .bottom
    )
    static let lightFill = LinearGradient(
        colors: [Color.white, Color(white: 0.92)],
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        GeometryReader { geo in
            let x = geo.size.width * split
            ZStack(alignment: .leading) {
                Self.darkFill
                Self.lightFill
                    .frame(width: x)
                Rectangle()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: 1.5)
                    .shadow(color: .black.opacity(0.35), radius: 1.5)
                    .offset(x: x - 0.75)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous))
        .allowsHitTesting(false)
    }
}

/// Ручка границы фона — внизу превью, чтобы не заслонять кольцо. Тянется влево и вправо.
struct PreviewBackdropHandle: View {
    @Binding var split: Double
    @EnvironmentObject private var localizer: LocalizationStore
    @State private var isHovered = false

    private static let size: CGFloat = 28
    private static let range: ClosedRange<Double> = 0.04...0.96

    var body: some View {
        GeometryReader { geo in
            let width = max(1, geo.size.width)
            knob
                .position(x: width * split, y: geo.size.height - Self.size / 2 - DS.Spacing.s)
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.coordinateSpace))
                        .onChanged { value in
                            split = min(Self.range.upperBound, max(Self.range.lowerBound, value.location.x / width))
                        }
                )
        }
        .coordinateSpace(name: Self.coordinateSpace)
    }

    private static let coordinateSpace = "previewBackdrop"

    private var knob: some View {
        Image(systemName: "arrow.left.and.right")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Color(white: 0.25))
            .frame(width: Self.size, height: Self.size)
            .background(Circle().fill(Color.white))
            .overlay(Circle().strokeBorder(Color.black.opacity(0.12), lineWidth: DS.Border.hairline))
            .shadow(color: .black.opacity(0.3), radius: isHovered ? 4 : 2, y: 1)
            .scaleEffect(isHovered ? 1.08 : 1)
            .contentShape(Circle())
            .onHover { inside in
                isHovered = inside
                if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
            }
            .animation(.easeInOut(duration: 0.12), value: isHovered)
            .accessibilityElement()
            .accessibilityLabel(Text(localizer.text(.previewBackdropHandle)))
            .accessibilityValue(Text("\(Int((split * 100).rounded()))%"))
            .accessibilityAdjustableAction { direction in
                let step = direction == .increment ? 0.1 : -0.1
                split = min(Self.range.upperBound, max(Self.range.lowerBound, split + step))
            }
    }
}

/// Квадратная кнопка над превью: подсказки, фон, «Параметры».
struct PreviewToolbarButton: View {
    let icon: String
    var isActive = false
    let help: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
        Button(action: action) {
            Image(systemName: icon)
                .font(DS.Typography.panelHeading)
                .foregroundStyle(.primary.opacity(isHovered ? 0.98 : isActive ? 0.96 : 0.88))
                .frame(width: DS.Sizing.compactButtonHeight, height: DS.Sizing.compactButtonHeight)
                .background(shape.fill(
                    isActive ? DS.Colors.blueAccent.opacity(0.2) : DS.Colors.field.opacity(isHovered ? 1 : 0.92)
                ))
                .overlay(shape.strokeBorder(
                    isActive ? DS.Colors.blueAccent.opacity(0.45) : DS.Colors.stroke,
                    lineWidth: DS.Border.hairline
                ))
                .scaleEffect(isHovered ? 1.05 : 1)
        }
        .buttonStyle(DSPlainButtonStyle())
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .animation(.easeInOut(duration: 0.15), value: isActive)
        .iconOnlyHelp(help)
    }
}
