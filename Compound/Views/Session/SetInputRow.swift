import SwiftUI

/// The one borderless set row shared by the live session and the log editor:
/// a circled set number followed by weight / reps / notes columns. The number
/// fields start empty and show `ghostWeight`/`ghostReps` in grey until the user
/// types their own value.
struct SetInputRow: View {
    let setNumber: Int
    let unit: String
    let ghostWeight: String
    let ghostReps: String
    /// Field contents on first appearance — "" when the set has no entered value.
    let initialWeight: String
    let initialReps: String
    @Binding var note: String
    /// Drives the circle's color. When `onToggle` is nil the circle is a plain
    /// (non-tappable) indicator — used by the editor, which has no live toggle.
    let completed: Bool
    var onToggle: (() -> Void)? = nil
    let onWeightChange: (String) -> Void
    let onRepsChange: (String) -> Void

    @State private var weightText = ""
    @State private var repsText = ""

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            circle

            column(label: unit.capitalized, width: 66) {
                numberField(text: $weightText, ghost: ghostWeight, keyboard: .decimalPad, onChange: onWeightChange)
            }

            column(label: "Reps", width: 58) {
                numberField(text: $repsText, ghost: ghostReps, keyboard: .numberPad, onChange: onRepsChange)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Notes").font(.caption).foregroundStyle(.secondary)
                TextField("", text: $note).font(.body)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
        .onAppear {
            if weightText.isEmpty { weightText = initialWeight }
            if repsText.isEmpty { repsText = initialReps }
        }
    }

    @ViewBuilder private var circle: some View {
        let label = Text("\(setNumber)")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(completed ? .primary : .secondary)
            .frame(width: 30, height: 30)
            .overlay(
                Circle().strokeBorder(
                    completed ? Color.primary : Color.secondary.opacity(0.5),
                    lineWidth: 1.5
                )
            )

        if let onToggle {
            Button(action: onToggle) { label }.buttonStyle(.plain)
        } else {
            label
        }
    }

    private func column<Content: View>(
        label: String,
        width: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
        }
        .frame(width: width)
    }

    /// A borderless numeric field showing `ghost` in grey while empty. The ghost
    /// is a non-interactive hint, so leaving it untouched types nothing.
    private func numberField(
        text: Binding<String>,
        ghost: String,
        keyboard: UIKeyboardType,
        onChange: @escaping (String) -> Void
    ) -> some View {
        ZStack(alignment: .leading) {
            if text.wrappedValue.isEmpty {
                Text(ghost)
                    .foregroundStyle(.tertiary)
                    .allowsHitTesting(false)
            }
            TextField("", text: text)
                .keyboardType(keyboard)
                .onChange(of: text.wrappedValue) { _, value in onChange(value) }
        }
        .font(.title3.weight(.semibold))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Formats a numeric set value, dropping a trailing `.0` (135.0 -> "135").
func formattedSetNumber(_ value: Double) -> String {
    value == value.rounded() ? String(Int(value)) : String(value)
}

/// The grey ghost string for a value — "0" when there is nothing to hint.
func ghostSetNumber(_ value: Double) -> String {
    value == 0 ? "0" : formattedSetNumber(value)
}
