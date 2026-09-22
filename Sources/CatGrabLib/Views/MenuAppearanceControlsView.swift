import SwiftUI

struct MenuAppearanceControlsView: View {
    /// Набор одного приложения: вид общий для меню «Команды приложения» или свой только для него.
    struct LookScope {
        let appName: String
        let hasOwnLook: Binding<Bool>
    }

    @Binding var menu: PieMenu
    /// Свои темы пользователя — общие для всех меню.
    var themeLibrary: ThemeLibrary = .empty
    /// Открытая вкладка при появлении панели; по умолчанию — «Темы». Для тестов и превью.
    var initialTab: Tab = .themes
    var lookScope: LookScope?
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
        let halfSector = 180.0 / Double(max(1, menu.sectorCount))
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

    private var showsHoverLabelBinding: Binding<Bool> {
        Binding(
            get: { menu.showsHoverLabel },
            set: { new in
                var m = menu
                m.showsHoverLabel = new
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

    /// Записать цвет в меню одним присваиванием, как и остальные поля панели.
    private func setColor(_ keyPath: WritableKeyPath<PieMenu, String>) -> (String) -> Void {
        { hex in
            var m = menu
            m[keyPath: keyPath] = hex
            menu = m
        }
    }

    enum Tab: Hashable {
        case themes
        case color
        case shape
        case details
    }

    @State private var tab: Tab

    init(menu: Binding<PieMenu>, themeLibrary: ThemeLibrary = .empty, initialTab: Tab = .themes, lookScope: LookScope? = nil, onClose: (() -> Void)? = nil) {
        self._menu = menu
        self.themeLibrary = themeLibrary
        self.initialTab = initialTab
        self.lookScope = lookScope
        self.onClose = onClose
        self._tab = State(initialValue: initialTab)
    }

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(title: localizer.text(.parameters), onClose: onClose)

            if let lookScope {
                lookScopeControl(lookScope)
                    .padding(.horizontal, DS.Spacing.l)
                    .padding(.top, DS.Spacing.m)
            }

            // Правки на любой вкладке — правки темы: сохранить или откатить их можно отсюда.
            ThemeStatusBar(menu: menu, library: themeLibrary, onApply: applyTheme)
                .padding(.horizontal, DS.Spacing.l)
                .padding(.top, DS.Spacing.m)

            DSSegmented(selection: $tab, options: [
                (.themes, localizer.text(.themesTab)),
                (.color, localizer.text(.menuColorSection)),
                (.shape, localizer.text(.appearanceSectionShape)),
                (.details, localizer.text(.detailsTab))
            ])
            .padding(.horizontal, DS.Spacing.l)
            .padding(.top, DS.Spacing.m)

            ScrollView(showsIndicators: true) {
                VStack(alignment: .leading, spacing: DS.Spacing.m) {
                    switch tab {
                    case .themes: themesTab
                    case .color: colorTab
                    case .shape: shapeTab
                    case .details: detailsTab
                    }
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

    /// Общий вид меняется вместе с меню «Команды приложения» у всех приложений без своего вида.
    private func lookScopeControl(_ scope: LookScope) -> some View {
        labeled(localizer.text(.lookScopeTitle)) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                DSSegmented(selection: scope.hasOwnLook, options: [
                    (false, localizer.text(.lookScopeShared)),
                    (true, localizer.text(.lookScopeOwn))
                ])
                Text(scope.hasOwnLook.wrappedValue
                    ? String(format: localizer.text(.lookScopeOwnHintFormat), scope.appName)
                    : localizer.text(.lookScopeSharedHint))
                    .font(DS.Typography.label)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Color tab

    /// Свои темы — стиль целиком (цвет, форма, детали). Клик оформляет меню темой и привязывает к ней.
    @ViewBuilder
    private var themesTab: some View {
        themesHeader(localizer.text(.myThemesSection), caption: localizer.text(.myThemesCaption), topInset: 0)
        CustomThemesGrid(library: themeLibrary, menu: menu, onApply: applyTheme)
    }

    private func applyTheme(_ theme: CustomMenuTheme) {
        var m = menu
        m.applyTheme(theme)
        menu = m
    }

    private func themesHeader(_ title: String, caption: String, topInset: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            DSSectionHeader(title: title, topInset: topInset)
            Text(caption)
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Цвета: сначала готовые палитры — быстро перебрать, ниже — тонкая настройка.
    @ViewBuilder
    private var colorTab: some View {
        themesHeader(localizer.text(.builtInThemesSection), caption: localizer.text(.builtInThemesCaption), topInset: 0)
        ThemeGalleryView(selectedID: menu.colorScheme.presetID) { preset in
            var m = menu
            m.applyPalette(preset)
            menu = m
        }

        DSSectionHeader(title: localizer.text(.colorFineTuningSection), topInset: DS.Spacing.s)
        DSSegmented(
            selection: colorModeBinding,
            options: [
                (.palette, localizer.text(.colorModePalette)),
                (.gradient, localizer.text(.colorModeGradient)),
                (.single, localizer.text(.colorModeSingle))
            ],
            accessibilityLabel: localizer.text(.colorModeTitle)
        )

        labeled(schemeColorsTitle, icon: "paintpalette") {
            schemeColorsEditor
        }

        modernSlider(
            label: localizer.text(.colorIntensity),
            icon: "drop.halffull",
            value: liquidGlassTintBinding,
            range: 0.0...0.7,
            step: 0.01,
            textFromModel: { "\(Int(round($0 * 100)))" },
            modelFromInput: { $0 / 100 },
            unitSuffix: "%"
        )

        labeled(localizer.text(.glassStyle), icon: "cube.transparent") {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                DSSegmented(selection: glassBinding, options: [
                    (.regular, localizer.text(.glassRegular)),
                    (.clear, localizer.text(.glassClear))
                ])
                Text(localizer.text(.glassStyleHint))
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        labeled(localizer.text(.iconStyleTitle), icon: "square.grid.2x2") {
            DSSegmented(selection: iconStyleBinding, options: [
                (.white, localizer.text(.iconStyleWhite)),
                (.tinted, localizer.text(.iconStyleTinted))
            ])
        }

        // Все цвета меню — на одной вкладке: и секторов, и кота с лапкой, и цифр.
        DSSectionHeader(title: localizer.text(.catPawDigitsColorSection), topInset: DS.Spacing.s)
        // Один ряд: подписи сверху, плашки снизу. По нижнему краю — если подпись на другом языке
        // перенесётся на вторую строку, плашки всё равно останутся на одной линии.
        colorGrid(cellAlignment: .bottomLeading) {
            colorCell(label: localizer.text(.catColorTitle), icon: "cat.fill", hex: menu.catColorHex, onPick: setColor(\.catColorHex))
            colorCell(label: localizer.text(.pawColorTitle), icon: "pawprint.fill", hex: menu.pawColorHex, onPick: setColor(\.pawColorHex))
            colorCell(
                label: localizer.text(.digitsColorTitle),
                icon: "number",
                hex: menu.shortcutDigitColorHex,
                onPick: setColor(\.shortcutDigitColorHex)
            )
        }

        // Всегда последним: сбрасывает свои цвета отдельных секторов, а не настройки выше.
        if menu.customColorCount > 0 {
            HStack(spacing: DS.Spacing.s) {
                Text(String(format: localizer.text(.sectorColorsCustomFormat), menu.customColorCount))
                    .font(DS.Typography.label)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: DS.Spacing.s)
                Button(localizer.text(.resetSectorColors)) {
                    var m = menu
                    m.resetSectorColors()
                    menu = m
                }
                .buttonStyle(DSFieldButtonStyle())
            }
            .padding(.top, DS.Spacing.s)
        }
    }

    /// Подпись над цветами схемы — по режиму: один цвет, цвета палитры или градиента.
    private var schemeColorsTitle: String {
        switch menu.colorScheme.mode {
        case .single: return localizer.text(.mainColorTitle)
        case .palette: return localizer.text(.paletteColorsTitle)
        case .gradient: return localizer.text(.gradientColorsTitle)
        }
    }

    /// Цвета схемы плашками «образец + код»: клик — палитра, «+» — ещё цвет. Идут по порядку
    /// секторов (у градиента — от первого к последнему) и переносятся на новые строки.
    private var schemeColorsEditor: some View {
        let scheme = menu.colorScheme
        let limit = scheme.mode == .gradient ? SectorColorScheme.maxGradientStops : SectorColorScheme.maxPaletteColors
        let canRemove = scheme.mode != .single && scheme.colors.count > 2
        let canAdd = scheme.mode != .single && scheme.colors.count < limit
        return colorGrid {
            ForEach(Array(scheme.colors.enumerated()), id: \.offset) { index, hex in
                schemeWell(index: index, hex: hex, canRemove: canRemove)
            }
            if canAdd { addColorButton }
        }
    }

    /// Три колонки во всю ширину — края сетки совпадают с переключателями выше и ниже.
    /// Через неё же идут цвета кота, лапки и цифр, чтобы все плашки были одного размера.
    private func colorGrid<Content: View>(
        cellAlignment: Alignment? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 6, alignment: cellAlignment), count: 3),
            alignment: .leading,
            spacing: 6,
            content: content
        )
    }

    private func schemeWell(index: Int, hex: String, canRemove: Bool) -> some View {
        ThemeColorWell(
            hex: hex,
            onPick: { new in updateScheme { $0.colors[index] = new } },
            onRemove: canRemove ? { updateScheme { $0.colors.remove(at: index) } } : nil,
            width: nil
        )
    }

    private var addColorButton: some View {
        Button {
            updateScheme { $0.colors.append(HexColor.rotateHue($0.colors.last ?? "#0A84FF", by: 40)) }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: ThemeColorWell.chipSize.height)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                        .strokeBorder(DS.Colors.stroke, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(DSPlainButtonStyle())
        .iconOnlyHelp(localizer.text(.addColor))
    }

    private func updateScheme(_ change: (inout SectorColorScheme) -> Void) {
        var m = menu
        change(&m.colorScheme)
        m.colorScheme.presetID = nil
        menu = m
    }

    private var colorModeBinding: Binding<SectorColorScheme.Mode> {
        Binding(
            get: { menu.colorScheme.mode },
            set: { mode in
                var m = menu
                m.colorScheme.switchMode(to: mode)
                menu = m
            }
        )
    }

    private var glassBinding: Binding<LiquidGlassVariant> {
        Binding(
            get: { menu.liquidGlass.variant },
            set: { variant in
                var m = menu
                m.liquidGlass.variant = variant
                menu = m
            }
        )
    }

    private var iconStyleBinding: Binding<SectorIconStyle> {
        Binding(
            get: { menu.iconStyle },
            set: { style in
                var m = menu
                m.iconStyle = style
                menu = m
            }
        )
    }

    /// Подпись над контролом; иконка — как у строк с ползунками, чтобы подписи стояли в одну колонку.
    private func labeled<Content: View>(
        _ title: String,
        icon: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs + 2) {
            HStack(spacing: DS.Spacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 14)
                }
                Text(title)
                    .font(DS.Typography.label)
                    .foregroundStyle(.secondary)
            }
            content()
        }
    }

    // MARK: - Shape & details tabs

    @ViewBuilder
    private var shapeTab: some View {
        DSSectionHeader(title: localizer.text(.ringSection), topInset: 0)

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

        // Центр — тоже диаметром, как и всё кольцо: радиус рядом с диаметром путал.
        modernSlider(
            label: localizer.text(.centerDiameterTitle),
            icon: "circle.dotted",
            value: innerRadiusBinding,
            range: PieMenu.innerRadiusAllowedRange(outerRadius: menu.menuRadius),
            step: 2,
            textFromModel: { "\(Int($0 * 2))" },
            modelFromInput: { $0 / 2 }
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

        DSSectionHeader(title: localizer.text(.shapeIconsSection), topInset: DS.Spacing.s)

        modernSlider(
            label: localizer.text(.iconSizeTitle),
            icon: "square.resize",
            value: $menu.iconSize,
            range: 16...48,
            step: 2,
            textFromModel: { "\(Int($0))" },
            modelFromInput: { $0 },
            unitSuffix: "px"
        )

        modernSlider(
            label: localizer.text(.iconDistanceTitle),
            icon: "arrow.left.and.right",
            value: $menu.iconDistance,
            range: 0.3...1.0,
            step: 0.05,
            textFromModel: { "\(Int(round($0 * 100)))" },
            modelFromInput: { $0 / 100 },
            unitSuffix: "%"
        )
    }

    @ViewBuilder
    private var detailsTab: some View {
        DSSectionHeader(title: localizer.text(.appearanceSectionPointer), topInset: 0)

        controlRow(label: localizer.text(.showHoverLabelTitle), icon: "text.bubble") {
            SettingsSwitch(isOn: showsHoverLabelBinding)
                .controlSize(.small)
        }

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

    }

    /// Ячейка сетки цветов: подпись сверху, плашка во всю ячейку под ней.
    private func colorCell(label: String, icon: String, hex: String, onPick: @escaping (String) -> Void) -> some View {
        labeled(label, icon: icon) {
            ThemeColorWell(hex: hex, themeColors: menu.colorScheme.sampleColors, onPick: onPick, width: nil)
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
