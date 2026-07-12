import Foundation

/// Pure lb ↔ kg conversion. Weights are stored in the user's currently chosen
/// unit; switching units converts every persisted `SetEntry.weight`.
enum WeightConversion {

    /// International avoirdupois pound per kilogram.
    static let poundsPerKilogram = 2.2046226218

    /// Converts `weight` from one unit system to another. Same-unit is a no-op.
    static func convert(_ weight: Double, from: UnitSystem, to: UnitSystem) -> Double {
        guard from != to else { return weight }
        switch (from, to) {
        case (.pounds, .kilograms):
            return weight / poundsPerKilogram
        case (.kilograms, .pounds):
            return weight * poundsPerKilogram
        default:
            return weight
        }
    }
}
