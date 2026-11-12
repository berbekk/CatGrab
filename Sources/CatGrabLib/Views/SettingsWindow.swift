import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var configObserver: NSObjectProtocol?
    private var screenObserver: NSObjectProtocol?
    private var clickOutsideMonitor: Any?
    /// После первого показа окна SwiftUI назначает первым респондером первый `NSTextField` и выделяет текст — снимаем фокус один раз.
    private var clearedInitialFieldFocus = false

    deinit {
        if let clickOutsideMonitor {
            NSEvent.removeMonitor(clickOutsideMonitor)
        }
        if let configObserver {
            NotificationCenter.default.removeObserver(configObserver)
        }
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
    }

    var isVisible: Bool { window?.isVisible ?? false }

    func show() {
        if window == nil {
            createWindow()
        }
        bringToFront()
        DispatchQueue.main.async { [weak self] in
            self?.bringToFront()
        }
    }

    private func createWindow() {
        clearedInitialFieldFocus = false

        let settingsView = SettingsView()
            .environmentObject(LocalizationStore.shared)
        let hostingView = NSHostingView(rootView: settingsView)

        let preferred = NSSize(width: DS.SettingsWindow.contentWidth, height: DS.SettingsWindow.contentHeight)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: preferred),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = localizedWindowTitle()
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
        // Пустой тулбар делает заголовок выше: кнопки окна встают внутрь плавающего сайдбара
        // с теми же отступами, что в приложениях macOS с сайдбаром.
        let toolbar = NSToolbar(identifier: "CatGrabSettingsToolbar")
        toolbar.showsBaselineSeparator = false
        window.toolbar = toolbar
        window.toolbarStyle = .unifiedCompact
        window.contentView = hostingView
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.delegate = self
        window.isMovableByWindowBackground = false
        window.backgroundColor = NSColor.windowBackgroundColor
        window.center()
        if let size = ScreenshotMode.windowSize {
            window.setContentSize(size)
            window.center()
        } else {
            window.setFrameAutosaveName("SettingsWindow")
        }
        fitToScreen(window)

        self.window = window

        configObserver = NotificationCenter.default.addObserver(
            forName: .configurationDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.window?.title = self?.localizedWindowTitle() ?? ""
            }
        }

        installClickOutsideMonitor()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let window = self.window else { return }
                self.fitToScreen(window)
            }
        }
    }

    private func bringToFront() {
        guard let window else { return }
        window.deminiaturize(nil)
        fitToScreen(window)
        if ScreenshotMode.showsWithoutActivating {
            window.orderFrontRegardless()
            return
        }
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Снимает фокус с текстового поля при клике по любой области окна настроек,
    /// которая не является полем ввода. Покрывает как AppKit, так и SwiftUI `TextField`.
    private func installClickOutsideMonitor() {
        guard clickOutsideMonitor == nil else { return }
        clickOutsideMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, let window = self.window, event.window === window else { return event }
            guard let hitView = self.currentEditingHitView() else { return event }
            let pointInView = hitView.convert(event.locationInWindow, from: nil)
            if hitView.bounds.contains(pointInView) { return event }
            window.makeFirstResponder(nil)
            return event
        }
    }

    /// Возвращает область экрана, внутри которой клики не должны снимать фокус.
    /// Для AppKit полей — сам `NSTextField`; для `NSTextView` — скролл-контейнер или сам view.
    private func currentEditingHitView() -> NSView? {
        guard let responder = window?.firstResponder else { return nil }
        if let textView = responder as? NSTextView {
            if textView.isFieldEditor, let field = textView.delegate as? NSView {
                return field
            }
            return textView.enclosingScrollView ?? textView
        }
        return nil
    }

    private func fitToScreen(_ window: NSWindow) {
        guard let screen = window.screen ?? NSScreen.main ?? NSScreen.screens.first else { return }
        let minimum = NSSize(width: DS.SettingsWindow.minimumContentWidth, height: DS.SettingsWindow.minimumContentHeight)
        let fitted = SettingsWindowLayout.fittedFrame(window.frame, visibleFrame: screen.visibleFrame, minimumSize: minimum)
        window.contentMinSize = NSSize(width: min(minimum.width, fitted.width), height: min(minimum.height, fitted.height))
        if window.frame != fitted { window.setFrame(fitted, display: true) }
    }

    func windowDidChangeScreen(_ notification: Notification) {
        guard let window, notification.object as? NSWindow === window else { return }
        fitToScreen(window)
    }

    func windowDidBecomeKey(_ notification: Notification) {
        guard let w = notification.object as? NSWindow,
              w === window,
              !clearedInitialFieldFocus
        else { return }
        clearedInitialFieldFocus = true
        DispatchQueue.main.async {
            DispatchQueue.main.async {
                w.makeFirstResponder(nil)
            }
        }
    }

    /// Не закрываем окно (иначе при LSUIElement приложение часто завершается вместе с последним окном).
    /// Скрываем и возвращаемся в режим accessory — приложение остаётся в статус-баре.
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard sender === window else { return true }
        NotificationCenter.default.post(name: .settingsWillHide, object: nil)
        sender.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
        return false
    }

    private func localizedWindowTitle() -> String {
        LocalizationStore.shared.text(.settingsWindowTitle)
    }
}

extension Notification.Name {
    static let settingsWillHide = Notification.Name("CatGrab.settingsWillHide")
}
