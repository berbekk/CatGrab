import SwiftUI

/// Готовые палитры: мини-кольцо в цветах палитры и название. Палитра — не тема: клик меняет цвета,
/// насыщенность, стекло и иконки меню (и его темы, если она есть — как несохранённую правку),
/// а форму и детали не трогает. Превью справа меняется сразу, так что палитры удобно перебирать.
struct ThemeGalleryView: View {
    let selectedID: String?
    let onPick: (MenuThemePreset) -> Void

    @EnvironmentObject private var localizer: LocalizationStore

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4),
            spacing: 6
        ) {
            ForEach(MenuThemePreset.all) { preset in
                ThemeCard(
                    ring: ThemeMiniRing(scheme: preset.scheme, intensity: preset.intensity, clearGlass: preset.glass == .clear),
                    title: preset.title(localizer),
                    isSelected: preset.id == selectedID
                ) {
                    onPick(preset)
                }
            }
        }
    }
}

private struct ThemeCard: View {
    let ring: ThemeMiniRing
    let title: String
    let isSelected: Bool
    let action: () -> Void
    /// Своя тема: по наведению в углу крестик «удалить».
    var onDelete: (() -> Void)?
    @State private var isHovered = false
    @EnvironmentObject private var localizer: LocalizationStore

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
        Button(action: action) {
            VStack(spacing: 5) {
                ring
                    .frame(width: 44, height: 44)
                Text(title)
                    .font(DS.Typography.caption)
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.vertical, DS.Spacing.s)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .background(shape.fill(Color.primary.opacity(isHovered || isSelected ? 0.07 : 0.035)))
            .overlay(
                shape.strokeBorder(
                    isSelected ? DS.Colors.blueAccent : Color.clear,
                    lineWidth: DS.Border.focus + 0.4
                )
            )
            .contentShape(shape)
        }
        .buttonStyle(DSPlainButtonStyle())
        .overlay(alignment: .topTrailing) {
            if isHovered, let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color.black.opacity(0.55))
                }
                .buttonStyle(DSPlainButtonStyle())
                .padding(3)
                .iconOnlyHelp(localizer.text(.delete))
                .transition(.opacity)
            }
        }
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Свои темы и действия с ними. Темы живут в конфиге, а сохранение темы меняет все её меню,
/// поэтому действия приходят снаружи (из окна настроек).
struct ThemeLibrary {
    var themes: [CustomMenuTheme]
    /// Новая тема из вида меню; меню к ней привязывает `PieMenu.applyTheme`.
    var create: (String, PieMenu) -> CustomMenuTheme
    var rename: (UUID, String) -> Void
    /// Сохранить вид меню в тему — изменения расходятся по всем меню этой темы.
    var save: (UUID, PieMenu) -> Void
    var delete: (UUID) -> Void

    static let empty = ThemeLibrary(
        themes: [],
        create: { CustomMenuTheme(name: $0, menu: $1) },
        rename: { _, _ in },
        save: { _, _ in },
        delete: { _ in }
    )

    /// «Моя тема 1», «Моя тема 2»… — первое свободное имя.
    func defaultName(_ localizer: LocalizationStore) -> String {
        let names = Set(themes.map(\.name))
        let format = localizer.text(.customThemeNameFormat)
        let number = (1...).first { !names.contains(String(format: format, $0)) } ?? themes.count + 1
        return String(format: format, number)
    }
}

/// «Мои темы»: темы и карточка «Сохранить» — вид меню (цвет, форма, детали) становится темой.
/// Клик по теме оформляет ею меню и привязывает к ней. Правый клик — переименовать, сохранить
/// в тему вид этого меню, удалить.
struct CustomThemesGrid: View {
    let library: ThemeLibrary
    let menu: PieMenu
    let onApply: (CustomMenuTheme) -> Void

    @EnvironmentObject private var localizer: LocalizationStore
    @State private var isSaving = false
    @State private var renamingID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4),
                spacing: 6
            ) {
                ForEach(library.themes) { theme in
                    ThemeCard(
                        ring: ThemeMiniRing(look: theme.look),
                        title: theme.name,
                        isSelected: menu.themeID == theme.id,
                        action: { onApply(theme) },
                        onDelete: { library.delete(theme.id) }
                    )
                    .contextMenu { menuActions(for: theme) }
                    .popover(isPresented: renamingBinding(for: theme.id), arrowEdge: .bottom) {
                        ThemeNameForm(
                            title: localizer.text(.renameThemeTitle),
                            initialName: theme.name,
                            onConfirm: { name in
                                library.rename(theme.id, name)
                                renamingID = nil
                            },
                            onCancel: { renamingID = nil }
                        )
                        .environmentObject(localizer)
                    }
                }
                SaveThemeCard { isSaving = true }
                    .popover(isPresented: $isSaving, arrowEdge: .bottom) {
                        ThemeNameForm(
                            title: localizer.text(.newThemeTitle),
                            initialName: library.defaultName(localizer),
                            onConfirm: { name in
                                onApply(library.create(name, menu))
                                isSaving = false
                            },
                            onCancel: { isSaving = false }
                        )
                        .environmentObject(localizer)
                    }
            }
            if library.themes.isEmpty {
                Text(localizer.text(.myThemesEmptyHint))
                    .font(DS.Typography.label)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func menuActions(for theme: CustomMenuTheme) -> some View {
        Button(localizer.text(.renameThemeAction)) { renamingID = theme.id }
        Button(localizer.text(.updateThemeAction)) {
            library.save(theme.id, menu)
            onApply(theme)
        }
        Divider()
        Button(localizer.text(.delete), role: .destructive) { library.delete(theme.id) }
    }

    private func renamingBinding(for id: UUID) -> Binding<Bool> {
        Binding(get: { renamingID == id }, set: { if !$0 { renamingID = nil } })
    }
}

