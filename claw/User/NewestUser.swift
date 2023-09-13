import Foundation

struct KeybaseSignatures: Codable, Identifiable, Hashable {
    var id: String {
        return kb_username
    }
    var kb_username: String
    var sig_hash: String
}

struct NewestUser: Codable, Identifiable, Hashable {
    var id: String {
        return username
    }
    var username: String
    var created_at: String
    var is_admin: Bool
    var about: String
    var is_moderator: Bool
    var karma: Int? // pushcx doesn't have any karma
    var avatar_url: String
    var invited_by_user: String? // jcs wasn't invited by anyone
    var github_username: String?
    var twitter_username: String?
    var keybase_signatures: [KeybaseSignatures]?
    
    static var placeholder: NewestUser {
        let username = ["username", "bot"].randomElement() ?? "unknown"
        let invited_by_user: [String?] = ["twodayslate", nil]
        return NewestUser(username: username, created_at: "2020-09-17T08:35:19.000-05:00", is_admin: false, about: "", is_moderator: false, karma: Int.random(in: 1..<1000), avatar_url: "/avatars/\(username)-100.png", invited_by_user: invited_by_user.randomElement() ?? nil, github_username: nil, twitter_username: nil, keybase_signatures: nil)
    }
}
