//
//  StoryListHTMLParser.swift
//  claw
//

import Foundation
import SwiftSoup

enum StoryListHTMLParserError: LocalizedError, Equatable {
    case missingStories
    case incompatibleStoryMarkup

    var errorDescription: String? {
        switch self {
        case .missingStories:
            return "The Lobsters webpage did not contain a story list."
        case .incompatibleStoryMarkup:
            return "The Lobsters story list markup is not supported by this version of Claw."
        }
    }
}

struct ParsedStoryList: Sendable {
    let stories: [NewestStory]
    let skippedStoryCount: Int
}

struct StoryListHTMLParser {
    static func parse(_ html: String, pageURL: URL) throws -> ParsedStoryList {
        let document = try SwiftSoup.parse(html, pageURL.absoluteString)
        guard let list = try document.select("ol.stories").first() else {
            throw StoryListHTMLParserError.missingStories
        }
        let elements = try list.select(".story").array()
        // A changed row selector must not turn a populated feed into an empty one.
        if elements.isEmpty {
            guard try list.text().isEmpty, list.children().isEmpty() else {
                throw StoryListHTMLParserError.incompatibleStoryMarkup
            }
            return ParsedStoryList(stories: [], skippedStoryCount: 0)
        }
        var stories: [NewestStory] = []
        var skipped = 0
        var ids = Set<String>()
        for element in elements {
            do {
                guard let story = try parseStory(element, pageURL: pageURL),
                      ids.insert(story.short_id).inserted else {
                    skipped += 1
                    continue
                }
                stories.append(story)
            } catch {
                skipped += 1
            }
        }
        skipped += try unrecognizedRowCount(in: list)
        guard !stories.isEmpty else {
            throw StoryListHTMLParserError.incompatibleStoryMarkup
        }
        return ParsedStoryList(stories: stories, skippedStoryCount: skipped)
    }

    static func parseOffMain(_ html: String, pageURL: URL) async throws -> ParsedStoryList {
        try await Task.detached(priority: .userInitiated) {
            try parse(html, pageURL: pageURL)
        }.value
    }

    // Descend through layout wrappers so a malformed sibling cannot hide
    // beside a recognized row inside the same container.
    private static func unrecognizedRowCount(in container: Element) throws -> Int {
        var count = 0
        for child in container.children().array() {
            if child.hasClass("story") || child.hasClass("last_read_newest") { continue }
            if try child.select(".story").isEmpty() {
                count += 1
            } else {
                count += try unrecognizedRowCount(in: child)
            }
        }
        return count
    }

    private static func parseStory(_ element: Element, pageURL: URL) throws -> NewestStory? {
        guard let fields = try LobstersHTMLParser.storyFields(
            from: element,
            pageURL: pageURL
        ) else {
            return nil
        }
        let commentsElement = try element.select(".comments_label a, a.mobile_comments").first()
        let commentsHref = try commentsElement?.attr("href") ?? fields.storyURL.absoluteString
        let commentsURL = LobstersHTMLParser.absoluteURL(commentsHref, relativeTo: pageURL)
        let commentCount = try LobstersHTMLParser.commentCount(from: commentsElement)
        let description = try element.select("details.story_content summary").first()?.html() ?? ""
        let isSelfPost = fields.destinationURL.host == pageURL.host
            && fields.destinationURL.path.hasPrefix("/s/\(fields.shortID)")

        return NewestStory(
            short_id: fields.shortID,
            short_id_url: fields.storyURL.absoluteString,
            created_at: fields.createdAt,
            title: fields.title,
            url: isSelfPost ? "" : fields.destinationURL.absoluteString,
            score: fields.score,
            score_is_hidden: fields.scoreIsHidden,
            score_is_unavailable: fields.scoreIsUnavailable,
            flags: element.hasClass("flagged") ? 1 : 0,
            comment_count: commentCount ?? 0,
            comment_count_is_unavailable: commentCount == nil,
            description: description,
            comments_url: commentsURL.absoluteString,
            submitter_user: fields.submitter,
            user_is_author: fields.userIsAuthor,
            tags: fields.tags
        )
    }
}
