//
//  CompoundWidgetsLiveActivity.swift
//  CompoundWidgets
//
//  Created by Shawnick Wang on 7/21/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct CompoundWidgetsAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct CompoundWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CompoundWidgetsAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension CompoundWidgetsAttributes {
    fileprivate static var preview: CompoundWidgetsAttributes {
        CompoundWidgetsAttributes(name: "World")
    }
}

extension CompoundWidgetsAttributes.ContentState {
    fileprivate static var smiley: CompoundWidgetsAttributes.ContentState {
        CompoundWidgetsAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: CompoundWidgetsAttributes.ContentState {
         CompoundWidgetsAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: CompoundWidgetsAttributes.preview) {
   CompoundWidgetsLiveActivity()
} contentStates: {
    CompoundWidgetsAttributes.ContentState.smiley
    CompoundWidgetsAttributes.ContentState.starEyes
}
