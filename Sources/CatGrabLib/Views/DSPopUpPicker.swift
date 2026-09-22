import AppKit
import SwiftUI

/// Выпадающий список в облике поля — та же высота, фон, рамка и шеврон, что у записи хоткея и текстовых
/// полей. Меню нативное: галочка у выбранного пункта, и он открывается поверх контрола, как у `NSPopUpButton`.
/// Ширина задана заранее, поэтому список не меняет размер, когда меняется выбранное значение или язык.
struct DSPopUpPicker<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(value: Value, title: String)]
    /// `nil` — на всю доступную ширину (поля в инспекторе).
    var width: CGFloat? = DS.Sizing.settingsControlWidth
    var accessibilityLabel: String = ""

    @State private var isHovered = false

    private var selectedIndex: Int? {
        options.firstIndex { $0.value == selection }
    }

    var body: some View {
        ZStack {
            HStack(spacing: DS.Spacing.s) {
                Text(selectedIndex.map { options[$0].title } ?? "")
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                SidebarAppMenuPickerChevronLabel()
            }
            .padding(.horizontal, DS.Spacing.fieldInsetHorizontal)
            .allowsHitTesting(false)

            PopUpMenuHost(
                titles: options.map(\.title),
                selectedIndex: selectedIndex,
                accessibilityLabel: accessibilityLabel,
                onSelect: { index in
                    guard options.indices.contains(index) else { return }
                    selection = options[index].value
                },
                onHover: { isHovered = $0 }
            )
        }
        .frame(width: width, height: DS.Sizing.fieldHeight)
        .frame(maxWidth: width == nil ? .infinity : nil)
        .dsFieldChrome(isHovered: isHovered)
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }
}

/// Прозрачная область над подписью списка: по клику показывает `NSMenu`.
/// Подпись под ней рисует SwiftUI — так шеврон и текст выглядят одинаково во всех полях
/// (у SwiftUI `Menu` подпись перерисовывает AppKit со своим размером и цветом символа).
struct PopUpMenuHost: NSViewRepresentable {
    var titles: [String]
    /// `nil` — меню готовых вариантов без текущего: открывается под полем, как pull-down.
    var selectedIndex: Int?
    /// SF Symbol слева у пункта — по индексу пункта.
    var symbols: [Int: String] = [:]
    /// Перед этими пунктами — разделитель.
    var separatorsBefore: Set<Int> = []
    var toolTip: String?
    var accessibilityLabel: String
    var onSelect: (Int) -> Void
    var onHover: (Bool) -> Void

    func makeNSView(context: Context) -> PopUpMenuHostView {
        let view = PopUpMenuHostView()
        view.setAccessibilityElement(true)
        view.setAccessibilityRole(.popUpButton)
        return view
    }

    func updateNSView(_ view: PopUpMenuHostView, context: Context) {
        view.titles = titles
        view.selectedIndex = selectedIndex
        view.symbols = symbols
        view.separatorsBefore = separatorsBefore
        view.toolTip = toolTip
        view.onSelect = onSelect
        view.onHover = onHover
        view.setAccessibilityLabel(accessibilityLabel)
        view.setAccessibilityValue(selectedIndex.map { titles[$0] })
    }
}

final class PopUpMenuHostView: NSView {
    var titles: [String] = []
    var selectedIndex: Int?
    var symbols: [Int: String] = [:]
    var separatorsBefore: Set<Int> = []
    var onSelect: ((Int) -> Void)?
    var onHover: ((Bool) -> Void)?

    /// Отступ подписи в поле и колонка галочки в меню: на эту разницу меню сдвигается влево,
    /// чтобы текст выбранного пункта встал ровно на место подписи.
    private static let menuTitleInset: CGFloat = 21

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        let options: NSTrackingArea.Options = [.activeAlways, .mouseEnteredAndExited, .inVisibleRect]
        addTrackingArea(NSTrackingArea(rect: .zero, options: options, owner: self, userInfo: nil))
    }

    override func mouseEntered(with event: NSEvent) {
        onHover?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHover?(false)
    }

    override func mouseDown(with event: NSEvent) {
        showMenu()
    }

    override func accessibilityPerformPress() -> Bool {
        showMenu()
        return true
    }

    private func showMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.font = .systemFont(ofSize: NSFont.systemFontSize)
        for (index, title) in titles.enumerated() {
            if separatorsBefore.contains(index) {
                menu.addItem(.separator())
            }
            let item = NSMenuItem(title: title, action: #selector(itemChosen(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            item.state = index == selectedIndex ? .on : .off
            item.setAlwaysVisibleImage(symbols[index].flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: nil) })
            menu.addItem(item)
        }
        let inset = Self.menuTitleInset - DS.Spacing.fieldInsetHorizontal
        menu.minimumWidth = bounds.width + inset
        guard let selectedIndex,
              let selected = menu.items.first(where: { !$0.isSeparatorItem && $0.tag == selectedIndex }) else {
            // Выбранного нет — под полем, правым краем к правому краю области.
            let gap: CGFloat = 4
            let origin = NSPoint(
                x: bounds.width - menu.size.width,
                y: isFlipped ? bounds.height + gap : -gap
            )
            menu.popUp(positioning: nil, at: origin, in: self)
            return
        }
        // Верх выбранного пункта — на верх подписи: пункт меню ниже поля, поэтому центрируем по высоте.
        let itemHeight: CGFloat = 22
        let y = isFlipped
            ? (bounds.height - itemHeight) / 2
            : bounds.height - (bounds.height - itemHeight) / 2
        menu.popUp(positioning: selected, at: NSPoint(x: -inset, y: y), in: self)
    }

    @objc private func itemChosen(_ sender: NSMenuItem) {
        onSelect?(sender.tag)
    }
}
