//
//  newest.swift
//  claw
//
//  Created by Zachary Gorak on 9/11/20.
//

import Foundation
import SwiftUI

struct Story: GenericStory, Codable, Hashable, Identifiable {

    var id: String {
        return short_id
    }

    var short_id: String
    var short_id_url: String
    var created_at: String
    var title: String
    var url: String
    var score: Int
    var score_is_hidden: Bool? = nil
    var score_is_unavailable: Bool? = nil
    var flags: Int
    var comment_count: Int
    var comment_count_is_unavailable: Bool? = nil
    var description: String
    var comments_url: String
    var submitter_user: String
    var user_is_author: Bool
    var tags: [String]
    var comments: [Comment]
    var comments_unavailable: Bool? = nil
    var user_upvoted: Bool = false
    var can_comment: Bool = false
    
    var sorted_comments: [CommentStructure] {
        var ans = [CommentStructure]()
        let rootComments = comments.filter { $0.parent_comment == nil }
        var subComments = comments.filter { $0.parent_comment != nil }

        func addComments(parent: CommentStructure) -> CommentStructure {
            var newParent = parent
            let children = subComments.filter { $0.parent_comment == parent.id }
            for child in children {
                let childStruct = addComments(parent: CommentStructure(comment: child))
                newParent = newParent.addChild(childStruct)
            }
            subComments.removeAll(where: { $0.parent_comment == parent.id })
            return newParent
        }

        for comment in rootComments {
            let parent = addComments(parent: CommentStructure(comment: comment))
            ans.append(parent)
        }

        return ans.sorted(by: { $0.comment.score > $1.comment.score })
    }
}

struct CommentStructure: Codable, Identifiable {
    var id: String {
        return comment.short_id
    }
    var comment: Comment
    var children: [CommentStructure] = []

    func addChild(_ child: Comment) -> Self {
        var newChildren = children
        newChildren.append(CommentStructure(comment: child))
        newChildren.sort(by: { $0.comment.score > $1.comment.score })
        return Self(comment: self.comment, children: newChildren)
    }

    func addChild(_ child: CommentStructure) -> Self {
        var newChildren = children
        newChildren.append(child)
        newChildren.sort(by: { $0.comment.score > $1.comment.score })
        return Self(comment: self.comment, children: newChildren)
    }
}

extension CommentStructure: Equatable {
    static func == (lhs: CommentStructure, rhs: CommentStructure) -> Bool {
        return lhs.id == rhs.id && rhs.children == lhs.children
    }
}

struct Comment: Codable, Hashable, Identifiable {
    var id: String {
        return short_id
    }
    var short_id: String
    var short_id_url: String
    var created_at: String
    var last_edited_at: String
    var is_deleted: Bool
    var is_moderated: Bool
    var score: Int
    var score_is_hidden: Bool? = nil
    var score_is_unavailable: Bool? = nil
    var flags: Int
    var url: String
    var comment: String
    var parent_comment: String?
    var commenting_user: String
    var user_upvoted: Bool? = nil
    var can_edit: Bool? = nil
    var can_delete: Bool? = nil
    var can_reply: Bool? = nil
    var can_vote: Bool? = nil

    var displayedScore: String {
        score_is_unavailable == true ? "—" : (score_is_hidden == true ? "~" : String(score))
    }

    static var placeholder: Comment {
        Comment(short_id: "", short_id_url: "", created_at: "2020-09-17T08:35:19.000-05:00", last_edited_at: "2020-09-17T08:35:19.000-05:00", is_deleted: false, is_moderated: false, score: Int.random(in: 3..<25), flags: 0, url: "", comment: ["Hello World!", "To be, or not to be! That is the question!"].randomElement() ?? "", commenting_user: "user")
    }
}

/// A small, allowlisted report: never include response HTML, cookies, headers,
/// URL credentials/query/fragment, or an arbitrary error's description/userInfo.
struct StoryLoadFailure: Equatable, LocalizedError {
    enum Stage: String {
        case request, storyParsing, commentsParsing
    }

    enum Kind: String {
        case rateLimited, http, network, storyMarkup, commentMarkup
        case invalidResponse, decoding, other
    }

    let kind: Kind
    let stage: Stage
    let url: String
    let occurredAt: Date
    let statusCode: Int?
    let retryAt: Date?
    let underlyingCode: Int?
    let errorType: String
    let parserReason: String?

