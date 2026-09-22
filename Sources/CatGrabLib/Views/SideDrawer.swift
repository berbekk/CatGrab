import SwiftUI

/// Левая выезжающая панель, которую страница меню отдаёт окну настроек. Инспектор выбранного
/// сектора и список «Добавить сектор» открываются там же и так же, как «Параметры» оформления:
/// поверх сайдбара, во всю высоту, с тем же выездом и закрытием по клику мимо.
struct SideDrawerContent {
    /// Смена id — другая панель: состояние инспектора начинается заново.
    let id: AnyHashable
    let onClose: () -> Void
    let view: AnyView

    init<Content: View>(id: AnyHashable, onClose: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.id = id
        self.onClose = onClose
        view = AnyView(content())
    }
}

struct SideDrawerKey: PreferenceKey {
    static var defaultValue: SideDrawerContent?

    static func reduce(value: inout SideDrawerContent?, nextValue: () -> SideDrawerContent?) {
        value = value ?? nextValue()
    }
}

extension View {
    /// Показать панель слева; `nil` — панели нет.
    func sideDrawer(_ content: SideDrawerContent?) -> some View {
        preference(key: SideDrawerKey.self, value: content)
    }

    /// Место для панели страницы — в окне настроек, рядом с «Параметрами» и в том же виде.
    func sideDrawerHost(width: CGFloat, animation: Animation?) -> some View {
        overlayPreferenceValue(SideDrawerKey.self, alignment: .topLeading) { content in
            ZStack(alignment: .topLeading) {
                if let content {
                    Color.black.opacity(0.001)
                        .ignoresSafeArea()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture(perform: content.onClose)

                    content.view
                        .id(content.id)
                        .frame(width: width)
                        .frame(maxHeight: .infinity)
                        .background(DS.Colors.canvasTop)
                        .overlay(alignment: .trailing) {
                            Rectangle()
                                .fill(DS.Colors.stroke)
                                .frame(width: 1)
                                .frame(maxHeight: .infinity)
                                .ignoresSafeArea(edges: .top)
                        }
                        .transition(.move(edge: .leading))
                }
            }
            .animation(animation, value: content?.id)
        }
    }
}
