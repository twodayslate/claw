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

struct StoryListHTMLParser {
    static func parse(_ html: String, pageURL: URL) throws -> [NewestStory] {
        let document = try SwiftSoup.parse(html, pageURL.absoluteString)
        guard let list = try document.select("ol.stories").first() else {
            throw StoryListHTMLParserError.missingStories
        }
        let elements = try list.select("li.story").array()
        return try elements.map { element in
            guard let story = try parseStory(element, pageURL: pageURL) else {
                throw StoryListHTMLParserError.incompatibleStoryMarkup
            }
            return story
        }
    }

    static func parseOffMain(_ html: String, pageURL: URL) async throws -> [NewestStory] {
        try await Task.detached(priority: .userInitiated) {
            try parse(html, pageURL: pageURL)
        }.value
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
            flags: element.hasClass("flagged") ? 1 : 0,
            comment_count: try LobstersHTMLParser.number(from: commentsElement),
            description: description,
            comments_url: commentsURL.absoluteString,
            submitter_user: fields.submitter,
            user_is_author: fields.userIsAuthor,
            tags: fields.tags
        )
    }
}