    init(error: Error, stage: Stage, url: URL, statusCode: Int? = nil, now: Date = Date()) {
        self.stage = stage
        self.errorType = String(reflecting: type(of: error))
        self.occurredAt = now
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        components?.user = nil
        components?.password = nil
        components?.query = nil
        components?.fragment = nil
        self.url = components?.url?.absoluteString ?? "Unavailable"
        var kind: Kind = stage == .request ? .other : (stage == .commentsParsing ? .commentMarkup : .storyMarkup)
        var status = statusCode
        var retry: Date?
        var reason: String?
        var underlying: Int?
        if let error = error as? LobstersPageLoaderError {
            switch error {
            case .rateLimited(let date): kind = .rateLimited; retry = date
            case .unsuccessfulStatusCode(let code): kind = .http; status = code
            case .invalidResponse: kind = .invalidResponse
            case .cannotDecodeContent: kind = .decoding
            }
        } else if let error = error as? WebpageFetcherError {
            switch error {
            case .unsuccessfulStatusCode(let code): kind = .http; status = code
            case .invalidResponse: kind = .invalidResponse
            case .cannotDecodeContent: kind = .decoding
            }
        } else if let error = error as? StoryHTMLParserError {
            switch error {
            case .missingStory: reason = "missingStory"
            case .missingStoryID: reason = "missingStoryID"
            case .missingTitle: reason = "missingTitle"
            case .incompatibleComments: reason = "incompatibleComments"
            }
        } else {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain { kind = .network }
            underlying = nsError.code
        }
        self.kind = kind
        self.statusCode = status
        self.retryAt = retry
        self.underlyingCode = underlying
        self.parserReason = reason
    }

    var title: LocalizedStringResource {
        switch kind {
        case .rateLimited: "Lobsters Is Limiting Requests"
        case .network: "Connection Problem"
        case .http: "Lobsters Could Not Load This Story"
        case .storyMarkup, .invalidResponse, .decoding: "Story Could Not Be Read"
        case .commentMarkup: "Comments Could Not Be Read"
        case .other: "Story Could Not Be Loaded"
        }
    }

    var message: LocalizedStringResource {
        switch kind {
        case .rateLimited:
            "Lobsters has temporarily paused requests. Wait until the time below, then pull to refresh."
        case .network:
            "Claw could not connect to Lobsters. Check your connection, then pull to refresh."
        case .http:
            "Lobsters returned an error for this story. Try again later. If it keeps happening, include the error details in a bug report."
        case .storyMarkup, .commentMarkup, .invalidResponse, .decoding:
            "Claw could not read the page returned by Lobsters. If refreshing does not help, copy the error details and include them in a bug report."
        case .other:
            "Claw could not finish loading this story. Try refreshing. If it keeps happening, include the error details in a bug report."
        }
    }

    var errorDescription: String? {
        var paragraphs = [String(localized: title), String(localized: message)]
        if let retryAt {
            paragraphs.append(String(localized: "Try again after \(retryAt.formatted(date: .omitted, time: .standard))."))
        }
        return paragraphs.joined(separator: "\n\n")
    }

    var report: String {
        let bundle = Bundle.main
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        var lines = [
            "Claw story error (report v1)",
            "Category: \(kind.rawValue)",
            "Stage: \(stage.rawValue)",
            "Error type: \(errorType)",
            "URL: \(url)",
            "Occurred: \(occurredAt.ISO8601Format())",
            "App: \(version) (\(build))",
            "OS: \(ProcessInfo.processInfo.operatingSystemVersionString)"
        ]
        if let statusCode { lines.append("HTTP status: \(statusCode)") }
        if kind == .rateLimited { lines.append("Rate limit: HTTP 429 or active cooldown from an earlier HTTP 429") }
        if let retryAt { lines.append("Retry after: \(retryAt.ISO8601Format())") }
        if let underlyingCode { lines.append("Underlying error code: \(underlyingCode)") }
        if let parserReason { lines.append("Parser reason: \(parserReason)") }
        return lines.joined(separator: "\n")
    }
}

@MainActor
class StoryFetcher: ObservableObject {
    private final class WeakReference {
        weak var value: StoryFetcher?

        init(_ value: StoryFetcher) {
            self.value = value
        }
    }

