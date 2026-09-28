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
/// и пальцев в касании было ровно N. Смахивания и щипки (Mission Control, Launchpad) двигают пальцы,
/// поэтому как касание не засчитываются и системе не мешают.
///
/// Пальцем считается только контакт, который пролежал заметную часть касания. При касании тремя
/// пальцами трекпада часто на миг задевает четвёртый (безымянный, большой): если считать его,
/// касание тремя открывало бы меню касания четырьмя.
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
    /// Какую долю самого долгого контакта должен пролежать контакт, чтобы считаться пальцем.
    /// Задевший трекпад палец лежит обычно не больше трети касания, настоящие — больше половины.
    var minContactShare: Double = 0.4

    private struct Contact {
        let firstSeen: Double
        var lastSeen: Double
        let startX: Float
        let startY: Float
        var maxShift: Float = 0
    }

    private var startTimestamp: Double?
    private var contacts: [Int32: Contact] = [:]
    /// Какие контакты лежали в каждом кадре — чтобы найти, сколько настоящих пальцев было одновременно.
    private var frames: [[Int32]] = []
    /// Касание уже длиннее допустимого: кадры больше не копим, результат известен.
    private var tooLong = false

    init(fingerCount: Int) {
        self.fingerCount = fingerCount
    }

    /// Возвращает `true` на кадре, в котором завершилось подходящее касание.
    mutating func process(touches: [Touch], timestamp: Double) -> Bool {
        if touches.isEmpty {
            defer { reset() }
            guard let start = startTimestamp, !tooLong, timestamp - start <= maxDuration else { return false }
            return recognizedFingerCount() == fingerCount
        }

        if startTimestamp == nil {
            startTimestamp = timestamp
        }
        guard !tooLong else { return false }
        if let start = startTimestamp, timestamp - start > maxDuration {
            tooLong = true
            frames = []
            return false
        }
        for touch in touches {
            if var contact = contacts[touch.id] {
                contact.lastSeen = timestamp
                contact.maxShift = max(contact.maxShift, hypot(touch.x - contact.startX, touch.y - contact.startY))
                contacts[touch.id] = contact
            } else {
                contacts[touch.id] = Contact(firstSeen: timestamp, lastSeen: timestamp, startX: touch.x, startY: touch.y)
            }
        }
        frames.append(touches.map(\.id))
        return false
    }

    /// Сколько пальцев было в касании: наибольшее число настоящих контактов, лежавших одновременно;
    /// `nil` — какой-то настоящий палец сдвинулся (это жест, а не касание).
    private func recognizedFingerCount() -> Int? {
        let longest = contacts.values.map { $0.lastSeen - $0.firstSeen }.max() ?? 0
        let threshold = longest * minContactShare
        let fingers = Set(contacts.filter { $0.value.lastSeen - $0.value.firstSeen >= threshold }.keys)
        guard !fingers.isEmpty else { return nil }
        if contacts.contains(where: { fingers.contains($0.key) && $0.value.maxShift > maxMovement }) {
            return nil
        }
        return frames.map { $0.filter(fingers.contains).count }.max()
    }

    mutating func reset() {
        startTimestamp = nil
        contacts = [:]
        frames = []
        tooLong = false
    }
}
