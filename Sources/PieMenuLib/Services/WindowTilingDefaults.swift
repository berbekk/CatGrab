import Foundation

/// Заготовки секторов «половины окна» для меню приложения.
/// Действия тайлинга через AX недоступны в App Sandbox — пункты создаются без действия.
enum WindowTilingDefaults {
    /// Поворот кольца по умолчанию для нового меню приложения.
    static let defaultAppMenuRotationDegrees: Double = 45

    /// Четыре половины окна (пользователь назначает доступные действия сам).
    static func halvesPieMenuItems(left: String, right: String, top: String, bottom: String) -> [PieMenuItem] {
        [
            PieMenuItem(
                title: right, icon: "rectangle.righthalf.filled",
                action: .unassigned,
                color: "#28CD41", sectorIndex: 0
            ),
            PieMenuItem(
                title: bottom, icon: "rectangle.bottomhalf.filled",
                action: .unassigned,
                color: "#5AC8FA", sectorIndex: 1
            ),
            PieMenuItem(
                title: left, icon: "rectangle.lefthalf.filled",
                action: .unassigned,
                color: "#8E8E93", sectorIndex: 2
            ),
            PieMenuItem(
                title: top, icon: "rectangle.tophalf.filled",
                action: .unassigned,
                color: "#007AFF", sectorIndex: 3
            ),
        ]
    }
}
