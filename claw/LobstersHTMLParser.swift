//
//  LobstersHTMLParser.swift
//  claw
//

import Foundation
import SwiftSoup

struct LobstersStoryFields: Sendable {
    let shortID: String
    let title: String
    let destinationURL: URL
    let storyURL: URL
    let createdAt: String
    let score: Int
    let submitter: String
    let userIsAuthor: Bool
    let tags: [String]
    let userUpvoted: Bool
}

enum LobstersHTMLParser {
    private static let outputDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        return formatter
    }()

    static func username(from html: String) throws -> String? {
        let document = try SwiftSoup.parse(html)
        let username = try document.body()?.attr("data-username")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return username?.isEmpty == false ? username : nil
    }

    static func avatarURL(from html: String, pageURL: URL) throws -> URL? {
        let document = try SwiftSoup.parse(html, pageURL.absoluteString)
        guard let avatar = try document.select("#gravatar img.avatar").first() else {
            return nil
        }
        let source = try avatar.attr("src")
        guard !source.isEmpty else {
            return nil
        }
        return URL(string: source, relativeTo: pageURL)?.absoluteURL
    }

    static func storyFields(
        from element: Element,
        pageURL: URL
    ) throws -> LobstersStoryFields? {
        let shortID = try element.attr("data-shortid")
        guard !shortID.isEmpty,
              let titleElement = try element.select("span.link a.u-url").first() else {
            return nil
        }

        let title = try titleElement.text()
        let destinationHref = try titleElement.attr("href")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty,
              !destinationHref.isEmpty,
              let destinationURL = URL(
                  string: destinationHref,
                  relativeTo: pageURL
              )?.absoluteURL else {
            return nil
        }

        let storyURL = absoluteURL("/s/\(shortID)", relativeTo: pageURL)
        let byline = try element.select("div.byline").first()
        let bylineText = try byline?.text().lowercased() ?? ""

        return LobstersStoryFields(
            shortID: shortID,
            title: title,
            destinationURL: destinationURL,
            storyURL: storyURL,
            createdAt: try timestamp(from: byline?.select("time").first()),
            score: try number(from: element.select("div.voters .upvoter").first()),
            submitter: try username(in: byline) ?? "",
            userIsAuthor: bylineText.contains("authored by"),
            tags: try element.select("ul.tags a").array().map { try $0.text() },
            userUpvoted: element.hasClass("upvoted")
        )
    }

    static func username(in byline: Element?) throws -> String? {
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

    static func number(from element: Element?) throws -> Int {
        guard let element else {
            return 0
        }
        let title = try element.attr("title")
        let candidate = title.isEmpty ? try element.text() : title
        let digits = candidate.filter { $0.isNumber || $0 == "-" }
        return Int(digits) ?? 0
    }

    static func timestamp(from element: Element?) throws -> String {
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

    static func formattedDate(_ date: Date) -> String {
        outputDateFormatter.string(from: date)
    }

    static func absoluteURL(_ value: String, relativeTo pageURL: URL) -> URL {
        URL(string: value, relativeTo: pageURL)?.absoluteURL ?? pageURL
    }
}
