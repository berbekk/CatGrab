import Foundation

/// Открытие меню касанием трекпада несколькими пальцами (без нажатия и без сдвига).
/// Число пальцев хранит само меню (`PieMenu.trackpadFingerCount`) — как и свой хоткей.
enum TrackpadGesture {
    /// Три пальца — системный «Поиск и детекторы данных» (если включён), поэтому их тоже даём выбрать, но не по умолчанию.
    static let supportedFingerCounts = [3, 4, 5]

    /// 0 и неподдерживаемые значения — жест выключен.
    static func isEnabled(fingerCount: Int) -> Bool {
        supportedFingerCounts.contains(fingerCount)
    }
}

/// Распознаёт «касание N пальцами»: все пальцы опустились и поднялись быстро, почти не сдвинувшись,
/// и за всё касание их ни разу не было больше N. Смахивания и щипки (Mission Control, Launchpad)
/// двигают пальцы, поэтому как касание не засчитываются и системе не мешают.
struct TrackpadTapRecognizer {
    struct Touch {
        let id: Int32
        /// Нормализованные координаты на трекпаде, 0...1.
        let x: Float
        let y: Float
    }

    var fingerCount: Int
    /// От первого касания до отрыва последнего пальца.
    var maxDuration: Double = 0.35
    /// Максимальный сдвиг любого пальца, в долях размера трекпада.
    var maxMovement: Float = 0.04

    private var startTimestamp: Double?
    private var maxTouches = 0
    private var startPositions: [Int32: (Float, Float)] = [:]
    private var moved = false

    init(fingerCount: Int) {
        self.fingerCount = fingerCount
    }

    /// Возвращает `true` на кадре, в котором завершилось подходящее касание.
    mutating func process(touches: [Touch], timestamp: Double) -> Bool {
        if touches.isEmpty {
            defer { reset() }
            guard let start = startTimestamp else { return false }
            return maxTouches == fingerCount && !moved && timestamp - start <= maxDuration
        }

        if startTimestamp == nil {
            startTimestamp = timestamp
        }
        maxTouches = max(maxTouches, touches.count)
        for touch in touches {
            if let (sx, sy) = startPositions[touch.id] {
                if hypot(touch.x - sx, touch.y - sy) > maxMovement { moved = true }
            } else {
                startPositions[touch.id] = (touch.x, touch.y)
            }
        }
        return false
    }

    mutating func reset() {
        startTimestamp = nil
        maxTouches = 0
        startPositions = [:]
        moved = false
    }
}
