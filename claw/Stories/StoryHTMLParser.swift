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
    case incompatibleComments

    var errorDescription: String? {
        switch self {
        case .missingStory:
            return "The Lobsters page did not contain a story."
        case .missingStoryID:
            return "The Lobsters story did not have an ID."
        case .missingTitle:
            return "The Lobsters story did not have a title."
        case .incompatibleComments:
            return "Comments could not be read from this Lobsters page."
        }
    }
}

struct StoryHTMLParser {
    static func parse(_ html: String, pageURL: URL) throws -> Story {
        let document = try SwiftSoup.parse(html, pageURL.absoluteString)
        guard let storyElement = try document.select(".story[data-shortid]").first() else {
            throw StoryHTMLParserError.missingStory
        }

        guard let fields = try LobstersHTMLParser.storyFields(
            from: storyElement,
            pageURL: pageURL
        ) else {
            throw StoryHTMLParserError.missingStoryID
        }

        let comments: [Comment]
        let commentsUnavailable: Bool
        do {
            let parsed = try parseComments(document: document, pageURL: pageURL)
            let countElement = try storyElement.select(".comments_label a, a.mobile_comments").first()
            if parsed.isEmpty, let expected = try LobstersHTMLParser.commentCount(from: countElement), expected > 0 {
                throw StoryHTMLParserError.incompatibleComments
            }
            comments = parsed
            commentsUnavailable = false
        } catch {
            // Keep the story readable. Do not publish a partially reconstructed
            // comment tree with replies attached to the wrong parent.
            comments = []
            commentsUnavailable = true
        }
        let canonicalURL = cleanURL(pageURL)
        let description = try document.select(".story_content .story_text").first()?.html() ?? ""
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
            score_is_hidden: fields.scoreIsHidden,
            score_is_unavailable: fields.scoreIsUnavailable,
            flags: 0,
            comment_count: comments.count,
            comment_count_is_unavailable: commentsUnavailable,
            description: description,
            comments_url: canonicalURL.absoluteString,
            submitter_user: fields.submitter,
            user_is_author: fields.userIsAuthor,
            tags: fields.tags,
            comments: comments,
            comments_unavailable: commentsUnavailable,
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
        try validateCommentMarkup(in: document)
        var ids = Set<String>()
        let elements = try document.select(".comments .comment").array().filter { element in
            var ancestor = element.parent()
            while let node = ancestor {
                if node.hasClass("comment_form_container") { return false }
                ancestor = node.parent()
            }
            return true
        }
        // Index owners once. Looking for descendants of each ancestor while
        // resolving every reply would repeatedly scan the same large thread.
        var ownerIDs: [ObjectIdentifier: String] = [:]
        for element in elements {
            var owner = element.parent()
            while let node = owner, !node.hasClass("comments_subtree") {
                owner = node.parent()
            }
            let shortID = try element.attr("data-shortid")
            guard let owner, !shortID.isEmpty, ids.insert(shortID).inserted,
                  ownerIDs.updateValue(shortID, forKey: ObjectIdentifier(owner)) == nil else {
                throw StoryHTMLParserError.incompatibleComments
            }
        }
        let comments = try elements.map { element in
            let shortID = try element.attr("data-shortid")
            guard let commentText = try element.select(".comment_text").first() else {
                throw StoryHTMLParserError.incompatibleComments
            }
            let byline = try element.select(".byline").first()
            let statusText = try commentText.select(".na").text().lowercased()
            let timestampElement = try byline?.select("time").first()
            let date = try timestamp(from: timestampElement)
            let permalinkElement = try byline?.select("a[href^='/c/']").first()
            let href = try permalinkElement?.attr("href") ?? "/c/\(shortID)"
            let permalink = absoluteURL(from: href, relativeTo: pageURL)
                ?? URL(string: "/c/\(shortID)", relativeTo: pageURL)!.absoluteURL
            let scoreElement = try element.select(".voters .upvoter").first()
            let score = try LobstersHTMLParser.score(from: scoreElement)

            return Comment(
                short_id: shortID,
                short_id_url: permalink.absoluteString,
                created_at: date,
                last_edited_at: date,
                is_deleted: statusText.contains("deleted"),
                is_moderated: statusText.contains("moderated") || statusText.contains("moderator"),
                score: score.value,
                score_is_hidden: score.isHidden,
                score_is_unavailable: score.isUnavailable,
                flags: element.hasClass("flagged") ? 1 : 0,
                url: permalink.absoluteString,
                comment: try commentText.html(),
                parent_comment: try parentCommentID(for: element, ownerIDs: ownerIDs),
                commenting_user: try LobstersHTMLParser.username(in: byline) ?? "",
                user_upvoted: element.hasClass("upvoted"),
                can_edit: try !element.select("a.comment_editor").isEmpty(),
                can_delete: try !element.select("a.comment_deletor").isEmpty(),
                can_reply: try !element.hasClass("flagged")
                    && !element.select("a.comment_replier").isEmpty(),
                can_vote: try !element.select("button.upvoter").isEmpty()
            )
        }
        guard comments.allSatisfy({ comment in
            comment.parent_comment.map { ids.contains($0) } ?? true
        }) else {
            throw StoryHTMLParserError.incompatibleComments
        }
        return comments
    }

    /// Inspect the original DOM without serializing or reparsing it. Known
    /// comment bodies and controls are opaque; unexpected text around them
    /// means the page cannot be safely represented as a complete comment tree.
    private static func validateCommentMarkup(in document: Document) throws {
        var pending: [(node: Node, inComments: Bool)] = [(document, false)]
        var foundComments = false
        while let (node, inComments) = pending.popLast() {
            var inside = inComments
            if let element = node as? Element {
                if element.hasClass("comment_form_container") || element.hasClass("thread_summary") {
                    continue
                }
                inside = inside || element.hasClass("comments")
                foundComments = foundComments || inside
                if element.hasClass("comment") { continue }
            } else if inside, let text = node as? TextNode,
                      !text.getWholeText().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw StoryHTMLParserError.incompatibleComments
            }
            for child in node.getChildNodes() {
                pending.append((child, inside))
            }
        }
        guard foundComments else { throw StoryHTMLParserError.incompatibleComments }
    }

    private static func parentCommentID(for element: Element, ownerIDs: [ObjectIdentifier: String]) throws -> String? {
        let ownID = try element.attr("data-shortid")
        var ancestor = element.parent()
        var foundSubtree = false

        while let current = ancestor {
            if current.hasClass("comments_subtree") {
                foundSubtree = true
                if let candidate = ownerIDs[ObjectIdentifier(current)], candidate != ownID {
                    return candidate
                }
            }
            ancestor = current.parent()
        }

        guard foundSubtree else { throw StoryHTMLParserError.incompatibleComments }
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
