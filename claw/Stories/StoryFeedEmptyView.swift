//
//  StoryFeedEmptyView.swift
//  claw
//

import SwiftUI

struct StoryFeedEmptyView: View {
    var body: some View {
        ContentUnavailableView {
            Label("No Stories", systemImage: "newspaper")
        } description: {
            #if DEBUG
            Text("The local Lobsters test server has no stories yet.")
            #else
            Text("No stories are available in this feed.")
            #endif
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}
