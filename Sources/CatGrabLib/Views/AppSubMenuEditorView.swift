import AppKit
import SwiftUI

/// Пункты меню запущенного приложения для выбора в редакторе набора команд.
@MainActor
final class AppMenuCatalog: ObservableObject {
    struct Item: Identifiable, Equatable {
        let path: [String]
        let shortcut: MenuShortcut?
        var id: String { path.joined(separator: "\u{1F}") }
        var title: String { path.last ?? "" }
        /// Промежуточные подменю: «Новое окно» лежит в «Файл», а «С профилем…» — в «Оболочка › Новое окно».
        var parentPath: [String] { Array(path.dropFirst().dropLast()) }
    }

    enum State: Equatable {
        case idle
        case noAccess
        case notRunning
        case loading
        case loaded([Item])
    }

    @Published private(set) var state: State = .idle

    /// Небольшая пауза после запуска приложения: меню появляется не сразу.
    private static let menuReadyDelay: TimeInterval = 1.0

    func load(bundleIdentifier: String) {
        guard AXIsProcessTrusted() else {
            state = .noAccess
            return
        }
        guard let app = PieSubActionResolver.runningApp(bundleIdentifier: bundleIdentifier) else {
            state = .notRunning
            return
        }
        state = .loading
        let pid = app.processIdentifier
        PieSubActionResolver.queue.async {
            let items = AppMenuCommandReader.allItems(pid: pid).map { Item(path: $0.path, shortcut: $0.shortcut) }
            DispatchQueue.main.async { [weak self] in
                self?.state = .loaded(items)
            }
        }
    }

    /// Запускает приложение в фоне, не уводя фокус из настроек, и читает его меню.
    func launchAndLoad(bundleIdentifier: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else { return }
        state = .loading
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        let delay = Self.menuReadyDelay
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { [weak self] _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self?.load(bundleIdentifier: bundleIdentifier)
            }
        }
    }

    func contains(path: [String], shortcut: MenuShortcut?) -> Bool? {
        guard case .loaded(let items) = state else { return nil }
        return items.contains { $0.path == path || (shortcut != nil && $0.shortcut == shortcut) }
    }
}

/// Свой набор команд одного приложения — правая панель настроек, когда в сайдбаре выбрано приложение.
/// Слева — кольцо, каким меню команд откроется в этом приложении (как превью у остальных меню),
/// справа — что можно добавить.
struct AppSubMenuEditorView: View {
    let bundleIdentifier: String
    @Binding var appSubMenus: [AppSubMenu]
    /// Меню «Команды приложения»: его вид — у набора каждого приложения, поворот — пока у набора нет своего.
    let appCommandsMenu: PieMenu
    var hapticFeedbackEnabled: Bool
    /// Убрать свой набор — приложение снова получит автоматические команды.
    var onReset: () -> Void

    @EnvironmentObject private var localizer: LocalizationStore
    @StateObject private var catalog = AppMenuCatalog()
    @State private var searchText = ""
    @State private var iconPickerEntryId: UUID?
    @State private var selectedEntryId: UUID?

