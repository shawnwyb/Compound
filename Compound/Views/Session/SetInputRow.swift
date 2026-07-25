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
    /// Drives the circle's fill. The circle is a readout, never a control: a set
    /// is marked done by logging its reps, not by tapping.
    let completed: Bool
    /// Live sessions pull the ghost weight into the field the moment reps are
    /// typed, so logging a set at the same weight as last time is one number.
    var adoptsGhostWeight = false
    let onWeightChange: (String) -> Void
    let onRepsChange: (String) -> Void

    @State private var weightText = ""
    @State private var repsText = ""

    @Environment(\.dynamicTypeSize) private var typeSize
    /// Column widths grow with the text size instead of clipping the numbers.
    @ScaledMetric(relativeTo: .title3) private var weightWidth: CGFloat = 66
    @ScaledMetric(relativeTo: .title3) private var repsWidth: CGFloat = 58

    var body: some View {
        // Four columns stop fitting side by side at accessibility text sizes, so
        // the row stacks rather than squeezing each field down to a digit.
        let stacked = typeSize.isAccessibilitySize
        let layout = stacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 8))

        layout {
            circle

            column(label: unit.capitalized, width: stacked ? nil : weightWidth) {
                numberField(text: $weightText, ghost: ghostWeight, keyboard: .decimalPad, onChange: onWeightChange)
                    .accessibilityLabel(unit.capitalized)
            }

            column(label: "Reps", width: stacked ? nil : repsWidth) {
                numberField(text: $repsText, ghost: ghostReps, keyboard: .numberPad) { value in
                    onRepsChange(value)
                    // Assigning the text is enough — the weight field's own
                    // `onChange` carries it down to the model from there.
                    if adoptsGhostWeight,
                       let adopted = adoptedGhostWeight(reps: value, weight: weightText, ghost: ghostWeight) {
                        weightText = adopted
                    }
                }
                .accessibilityLabel("Reps")
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Notes").font(.caption).foregroundStyle(.secondary)
                // No placeholder: the "Notes" caption is directly above it, and a
                // repeated hint down fifteen set rows is just noise.
                TextField("", text: $note)
                    .font(.body)
                    .submitLabel(.done)
                    .accessibilityLabel("Set note")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
        .onAppear {
            if weightText.isEmpty { weightText = initialWeight }
            if repsText.isEmpty { repsText = initialReps }
        }
    }

    /// Done reads as a *filled* accent disc and pending as a hollow ring, so the
    /// state survives greyscale and colour-blind vision — the fill, not the hue,
    /// is what carries the meaning.
    private var circle: some View {
        Text("\(setNumber)")
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(completed ? AnyShapeStyle(.background) : AnyShapeStyle(.secondary))
            .frame(width: 30, height: 30)
            .background {
                Circle()
                    .fill(.tint)
                    .opacity(completed ? 1 : 0)
            }
            .overlay {
                Circle()
                    .strokeBorder(Color.secondary.opacity(0.5), lineWidth: 1.5)
                    .opacity(completed ? 0 : 1)
            }
            .animation(.snappy(duration: 0.2), value: completed)
            .frame(width: 44, height: 44)
            .accessibilityElement()
            .accessibilityLabel("Set \(setNumber)")
            .accessibilityValue(completed ? "Done" : "Not done")
    }

    /// A labelled field column. A nil `width` lets it take the space it needs —
    /// used by the stacked accessibility layout.
    private func column<Content: View>(
        label: String,
        width: CGFloat?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
        }
        .frame(width: width, alignment: .leading)
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

/// The weight a row should adopt when reps are typed into a set whose weight is
/// still blank: last time's number, so logging a set at the same load means
/// entering one figure instead of two.
///
/// Returns nil when there is nothing to adopt — reps cleared back to empty, a
/// weight the user has already entered (never overwrite that), or a ghost with
/// no real value behind it, which is how a bodyweight movement stays at zero.
func adoptedGhostWeight(reps: String, weight: String, ghost: String) -> String? {
    guard !reps.isEmpty, weight.isEmpty, !ghost.isEmpty, ghost != "0" else { return nil }
    return ghost
}
