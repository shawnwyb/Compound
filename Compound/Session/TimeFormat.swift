import Foundation

/// Clock-style formatting for timer displays. Pure — unit tested.
enum TimeFormat {

    /// Formats a second count as clock time, clamping negatives to zero:
    /// `5 -> "0:05"`, `65 -> "1:05"`, `600 -> "10:00"`, `3661 -> "1:01:01"`.
    static func clock(_ seconds: Int) -> String {
        let total = max(0, seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}
