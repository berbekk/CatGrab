import SwiftUI

struct MenuAppearanceControlsView: View {
    @Binding var menu: PieMenu
    var onClose: (() -> Void)?

    /// Одна ширина для всех числовых полей справа (число + опционально суффикс).
    private static let valueTrayWidth: CGFloat = 82

    @EnvironmentObject private var localizer: LocalizationStore

    /// Явная привязка: `$menu.liquidGlass.tintOpacity` не всегда пробрасывает запись в `PieMenu` у родителя.
    private var liquidGlassTintBinding: Binding<Double> {
        Binding(
            get: { menu.liquidGlass.tintOpacity },
            set: { new in
                var m = menu
                m.liquidGlass.tintOpacity = new
                menu = m
            }
        )
    }

    private var rotationStep: Double {
        let halfSector = 180.0 / Double(max(1, menu.items.count))
        let divisions = ceil(halfSector / 5.0)
        return halfSector / divisions
    }

    private var appearanceScaleBinding: Binding<Double> {
        Binding(
            get: { menu.appearanceScale },
            set: { new in
                var m = menu
                m.appearanceScale = PieMenu.clampedAppearanceScale(new)
                menu = m
            }
        )
    }

    private var innerRadiusBinding: Binding<Double> {
        Binding(
            get: { menu.innerRadius },
            set: { new in
                var m = menu
                m.innerRadius = PieMenu.clampedInnerRadius(new, outerRadius: m.menuRadius)
                menu = m
            }
        )
    }

    private var pawSizeBinding: Binding<Double> {
        Binding(
            get: { menu.pawSizeScale },
            set: { new in
                var m = menu
                m.pawSizeScale = PieMenu.clampedPawSizeScale(new)
                menu = m
            }
        )
    }

    private var pawRadialBinding: Binding<Double> {
        Binding(
            get: { menu.pawRadialInset },
            set: { new in
                var m = menu
                m.pawRadialInset = PieMenu.clampedPawRadialInset(new)
                menu = m
            }
        )
    }

    private var pawEnabledBinding: Binding<Bool> {
        Binding(
            get: { menu.pawDecorationEnabled },
            set: { new in
                var m = menu
                m.pawDecorationEnabled = new
                menu = m
            }
        )
    }

    private var centerCatScaleBinding: Binding<Double> {
        Binding(
            get: { menu.centerCatScale },
            set: { new in
                var m = menu
                m.centerCatScale = PieMenu.clampedCenterCatScale(new)
                menu = m
            }
        )
    }

    private var centerAppIconScaleBinding: Binding<Double> {
        Binding(
            get: { menu.centerAppIconScale },
            set: { new in
                var m = menu
                m.centerAppIconScale = PieMenu.clampedCenterAppIconScale(new)
                menu = m
            }
        )
    }

    private var shortcutDigitSizeBinding: Binding<Double> {
        Binding(
            get: { menu.shortcutDigitSizeScale },
            set: { new in
                var m = menu
                m.shortcutDigitSizeScale = PieMenu.clampedShortcutDigitSizeScale(new)
                menu = m
            }
        )
    }

    private var shortcutDigitInsetLeftBinding: Binding<Double> {
        Binding(
            get: { menu.shortcutDigitInsetLeftScale },
            set: { new in
                var m = menu
                m.shortcutDigitInsetLeftScale = PieMenu.clampedShortcutDigitInsetLeftScale(new)
                menu = m
            }
        )
    }

    private var shortcutDigitInsetRightBinding: Binding<Double> {
        Binding(
            get: { menu.shortcutDigitInsetRightScale },
            set: { new in
                var m = menu
                m.shortcutDigitInsetRightScale = PieMenu.clampedShortcutDigitInsetRightScale(new)
                menu = m
            }
        )
    }

    private var shortcutDigitOpacityBinding: Binding<Double> {
        Binding(
            get: { menu.shortcutDigitOpacity },
            set: { new in
                var m = menu
                m.shortcutDigitOpacity = PieMenu.clampedShortcutDigitOpacity(new)
                menu = m
            }
        )
    }

