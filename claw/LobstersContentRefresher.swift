//
//  LobstersContentRefresher.swift
//  claw
//

import WidgetKit

@MainActor
final class LobstersContentRefresher {
    private var refreshTask: Task<Void, Never>?
    private var refreshRequested = false

    func invalidate(
        reloadWidgets: Bool = true,
        clearingLiveContent: Bool = false
    ) {
        if clearingLiveContent {
            Self.clearLiveContent()
        } else {
            StoryFetcher.cachedStories.removeAll()
            TagStoryFetcher.cachedStories.removeAll()
        }

        if reloadWidgets {
            WidgetCenter.shared.reloadAllTimelines()
        }
        guard refreshTask == nil else {
            refreshRequested = true
            return
        }

        refreshTask = Task { [weak self] in
            async let hottest: Void = Self.refreshHottest()
            async let newest: Void = Self.refreshNewest()
            async let stories: Void = StoryFetcher.reloadLiveFetchers()
            async let tags: Void = TagStoryFetcher.reloadLiveFetchers()
            _ = await (hottest, newest, stories, tags)
            guard let self else {
                return
            }
            refreshTask = nil
            if refreshRequested {
                refreshRequested = false
                invalidate(reloadWidgets: false)
            }
        }
    }

    static func clearLiveContent() {
        HottestFetcher.shared.invalidateContent()
        NewestFetcher.shared.invalidateContent()
        StoryFetcher.invalidateLiveContent()
        TagStoryFetcher.invalidateLiveContent()
    }

    private static func refreshHottest() async {
        try? await HottestFetcher.shared.loadSupersedingPendingLoads()
    }

    private static func refreshNewest() async {
        try? await NewestFetcher.shared.loadSupersedingPendingLoads()
    }
}
