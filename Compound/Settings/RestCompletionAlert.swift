import AudioToolbox
import UIKit

/// Plays the rest-timer completion cue based on Profile settings.
enum RestCompletionAlert {
    static func play(sound: Bool, vibration: Bool) {
        if sound {
            // System "tweet" — short, noticeable, works without custom assets.
            AudioServicesPlaySystemSound(1016)
        }
        if vibration {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
        }
    }
}
