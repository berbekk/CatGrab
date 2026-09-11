import SwiftUI
import AppKit

// MARK: - Design Tokens

enum DS {
    enum Radius {
        static let xs: CGFloat = 4
        static let s: CGFloat = 6
        static let m: CGFloat = 8
        static let l: CGFloat = 10
        static let xl: CGFloat = 12
        static let card: CGFloat = xl
        static let insetPanel: CGFloat = l

        /// Радиус внутреннего контура, концентричного внешнему при равном отступе `inset` между дугами.
        static func nested(outer: CGFloat, inset: CGFloat) -> CGFloat {
            max(0, outer - inset)
        }
    }

    /// Круговое меню (сектора).
    enum Pie {
        /// Скругление углов сектора в координатах кольца; дополнительно ограничивается размером сектора.
        static let sectorCornerRadius: CGFloat = 10
        /// Диаметр центрального хаба относительно внутреннего диаметра кольца.
        /// Уменьшен на 20% от предыдущего значения 0.86.
        static let centerHubDiameterRatio: CGFloat = 0.688
        /// Доля диаметра кота от `innerRadius * 2` в центре кольца (`PieMenuView`, превью настроек).
        static let centerCatArtDiameterFactor: CGFloat = 0.58
        /// Сектор без назначенного действия — слабее заливка стекла/тинта.
        static let unassignedSectorFillOpacityFactor: Double = 0.52
        /// Иконка в пустом секторе визуально вторична.
        static let unassignedIconOpacity: Double = 0.48
        /// Бейдж цифры быстрого выбора для пустого сектора.
        static let unassignedShortcutBadgeOpacityMultiplier: Double = 0.58
        /// Обводка сектора без действия чуть бледнее.
        static let unassignedSectorBorderOpacityMultiplier: Double = 0.72
    }

    enum Motion {
        /// Выезжающие панели (внешний вид меню, инспектор элемента).
        static let slidePanelSpring = Animation.spring(response: 0.28, dampingFraction: 0.82)

        /// Заменяет любую анимацию на отсутствующую, если включён Reduce Motion.
        /// Использовать в местах, где важна accessibility: `animation(DS.Motion.respectReducing(.spring(...), reduce: reduce), value: ...)`.
        static func respectReducing(_ base: Animation?, reduce: Bool) -> Animation? {
            reduce ? nil : base
        }
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 28
        /// Горизонтальный внутренний отступ у полей ввода и похожих контролов.
        static let fieldInsetHorizontal: CGFloat = 10
        /// Вертикальный отступ у компактных строк (поиск, табы).
        static let fieldInsetVertical: CGFloat = 8
    }

    enum Typography {
        static let bodySize: CGFloat = 13
        /// Заголовок боковой колонки / экрана
        static let screenTitle = Font.system(size: 15, weight: .semibold)
        /// Подзаголовок, счётчики
        static let subtitle = Font.system(size: 11, weight: .regular)
        /// Подписи полей, подсказки, второстепенные метки
        static let label = Font.system(size: 11, weight: .medium)
        /// Заголовки секций (в т.ч. uppercase)
        static let section = Font.system(size: 11, weight: .medium)
        /// Основной текст
        static let body = Font.system(size: bodySize, weight: .regular)
        /// Строки списков, заголовки панелей, акцент без лишнего веса
        static let bodyEmphasized = Font.system(size: bodySize, weight: .medium)
        /// Вторичные строки в компактных блоках
        static let bodyCompact = Font.system(size: 12, weight: .regular)
        /// Кнопки, значения в полях
        static let control = Font.system(size: 12, weight: .medium)
        /// Заголовки всплывающих панелей слайдеров
        static let panelHeading = Font.system(size: 12, weight: .medium)
        /// Хоткеи и мелкие подписи
        static let caption = Font.system(size: 10, weight: .medium)
        /// Пустое состояние
        static let emptyTitle = Font.title3.weight(.semibold)
        static let emptyStateGlyph = Font.system(size: 46, weight: .ultraLight)
        /// Крупная иконка в подвале сайдбара
        static let footerLeadingIcon = Font.system(size: 16, weight: .medium)
        /// Иконка в центре кольца меню
        static let hubIcon = Font.system(size: 14, weight: .medium)
        /// Ячейка символа в сетке
        static let symbolTile = Font.system(size: 21, weight: .medium)
        /// Ячейка эмодзи в сетке
        static let emojiTile = Font.system(size: 26, weight: .regular)
        /// Текст хоткея в поле записи и бейджах
        static func hotkeyDisplay(size: CGFloat = 12) -> Font {
            Font.system(size: size, weight: .semibold, design: .rounded)
        }
    }

