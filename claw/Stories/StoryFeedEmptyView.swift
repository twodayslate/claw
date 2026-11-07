//
//  StoryFeedEmptyView.swift
//  claw
//

import SwiftUI

struct StoryFeedEmptyView: View {
    var loadFailed = false
    var body: some View {
        ContentUnavailableView {
            if loadFailed {
                Label("Stories Unavailable", systemImage: "exclamationmark.triangle")
            } else {
                Label("No Stories", systemImage: "newspaper")
            }
        } description: {
            if loadFailed {
                Text("Pull to refresh and try again.")
            } else {
                #if DEBUG
                Text("The local Lobsters test server has no stories yet.")
                #else
                Text("No stories are available in this feed.")
                #endif
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}

struct StoryFeedStatusView: View {
    let skippedStoryCount: Int
    let loadFailed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if skippedStoryCount > 0 {
                Label("Some stories could not be loaded. Pull to refresh to try again.", systemImage: "exclamationmark.triangle")
                    .accessibilityIdentifier("incomplete-story-feed")
            }
            if loadFailed {
                Label("Unable to load stories. Pull to refresh to try again.", systemImage: "arrow.clockwise")
                    .accessibilityIdentifier("story-feed-load-failed")
            }
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(skippedStoryCount > 0 || loadFailed ? 16 : 0)
    }
}