    private var shortcutDigitColorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: menu.shortcutDigitColorHex) ?? .white },
            set: { newColor in
                var m = menu
                m.shortcutDigitColorHex = newColor.toHex() ?? PieMenu.defaultShortcutDigitColorHex
                menu = m
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(title: localizer.text(.parameters), onClose: onClose)

            ScrollView(showsIndicators: true) {
                VStack(alignment: .leading, spacing: DS.Spacing.m) {
                    DSSectionHeader(title: localizer.text(.appearanceSectionShape), topInset: 0)

                    modernSlider(
                        label: localizer.text(.appearanceScale),
                        icon: "arrow.up.left.and.arrow.down.right",
                        value: appearanceScaleBinding,
                        range: PieMenu.appearanceScaleAllowedRange,
                        step: 0.05,
                        textFromModel: { "\(Int(round($0 * 100)))" },
                        modelFromInput: { $0 / 100 },
                        unitSuffix: "%"
                    )

                    modernSlider(
                        label: localizer.text(.diameter),
                        icon: "circle.dashed",
                        value: $menu.menuRadius,
                        range: 80...250,
                        step: 10,
                        textFromModel: { "\(Int($0 * 2))" },
                        modelFromInput: { $0 / 2 }
                    )
                    .onChange(of: menu.menuRadius) { newOuter in
                        let c = PieMenu.clampedInnerRadius(menu.innerRadius, outerRadius: newOuter)
                        if c != menu.innerRadius {
                            var m = menu
                            m.innerRadius = c
                            menu = m
                        }
                    }

                    modernSlider(
                        label: localizer.text(.innerRadius),
                        icon: "circle.dotted",
                        value: innerRadiusBinding,
                        range: PieMenu.innerRadiusAllowedRange(outerRadius: menu.menuRadius),
                        step: 2,
                        textFromModel: { "\(Int($0))" },
                        modelFromInput: { $0 }
                    )

                    modernSlider(
                        label: localizer.text(.distance),
                        icon: "arrow.left.and.right",
                        value: $menu.iconDistance,
                        range: 0.3...1.0,
                        step: 0.05,
                        textFromModel: { "\(Int(round($0 * 100)))" },
                        modelFromInput: { $0 / 100 },
                        unitSuffix: "%"
                    )

                    modernSlider(
                        label: localizer.text(.icon),
                        icon: "square.resize",
                        value: $menu.iconSize,
                        range: 16...48,
                        step: 2,
                        textFromModel: { "\(Int($0))" },
                        modelFromInput: { $0 },
                        unitSuffix: "px"
                    )

                    modernSlider(
                        label: localizer.text(.rotation),
                        icon: "rotate.right",
                        value: $menu.rotationDegrees,
                        range: -180...180,
                        step: rotationStep,
                        textFromModel: { String(format: "%.1f", $0) },
                        modelFromInput: { $0 },
                        unitSuffix: "°"
                    )

                    DSSectionHeader(title: localizer.text(.appearanceSectionPaw), topInset: DS.Spacing.s)

                    controlRow(label: localizer.text(.pawDecorationShow), icon: "pawprint.fill") {
                        SettingsSwitch(isOn: pawEnabledBinding)
                            .controlSize(.small)
                    }

                    Group {
                        modernSlider(
                            label: localizer.text(.pawDecorationSize),
                            icon: "arrow.up.left.and.arrow.down.right",
                            value: pawSizeBinding,
                            range: 0.35...0.95,
                            step: 0.02,
                            textFromModel: { "\(Int(round($0 * 100)))" },
                            modelFromInput: { $0 / 100 },
                            unitSuffix: "%"
                        )

                        modernSlider(
                            label: localizer.text(.pawDecorationRadial),
                            icon: "arrow.down.to.line.compact",
                            value: pawRadialBinding,
                            range: 0.05...0.95,
                            step: 0.01,
                            textFromModel: { "\(Int(round($0 * 100)))" },
                            modelFromInput: { $0 / 100 },
                            unitSuffix: "%"
                        )
                    }
                    .opacity(menu.pawDecorationEnabled ? 1 : 0.45)
                    .disabled(!menu.pawDecorationEnabled)

                    // В центре меню команд вместо кота — иконка активного приложения.
                    if menu.isAppCommandsMenu {
                        modernSlider(
                            label: localizer.text(.centerAppIconSize),
                            icon: "app.fill",
                            value: centerAppIconScaleBinding,
                            range: PieMenu.centerAppIconScaleAllowedRange,
                            step: 0.02,
                            textFromModel: { "\(Int(round($0 * 100)))" },
                            modelFromInput: { $0 / 100 },
                            unitSuffix: "%"
                        )
                    } else {
                        modernSlider(
                            label: localizer.text(.centerCatSize),
                            icon: "cat.fill",
                            value: centerCatScaleBinding,
                            range: PieMenu.centerCatScaleAllowedRange,
                            step: 0.02,
                            textFromModel: { "\(Int(round($0 * 100)))" },
                            modelFromInput: { $0 / 100 },
                            unitSuffix: "%"
                        )
                    }

                    DSSectionHeader(title: localizer.text(.appearanceSectionDigits), topInset: DS.Spacing.s)

                    modernSlider(
                        label: localizer.text(.appearanceDigitSize),
                        icon: "textformat.size",
                        value: shortcutDigitSizeBinding,
                        range: PieMenu.shortcutDigitSizeScaleAllowedRange,
                        step: 0.01,
                        textFromModel: { "\(Int(round($0 * 100)))" },
                        modelFromInput: { $0 / 100 },
                        unitSuffix: "%"
                    )

                    modernSlider(
                        label: localizer.text(.appearanceDigitInsetLeft),
                        icon: "arrow.up.and.down.and.arrow.left.and.right",
                        value: shortcutDigitInsetLeftBinding,
                        range: PieMenu.shortcutDigitInsetLeftScaleAllowedRange,
                        step: 0.01,
                        textFromModel: { "\(Int(round($0 * 100)))" },
                        modelFromInput: { $0 / 100 },
                        unitSuffix: "%"
                    )

                    modernSlider(
                        label: localizer.text(.appearanceDigitInsetRight),
                        icon: "arrow.up.and.down.and.arrow.left.and.right",
                        value: shortcutDigitInsetRightBinding,
                        range: PieMenu.shortcutDigitInsetRightScaleAllowedRange,
                        step: 0.01,
                        textFromModel: { "\(Int(round($0 * 100)))" },
                        modelFromInput: { $0 / 100 },
                        unitSuffix: "%"
                    )

                    modernSlider(
                        label: localizer.text(.appearanceDigitOpacity),
                        icon: "circle.lefthalf.filled",
                        value: shortcutDigitOpacityBinding,
                        range: PieMenu.shortcutDigitOpacityAllowedRange,
                        step: 0.01,
                        textFromModel: { "\(Int(round($0 * 100)))" },
                        modelFromInput: { $0 / 100 },
                        unitSuffix: "%"
                    )

                    controlRow(label: localizer.text(.appearanceDigitColor), icon: "paintpalette") {
                        ColorPicker("", selection: shortcutDigitColorBinding, supportsOpacity: false)
                            .labelsHidden()
                    }

                    DSSectionHeader(title: localizer.text(.appearanceSectionGlass), topInset: DS.Spacing.s)

                    modernSlider(
                        label: localizer.text(.appearanceGlassTint),
                        icon: "paintpalette",
                        value: liquidGlassTintBinding,
                        range: 0.0...0.7,
                        step: 0.01,
                        textFromModel: { "\(Int(round($0 * 100)))" },
                        modelFromInput: { $0 / 100 },
                        unitSuffix: "%"
                    )
                }
                .padding(DS.Spacing.l)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: .infinity)
        .background(DS.Colors.canvasTop)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(DS.Colors.stroke)
                .frame(width: 1)
                .frame(maxHeight: .infinity)
                .ignoresSafeArea(edges: .top)
        }
    }

    /// Строка с подписью слева и контролом справа — в той же колонке, что и числовые поля ползунков.
    private func controlRow<Control: View>(
        label: String,
        icon: String,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .frame(width: 14)
            Text(label)
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)
            Spacer(minLength: DS.Spacing.s)
            control()
        }
        .frame(minHeight: 22)
    }

    private func modernSlider(
        label: String,
        icon: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        textFromModel: @escaping (Double) -> String,
        modelFromInput: @escaping (Double) -> Double,
        unitSuffix: String? = nil
    ) -> some View {
        VStack(spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: icon)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 14)
                Text(label)
                    .font(DS.Typography.label)
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 3) {
                    SteppedNumericField(
                        value: value,
                        range: range,
                        step: step,
                        textFromModel: textFromModel,
                        modelFromInput: modelFromInput
                    )
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    if let unitSuffix {
                        Text(unitSuffix)
                            .font(DS.Typography.hotkeyDisplay(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize()
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .frame(width: Self.valueTrayWidth, alignment: .trailing)
                .background(DS.Colors.field)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous))
            }
            Slider(value: steppedBinding(value: value, range: range, step: step), in: range)
                .controlSize(.regular)
                .tint(DS.Colors.blueAccent)
        }
    }

    private func steppedBinding(
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double
    ) -> Binding<Double> {
        Binding(
            get: { value.wrappedValue },
            set: { newValue in
                let steppedValue = (newValue / step).rounded() * step
                value.wrappedValue = min(max(steppedValue, range.lowerBound), range.upperBound)
            }
        )
    }

}

