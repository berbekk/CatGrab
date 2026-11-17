import AppKit
import SwiftUI

/// Тёмное ли сейчас оформление macOS. Своё оформление окон приложения (`AppAppearance`) сюда
/// не влияет: кольцо «как в системе» следует за системой, а не за окном настроек.
@MainActor
final class SystemAppearanceObserver: ObservableObject {
    static let shared = SystemAppearanceObserver()

    @Published private(set) var isDark: Bool = SystemAppearanceObserver.readIsDark()

    private var observer: NSObjectProtocol?

    private init() {
        observer = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { _ in
            // Ключ обновляется чуть позже уведомления.
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    SystemAppearanceObserver.shared.isDark = SystemAppearanceObserver.readIsDark()
                }
            }
        }
    }

    nonisolated static func readIsDark() -> Bool {
        UserDefaults.standard.string(forKey: "AppleInterfaceStyle")?.caseInsensitiveCompare("dark") == .orderedSame
    }
}

extension RingPalette {
    var colorScheme: ColorScheme { isDark ? .dark : .light }

    var nsAppearance: NSAppearance? {
        NSAppearance(named: isDark ? .darkAqua : .aqua)
    }

    /// Подложка сектора, когда стекла нет (или включено «Уменьшить прозрачность»).
    var baseColor: Color { Color(hex: baseHex) ?? (isDark ? .black : .white) }

    /// Обводка сектора: два штриха поверх друг друга — светлый и тёмный, так край виден на любом фоне.
    /// Без стекла — один чёткий штрих, как у обычных окон и панелей.
    struct SectorStroke {
        let light: Color
        let dark: Color
        let width: CGFloat
    }

    func sectorStroke(emphasized: Bool, dimming: Double = 1) -> SectorStroke {
        let width = emphasized ? DS.Pie.highlightBorderWidth : (isSolid ? 1.1 : 0.7)
        switch (isSolid, isDark) {
        case (true, true):
            return SectorStroke(light: .white.opacity((emphasized ? 0.8 : 0.42) * dimming), dark: .clear, width: width)
        case (true, false):
            return SectorStroke(light: .clear, dark: .black.opacity((emphasized ? 0.85 : 0.62) * dimming), width: width)
        case (false, true):
            return SectorStroke(
                light: .white.opacity((emphasized ? DS.Pie.highlightBorderOpacity : 0.24) * dimming),
                dark: .black.opacity((emphasized ? 0.26 : 0.16) * dimming),
                width: width
            )
        case (false, false):
            return SectorStroke(
                light: .white.opacity((emphasized ? 0.9 : 0.6) * dimming),
                dark: .black.opacity((emphasized ? 0.34 : 0.14) * dimming),
                width: width
            )
        }
    }

    /// Блик у выделенного сектора: на светлом кольце белый блик не виден, там он слабый тёмный.
    var highlightGlow: Color {
        isDark ? .white.opacity(DS.Pie.highlightInnerGlowOpacity) : .black.opacity(0.05)
    }

    /// Плашка подписи под курсором — та же сторона, что и кольцо.
    var hoverLabelFill: Color { isDark ? .black.opacity(0.66) : .white.opacity(0.94) }
    var hoverLabelStroke: Color { isDark ? .white.opacity(0.18) : .black.opacity(0.16) }
    var hoverLabelTitle: Color { isDark ? .white : Color(hex: Self.darkInkHex) ?? .black }
    var hoverLabelDetail: Color { isDark ? .white.opacity(0.55) : .black.opacity(0.5) }
    var destructiveText: Color { isDark ? DS.Pie.destructiveSubSectorIcon : Color(red: 0.8, green: 0.16, blue: 0.12) }

    /// Цвет значка или цифры, который читается на секторе цвета `sectorHex` при насыщенности `alpha`.
    func readableColor(_ hex: String, sectorHex: String, alpha: Double) -> Color {
        let fixed = readable(hex, on: self.sectorHex(tint: sectorHex, alpha: alpha))
        return Color(hex: fixed) ?? .white
    }
}

private struct RingPaletteKey: EnvironmentKey {
    static let defaultValue = RingPalette(isDark: true, isSolid: false)
}

extension EnvironmentValues {
    /// Сторона и материал кольца — для секторов, подписи и заливки внутри него.
    var ringPalette: RingPalette {
        get { self[RingPaletteKey.self] }
        set { self[RingPaletteKey.self] = newValue }
    }
}

extension View {
    /// Кольцо целиком рисуется в своей стороне, независимо от окна, в котором оно лежит.
    func ringPalette(_ palette: RingPalette) -> some View {
        environment(\.ringPalette, palette)
            .environment(\.colorScheme, palette.colorScheme)
    }
}