/// Тема меню сверху панели «Параметры», на всех вкладках: какая тема, есть ли правки, не
/// сохранённые в неё, и что с ними сделать — откатить к сохранённой или сохранить (тогда они
/// разойдутся по всем меню этой темы). Меню без темы можно сразу сохранить как тему.
struct ThemeStatusBar: View {
    let menu: PieMenu
    let library: ThemeLibrary
    /// Оформить меню темой: откат к сохранённой или привязка к только что созданной.
    let onApply: (CustomMenuTheme) -> Void

    @EnvironmentObject private var localizer: LocalizationStore
    @State private var isNaming = false

    var body: some View {
        let theme = menu.theme(in: library.themes)
        let isModified = theme.map { !$0.matches(menu) } ?? false
        HStack(spacing: DS.Spacing.s) {
            ThemeMiniRing(look: MenuLook(menu))
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(theme?.name ?? localizer.text(.customStyleName))
                    .font(DS.Typography.body)
                    .lineLimit(1)
                Text(localizer.text(theme == nil ? .themeStatusNone : isModified ? .themeStatusModified : .themeStatusSaved))
                    .font(DS.Typography.label)
                    .foregroundStyle(isModified ? Color.orange : Color.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: DS.Spacing.s)
            if let theme, isModified {
                Button { onApply(theme) } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .buttonStyle(DSFieldButtonStyle(width: DS.Sizing.fieldHeight))
                .iconOnlyHelp(localizer.text(.revertThemeAction))
                Button(localizer.text(.saveAction)) { library.save(theme.id, menu) }
                    .buttonStyle(DSFieldButtonStyle(isProminent: true))
            } else if theme == nil {
                Button(localizer.text(.saveAction)) { isNaming = true }
                    .buttonStyle(DSFieldButtonStyle())
                    .help(localizer.text(.saveThemeHelp))
                    .popover(isPresented: $isNaming, arrowEdge: .bottom) {
                        ThemeNameForm(
                            title: localizer.text(.newThemeTitle),
                            initialName: library.defaultName(localizer),
                            onConfirm: { name in
                                onApply(library.create(name, menu))
                                isNaming = false
                            },
                            onCancel: { isNaming = false }
                        )
                        .environmentObject(localizer)
                    }
            }
        }
        .padding(.horizontal, DS.Spacing.s + 2)
        .padding(.vertical, DS.Spacing.s)
        .frame(minHeight: DS.Sizing.fieldHeight + DS.Spacing.s * 2)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous)
                .strokeBorder(isModified ? Color.orange.opacity(0.45) : DS.Colors.stroke, lineWidth: DS.Border.hairline)
        )
        .animation(.easeInOut(duration: 0.15), value: isModified)
    }
}

/// Пунктирная карточка «Сохранить» в конце «Моих тем».
private struct SaveThemeCard: View {
    let action: () -> Void
    @State private var isHovered = false
    @EnvironmentObject private var localizer: LocalizationStore

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                // Не «Сохранить»: у плашки темы наверху так называется запись правок в текущую тему,
                // а эта карточка всегда создаёт новую.
                Text(localizer.text(.newThemeTitle))
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.vertical, DS.Spacing.s)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .background(shape.fill(Color.primary.opacity(isHovered ? 0.07 : 0.02)))
            .overlay(shape.strokeBorder(DS.Colors.stroke, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
            .contentShape(shape)
        }
        .buttonStyle(DSPlainButtonStyle())
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .help(localizer.text(.saveThemeHelp))
    }
}

/// Имя темы: при сохранении новой и при переименовании. Enter — сохранить.
struct ThemeNameForm: View {
    let title: String
    let onConfirm: (String) -> Void
    let onCancel: () -> Void
    @State private var name: String
    @EnvironmentObject private var localizer: LocalizationStore