    /// Коэффициенты визуального выравнивания разных типов иконок в кольце меню.
    enum PieIconVisualScale {
        /// Фавикон с сайта (кэш) часто выглядит крупнее остальных.
        static let favicon: CGFloat = 0.88
        /// SF Symbols по умолчанию заполняют квадрат сильнее текста и фавикона.
        static let sfSymbol: CGFloat = 0.82
        /// Доля от размера ячейки для кастомного текста `text:`.
        static let textFontToCell: CGFloat = 0.52
    }

    enum Sizing {
        static let fieldHeight: CGFloat = 32
        static let compactButtonHeight: CGFloat = 32
        static let iconPickerSize = CGSize(width: 480, height: 540)
        static let pickerTile: CGFloat = 48
        static let emojiTile: CGFloat = 48
        static let emptyStateHalo: CGFloat = 140
        static let closeButton: CGFloat = 24
        static let sidebarWidth: CGFloat = 360
        /// На сколько панель «Параметры» визуала шире колонки сайдбара.
        static let appearanceDrawerExtraWidth: CGFloat = 2
        static var appearanceDrawerWidth: CGFloat { sidebarWidth + appearanceDrawerExtraWidth }
        static let sidebarHeaderIconButton: CGFloat = 24
        static let sidebarFooterIconButton: CGFloat = 28
        static let sidebarIconGlyph: CGFloat = 14
        /// Круглая кнопка «очистить» в поле ввода
        static let fieldClearButton: CGFloat = 18
        static let sidebarRowMinHeight: CGFloat = 46
        /// Одна строка списка подменю приложения (имя, хоткей, удаление) в настройках.
        static let appBoundMenuSiblingRowHeight: CGFloat = 40
        /// Индикатор выбранного подменю в строке (круг вместо вертикальной полосы).
        static let appMenuRowSelectionDot: CGFloat = 8
        /// Сколько таких строк показывать по высоте; при большем числе меню список прокручивается.
        static let appBoundMenuMaxVisibleRows: Int = 4
        static var appBoundMenuScrollViewportHeight: CGFloat {
            let n = CGFloat(appBoundMenuMaxVisibleRows)
            return n * appBoundMenuSiblingRowHeight + (n - 1) * Spacing.s
        }
        static let sidebarIconTile: CGFloat = 28
        static let sidebarActionHeight: CGFloat = 42
        static let sidebarHorizontalPadding: CGFloat = 16
        static let sidebarRowInnerPadding: CGFloat = 12
        /// Максимальная ширина колонки хоткея в сайдбаре (обрезка длинных подписей вправо).
        static let sidebarHotkeyColumnMaxWidth: CGFloat = 172
        /// Колонка только с `NSSwitch` в строке «Запущенные приложения» (не занимать ширину под хоткей).
        static let sidebarRunningAppsSwitchColumnWidth: CGFloat = 52
        /// Целевой отступ шеврона выбора приложения от правого края строки (pt).
        static let sidebarAppMenuChevronTargetTrailingInset: CGFloat = 15
        /// Лишние pt справа из‑за вложенных паддингов списка/блока «для приложений»; вычитается из таргета.
        static let sidebarAppMenuChevronTrailingSlack: CGFloat = 23
        /// Фактический `.padding(.trailing)` у `SidebarAppMenuChevronColumn` (таргет минус «лишнее»).
        static var sidebarAppMenuChevronColumnPaddingTrailing: CGFloat {
            sidebarAppMenuChevronTargetTrailingInset - sidebarAppMenuChevronTrailingSlack
        }
        /// Единый вертикальный зазор в нижнем блоке сайдбара: до/после разделителя и снизу панели (= боковой отступ).
        static var sidebarFooterVerticalGutter: CGFloat { sidebarHorizontalPadding }
        /// Нижний отступ под «Системные параметры» (то же значение, что `sidebarFooterVerticalGutter`).
        static var sidebarSystemPrefsBottomInset: CGFloat { sidebarFooterVerticalGutter }
        /// Высота линии-разделителя в нижнем блоке сайдбара.
        static let sidebarDividerLineHeight: CGFloat = 1
        /// Суммарная высота нижнего блока сайдбара под списком: «Добавить/Удалить», разделитель, «Системные настройки», отступы.
        static var sidebarBottomChromeHeight: CGFloat {
            let addDeleteBlock = Spacing.s + sidebarRowMinHeight + sidebarFooterVerticalGutter
            let systemBlock = sidebarFooterVerticalGutter + sidebarRowMinHeight + sidebarFooterVerticalGutter
            return addDeleteBlock + sidebarDividerLineHeight + systemBlock
        }
        /// Верх секции «Настройки меню» в редакторе (положительный отступ от верха контента).
        static let menuEditorSettingsTop: CGFloat = 12
    }

