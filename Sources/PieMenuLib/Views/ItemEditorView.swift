import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ItemEditorView: View {
    @Binding var item: PieMenuItem
    let isAppMenu: Bool
    var onClose: (() -> Void)? = nil
    let onDelete: () -> Void

    @State private var actionType: ActionType?
    @State private var bundleId: String
    @State private var selectedAppName: String
    @State private var urlString: String
    @State private var keystrokeKeyCode: Int
    @State private var keystrokeModifiers: Int
    @State private var systemKind: MacOSSystemActionKind
    @State private var snippetText: String
    @State private var showIconPicker = false
    @State private var isCloseHovered = false
    @State private var isIconHovered = false
    @State private var isDeleteHovered = false
    @State private var isBrowseAppHovered = false
    @State private var iconColorValue: Color
    @State private var sectorColorHex: String
    @State private var customShortcutInput: String
    @EnvironmentObject private var localizer: LocalizationStore

    enum ActionType: CaseIterable {
        case launchApp
        case openURL
        case keystroke
        case systemShortcut
        case snippet

        func title(_ localizer: LocalizationStore) -> String {
            switch self {
            case .launchApp:
                return localizer.text(.actionTypeApp)
            case .openURL:
                return localizer.text(.actionTypeUrl)
            case .keystroke:
                return localizer.text(.actionTypeKeystroke)
            case .systemShortcut:
                return localizer.text(.actionTypeSystem)
            case .snippet:
                return localizer.text(.actionTypeSnippet)
            }
        }
    }

    var availableActionTypes: [ActionType] {
        // App Sandbox: эмуляция клавиш недоступна.
        let base = ActionType.allCases.filter { $0 != .keystroke }
        if isAppMenu {
            return base.filter { $0 != .launchApp }
        }
        return base
    }

    init(item: Binding<PieMenuItem>, isAppMenu: Bool = false, onClose: (() -> Void)? = nil, onDelete: @escaping () -> Void) {
        _item = item
        self.isAppMenu = isAppMenu
        self.onClose = onClose
        self.onDelete = onDelete
        _sectorColorHex = State(initialValue: item.wrappedValue.color)
        _customShortcutInput = State(initialValue: item.wrappedValue.customShortcut ?? "")

        if let hex = item.wrappedValue.iconColor, let c = Color(hex: hex) {
            _iconColorValue = State(initialValue: c)
        } else {
            _iconColorValue = State(initialValue: Color(hex: item.wrappedValue.color) ?? .blue)
        }

        let action = item.wrappedValue.action
        switch action {
        case .unassigned:
            _actionType = State(initialValue: nil)
            _bundleId = State(initialValue: "")
            _selectedAppName = State(initialValue: "")
            _urlString = State(initialValue: "")
            _keystrokeKeyCode = State(initialValue: 0)
            _keystrokeModifiers = State(initialValue: 0)
            _systemKind = State(initialValue: .missionControl)
            _snippetText = State(initialValue: "")
        case .launchApp(let id):
            _actionType = State(initialValue: .launchApp)
            _bundleId = State(initialValue: id)
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
                _selectedAppName = State(initialValue: FileManager.default.displayName(atPath: url.path))
            } else {
                _selectedAppName = State(initialValue: item.wrappedValue.title)
            }
            _urlString = State(initialValue: "")
            _keystrokeKeyCode = State(initialValue: 0)
            _keystrokeModifiers = State(initialValue: 0)
            _systemKind = State(initialValue: .missionControl)
            _snippetText = State(initialValue: "")
        case .openURL(let url):
            _actionType = State(initialValue: .openURL)
            _bundleId = State(initialValue: "")
            _selectedAppName = State(initialValue: "")
            _urlString = State(initialValue: url)
            _keystrokeKeyCode = State(initialValue: 0)
            _keystrokeModifiers = State(initialValue: 0)
            _systemKind = State(initialValue: .missionControl)
            _snippetText = State(initialValue: "")
        case .keystroke(let code, let mods):
            _actionType = State(initialValue: .keystroke)
            _bundleId = State(initialValue: "")
            _selectedAppName = State(initialValue: "")
            _urlString = State(initialValue: "")
            _keystrokeKeyCode = State(initialValue: code)
            _keystrokeModifiers = State(initialValue: mods)
            _systemKind = State(initialValue: .missionControl)
            _snippetText = State(initialValue: "")
        case .systemShortcut(let kind):
            _actionType = State(initialValue: .systemShortcut)
            _bundleId = State(initialValue: "")
            _selectedAppName = State(initialValue: "")
            _urlString = State(initialValue: "")
            _keystrokeKeyCode = State(initialValue: 0)
            _keystrokeModifiers = State(initialValue: 0)
            _systemKind = State(initialValue: kind)
            _snippetText = State(initialValue: "")
        case .snippet(let text):
            _actionType = State(initialValue: .snippet)
            _bundleId = State(initialValue: "")
            _selectedAppName = State(initialValue: "")
            _urlString = State(initialValue: "")
            _keystrokeKeyCode = State(initialValue: 0)
            _keystrokeModifiers = State(initialValue: 0)
            _systemKind = State(initialValue: .missionControl)
            _snippetText = State(initialValue: text)
        }
    }

    private var segmentColor: Color {
        Color(hex: item.color) ?? .blue
    }

    private var resolvedIconColor: Color {
        if let hex = item.iconColor, let c = Color(hex: hex) { return c }
        return segmentColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            drawerHeader
                .padding(.horizontal, DS.Spacing.l)
                .padding(.top, DS.Spacing.l)
                .padding(.bottom, DS.Spacing.m)

            Divider()
                .background(DS.Colors.stroke)

            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.l) {
                    formField(label: localizer.text(.actionType)) {
                        actionTypePicker
                    }

                    if actionType != .launchApp {
                        formField(label: localizer.text(.icon)) {
                            HStack(spacing: DS.Spacing.m) {
                                iconButton
                                iconColorPicker
                            }
                        }
                    }

                    formField(label: actionFieldLabel) {
                        actionFields
                    }

                    formField(label: localizer.text(.sectorColor)) {
                        SectorColorPickerView(selectedHex: $sectorColorHex)
                    }

                    formField(label: localizer.text(.customShortcut)) {
                        customShortcutField
                    }
                }
                .padding(DS.Spacing.l)
            }

            Spacer(minLength: 0)

            Divider()
                .background(DS.Colors.stroke)

            deleteButton
                .padding(.horizontal, DS.Spacing.l)
                .padding(.vertical, DS.Spacing.m)
        }
        .onChange(of: actionType) { _ in updateAction() }
        .onChange(of: bundleId) { _ in updateAction() }
        .onChange(of: iconColorValue) { newColor in
            item.iconColor = newColor.toHex()
        }
        .onChange(of: sectorColorHex) { newHex in
            item.color = newHex
        }
        .onChange(of: customShortcutInput) { newValue in
            var candidate = PieMenuItem.normalizedCustomShortcut(newValue)
            if candidate == nil, let last = newValue.last {
                candidate = PieMenuItem.normalizedCustomShortcut(String(last))
            }
            let normalized = candidate ?? ""
            if normalized != newValue {
                customShortcutInput = normalized
            }
            item.customShortcut = normalized.isEmpty ? nil : normalized
        }
        .onChange(of: urlString) { newValue in
            updateAction()
            if actionType == .openURL,
               let host = extractHost(from: newValue),
               !host.isEmpty {
                FaviconDownloader.shared.fetch(domain: host) { path in
                    item.icon = "file:\(path)"
                }
            }
        }
        .onChange(of: keystrokeKeyCode) { _ in updateAction() }
        .onChange(of: keystrokeModifiers) { _ in updateAction() }
        .onChange(of: systemKind) { _ in updateAction() }
        .onChange(of: snippetText) { _ in updateAction() }
    }

    private var drawerHeader: some View {
        HStack {
            Text(localizer.text(.selectedItemParameters))
                .font(DS.Typography.bodyEmphasized)
                .foregroundStyle(.primary)
            Spacer()
            if let close = onClose {
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.primary.opacity(isCloseHovered ? 0.95 : 0.75))
                        .frame(width: DS.Sizing.closeButton, height: DS.Sizing.closeButton)
                        .background(Color.white.opacity(isCloseHovered ? 0.16 : 0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(DSPlainButtonStyle())
                .onHover { isCloseHovered = $0 }
                .animation(.easeInOut(duration: 0.1), value: isCloseHovered)
                .help(localizer.text(.close))
            }
        }
    }

    private var actionFieldLabel: String {
        guard let actionType else { return localizer.text(.parameters) }
        switch actionType {
        case .launchApp: return localizer.text(.application)
        case .openURL: return localizer.text(.actionTypeUrl)
        case .keystroke: return localizer.text(.keyCombination)
        case .systemShortcut: return localizer.text(.systemMacAction)
        case .snippet: return localizer.text(.snippetText)
        }
    }

    private var actionTypePicker: some View {
        Menu {
            Button(localizer.text(.unassigned)) { actionType = nil }
            ForEach(availableActionTypes, id: \.self) { type in
                Button(type.title(localizer)) { actionType = type }
            }
        } label: {
            HStack(spacing: DS.Spacing.s) {
                Image(systemName: "filemenu.and.cursorarrow")
                    .font(DS.Typography.label)
                    .foregroundStyle(.secondary)

                Text(actionType?.title(localizer) ?? localizer.text(.unassigned))
                    .font(DS.Typography.hotkeyDisplay())
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary.opacity(0.6))
            }
            .padding(.horizontal, DS.Spacing.fieldInsetHorizontal)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(height: DS.Sizing.fieldHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                .fill(DS.Colors.field.opacity(isActionTypeHovered ? 1.0 : 0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                .strokeBorder(
                    isActionTypeHovered ? Color.white.opacity(0.2) : DS.Colors.stroke,
                    lineWidth: DS.Border.hairline
                )
        )
        .contentShape(Rectangle())
        .onHover { isActionTypeHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isActionTypeHovered)
    }

    private func formField<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(label)
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)
            content()
        }
    }

    private var deleteButton: some View {
        Button(action: onDelete) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "trash")
                    .font(DS.Typography.label)
                Text(localizer.text(.deleteItem))
                    .font(DS.Typography.control)
            }
            .foregroundStyle(.red.opacity(isDeleteHovered ? 1.0 : 0.9))
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.s)
            .background(Color.red.opacity(isDeleteHovered ? 0.14 : 0.08))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                    .strokeBorder(Color.red.opacity(isDeleteHovered ? 0.3 : 0), lineWidth: DS.Border.hairline)
            )
        }
        .buttonStyle(DSPlainButtonStyle())
        .onHover { isDeleteHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isDeleteHovered)
    }

    private var iconButton: some View {
        Button { showIconPicker.toggle() } label: {
            IconView(
                icon: item.icon,
                size: 16,
                color: resolvedIconColor,
                appBundleId: actionType == .launchApp && !bundleId.isEmpty ? bundleId : nil
            )
            .frame(width: DS.Sizing.fieldHeight, height: DS.Sizing.fieldHeight)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                    .fill(DS.Colors.field.opacity(isIconHovered ? 1.0 : 0.8))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                    .strokeBorder(
                        isIconHovered ? Color.white.opacity(0.2) : DS.Colors.stroke,
                        lineWidth: DS.Border.hairline
                    )
            )
        }
        .buttonStyle(DSPlainButtonStyle())
        .onHover { isIconHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isIconHovered)
        .help(localizer.text(.changeIcon))
        .popover(isPresented: $showIconPicker) {
            IconPickerView(
                selectedIcon: $item.icon,
                launchAppBundleId: actionType == .launchApp && !bundleId.isEmpty ? bundleId : nil
            )
        }
    }

    @State private var isColorHovered = false
    @State private var isActionTypeHovered = false
    @State private var isSystemActionHovered = false

    private var iconColorPicker: some View {
        ColorPicker("", selection: $iconColorValue, supportsOpacity: false)
            .labelsHidden()
            .scaleEffect(x: DS.Sizing.fieldHeight / 28, y: DS.Sizing.fieldHeight / 28)
            .frame(width: DS.Sizing.fieldHeight, height: DS.Sizing.fieldHeight)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                    .fill(iconColorValue)
                    .allowsHitTesting(false)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                    .strokeBorder(
                        isColorHovered ? Color.white.opacity(0.3) : Color.black.opacity(0.3),
                        lineWidth: DS.Border.hairline
                    )
                    .allowsHitTesting(false)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous))
            .onHover { isColorHovered = $0 }
            .animation(.easeInOut(duration: 0.12), value: isColorHovered)
    }

    @ViewBuilder
    private var actionFields: some View {
        if let actionType {
            switch actionType {
            case .launchApp:
                Button(action: browseApp) {
                    HStack(spacing: DS.Spacing.s) {
                        if !bundleId.isEmpty {
                            if let nsImage = AppIconResolver.shared.icon(forBundleIdentifier: bundleId) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .frame(width: 20, height: 20)
                            } else {
                                Image(systemName: "app.fill")
                                    .font(DS.Typography.control)
                                    .foregroundStyle(.secondary.opacity(0.8))
                                    .frame(width: 20, height: 20)
                            }
                            Text(selectedAppName.isEmpty ? bundleId : selectedAppName)
                                .font(DS.Typography.bodyCompact)
                                .foregroundStyle(.primary.opacity(isBrowseAppHovered ? 0.95 : 0.9))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        } else {
                            Text(localizer.text(.chooseApplication))
                                .font(DS.Typography.body)
                                .foregroundStyle(.secondary.opacity(isBrowseAppHovered ? 0.95 : 0.75))
                            Spacer(minLength: 0)
                        }
                        Image(systemName: "chevron.right")
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary.opacity(isBrowseAppHovered ? 0.85 : 0.6))
                    }
                    .padding(.horizontal, DS.Spacing.m)
                    .frame(height: DS.Sizing.fieldHeight)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                            .fill(DS.Colors.field.opacity(isBrowseAppHovered ? 1.0 : 0.8))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                            .strokeBorder(
                                isBrowseAppHovered ? Color.white.opacity(0.2) : DS.Colors.stroke,
                                lineWidth: DS.Border.hairline
                            )
                    )
                }
                .buttonStyle(DSPlainButtonStyle())
                .onHover { isBrowseAppHovered = $0 }
                .animation(.easeInOut(duration: 0.12), value: isBrowseAppHovered)

            case .openURL:
                ModernTextField("https://...", text: $urlString, updateMode: .onBlur)

            case .keystroke:
                KeystrokeRecorderView(keyCode: $keystrokeKeyCode, modifiers: $keystrokeModifiers)
            case .systemShortcut:
                systemActionPicker
            case .snippet:
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    SnippetTextEditor(text: $snippetText, placeholder: localizer.text(.snippetPlaceholder))
                    Text(localizer.text(.snippetClipboardHint))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } else {
            Text(localizer.text(.unassigned))
                .font(DS.Typography.control)
                .foregroundStyle(.secondary.opacity(0.8))
                .padding(.horizontal, DS.Spacing.m)
                .frame(height: DS.Sizing.fieldHeight)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                        .fill(DS.Colors.field.opacity(0.8))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                        .strokeBorder(DS.Colors.stroke, lineWidth: DS.Border.hairline)
                )
        }
    }

    private func updateAction() {
        guard let actionType else {
            item.action = .unassigned
            item.icon = PieMenuItem.unassignedSFSymbol
            return
        }

        switch actionType {
        case .launchApp:
            item.action = .launchApp(bundleIdentifier: bundleId)
            if !bundleId.isEmpty {
                item.icon = "app:\(bundleId)"
                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                    item.title = FileManager.default.displayName(atPath: url.path)
                } else if !selectedAppName.isEmpty {
                    item.title = selectedAppName
                }
            }
        case .openURL:
            item.action = .openURL(url: urlString)
        case .keystroke:
            item.action = .keystroke(keyCode: keystrokeKeyCode, modifiers: keystrokeModifiers)
        case .systemShortcut:
            let kind = systemKind.isAvailableInAppStore ? systemKind : .missionControl
            systemKind = kind
            item.action = .systemShortcut(kind)
            item.title = kind.displayName(language: localizer.language)
            item.icon = kind.defaultSFSymbol
        case .snippet:
            item.action = .snippet(text: snippetText)
        }
    }

    private var systemActionPicker: some View {
        Menu {
            ForEach(MacOSSystemActionKind.appStoreCases) { kind in
                Button {
                    systemKind = kind
                } label: {
                    HStack {
                        if systemKind == kind {
                            Image(systemName: "checkmark")
                        }
                        Text(kind.displayName(language: localizer.language))
                    }
                }
            }
        } label: {
            HStack(spacing: DS.Spacing.s) {
                Image(systemName: "command.circle")
                    .font(DS.Typography.label)
                    .foregroundStyle(.secondary)
                Text(systemKind.displayName(language: localizer.language))
                    .font(DS.Typography.hotkeyDisplay())
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary.opacity(0.6))
            }
            .padding(.horizontal, DS.Spacing.fieldInsetHorizontal)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(height: DS.Sizing.fieldHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                .fill(DS.Colors.field.opacity(isSystemActionHovered ? 1.0 : 0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                .strokeBorder(
                    isSystemActionHovered ? Color.white.opacity(0.2) : DS.Colors.stroke,
                    lineWidth: DS.Border.hairline
                )
        )
        .contentShape(Rectangle())
        .onHover { isSystemActionHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isSystemActionHovered)
    }

    private var customShortcutField: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            ShortcutDigitKeyField(placeholder: "A-Z / 0-9", text: $customShortcutInput)
            Text(localizer.text(.customShortcutHint))
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func extractHost(from urlString: String) -> String? {
        var s = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if !s.contains("://") { s = "https://" + s }
        return URL(string: s)?.host
    }

    private func browseApp() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = localizer.text(.select)
        if panel.runModal() == .OK, let url = panel.url,
           let descriptor = AppDescriptorResolver.resolve(from: url) {
            bundleId = descriptor.bundleIdentifier
            selectedAppName = descriptor.displayName
            item.title = descriptor.displayName
            item.action = .launchApp(bundleIdentifier: descriptor.bundleIdentifier)
            item.icon = "app:\(descriptor.bundleIdentifier)"
        }
    }
}

private struct ItemEditorPreview: View {
    @State private var item = PieMenuItem(
        title: "Safari",
        icon: "safari",
        action: .launchApp(bundleIdentifier: "com.apple.Safari"),
        color: "#007AFF",
        sectorIndex: 0
    )
    var body: some View {
        ItemEditorView(item: $item, onDelete: {})
            .frame(width: 340, height: 500)
            .background(
                LinearGradient(
                    colors: [DS.Colors.panelTop, DS.Colors.panelBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .preferredColorScheme(.dark)
            .environmentObject(LocalizationStore(language: .russian))
    }
}

#Preview("ItemEditor") {
    ItemEditorPreview()
}
