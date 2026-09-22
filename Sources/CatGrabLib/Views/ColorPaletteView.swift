import SwiftUI

/// Большая палитра: «Как в теме» (для сектора), цвета текущей темы, библиотека из 84 цветов
/// и системное колесо для любого другого. Поповер не закрывается после выбора — удобно перебирать.
struct ColorPaletteView: View {
    struct ThemeOption {
        let color: String
        let isSelected: Bool
        let onPick: () -> Void
    }

    var themeOption: ThemeOption?
    var themeColors: [String]
    var selectedHex: String?
    var onPick: (String) -> Void
    /// Для цветов темы: убрать этот цвет из палитры.
    var onRemove: (() -> Void)?

    @EnvironmentObject private var localizer: LocalizationStore

    private static let swatch: CGFloat = 22
    private static let spacing: CGFloat = 4

    private var uniqueThemeColors: [String] {
        var seen = Set<String>()
        return themeColors.filter { seen.insert($0.uppercased()).inserted }
    }

    private var customColor: Binding<Color> {
        Binding(
            get: { Color(hex: selectedHex ?? "#0A84FF") ?? .blue },
            set: { onPick($0.toHex() ?? "#0A84FF") }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            if let themeOption {
                Button(action: themeOption.onPick) {
                    HStack(spacing: DS.Spacing.s) {
                        PaletteSwatch(hex: themeOption.color, isSelected: false, size: Self.swatch)
                        Text(localizer.text(.colorFromTheme))
                            .font(DS.Typography.body)
                            .foregroundStyle(.primary)
                        Spacer(minLength: 0)
                        if themeOption.isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(DS.Colors.blueAccent)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.s)
                    .frame(height: DS.Sizing.fieldHeight)
                    .dsFieldChrome(isHovered: false, isFocused: themeOption.isSelected)
                    .contentShape(Rectangle())
                }
                .buttonStyle(DSPlainButtonStyle())
            }

            if !uniqueThemeColors.isEmpty {
                section(localizer.text(.themeColors)) {
                    HStack(spacing: Self.spacing) {
                        ForEach(uniqueThemeColors, id: \.self) { hex in
                            swatchButton(hex)
                        }
                    }
                }
            }

            section(localizer.text(.allColors)) {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(Self.swatch), spacing: Self.spacing), count: ColorSwatchLibrary.columns),
                    spacing: Self.spacing
                ) {
                    ForEach(ColorSwatchLibrary.all, id: \.self) { hex in
                        swatchButton(hex)
                    }
                }
            }

            HStack {
                ColorPicker(localizer.text(.otherColor), selection: customColor, supportsOpacity: false)
                    .font(DS.Typography.body)
                Spacer(minLength: 0)
                if let onRemove {
                    Button(localizer.text(.removeColor), action: onRemove)
                        .buttonStyle(DSFieldButtonStyle(isDestructive: true))
                }
            }
        }
        .padding(DS.Spacing.m + 2)
        .frame(width: CGFloat(ColorSwatchLibrary.columns) * (Self.swatch + Self.spacing) - Self.spacing + (DS.Spacing.m + 2) * 2)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text(title)
                .font(DS.Typography.section)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            content()
        }
    }

    private func swatchButton(_ hex: String) -> some View {
        let isSelected = themeOption?.isSelected != true && selectedHex?.caseInsensitiveCompare(hex) == .orderedSame
        return Button { onPick(hex) } label: {
            PaletteSwatch(hex: hex, isSelected: isSelected, size: Self.swatch)
        }
        .buttonStyle(DSPlainButtonStyle())
        .accessibilityLabel(Text(hex))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

struct PaletteSwatch: View {
    let hex: String
    let isSelected: Bool
    var size: CGFloat = 22

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
        shape
            .fill(Color(hex: hex) ?? .gray)
            .frame(width: size, height: size)
            .overlay(shape.strokeBorder(Color.primary.opacity(0.14), lineWidth: DS.Border.hairline))
            .overlay {
                if isSelected {
                    shape.strokeBorder(Color.white, lineWidth: 2)
                        .padding(-1)
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.42, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.45), radius: 1, y: 0.5)
                }
            }
    }
}

/// Поле цвета в инспекторе: образец и подпись («Как в теме» или hex), по клику — палитра.
struct PaletteField: View {
    /// Цвет, который даёт тема.
    let themeColor: String
    let themeColors: [String]
    /// Свой цвет; nil — как в теме.
    let customHex: String?
    let accessibilityTitle: String
    let onUseTheme: () -> Void
    let onPick: (String) -> Void

