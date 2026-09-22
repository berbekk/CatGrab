import AppKit
import Combine
import SwiftUI

/// Состояние знакомства: страница и живая копия конфига — правки хоткея и палитры тут же видны
/// на кольце слева и сохраняются в настройки.
@MainActor
final class OnboardingModel: ObservableObject {
    @Published var page: OnboardingPage
    @Published private(set) var configuration: PieConfiguration
    /// Нужен ли перезапуск, чтобы «Мониторинг ввода» заработал: решает `AppDelegate` по состоянию tap'а.
    var needsRelaunch: () -> Bool = { false }
    /// Завершение тура: `relaunch` — перезапустить приложение, иначе просто открыть настройки.
    var onFinish: ((_ relaunch: Bool) -> Void)?

    private var subscription: AnyCancellable?
    /// Правки копятся и сохраняются с задержкой, как в настройках: поворот кольца пишет по шагу
    /// привязки, и каждое сохранение перерегистрирует хоткеи.
    private var pendingSave: DispatchWorkItem?

    init(startPage: OnboardingPage) {
        page = startPage
        configuration = ConfigManager.shared.configuration
        subscription = ConfigManager.shared.configurationPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] configuration in
                guard let self, self.pendingSave == nil else { return }
                self.configuration = configuration
            }
    }

    var mainMenu: PieMenu? {
        PieMenu.mainTemplateMenu(from: configuration.menus)
    }

    /// Меню «Main» как привязка — для превью с перетаскиванием и поля хоткея.
    var mainMenuBinding: Binding<PieMenu> {
        Binding(
            get: { self.mainMenu ?? PieMenu() },
            set: { menu in self.updateMainMenu { $0 = menu } }
        )
    }

    func updateMainMenu(_ change: (inout PieMenu) -> Void) {
        guard let mainId = mainMenu?.id, let index = configuration.menus.firstIndex(where: { $0.id == mainId }) else { return }
        change(&configuration.menus[index])
        scheduleSave()
    }

    /// Стартовый вид — всем обычным меню сразу: у нового пользователя оно одно.
    func applyPalette(_ preset: MenuThemePreset) {
        for index in configuration.menus.indices where !configuration.menus[index].isDynamicMenu {
            configuration.menus[index].applyPalette(preset)
        }
        scheduleSave()
    }

    private func scheduleSave() {
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingSave = nil
            ConfigManager.shared.save(self.configuration)
        }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Timings.settingsSaveDebounce, execute: work)
    }

    func flushPendingSave() {
        guard let work = pendingSave else { return }
        work.cancel()
        pendingSave = nil
        ConfigManager.shared.save(configuration)
    }

    /// Права выдали, пока открыта страница прав, — идём дальше сами.
    func permissionsGranted() {
        if page == .permissions { page = .done }
    }
}

struct OnboardingView: View {
    @ObservedObject var model: OnboardingModel
    @ObservedObject private var permissions = PermissionsMonitor.shared
    @EnvironmentObject private var localizer: LocalizationStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pickedTitle: String?
    @State private var pickedResetTask: Task<Void, Never>?
    /// Выбранный сектор в превью на страницах расстановки — только подсветка, инспектора здесь нет.
    @State private var arrangeSelection: UUID?
    /// Показательное движение: сдвиг сектора (радианы) или поворот кольца (градусы).
    @StateObject private var demo = DemoAnimator()

    static let windowSize = NSSize(width: 780, height: 500)
    private static let heroWidth: CGFloat = 340
    /// Палитры для первого выбора: спокойная, прозрачная, яркая, неоновая, пастельная, холодная.
    private static let starterPaletteIDs = ["classic", "crystal", "rainbow", "neon", "pastel", "ocean"]

