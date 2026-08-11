import Foundation

@MainActor
final class UserStoryFetcher: GenericArrayFetcher<NewestStory> {
    private static let storiesPerPage = 25

    let username: String
    private var canLoadMore = true

    init(username: String) {
        self.username = username
    }

    override func load() async throws {
        guard !isLoading else {
            return
        }

        let generation = captureContentGeneration()
        hasAttemptedLoad = true
        page = 1
        canLoadMore = true
        isLoading = true
        defer {
            if isCurrentContentGeneration(generation) {
                isLoading = false
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
        items = stories
        canLoadMore = stories.count == Self.storiesPerPage
        page += 1
    }

    override func more(_ story: NewestStory? = nil) async throws {
        guard items.last == story, canLoadMore, !isLoadingMore else {
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
        for story in stories where !items.contains(story) {
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
        let data = try await LobstersPageLoader.shared.data(from: url)
        return try JSONDecoder().decode([NewestStory].self, from: data)
    }
}
