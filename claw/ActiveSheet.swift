import Foundation

enum ActiveSheet: Identifiable, Equatable {
    case share(URL)
    case safari(URL)
    case story(id:String)
    case user(username:String)
    case url(URL)
    
    var id: String {
        switch self {
        case .share(let url): return "share:\(url.absoluteString)"
        case .safari(let url): return "safari:\(url.absoluteString)"
        case .user(let username): return "user:\(username)"
        case .story(let id): return "id:\(id)"
        case .url(let url): return "url\(url.absoluteString)"
        }
    }
}

extension ActiveSheet: CustomDebugStringConvertible {
    var debugDescription: String {
        return self.id
    }
}
