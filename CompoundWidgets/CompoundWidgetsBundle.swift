import SwiftUI
import WidgetKit

/// The extension only ships the workout Live Activity — there is no home-screen
/// widget (the Xcode template's placeholder one was removed).
@main
struct CompoundWidgetsBundle: WidgetBundle {
    var body: some Widget {
        WorkoutLiveActivity()
    }
}
