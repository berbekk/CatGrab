import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct IconView: View {
    let icon: String
    let size: CGFloat
    var color: Color = .primary
    var appBundleId: String?

    private var resolvedBundleId: String? {
        if icon.hasPrefix("app:"), icon.count > 4 {
            return String(icon.dropFirst(4))
        }
        return appBundleId
    }

    var body: some View {
        if let bundleId = resolvedBundleId, !bundleId.isEmpty,
           let nsImage = AppIconResolver.shared.icon(forBundleIdentifier: bundleId) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else if icon.hasPrefix("text:") {
            let label = String(icon.dropFirst(5))
            Text(label)
                .font(.system(size: max(size * DS.PieIconVisualScale.textFontToCell, 9), weight: .semibold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(width: size, height: size)
        } else if icon.hasPrefix("file:"), icon.count > 5 {
            let path = String(icon.dropFirst(5))
            let faviconScale = FaviconDownloader.isFaviconCacheFilePath(path) ? DS.PieIconVisualScale.favicon : 1
            if FileManager.default.fileExists(atPath: path),
               let nsImage = NSImage(contentsOfFile: path) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * faviconScale, height: size * faviconScale)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: size * DS.PieIconVisualScale.sfSymbol))
                    .foregroundStyle(.quaternary)
            }
        } else if icon.isEmpty {
            Image(systemName: "questionmark.square.dashed")
                .font(.system(size: size * DS.PieIconVisualScale.sfSymbol))
                .foregroundStyle(.quaternary)
        } else if icon.hasPrefix("app:") || icon.hasPrefix("file:") {
            Image(systemName: "photo")
                .font(.system(size: size * DS.PieIconVisualScale.sfSymbol))
                .foregroundStyle(.quaternary)
        } else if icon.allSatisfy({ $0.isASCII }) {
            Image(systemName: icon)
                .font(.system(size: size * DS.PieIconVisualScale.sfSymbol, weight: .medium))
                .foregroundStyle(color)
        } else {
            Text(icon)
                .font(.system(size: size))
        }
    }
}

class FaviconDownloader {
    static let shared = FaviconDownloader()

    private let cacheDir: URL
    private var activeTasks: [String: URLSessionDataTask] = [:]

    private init() {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CatGrab/favicons")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        cacheDir = dir
    }

    func cachePath(for domain: String) -> String {
        cacheDir.appendingPathComponent(
            domain.replacingOccurrences(of: "/", with: "_") + ".png"
        ).path
    }

    func isCached(domain: String) -> Bool {
        FileManager.default.fileExists(atPath: cachePath(for: domain))
    }

    /// Путь к загруженному фавикону URL (не к произвольному файлу из пикера).
    static func isFaviconCacheFilePath(_ absolutePath: String) -> Bool {
        absolutePath.contains("/CatGrab/favicons/")
    }

    func fetch(domain: String, completion: @escaping (String) -> Void) {
        guard !domain.isEmpty else { return }
        let path = cachePath(for: domain)
        if FileManager.default.fileExists(atPath: path) {
            completion(path)
            return
        }

        activeTasks[domain]?.cancel()

        let sources = [
            "https://www.google.com/s2/favicons?domain=\(domain)&sz=64",
            "https://icons.duckduckgo.com/ip3/\(domain).ico",
            "https://\(domain)/favicon.ico"
        ]
        tryLoad(domain: domain, sources: sources, index: 0, savePath: path, completion: completion)
    }

