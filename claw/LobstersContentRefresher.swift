//
//  LobstersContentRefresher.swift
//  claw
//

import WidgetKit

@MainActor
final class LobstersContentRefresher {
    private var refreshTask: Task<Void, Never>?
    private var refreshRequested = false
    private let refreshLiveContent: () async -> Void

    init(refreshLiveContent: (() async -> Void)? = nil) {
        self.refreshLiveContent = refreshLiveContent ?? {
            await Self.refreshHottest()
            await Self.refreshNewest()
            await StoryFetcher.reloadLiveFetchers()
            await TagStoryFetcher.reloadLiveFetchers()
        }
    }

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

        refreshTask = Task { [weak self, refreshLiveContent] in
            await refreshLiveContent()
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