    init(title: String, initialName: String, onConfirm: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.title = title
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _name = State(initialValue: initialName)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            Text(title)
                .font(DS.Typography.body.weight(.semibold))
            ModernTextField(localizer.text(.themeNamePlaceholder), text: $name, onSubmit: confirm)
                .frame(height: DS.Sizing.fieldHeight)
            HStack(spacing: DS.Spacing.s) {
                Spacer(minLength: 0)
                Button(localizer.text(.cancelAction), action: onCancel)
                    .buttonStyle(DSFieldButtonStyle())
                Button(localizer.text(.saveAction), action: confirm)
                    .buttonStyle(DSFieldButtonStyle(isProminent: true))
                    .disabled(trimmedName.isEmpty)
            }
        }
        .padding(DS.Spacing.m + 2)
        .frame(width: 280)
    }

    private func confirm() {
        guard !trimmedName.isEmpty else { return }
        onConfirm(trimmedName)
    }
}

/// Кольцо из восьми секторов в цветах схемы — узнаётся с первого взгляда.
struct ThemeMiniRing: View {
    let scheme: SectorColorScheme
    let intensity: Double
    var clearGlass = false
    var sectorCount = 8
    /// Толщина кольца: доля внутреннего радиуса от внешнего. У своих тем — как у сохранённого меню.
    var innerRatio = 0.44
    /// Цвет кота в центре; `nil` — как у нового меню (чёрный).
    var catColor: Color?

    /// Высота головы кота относительно её ширины (`design/cat.svg`, 99×93).
    private static let catHeadAspectRatio = 93.0 / 99.0

    @Environment(\.colorScheme) private var colorScheme

    /// Чёрный кот на тёмной карточке сливался с фоном: в тёмном оформлении силуэт чуть светлее
    /// и с контуром, в светлом — тёмный с лёгким контуром, как у самого кольца.
    private var headFill: Color {
        catColor ?? (colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.12))
    }

    private var headOutline: Color {
        colorScheme == .dark ? Color.white.opacity(0.32) : Color.black.opacity(0.18)
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outer = min(size.width, size.height) / 2
            let inner = outer * innerRatio

            Canvas { context, _ in
                let step = 2 * Double.pi / Double(sectorCount)
                let gap = 0.05
                // Насыщенность темы видна по плотности заливки; прозрачное стекло — светлее.
                let alpha = min(1, (clearGlass ? 0.35 : 0.5) + intensity * 0.9)
                for index in 0..<sectorCount {
                    let start = -Double.pi / 2 + Double(index) * step + gap
                    let end = start + step - gap * 2
                    var path = Path()
                    path.addArc(center: center, radius: outer, startAngle: .radians(start), endAngle: .radians(end), clockwise: false)
                    path.addArc(center: center, radius: inner, startAngle: .radians(end), endAngle: .radians(start), clockwise: true)
                    path.closeSubpath()
                    let color = Color(hex: scheme.color(at: index, count: sectorCount)) ?? .gray
                    context.fill(path, with: .color(color.opacity(alpha)))
                }
            }
            // Голова кота вместо простого кружка в центре — узнаваемый силуэт, как в самом меню.
            CatSVGHeadShape()
                .fill(headFill)
                .overlay(CatSVGHeadShape().stroke(headOutline, lineWidth: 0.8))
                .frame(width: inner * 1.5, height: inner * 1.5 * Self.catHeadAspectRatio)
                .position(center)
        }
        .accessibilityHidden(true)
    }
}

extension ThemeMiniRing {
    /// Мини-кольцо своей темы: её цвета, стекло и толщина кольца.
    init(look: MenuLook) {
        self.init(
            scheme: look.colorScheme,
            intensity: look.liquidGlass.tintOpacity,
            clearGlass: look.liquidGlass.variant == .clear,
            innerRatio: min(0.8, max(0.2, look.innerRadius / max(1, look.menuRadius))),
            catColor: Color(hex: look.catColorHex)
        )
    }
}

extension MenuThemePreset {
    private static let titleKeys: [String: L10nKey] = [
        "classic": .themeClassic, "crystal": .themeCrystal, "mono": .themeMono, "graphite": .themeGraphite,
        "rainbow": .themeRainbow, "retro": .themeRetro, "candy": .themeCandy, "citrus": .themeCitrus,
        "neon": .themeNeon, "cyber": .themeCyber, "berry": .themeBerry,
        "pastel": .themePastel, "sakura": .themeSakura, "lavender": .themeLavender, "mint": .themeMint,
        "ice": .themeIce, "ocean": .themeOcean, "aurora": .themeAurora, "forest": .themeForest,
        "autumn": .themeAutumn, "sunset": .themeSunset, "gold": .themeGold, "coffee": .themeCoffee,
        "midnight": .themeMidnight
    ]

    func title(_ localizer: LocalizationStore) -> String {
        Self.titleKeys[id].map(localizer.text) ?? id.capitalized
    }
}
