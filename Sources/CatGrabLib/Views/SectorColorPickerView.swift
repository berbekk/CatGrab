import SwiftUI

struct SectorColorPickerView: View {
    @Binding var selectedHex: String
    @State private var showCustomPicker = false
    @State private var customColor: Color
    @State private var hoveredIndex: Int?
    @State private var isCustomHovered = false
    @EnvironmentObject private var localizer: LocalizationStore

    private let columns = Array(repeating: GridItem(.fixed(28), spacing: 6), count: 6)

    init(selectedHex: Binding<String>) {
        _selectedHex = selectedHex
        _customColor = State(initialValue: Color(hex: selectedHex.wrappedValue) ?? .blue)
    }

    private var isCustomColor: Bool {
        !PieMenuItem.sectorPalette.contains(selectedHex)
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
            ForEach(Array(PieMenuItem.sectorPalette.enumerated()), id: \.offset) { index, hex in
                swatchButton(hex: hex, index: index)
            }
            customSwatchButton
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func swatchButton(hex: String, index: Int) -> some View {
        let isSelected = selectedHex == hex
        let isHovered = hoveredIndex == index
        let color = Color(hex: hex) ?? .gray

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedHex = hex
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(color)
                    .frame(width: 28, height: 28)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(
                                isSelected ? Color.white.opacity(0.9) : isHovered ? Color.white.opacity(0.4) : Color.white.opacity(0.15),
                                lineWidth: isSelected ? 2 : DS.Border.hairline
                            )
                    )
                    .shadow(color: isSelected ? color.opacity(0.5) : .clear, radius: 6, x: 0, y: 2)
                    .scaleEffect(isSelected ? 1.1 : isHovered ? 1.05 : 1.0)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.4), radius: 1, x: 0, y: 1)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(DSPlainButtonStyle())
        .onHover { hoveredIndex = $0 ? index : nil }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        // Плитка несёт только цвет — без метки VoiceOver слышит просто «button».
        .accessibilityLabel("\(localizer.text(.sectorColor)) \(hex)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var customSwatchButton: some View {
        ZStack {
            // Реальный контрол — почти прозрачный `ColorPicker` сверху; вся видимая заливка ниже decorative.
            // Пустой заголовок убирал и подпись VoiceOver вместе с видимым текстом — возвращаем её явно.
            ColorPicker(localizer.text(.sectorColor), selection: $customColor, supportsOpacity: false)
                .labelsHidden()
                .scaleEffect(x: 28.0 / 28, y: 28.0 / 28)
                .frame(width: 28, height: 28)
                .opacity(0.011)

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(
                    AngularGradient(
                        colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red],
                        center: .center
                    )
                )
                .frame(width: 28, height: 28)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(
                            isCustomColor ? Color.white.opacity(0.9) : isCustomHovered ? Color.white.opacity(0.4) : Color.white.opacity(0.15),
                            lineWidth: isCustomColor ? 2 : DS.Border.hairline
                        )
                )
                .scaleEffect(isCustomColor ? 1.1 : isCustomHovered ? 1.05 : 1.0)
                .overlay {
                    if isCustomColor {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.4), radius: 1, x: 0, y: 1)
                    } else {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.8))
                            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .frame(width: 28, height: 28)
        .onHover { isCustomHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isCustomHovered)
        .animation(.easeInOut(duration: 0.15), value: isCustomColor)
        .onChange(of: customColor) { newColor in
            if let hex = newColor.toHex() {
                selectedHex = hex
            }
        }
    }
}

#Preview("SectorColorPicker") {
    struct Preview: View {
        @State private var hex = "#007AFF"
        var body: some View {
            VStack(spacing: 20) {
                SectorColorPickerView(selectedHex: $hex)
                Text(hex)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .background(DS.Colors.panelTop)
            .preferredColorScheme(.dark)
        }
    }
    return Preview()
        .environmentObject(LocalizationStore(language: .english))
}
