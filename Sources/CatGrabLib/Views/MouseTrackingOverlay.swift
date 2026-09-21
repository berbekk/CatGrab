import SwiftUI
import AppKit

struct MouseTrackingOverlay: NSViewRepresentable {
    let center: CGPoint
    let radius: Double
    let innerRadius: Double
    let sectorCount: Int
    let rotationDegrees: Double
    let items: [PieMenuItem]
    /// Только для меню запущенных приложений: в центральном круге подсвечивается первый сектор.
    var innerCircleHighlightsFirstSector: Bool = false
    var hapticFeedbackEnabled: Bool = true
    /// Позиция курсора в координатах того же SwiftUI-пространства, что и `center`.
    var onPointerLocationUpdate: ((CGPoint) -> Void)?
    let onHover: (Int?) -> Void
    let onSelect: (PieMenuItem) -> Void
    let onDismiss: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = MouseTrackingNSView()
        view.center = center
        view.radius = radius
        view.innerRadius = innerRadius
        view.sectorCount = sectorCount
        view.rotationDegrees = rotationDegrees
        view.items = items
        view.innerCircleHighlightsFirstSector = innerCircleHighlightsFirstSector
        view.hapticFeedbackEnabled = hapticFeedbackEnabled
        view.onPointerLocationUpdate = onPointerLocationUpdate
        view.onHover = onHover
        view.onSelect = onSelect
        view.onDismiss = onDismiss
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? MouseTrackingNSView else { return }
        view.center = center
        view.radius = radius
        view.innerRadius = innerRadius
        view.sectorCount = sectorCount
        view.rotationDegrees = rotationDegrees
        view.items = items
        view.innerCircleHighlightsFirstSector = innerCircleHighlightsFirstSector
        view.hapticFeedbackEnabled = hapticFeedbackEnabled
        view.onPointerLocationUpdate = onPointerLocationUpdate
        view.onHover = onHover
        view.onSelect = onSelect
        view.onDismiss = onDismiss
    }
}

final class MouseTrackingNSView: NSView {
    override var isFlipped: Bool { true }
    var center: CGPoint = .zero
    var radius: Double = 0
    var innerRadius: Double = centerCircleRadius
    var sectorCount: Int = 1
    var rotationDegrees: Double = 0
    var items: [PieMenuItem] = []
    var innerCircleHighlightsFirstSector = false
    var hapticFeedbackEnabled = true
    var onPointerLocationUpdate: ((CGPoint) -> Void)?
    var onHover: ((Int?) -> Void)?
    var onSelect: ((PieMenuItem) -> Void)?
    var onDismiss: (() -> Void)?
    private var trackingArea: NSTrackingArea?
    private var lastHoveredSectorIndex: Int?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
            trackingArea = nil
        }
        let options: NSTrackingArea.Options = [.activeAlways, .mouseMoved, .mouseEnteredAndExited]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        trackingArea = area
        addTrackingArea(area)
        DispatchQueue.main.async { [weak self] in
            self?.reportCurrentPointerLocation()
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            DispatchQueue.main.async { [weak self] in
                self?.reportCurrentPointerLocation()
            }
        }
    }

    private func reportCurrentPointerLocation() {
        guard let window else { return }
        let location = convert(window.mouseLocationOutsideOfEventStream, from: nil)
        onPointerLocationUpdate?(location)
    }

    override func mouseMoved(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        onPointerLocationUpdate?(location)
        let sectorIndex = hoverSectorIndex(at: location)
        if sectorIndex != lastHoveredSectorIndex {
            lastHoveredSectorIndex = sectorIndex
            if sectorIndex != nil, hapticFeedbackEnabled {
                NSHapticFeedbackManager.defaultPerformer.perform(
                    .levelChange,
                    performanceTime: .default
                )
            }
        }
        onHover?(sectorIndex)
    }

    override func mouseEntered(with event: NSEvent) {
        reportCurrentPointerLocation()
    }

    override func mouseExited(with event: NSEvent) {
        lastHoveredSectorIndex = nil
        onHover?(nil)
        onPointerLocationUpdate?(center)
    }

    override func cursorUpdate(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        if let index = sectorIndex(at: location), index < items.count {
            NSCursor.pointingHand.set()
        } else {
            NSCursor.arrow.set()
        }
    }

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        if let index = sectorIndex(at: location), index < items.count {
            onSelect?(items[index])
        } else {
            onDismiss?()
        }
    }

    private func hoverSectorIndex(at point: NSPoint) -> Int? {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let dist = sqrt(dx * dx + dy * dy)
        if dist < innerRadius {
            return innerCircleHighlightsFirstSector ? 0 : nil
        }
        let rotationRadians = rotationDegrees * .pi / 180
        let angleNorm = PieSectorLayout.normalizePointerAngle(
            atan2Angle: atan2(dy, dx),
            rotationRadians: rotationRadians
        )
        return PieSectorLayout.sectorIndex(
            angleNorm: angleNorm,
            radius: dist,
            sectorCount: sectorCount,
            innerRadius: innerRadius,
            outerRadius: radius,
            ignoreAngularGaps: true
        )
    }

    private func sectorIndex(at point: NSPoint) -> Int? {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let dist = sqrt(dx * dx + dy * dy)
        if dist < innerRadius {
            return innerCircleHighlightsFirstSector ? 0 : nil
        }
        let rotationRadians = rotationDegrees * .pi / 180
        let angleNorm = PieSectorLayout.normalizePointerAngle(
            atan2Angle: atan2(dy, dx),
            rotationRadians: rotationRadians
        )
        return PieSectorLayout.sectorIndex(
            angleNorm: angleNorm,
            radius: dist,
            sectorCount: sectorCount,
            innerRadius: innerRadius,
            outerRadius: radius,
            ignoreAngularGaps: true
        )
    }
}
