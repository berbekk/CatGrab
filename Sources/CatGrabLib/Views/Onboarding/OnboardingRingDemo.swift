import SwiftUI

/// Настоящее кольцо в окне знакомства — тот же `PieMenuView`, что открывается по хоткею: стекло,
/// кот, лапка, подписи. Мышь оно не принимает: выделение и появление ведёт сам тур, зацикленно,
/// а кот смотрит на выделенный сектор.
struct OnboardingRingDemo: View {
    let menu: PieMenu
    let language: AppLanguage
    @ObservedObject var highlightState: PieMenuHighlightState
    @ObservedObject var presentation: PieMenuPresentation

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            // Тот же масштаб, что у превью редактора (`MenuPreviewView`): на страницах расстановки
            // кольцо рисует оно, и размер не должен прыгать между страницами.
            let scale = MenuPreviewView.fittingScale(for: menu, in: geo.size)
            let items = menu.themed(menu.items.sorted { $0.sectorIndex < $1.sectorIndex })
            let radius = menu.effectiveMenuRadius * scale
            let rotation = menu.effectiveRotationDegrees(sectorCount: items.count)

            PieMenuView(
                items: items,
                radius: radius,
                innerRadius: menu.effectiveInnerRadius * scale,
                iconDistance: menu.iconDistance,
                iconSize: menu.fittedIconSize(sectorCount: items.count) * scale,
                rotationDegrees: rotation,
                liquidGlass: menu.liquidGlass,
                menuCenter: center,
                pawDecorationEnabled: menu.pawDecorationEnabled,
                pawSizeScale: menu.pawSizeScale,
                pawRadialInset: menu.pawRadialInset,
                centerCatScale: menu.centerCatScale,
                centerAppIconScale: menu.centerAppIconScale,
                shortcutDigitSizeScale: menu.shortcutDigitSizeScale,
                shortcutDigitInsetLeftScale: menu.shortcutDigitInsetLeftScale,
                shortcutDigitInsetRightScale: menu.shortcutDigitInsetRightScale,
                shortcutDigitOpacity: menu.shortcutDigitOpacity,
                shortcutDigitColorHex: menu.shortcutDigitColorHex,
                catColorHex: menu.catColorHex,
                pawColorHex: menu.pawColorHex,
                // Подписи снаружи кольца в узкую панель не помещаются — тур показывает их под кольцом.
                hoverLabels: nil,
                highlightState: highlightState,
                presentation: presentation,
                hapticFeedbackEnabled: false
            )
            .onAppear { presentation.pointer = center }
            .onChange(of: highlightState.highlightedIndex) { index in
                // Кот провожает взглядом выделенный сектор, как провожал бы курсор.
                guard let index, !items.isEmpty else {
                    presentation.pointer = center
                    return
                }
                let step = 2 * Double.pi / Double(items.count)
                let mid = step * (Double(index) + 0.5) - .pi / 2 + rotation * .pi / 180
                let reach = radius * 0.75
                presentation.pointer = CGPoint(x: center.x + cos(mid) * reach, y: center.y + sin(mid) * reach)
            }
        }
        .environment(\.colorScheme, .dark)
    }
}
