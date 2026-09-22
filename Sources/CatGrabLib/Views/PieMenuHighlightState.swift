import AppKit
import SwiftUI

/// Общее состояние подсветки сектора: мышь, клавиатура (стрелки, Tab) и повторные нажатия клавиши
/// хоткея (меню запущенных приложений, режим «по клику»).
final class PieMenuHighlightState: ObservableObject {
    @Published var highlightedIndex: Int?

    func reset() {
        highlightedIndex = nil
    }

    /// Выделить сектор. Тот же сектор — ничего не делает: иначе каждое движение мыши перерисовывало бы
    /// кольцо. Лёгкий щелчок трекпада — при переходе на другой сектор, не при уходе с кольца.
    func select(_ index: Int?, hapticFeedbackEnabled: Bool) {
        guard index != highlightedIndex else { return }
        if index != nil, hapticFeedbackEnabled {
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
        }
        highlightedIndex = index
    }

    func advanceSelection(sectorCount: Int, hapticFeedbackEnabled: Bool) {
        guard sectorCount > 0 else { return }
        select(
            PieSectorLayout.cycledIndex(from: highlightedIndex, by: 1, sectorCount: sectorCount),
            hapticFeedbackEnabled: hapticFeedbackEnabled
        )
    }
}

/// Появление кольца и куда смотрит кот. Живёт в контроллере окна, потому что само дерево SwiftUI
/// не пересоздаётся между показами: `appeared` сбрасывается перед каждым показом и включается
/// с анимацией сразу после, `pointer` ставится в центр кольца, а дальше его ведёт курсор.
final class PieMenuPresentation: ObservableObject {
    @Published var appeared = false
    @Published var pointer: CGPoint = .zero
}