    @EnvironmentObject private var localizer: LocalizationStore
    @State private var isPresented = false
    @State private var isHovered = false

    var body: some View {
        Button { isPresented.toggle() } label: {
            HStack(spacing: DS.Spacing.s) {
                PaletteSwatch(hex: customHex ?? themeColor, isSelected: false, size: 20)
                Text(customHex ?? localizer.text(.colorFromTheme))
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                SidebarAppMenuPickerChevronLabel()
            }
            .padding(.horizontal, DS.Spacing.fieldInsetHorizontal)
            .frame(height: DS.Sizing.fieldHeight)
            .frame(maxWidth: .infinity)
            .dsFieldChrome(isHovered: isHovered, isFocused: isPresented)
            .contentShape(Rectangle())
        }
        .buttonStyle(DSPlainButtonStyle())
        .onHover { isHovered = $0 }
        .accessibilityLabel(Text(accessibilityTitle))
        .popover(isPresented: $isPresented, arrowEdge: .trailing) {
            ColorPaletteView(
                themeOption: .init(color: themeColor, isSelected: customHex == nil, onPick: onUseTheme),
                themeColors: themeColors,
                selectedHex: customHex,
                onPick: onPick
            )
            .environmentObject(localizer)
        }
    }
}

/// Цвет сектора: «Как в теме» — цвет по месту в схеме меню, иначе свой.
struct SectorColorField: View {
    @Binding var item: PieMenuItem
    /// Цвет, который сектор получает от темы на своём месте.
    let themeColor: String
    let themeColors: [String]

    @EnvironmentObject private var localizer: LocalizationStore

    var body: some View {
        PaletteField(
            themeColor: themeColor,
            themeColors: themeColors,
            customHex: item.usesThemeColor ? nil : item.color,
            accessibilityTitle: localizer.text(.sectorColor),
            onUseTheme: { item.usesThemeColor = true },
            onPick: { hex in
                item.color = hex
                item.usesThemeColor = false
            }
        )
    }
}

/// Цвет иконки: «Как в теме» — иконка следует настройке меню «Цветные / Белые», иначе свой.
struct IconColorField: View {
    @Binding var item: PieMenuItem
    /// Цвет иконки по теме: белый или цвет сектора.
    let themeColor: String
    let themeColors: [String]

    @EnvironmentObject private var localizer: LocalizationStore

    var body: some View {
        PaletteField(
            themeColor: themeColor,
            themeColors: themeColors,
            customHex: item.iconColor,
            accessibilityTitle: localizer.text(.iconColorLabel),
            onUseTheme: { item.iconColor = nil },
            onPick: { item.iconColor = $0 }
        )
    }
}

/// Кружок одного цвета темы: по клику — палитра, в ней же «Убрать цвет».
struct ThemeColorWell: View {
    let hex: String
    /// Цвета для быстрого выбора сверху палитры; пусто — своя тема или ни к чему привязанный цвет.
    var themeColors: [String] = []
    let onPick: (String) -> Void
    var onRemove: (() -> Void)?
    /// `nil` — на всю ширину ячейки (сетка цветов схемы).
    var width: CGFloat? = Self.chipSize.width

    @EnvironmentObject private var localizer: LocalizationStore
    @State private var isPresented = false
    @State private var isHovered = false

    static let chipSize = CGSize(width: 100, height: 28)

    var body: some View {
        Button { isPresented.toggle() } label: {
            HStack(spacing: 6) {
                PaletteSwatch(hex: hex, isSelected: false, size: 18)
                Text(hex.uppercased())
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 5)
            .frame(width: width, height: Self.chipSize.height)
            .frame(maxWidth: width == nil ? .infinity : nil)
            .dsFieldChrome(isHovered: isHovered, isFocused: isPresented)
            .contentShape(Rectangle())
        }
        .buttonStyle(DSPlainButtonStyle())
        .onHover { isHovered = $0 }
        .accessibilityLabel(Text(hex))
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            ColorPaletteView(
                themeColors: themeColors,
                selectedHex: hex,
                onPick: onPick,
                onRemove: onRemove.map { remove in { isPresented = false; remove() } }
            )
            .environmentObject(localizer)
        }
    }
}
