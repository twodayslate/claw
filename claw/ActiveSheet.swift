import Foundation

enum ActiveSheet: Identifiable {
    case share(URL)
    case safari(URL)
    case story(id:String)
    case user(username:String)
    case url(URL)
    
    var id: String {
        switch self {
        case .share(let url): return "share:\(url.absoluteString)"
        case .safari(let url): return "safari:\(url.absoluteString)"
        case .user(let id): return "user:\(id)"
        case .story(let username): return "username:\(username)"
        case .url(let url): return "url\(url.absoluteString)"
        }
    }
}

extension ActiveSheet: CustomDebugStringConvertible {
    var debugDescription: String {
        return self.id
    }
}