    private func tryLoad(domain: String,
                         sources: [String],
                         index: Int,
                         savePath: String,
                         completion: @escaping (String) -> Void) {
        guard index < sources.count, let url = URL(string: sources[index]) else { return }
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let data = data, error == nil,
               let http = response as? HTTPURLResponse, http.statusCode == 200,
               let nsImage = NSImage(data: data), nsImage.isValid,
               nsImage.size.width > 1 {
                if let tiff = nsImage.tiffRepresentation,
                   let rep = NSBitmapImageRep(data: tiff),
                   let png = rep.representation(using: .png, properties: [:]) {
                    try? png.write(to: URL(fileURLWithPath: savePath))
                }
                DispatchQueue.main.async {
                    self?.activeTasks.removeValue(forKey: domain)
                    completion(savePath)
                }
            } else {
                self?.tryLoad(domain: domain, sources: sources, index: index + 1,
                              savePath: savePath, completion: completion)
            }
        }
        activeTasks[domain] = task
        task.resume()
    }
}

struct IconPickerView: View {
    @Binding var selectedIcon: String
    var launchAppBundleId: String?
    @EnvironmentObject private var localizer: LocalizationStore
    @State private var mode = 2
    @State private var searchText = ""
    @State private var emojiInput = ""
    @State private var textInput = ""
    @State private var emojiCategoryIndex = 0
    @State private var sfCategoryIndex: Int?
    @FocusState private var isEmojiInputFocused: Bool
    @FocusState private var isSearchFocused: Bool

    private enum Tab: Int, CaseIterable {
        case sfSymbols = 0
        case emoji = 1
        case app = 2
        case file = 3
        case text = 4

        var icon: String {
            switch self {
            case .sfSymbols: return "star.circle"
            case .emoji: return "face.smiling"
            case .app: return "app.badge"
            case .file: return "doc.badge.plus"
            case .text: return "textformat"
            }
        }

        func label(_ localizer: LocalizationStore) -> String {
            switch self {
            case .sfSymbols: return localizer.text(.tabSFSymbols)
            case .emoji: return localizer.text(.tabEmoji)
            case .app: return localizer.text(.tabApplication)
            case .file: return localizer.text(.tabFromFile)
            case .text: return localizer.text(.tabText)
            }
        }
    }

    private var currentTab: Tab { Tab(rawValue: mode) ?? .sfSymbols }

    private var availableSymbolCategories: [(name: String, icon: String, icons: [String])] {
        SFSymbolCatalog.categories.map { (name: $0.name, icon: $0.icon, icons: $0.symbols) }
    }

    var body: some View {
        VStack(spacing: 0) {
            iconPreviewHeader
            Divider().opacity(0.5)
            tabBar
            Divider().opacity(0.5)

            switch currentTab {
            case .sfSymbols: sfSymbolsContent
            case .emoji: emojiContent
            case .app: appIconContent
            case .file: fileIconContent
            case .text: textContent
            }
        }
        .frame(width: DS.Sizing.iconPickerSize.width, height: DS.Sizing.iconPickerSize.height)
    }

    // MARK: - Preview Header

