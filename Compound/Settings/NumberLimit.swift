import Foundation

/// How much number a typed field will take: a budget of digits either side of
/// the decimal point, applied to the text as it is typed or pasted.
///
/// Each ceiling sits just past what the quantity can physically be, so a typo
/// is refused in the field it was made in rather than showing up later as an
/// unreadable chart. That also makes the numbers that crashed this app —
/// "inf", "nan", and runs of digits past `Double` and `Int` — unrepresentable:
/// there is no longer a way to type one.
struct NumberLimit {
    /// Digits before the decimal point, leading zeros excluded.
    let integerDigits: Int
    /// Digits after it. Zero means the field takes whole numbers only, and
    /// drops a decimal separator entirely.
    let decimalPlaces: Int

    /// Up to 9999.9. Three digits would refuse real entries — a loaded leg
    /// press or hip thrust runs past 1,000 — while 9999 still catches a
    /// fat-fingered 18000. One decimal covers bathroom scales (0.1) and
    /// fractional plates (2.5, 1.25, 0.5).
    static let weight = NumberLimit(integerDigits: 4, decimalPlaces: 1)

    /// Up to 999. Bodyweight sets of 100+ are real; no set has ever had 1,000.
    static let reps = NumberLimit(integerDigits: 3, decimalPlaces: 0)

    /// Up to 99999. Peak self-reported intakes reach ~12,000, so a 4-digit
    /// ceiling would refuse a legitimate 10,000-calorie day.
    static let calories = NumberLimit(integerDigits: 5, decimalPlaces: 0)

    /// Up to 9999 grams, against a real ceiling around 600.
    static let protein = NumberLimit(integerDigits: 4, decimalPlaces: 0)

    /// `text` reduced to what this field accepts: digits and at most one
    /// decimal separator, each side trimmed to its budget. Everything else —
    /// signs, letters, units pasted along with the number — is dropped.
    ///
    /// Feeding the result back into the field is what refuses the keystroke
    /// past the cap: the typed character simply never appears.
    func filtered(_ text: String) -> String {
        var integer = ""
        var fraction = ""
        var separator: Character?

        for character in text {
            if character.isASCII, character.isNumber {
                if separator == nil { integer.append(character) } else { fraction.append(character) }
            } else if decimalPlaces > 0, separator == nil, character == "." || character == "," {
                // Kept as typed — a comma is a decimal point on most keyboards
                // in Europe, and parsing normalizes it later.
                separator = character
            }
        }

        // A run of leading zeros isn't part of the number and must not eat the
        // budget: "00180" is 180, not 18.
        while integer.count > 1, integer.hasPrefix("0") { integer.removeFirst() }

        integer = String(integer.prefix(integerDigits))
        fraction = String(fraction.prefix(decimalPlaces))
        guard let separator else { return integer }
        return integer + String(separator) + fraction
    }

    /// A stored number as field text: rounded to the decimal budget, with no
    /// trailing ".0" on a whole number.
    ///
    /// Blank when even the rounded number is too big for the field to hold —
    /// something logged before there was a budget, or not a real number at all.
    /// Blanking beats truncating: dropping digits off 1e30 would put a
    /// completely different number in front of the user as if they'd typed it.
    /// The value on disk is left alone until they type over it.
    func text(for value: Double) -> String {
        guard value.isFinite else { return "" }
        let scale = pow(10, Double(decimalPlaces))
        let rounded = (value * scale).rounded() / scale
        let text = rounded == rounded.rounded()
            ? String(format: "%.0f", rounded)
            : String(format: "%.\(decimalPlaces)f", rounded)
        return accepting(text)
    }

    /// `text` if the field would have accepted it as typed, otherwise "".
    private func accepting(_ text: String) -> String {
        filtered(text) == text ? text : ""
    }
}
