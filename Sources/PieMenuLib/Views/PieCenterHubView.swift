import SwiftUI

struct PieCenterHubView: View {
    let diameter: CGFloat
    let isHovered: Bool
    let iconName: String
    var iconColor: Color = .white
    var tintColor: Color = DS.Colors.blueAccent
    var fillOpacityFactor: Double = 1
    var glassSettings: LiquidGlassSettings = .default
    var stableBackground: Bool = false

    private var clampedFactor: Double {
        max(0, min(1, fillOpacityFactor))
    }

    private var tintOpacity: Double {
        max(0, min(1, glassSettings.tintOpacity))
    }

    var body: some View {
        let circle = Circle()

        ZStack {
            if stableBackground {
                ZStack {
                    circle.fill(.thickMaterial)
                    circle.fill(tintColor.opacity(tintOpacity * clampedFactor))
                }
            } else if #available(macOS 26.0, *) {
                let tintAlpha = tintOpacity * clampedFactor
                let baseGlass: Glass = glassSettings.variant == .clear ? .clear : .regular
                let glass = baseGlass.tint(tintColor.opacity(tintAlpha))
                circle.fill(Color.clear).glassEffect(glass, in: circle)
            } else {
                ZStack {
                    circle.fill(.ultraThinMaterial)
                    circle.fill(tintColor.opacity(tintOpacity * clampedFactor))
                }
            }

            circle
                .strokeBorder(
                    Color.white.opacity((isHovered ? 0.4 : 0.24) * clampedFactor),
                    lineWidth: isHovered ? 1.4 : 0.7
                )
            circle
                .strokeBorder(
                    Color.black.opacity((isHovered ? 0.26 : 0.16) * clampedFactor),
                    lineWidth: isHovered ? 1.4 : 0.7
                )

            Image(systemName: iconName)
                .font(.system(size: diameter * 0.40, weight: .medium))
                .foregroundStyle(iconColor)
        }
        .frame(width: diameter, height: diameter)
        .scaleEffect(isHovered ? 1.03 : 1)
    }
}