    private var iconPreviewHeader: some View {
        HStack(spacing: DS.Spacing.m) {
            IconView(
                icon: selectedIcon,
                size: 28,
                color: .primary,
                appBundleId: launchAppBundleId
            )
            .frame(width: 40, height: 40)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous)
                    .fill(DS.Colors.elevatedFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous)
                    .strokeBorder(DS.Colors.stroke, lineWidth: DS.Border.hairline)
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(localizer.text(.changeIcon))
                    .font(DS.Typography.bodyEmphasized)
                    .foregroundStyle(.primary)
                Text(iconDescription)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.m)
        .padding(.vertical, DS.Spacing.s)
    }

    private var iconDescription: String {
        if selectedIcon.isEmpty { return "—" }
        if selectedIcon.hasPrefix("app:") { return String(selectedIcon.dropFirst(4)) }
        if selectedIcon.hasPrefix("file:") {
            return URL(fileURLWithPath: String(selectedIcon.dropFirst(5))).lastPathComponent
        }
        if selectedIcon.hasPrefix("text:") { return "\"\(selectedIcon.dropFirst(5))\"" }
        if selectedIcon.allSatisfy({ $0.isASCII }) { return selectedIcon }
        return selectedIcon
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 2) {
            ForEach(Tab.allCases, id: \.rawValue) { tab in
                PickerTabButton(
                    icon: tab.icon,
                    label: tab.label(localizer),
                    isSelected: mode == tab.rawValue
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        mode = tab.rawValue
                    }
                }
            }
        }
        .padding(.horizontal, DS.Spacing.s)
        .padding(.vertical, 6)
    }

    // MARK: - App Icon

    @ViewBuilder
    private var appIconContent: some View {
        VStack(spacing: DS.Spacing.m) {
            if let bundleId = launchAppBundleId, !bundleId.isEmpty {
                appIconButton(bundleId: bundleId)
            }
            Button {
                browseAppForIcon()
            } label: {
                Label(localizer.text(.chooseOtherApplication), systemImage: "app.badge")
                    .font(DS.Typography.control)
                    .frame(maxWidth: .infinity)
                    .padding(DS.Spacing.fieldInsetHorizontal)
            }
            .buttonStyle(.borderedProminent)
            .pointingHandCursor()
            Spacer()
        }
        .padding(DS.Spacing.m)
    }

    private func appIconButton(bundleId: String) -> some View {
        let appIconValue = "app:\(bundleId)"
        let isSelected = selectedIcon == appIconValue
        return Button {
            selectedIcon = appIconValue
        } label: {
            HStack(spacing: DS.Spacing.s) {
                if let nsImage = AppIconResolver.shared.icon(forBundleIdentifier: bundleId) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .frame(width: 32, height: 32)
                }
                Text(localizer.text(.iconOfSelectedApplication))
                    .font(DS.Typography.bodyCompact)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(DS.Typography.footerLeadingIcon)
                        .foregroundStyle(DS.Colors.blueAccent)
                }
            }
            .padding(DS.Spacing.m)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                    .fill(isSelected ? DS.Colors.blueAccent.opacity(0.1) : DS.Colors.tertiaryFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                    .strokeBorder(isSelected ? DS.Colors.blueAccent.opacity(0.34) : .clear, lineWidth: DS.Border.emphasized)
            )
        }
        .buttonStyle(DSPlainButtonStyle())
    }

    // MARK: - File Icon

    private var fileIconContent: some View {
        VStack(spacing: DS.Spacing.m) {
            Button {
                browseFileForIcon()
            } label: {
                Label(localizer.text(.chooseIconFile), systemImage: "photo.on.rectangle.angled")
                    .font(DS.Typography.control)
                    .frame(maxWidth: .infinity)
                    .padding(DS.Spacing.fieldInsetHorizontal)
            }
            .buttonStyle(.borderedProminent)
            .pointingHandCursor()
            if selectedIcon.hasPrefix("file:") {
                HStack(spacing: DS.Spacing.s) {
                    IconView(icon: selectedIcon, size: 32)
                        .frame(width: 36, height: 36)
                        .background(.quaternary.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous))
                    Text(String(selectedIcon.dropFirst(5)))
                        .font(DS.Typography.label)
                        .lineLimit(2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(DS.Spacing.m)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                        .fill(DS.Colors.blueAccent.opacity(0.08))
                )
            }
            Spacer()
        }
        .padding(DS.Spacing.m)
    }

    private func browseAppForIcon() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = localizer.text(.select)
        if panel.runModal() == .OK, let url = panel.url, let bundle = Bundle(url: url),
           let id = bundle.bundleIdentifier {
            selectedIcon = "app:\(id)"
        }
    }

    private func browseFileForIcon() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.icns, .png, .pdf]
        if panel.runModal() == .OK, let url = panel.url {
            selectedIcon = "file:\(url.path)"
        }
    }

    // MARK: - SF Symbols

    private var sfSymbolsContent: some View {
        VStack(spacing: 0) {
            searchField

            if !searchText.isEmpty {
                symbolGrid(categories: filteredCategories)
            } else {
                sfCategoryBrowser
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(DS.Typography.label)
                .foregroundStyle(.tertiary)
            ZStack(alignment: .leading) {
                if searchText.isEmpty && !isSearchFocused {
                    Text(localizer.text(.searchSymbols))
                        .font(DS.Typography.control)
                        .foregroundStyle(.secondary.opacity(0.6))
                        .allowsHitTesting(false)
                }
                TextField("", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(DS.Typography.control)
                    .focused($isSearchFocused)
                    .stretchInputHorizontally()
            }
            .stretchInputHorizontally()
            if !searchText.isEmpty {
                FieldClearButton { searchText = "" }
            }
        }
        .padding(.horizontal, DS.Spacing.fieldInsetHorizontal)
        .padding(.vertical, DS.Spacing.fieldInsetVertical)
        .background(DS.Colors.tertiaryFill)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous))
        .padding(.horizontal, DS.Spacing.fieldInsetHorizontal)
        .padding(.vertical, DS.Spacing.s)
        .pointingHandCursor()
    }

    private var sfCategoryBrowser: some View {
        HStack(spacing: 0) {
            sfCategorySidebar
            Divider().opacity(0.5)

            if let idx = sfCategoryIndex, idx < availableSymbolCategories.count {
                let cat = availableSymbolCategories[idx]
                symbolGrid(categories: [(name: cat.name, icons: cat.icons)])
            } else {
                symbolGrid(categories: availableSymbolCategories.map { (name: $0.name, icons: $0.icons) })
            }
        }
    }

    private var sfCategorySidebar: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 2) {
                SFCategorySidebarButton(
                    icon: "square.grid.2x2",
                    isSelected: sfCategoryIndex == nil
                ) {
                    withAnimation(.easeInOut(duration: 0.12)) { sfCategoryIndex = nil }
                }
                .iconOnlyHelp("All")

                ForEach(Array(availableSymbolCategories.enumerated()), id: \.offset) { idx, cat in
                    SFCategorySidebarButton(
                        icon: cat.icon,
                        isSelected: sfCategoryIndex == idx
                    ) {
                        withAnimation(.easeInOut(duration: 0.12)) { sfCategoryIndex = idx }
                    }
                    .iconOnlyHelp(cat.name)
                }
            }
            .padding(.vertical, DS.Spacing.xs)
            .padding(.horizontal, 4)
        }
        .frame(width: 36)
    }

    private func symbolGrid(categories: [(name: String, icons: [String])]) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DS.Spacing.m) {
                ForEach(categories, id: \.name) { category in
                    VStack(alignment: .leading, spacing: DS.Spacing.s) {
                        Text(category.name)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.tertiary)
                            .textCase(.uppercase)
                            .tracking(0.4)

                        LazyVGrid(
                            columns: Array(repeating: GridItem(.fixed(DS.Sizing.pickerTile), spacing: DS.Spacing.xs), count: 8),
                            spacing: DS.Spacing.xs
                        ) {
                            ForEach(category.icons, id: \.self) { icon in
                                SymbolTileButton(icon: icon, isSelected: selectedIcon == icon) {
                                    selectedIcon = icon
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.fieldInsetHorizontal)
            .padding(.bottom, DS.Spacing.fieldInsetHorizontal)
            .padding(.top, DS.Spacing.xs)
        }
    }

    private var filteredCategories: [(name: String, icons: [String])] {
        let allCats = availableSymbolCategories.map { (name: $0.name, icons: $0.icons) }
        if searchText.isEmpty { return allCats }
        let query = searchText.lowercased()
        return allCats.compactMap { category in
            let filtered = category.icons.filter { $0.lowercased().contains(query) }
            guard !filtered.isEmpty else { return nil }
            return (name: category.name, icons: filtered)
        }
    }

    // MARK: - Emoji

    private var emojiContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                emojiCategorySidebar
                Divider().opacity(0.5)

                ScrollView {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.fixed(DS.Sizing.emojiTile), spacing: DS.Spacing.xs), count: 8),
                        spacing: DS.Spacing.xs
                    ) {
                        ForEach(currentEmojiCategory.emojis, id: \.self) { emoji in
                            EmojiTileButton(emoji: emoji, isSelected: selectedIcon == emoji) {
                                selectedIcon = emoji
                            }
                        }
                    }
                    .padding(.horizontal, DS.Spacing.fieldInsetHorizontal)
                    .padding(.bottom, DS.Spacing.fieldInsetHorizontal)
                    .padding(.top, DS.Spacing.xs)
                }
            }

            Divider().opacity(0.5)

            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "face.smiling")
                    .font(DS.Typography.label)
                    .foregroundStyle(.tertiary)
                ZStack(alignment: .leading) {
                    if emojiInput.isEmpty && !isEmojiInputFocused {
                        Text(localizer.text(.pasteEmoji))
                            .font(DS.Typography.control)
                            .foregroundStyle(.secondary.opacity(0.6))
                            .allowsHitTesting(false)
                    }
                    TextField("", text: $emojiInput)
                        .textFieldStyle(.plain)
                        .font(DS.Typography.control)
                        .focused($isEmojiInputFocused)
                        .onChange(of: emojiInput) { newValue in
                            applyEmojiFromInput(newValue)
                        }
                        .stretchInputHorizontally()
                }
                .stretchInputHorizontally()
                if !emojiInput.isEmpty {
                    FieldClearButton { emojiInput = "" }
                }
                Button {
                    openSystemEmojiPicker()
                } label: {
                    Image(systemName: "character.book.closed")
                        .font(DS.Typography.control)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(DSPlainButtonStyle())
                .iconOnlyHelp(localizer.text(.pasteEmoji))
            }
            .padding(.horizontal, DS.Spacing.fieldInsetHorizontal)
            .padding(.vertical, DS.Spacing.fieldInsetVertical)
            .pointingHandCursor()
        }
    }

    private var currentEmojiCategory: EmojiCategory {
        let cats = EmojiCatalog.categories
        guard emojiCategoryIndex < cats.count else { return cats[0] }
        return cats[emojiCategoryIndex]
    }

    private var emojiCategorySidebar: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 2) {
                ForEach(Array(EmojiCatalog.categories.enumerated()), id: \.offset) { idx, cat in
                    EmojiCategorySidebarButton(
                        emoji: cat.icon,
                        isSelected: emojiCategoryIndex == idx
                    ) {
                        withAnimation(.easeInOut(duration: 0.12)) { emojiCategoryIndex = idx }
                    }
                    .iconOnlyHelp(cat.key.capitalized)
                }
            }
            .padding(.vertical, DS.Spacing.xs)
            .padding(.horizontal, 4)
        }
        .frame(width: 36)
    }

    private func openSystemEmojiPicker() {
        DispatchQueue.main.asyncAfter(deadline: .now() + Timings.characterPaletteFocusDelay) {
            isEmojiInputFocused = true
            NSApp.orderFrontCharacterPalette(nil)
        }
    }

    private func applyEmojiFromInput(_ value: String) {
        guard let emoji = value.first(where: { !$0.isASCII }) else { return }
        selectedIcon = String(emoji)
        emojiInput = String(emoji)
    }

    // MARK: - Text

    private var textContent: some View {
        VStack(spacing: DS.Spacing.m) {
            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                Text(localizer.text(.textInsteadOfIcon))
                    .font(DS.Typography.label)
                    .foregroundStyle(.secondary)

                HStack(spacing: DS.Spacing.s) {
                    ModernTextField(localizer.text(.enterText), text: $textInput)
                        .onAppear {
                            if selectedIcon.hasPrefix("text:") {
                                textInput = String(selectedIcon.dropFirst(5))
                            }
                        }

                    Button("OK") {
                        guard !textInput.isEmpty else { return }
                        selectedIcon = "text:\(textInput)"
                    }
                    .controlSize(.small)
                    .disabled(textInput.isEmpty)
                }
            }
            .padding(.horizontal, DS.Spacing.m)
            .padding(.top, DS.Spacing.m)

            if selectedIcon.hasPrefix("text:") {
                VStack(spacing: DS.Spacing.s) {
                    Text(localizer.text(.preview))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)

                    IconView(icon: selectedIcon, size: 40, color: .primary)
                        .frame(width: 60, height: 60)
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                                .fill(DS.Colors.elevatedFill)
                        )
                }
            }

            Spacer()
        }
    }
}

