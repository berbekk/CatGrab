import SwiftUI
import AppKit

/// Имя подменю приложения: AppKit‑поле со снятием фокуса по клику снаружи и кнопкой очистки.
struct AppMenuNameField: View {
    @Binding var text: String
    let placeholder: String
    let maxWidth: CGFloat
    var requestFocus: Binding<Bool>? = nil
    var onResignFocus: (() -> Void)? = nil
    @EnvironmentObject private var localizer: LocalizationStore

    @State private var isFocused = false

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            PlainTextFieldRepresentable(
                text: $text,
                placeholder: placeholder,
                isFocused: $isFocused,
                commitsOnBlur: false,
                requestFocus: requestFocus,
                onSubmit: {},
                onResignFocus: onResignFocus
            )
            .padding(.leading, DS.Spacing.m)
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: DS.Sizing.fieldHeight, alignment: .leading)

            if !text.isEmpty {
                FieldClearButton {
                    text = ""
                    DispatchQueue.main.async {
                        NSApp.keyWindow?.makeFirstResponder(nil)
                    }
                }
                .help(localizer.text(.reset))
                .padding(.trailing, DS.Spacing.m)
            }
        }
        .frame(minWidth: 0, maxWidth: maxWidth)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                .strokeBorder(DS.Colors.blueAccent.opacity(0.85), lineWidth: DS.Border.focus)
                .opacity(isFocused ? 1 : 0)
        )
        .animation(.easeInOut(duration: 0.12), value: isFocused)
    }
}

struct AppSiblingDeleteTrashButton: View {
    let helpText: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "trash")
                .font(.system(size: 14, weight: .medium))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(isHovered ? Color.red : Color.secondary)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
                .accessibilityHidden(true)
        }
        .buttonStyle(DSPlainButtonStyle())
        .help(helpText)
        .accessibilityLabel(Text(helpText))
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}
