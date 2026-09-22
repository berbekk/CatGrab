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

/// Что можно добавить в меню команд: своё действие, как у сектора любого меню, встроенные команды
/// окна и приложения и, у набора одного приложения, пункты его строки меню. Выезжает справа
/// от превью, как инспектор сектора. Им же выбирают другую команду для сектора.
struct CommandCatalogView: View {
    enum Mode {
        /// Новый сектор.
        case add
        /// Команда для выбранного сектора: своих действий здесь нет, их выбирают в инспекторе.
        case replace
    }

    /// Приложение набора; `nil` — команды по умолчанию: только встроенные, пункты меню у каждого
    /// приложения свои.
    let bundleIdentifier: String?
    let entries: [AppSubMenuEntry]
    var mode: Mode = .add
    @ObservedObject var catalog: AppMenuCatalog
    let onAdd: (AppSubMenuEntry) -> Void
    let onClose: () -> Void

    @EnvironmentObject private var localizer: LocalizationStore
    @State private var searchText = ""

    private var appName: String {
        bundleIdentifier.map(AppSubMenuEditorView.appName(for:)) ?? localizer.text(.genericAppName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelHeader(title: localizer.text(mode == .add ? .addSector : .chooseCommand), onClose: onClose)

            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                HStack(spacing: DS.Spacing.s) {
                    ModernTextField(localizer.text(.subMenuSearchPlaceholder), text: $searchText)
                        .frame(height: DS.Sizing.fieldHeight)
                    if let bundleIdentifier {
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
                }

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        let actionTypes = filteredActionTypes
                        if mode == .add, !actionTypes.isEmpty {
                            sectionHeader(localizer.text(.customActionSection))
                            ForEach(actionTypes, id: \.self) { type in
                                availableRow(
                                    title: type.title(localizer),
                                    caption: nil,
                                    icon: Self.icon(for: type),
                                    shortcut: nil,
                                    isAdded: false
                                ) {
                                    onAdd(newActionEntry(type))
                                }
                            }
                        }
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
                                    onAdd(AppSubMenuEntry(kind: kind))
                                }
                            }
                        }
                        if bundleIdentifier != nil {
                            sectionHeader(localizer.text(.subMenuAppMenus))
                            catalogContent
                        }
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.m)
            .padding(.top, DS.Spacing.m)
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
                    if let bundleIdentifier {
                        catalog.launchAndLoad(bundleIdentifier: bundleIdentifier)
                    }
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
                            onAdd(AppSubMenuEntry(kind: .menuItem, menuPath: item.path, shortcut: item.shortcut))
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

    private var filteredActionTypes: [ItemEditorView.ActionType] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return ItemEditorView.ActionType.regular }
        return ItemEditorView.ActionType.regular.filter { $0.title(localizer).localizedCaseInsensitiveContains(query) }
    }

    private static func icon(for type: ItemEditorView.ActionType) -> String {
        switch type {
        case .appCommand: return "command"
        case .launchApp: return "square.grid.2x2"
        case .openURL: return "link"
        case .keystroke: return "keyboard"
        case .systemShortcut: return "gearshape"
        case .snippet: return "text.quote"
        }
    }

    /// Сектор со своим действием выбранного вида; остальное (какое приложение, ссылку, сочетание)
    /// задают в инспекторе, который откроется сразу.
    private func newActionEntry(_ type: ItemEditorView.ActionType) -> AppSubMenuEntry {
        let action: MenuAction
        var title = type.title(localizer)
        var icon = Self.icon(for: type)
        switch type {
        case .appCommand, .launchApp: action = .launchApp(bundleIdentifier: "")
        case .openURL: action = .openURL(url: "")
        case .keystroke: action = .keystroke(keyCode: 0, modifiers: 0)
        case .systemShortcut:
            let kind = MacOSSystemActionKind.missionControl
            action = .systemShortcut(kind)
            title = kind.displayName(language: localizer.language)
            icon = kind.defaultSFSymbol
        case .snippet: action = .snippet(text: "")
        }
        return AppSubMenuEntry(action: PieMenuItem(title: title, icon: icon, action: action))
    }

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
}