// MARK: - Tile Buttons

private struct SymbolTileButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(DS.Typography.symbolTile)
                .foregroundStyle(isSelected ? DS.Colors.blueAccent : isHovered ? .primary : .secondary)
                .frame(width: DS.Sizing.pickerTile, height: DS.Sizing.pickerTile)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous)
                        .fill(
                            isSelected
                                ? DS.Colors.blueAccent.opacity(0.15)
                                : isHovered ? Color.primary.opacity(0.08) : Color.clear
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous)
                        .strokeBorder(isSelected ? DS.Colors.blueAccent.opacity(0.3) : .clear, lineWidth: DS.Border.hairline)
                )
                .scaleEffect(isHovered && !isSelected ? 1.12 : 1.0)
        }
        .buttonStyle(DSPlainButtonStyle())
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .iconOnlyHelp(icon)
    }
}

private struct EmojiTileButton: View {
    let emoji: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(emoji)
                .font(DS.Typography.emojiTile)
                .frame(width: DS.Sizing.emojiTile, height: DS.Sizing.emojiTile)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous)
                        .fill(
                            isSelected
                                ? DS.Colors.blueAccent.opacity(0.15)
                                : isHovered ? Color.primary.opacity(0.08) : Color.clear
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous)
                        .strokeBorder(isSelected ? DS.Colors.blueAccent.opacity(0.3) : .clear, lineWidth: DS.Border.hairline)
                )
                .scaleEffect(isHovered && !isSelected ? 1.15 : 1.0)
        }
        .buttonStyle(DSPlainButtonStyle())
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

