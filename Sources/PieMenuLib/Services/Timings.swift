import Foundation

/// Единый источник магических временных констант, чтобы не разбрасывать задержки по коду.
enum Timings {
    /// Задержка перед симуляцией keystroke после `activate()` — нужна, чтобы целевое приложение стало frontmost.
    static let focusRestorationDelay: TimeInterval = 0.15

    /// Debounce сохранения настроек после последнего редактирования.
    static let settingsSaveDebounce: TimeInterval = 0.22

    /// Повторный опрос прав после возврата из System Settings (окна онбординга/настроек).
    static let permissionsRefreshDelay: TimeInterval = 0.25

    /// Пауза между системным диалогом «Универсальный доступ» (он же добавляет приложение в список)
    /// и открытием панели Системных настроек — чтобы диалог не оказался под окном настроек.
    static let accessibilitySettingsOpenDelay: TimeInterval = 0.6

    /// Задержка перед системным диалогом доступа после показа окна онбординга,
    /// чтобы диалог появился поверх уже видимого окна.
    static let accessibilityPromptAfterOnboardingDelay: TimeInterval = 0.4

    /// Сколько ждать после запуска, прежде чем проверять, поместился ли значок в строку меню
    /// (macOS раскладывает NSStatusItem асинхронно).
    static let statusItemLayoutSettleDelay: TimeInterval = 1.0

    /// Задержка перед активацией Character Palette после фокуса текстового поля.
    static let characterPaletteFocusDelay: TimeInterval = 0.05

    /// Пауза между keyDown и keyUp синтетического события для session event tap
    /// (слишком короткая пауза иногда теряет keyUp в целевом приложении).
    static let syntheticKeystrokeSessionGapMicroseconds: useconds_t = 12_000

    /// Дебаунс повторной доставки chord-события в открытом пай-меню (HID + локальный монитор).
    static let chordAdvanceDebounce: TimeInterval = 0.018

    /// Системная задержка показа `.help()` tooltip; убираем долгое ожидание подсказок.
    static let tooltipInitialDelayMilliseconds = 500
}
