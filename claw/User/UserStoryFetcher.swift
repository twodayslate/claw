import Foundation

@MainActor
final class UserStoryFetcher: GenericArrayFetcher<NewestStory> {
    private static let storiesPerPage = 25

    let username: String
    private var canLoadMore = true
    private let pageLoader: LobstersPageLoader

    init(username: String, pageLoader: LobstersPageLoader = .shared) {
        self.username = username
        self.pageLoader = pageLoader
    }

    override func load() async throws {
        guard !isLoading else {
            return
        }

        if isLoadingMore { supersedePendingLoads() }
        let generation = captureContentGeneration()
        hasAttemptedLoad = true
        isLoading = true
        defer {
            if isCurrentContentGeneration(generation) {
                isLoading = false
            }
        }

        let stories: [NewestStory]
        do {
            stories = try await fetch(page: 1)
        } catch {
            guard isCurrentContentGeneration(generation) else {
                return
            }
            throw error
        }
        guard isCurrentContentGeneration(generation) else {
            return
        }
        hasLoadedContent = true
        items = stories
        canLoadMore = stories.count == Self.storiesPerPage
        page = 2
    }

    override func more(_ story: NewestStory? = nil) async throws {
        guard let story, items.last?.id == story.id, canLoadMore, !isLoading, !isLoadingMore else {
            return
        }

        let generation = captureContentGeneration()
        isLoadingMore = true
        defer {
            if isCurrentContentGeneration(generation) {
                isLoadingMore = false
            }
        }

        let stories: [NewestStory]
        do {
            stories = try await fetch(page: page)
        } catch {
            guard isCurrentContentGeneration(generation) else {
                return
            }
            throw error
        }
        guard isCurrentContentGeneration(generation) else {
            return
        }
        let existingIDs = Set(items.map(\.id))
        for story in stories where !existingIDs.contains(story.id) {
            items.append(story)
        }
        canLoadMore = stories.count == Self.storiesPerPage
        page += 1
    }

    private func fetch(page: Int) async throws -> [NewestStory] {
        let url = APIConfiguration.shared.userStoriesURL(
            username: username,
            page: page
        )
        let data = try await pageLoader.data(from: url)
        return try JSONDecoder().decode([NewestStory].self, from: data)
    }
}
