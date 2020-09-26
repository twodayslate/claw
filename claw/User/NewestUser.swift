import Foundation

struct KeybaseSignatures: Codable, Identifiable {
    var id: String {
        return kb_username
    }
    var kb_username: String
    var sig_hash: String
}

struct NewestUser: Codable, Identifiable {
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
        return NewestUser(username: "username", created_at: "2020-09-17T08:35:19.000-05:00", is_admin: false, about: "", is_moderator: false, karma: 1, avatar_url: "/avatars/username-100.png", invited_by_user: "twodayslate", github_username: nil, twitter_username: nil, keybase_signatures: nil)
    }
}