    static func appName(for bundleIdentifier: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        }
        return bundleIdentifier
    }

    private var appName: String {
        Self.appName(for: bundleIdentifier)
    }

    private var subMenuIndex: Int? {
        appSubMenus.firstIndex { $0.matches(bundleIdentifier: bundleIdentifier) }
    }

    private var entries: [AppSubMenuEntry] {
        subMenuIndex.map { appSubMenus[$0].entries } ?? []
    }

    private var selectedEntry: AppSubMenuEntry? {
        selectedEntryId.flatMap { id in entries.first { $0.id == id } }
    }

    private var effectiveRotation: Double {
        subMenuIndex.flatMap { appSubMenus[$0].rotationDegrees } ?? appCommandsMenu.rotationDegrees
    }

    /// Меню команд с командами и поворотом этого набора: превью рисует ровно то, что откроется в приложении.
    /// Обратно записываются команды (порядок, удаление) и поворот — вид меню здесь не меняется.
    private var previewMenuBinding: Binding<PieMenu> {
        Binding(
            get: {
                var menu = appCommandsMenu
                menu.appCommandsDefaultEntries = entries
                menu.rotationDegrees = effectiveRotation
                return menu
            },
            set: { newMenu in
                if newMenu.rotationDegrees != effectiveRotation, let index = subMenuIndex {
                    appSubMenus[index].rotationDegrees = newMenu.rotationDegrees
                }
                updateEntries { $0 = newMenu.appCommandsDefaultEntries }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            header
            HStack(alignment: .top, spacing: DS.Spacing.m) {
                column(title: localizer.text(.subMenuChosen)) { chosenColumn }
                column(title: localizer.text(.add)) { availableColumn }
            }
        }
        .padding(.horizontal, DS.Spacing.l)
        .padding(.top, DS.Spacing.s + DS.Spacing.m)
        .padding(.bottom, DS.Spacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DS.Colors.canvasTop)
        .onAppear { catalog.load(bundleIdentifier: bundleIdentifier) }
    }

    // MARK: - Шапка

    private var header: some View {
        HStack(alignment: .center, spacing: DS.Spacing.m) {
            if let icon = AppIconResolver.shared.icon(forBundleIdentifier: bundleIdentifier) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 40, height: 40)
            }
            Text(String(format: localizer.text(.subMenuEditorTitleFormat), appName))
                .font(DS.Typography.screenTitle)
                .lineLimit(1)
            Spacer(minLength: DS.Spacing.l)
            Button(localizer.text(.subMenuResetToAutomatic), action: onReset)
                .buttonStyle(DSFieldButtonStyle())
                .help(localizer.text(.subMenuResetToAutomaticHelp))
        }
    }

    private func column<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            DSSectionHeader(title: title, topInset: 0)
            SettingsCard {
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - В меню

    @ViewBuilder
    private var chosenColumn: some View {
        if entries.isEmpty {
            Text(localizer.text(.subMenuChosenEmpty))
                .font(DS.Typography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: DS.Spacing.s) {
                MenuPreviewView(
                    menu: previewMenuBinding,
                    selectedItemId: $selectedEntryId,
                    hapticFeedbackEnabled: hapticFeedbackEnabled,
                    isAppearancePanelVisible: false,
                    onToggleAppearancePanel: {},
                    appSetBundleId: bundleIdentifier
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                SettingsRowDivider()
                selectionFooter
            }
        }
    }

    /// Выбранный сектор: сменить иконку или убрать. Высота постоянная — до выбора здесь подсказка,
    /// поэтому кольцо над строкой не прыгает.
    private var selectionFooter: some View {
        Group {
            if let entry = selectedEntry {
                let missing = entry.kind == .menuItem
                    && catalog.contains(path: entry.menuPath, shortcut: entry.shortcut) == false
                HStack(spacing: DS.Spacing.m) {
                    iconButton(for: entry)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title(of: entry))
                            .font(DS.Typography.body)
                            .lineLimit(1)
                        Text(missing ? localizer.text(.subMenuMissing) : caption(of: entry))
                            .font(DS.Typography.label)
                            .foregroundStyle(missing ? Color.orange : Color.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if let shortcut = entry.shortcut {
                        HotkeyCaption(text: shortcut.displayString)
                    }
                    Button(localizer.text(.subMenuRemove)) {
                        withoutAnimation {
                            updateEntries { $0.removeAll { $0.id == entry.id } }
                        }
                        selectedEntryId = nil
                    }
                    .buttonStyle(DSFieldButtonStyle(isDestructive: true))
                }
            } else {
                Text(localizer.text(.tapSectorToEdit))
                    .font(DS.Typography.label)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: DS.Sizing.fieldHeight + DS.Spacing.s)
    }

    private func iconButton(for entry: AppSubMenuEntry) -> some View {
        Button {
            iconPickerEntryId = entry.id
        } label: {
            IconView(icon: entry.resolvedIcon, size: 18, color: entry.kind == .quitApp ? .red : .primary)
                .frame(width: DS.Sizing.fieldHeight, height: DS.Sizing.fieldHeight)
                .dsFieldChrome(isHovered: false)
        }
        .buttonStyle(DSPlainButtonStyle())
        .iconOnlyHelp(localizer.text(.changeIcon))
        .popover(isPresented: Binding(
            get: { iconPickerEntryId == entry.id },
            set: { if !$0 { iconPickerEntryId = nil } }
        )) {
            IconPickerView(selectedIcon: Binding(
                get: { entry.resolvedIcon },
                set: { newIcon in
                    updateEntries { list in
                        guard let i = list.firstIndex(where: { $0.id == entry.id }) else { return }
                        list[i].icon = newIcon
                    }
                }
            ))
            .environmentObject(localizer)
        }
    }

    // MARK: - Доступные

    private var availableColumn: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            HStack(spacing: DS.Spacing.s) {
                ModernTextField(localizer.text(.subMenuSearchPlaceholder), text: $searchText)
                    .frame(height: DS.Sizing.fieldHeight)
                Button {
                    catalog.load(bundleIdentifier: bundleIdentifier)
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(DS.Typography.control)
                        .foregroundStyle(.secondary)
                        .frame(width: DS.Sizing.fieldHeight, height: DS.Sizing.fieldHeight)
                        .dsFieldChrome(isHovered: false)
                }
                .buttonStyle(DSPlainButtonStyle())
                .iconOnlyHelp(localizer.text(.subMenuReload))
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    let builtIns = filteredBuiltIns
                    if !builtIns.isEmpty {
                        sectionHeader(localizer.text(.subMenuWindowAndApp))
                        ForEach(builtIns, id: \.self) { kind in
                            availableRow(
                                title: kind.title(appName: appName, language: localizer.language),
                                caption: nil,
                                icon: kind.defaultIcon,
                                shortcut: nil,
                                isAdded: entries.contains { $0.kind == kind }
                            ) {
                                updateEntries { $0.append(AppSubMenuEntry(kind: kind)) }
                            }
                        }
                    }
                    sectionHeader(localizer.text(.subMenuAppMenus))
                    catalogContent
                }
            }
        }
    }

    @ViewBuilder
    private var catalogContent: some View {
        switch catalog.state {
        case .idle, .loading:
            HStack(spacing: DS.Spacing.s) {
                ProgressView().controlSize(.small)
                Text(localizer.text(.subMenuLoading))
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)
            }
            .padding(DS.Spacing.s)
        case .noAccess:
            statusText(localizer.text(.subMenuNoAccessibility))
        case .notRunning:
            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                statusText(localizer.text(.subMenuAppNotRunning))
                Button(localizer.text(.subMenuOpenApp)) {
                    catalog.launchAndLoad(bundleIdentifier: bundleIdentifier)
                }
                .pointingHandCursor()
                .padding(.horizontal, DS.Spacing.s)
            }
        case .loaded(let items):
            let filtered = filter(items)
            if filtered.isEmpty {
                statusText(localizer.text(.subMenuNothingFound))
            } else {
                ForEach(groupedByTopMenu(filtered), id: \.title) { group in
                    Text(group.title)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, DS.Spacing.s)
                        .padding(.top, DS.Spacing.s)
                    ForEach(group.items) { item in
                        availableRow(
                            title: item.title,
                            caption: item.parentPath.isEmpty ? nil : item.parentPath.joined(separator: " › "),
                            icon: SubActionIconGuess.icon(title: item.title, shortcut: item.shortcut),
                            shortcut: item.shortcut,
                            isAdded: entries.contains { $0.kind == .menuItem && $0.menuPath == item.path }
                        ) {
                            updateEntries {
                                $0.append(AppSubMenuEntry(kind: .menuItem, menuPath: item.path, shortcut: item.shortcut))
                            }
                        }
                    }
                }
            }
        }
    }

    private func availableRow(
        title: String,
        caption: String?,
        icon: String,
        shortcut: MenuShortcut?,
        isAdded: Bool,
        add: @escaping () -> Void
    ) -> some View {
        Button(action: add) {
            HStack(spacing: DS.Spacing.s) {
                IconView(icon: icon, size: 15, color: .secondary)
                    .frame(width: 20, height: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(DS.Typography.body)
                        .lineLimit(1)
                    if let caption {
                        Text(caption)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: DS.Spacing.s)
                if let shortcut {
                    Text(shortcut.displayString)
                        .font(DS.Typography.hotkeyDisplay(size: 11))
                        .foregroundStyle(.secondary)
                }
                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle")
                    .foregroundStyle(isAdded ? Color.accentColor : Color.secondary)
            }
            .padding(.horizontal, DS.Spacing.s)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(DSPlainButtonStyle())
        .disabled(isAdded)
        .iconOnlyHelp(localizer.text(.add))
    }

    private func sectionHeader(_ title: String) -> some View {
        DSSectionHeader(title: title)
            .padding(.horizontal, DS.Spacing.s)
            .padding(.bottom, 2)
    }

    private func statusText(_ text: String) -> some View {
        Text(text)
            .font(DS.Typography.body)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(DS.Spacing.s)
    }

    // MARK: - Данные

    private var filteredBuiltIns: [AppSubMenuEntry.Kind] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return AppSubMenuEntry.Kind.builtIns }
        return AppSubMenuEntry.Kind.builtIns.filter {
            $0.title(appName: appName, language: localizer.language).localizedCaseInsensitiveContains(query)
        }
    }

    private func filter(_ items: [AppMenuCatalog.Item]) -> [AppMenuCatalog.Item] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return items }
        return items.filter { item in
            item.path.contains { $0.localizedCaseInsensitiveContains(query) }
                || (item.shortcut?.displayString.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    private struct MenuGroup {
        let title: String
        let items: [AppMenuCatalog.Item]
    }

    /// Группы по меню в строке меню, в том же порядке, что и у приложения.
    private func groupedByTopMenu(_ items: [AppMenuCatalog.Item]) -> [MenuGroup] {
        var order: [String] = []
        var byTitle: [String: [AppMenuCatalog.Item]] = [:]
        for item in items {
            let top = item.path.first ?? ""
            if byTitle[top] == nil { order.append(top) }
            byTitle[top, default: []].append(item)
        }
        return order.map { MenuGroup(title: $0, items: byTitle[$0] ?? []) }
    }

    private func title(of entry: AppSubMenuEntry) -> String {
        entry.kind == .menuItem
            ? entry.menuTitle
            : entry.kind.title(appName: appName, language: localizer.language)
    }

    private func caption(of entry: AppSubMenuEntry) -> String {
        entry.kind == .menuItem
            ? entry.menuPath.dropLast().joined(separator: " › ")
            : localizer.text(.subMenuWindowAndApp)
    }

    /// Когда число команд меняется, поворот снова встаёт в ближайшее удобное положение — как у обычных
    /// меню при удалении пункта: прежний под другое число секторов ставит их вкривь.
    private func updateEntries(_ change: (inout [AppSubMenuEntry]) -> Void) {
        guard let index = subMenuIndex else { return }
        let rotation = effectiveRotation
        var list = appSubMenus[index].entries
        let oldCount = list.count
        change(&list)
        if list.count != oldCount, !list.isEmpty {
            appSubMenus[index].rotationDegrees = PieMenu.snappedAestheticRotationDegrees(
                raw: rotation,
                sectorCount: list.count
            )
        }
        appSubMenus[index].entries = list
    }
}
