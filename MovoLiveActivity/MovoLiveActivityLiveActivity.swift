#if DEBUG
//
//  MovoLiveActivityLiveActivity.swift
//  MovoLiveActivity
//
//  Created by Benedikt on 06.08.25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct MovoLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var emoji: String
    }
    var name: String
}

struct MovoLiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MovoLiveActivityAttributes.self) { context in
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Text("Leading") }
                DynamicIslandExpandedRegion(.trailing) { Text("Trailing") }
                DynamicIslandExpandedRegion(.bottom) { Text("Bottom \(context.state.emoji)") }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .keylineTint(.red)
        }
    }
}

extension MovoLiveActivityAttributes {
    fileprivate static var preview: MovoLiveActivityAttributes {
        MovoLiveActivityAttributes(name: "World")
    }
}

extension MovoLiveActivityAttributes.ContentState {
    fileprivate static var smiley: MovoLiveActivityAttributes.ContentState { .init(emoji: "😀") }
    fileprivate static var starEyes: MovoLiveActivityAttributes.ContentState { .init(emoji: "🤩") }
}

#Preview("Notification", as: .content, using: MovoLiveActivityAttributes.preview) {
   MovoLiveActivityLiveActivity()
} contentStates: {
    MovoLiveActivityAttributes.ContentState.smiley
    MovoLiveActivityAttributes.ContentState.starEyes
}
#endif