// MARK: - Numeric field (typed values alongside slider)

private struct SteppedNumericField: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let textFromModel: (Double) -> String
    let modelFromInput: (Double) -> Double

    @FocusState private var focused: Bool
    @State private var fieldText: String = ""

    var body: some View {
        TextField("", text: $fieldText)
            .focused($focused)
            .textFieldStyle(.plain)
            .font(DS.Typography.hotkeyDisplay(size: 11))
            .foregroundStyle(.primary)
            .multilineTextAlignment(.trailing)
            .onSubmit { commit() }
            .onChange(of: focused) { isFocused in
                if isFocused {
                    fieldText = textFromModel(value)
                } else {
                    commit()
                }
            }
            .onChange(of: value) { newValue in
                if !focused {
                    fieldText = textFromModel(newValue)
                }
            }
            .onAppear {
                fieldText = textFromModel(value)
            }
            .stretchInputHorizontally(alignment: .trailing)
            .pointingHandCursor()
    }

    private func commit() {
        let normalized = fieldText
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        guard let parsed = Double(normalized) else {
            fieldText = textFromModel(value)
            return
        }
        var model = modelFromInput(parsed)
        if step > 0 {
            model = (model / step).rounded() * step
        }
        model = min(max(model, range.lowerBound), range.upperBound)
        value = model
        fieldText = textFromModel(model)
    }
}
