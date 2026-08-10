//
//  StoryHTMLParser.swift
//  claw
//

import Foundation
import SwiftSoup

enum StoryHTMLParserError: LocalizedError {
    case missingStory
    case missingStoryID
    case missingTitle

    var errorDescription: String? {
        switch self {
        case .missingStory:
            return "The Lobsters page did not contain a story."
        case .missingStoryID:
            return "The Lobsters story did not have an ID."
        case .missingTitle:
            return "The Lobsters story did not have a title."
        }
    }
}

struct StoryHTMLParser {
    static func parse(_ html: String, pageURL: URL) throws -> Story {
        let document = try SwiftSoup.parse(html, pageURL.absoluteString)
        guard let storyElement = try document.select("li.story[data-shortid]").first() else {
            throw StoryHTMLParserError.missingStory
        }

        guard let fields = try LobstersHTMLParser.storyFields(
            from: storyElement,
            pageURL: pageURL
        ) else {
            throw StoryHTMLParserError.missingStoryID
        }

        let comments = try parseComments(document: document, pageURL: pageURL)
        let canonicalURL = cleanURL(pageURL)
        let description = try document.select("div.story_content div.story_text").first()?.html() ?? ""
        let isSelfPost = fields.destinationURL.host == pageURL.host
            && fields.destinationURL.path.hasPrefix("/s/\(fields.shortID)")
        let canComment = try document.select(".comment_form_container form").array().contains { form in
            let storyID = try form.select("input[name='story_id']").first()?.attr("value")
            let parentID = try form.select("input[name='parent_comment_short_id']").first()
            return storyID == fields.shortID && parentID == nil
        }

        return Story(
            short_id: fields.shortID,
            short_id_url: fields.storyURL.absoluteString,
            created_at: fields.createdAt,
            title: fields.title,
            url: isSelfPost ? "" : fields.destinationURL.absoluteString,
            score: fields.score,
            flags: 0,
            comment_count: comments.count,
            description: description,
            comments_url: canonicalURL.absoluteString,
            submitter_user: fields.submitter,
            user_is_author: fields.userIsAuthor,
            tags: fields.tags,
            comments: comments,
            user_upvoted: fields.userUpvoted,
            can_comment: canComment
        )
    }

    static func parseOffMain(_ html: String, pageURL: URL) async throws -> Story {
        try await Task.detached(priority: .userInitiated) {
            try parse(html, pageURL: pageURL)
        }.value
    }

    private static func parseComments(document: Document, pageURL: URL) throws -> [Comment] {
        try document.select("div.comment[data-shortid]").array().map { element in
            let shortID = try element.attr("data-shortid")
            let byline = try element.select("div.byline").first()
            let commentText = try element.select("div.comment_text").first()
            let statusText = try commentText?.select(".na").text().lowercased() ?? ""
            let timestampElement = try byline?.select("time").first()
            let date = try timestamp(from: timestampElement)
            let permalinkElement = try byline?.select("a[href^='/c/']").first()
            let href = try permalinkElement?.attr("href") ?? "/c/\(shortID)"
            let permalink = absoluteURL(from: href, relativeTo: pageURL)
                ?? URL(string: "/c/\(shortID)", relativeTo: pageURL)!.absoluteURL
            let scoreElement = try element.select("div.voters .upvoter").first()

            return Comment(
                short_id: shortID,
                short_id_url: permalink.absoluteString,
                created_at: date,
                last_edited_at: date,
                is_deleted: statusText.contains("deleted"),
                is_moderated: statusText.contains("moderated") || statusText.contains("moderator"),
                score: try LobstersHTMLParser.number(from: scoreElement),
                flags: element.hasClass("flagged") ? 1 : 0,
                url: permalink.absoluteString,
                comment: try commentText?.html() ?? "",
                parent_comment: try parentCommentID(for: element),
                commenting_user: try LobstersHTMLParser.username(in: byline) ?? "",
                user_upvoted: element.hasClass("upvoted"),
                can_edit: try !element.select("a.comment_editor").isEmpty(),
                can_delete: try !element.select("a.comment_deletor").isEmpty(),
                can_reply: try !element.hasClass("flagged")
                    && !element.select("a.comment_replier").isEmpty(),
                can_vote: try !element.select("button.upvoter").isEmpty()
            )
        }
    }

    private static func parentCommentID(for element: Element) throws -> String? {
        let ownID = try element.attr("data-shortid")
        var ancestor = element.parent()

        while let current = ancestor {
            if current.tagName() == "li", current.hasClass("comments_subtree") {
                for child in current.children().array()
                where child.tagName() == "div" && child.hasClass("comment") {
                    let candidate = try child.attr("data-shortid")
                    if !candidate.isEmpty, candidate != ownID {
                        return candidate
                    }
                }
            }
            ancestor = current.parent()
        }

        return nil
    }

    private static func timestamp(from element: Element?) throws -> String {
        try LobstersHTMLParser.timestamp(from: element)
    }

    private static func cleanURL(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        components.query = nil
        components.fragment = nil
        return components.url ?? url
    }

    private static func absoluteURL(from href: String, relativeTo pageURL: URL) -> URL? {
        URL(string: href, relativeTo: pageURL)?.absoluteURL
    }
}
