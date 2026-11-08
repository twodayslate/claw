import Foundation

enum ActiveSheet: Identifiable, Equatable {
    static func == (lhs: ActiveSheet, rhs: ActiveSheet) -> Bool {
        lhs.id == rhs.id
    }

    case share(URL)
    case safari(URL)
    case story(id:String, url:URL?)
    case comment(id: String, url: URL)
    case user(username:String)
    case url(URL)
    case error(Error)
    
    var id: String {
        switch self {
        case .share(let url): return "share:\(url.absoluteString)"
        case .safari(let url): return "safari:\(url.absoluteString)"
        case .user(let username): return "user:\(username)"
        case .story(let id, let url): return "story:\(id):\(url?.fragment ?? "")"
        case .comment(let id, _): return "comment:\(id)"
        case .url(let url): return "url\(url.absoluteString)"
        case .error(let error): return "error: \(error)"
        }
    }

    static func destination(for url: URL) -> ActiveSheet? {
        guard let link = LobstersLink(url: url) else { return nil }
        switch link {
        case .story(let id, let url): return .story(id: id, url: url)
        case .comment(let id, let url): return .comment(id: id, url: url)
        case .user(let username): return .user(username: username)
        }
    }
}

extension ActiveSheet: CustomDebugStringConvertible {
    var debugDescription: String {
        return self.id
    }
}
