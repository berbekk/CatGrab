import SwiftUI

/// Настоящее кольцо в окне знакомства — тот же `PieMenuView`, что открывается по хоткею: стекло,
/// кот, лапка, подписи. По нему можно водить и кликать, ничего не выполняя: так первая встреча
/// с меню происходит до того, как человек его вызвал сам.
struct OnboardingRingDemo: View {
    let menu: PieMenu
    let language: AppLanguage
    var onPick: ((PieMenuItem) -> Void)?

    @StateObject private var highlightState = PieMenuHighlightState()
    @StateObject private var presentation = PieMenuPresentation.settled(pointer: .zero)

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            // Тот же масштаб, что у превью редактора (`MenuPreviewView`): на странице расстановки
            // кольцо рисует оно, и размер не должен прыгать между страницами.
            let scale = MenuPreviewView.fittingScale(for: menu, in: geo.size)
            let items = menu.themed(menu.items.sorted { $0.sectorIndex < $1.sectorIndex })

            PieMenuView(
                items: items,
                radius: menu.effectiveMenuRadius * scale,
                innerRadius: menu.effectiveInnerRadius * scale,
                iconDistance: menu.iconDistance,
                iconSize: menu.fittedIconSize(sectorCount: items.count) * scale,
                rotationDegrees: menu.effectiveRotationDegrees(sectorCount: items.count),
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
                hoverLabels: menu.showsHoverLabel ? items.map { $0.hoverLabel(language: language) } : nil,
                highlightState: highlightState,
                presentation: presentation,
                hapticFeedbackEnabled: false,
                onItemSelected: onPick
            )
            .onAppear { presentation.pointer = center }
        }
        .environment(\.colorScheme, .dark)
    }
}
