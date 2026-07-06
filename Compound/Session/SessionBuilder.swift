import Foundation

/// Seed values for one set at the start of a session.
struct SeededSet: Equatable {
    let reps: Int
    let weight: Double
}

/// Merges a routine's target set count with remembered values into concrete
/// seeded sets. Pure logic — unit tested.
enum SessionBuilder {

    /// The number of sets to start a session with. History wins when it exists
    /// (so mid-workout adds/deletes carry forward without touching the routine);
    /// the routine's target only seeds the very first session for an exercise.
    static func setCount(targetSets: Int, historyCount: Int) -> Int {
        historyCount > 0 ? historyCount : max(0, targetSets)
    }

    /// Produces the seeded sets for a session:
    /// - with history, one set per remembered set, copying reps/weight,
    /// - with no history, `targetSets` zeroed sets.
    static func seededSets(targetSets: Int, lastValues: [PrefilledSet]) -> [SeededSet] {
        let count = setCount(targetSets: targetSets, historyCount: lastValues.count)
        guard count > 0 else { return [] }
        return (0..<count).map { index in
            if index < lastValues.count {
                let value = lastValues[index]
                return SeededSet(reps: value.reps, weight: value.weight)
            } else {
                return SeededSet(reps: 0, weight: 0)
            }
        }
    }
}