    /// Фиксированный размер контента окна настроек (`NSWindow`, корневой `frame` у `SettingsView`).
    enum SettingsWindow {
        static let contentWidth: CGFloat = 1120
        static let contentHeight: CGFloat = 760
        /// Запас под title bar при `fullSizeContentView`, если `safeAreaInsets.top` приходит 0.
        static let minimumTitlebarContentInset: CGFloat = 28
    }

    enum Border {
        static let hairline: CGFloat = 0.8
        static let focus: CGFloat = 1.1
        static let emphasized: CGFloat = 1.0
    }

    enum Shadow {
        static let cardColor = Color.black.opacity(0.22)
        static let cardRadius: CGFloat = 18
        static let cardY: CGFloat = 8
    }

    enum Colors {
        private static func adaptive(light: NSColor, dark: NSColor) -> Color {
            let dynamic = NSColor(name: nil) { appearance in
                let match = appearance.bestMatch(from: [.darkAqua, .aqua])
                return match == .darkAqua ? dark : light
            }
            return Color(nsColor: dynamic)
        }

        static let canvasTop = adaptive(
            light: NSColor(srgbRed: 0.95, green: 0.95, blue: 0.96, alpha: 1.0),
            dark: NSColor(srgbRed: 0.13, green: 0.13, blue: 0.14, alpha: 1.0)
        )
        static let canvasBottom = adaptive(
            light: NSColor(srgbRed: 0.94, green: 0.94, blue: 0.95, alpha: 1.0),
            dark: NSColor(srgbRed: 0.12, green: 0.12, blue: 0.13, alpha: 1.0)
        )
        static let panelTop = adaptive(
            light: NSColor(srgbRed: 0.98, green: 0.98, blue: 0.98, alpha: 1.0),
            dark: NSColor(srgbRed: 0.18, green: 0.18, blue: 0.19, alpha: 1.0)
        )
        static let panelBottom = adaptive(
            light: NSColor(srgbRed: 0.96, green: 0.96, blue: 0.97, alpha: 1.0),
            dark: NSColor(srgbRed: 0.16, green: 0.16, blue: 0.17, alpha: 1.0)
        )
        static let field = adaptive(
            light: NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
            dark: NSColor(srgbRed: 0.22, green: 0.22, blue: 0.23, alpha: 1.0)
        )
        static let frostedTop = adaptive(
            light: NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.92),
            dark: NSColor(srgbRed: 0.23, green: 0.23, blue: 0.24, alpha: 0.88)
        )
        static let frostedBottom = adaptive(
            light: NSColor(srgbRed: 0.97, green: 0.97, blue: 0.98, alpha: 0.88),
            dark: NSColor(srgbRed: 0.17, green: 0.17, blue: 0.18, alpha: 0.82)
        )
        static let frostedStrokeTop = adaptive(
            light: NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.45),
            dark: NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.14)
        )
        static let frostedStrokeBottom = adaptive(
            light: NSColor(srgbRed: 0.55, green: 0.55, blue: 0.58, alpha: 0.24),
            dark: NSColor(srgbRed: 0.0, green: 0.0, blue: 0.0, alpha: 0.25)
        )
        static let tertiaryFill = Color.primary.opacity(0.06)
        static let elevatedFill = Color.primary.opacity(0.08)
        /// Семантическая линия-разделитель: сама адаптируется к Dark Mode и режиму Increased Contrast.
        static let stroke = Color(nsColor: .separatorColor)
        static let blueAccent = Color.accentColor
        /// Рамка выбранного меню в сайдбаре настроек (согласована с акцентом иконки).
        static let sidebarMenuSelectedStroke = blueAccent.opacity(0.55)

        /// Подпись хоткея: контраст на сине-залитом фоне.
        static let hotkeyLabel = adaptive(
            light: NSColor(srgbRed: 0.06, green: 0.14, blue: 0.36, alpha: 1.0),
            dark: NSColor(srgbRed: 0.94, green: 0.97, blue: 1.0, alpha: 1.0)
        )
        /// Фон бейджа хоткея и поля записи в покое (синий акцент).
        static let hotkeyBadgeFill = adaptive(
            light: NSColor(srgbRed: 0.88, green: 0.92, blue: 1.0, alpha: 1.0),
            dark: NSColor(srgbRed: 0.18, green: 0.32, blue: 0.62, alpha: 1.0)
        )
        static let hotkeyBadgeStroke = adaptive(
            light: NSColor(srgbRed: 0.28, green: 0.48, blue: 0.92, alpha: 0.5),
            dark: NSColor(srgbRed: 0.42, green: 0.68, blue: 1.0, alpha: 0.65)
        )
    }
}