    @Published var story: Story? = nil
    @Published var loadFailed = false
    @Published private(set) var loadFailure: StoryLoadFailure?

    public var short_id: String? = nil
    public var pageURL: URL? = nil
    private let webpageFetcher: WebpageFetcher
    private var contentGeneration: UInt = 0

    init(
        _ short_id: String? = nil,
        webpageFetcher: WebpageFetcher = .shared
    ) {
        self.short_id = short_id
        self.webpageFetcher = webpageFetcher
        Self.liveFetchers.append(WeakReference(self))
    }

    static var cachedStories = [Story]()
    static let fetchQueue = DispatchQueue(label: "StoryFetcher")
    private static var liveFetchers = [WeakReference]()

    static func reloadLiveFetchers() async {
        liveFetchers.removeAll { $0.value == nil }
        let fetchers = liveFetchers.compactMap(\.value)
        for fetcher in fetchers {
            try? await fetcher.loadSupersedingPendingLoads()
        }
    }

    static func invalidateLiveContent() {
        cachedStories.removeAll()
        liveFetchers.removeAll { $0.value == nil }
        for fetcher in liveFetchers.compactMap(\.value) {
            fetcher.invalidateContent()
        }
    }

    private func supersedePendingLoads() {
        contentGeneration &+= 1
        isReloading = false
    }

    private func invalidateContent() {
        supersedePendingLoads()
        story = nil
        loadFailed = false
        loadFailure = nil
    }

    private func loadSupersedingPendingLoads() async throws {
        supersedePendingLoads()
        try await load()
    }

    private func isCurrentContentGeneration(_ generation: UInt) -> Bool {
        generation == contentGeneration
    }

    @Published var isReloading = false
    func reload() async throws {
        if isReloading {
            return
        }
        self.isReloading = true
        defer {
            isReloading = false
        }
        try await self.load()
    }
    
    func loadIfEmpty() async throws {
        if let _ = self.story {
            return
        }
        try await self.load()
    }

    func load() async throws {
        guard let short_id = self.short_id else {
            return
        }
        let generation = contentGeneration
        if let cachedStory = StoryFetcher.cachedStories.first(where: {$0.short_id == short_id}) {
            self.story = cachedStory
        }
        let configuredURL = APIConfiguration.shared.storyURL(shortId: short_id)
        let url: URL
        if let pageURL, APIConfiguration.shared.isLobstersURL(pageURL) {
            url = pageURL
        } else {
            url = configuredURL
        }

        var request = URLRequest(url: url)

        let isShortURL = url.pathComponents.count == 3
            && url.pathComponents[1] == "s"
            && url.pathComponents[2] == short_id
        let webpage: Webpage
        do {
            let hasCookies = try !webpageFetcher.cookies(for: url).isEmpty
            if isShortURL, !hasCookies {
                request.setValue("claw_cache_bypass=1", forHTTPHeaderField: "Cookie")
            }
            webpage = try await webpageFetcher.fetch(request)
        } catch {
            guard isCurrentContentGeneration(generation) else {
                return
            }
            loadFailure = StoryLoadFailure(error: error, stage: .request, url: url)
            loadFailed = true
            throw error
        }

        let parsedStory: Story
        do {
            parsedStory = try await StoryHTMLParser.parseOffMain(
                webpage.html,
                pageURL: webpage.url
            )
        } catch {
            guard isCurrentContentGeneration(generation) else {
                return
            }
            loadFailure = StoryLoadFailure(error: error, stage: .storyParsing,
                url: webpage.url, statusCode: webpage.response.statusCode)
            loadFailed = true
            throw error
        }
        guard isCurrentContentGeneration(generation) else {
            return
        }
        self.story = parsedStory
        loadFailure = parsedStory.comments_unavailable == true
            ? StoryLoadFailure(error: StoryHTMLParserError.incompatibleComments,
                stage: .commentsParsing, url: webpage.url, statusCode: webpage.response.statusCode)
            : nil
        loadFailed = false

        StoryFetcher.cachedStories.removeAll(where: {$0.short_id == short_id})
        StoryFetcher.cachedStories.append(parsedStory)
        if StoryFetcher.cachedStories.count > 10 {
            StoryFetcher.cachedStories.removeFirst()
        }
        
    }

}
