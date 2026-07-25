import Foundation

/// Reading a weight back out of a text field — the Body tab's bodyweight, a
/// set's load. Shared so every weight field agrees on what counts as a number.
enum WeightText {

    /// The weight `text` means, or nil if it isn't a usable number.
    ///
    /// Accepts a comma decimal separator, and — the reason this exists rather
    /// than a bare `Double.init` — rejects the non-finite values that parses
    /// happily: "inf", "nan", and any run of digits too long for a Double
    /// (which a held-down key reaches). Those spread: charts hand CoreGraphics
    /// a NaN plot area, and the readouts that print a whole number trap on the
    /// `Int(_:)` conversion.
    static func value(_ text: String) -> Double? {
        guard let value = Double(text.replacingOccurrences(of: ",", with: ".")),
              value.isFinite
        else { return nil }
        return value
    }
}