// MARK: - Hotkey sidebar badge

/// Компактная подпись комбинации в списке меню (высокий контраст).
struct HotkeySidebarCaption: View {
    let text: String
    var isPlaceholder: Bool = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: DS.Radius.xs, style: .continuous)
        return Text(text)
            .font(DS.Typography.hotkeyDisplay(size: 11))
            .foregroundStyle(isPlaceholder ? Color.secondary.opacity(0.82) : DS.Colors.hotkeyLabel)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                shape.fill(isPlaceholder ? DS.Colors.hotkeyBadgeFill.opacity(0.55) : DS.Colors.hotkeyBadgeFill)
            )
            .overlay(
                shape.strokeBorder(
                    isPlaceholder ? DS.Colors.hotkeyBadgeStroke.opacity(0.45) : DS.Colors.hotkeyBadgeStroke,
                    lineWidth: DS.Border.hairline
                )
            )
    }
}

// MARK: - Plain Button + курсор

struct DSPlainButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .pointingHandCursor()
    }
}

// MARK: - Field Clear Button

struct FieldClearButton: View {
    let action: () -> Void
    @State private var isHovered = false
    @EnvironmentObject private var localizer: LocalizationStore

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(Color.primary.opacity(0.45))
                .frame(width: DS.Sizing.fieldClearButton, height: DS.Sizing.fieldClearButton)
                .background(
                    Circle()
                        .fill(Color.primary.opacity(isHovered ? 0.18 : 0.12))
                )
        }
        .buttonStyle(DSPlainButtonStyle())
        .onHover { isHovered = $0 }
        .accessibilityLabel(Text(localizer.text(.reset)))
    }
}

// MARK: - Input hit area (macOS)

extension View {
    /// Клик по всей ширине контейнера, а не только по узкой intrinsic-зоне поля.
    /// `minWidth: 0` нужен, чтобы во вложенных `HStack`/`Button` предложение ширины доходило до текста и троеточие не появлялось «раньше» свободного места.
    func stretchInputHorizontally(alignment: Alignment = .leading) -> some View {
        frame(minWidth: 0, maxWidth: .infinity, alignment: alignment)
    }
}

// MARK: - Modern TextField

struct ModernTextField: View {
    enum UpdateMode {
        case continuous
        case onBlur
    }

    private let placeholder: String
    @Binding var text: String
    private let updateMode: UpdateMode
    var onSubmit: (() -> Void)? = nil

    init(
        _ placeholder: String,
        text: Binding<String>,
        updateMode: UpdateMode = .continuous,
        onSubmit: (() -> Void)? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.updateMode = updateMode
        self.onSubmit = onSubmit
    }