    var body: some View {
        HStack(spacing: 0) {
            hero
                .frame(width: Self.heroWidth)
                .padding(DS.Spacing.l)

            VStack(alignment: .leading, spacing: 0) {
                ScrollView(showsIndicators: false) {
                    pageContent
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, DS.Spacing.xxl)
                        .padding(.trailing, DS.Spacing.xl)
                }
                footer
                    .padding(.trailing, DS.Spacing.xl)
                    .padding(.bottom, DS.Spacing.l)
            }
        }
        .frame(width: Self.windowSize.width, height: Self.windowSize.height)
        .background(DS.Colors.canvasTop)
        .onChange(of: model.page) { page in
            playDemo(for: page)
            // Системный диалог — когда человек дошёл до страницы прав, а не в первую секунду.
            guard page == .permissions else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + Timings.accessibilityPromptAfterOnboardingDelay) {
                if PermissionsSnapshot.current().accessibilityTrusted {
                    PermissionsSnapshot.promptInputMonitoringIfNeeded()
                } else {
                    PermissionsSnapshot.promptAccessibilityIfNeeded()
                }
            }
        }
    }

    // MARK: - Кольцо

    private var isArrangePage: Bool {
        model.page == .reorder || model.page == .rotate
    }

    /// Показать движение, о котором страница: сектор проезжает на соседнее место и возвращается,
    /// кольцо поворачивается на шаг и обратно. Только на экране, конфиг не меняется. С «Уменьшить
    /// движение» не проигрывается — жест описан текстом.
    private func playDemo(for page: OnboardingPage) {
        demo.cancel()
        guard !reduceMotion else { return }
        let sectorCount = max(1, model.mainMenu?.items.count ?? 1)
        switch page {
        case .reorder:
            // Лапа хватает верхний сектор, переносит на соседнее место, чуть перелетает, отпускает
            // и через паузу возвращает обратно.
            let step = 2 * Double.pi / Double(sectorCount)
            demo.play(after: 0.7, keyframes: [
                .init(value: step, duration: 1.0, response: 0.55, damping: 0.58),
                .hold(step, 0.5),
                .init(value: 0, duration: 1.0, response: 0.55, damping: 0.58)
            ])
        case .rotate:
            // Кольцо крутится на шаг в одну сторону, на два — в другую, и возвращается: видно и ход,
            // и привязку к «красивым» положениям.
            let step = PieMenu.aestheticRotationStepDegrees(for: sectorCount)
            demo.play(after: 0.7, keyframes: [
                .init(value: step, duration: 0.9, response: 0.6, damping: 0.62),
                .hold(step, 0.35),
                .init(value: -step, duration: 1.2, response: 0.7, damping: 0.62),
                .hold(-step, 0.35),
                .init(value: 0, duration: 0.9, response: 0.6, damping: 0.62)
            ])
        default:
            break
        }
    }

    private var hero: some View {
        VStack(spacing: DS.Spacing.s) {
            // Обе версии кольца — в одной и той же рамке с одними отступами и одной формулой
            // масштаба, иначе кольцо меняло размер при переходе на страницы расстановки.
            Group {
                if isArrangePage {
                    // Настоящее превью из редактора: перетаскивание секторов и ⌥-поворот — те же жесты,
                    // что потом в настройках у каждого меню.
                    MenuPreviewView(
                        menu: model.mainMenuBinding,
                        selectedItemId: $arrangeSelection,
                        hapticFeedbackEnabled: model.configuration.hapticFeedbackEnabled,
                        isAppearancePanelVisible: false,
                        showsEditorChrome: false,
                        demoDrag: model.page == .reorder && demo.isActive ? .init(index: 0, angleOffset: demo.value) : nil,
                        demoRotationOffsetDegrees: model.page == .rotate ? demo.value : 0
                    )
                    .onAppear { playDemo(for: model.page) }
                } else if let menu = model.mainMenu {
                    OnboardingRingDemo(menu: menu, language: localizer.language) { item in
                        pickedTitle = item.title
                        pickedResetTask?.cancel()
                        pickedResetTask = Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 1_800_000_000)
                            guard !Task.isCancelled else { return }
                            pickedTitle = nil
                        }
                    }
                }
            }
            .padding(DS.Spacing.m)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PreviewBackdrop.darkFill)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
            Text(heroCaption)
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .animation(DS.Motion.respectReducing(.easeInOut(duration: 0.15), reduce: reduceMotion), value: pickedTitle)
        }
    }

    private var heroCaption: String {
        switch model.page {
        case .reorder: return localizer.text(.dragToReorder)
        case .rotate: return localizer.text(.optionDragToRotate)
        default: return pickedTitle.map { String(format: localizer.text(.onboardingPickedFormat), $0) } ?? " "
        }
    }

    // MARK: - Страницы

    @ViewBuilder
    private var pageContent: some View {
        switch model.page {
        case .welcome: welcomePage
        case .open: openPage
        case .reorder: reorderPage
        case .rotate: rotatePage
        case .builtIn: builtInPage
        case .style: stylePage
        case .permissions: permissionsPage
        case .done: donePage
        }
    }

    private var welcomePage: some View {
        page(title: localizer.text(.onboardingWelcomeTitle), body: localizer.text(.onboardingWelcomeBody)) {
            Label(localizer.text(.onboardingTryHint), systemImage: "cursorarrow.motionlines")
                .font(DS.Typography.body)
                .foregroundStyle(.secondary)
        }
    }

    private var openPage: some View {
        page(title: localizer.text(.onboardingOpenTitle), body: localizer.text(.howToOpenHint)) {
            SettingsCard {
                SettingsRow(localizer.text(.hotkey)) {
                    HotkeyRecorderView(hotkey: mainHotkeyBinding)
                        .frame(width: DS.Sizing.settingsControlWidth)
                }
            }
            Text(localizer.text(.onboardingTrackpadNote))
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var reorderPage: some View {
        page(title: localizer.text(.onboardingReorderTitle), body: localizer.text(.onboardingReorderBody)) {
            Label(localizer.text(.dragToReorder), systemImage: "arrow.left.arrow.right")
                .font(DS.Typography.body)
                .foregroundStyle(.secondary)
            Text(localizer.text(.onboardingArrangeNote))
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var rotatePage: some View {
        page(title: localizer.text(.onboardingRotateTitle), body: localizer.text(.onboardingRotateBody)) {
            Label(localizer.text(.optionDragToRotate), systemImage: "option")
                .font(DS.Typography.body)
                .foregroundStyle(.secondary)
            Text(localizer.text(.onboardingArrangeNote))
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var builtInPage: some View {
        page(title: localizer.text(.onboardingBuiltInTitle), body: nil) {
            SettingsCard {
                VStack(spacing: DS.Spacing.m) {
                    builtInRow(
                        menu: PieConfiguration.templateRunningAppsMenu(),
                        title: localizer.text(.activeAppsMenuTitle),
                        body: localizer.text(.onboardingActiveAppsBody)
                    )
                    SettingsRowDivider()
                    builtInRow(
                        menu: PieConfiguration.templateAppCommandsMenu(),
                        title: localizer.text(.appCommandsMenuTitle),
                        body: localizer.text(.onboardingAppCommandsBody)
                    )
                }
            }
        }
    }

    private func builtInRow(menu: PieMenu, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.m) {
            MenuIconTile(menu: menu)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: DS.Spacing.s) {
                    Text(title)
                        .font(DS.Typography.bodyEmphasized)
                    if let hotkey = model.configuration.menus.first(where: { $0.kind == menu.kind })?.hotkey, !hotkey.isEmpty {
                        HotkeyCaption(text: hotkey.glyphString)
                    }
                }
                Text(body)
                    .font(DS.Typography.label)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var stylePage: some View {
        page(title: localizer.text(.onboardingStyleTitle), body: localizer.text(.onboardingStyleBody)) {
            let selected = model.mainMenu?.colorScheme.presetID
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
                ForEach(Self.starterPaletteIDs.compactMap(MenuThemePreset.withID)) { preset in
                    StarterPaletteCard(preset: preset, isSelected: preset.id == selected) {
                        model.applyPalette(preset)
                    }
                }
            }
            Text(localizer.text(.onboardingIconsNote))
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var permissionsPage: some View {
        page(title: localizer.text(.onboardingPermissionsTitle), body: localizer.text(.onboardingPermissionsBody)) {
            PermissionAccessCard()
        }
    }

    private var donePage: some View {
        let hotkey = model.mainMenu?.hotkey ?? .defaultHotkey
        return page(
            title: localizer.text(.onboardingDoneTitle),
            body: String(format: localizer.text(.onboardingDoneBodyFormat), hotkey.glyphString)
        ) {
            if model.needsRelaunch() {
                Label(localizer.text(.onboardingRelaunchNote), systemImage: "arrow.clockwise")
                    .font(DS.Typography.label)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            MenuBarIconHiddenBanner()
                .padding(.horizontal, -DS.Spacing.l)
        }
    }

    private func page<Content: View>(title: String, body: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            Text(title)
                .font(DS.Typography.onboardingTitle)
            if let body {
                Text(body)
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            content()
        }
        .id(model.page)
        .transition(.opacity)
        .animation(DS.Motion.respectReducing(.easeInOut(duration: 0.18), reduce: reduceMotion), value: model.page)
    }

    private var mainHotkeyBinding: Binding<HotkeyConfig> {
        Binding(
            get: { model.mainMenu?.hotkey ?? .empty },
            set: { hotkey in model.updateMainMenu { $0.hotkey = hotkey } }
        )
    }

    // MARK: - Подвал

    private var footer: some View {
        HStack(spacing: DS.Spacing.s) {
            HStack(spacing: 6) {
                ForEach(OnboardingPage.allCases, id: \.rawValue) { page in
                    Circle()
                        .fill(Color.primary.opacity(page == model.page ? 0.8 : 0.18))
                        .frame(width: 6, height: 6)
                }
            }
            .accessibilityHidden(true)
            Spacer(minLength: DS.Spacing.l)
            if let previous = model.page.previous {
                Button(localizer.text(.onboardingBack)) { model.page = previous }
                    .buttonStyle(DSFieldButtonStyle(minWidth: 96))
            }
            primaryButton
        }
    }

    @ViewBuilder
    private var primaryButton: some View {
        switch model.page {
        case .done:
            let relaunch = model.needsRelaunch()
            Button(localizer.text(relaunch ? .onboardingRestartAction : .onboardingFinishAction)) {
                model.flushPendingSave()
                model.onFinish?(relaunch)
            }
            .buttonStyle(DSFieldButtonStyle(minWidth: 140, isProminent: true))
            .keyboardShortcut(.defaultAction)
        case .permissions:
            let granted = permissions.snapshot.allRequiredGranted
            Button(localizer.text(granted ? .permissionsContinue : .permissionsSkip)) {
                model.page = .done
            }
            .buttonStyle(DSFieldButtonStyle(minWidth: 96, isProminent: granted))
            .keyboardShortcut(.defaultAction)
        default:
            Button(localizer.text(.permissionsContinue)) {
                if let next = model.page.next { model.page = next }
            }
            .buttonStyle(DSFieldButtonStyle(minWidth: 96, isProminent: true))
            .keyboardShortcut(.defaultAction)
        }
    }
}

/// Палитра для первого выбора: мини-кольцо и название, как в галерее «Параметров».
private struct StarterPaletteCard: View {
    let preset: MenuThemePreset
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false
    @EnvironmentObject private var localizer: LocalizationStore

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
        Button(action: action) {
            VStack(spacing: 5) {
                ThemeMiniRing(scheme: preset.scheme, intensity: preset.intensity, clearGlass: preset.glass == .clear)
                    .frame(width: 40, height: 40)
                Text(preset.title(localizer))
                    .font(DS.Typography.caption)
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.vertical, DS.Spacing.s)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .background(shape.fill(Color.primary.opacity(isHovered || isSelected ? 0.07 : 0.035)))
            .overlay(shape.strokeBorder(isSelected ? DS.Colors.blueAccent : Color.clear, lineWidth: DS.Border.focus + 0.4))
            .contentShape(shape)
        }
        .buttonStyle(DSPlainButtonStyle())
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .accessibilityLabel(Text(preset.title(localizer)))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
