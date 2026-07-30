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

        let shortID = try storyElement.attr("data-shortid")
        guard !shortID.isEmpty else {
            throw StoryHTMLParserError.missingStoryID
        }

        guard let titleElement = try storyElement.select("span.link a.u-url").first() else {
            throw StoryHTMLParserError.missingTitle
        }

        let title = try titleElement.text()
        guard !title.isEmpty else {
            throw StoryHTMLParserError.missingTitle
        }

        let comments = try parseComments(document: document, pageURL: pageURL)
        let canonicalURL = cleanURL(pageURL)
        let byline = try storyElement.select("div.byline").first()
        let submitter = try username(in: byline) ?? ""
        let bylineText = try byline?.text().lowercased() ?? ""
        let storyTime = try storyElement.select("time").first()
        let createdAt = try timestamp(from: storyTime)
        let tags = try storyElement.select("ul.tags a").array().map { try $0.text() }
        let description = try document.select("div.story_content div.story_text").first()?.html() ?? ""
        let scoreElement = try storyElement.select("div.voters .upvoter").first()
        let score = try number(from: scoreElement)

        let href = try titleElement.attr("href")
        let destinationURL = absoluteURL(from: href, relativeTo: pageURL)
        let isSelfPost = destinationURL?.host == pageURL.host
            && destinationURL?.path.hasPrefix("/s/\(shortID)") == true

        return Story(
            short_id: shortID,
            short_id_url: shortStoryURL(shortID: shortID, relativeTo: pageURL).absoluteString,
            created_at: createdAt,
            title: title,
            url: isSelfPost ? "" : (destinationURL?.absoluteString ?? href),
            score: score,
            flags: 0,
            comment_count: comments.count,
            description: description,
            comments_url: canonicalURL.absoluteString,
            submitter_user: submitter,
            user_is_author: bylineText.contains("authored by"),
            tags: tags,
            comments: comments
        )
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
                score: try number(from: scoreElement),
                flags: element.hasClass("flagged") ? 1 : 0,
                url: permalink.absoluteString,
                comment: try commentText?.html() ?? "",
                parent_comment: try parentCommentID(for: element),
                commenting_user: try username(in: byline) ?? ""
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

    private static func username(in byline: Element?) throws -> String? {
        guard let byline else {
            return nil
        }

        for link in try byline.select("a[href^='/~']").array() {
            if try link.attr("aria-hidden") == "true" {
                continue
            }
            let name = try link.text()
            if !name.isEmpty {
                return name
            }
        }
        return nil
    }

    private static func number(from element: Element?) throws -> Int {
        guard let element else {
            return 0
        }

        let candidate = try element.attr("title").isEmpty
            ? element.text()
            : element.attr("title")
        let digits = candidate.filter { $0.isNumber || $0 == "-" }
        return Int(digits) ?? 0
    }

    private static func timestamp(from element: Element?) throws -> String {
        if let unixString = try element?.attr("data-at-unix"),
           let unixTime = TimeInterval(unixString) {
            return formattedDate(Date(timeIntervalSince1970: unixTime))
        }

        if let dateString = try element?.attr("datetime"), !dateString.isEmpty {
            let formatter = ISO8601DateFormatter()
            if let date = formatter.date(from: dateString) {
                return formattedDate(date)
            }
            return dateString
        }

        return formattedDate(Date())
    }

    private static func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        return formatter.string(from: date)
    }

    private static func cleanURL(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        components.query = nil
        components.fragment = nil
        return components.url ?? url
    }

    private static func shortStoryURL(shortID: String, relativeTo pageURL: URL) -> URL {
        var components = URLComponents()
        components.scheme = pageURL.scheme
        components.host = pageURL.host
        components.port = pageURL.port
        components.path = "/s/\(shortID)"
        return components.url ?? URL(string: "/s/\(shortID)", relativeTo: pageURL)!.absoluteURL
    }

    private static func absoluteURL(from href: String, relativeTo pageURL: URL) -> URL? {
        URL(string: href, relativeTo: pageURL)?.absoluteURL
    }
}