    @State private var focused = false
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            PlainTextFieldRepresentable(
                text: $text,
                placeholder: placeholder,
                isFocused: $focused,
                commitsOnBlur: updateMode == .onBlur,
                onSubmit: onSubmit
            )
            .foregroundStyle(.primary)
            .padding(.leading, DS.Spacing.fieldInsetHorizontal)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            if !text.isEmpty {
                FieldClearButton {
                    text = ""
                }
            }
        }
        .padding(.trailing, DS.Spacing.fieldInsetHorizontal)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                .fill(DS.Colors.field.opacity(isHovered || focused ? 1.0 : 0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                .strokeBorder(
                    focused
                        ? DS.Colors.blueAccent.opacity(0.9)
                        : isHovered ? Color.white.opacity(0.2) : DS.Colors.stroke,
                    lineWidth: focused ? DS.Border.focus : DS.Border.hairline
                )
        )
        .frame(height: DS.Sizing.fieldHeight)
        .stretchInputHorizontally()
        .contentShape(RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous))
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }
}

// MARK: - Section Label

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(DS.Typography.label)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Form Field

struct FormField<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            SectionLabel(text: label)
            content
        }
    }
}

// MARK: - Toolbar Separator

struct ToolbarSeparator: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.1))
            .frame(width: 1, height: 18)
            .padding(.horizontal, 2)
    }
}

// MARK: - Toolbar Action Button

struct ToolbarActionButton: View {
    let icon: String
    let label: String
    var isDestructive: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    private var fg: Color {
        if isDestructive { return isHovered ? .red : Color.red.opacity(0.75) }
        return isHovered ? .primary : .secondary
    }

    private var bg: Color {
        if isDestructive { return isHovered ? Color.red.opacity(0.16) : Color.clear }
        return isHovered ? Color.white.opacity(0.08) : .clear
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: icon)
                    .font(DS.Typography.label)
                Text(label)
                    .font(DS.Typography.control)
            }
            .foregroundStyle(fg)
            .padding(.horizontal, DS.Spacing.s)
            .padding(.vertical, DS.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous)
                    .fill(bg)
            )
        }
        .buttonStyle(DSPlainButtonStyle())
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.1), value: isHovered)
    }
}

// MARK: - Settings Card

struct SettingsCard<Content: View>: View {
    var fillBackground: Bool = true
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(DS.Spacing.m)
            .background {
                if fillBackground {
                    RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .strokeBorder(DS.Colors.stroke, lineWidth: DS.Border.hairline)
            )
    }
}

// MARK: - Secondary Capsule Button

struct SecondaryCapsuleButton: View {
    let title: String
    let icon: String
    let isDestructive: Bool
    let action: () -> Void

    init(title: String, icon: String, isDestructive: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isDestructive = isDestructive
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(DS.Typography.control)
                .frame(minHeight: DS.Sizing.compactButtonHeight)
                .padding(.horizontal, DS.Spacing.s)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .tint(isDestructive ? .red : nil)
        .foregroundStyle(.primary)
        .pointingHandCursor()
    }
}

#Preview("DesignSystem Components") {
    VStack(spacing: DS.Spacing.xl) {
        ModernTextField("Placeholder", text: .constant("Hello"))
            .frame(width: 250)

        SectionLabel(text: "Section Label")

        FormField(label: "Form Field") {
            ModernTextField("Field", text: .constant("Value"))
        }
        .frame(width: 250)

        HStack(spacing: DS.Spacing.m) {
            ToolbarActionButton(icon: "plus", label: "Add", action: {})
            ToolbarSeparator()
            ToolbarActionButton(icon: "trash", label: "Delete", isDestructive: true, action: {})
        }

        SettingsCard {
            Text("Card Content")
                .foregroundStyle(.white)
                .frame(width: 200, height: 60)
        }

        HStack(spacing: DS.Spacing.m) {
            SecondaryCapsuleButton(title: "Action", icon: "bolt", action: {})
            SecondaryCapsuleButton(title: "Delete", icon: "trash", isDestructive: true, action: {})
        }
    }
    .padding(DS.Spacing.xxl)
    .background(DS.Colors.canvasTop)
    .preferredColorScheme(.dark)
}
