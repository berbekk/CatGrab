import SwiftUI

/// Превью меню команд с правкой — так же, как у обычных меню: клик по сектору открывает тот же
/// инспектор, клик по коту в центре — список, что добавить. Оба выезжают слева, как «Параметры».
/// Сектор может быть командой приложения или любым действием обычного меню.
/// Им правят и набор одного приложения, и команды по умолчанию меню «Команды приложения».
struct CommandSetEditorPane: View {
    /// Меню команд; команды набора — в `appCommandsDefaultEntries`.
    @Binding var menu: PieMenu
    /// Приложение набора; `nil` — команды по умолчанию для приложений без своего набора.
    let bundleIdentifier: String?
    var hapticFeedbackEnabled: Bool
    /// Панель «Параметры» выезжает туда же, куда инспектор: открытие одного закрывает другое.
    @Binding var showAppearancePanel: Bool

    @EnvironmentObject private var localizer: LocalizationStore
    @StateObject private var catalog = AppMenuCatalog()
    @State private var selectedEntryId: UUID?
    /// Открыт список: добавить сектор или выбрать команду для выбранного.
    @State private var catalogMode: CommandCatalogView.Mode?

    /// Последнюю команду не убрать: пустое кольцо не откроется вовсе.
    private static let minEntryCount = 1

    private var entries: [AppSubMenuEntry] {
        menu.appCommandsDefaultEntries
    }

    private var selectedIndex: Int? {
        selectedEntryId.flatMap { id in entries.firstIndex { $0.id == id } }
    }

    private var appName: String {
        bundleIdentifier.map(AppSubMenuEditorView.appName(for:)) ?? localizer.text(.genericAppName)
    }

    var body: some View {
        Group {
            if entries.isEmpty {
                // Кольца нет — нет и кота, поэтому здесь кнопка.
                VStack(spacing: DS.Spacing.m) {
                    Text(localizer.text(.subMenuChosenEmpty))
                        .font(DS.Typography.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button(action: openCatalog) {
                        Label(localizer.text(.addSector), systemImage: "plus")
                    }
                    .buttonStyle(DSFieldButtonStyle())
                }
            } else {
                MenuPreviewView(
                    menu: $menu,
                    selectedItemId: $selectedEntryId,
                    hapticFeedbackEnabled: hapticFeedbackEnabled,
                    isAppearancePanelVisible: showAppearancePanel,
                    onAddItem: openCatalog,
                    appSetBundleId: bundleIdentifier
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sideDrawer(drawer)
        .onAppear {
            if let bundleIdentifier {
                catalog.load(bundleIdentifier: bundleIdentifier)
            }
            if entries.isEmpty {
                catalogMode = .add
            }
        }
        .onChange(of: selectedEntryId) { id in
            if id != nil {
                catalogMode = nil
                showAppearancePanel = false
            }
        }
        .onChange(of: catalogMode) { mode in
            if mode != nil { showAppearancePanel = false }
        }
        .onChange(of: showAppearancePanel) { visible in
            if visible { closeDrawer() }
        }
    }

    /// Что сейчас в левой панели: список команд или инспектор выбранного сектора.
    private var drawer: SideDrawerContent? {
        if let catalogMode {
            return SideDrawerContent(id: "catalog-\(catalogMode)", onClose: closeDrawer) {
                CommandCatalogView(
                    bundleIdentifier: bundleIdentifier,
                    entries: entries,
                    mode: catalogMode,
                    catalog: catalog,
                    onAdd: { catalogMode == .add ? addEntry($0) : replaceSelectedCommand(with: $0) },
                    onClose: { self.catalogMode = nil }
                )
            }
        }
        guard let index = selectedIndex else { return nil }
        let entry = entries[index]
        return SideDrawerContent(id: entry.id, onClose: closeDrawer) {
            ItemEditorView(
                item: Binding(
                    get: {
                        let current = entryWithID(entry.id) ?? entry
                        return current.asMenuItem(
                            title: current.displayTitle(appName: appName, language: localizer.language),
                            themeColor: themeColor(at: index),
                            sectorIndex: index
                        )
                    },
                    set: { item in updateEntry(id: entry.id) { $0.apply(item) } }
                ),
                themeColor: themeColor(at: index),
                themeColors: menu.colorScheme.sampleColors,
                iconThemeColor: menu.iconStyle == .white ? "#FFFFFF" : entry.color ?? themeColor(at: index),
                appCommand: .init(
                    command: entry.kind == .action ? nil : summary(of: entry),
                    choose: { catalogMode = .replace }
                ),
                onClose: closeDrawer,
                onDelete: { removeEntry(id: entry.id) }
            )
        }
    }

    private func summary(of entry: AppSubMenuEntry) -> ItemEditorView.AppCommandSlot.Summary {
        let isMenuItem = entry.kind == .menuItem
        return .init(
            title: entry.displayTitle(appName: appName, language: localizer.language),
            caption: isMenuItem
                ? entry.menuPath.dropLast().joined(separator: " › ")
                : localizer.text(.subMenuWindowAndApp),
            shortcut: entry.shortcut?.displayString,
            isMissing: isMenuItem && catalog.contains(path: entry.menuPath, shortcut: entry.shortcut) == false
        )
    }

    private func entryWithID(_ id: UUID) -> AppSubMenuEntry? {
        menu.appCommandsDefaultEntries.first { $0.id == id }
    }

    private func updateEntry(id: UUID, _ change: (inout AppSubMenuEntry) -> Void) {
        guard let i = menu.appCommandsDefaultEntries.firstIndex(where: { $0.id == id }) else { return }
        change(&menu.appCommandsDefaultEntries[i])
    }

    /// Цвет темы на месте сектора — как его раскрасит кольцо.
    private func themeColor(at index: Int) -> String {
        menu.colorScheme.color(at: index, count: entries.count)
    }

    private func openCatalog() {
        selectedEntryId = nil
        catalogMode = .add
    }

    private func closeDrawer() {
        selectedEntryId = nil
        catalogMode = nil
    }

    /// После команды список остаётся открытым — так удобно добавить несколько подряд. Своё действие
    /// сразу открывается в инспекторе: там выбирают приложение, ссылку или сочетание.
    private func addEntry(_ entry: AppSubMenuEntry) {
        withoutAnimation {
            menu.appCommandsDefaultEntries.append(entry)
            menu.snapRotationToAestheticAnchor()
        }
        if entry.kind == .action {
            selectedEntryId = entry.id
            catalogMode = nil
        }
    }

    private func replaceSelectedCommand(with command: AppSubMenuEntry) {
        if let id = selectedEntryId {
            updateEntry(id: id) { $0.replaceCommand(with: command) }
        }
        catalogMode = nil
    }

    private func removeEntry(id: UUID) {
        guard entries.count > Self.minEntryCount else { return }
        withoutAnimation {
            menu.appCommandsDefaultEntries.removeAll { $0.id == id }
            menu.snapRotationToAestheticAnchor()
        }
        selectedEntryId = nil
    }
}
