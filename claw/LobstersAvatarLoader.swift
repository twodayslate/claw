//
//  LobstersAvatarLoader.swift
//  claw
//

import UIKit

@MainActor
final class LobstersAvatarLoader {
    private struct CacheKey: Hashable {
        let origin: String
        let username: String
    }

    struct Avatar {
        let url: URL
        let image: UIImage
    }

    private let pageLoader: LobstersPageLoader
    private var cache = [CacheKey: Avatar]()

    init(pageLoader: LobstersPageLoader = .shared) {
        self.pageLoader = pageLoader
    }

    func avatar(for username: String) async throws -> Avatar? {
        let profileURL = APIConfiguration.shared.userPageURL(username: username)
        let key = CacheKey(
            origin: Self.origin(of: profileURL),
            username: username
        )
        if let cached = cache[key] {
            return cached
        }

        let page = try await pageLoader.load(profileURL)
        guard let avatarURL = try await Task.detached(priority: .utility, operation: {
            try LobstersHTMLParser.avatarURL(from: page.html, pageURL: profileURL)
        }).value else {
            return nil
        }

        let data = try await pageLoader.data(from: avatarURL)
        guard let image = UIImage(data: data) else {
            return nil
        }
        let avatar = Avatar(url: avatarURL, image: makeTabBarAvatar(from: image))
        cache[key] = avatar
        return avatar
    }

    private static func origin(of url: URL) -> String {
        var components = URLComponents()
        components.scheme = url.scheme?.lowercased()
        components.host = url.host?.lowercased()
        components.port = url.port
        return components.string ?? url.absoluteString
    }

    private func makeTabBarAvatar(from image: UIImage) -> UIImage {
        let size = CGSize(width: 27, height: 27)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).addClip()
            image.draw(in: CGRect(origin: .zero, size: size))
        }.withRenderingMode(.alwaysOriginal)
    }
}
