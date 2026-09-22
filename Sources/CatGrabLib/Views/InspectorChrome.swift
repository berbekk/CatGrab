import SwiftUI

/// Инспектор сектора в левой панели окна — один для пункта обычного меню и для команды приложения:
/// шапка с крестиком, поля с прокруткой и кнопка удаления внизу.
struct InspectorPanel<Content: View>: View {
    let title: String
    var onClose: (() -> Void)?
    /// `nil` — удалить нельзя (например, последний сектор), кнопки нет.
    var onDelete: (() -> Void)?
    @ViewBuilder let content: () -> Content

    @EnvironmentObject private var localizer: LocalizationStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelHeader(title: title, onClose: onClose)

            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.l) {
                    content()
                }
                .padding(DS.Spacing.l)
            }

            Spacer(minLength: 0)

            if let onDelete {
                Rectangle()
                    .fill(DS.Colors.stroke)
                    .frame(height: DS.Border.hairline)

                InspectorDeleteButton(title: localizer.text(.deleteItem), action: onDelete)
                    .padding(.horizontal, DS.Spacing.l)
                    .padding(.vertical, DS.Spacing.m)
            }
        }
    }
}

/// Подпись над полем инспектора.
struct InspectorField<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(label)
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)
            content()
        }
    }
}

struct InspectorDeleteButton: View {
    let title: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "trash")
                    .font(DS.Typography.label)
                Text(title)
                    .font(DS.Typography.control)
            }
            .foregroundStyle(.red.opacity(isHovered ? 1.0 : 0.9))
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.s)
            .background(Color.red.opacity(isHovered ? 0.14 : 0.08))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous)
                    .strokeBorder(Color.red.opacity(isHovered ? 0.3 : 0), lineWidth: DS.Border.hairline)
            )
        }
        .buttonStyle(DSPlainButtonStyle())
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }
}

/// Своя клавиша быстрого выбора: одна буква или цифра, пусто — по позиции сектора.
struct CustomShortcutField: View {
    @Binding var value: String?
    @State private var input: String
    @EnvironmentObject private var localizer: LocalizationStore

    init(value: Binding<String?>) {
        _value = value
        _input = State(initialValue: value.wrappedValue ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            ShortcutDigitKeyField(placeholder: "A-Z / 0-9", text: $input)
            Text(localizer.text(.customShortcutHint))
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
        .onChange(of: input) { newValue in
            var candidate = PieMenuItem.normalizedCustomShortcut(newValue)
            if candidate == nil, let last = newValue.last {
                candidate = PieMenuItem.normalizedCustomShortcut(String(last))
            }
            let normalized = candidate ?? ""
            if normalized != newValue {
                input = normalized
            }
            value = normalized.isEmpty ? nil : normalized
        }
    }
}