private struct SFCategorySidebarButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isSelected ? DS.Colors.blueAccent : isHovered ? .primary : .secondary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous)
                        .fill(isSelected ? DS.Colors.blueAccent.opacity(0.12) : isHovered ? Color.primary.opacity(0.06) : Color.clear)
                )
        }
        .buttonStyle(DSPlainButtonStyle())
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.1), value: isHovered)
    }
}

private struct EmojiCategorySidebarButton: View {
    let emoji: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(emoji)
                .font(.system(size: 14))
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous)
                        .fill(isSelected ? DS.Colors.blueAccent.opacity(0.12) : isHovered ? Color.primary.opacity(0.06) : Color.clear)
                )
        }
        .buttonStyle(DSPlainButtonStyle())
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.1), value: isHovered)
    }
}

private struct PickerTabButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? DS.Colors.blueAccent : isHovered ? .primary : .secondary)
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(isSelected ? DS.Colors.blueAccent : isHovered ? .primary.opacity(0.7) : .secondary.opacity(0.6))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous)
                    .fill(isSelected ? DS.Colors.blueAccent.opacity(0.1) : isHovered ? Color.primary.opacity(0.04) : Color.clear)
            )
        }
        .buttonStyle(DSPlainButtonStyle())
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.1), value: isHovered)
    }
}

private struct IconPickerPreview: View {
    @State private var icon = "star.fill"
    var body: some View {
        IconPickerView(selectedIcon: $icon)
            .preferredColorScheme(.dark)
            .environmentObject(LocalizationStore(language: .russian))
    }
}

#Preview("IconPicker") {
    IconPickerPreview()
}
